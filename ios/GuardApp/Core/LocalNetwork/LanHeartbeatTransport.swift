import Darwin
import Foundation

#if canImport(Network)
import Network
#endif

protocol LanHeartbeatTransport: AnyObject {
    func start(onReceive: @escaping (Data) -> Void)
    func stop()
    func send(_ data: Data)
}

final class UdpLanHeartbeatTransport: LanHeartbeatTransport {
    private let port: UInt16
    private let queue = DispatchQueue(label: "deviceguard.lan-heartbeat", attributes: .concurrent)
    private var socketFileDescriptor: Int32 = -1
    private var running = false
    private var onReceive: ((Data) -> Void)?

    init(port: UInt16 = 41010) {
        self.port = port
    }

    func start(onReceive: @escaping (Data) -> Void) {
        queue.async {
            self.onReceive = onReceive
            guard !self.running else { return }

            let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            guard descriptor >= 0 else { return }

            var enabled: Int32 = 1
            setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &enabled, socklen_t(MemoryLayout<Int32>.size))
            setsockopt(descriptor, SOL_SOCKET, SO_BROADCAST, &enabled, socklen_t(MemoryLayout<Int32>.size))

            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = self.networkByteOrder(self.port)
            address.sin_addr = in_addr(s_addr: INADDR_ANY)

            let bindResult = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                    bind(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }

            guard bindResult == 0 else {
                close(descriptor)
                return
            }

            self.socketFileDescriptor = descriptor
            self.running = true
            self.receiveLoop()
        }
    }

    func stop() {
        queue.async {
            self.running = false
            if self.socketFileDescriptor >= 0 {
                close(self.socketFileDescriptor)
                self.socketFileDescriptor = -1
            }
        }
    }

    func send(_ data: Data) {
        queue.async {
            guard self.socketFileDescriptor >= 0 else { return }

            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = self.networkByteOrder(self.port)
            address.sin_addr = in_addr(s_addr: inet_addr("255.255.255.255"))

            data.withUnsafeBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else { return }
                _ = withUnsafePointer(to: &address) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                        sendto(
                            self.socketFileDescriptor,
                            baseAddress,
                            data.count,
                            0,
                            socketAddress,
                            socklen_t(MemoryLayout<sockaddr_in>.size)
                        )
                    }
                }
            }
        }
    }

    private func receiveLoop() {
        queue.async {
            var buffer = [UInt8](repeating: 0, count: 4096)

            while self.running && self.socketFileDescriptor >= 0 {
                let received = recv(self.socketFileDescriptor, &buffer, buffer.count, 0)
                if received > 0 {
                    let data = Data(buffer.prefix(Int(received)))
                    DispatchQueue.main.async { [weak self] in
                        self?.onReceive?(data)
                    }
                } else if received < 0 && errno != EINTR {
                    self.running = false
                }
            }
        }
    }

    private func networkByteOrder(_ value: UInt16) -> UInt16 {
        value.bigEndian
    }
}

#if canImport(Network)
final class BonjourLanHeartbeatTransport: LanHeartbeatTransport {
    private let serviceType: String
    private let queue = DispatchQueue(label: "deviceguard.bonjour-heartbeat")
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]
    private var receiveBuffers: [String: Data] = [:]
    private var onReceive: ((Data) -> Void)?

    init(serviceType: String = "_deviceguard._tcp") {
        self.serviceType = serviceType
    }

    func start(onReceive: @escaping (Data) -> Void) {
        queue.async {
            self.onReceive = onReceive
            if self.listener != nil || self.browser != nil { return }
            self.startListener()
            self.startBrowser()
        }
    }

    func stop() {
        queue.async {
            self.listener?.cancel()
            self.browser?.cancel()
            self.connections.values.forEach { $0.cancel() }
            self.listener = nil
            self.browser = nil
            self.connections.removeAll()
            self.receiveBuffers.removeAll()
        }
    }

    func send(_ data: Data) {
        let framed = frame(data)
        queue.async {
            for connection in self.connections.values {
                connection.send(content: framed, completion: .contentProcessed { _ in })
            }
        }
    }

    private func startListener() {
        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(type: serviceType)
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            listener = nil
        }
    }

    private func startBrowser() {
        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.connect(to: results)
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    private func connect(to results: Set<NWBrowser.Result>) {
        let activeKeys = Set(results.map { "endpoint:\(String(describing: $0.endpoint))" })
        for key in connections.keys where !activeKeys.contains(key) && key.hasPrefix("endpoint:") {
            connections[key]?.cancel()
            connections.removeValue(forKey: key)
        }

        for result in results {
            let key = "endpoint:\(String(describing: result.endpoint))"
            guard connections[key] == nil else { continue }
            let connection = NWConnection(to: result.endpoint, using: .tcp)
            connections[key] = connection
            connection.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    self?.removeConnection(key)
                }
                if case .cancelled = state {
                    self?.removeConnection(key)
                }
            }
            connection.start(queue: queue)
        }
    }

    private func accept(_ connection: NWConnection) {
        let key = "inbound:\(UUID().uuidString)"
        connections[key] = connection
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                self?.removeConnection(key)
            }
            if case .cancelled = state {
                self?.removeConnection(key)
            }
        }
        connection.start(queue: queue)
        receive(on: connection, key: key)
    }

    private func receive(on connection: NWConnection, key: String) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                var buffer = self.receiveBuffers[key] ?? Data()
                buffer.append(data)
                self.receiveBuffers[key] = buffer
                self.drainBuffer(for: key)
            }
            if error == nil && !isComplete {
                self.receive(on: connection, key: key)
            } else {
                self.removeConnection(key)
            }
        }
    }

    private func drainBuffer(for key: String) {
        guard var buffer = receiveBuffers[key] else { return }

        while buffer.count >= 4 {
            let length = buffer.prefix(4).reduce(UInt32(0)) { partial, byte in
                (partial << 8) | UInt32(byte)
            }
            let payloadLength = Int(length)
            guard payloadLength > 0 && buffer.count >= 4 + payloadLength else { break }

            let payload = buffer.subdata(in: 4..<(4 + payloadLength))
            buffer.removeSubrange(0..<(4 + payloadLength))
            DispatchQueue.main.async { [weak self] in
                self?.onReceive?(payload)
            }
        }

        receiveBuffers[key] = buffer
    }

    private func removeConnection(_ key: String) {
        queue.async {
            self.connections[key]?.cancel()
            self.connections.removeValue(forKey: key)
            self.receiveBuffers.removeValue(forKey: key)
        }
    }

    private func frame(_ data: Data) -> Data {
        var length = UInt32(data.count).bigEndian
        var framed = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        framed.append(data)
        return framed
    }
}
#endif

final class InMemoryLanHeartbeatTransport: LanHeartbeatTransport {
    private var onReceive: ((Data) -> Void)?
    private(set) var sentPayloads: [Data] = []

    func start(onReceive: @escaping (Data) -> Void) {
        self.onReceive = onReceive
    }

    func stop() {
        onReceive = nil
    }

    func send(_ data: Data) {
        sentPayloads.append(data)
    }

    func simulateReceive(_ data: Data) {
        onReceive?(data)
    }
}
