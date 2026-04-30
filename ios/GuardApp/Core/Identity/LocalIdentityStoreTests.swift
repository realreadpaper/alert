import Foundation

func runLocalIdentityStoreSelfTest() throws {
    let storage = InMemoryIdentityStorage()
    var generatedIds = ["device-a", "device-b"]
    let store = LocalIdentityStore(storage: storage) {
        generatedIds.removeFirst()
    }

    let first = try store.loadOrCreateIdentity()
    assert(first.deviceId == "device-a")
    assert(first.groupSecret == nil)

    let second = try store.loadOrCreateIdentity()
    assert(second.deviceId == "device-a")

    let secret = Data("group-secret".utf8)
    try store.saveGroupSecret(secret)

    let withSecret = try store.loadOrCreateIdentity()
    assert(withSecret.groupSecret == secret)

    try store.clear()
    let afterClear = try store.loadOrCreateIdentity()
    assert(afterClear.deviceId == "device-b")
    assert(afterClear.groupSecret == nil)
}
