import Foundation

func runGuardPairingServiceSelfTest() throws {
    var ids = ["group-1", "invite-1"]
    let service = GuardPairingService(
        idFactory: { ids.removeFirst() },
        tokenFactory: { "token-1" },
        secretFactory: { Data("secret-1".utf8) }
    )
    let now = Date(timeIntervalSince1970: 1_777_560_000)

    let (group, secret) = service.createGroup(
        ownerDeviceId: "owner-device",
        ownerDisplayName: "主力 iPhone",
        ownerPlatform: .iOS,
        now: now
    )
    assert(group.groupId == "group-1")
    assert(group.devices.count == 1)
    assert(secret == Data("secret-1".utf8))

    let invite = try service.createInvite(group: group, ownerDeviceId: "owner-device", now: now)
    assert(invite.inviteId == "invite-1")
    assert(invite.joinToken == "token-1")
    assert(invite.expiresAtEpochSeconds == 1_777_560_300)

    let payload = try service.encodeInviteForQRCode(invite)
    assert(payload.contains("\"type\":\"device_guard_pairing_invite\""))
    assert(payload.contains("\"expiresAtEpochSeconds\":1777560300"))
    let decoded = try service.decodeInviteFromQRCode(payload, now: now.addingTimeInterval(10))
    assert(decoded == invite)

    let canonicalPayload = """
    {"type":"device_guard_pairing_invite","protocolVersion":1,"inviteId":"invite-2","groupId":"group-2","ownerDeviceId":"owner-2","joinToken":"token-2","expiresAtEpochSeconds":1777560600}
    """
    let canonicalInvite = try service.decodeInviteFromQRCode(canonicalPayload, now: now)
    assert(canonicalInvite.inviteId == "invite-2")
    assert(canonicalInvite.expiresAtEpochSeconds == 1_777_560_600)

    let request = service.createJoinRequest(
        invite: decoded,
        deviceId: "member-device",
        displayName: "商务 Android",
        platform: .android,
        now: now.addingTimeInterval(20)
    )

    let approved = try service.approveJoin(
        request: request,
        invite: decoded,
        group: group,
        groupSecret: secret,
        now: now.addingTimeInterval(30)
    )
    assert(approved.group.devices.count == 2)
    assert(approved.group.devices.last?.role == .member)
    assert(approved.groupSecret == secret)
}
