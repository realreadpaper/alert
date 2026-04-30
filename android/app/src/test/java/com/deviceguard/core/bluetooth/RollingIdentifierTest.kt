package com.deviceguard.core.bluetooth

import kotlin.test.Test
import kotlin.test.assertEquals

class RollingIdentifierTest {
    @Test
    fun rollingIdentifierIsStableWithinBucketAndMapsBackToDevice() {
        val generator = RollingIdentifierGenerator(bucketSeconds = 300, outputBytes = 8)
        val secret = "shared-secret-32-byte-material".toByteArray()

        val first = generator.generate(secret, "device-a", 1_777_560_010)
        val second = generator.generate(secret, "device-a", 1_777_560_020)
        assertEquals(first, second)

        val candidates = generator.candidates(secret, listOf("device-a", "device-b"), 1_777_560_010)
        assertEquals("device-a", candidates[first.value])
    }
}
