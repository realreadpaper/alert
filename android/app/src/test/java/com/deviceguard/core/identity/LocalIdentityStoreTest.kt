package com.deviceguard.core.identity

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertNull

class LocalIdentityStoreTest {
    @Test
    fun loadOrCreateIdentityPersistsDeviceIdUntilClear() {
        val storage = InMemoryIdentityStorage()
        val ids = ArrayDeque(listOf("device-a", "device-b"))
        val store = LocalIdentityStore(storage = storage, idFactory = { ids.removeFirst() })

        val first = store.loadOrCreateIdentity()
        assertEquals("device-a", first.deviceId)
        assertNull(first.groupSecret)

        val second = store.loadOrCreateIdentity()
        assertEquals("device-a", second.deviceId)

        val secret = "group-secret".toByteArray()
        store.saveGroupSecret(secret)
        assertContentEquals(secret, store.loadOrCreateIdentity().groupSecret)

        store.clear()
        val afterClear = store.loadOrCreateIdentity()
        assertEquals("device-b", afterClear.deviceId)
        assertNull(afterClear.groupSecret)
    }
}
