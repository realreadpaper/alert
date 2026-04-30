package com.deviceguard.core.permissions

import com.deviceguard.core.guardengine.DeviceState

enum class GuardPermissionKind {
    BLUETOOTH,
    NOTIFICATION,
    LOCAL_NETWORK,
    FOREGROUND_SERVICE,
    BATTERY_OPTIMIZATION
}

enum class GuardPermissionStatus {
    GRANTED,
    DENIED,
    NOT_DETERMINED,
    RESTRICTED
}

data class GuardPermissionSnapshot(
    val bluetooth: GuardPermissionStatus,
    val notification: GuardPermissionStatus,
    val localNetwork: GuardPermissionStatus,
    val foregroundService: GuardPermissionStatus,
    val batteryOptimization: GuardPermissionStatus
)

data class PermissionIssue(
    val kind: GuardPermissionKind,
    val title: String,
    val message: String,
    val primaryActionTitle: String,
    val degradedState: DeviceState?
)

class PermissionGuide {
    fun mostImportantIssue(snapshot: GuardPermissionSnapshot): PermissionIssue? {
        if (snapshot.bluetooth != GuardPermissionStatus.GRANTED) {
            return PermissionIssue(
                kind = GuardPermissionKind.BLUETOOTH,
                title = "需要开启附近设备权限",
                message = "用于发现看护组内手机是否仍在身边。",
                primaryActionTitle = "去开启",
                degradedState = DeviceState.PERMISSION_LIMITED
            )
        }

        if (snapshot.notification != GuardPermissionStatus.GRANTED) {
            return PermissionIssue(
                kind = GuardPermissionKind.NOTIFICATION,
                title = "需要开启通知",
                message = "设备可能离开时，通知用于及时提醒你。",
                primaryActionTitle = "去开启",
                degradedState = null
            )
        }

        if (snapshot.foregroundService != GuardPermissionStatus.GRANTED) {
            return PermissionIssue(
                kind = GuardPermissionKind.FOREGROUND_SERVICE,
                title = "后台看护可能受限",
                message = "开启持续看护时，系统需要显示看护状态通知。",
                primaryActionTitle = "查看设置",
                degradedState = null
            )
        }

        if (snapshot.localNetwork != GuardPermissionStatus.GRANTED) {
            return PermissionIssue(
                kind = GuardPermissionKind.LOCAL_NETWORK,
                title = "建议允许本地网络",
                message = "同一 Wi-Fi 下可减少室内误报；不开启时仍可使用蓝牙看护。",
                primaryActionTitle = "去开启",
                degradedState = null
            )
        }

        if (snapshot.batteryOptimization != GuardPermissionStatus.GRANTED) {
            return PermissionIssue(
                kind = GuardPermissionKind.BATTERY_OPTIMIZATION,
                title = "后台看护可能被系统限制",
                message = "部分手机会限制后台运行，可在系统设置中允许持续看护。",
                primaryActionTitle = "查看设置",
                degradedState = null
            )
        }

        return null
    }

    fun canStartCoreGuarding(snapshot: GuardPermissionSnapshot): Boolean {
        return snapshot.bluetooth == GuardPermissionStatus.GRANTED
    }
}
