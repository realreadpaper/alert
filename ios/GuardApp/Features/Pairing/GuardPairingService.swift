import Foundation

final class GuardPairingService {
    private let protocolVersion = 1
    private let inviteType = "device_guard_pairing_invite"
    private let idFactory: () -> String
    private let tokenFactory: () -> String
    private let secretFactory: () -> Data
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        idFactory: @escaping () -> String = { UUID().uuidString },
        tokenFactory: @escaping () -> String = { UUID().uuidString.replacingOccurrences(of: "-", with: "") },
        secretFactory: @escaping () -> Data = { Data((0..<32).map { _ in UInt8.random(in: 0...255) }) }
    ) {
        self.idFactory = idFactory
        self.tokenFactory = tokenFactory
        self.secretFactory = secretFactory

        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func createGroup(ownerDeviceId: String, ownerDisplayName: String, ownerPlatform: GuardPlatform, now: Date) -> (GuardGroup, Data) {
        let owner = GuardDevice(
            deviceId: ownerDeviceId,
            displayName: ownerDisplayName,
            platform: ownerPlatform,
            role: .owner,
            joinedAt: now
        )
        let group = GuardGroup(
            groupId: idFactory(),
            displayName: "看护组",
            keyVersion: 1,
            createdAt: now,
            devices: [owner],
            currentMode: .outing
        )
        return (group, secretFactory())
    }

    func createInvite(group: GuardGroup, ownerDeviceId: String, now: Date, validFor seconds: TimeInterval = 300) throws -> PairingInvite {
        guard group.devices.contains(where: { $0.deviceId == ownerDeviceId && $0.role == .owner }) else {
            throw PairingError.ownerDeviceMismatch
        }
        return PairingInvite(
            inviteId: idFactory(),
            expiresAtEpochSeconds: Int64(now.timeIntervalSince1970 + seconds),
            groupId: group.groupId,
            ownerDeviceId: ownerDeviceId,
            joinToken: tokenFactory(),
            protocolVersion: protocolVersion
        )
    }

    func encodeInviteForQRCode(_ invite: PairingInvite) throws -> String {
        let data = try encoder.encode(PairingInviteEnvelope(type: inviteType, invite: invite))
        return String(data: data, encoding: .utf8) ?? ""
    }

    func decodeInviteFromQRCode(_ payload: String, now: Date) throws -> PairingInvite {
        try decodeInviteFromQRCode(payload, nowEpochSeconds: Int64(now.timeIntervalSince1970))
    }

    func decodeInviteFromQRCode(_ payload: String, nowEpochSeconds: Int64) throws -> PairingInvite {
        guard let data = payload.data(using: .utf8) else {
            throw PairingError.invalidInvitePayload
        }
        let envelope = try decoder.decode(PairingInviteEnvelope.self, from: data)
        guard envelope.type == inviteType else {
            throw PairingError.invalidInvitePayload
        }
        let invite = envelope.invite
        guard invite.protocolVersion == protocolVersion else {
            throw PairingError.unsupportedProtocolVersion
        }
        guard invite.expiresAtEpochSeconds > nowEpochSeconds else {
            throw PairingError.expiredInvite
        }
        return invite
    }

    func createJoinRequest(invite: PairingInvite, deviceId: String, displayName: String, platform: GuardPlatform, now: Date) -> JoinRequest {
        JoinRequest(
            inviteId: invite.inviteId,
            groupId: invite.groupId,
            deviceId: deviceId,
            displayName: displayName,
            platform: platform,
            requestedAtEpochSeconds: Int64(now.timeIntervalSince1970)
        )
    }

    func approveJoin(request: JoinRequest, invite: PairingInvite, group: GuardGroup, groupSecret: Data, now: Date) throws -> ApprovedJoin {
        guard invite.protocolVersion == protocolVersion else {
            throw PairingError.unsupportedProtocolVersion
        }
        guard invite.expiresAtEpochSeconds > Int64(now.timeIntervalSince1970) else {
            throw PairingError.expiredInvite
        }
        guard request.groupId == group.groupId && invite.groupId == group.groupId else {
            throw PairingError.groupMismatch
        }
        guard request.inviteId == invite.inviteId else {
            throw PairingError.invalidInvitePayload
        }
        guard !group.devices.contains(where: { $0.deviceId == request.deviceId }) else {
            throw PairingError.duplicateDevice
        }

        var updated = group
        updated.devices.append(
            GuardDevice(
                deviceId: request.deviceId,
                displayName: request.displayName,
                platform: request.platform,
                role: .member,
                joinedAt: now
            )
        )

        return ApprovedJoin(group: updated, groupSecret: groupSecret)
    }
}

private struct PairingInviteEnvelope: Codable {
    let type: String
    let protocolVersion: Int
    let inviteId: String
    let groupId: String
    let ownerDeviceId: String
    let joinToken: String
    let expiresAtEpochSeconds: Int64

    init(type: String, invite: PairingInvite) {
        self.type = type
        protocolVersion = invite.protocolVersion
        inviteId = invite.inviteId
        groupId = invite.groupId
        ownerDeviceId = invite.ownerDeviceId
        joinToken = invite.joinToken
        expiresAtEpochSeconds = invite.expiresAtEpochSeconds
    }

    var invite: PairingInvite {
        PairingInvite(
            inviteId: inviteId,
            expiresAtEpochSeconds: expiresAtEpochSeconds,
            groupId: groupId,
            ownerDeviceId: ownerDeviceId,
            joinToken: joinToken,
            protocolVersion: protocolVersion
        )
    }
}
