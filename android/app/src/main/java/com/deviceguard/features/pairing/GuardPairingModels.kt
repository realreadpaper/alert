package com.deviceguard.features.pairing

enum class GuardPlatform {
    IOS,
    ANDROID
}

enum class GuardDeviceRole {
    OWNER,
    MEMBER
}

enum class GuardMode {
    OUTING,
    INDOOR,
    SILENT
}

data class GuardDevice(
    val deviceId: String,
    val displayName: String,
    val platform: GuardPlatform,
    val role: GuardDeviceRole,
    val joinedAtEpochSeconds: Long
)

data class GuardGroup(
    val groupId: String,
    val displayName: String,
    val keyVersion: Int,
    val createdAtEpochSeconds: Long,
    val devices: List<GuardDevice>,
    val currentMode: GuardMode
)

data class PairingInvite(
    val inviteId: String,
    val expiresAtEpochSeconds: Long,
    val groupId: String,
    val ownerDeviceId: String,
    val joinToken: String,
    val protocolVersion: Int
)

data class JoinRequest(
    val inviteId: String,
    val groupId: String,
    val deviceId: String,
    val displayName: String,
    val platform: GuardPlatform,
    val requestedAtEpochSeconds: Long
)

data class ApprovedJoin(
    val group: GuardGroup,
    val groupSecret: ByteArray
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ApprovedJoin) return false
        return group == other.group && groupSecret.contentEquals(other.groupSecret)
    }

    override fun hashCode(): Int {
        return 31 * group.hashCode() + groupSecret.contentHashCode()
    }
}

sealed class PairingException(message: String) : IllegalStateException(message) {
    data object ExpiredInvite : PairingException("invite expired")
    data object GroupMismatch : PairingException("group mismatch")
    data object OwnerDeviceMismatch : PairingException("owner device mismatch")
    data object DuplicateDevice : PairingException("duplicate device")
    data object UnsupportedProtocolVersion : PairingException("unsupported protocol version")
    data object InvalidInvitePayload : PairingException("invalid invite payload")
}
