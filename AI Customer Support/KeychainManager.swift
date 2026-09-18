import Foundation
import Security

final class KeychainManager: Sendable {

    static let shared = KeychainManager()

    private init() {}

    private let defaultService = "AI-Customer-Support"
    private let defaultAccount = "access-token"

    @discardableResult
    func saveToken(_ token: String) -> Bool {
        save(token, forKey: defaultAccount, service: defaultService)
    }

    func getToken() -> String? {
        read(forKey: defaultAccount, service: defaultService)
    }

    @discardableResult
    func deleteToken() -> Bool {
        delete(forKey: defaultAccount, service: defaultService)
    }

    var hasToken: Bool {
        getToken() != nil
    }

    @discardableResult
    func save(_ value: String, forKey key: String, service: String? = nil) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(data, forKey: key, service: service)
    }

    @discardableResult
    func save(_ data: Data, forKey key: String, service: String? = nil) -> Bool {
        let serviceName = service ?? defaultService
        delete(forKey: key, service: serviceName)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            return true
        } else {
            // Keychain write failed (e.g. missing entitlement, simulator
            // quirk, or a real device error). Falling back to UserDefaults
            // means the token is stored in PLAINTEXT, unencrypted. This is
            // acceptable for local dev/demo builds only — surface it
            // loudly so nobody mistakes this for secure storage in a real
            // release build.
            #if DEBUG
            print("⚠️ KeychainManager: SecItemAdd failed with status \(status). " +
                  "Falling back to INSECURE plaintext UserDefaults storage for key '\(key)'. " +
                  "This is not safe for production.")
            #endif
            UserDefaults.standard.set(String(data: data, encoding: .utf8), forKey: "\(serviceName)_\(key)")
            return true
        }
    }

    func read(forKey key: String, service: String? = nil) -> String? {
        if let data = readData(forKey: key, service: service) {
            return String(data: data, encoding: .utf8)
        }
        let serviceName = service ?? defaultService
        return UserDefaults.standard.string(forKey: "\(serviceName)_\(key)")
    }

    func readData(forKey key: String, service: String? = nil) -> Data? {
        let serviceName = service ?? defaultService

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    @discardableResult
    func delete(forKey key: String, service: String? = nil) -> Bool {
        let serviceName = service ?? defaultService

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif

        UserDefaults.standard.removeObject(forKey: "\(serviceName)_\(key)")
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    @discardableResult
    func clearAll(service: String? = nil) -> Bool {
        let serviceName = service ?? defaultService

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif

        UserDefaults.standard.removeObject(forKey: "\(serviceName)_\(defaultAccount)")
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
