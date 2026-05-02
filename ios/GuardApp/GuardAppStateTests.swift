import Foundation

func runGuardAppStateSelfTest() throws {
    let signer = LanHeartbeatSigner()
    let transport = InMemoryLanHeartbeatTransport()
    let state = GuardAppState(
        localDeviceId: "device-a",
        localDeviceName: "主力 iPhone",
        groupId: "test-group",
        groupSecret: Data("shared-secret-32-byte-material".utf8),
        signer: signer,
        transport: transport,
        now: { Date(timeIntervalSince1970: 1_777_560_000) }
    )

    assert(state.screen == .home)
    assert(state.deviceRows.count == 1)
    assert(state.deviceRows[0].id == "device-a")
    assert(state.deviceRows[0].stateText == "本机")
    assert(state.homeStatus.title == "待添加")
    assert(state.homeStatus.deviceCountText == "0")

    state.startAddDevice()
    assert(state.screen == .addDevice)
    assert(!state.activeInviteCode.isEmpty)
    assert(GuardQRCode.makeCIImage(from: state.activeInviteCode) != nil)

    state.cancelAddDevice()
    assert(state.screen == .home)
    assert(state.activeInviteCode.isEmpty)

    state.toggleGuarding()
    assert(!state.isGuarding)
    state.toggleGuarding()
    assert(state.isGuarding)
    let sentAfterRestart = transport.sentPayloads.count

    let message = signer.create(
        groupId: "test-group",
        groupSecret: Data("shared-secret-32-byte-material".utf8),
        deviceId: "device-b",
        deviceName: "备用 iPhone",
        mode: .indoor,
        timestamp: 1_777_560_000,
        nonce: "nonce-b"
    )
    try state.receiveHeartbeatData(signer.encode(message))

    assert(state.deviceRows.count == 2)
    assert(state.deviceRows.contains { $0.id == "device-b" && $0.stateText == "在线" })
    assert(state.homeStatus.title == "安全")
    assert(state.homeStatus.deviceCountText == "1")
    assert(transport.sentPayloads.count == sentAfterRestart)

    state.sendHeartbeat()
    assert(transport.sentPayloads.count == sentAfterRestart + 1)
}
