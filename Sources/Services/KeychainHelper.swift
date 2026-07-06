import Foundation
import Security

/// تخزين آمن لكلمات المرور في Keychain الخاص بـ macOS.
/// لا تُكتب أي كلمة مرور على القرص بشكل نصّي أبداً.
enum KeychainHelper {
    private static let service = "com.badrs.softphone"

    @discardableResult
    static func save(password: String, for key: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    // مفاتيح قياسية لكل حساب
    static func sipPasswordKey(_ id: UUID) -> String { "sip-password-\(id.uuidString)" }
    static func proxyPasswordKey(_ id: UUID) -> String { "proxy-password-\(id.uuidString)" }
    static func turnPasswordKey(_ id: UUID) -> String { "turn-password-\(id.uuidString)" }
    static let appLockKey = "app-lock-password"
}
