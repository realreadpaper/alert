package com.deviceguard

import com.deviceguard.features.pairing.GuardDeviceRole
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

class GuardAppStateTest {
    @Test
    fun createsInviteReceivesJoinRequestAndApprovesDevice() {
        val initial = GuardAppState.initial(nowEpochSeconds = 1_777_560_000L)

        assertEquals(GuardAppScreen.Home, initial.screen)
        assertEquals(listOf("本机 Android"), initial.homeUiState.deviceRows.map { it.name })

        val inviting = initial.startAddDevice(nowEpochSeconds = 1_777_560_010L)

        assertEquals(GuardAppScreen.AddDevice, inviting.screen)
        assertNotNull(inviting.activeInvite)
        assertEquals(9, inviting.activeInviteDisplayCode?.length)
        assertEquals('-', inviting.activeInviteDisplayCode?.get(4))
        assertNull(inviting.pendingJoinRequest)

        val requested = inviting.simulateIncomingJoinRequest(nowEpochSeconds = 1_777_560_020L)

        assertEquals(GuardAppScreen.AddDevice, requested.screen)
        assertEquals("新手机 Android", requested.pendingJoinRequest?.displayName)

        val approved = requested.approvePendingJoin(nowEpochSeconds = 1_777_560_030L)

        assertEquals(GuardAppScreen.Home, approved.screen)
        assertNull(approved.activeInvite)
        assertNull(approved.pendingJoinRequest)
        assertEquals(listOf("本机 Android", "新手机 Android"), approved.homeUiState.deviceRows.map { it.name })
        assertEquals(GuardDeviceRole.MEMBER, approved.group.devices.last().role)
    }

    @Test
    fun cancelingInviteReturnsHomeWithoutAddingDevice() {
        val initial = GuardAppState.initial(nowEpochSeconds = 1_777_560_000L)
        val canceled = initial
            .startAddDevice(nowEpochSeconds = 1_777_560_010L)
            .cancelAddDevice()

        assertEquals(GuardAppScreen.Home, canceled.screen)
        assertNull(canceled.activeInvite)
        assertEquals(listOf("本机 Android"), canceled.homeUiState.deviceRows.map { it.name })
    }

    @Test
    fun approvedMemberUsesLocalOnlyOnlineState() {
        val withMember = GuardAppState.initial(nowEpochSeconds = 1_777_560_000L)
            .startAddDevice(nowEpochSeconds = 1_777_560_010L)
            .simulateIncomingJoinRequest(nowEpochSeconds = 1_777_560_020L)
            .approvePendingJoin(nowEpochSeconds = 1_777_560_030L)

        assertEquals(listOf("在线", "在线"), withMember.homeUiState.deviceRows.map { it.stateText })
    }
}
