package com.deviceguard.core.identity

import java.security.SecureRandom
import java.util.UUID

data class LocalIdentity(
    val deviceId: String,
    val groupSecret: ByteArray?
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is LocalIdentity) return false
        return deviceId == other.deviceId && groupSecret.contentEquals(other.groupSecret)
    }

    override fun hashCode(): Int {
        var result = deviceId.hashCode()
        result = 31 * result + (groupSecret?.contentHashCode() ?: 0)
        return result
    }
}

interface SecureIdentityStorage {
    fun read(key: String): ByteArray?
    fun write(key: String, value: ByteArray)
    fun delete(key: String)
}

class LocalIdentityStore(
    private val storage: SecureIdentityStorage,
    private val idFactory: () -> String = { UUID.randomUUID().toString() },
    private val secretFactory: (Int) -> ByteArray = { size ->
        ByteArray(size).also { SecureRandom().nextBytes(it) }
    }
) {
    fun loadOrCreateIdentity(): LocalIdentity {
        val deviceId = loadOrCreateDeviceId()
        return LocalIdentity(
            deviceId = deviceId,
            groupSecret = storage.read(KEY_GROUP_SECRET)
        )
    }

    fun saveGroupSecret(secret: ByteArray) {
        require(secret.isNotEmpty()) { "groupSecret must not be empty" }
        storage.write(KEY_GROUP_SECRET, secret.copyOf())
    }

    fun createGroupSecret(size: Int = DEFAULT_GROUP_SECRET_SIZE): ByteArray {
        require(size >= MIN_GROUP_SECRET_SIZE) { "groupSecret must be at least $MIN_GROUP_SECRET_SIZE bytes" }
        return secretFactory(size)
    }

    fun clear() {
        storage.delete(KEY_DEVICE_ID)
        storage.delete(KEY_GROUP_SECRET)
    }

    private fun loadOrCreateDeviceId(): String {
        val stored = storage.read(KEY_DEVICE_ID)
            ?.toString(Charsets.UTF_8)
            ?.takeIf { it.isNotBlank() }
        if (stored != null) return stored

        val created = idFactory()
        storage.write(KEY_DEVICE_ID, created.toByteArray(Charsets.UTF_8))
        return created
    }

    companion object {
        private const val KEY_DEVICE_ID = "deviceId"
        private const val KEY_GROUP_SECRET = "groupSecret"
        private const val DEFAULT_GROUP_SECRET_SIZE = 32
        private const val MIN_GROUP_SECRET_SIZE = 16
    }
}

class InMemoryIdentityStorage : SecureIdentityStorage {
    private val values = mutableMapOf<String, ByteArray>()

    override fun read(key: String): ByteArray? = values[key]?.copyOf()

    override fun write(key: String, value: ByteArray) {
        values[key] = value.copyOf()
    }

    override fun delete(key: String) {
        values.remove(key)
    }
}
