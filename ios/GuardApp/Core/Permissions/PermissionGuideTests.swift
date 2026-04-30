func runPermissionGuideSelfTest() {
    let guide = PermissionGuide()

    let blocked = GuardPermissionSnapshot(
        bluetooth: .denied,
        notification: .granted,
        localNetwork: .granted,
        backgroundRefresh: .granted
    )
    let issue = guide.mostImportantIssue(from: blocked)
    assert(issue?.kind == .bluetooth)
    assert(issue?.degradedState == .permissionLimited)
    assert(!guide.canStartCoreGuarding(snapshot: blocked))

    let localNetworkOnly = GuardPermissionSnapshot(
        bluetooth: .granted,
        notification: .granted,
        localNetwork: .denied,
        backgroundRefresh: .granted
    )
    assert(guide.mostImportantIssue(from: localNetworkOnly)?.kind == .localNetwork)
    assert(guide.canStartCoreGuarding(snapshot: localNetworkOnly))
}
