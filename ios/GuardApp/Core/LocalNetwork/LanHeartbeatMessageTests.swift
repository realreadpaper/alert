import Foundation

func runLocalHeartbeatSelfTest() throws {
    let secret = Data("shared-secret-32-byte-material".utf8)
    let signer = LanHeartbeatSigner()
    let message = signer.create(
        groupId: "group-1",
        groupSecret: secret,
        deviceId: "device-a",
        deviceName: "主力 iPhone",
        mode: .outing,
        timestamp: 1_777_560_000,
        nonce: "nonce-1"
    )

    assert(signer.verify(message, groupSecret: secret, now: 1_777_560_010))
    assert(!signer.verify(message, groupSecret: Data("wrong-secret".utf8), now: 1_777_560_010))
    assert(!signer.verify(message, groupSecret: secret, now: 1_777_560_100))

    let encoded = try signer.encode(message)
    let decoded = try signer.decode(encoded)
    assert(decoded == message)
}

func runRollingIdentifierSelfTest() {
    let generator = RollingIdentifierGenerator(bucketSeconds: 300, outputBytes: 8)
    let secret = Data("shared-secret-32-byte-material".utf8)
    let date = Date(timeIntervalSince1970: 1_777_560_010)

    let first = generator.generate(groupSecret: secret, deviceId: "device-a", date: date)
    let second = generator.generate(groupSecret: secret, deviceId: "device-a", date: date.addingTimeInterval(10))
    assert(first == second)

    let candidates = generator.candidates(groupSecret: secret, deviceIds: ["device-a", "device-b"], date: date)
    assert(candidates[first.value] == "device-a")
}
