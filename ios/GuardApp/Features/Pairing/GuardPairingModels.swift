import Foundation

enum GuardPlatform: String, Codable, Equatable {
    case iOS
    case android
}

enum GuardDeviceRole: String, Codable, Equatable {
    case owner
    case member
}

enum GuardMode: String, Codable, Equatable {
    case outing
    case indoor
    case silent
}

struct GuardDevice: Codable, Equatable {
    let deviceId: String
    var displayName: String
    let platform: GuardPlatform
    let role: GuardDeviceRole
    let joinedAt: Date
}

struct GuardGroup: Codable, Equatable {
    let groupId: String
    var displayName: String
    var keyVersion: Int
    let createdAt: Date
    var devices: [GuardDevice]
    var currentMode: GuardMode
}

struct PairingInvite: Codable, Equatable {
    let inviteId: String
    let expiresAt: Date
    let groupId: String
    let ownerDeviceId: String
    let joinToken: String
    let protocolVersion: Int
}

struct JoinRequest: Codable, Equatable {
    let inviteId: String
    let groupId: String
    let deviceId: String
    let displayName: String
    let platform: GuardPlatform
    let requestedAt: Date
}

struct ApprovedJoin: Codable, Equatable {
    let group: GuardGroup
    let groupSecret: Data
}

enum PairingError: Error, Equatable {
    case expiredInvite
    case groupMismatch
    case ownerDeviceMismatch
    case duplicateDevice
    case unsupportedProtocolVersion
    case invalidInvitePayload
}
