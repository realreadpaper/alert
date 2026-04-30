import Foundation
import Security

struct LocalIdentity: Equatable {
    let deviceId: String
    let groupSecret: Data?
}

enum LocalIdentityError: Error, Equatable {
    case invalidStoredDeviceId
    case keychainUnhandledStatus(OSStatus)
}

protocol SecureIdentityStorage {
    func read(key: String) throws -> Data?
    func write(_ data: Data, key: String) throws
    func delete(key: String) throws
}

final class LocalIdentityStore {
    private enum Keys {
        static let deviceId = "deviceId"
        static let groupSecret = "groupSecret"
    }

    private let storage: SecureIdentityStorage
    private let idFactory: () -> String

    init(
        storage: SecureIdentityStorage,
        idFactory: @escaping () -> String = { UUID().uuidString }
    ) {
        self.storage = storage
        self.idFactory = idFactory
    }

    func loadOrCreateIdentity() throws -> LocalIdentity {
        let deviceId = try loadOrCreateDeviceId()
        let groupSecret = try storage.read(key: Keys.groupSecret)
        return LocalIdentity(deviceId: deviceId, groupSecret: groupSecret)
    }

    func saveGroupSecret(_ secret: Data) throws {
        try storage.write(secret, key: Keys.groupSecret)
    }

    func clear() throws {
        try storage.delete(key: Keys.deviceId)
        try storage.delete(key: Keys.groupSecret)
    }

    private func loadOrCreateDeviceId() throws -> String {
        if let stored = try storage.read(key: Keys.deviceId) {
            guard let value = String(data: stored, encoding: .utf8), !value.isEmpty else {
                throw LocalIdentityError.invalidStoredDeviceId
            }
            return value
        }

        let created = idFactory()
        try storage.write(Data(created.utf8), key: Keys.deviceId)
        return created
    }
}

final class KeychainIdentityStorage: SecureIdentityStorage {
    private let service: String

    init(service: String = "com.deviceguard.identity") {
        self.service = service
    }

    func read(key: String) throws -> Data? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw LocalIdentityError.keychainUnhandledStatus(status)
        }
        return item as? Data
    }

    func write(_ data: Data, key: String) throws {
        var query = baseQuery(key: key)
        let attributes = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw LocalIdentityError.keychainUnhandledStatus(updateStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw LocalIdentityError.keychainUnhandledStatus(addStatus)
        }
    }

    func delete(key: String) throws {
        let status = SecItemDelete(baseQuery(key: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw LocalIdentityError.keychainUnhandledStatus(status)
        }
    }

    private func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}

final class InMemoryIdentityStorage: SecureIdentityStorage {
    private var values: [String: Data] = [:]

    func read(key: String) throws -> Data? {
        values[key]
    }

    func write(_ data: Data, key: String) throws {
        values[key] = data
    }

    func delete(key: String) throws {
        values.removeValue(forKey: key)
    }
}
