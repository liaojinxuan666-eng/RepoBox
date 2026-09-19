import Foundation
import Security

enum Keychain {
    static func save(_ account: String, _ value: String) {
        let data = value.data(using: .utf8)!
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "RepoBox",
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    static func load(_ account: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "RepoBox",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        SecItemCopyMatching(q as CFDictionary, &out)
        guard let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func delete(_ account: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "RepoBox",
            kSecAttrAccount as String: account
        ]
        SecItemDelete(q as CFDictionary)
    }
}