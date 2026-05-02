import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum GuardAppScreen: Equatable {
    case home
    case addDevice
}

final class GuardAppState: ObservableObject {
    @Published private(set) var screen: GuardAppScreen
    @Published private(set) var mode: GuardMode
    @Published private(set) var isGuarding: Bool
    @Published private(set) var activeInviteCode: String
    @Published private(set) var deviceRows: [HomeDeviceRow]
    @Published private(set) var homeStatus: HomeStatusSummary
    @Published private(set) var localNetworkStatus: String

    private struct Peer {
        let id: String
        var displayName: String
        var mode: GuardMode
        var lastSeenAt: Date
    }

    private let localDeviceId: String
    private let localDeviceName: String
    private let groupId: String
    private let groupSecret: Data
    private let signer: LanHeartbeatSigner
    private let transport: LanHeartbeatTransport
    private let now: () -> Date
    private let pairingService: GuardPairingService
    private let expectedGroupHash: String
    private var peers: [String: Peer] = [:]
    private var heartbeatTimer: Timer?
    private var hasStarted = false

    init(
        localDeviceId: String,
        localDeviceName: String,
        groupId: String,
        groupSecret: Data,
        signer: LanHeartbeatSigner = LanHeartbeatSigner(),
        transport: LanHeartbeatTransport,
        now: @escaping () -> Date = Date.init
    ) {
        self.localDeviceId = localDeviceId
        self.localDeviceName = localDeviceName
        self.groupId = groupId
        self.groupSecret = groupSecret
        self.signer = signer
        self.transport = transport
        self.now = now
        pairingService = GuardPairingService()
        expectedGroupHash = signer.create(
            groupId: groupId,
            groupSecret: groupSecret,
            deviceId: localDeviceId,
            deviceName: localDeviceName,
            mode: .outing,
            timestamp: Int64(now().timeIntervalSince1970),
            nonce: "group-hash"
        ).groupHash

        screen = .home
        mode = .outing
        isGuarding = true
        activeInviteCode = ""
        homeStatus = HomeStatusSummary(
            title: "待添加",
            color: GuardColor.warning,
            deviceCountText: "0",
            message: "添加至少一台设备后开始互相看护"
        )
        localNetworkStatus = "本地网络待启动"
        deviceRows = [
            HomeDeviceRow(id: localDeviceId, name: localDeviceName, stateText: "本机", stateColor: GuardColor.safe)
        ]
    }

