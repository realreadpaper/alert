import Foundation

enum DeviceState: String, Equatable {
    case online
    case unstable
    case preAlert
    case alarming
    case paused
    case permissionLimited
    case lowPowerRisk
}

enum AlarmIntent: Equatable {
    case none
    case notifyAndVibrate(deviceId: String)
    case ringAndVibrate(deviceId: String)
}

struct GuardModeConfig: Equatable {
    let unstableAfter: TimeInterval
    let preAlertAfter: TimeInterval
    let strongAlertAfter: TimeInterval
    let allowsRinging: Bool

    static func config(for mode: GuardMode) -> GuardModeConfig {
        switch mode {
        case .outing:
            GuardModeConfig(unstableAfter: 6, preAlertAfter: 15, strongAlertAfter: 30, allowsRinging: true)
        case .indoor:
            GuardModeConfig(unstableAfter: 20, preAlertAfter: 50, strongAlertAfter: 100, allowsRinging: true)
        case .silent:
            GuardModeConfig(unstableAfter: 20, preAlertAfter: 50, strongAlertAfter: 100, allowsRinging: false)
        }
    }
}

struct DeviceObservation: Equatable {
    let deviceId: String
    let lastBleSeenAt: Date?
    let lastLanSeenAt: Date?
    let hasReliableBleHit: Bool
    let permissionBlocked: Bool
    let lowPowerRisk: Bool
    let pausedUntil: Date?

    var lastReliableSeenAt: Date? {
        let bleSeen = hasReliableBleHit ? lastBleSeenAt : nil
        return [bleSeen, lastLanSeenAt].compactMap { $0 }.max()
    }
}

struct GuardDecision: Equatable {
    let deviceId: String
    let state: DeviceState
    let alarmIntent: AlarmIntent
    let secondsSinceReliableSeen: TimeInterval?
}

final class GuardEngine {
    func evaluate(observation: DeviceObservation, mode: GuardMode, now: Date) -> GuardDecision {
        if let pausedUntil = observation.pausedUntil, pausedUntil > now {
            return GuardDecision(
                deviceId: observation.deviceId,
                state: .paused,
                alarmIntent: .none,
                secondsSinceReliableSeen: secondsSince(observation.lastReliableSeenAt, now: now)
            )
        }

        if observation.permissionBlocked {
            return GuardDecision(
                deviceId: observation.deviceId,
                state: .permissionLimited,
                alarmIntent: .none,
                secondsSinceReliableSeen: secondsSince(observation.lastReliableSeenAt, now: now)
            )
        }

        if observation.lowPowerRisk {
            return GuardDecision(
                deviceId: observation.deviceId,
                state: .lowPowerRisk,
                alarmIntent: .none,
                secondsSinceReliableSeen: secondsSince(observation.lastReliableSeenAt, now: now)
            )
        }

        guard let lastSeen = observation.lastReliableSeenAt else {
            return missingDecision(deviceId: observation.deviceId, elapsed: .infinity, mode: mode)
        }

        let elapsed = now.timeIntervalSince(lastSeen)
        return missingDecision(deviceId: observation.deviceId, elapsed: elapsed, mode: mode)
    }

    private func missingDecision(deviceId: String, elapsed: TimeInterval, mode: GuardMode) -> GuardDecision {
        let config = GuardModeConfig.config(for: mode)
        if elapsed < config.unstableAfter {
            return GuardDecision(deviceId: deviceId, state: .online, alarmIntent: .none, secondsSinceReliableSeen: elapsed)
        }
        if elapsed < config.preAlertAfter {
            return GuardDecision(deviceId: deviceId, state: .unstable, alarmIntent: .none, secondsSinceReliableSeen: elapsed)
        }
        if elapsed < config.strongAlertAfter || !config.allowsRinging {
            return GuardDecision(
                deviceId: deviceId,
                state: .preAlert,
                alarmIntent: .notifyAndVibrate(deviceId: deviceId),
                secondsSinceReliableSeen: elapsed
            )
        }
        return GuardDecision(
            deviceId: deviceId,
            state: .alarming,
            alarmIntent: .ringAndVibrate(deviceId: deviceId),
            secondsSinceReliableSeen: elapsed
        )
    }

    private func secondsSince(_ date: Date?, now: Date) -> TimeInterval? {
        date.map { now.timeIntervalSince($0) }
    }
}
