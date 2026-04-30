import Foundation
import UserNotifications

final class RecordingNotifier: AlarmNotifying {
    private(set) var notifications: [(String, String, UNNotificationSound?)] = []

    func notify(title: String, body: String, sound: UNNotificationSound?) {
        notifications.append((title, body, sound))
    }
}

func runAlarmEngineSelfTest() {
    let notifier = RecordingNotifier()
    let soundPlayer = NoopAlarmSoundPlayer()
    let engine = AlarmEngine(notifier: notifier, soundPlayer: soundPlayer)
    let now = Date(timeIntervalSince1970: 1_777_560_000)

    let preAlert = GuardDecision(
        deviceId: "device-a",
        state: .preAlert,
        alarmIntent: .notifyAndVibrate(deviceId: "device-a"),
        secondsSinceReliableSeen: 20
    )
    let preAlertAction = engine.handle(decision: preAlert, deviceName: "备用机", now: now)
    assert(preAlertAction == .notify(deviceId: "device-a", title: "设备可能离开", body: "备用机 可能离开看护范围"))
    assert(!soundPlayer.isRinging)

    let alarming = GuardDecision(
        deviceId: "device-a",
        state: .alarming,
        alarmIntent: .ringAndVibrate(deviceId: "device-a"),
        secondsSinceReliableSeen: 40
    )
    let alarmAction = engine.handle(decision: alarming, deviceName: "备用机", now: now)
    assert(alarmAction == .ring(deviceId: "device-a", title: "设备已离开看护范围", body: "备用机 仍未恢复连接"))
    assert(soundPlayer.isRinging)

    let pauseAction = engine.pause(deviceId: "device-a", now: now, duration: 600)
    assert(pauseAction == .pause(deviceId: "device-a", until: now.addingTimeInterval(600)))
    assert(!soundPlayer.isRinging)

    let suppressed = engine.handle(decision: alarming, deviceName: "备用机", now: now.addingTimeInterval(10))
    assert(suppressed == .none)
}
