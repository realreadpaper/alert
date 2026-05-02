package com.deviceguard.features.home

import com.deviceguard.core.guardengine.GuardMode
import com.deviceguard.design.GuardColors
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class HomeUiStateTest {
    @Test
    fun togglesGuardingAndUpdatesDeviceRows() {
        val initial = HomeUiState.initial()

        assertTrue(initial.isGuarding)
        assertEquals("停止看护", initial.primaryActionTitle)
        assertEquals("台设备正在本地看护", initial.statusDescription)
        assertEquals("在线", initial.deviceRows.first().stateText)

        val stopped = initial.toggleGuarding()

        assertFalse(stopped.isGuarding)
        assertEquals("开始看护", stopped.primaryActionTitle)
        assertEquals("开启后，将在设备离开时提醒你", stopped.statusDescription)
        assertEquals(listOf("已暂停", "已暂停", "已暂停"), stopped.deviceRows.map { it.stateText })
        assertEquals(GuardColors.Ink500, stopped.deviceRows.first().stateColor)

        val restarted = stopped.toggleGuarding()

        assertTrue(restarted.isGuarding)
        assertEquals("停止看护", restarted.primaryActionTitle)
        assertEquals(listOf("在线", "在线", "在线"), restarted.deviceRows.map { it.stateText })
        assertEquals(GuardColors.Safe, restarted.deviceRows.first().stateColor)
    }

    @Test
    fun selectingModesChangesActiveModeAndDescription() {
        val initial = HomeUiState.initial()

        val indoor = initial.selectMode(GuardMode.INDOOR)
        assertEquals(GuardMode.INDOOR, indoor.mode)
        assertEquals("室内模式", indoor.modeTitle)
        assertEquals("适合办公室和家中，减少误报。", indoor.modeHint)

        val silent = indoor.selectMode(GuardMode.SILENT)
        assertEquals(GuardMode.SILENT, silent.mode)
        assertEquals("静音模式", silent.modeTitle)
        assertEquals("只通知和震动，不主动响铃。", silent.modeHint)
    }
}
