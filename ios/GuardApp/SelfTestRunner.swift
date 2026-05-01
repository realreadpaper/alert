#if SELF_TEST
@main
struct GuardSelfTestRunner {
    static func main() throws {
        try runLocalIdentityStoreSelfTest()
        runAlarmEngineSelfTest()
        runPermissionGuideSelfTest()
        try runLocalHeartbeatSelfTest()
        runRollingIdentifierSelfTest()
        runGuardEngineSelfTest()
        try runGuardPairingServiceSelfTest()
    }
}
#endif
