import Foundation
import CryptoKit

/// قفل التطبيق بكلمة مرور — تُخزَّن كـ SHA-256 مع Salt في Keychain.
@MainActor
final class AppLockManager: ObservableObject {
    @Published var isLocked: Bool = false

    var isConfigured: Bool {
        KeychainHelper.load(key: KeychainHelper.appLockKey) != nil
    }

    func lockIfNeeded(settings: AppSettings) {
        if settings.appLockEnabled && isConfigured {
            isLocked = true
        }
    }

    func setPassword(_ password: String) {
        let salt = UUID().uuidString
        KeychainHelper.save(password: salt + ":" + Self.hash(password + salt),
                            for: KeychainHelper.appLockKey)
    }

    func removePassword() {
        KeychainHelper.delete(key: KeychainHelper.appLockKey)
        isLocked = false
    }

    func unlock(with password: String) -> Bool {
        guard let stored = KeychainHelper.load(key: KeychainHelper.appLockKey) else { return true }
        let parts = stored.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return false }
        let (salt, digest) = (parts[0], parts[1])
        if Self.hash(password + salt) == digest {
            isLocked = false
            return true
        }
        return false
    }

    private static func hash(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
