package com.deviceguard.core.permissions

import com.deviceguard.core.guardengine.DeviceState
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PermissionGuideTest {
    @Test
    fun prioritizesBluetoothAndAllowsLocalNetworkDegradation() {
        val guide = PermissionGuide()

        val blocked = GuardPermissionSnapshot(
            bluetooth = GuardPermissionStatus.DENIED,
            notification = GuardPermissionStatus.GRANTED,
            localNetwork = GuardPermissionStatus.GRANTED,
            foregroundService = GuardPermissionStatus.GRANTED,
            batteryOptimization = GuardPermissionStatus.GRANTED
        )
        val issue = guide.mostImportantIssue(blocked)
        assertEquals(GuardPermissionKind.BLUETOOTH, issue?.kind)
        assertEquals(DeviceState.PERMISSION_LIMITED, issue?.degradedState)
        assertFalse(guide.canStartCoreGuarding(blocked))

        val localNetworkOnly = GuardPermissionSnapshot(
            bluetooth = GuardPermissionStatus.GRANTED,
            notification = GuardPermissionStatus.GRANTED,
            localNetwork = GuardPermissionStatus.DENIED,
            foregroundService = GuardPermissionStatus.GRANTED,
            batteryOptimization = GuardPermissionStatus.GRANTED
        )
        assertEquals(GuardPermissionKind.LOCAL_NETWORK, guide.mostImportantIssue(localNetworkOnly)?.kind)
        assertTrue(guide.canStartCoreGuarding(localNetworkOnly))
    }
}
