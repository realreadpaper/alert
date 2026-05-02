package com.deviceguard.core.localnetwork

import com.deviceguard.core.guardengine.GuardMode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class LanHeartbeatMessageTest {
    @Test
    fun signedHeartbeatVerifiesAndRoundTrips() {
        val signer = LanHeartbeatSigner()
        val secret = "shared-secret-32-byte-material".toByteArray()
        val message = signer.create(
            groupId = "group-1",
            groupSecret = secret,
            deviceId = "device-a",
            deviceName = "主力 iPhone",
            mode = GuardMode.OUTING,
            timestamp = 1_777_560_000,
            nonce = "nonce-1"
        )

        assertTrue(signer.verify(message, secret, now = 1_777_560_010))
        assertFalse(signer.verify(message, "wrong-secret".toByteArray(), now = 1_777_560_010))
        assertFalse(signer.verify(message, secret, now = 1_777_560_100))

        val encoded = signer.encode(message)
        assertTrue(encoded.contains("\"mode\":\"outing\""))
        val decoded = signer.decode(encoded)
        assertEquals(message, decoded)
    }
}
