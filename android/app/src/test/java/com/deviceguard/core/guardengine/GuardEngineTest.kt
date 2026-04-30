package com.deviceguard.core.guardengine

import kotlin.test.Test
import kotlin.test.assertEquals

class GuardEngineTest {
    @Test
    fun evaluatesOutingModeTransitionsAndSilentMode() {
        val engine = GuardEngine()
        val now = 1_777_560_000L

        val online = engine.evaluate(
            observation = observation(lastBleSeenAt = now - 3),
            mode = GuardMode.OUTING,
            nowEpochSeconds = now
        )
        assertEquals(DeviceState.ONLINE, online.state)
        assertEquals(AlarmIntent.None, online.alarmIntent)

        val unstable = engine.evaluate(
            observation = observation(lastBleSeenAt = now - 8),
            mode = GuardMode.OUTING,
            nowEpochSeconds = now
        )
        assertEquals(DeviceState.UNSTABLE, unstable.state)

        val preAlert = engine.evaluate(
            observation = observation(lastBleSeenAt = now - 20),
            mode = GuardMode.OUTING,
            nowEpochSeconds = now
        )
        assertEquals(DeviceState.PRE_ALERT, preAlert.state)
        assertEquals(AlarmIntent.NotifyAndVibrate("device-a"), preAlert.alarmIntent)

        val alarming = engine.evaluate(
            observation = observation(lastBleSeenAt = now - 40),
            mode = GuardMode.OUTING,
            nowEpochSeconds = now
        )
        assertEquals(DeviceState.ALARMING, alarming.state)
        assertEquals(AlarmIntent.RingAndVibrate("device-a"), alarming.alarmIntent)

        val silent = engine.evaluate(
            observation = observation(lastBleSeenAt = now - 200),
            mode = GuardMode.SILENT,
            nowEpochSeconds = now
        )
        assertEquals(DeviceState.PRE_ALERT, silent.state)
        assertEquals(AlarmIntent.NotifyAndVibrate("device-a"), silent.alarmIntent)

        val paused = engine.evaluate(
            observation = observation(lastBleSeenAt = null, pausedUntil = now + 60),
            mode = GuardMode.OUTING,
            nowEpochSeconds = now
        )
        assertEquals(DeviceState.PAUSED, paused.state)
        assertEquals(AlarmIntent.None, paused.alarmIntent)
    }

    private fun observation(
        lastBleSeenAt: Long?,
        pausedUntil: Long? = null
    ) = DeviceObservation(
        deviceId = "device-a",
        lastBleSeenAtEpochSeconds = lastBleSeenAt,
        lastLanSeenAtEpochSeconds = null,
        hasReliableBleHit = lastBleSeenAt != null,
        permissionBlocked = false,
        lowPowerRisk = false,
        pausedUntilEpochSeconds = pausedUntil
    )
}