    static func live() -> GuardAppState {
        let defaults = UserDefaults.standard
        let key = "DeviceGuard.localDeviceId"
        let deviceId: String
        if let stored = defaults.string(forKey: key) {
            deviceId = stored
        } else {
            deviceId = UUID().uuidString
            defaults.set(deviceId, forKey: key)
        }

        #if canImport(UIKit)
        let deviceName = UIDevice.current.name
        #else
        let deviceName = "本机设备"
        #endif

        return GuardAppState(
            localDeviceId: deviceId,
            localDeviceName: deviceName,
            groupId: "device-guard-local-test-group",
            groupSecret: Data("device-guard-local-test-secret-32b".utf8),
            transport: BonjourLanHeartbeatTransport()
        )
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        localNetworkStatus = "本地网络监听中"
        transport.start { [weak self] data in
            self?.handleIncomingHeartbeat(data)
        }
        sendHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
            self?.refreshDeviceRows()
        }
    }

    func stop() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        transport.stop()
        hasStarted = false
        localNetworkStatus = "本地网络已停止"
    }

    func startAddDevice() {
        let owner = GuardDevice(
            deviceId: localDeviceId,
            displayName: localDeviceName,
            platform: .iOS,
            role: .owner,
            joinedAt: now()
        )
        let group = GuardGroup(
            groupId: groupId,
            displayName: "看护组",
            keyVersion: 1,
            createdAt: now(),
            devices: [owner],
            currentMode: mode
        )

        if let invite = try? pairingService.createInvite(group: group, ownerDeviceId: localDeviceId, now: now()),
           let payload = try? pairingService.encodeInviteForQRCode(invite) {
            activeInviteCode = payload
        } else {
            activeInviteCode = "无法创建邀请，请稍后重试"
        }
        screen = .addDevice
    }

    func cancelAddDevice() {
        activeInviteCode = ""
        screen = .home
    }

    func toggleGuarding() {
        isGuarding.toggle()
        localNetworkStatus = isGuarding ? "本地网络监听中" : "看护已暂停"
        if isGuarding {
            sendHeartbeat()
        }
        refreshDeviceRows()
    }

    func selectMode(_ selectedMode: GuardMode) {
        mode = selectedMode
        sendHeartbeat()
    }

    func sendHeartbeat() {
        guard isGuarding else { return }
        let message = signer.create(
            groupId: groupId,
            groupSecret: groupSecret,
            deviceId: localDeviceId,
            deviceName: localDeviceName,
            mode: mode,
            timestamp: Int64(now().timeIntervalSince1970)
        )

        if let data = try? signer.encode(message) {
            transport.send(data)
        }
    }

    func receiveHeartbeatData(_ data: Data) throws {
        let message = try signer.decode(data)
        guard message.deviceId != localDeviceId else { return }
        guard message.groupHash == expectedGroupHash else { return }
        guard signer.verify(
            message,
            groupSecret: groupSecret,
            now: Int64(now().timeIntervalSince1970),
            allowedSkewSeconds: 120
        ) else { return }

        peers[message.deviceId] = Peer(
            id: message.deviceId,
            displayName: peerDisplayName(for: message.deviceId),
            mode: message.mode,
            lastSeenAt: Date(timeIntervalSince1970: TimeInterval(message.timestamp))
        )
        refreshDeviceRows()
    }

    private func handleIncomingHeartbeat(_ data: Data) {
        do {
            try receiveHeartbeatData(data)
        } catch {
            localNetworkStatus = "收到无法验证的本地心跳"
        }
    }

    private func refreshDeviceRows() {
        let localStateText = isGuarding ? "本机" : "已暂停"
        let localRow = HomeDeviceRow(
            id: localDeviceId,
            name: localDeviceName,
            stateText: localStateText,
            stateColor: isGuarding ? GuardColor.safe : GuardColor.ink500
        )

        let peerRows = peers.values
            .sorted { $0.displayName < $1.displayName }
            .map { peer -> HomeDeviceRow in
                let age = now().timeIntervalSince(peer.lastSeenAt)
                if age <= 10 {
                    return HomeDeviceRow(id: peer.id, name: peer.displayName, stateText: "在线", stateColor: GuardColor.safe)
                }
                if age <= 30 {
                    return HomeDeviceRow(id: peer.id, name: peer.displayName, stateText: "不稳定", stateColor: GuardColor.warning)
                }
                return HomeDeviceRow(id: peer.id, name: peer.displayName, stateText: "失联", stateColor: GuardColor.danger)
            }

        deviceRows = [localRow] + peerRows
        homeStatus = makeHomeStatus(peerRows: peerRows)
    }

    private func peerDisplayName(for deviceId: String) -> String {
        let suffix = String(deviceId.suffix(4)).uppercased()
        return "附近 iPhone \(suffix)"
    }

    private func makeHomeStatus(peerRows: [HomeDeviceRow]) -> HomeStatusSummary {
        guard isGuarding else {
            return HomeStatusSummary(
                title: "未开启",
                color: GuardColor.ink500,
                deviceCountText: "\(peerRows.count)",
                message: "开启后，将在设备离开时提醒你"
            )
        }

        guard !peerRows.isEmpty else {
            return HomeStatusSummary(
                title: "待添加",
                color: GuardColor.warning,
                deviceCountText: "0",
                message: "添加至少一台设备后开始互相看护"
            )
        }

        if peerRows.contains(where: { $0.stateText == "失联" }) {
            return HomeStatusSummary(
                title: "失联",
                color: GuardColor.danger,
                deviceCountText: "\(peerRows.count)",
                message: "有设备未收到本地心跳"
            )
        }

        if peerRows.contains(where: { $0.stateText == "不稳定" }) {
            return HomeStatusSummary(
                title: "不稳定",
                color: GuardColor.warning,
                deviceCountText: "\(peerRows.count)",
                message: "有设备心跳延迟，请确认仍在附近"
            )
        }

        return HomeStatusSummary(
            title: "安全",
            color: GuardColor.safe,
            deviceCountText: "\(peerRows.count)",
            message: "台设备正在本地互相看护"
        )
    }
}
