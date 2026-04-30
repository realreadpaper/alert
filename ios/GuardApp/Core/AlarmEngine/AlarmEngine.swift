import Foundation
import UserNotifications

enum AlarmAction: Equatable {
    case none
    case notify(deviceId: String, title: String, body: String)
    case ring(deviceId: String, title: String, body: String)
    case stop(deviceId: String)
    case pause(deviceId: String, until: Date)
}

protocol AlarmNotifying {
    func notify(title: String, body: String, sound: UNNotificationSound?)
}

protocol AlarmSoundPlaying {
    func startRinging()
    func stopRinging()
}

final class AlarmEngine {
    private let notifier: AlarmNotifying
    private let soundPlayer: AlarmSoundPlaying
    private var activeRingingDeviceIds: Set<String> = []
    private var pausedUntilByDeviceId: [String: Date] = [:]

    init(notifier: AlarmNotifying, soundPlayer: AlarmSoundPlaying) {
        self.notifier = notifier
        self.soundPlayer = soundPlayer
    }

    func handle(decision: GuardDecision, deviceName: String, now: Date) -> AlarmAction {
        if let pausedUntil = pausedUntilByDeviceId[decision.deviceId], pausedUntil > now {
            return .none
        }

        switch decision.alarmIntent {
        case .none:
            stopIfNeeded(deviceId: decision.deviceId)
            return .none
        case .notifyAndVibrate:
            let title = "设备可能离开"
            let body = "\(deviceName) 可能离开看护范围"
            notifier.notify(title: title, body: body, sound: .default)
            return .notify(deviceId: decision.deviceId, title: title, body: body)
        case .ringAndVibrate:
            let title = "设备已离开看护范围"
            let body = "\(deviceName) 仍未恢复连接"
            notifier.notify(title: title, body: body, sound: .defaultCritical)
            activeRingingDeviceIds.insert(decision.deviceId)
            soundPlayer.startRinging()
            return .ring(deviceId: decision.deviceId, title: title, body: body)
        }
    }

    func acknowledge(deviceId: String) -> AlarmAction {
        pausedUntilByDeviceId.removeValue(forKey: deviceId)
        stopIfNeeded(deviceId: deviceId)
        return .stop(deviceId: deviceId)
    }

    func pause(deviceId: String, now: Date, duration: TimeInterval = 600) -> AlarmAction {
        let until = now.addingTimeInterval(duration)
        pausedUntilByDeviceId[deviceId] = until
        stopIfNeeded(deviceId: deviceId)
        return .pause(deviceId: deviceId, until: until)
    }

    func pausedUntil(deviceId: String) -> Date? {
        pausedUntilByDeviceId[deviceId]
    }

    private func stopIfNeeded(deviceId: String) {
        guard activeRingingDeviceIds.remove(deviceId) != nil else { return }
        if activeRingingDeviceIds.isEmpty {
            soundPlayer.stopRinging()
        }
    }
}

final class LocalNotificationAdapter: AlarmNotifying {
    func notify(title: String, body: String, sound: UNNotificationSound?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

final class NoopAlarmSoundPlayer: AlarmSoundPlaying {
    private(set) var isRinging = false

    func startRinging() {
        isRinging = true
    }

    func stopRinging() {
        isRinging = false
    }
}
