package com.deviceguard.features.home

import com.deviceguard.core.guardengine.GuardMode
import com.deviceguard.design.GuardColors

data class HomeUiState(
    val mode: GuardMode,
    val isGuarding: Boolean,
    private val devices: List<HomeDevice>
) {
    val primaryActionTitle: String
        get() = if (isGuarding) "停止看护" else "开始看护"

    val statusTitle: String
        get() = if (isGuarding) "安全" else "未开启"

    val statusDescription: String
        get() = if (isGuarding) "台设备正在本地看护" else "开启后，将在设备离开时提醒你"

    val modeTitle: String
        get() = when (mode) {
            GuardMode.OUTING -> "外出模式"
            GuardMode.INDOOR -> "室内模式"
            GuardMode.SILENT -> "静音模式"
        }

    val modeHint: String
        get() = when (mode) {
            GuardMode.OUTING -> "适合出门和商务场合，提醒更及时。"
            GuardMode.INDOOR -> "适合办公室和家中，减少误报。"
            GuardMode.SILENT -> "只通知和震动，不主动响铃。"
        }

    val deviceRows: List<HomeDeviceRow>
        get() = devices.map { device ->
            if (isGuarding) {
                HomeDeviceRow(device.id, device.name, device.guardingStateText, device.guardingStateColor)
            } else {
                HomeDeviceRow(device.id, device.name, "已暂停", GuardColors.Ink500)
            }
        }

    fun toggleGuarding(): HomeUiState = copy(isGuarding = !isGuarding)

    fun selectMode(mode: GuardMode): HomeUiState = copy(mode = mode)

    companion object {
        fun initial(): HomeUiState = HomeUiState(
            mode = GuardMode.OUTING,
            isGuarding = true,
            devices = defaultDevices
        )

        fun from(mode: GuardMode, isGuarding: Boolean): HomeUiState = HomeUiState(
            mode = mode,
            isGuarding = isGuarding,
            devices = defaultDevices
        )

        fun fromDevices(
            mode: GuardMode,
            isGuarding: Boolean,
            devices: List<HomeDevice>
        ): HomeUiState = HomeUiState(
            mode = mode,
            isGuarding = isGuarding,
            devices = devices
        )

        private val defaultDevices = listOf(
            HomeDevice("iphone", "主力 iPhone"),
            HomeDevice("android", "商务 Android"),
            HomeDevice("backup", "备用机")
        )
    }
}

data class HomeDevice(
    val id: String,
    val name: String,
    val guardingStateText: String = "在线",
    val guardingStateColor: androidx.compose.ui.graphics.Color = GuardColors.Safe
)
