import CryptoKit
import Foundation

struct LanHeartbeatMessage: Codable, Equatable {
    let protocolVersion: Int
    let groupHash: String
    let deviceId: String
    let deviceNameHash: String
    let timestamp: Int64
    let nonce: String
    let mode: GuardMode
    let signature: String
}

final class LanHeartbeatSigner {
    private let protocolVersion = 1
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func create(
        groupId: String,
        groupSecret: Data,
        deviceId: String,
        deviceName: String,
        mode: GuardMode,
        timestamp: Int64,
        nonce: String = UUID().uuidString
    ) -> LanHeartbeatMessage {
        let groupHash = shortHash(groupId)
        let deviceNameHash = shortHash(deviceName)
        let payload = signingPayload(
            protocolVersion: protocolVersion,
            groupHash: groupHash,
            deviceId: deviceId,
            deviceNameHash: deviceNameHash,
            timestamp: timestamp,
            nonce: nonce,
            mode: mode
        )
        return LanHeartbeatMessage(
            protocolVersion: protocolVersion,
            groupHash: groupHash,
            deviceId: deviceId,
            deviceNameHash: deviceNameHash,
            timestamp: timestamp,
            nonce: nonce,
            mode: mode,
            signature: hmac(payload, secret: groupSecret)
        )
    }

    func encode(_ message: LanHeartbeatMessage) throws -> Data {
        try encoder.encode(message)
    }

    func decode(_ data: Data) throws -> LanHeartbeatMessage {
        try decoder.decode(LanHeartbeatMessage.self, from: data)
    }

    func verify(_ message: LanHeartbeatMessage, groupSecret: Data, now: Int64, allowedSkewSeconds: Int64 = 30) -> Bool {
        guard message.protocolVersion == protocolVersion else { return false }
        guard abs(now - message.timestamp) <= allowedSkewSeconds else { return false }
        let payload = signingPayload(
            protocolVersion: message.protocolVersion,
            groupHash: message.groupHash,
            deviceId: message.deviceId,
            deviceNameHash: message.deviceNameHash,
            timestamp: message.timestamp,
            nonce: message.nonce,
            mode: message.mode
        )
        return hmac(payload, secret: groupSecret) == message.signature
    }

    private func signingPayload(
        protocolVersion: Int,
        groupHash: String,
        deviceId: String,
        deviceNameHash: String,
        timestamp: Int64,
        nonce: String,
        mode: GuardMode
    ) -> String {
        [
            String(protocolVersion),
            groupHash,
            deviceId,
            deviceNameHash,
            String(timestamp),
            nonce,
            mode.rawValue
        ].joined(separator: "|")
    }

    private func hmac(_ payload: String, secret: Data) -> String {
        let key = SymmetricKey(data: secret)
        let signature = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(signature).map { String(format: "%02x", $0) }.joined()
    }

    private func shortHash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return Data(digest).prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
