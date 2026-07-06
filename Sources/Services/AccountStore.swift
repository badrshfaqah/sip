import Foundation
import Combine

/// إدارة حسابات SIP المتعددة: حفظ، استيراد، تصدير، ونسخ الإعدادات.
/// تُخزَّن الحسابات (بدون كلمات المرور) في Application Support كملف JSON.
@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [SIPAccount] = []
    @Published var activeAccountID: UUID? {
        didSet { persist() }
    }

    var activeAccount: SIPAccount? {
        accounts.first { $0.id == activeAccountID } ?? accounts.first
    }

    private let fileURL: URL

    init() {
        let dir = AppPaths.applicationSupport
        fileURL = dir.appendingPathComponent("accounts.json")
        load()
    }

    // MARK: - CRUD

    func upsert(_ account: SIPAccount, password: String?) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        if let password, account.savePassword {
            KeychainHelper.save(password: password, for: KeychainHelper.sipPasswordKey(account.id))
        } else if !account.savePassword {
            KeychainHelper.delete(key: KeychainHelper.sipPasswordKey(account.id))
        }
        if activeAccountID == nil { activeAccountID = account.id }
        persist()
    }

    func remove(_ account: SIPAccount) {
        accounts.removeAll { $0.id == account.id }
        KeychainHelper.delete(key: KeychainHelper.sipPasswordKey(account.id))
        KeychainHelper.delete(key: KeychainHelper.proxyPasswordKey(account.id))
        KeychainHelper.delete(key: KeychainHelper.turnPasswordKey(account.id))
        if activeAccountID == account.id { activeAccountID = accounts.first?.id }
        persist()
    }

    /// نسخ إعدادات حساب إلى حساب جديد
    func duplicate(_ account: SIPAccount) {
        var copy = account
        copy.id = UUID()
        copy.accountName = account.accountName + " (نسخة)"
        copy.savePassword = false
        accounts.append(copy)
        persist()
    }

    func password(for account: SIPAccount) -> String? {
        KeychainHelper.load(key: KeychainHelper.sipPasswordKey(account.id))
    }

    // MARK: - استيراد / تصدير

    /// تصدير الإعدادات إلى JSON (بدون كلمات المرور)
    func exportAccounts(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(accounts)
        try data.write(to: url, options: .atomic)
    }

    /// استيراد الإعدادات من JSON — يضيف الحسابات بهوّيات جديدة لتفادي التعارض
    func importAccounts(from url: URL) throws {
        let data = try Data(contentsOf: url)
        var imported = try JSONDecoder().decode([SIPAccount].self, from: data)
        for i in imported.indices {
            imported[i].id = UUID()
            imported[i].savePassword = false
        }
        accounts.append(contentsOf: imported)
        persist()
    }

    /// إعادة تعيين كل الإعدادات
    func resetAll() {
        for account in accounts {
            KeychainHelper.delete(key: KeychainHelper.sipPasswordKey(account.id))
            KeychainHelper.delete(key: KeychainHelper.proxyPasswordKey(account.id))
            KeychainHelper.delete(key: KeychainHelper.turnPasswordKey(account.id))
        }
        accounts = []
        activeAccountID = nil
        persist()
    }

    // MARK: - التخزين

    private struct Snapshot: Codable {
        var accounts: [SIPAccount]
        var activeAccountID: UUID?
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        accounts = snapshot.accounts
        activeAccountID = snapshot.activeAccountID
    }

    private func persist() {
        let snapshot = Snapshot(accounts: accounts, activeAccountID: activeAccountID)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

/// مسارات التخزين الموحّدة للتطبيق
enum AppPaths {
    static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("DeveloperSoftPhone", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var recordings: URL {
        let dir = applicationSupport.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
