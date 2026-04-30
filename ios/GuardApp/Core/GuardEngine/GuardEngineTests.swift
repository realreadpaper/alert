import Foundation

func runGuardEngineSelfTest() {
    let engine = GuardEngine()
    let now = Date(timeIntervalSince1970: 1_777_560_000)

    let online = engine.evaluate(
        observation: DeviceObservation(
            deviceId: "device-a",
            lastBleSeenAt: now.addingTimeInterval(-3),
            lastLanSeenAt: nil,
            hasReliableBleHit: true,
            permissionBlocked: false,
            lowPowerRisk: false,
            pausedUntil: nil
        ),
        mode: .outing,
        now: now
    )
    assert(online.state == .online)
    assert(online.alarmIntent == .none)

    let unstable = engine.evaluate(
        observation: DeviceObservation(
            deviceId: "device-a",
            lastBleSeenAt: now.addingTimeInterval(-8),
            lastLanSeenAt: nil,
            hasReliableBleHit: true,
            permissionBlocked: false,
            lowPowerRisk: false,
            pausedUntil: nil
        ),
        mode: .outing,
        now: now
    )
    assert(unstable.state == .unstable)

    let preAlert = engine.evaluate(
        observation: DeviceObservation(
            deviceId: "device-a",
            lastBleSeenAt: now.addingTimeInterval(-20),
            lastLanSeenAt: nil,
            hasReliableBleHit: true,
            permissionBlocked: false,
            lowPowerRisk: false,
            pausedUntil: nil
        ),
        mode: .outing,
        now: now
    )
    assert(preAlert.state == .preAlert)
    assert(preAlert.alarmIntent == .notifyAndVibrate(deviceId: "device-a"))

    let alarming = engine.evaluate(
        observation: DeviceObservation(
            deviceId: "device-a",
            lastBleSeenAt: now.addingTimeInterval(-40),
            lastLanSeenAt: nil,
            hasReliableBleHit: true,
            permissionBlocked: false,
            lowPowerRisk: false,
            pausedUntil: nil
        ),
        mode: .outing,
        now: now
    )
    assert(alarming.state == .alarming)
    assert(alarming.alarmIntent == .ringAndVibrate(deviceId: "device-a"))

    let silent = engine.evaluate(
        observation: DeviceObservation(
            deviceId: "device-a",
            lastBleSeenAt: now.addingTimeInterval(-200),
            lastLanSeenAt: nil,
            hasReliableBleHit: true,
            permissionBlocked: false,
            lowPowerRisk: false,
            pausedUntil: nil
        ),
        mode: .silent,
        now: now
    )
    assert(silent.state == .preAlert)
    assert(silent.alarmIntent == .notifyAndVibrate(deviceId: "device-a"))

    let paused = engine.evaluate(
        observation: DeviceObservation(
            deviceId: "device-a",
            lastBleSeenAt: nil,
            lastLanSeenAt: nil,
            hasReliableBleHit: false,
            permissionBlocked: false,
            lowPowerRisk: false,
            pausedUntil: now.addingTimeInterval(60)
        ),
        mode: .outing,
        now: now
    )
    assert(paused.state == .paused)
    assert(paused.alarmIntent == .none)
}
