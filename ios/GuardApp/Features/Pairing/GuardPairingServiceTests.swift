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

    let payload = try service.encodeInviteForQRCode(invite)
    let decoded = try service.decodeInviteFromQRCode(payload, now: now.addingTimeInterval(10))
    assert(decoded == invite)

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
