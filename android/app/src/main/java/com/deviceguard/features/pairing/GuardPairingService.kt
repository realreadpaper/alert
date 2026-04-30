package com.deviceguard.features.pairing

import org.json.JSONObject
import java.security.SecureRandom
import java.util.UUID

class GuardPairingService(
    private val idFactory: () -> String = { UUID.randomUUID().toString() },
    private val tokenFactory: () -> String = { UUID.randomUUID().toString().replace("-", "") },
    private val secretFactory: () -> ByteArray = {
        ByteArray(32).also { SecureRandom().nextBytes(it) }
    }
) {
    fun createGroup(
        ownerDeviceId: String,
        ownerDisplayName: String,
        ownerPlatform: GuardPlatform,
        nowEpochSeconds: Long
    ): Pair<GuardGroup, ByteArray> {
        val owner = GuardDevice(
            deviceId = ownerDeviceId,
            displayName = ownerDisplayName,
            platform = ownerPlatform,
            role = GuardDeviceRole.OWNER,
            joinedAtEpochSeconds = nowEpochSeconds
        )
        val group = GuardGroup(
            groupId = idFactory(),
            displayName = "看护组",
            keyVersion = 1,
            createdAtEpochSeconds = nowEpochSeconds,
            devices = listOf(owner),
            currentMode = GuardMode.OUTING
        )
        return group to secretFactory()
    }

    fun createInvite(
        group: GuardGroup,
        ownerDeviceId: String,
        nowEpochSeconds: Long,
        validForSeconds: Long = 300
    ): PairingInvite {
        val ownerMatches = group.devices.any {
            it.deviceId == ownerDeviceId && it.role == GuardDeviceRole.OWNER
        }
        if (!ownerMatches) throw PairingException.OwnerDeviceMismatch

        return PairingInvite(
            inviteId = idFactory(),
            expiresAtEpochSeconds = nowEpochSeconds + validForSeconds,
            groupId = group.groupId,
            ownerDeviceId = ownerDeviceId,
            joinToken = tokenFactory(),
            protocolVersion = PROTOCOL_VERSION
        )
    }

    fun encodeInviteForQrCode(invite: PairingInvite): String {
        return JSONObject()
            .put("inviteId", invite.inviteId)
            .put("expiresAtEpochSeconds", invite.expiresAtEpochSeconds)
            .put("groupId", invite.groupId)
            .put("ownerDeviceId", invite.ownerDeviceId)
            .put("joinToken", invite.joinToken)
            .put("protocolVersion", invite.protocolVersion)
            .toString()
    }

    fun decodeInviteFromQrCode(payload: String, nowEpochSeconds: Long): PairingInvite {
        val json = runCatching { JSONObject(payload) }
            .getOrElse { throw PairingException.InvalidInvitePayload }

        val invite = runCatching {
            PairingInvite(
                inviteId = json.getString("inviteId"),
                expiresAtEpochSeconds = json.getLong("expiresAtEpochSeconds"),
                groupId = json.getString("groupId"),
                ownerDeviceId = json.getString("ownerDeviceId"),
                joinToken = json.getString("joinToken"),
                protocolVersion = json.getInt("protocolVersion")
            )
        }.getOrElse { throw PairingException.InvalidInvitePayload }

        if (invite.protocolVersion != PROTOCOL_VERSION) {
            throw PairingException.UnsupportedProtocolVersion
        }
        if (invite.expiresAtEpochSeconds <= nowEpochSeconds) {
            throw PairingException.ExpiredInvite
        }
        return invite
    }

    fun createJoinRequest(
        invite: PairingInvite,
        deviceId: String,
        displayName: String,
        platform: GuardPlatform,
        nowEpochSeconds: Long
    ): JoinRequest {
        return JoinRequest(
            inviteId = invite.inviteId,
            groupId = invite.groupId,
            deviceId = deviceId,
            displayName = displayName,
            platform = platform,
            requestedAtEpochSeconds = nowEpochSeconds
        )
    }

    fun approveJoin(
        request: JoinRequest,
        invite: PairingInvite,
        group: GuardGroup,
        groupSecret: ByteArray,
        nowEpochSeconds: Long
    ): ApprovedJoin {
        if (invite.protocolVersion != PROTOCOL_VERSION) {
            throw PairingException.UnsupportedProtocolVersion
        }
        if (invite.expiresAtEpochSeconds <= nowEpochSeconds) {
            throw PairingException.ExpiredInvite
        }
        if (request.groupId != group.groupId || invite.groupId != group.groupId) {
            throw PairingException.GroupMismatch
        }
        if (request.inviteId != invite.inviteId) {
            throw PairingException.InvalidInvitePayload
        }
        if (group.devices.any { it.deviceId == request.deviceId }) {
            throw PairingException.DuplicateDevice
        }

        val member = GuardDevice(
            deviceId = request.deviceId,
            displayName = request.displayName,
            platform = request.platform,
            role = GuardDeviceRole.MEMBER,
            joinedAtEpochSeconds = nowEpochSeconds
        )
        return ApprovedJoin(
            group = group.copy(devices = group.devices + member),
            groupSecret = groupSecret.copyOf()
        )
    }

    private companion object {
        const val PROTOCOL_VERSION = 1
    }
}
