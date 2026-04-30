package com.deviceguard.core.alarmengine

import com.deviceguard.core.guardengine.AlarmIntent
import com.deviceguard.core.guardengine.GuardDecision

sealed interface AlarmAction {
    data object None : AlarmAction
    data class Notify(val deviceId: String, val title: String, val body: String) : AlarmAction
    data class Ring(val deviceId: String, val title: String, val body: String) : AlarmAction
    data class Stop(val deviceId: String) : AlarmAction
    data class Pause(val deviceId: String, val untilEpochSeconds: Long) : AlarmAction
}

interface AlarmNotifier {
    fun notify(title: String, body: String, channel: AlarmNotificationChannel)
}

interface AlarmSoundPlayer {
    fun startRinging()
    fun stopRinging()
}

enum class AlarmNotificationChannel {
    PRE_ALERT,
    STRONG_ALARM
}

class AlarmEngine(
    private val notifier: AlarmNotifier,
    private val soundPlayer: AlarmSoundPlayer
) {
    private val activeRingingDeviceIds = mutableSetOf<String>()
    private val pausedUntilByDeviceId = mutableMapOf<String, Long>()

    fun handle(decision: GuardDecision, deviceName: String, nowEpochSeconds: Long): AlarmAction {
        val pausedUntil = pausedUntilByDeviceId[decision.deviceId]
        if (pausedUntil != null && pausedUntil > nowEpochSeconds) {
            return AlarmAction.None
        }

        return when (decision.alarmIntent) {
            AlarmIntent.None -> {
                stopIfNeeded(decision.deviceId)
                AlarmAction.None
            }
            is AlarmIntent.NotifyAndVibrate -> {
                val title = "设备可能离开"
                val body = "$deviceName 可能离开看护范围"
                notifier.notify(title, body, AlarmNotificationChannel.PRE_ALERT)
                AlarmAction.Notify(decision.deviceId, title, body)
            }
            is AlarmIntent.RingAndVibrate -> {
                val title = "设备已离开看护范围"
                val body = "$deviceName 仍未恢复连接"
                notifier.notify(title, body, AlarmNotificationChannel.STRONG_ALARM)
                activeRingingDeviceIds += decision.deviceId
                soundPlayer.startRinging()
                AlarmAction.Ring(decision.deviceId, title, body)
            }
        }
    }

    fun acknowledge(deviceId: String): AlarmAction {
        pausedUntilByDeviceId.remove(deviceId)
        stopIfNeeded(deviceId)
        return AlarmAction.Stop(deviceId)
    }

    fun pause(deviceId: String, nowEpochSeconds: Long, durationSeconds: Long = 600): AlarmAction {
        val until = nowEpochSeconds + durationSeconds
        pausedUntilByDeviceId[deviceId] = until
        stopIfNeeded(deviceId)
        return AlarmAction.Pause(deviceId, until)
    }

    fun pausedUntil(deviceId: String): Long? = pausedUntilByDeviceId[deviceId]

    private fun stopIfNeeded(deviceId: String) {
        val removed = activeRingingDeviceIds.remove(deviceId)
        if (removed && activeRingingDeviceIds.isEmpty()) {
            soundPlayer.stopRinging()
        }
    }
}

class RecordingAlarmNotifier : AlarmNotifier {
    val notifications = mutableListOf<Triple<String, String, AlarmNotificationChannel>>()

    override fun notify(title: String, body: String, channel: AlarmNotificationChannel) {
        notifications += Triple(title, body, channel)
    }
}

class InMemoryAlarmSoundPlayer : AlarmSoundPlayer {
    var isRinging: Boolean = false
        private set

    override fun startRinging() {
        isRinging = true
    }

    override fun stopRinging() {
        isRinging = false
    }
}
