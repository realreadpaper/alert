package com.deviceguard.core.localnetwork

import com.deviceguard.core.guardengine.GuardMode
import org.json.JSONObject
import java.security.MessageDigest
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlin.math.abs

data class LanHeartbeatMessage(
    val protocolVersion: Int,
    val groupHash: String,
    val deviceId: String,
    val deviceNameHash: String,
    val timestamp: Long,
    val nonce: String,
    val mode: GuardMode,
    val signature: String
)

class LanHeartbeatSigner {
    fun create(
        groupId: String,
        groupSecret: ByteArray,
        deviceId: String,
        deviceName: String,
        mode: GuardMode,
        timestamp: Long,
        nonce: String
    ): LanHeartbeatMessage {
        val groupHash = shortHash(groupId)
        val deviceNameHash = shortHash(deviceName)
        val payload = signingPayload(
            protocolVersion = PROTOCOL_VERSION,
            groupHash = groupHash,
            deviceId = deviceId,
            deviceNameHash = deviceNameHash,
            timestamp = timestamp,
            nonce = nonce,
            mode = mode
        )
        return LanHeartbeatMessage(
            protocolVersion = PROTOCOL_VERSION,
            groupHash = groupHash,
            deviceId = deviceId,
            deviceNameHash = deviceNameHash,
            timestamp = timestamp,
            nonce = nonce,
            mode = mode,
            signature = hmacHex(groupSecret, payload)
        )
    }

    fun encode(message: LanHeartbeatMessage): String {
        return JSONObject()
            .put("protocolVersion", message.protocolVersion)
            .put("groupHash", message.groupHash)
            .put("deviceId", message.deviceId)
            .put("deviceNameHash", message.deviceNameHash)
            .put("timestamp", message.timestamp)
            .put("nonce", message.nonce)
            .put("mode", message.mode.wireValue)
            .put("signature", message.signature)
            .toString()
    }

    fun decode(payload: String): LanHeartbeatMessage {
        val json = JSONObject(payload)
        return LanHeartbeatMessage(
            protocolVersion = json.getInt("protocolVersion"),
            groupHash = json.getString("groupHash"),
            deviceId = json.getString("deviceId"),
            deviceNameHash = json.getString("deviceNameHash"),
            timestamp = json.getLong("timestamp"),
            nonce = json.getString("nonce"),
            mode = GuardMode.fromWireValue(json.getString("mode")),
            signature = json.getString("signature")
        )
    }

    fun verify(
        message: LanHeartbeatMessage,
        groupSecret: ByteArray,
        now: Long,
        allowedSkewSeconds: Long = 30
    ): Boolean {
        if (message.protocolVersion != PROTOCOL_VERSION) return false
        if (abs(now - message.timestamp) > allowedSkewSeconds) return false
        val payload = signingPayload(
            protocolVersion = message.protocolVersion,
            groupHash = message.groupHash,
            deviceId = message.deviceId,
            deviceNameHash = message.deviceNameHash,
            timestamp = message.timestamp,
            nonce = message.nonce,
            mode = message.mode
        )
        return hmacHex(groupSecret, payload) == message.signature
    }

    private fun signingPayload(
        protocolVersion: Int,
        groupHash: String,
        deviceId: String,
        deviceNameHash: String,
        timestamp: Long,
        nonce: String,
        mode: GuardMode
    ): String = listOf(
        protocolVersion.toString(),
        groupHash,
        deviceId,
        deviceNameHash,
        timestamp.toString(),
        nonce,
        mode.wireValue
    ).joinToString("|")

    private fun shortHash(value: String): String {
        return MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
            .take(8)
            .joinToString("") { "%02x".format(it) }
    }

    private fun hmacHex(secret: ByteArray, payload: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret, "HmacSHA256"))
        return mac.doFinal(payload.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }

    private companion object {
        const val PROTOCOL_VERSION = 1
    }
}
