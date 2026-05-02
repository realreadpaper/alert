package com.deviceguard.features.pairing

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import org.json.JSONObject

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
        val json = JSONObject(payload)
        assertEquals("device_guard_pairing_invite", json.getString("type"))
        assertEquals("invite-1", json.getString("inviteId"))
        assertEquals("group-1", json.getString("groupId"))
        assertEquals("owner-device", json.getString("ownerDeviceId"))
        assertEquals("token-1", json.getString("joinToken"))
        assertEquals(1_777_560_300L, json.getLong("expiresAtEpochSeconds"))
        val decoded = service.decodeInviteFromQrCode(payload, now + 10)
        assertEquals(invite, decoded)

        val canonicalPayload = """
            {"type":"device_guard_pairing_invite","protocolVersion":1,"inviteId":"invite-2","groupId":"group-2","ownerDeviceId":"owner-2","joinToken":"token-2","expiresAtEpochSeconds":1777560600}
        """.trimIndent()
        val canonicalInvite = service.decodeInviteFromQrCode(canonicalPayload, now)
        assertEquals("invite-2", canonicalInvite.inviteId)
        assertEquals(1_777_560_600L, canonicalInvite.expiresAtEpochSeconds)

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
