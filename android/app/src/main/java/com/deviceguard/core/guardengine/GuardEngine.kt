package com.deviceguard.core.guardengine

enum class GuardMode(val wireValue: String) {
    OUTING("outing"),
    INDOOR("indoor"),
    SILENT("silent");

    companion object {
        fun fromWireValue(value: String): GuardMode = entries.firstOrNull { it.wireValue == value }
            ?: throw IllegalArgumentException("Unsupported guard mode: $value")
    }
}

enum class DeviceState {
    ONLINE,
    UNSTABLE,
    PRE_ALERT,
    ALARMING,
    PAUSED,
    PERMISSION_LIMITED,
    LOW_POWER_RISK
}

sealed interface AlarmIntent {
    data object None : AlarmIntent
    data class NotifyAndVibrate(val deviceId: String) : AlarmIntent
    data class RingAndVibrate(val deviceId: String) : AlarmIntent
}

data class GuardModeConfig(
    val unstableAfterSeconds: Long,
    val preAlertAfterSeconds: Long,
    val strongAlertAfterSeconds: Long,
    val allowsRinging: Boolean
) {
    companion object {
        fun forMode(mode: GuardMode): GuardModeConfig = when (mode) {
            GuardMode.OUTING -> GuardModeConfig(
                unstableAfterSeconds = 6,
                preAlertAfterSeconds = 15,
                strongAlertAfterSeconds = 30,
                allowsRinging = true
            )
            GuardMode.INDOOR -> GuardModeConfig(
                unstableAfterSeconds = 20,
                preAlertAfterSeconds = 50,
                strongAlertAfterSeconds = 100,
                allowsRinging = true
            )
            GuardMode.SILENT -> GuardModeConfig(
                unstableAfterSeconds = 20,
                preAlertAfterSeconds = 50,
                strongAlertAfterSeconds = 100,
                allowsRinging = false
            )
        }
    }
}

data class DeviceObservation(
    val deviceId: String,
    val lastBleSeenAtEpochSeconds: Long?,
    val lastLanSeenAtEpochSeconds: Long?,
    val hasReliableBleHit: Boolean,
    val permissionBlocked: Boolean,
    val lowPowerRisk: Boolean,
    val pausedUntilEpochSeconds: Long?
) {
    val lastReliableSeenAtEpochSeconds: Long?
        get() = listOfNotNull(
            if (hasReliableBleHit) lastBleSeenAtEpochSeconds else null,
            lastLanSeenAtEpochSeconds
        ).maxOrNull()
}

data class GuardDecision(
    val deviceId: String,
    val state: DeviceState,
    val alarmIntent: AlarmIntent,
    val secondsSinceReliableSeen: Long?
)

class GuardEngine {
    fun evaluate(
        observation: DeviceObservation,
        mode: GuardMode,
        nowEpochSeconds: Long
    ): GuardDecision {
        val elapsed = observation.lastReliableSeenAtEpochSeconds?.let { nowEpochSeconds - it }

        if (observation.pausedUntilEpochSeconds != null && observation.pausedUntilEpochSeconds > nowEpochSeconds) {
            return GuardDecision(observation.deviceId, DeviceState.PAUSED, AlarmIntent.None, elapsed)
        }

        if (observation.permissionBlocked) {
            return GuardDecision(observation.deviceId, DeviceState.PERMISSION_LIMITED, AlarmIntent.None, elapsed)
        }

        if (observation.lowPowerRisk) {
            return GuardDecision(observation.deviceId, DeviceState.LOW_POWER_RISK, AlarmIntent.None, elapsed)
        }

        return missingDecision(
            deviceId = observation.deviceId,
            elapsedSeconds = elapsed ?: Long.MAX_VALUE,
            mode = mode
        )
    }

    private fun missingDecision(
        deviceId: String,
        elapsedSeconds: Long,
        mode: GuardMode
    ): GuardDecision {
        val config = GuardModeConfig.forMode(mode)
        return when {
            elapsedSeconds < config.unstableAfterSeconds -> GuardDecision(
                deviceId = deviceId,
                state = DeviceState.ONLINE,
                alarmIntent = AlarmIntent.None,
                secondsSinceReliableSeen = elapsedSeconds
            )
            elapsedSeconds < config.preAlertAfterSeconds -> GuardDecision(
                deviceId = deviceId,
                state = DeviceState.UNSTABLE,
                alarmIntent = AlarmIntent.None,
                secondsSinceReliableSeen = elapsedSeconds
            )
            elapsedSeconds < config.strongAlertAfterSeconds || !config.allowsRinging -> GuardDecision(
                deviceId = deviceId,
                state = DeviceState.PRE_ALERT,
                alarmIntent = AlarmIntent.NotifyAndVibrate(deviceId),
                secondsSinceReliableSeen = elapsedSeconds
            )
            else -> GuardDecision(
                deviceId = deviceId,
                state = DeviceState.ALARMING,
                alarmIntent = AlarmIntent.RingAndVibrate(deviceId),
                secondsSinceReliableSeen = elapsedSeconds
            )
        }
    }
}
