package com.deviceguard.core.bluetooth

import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

data class RollingIdentifier(
    val value: String,
    val timeBucket: Long
)

class RollingIdentifierGenerator(
    private val bucketSeconds: Long = 300,
    private val outputBytes: Int = 12
) {
    init {
        require(bucketSeconds > 0) { "bucketSeconds must be positive" }
        require(outputBytes in 1..32) { "outputBytes must be 1..32" }
    }

    fun generate(groupSecret: ByteArray, deviceId: String, epochSeconds: Long): RollingIdentifier {
        val bucket = epochSeconds / bucketSeconds
        return RollingIdentifier(
            value = hmacHex(groupSecret, "$deviceId:$bucket").take(outputBytes * 2),
            timeBucket = bucket
        )
    }

    fun candidates(
        groupSecret: ByteArray,
        deviceIds: List<String>,
        epochSeconds: Long,
        bucketDrift: Long = 1
    ): Map<String, String> {
        val currentBucket = epochSeconds / bucketSeconds
        return buildMap {
            for (deviceId in deviceIds) {
                for (bucket in (currentBucket - bucketDrift)..(currentBucket + bucketDrift)) {
                    val value = hmacHex(groupSecret, "$deviceId:$bucket").take(outputBytes * 2)
                    put(value, deviceId)
                }
            }
        }
    }

    private fun hmacHex(secret: ByteArray, payload: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret, "HmacSHA256"))
        return mac.doFinal(payload.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }
}
