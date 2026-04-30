package com.deviceguard.features.pairing

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals

class GuardPairingServiceTest {
    @Test
    fun createInviteDecodeAndApproveJoin() {
        val ids = ArrayDeque(listOf("group-1", "invite-1"))
        val service = GuardPairingService(
            idFactory = { ids.removeFirst() },
            tokenFactory = { "token-1" },
            secretFactory = { "secret-1".toByteArray() }
        )
        val now = 1_777_560_000L

        val (group, secret) = service.createGroup(
            ownerDeviceId = "owner-device",
            ownerDisplayName = "主力 iPhone",
            ownerPlatform = GuardPlatform.IOS,
            nowEpochSeconds = now
        )
        assertEquals("group-1", group.groupId)
        assertEquals(1, group.devices.size)
        assertContentEquals("secret-1".toByteArray(), secret)

        val invite = service.createInvite(group, "owner-device", now)
        val payload = service.encodeInviteForQrCode(invite)
        val decoded = service.decodeInviteFromQrCode(payload, now + 10)
        assertEquals(invite, decoded)

        val request = service.createJoinRequest(
            invite = decoded,
            deviceId = "member-device",
            displayName = "商务 Android",
            platform = GuardPlatform.ANDROID,
            nowEpochSeconds = now + 20
        )

        val approved = service.approveJoin(
            request = request,
            invite = decoded,
            group = group,
            groupSecret = secret,
            nowEpochSeconds = now + 30
        )
        assertEquals(2, approved.group.devices.size)
        assertEquals(GuardDeviceRole.MEMBER, approved.group.devices.last().role)
        assertContentEquals(secret, approved.groupSecret)
    }
}
