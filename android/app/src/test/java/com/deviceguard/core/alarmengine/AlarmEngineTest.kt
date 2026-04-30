package com.deviceguard.core.alarmengine

import com.deviceguard.core.guardengine.AlarmIntent
import com.deviceguard.core.guardengine.DeviceState
import com.deviceguard.core.guardengine.GuardDecision
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class AlarmEngineTest {
    @Test
    fun handlesPreAlertStrongAlarmAndPause() {
        val notifier = RecordingAlarmNotifier()
        val soundPlayer = InMemoryAlarmSoundPlayer()
        val engine = AlarmEngine(notifier, soundPlayer)
        val now = 1_777_560_000L

        val preAlert = GuardDecision(
            deviceId = "device-a",
            state = DeviceState.PRE_ALERT,
            alarmIntent = AlarmIntent.NotifyAndVibrate("device-a"),
            secondsSinceReliableSeen = 20
        )
        val preAlertAction = engine.handle(preAlert, "备用机", now)
        assertEquals(AlarmAction.Notify("device-a", "设备可能离开", "备用机 可能离开看护范围"), preAlertAction)
        assertFalse(soundPlayer.isRinging)

        val alarming = GuardDecision(
            deviceId = "device-a",
            state = DeviceState.ALARMING,
            alarmIntent = AlarmIntent.RingAndVibrate("device-a"),
            secondsSinceReliableSeen = 40
        )
        val alarmAction = engine.handle(alarming, "备用机", now)
        assertEquals(AlarmAction.Ring("device-a", "设备已离开看护范围", "备用机 仍未恢复连接"), alarmAction)
        assertTrue(soundPlayer.isRinging)

        val pauseAction = engine.pause("device-a", now, durationSeconds = 600)
        assertEquals(AlarmAction.Pause("device-a", now + 600), pauseAction)
        assertFalse(soundPlayer.isRinging)

        val suppressed = engine.handle(alarming, "备用机", now + 10)
        assertEquals(AlarmAction.None, suppressed)
    }
}
