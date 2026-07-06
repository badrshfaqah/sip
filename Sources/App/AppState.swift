import SwiftUI
import Combine
import ServiceManagement

/// الحالة العامة للتطبيق: تجمع كل الخدمات وتدير الإعدادات واللغة والثيم.
@MainActor
final class AppState: ObservableObject {
    let sip = SIPManager()
    let accountStore = AccountStore()
    let callHistory = CallHistoryStore()
    let contacts = ContactsStore()
    let appLock = AppLockManager()
    let updateChecker = UpdateChecker()

    @Published var settings: AppSettings {
        didSet {
            persistSettings()
            NotificationManager.shared.configure(with: settings)
            applyLaunchAtLogin()
        }
    }

    /// true عندما لا يوجد أي حساب مسجَّل — تُعرض شاشة تسجيل الدخول
    @Published var showLogin: Bool = false

    private let settingsURL = AppPaths.applicationSupport.appendingPathComponent("settings.json")

    init() {
        if let data = try? Data(contentsOf: settingsURL),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
        NotificationManager.shared.configure(with: settings)

        sip.onCallFinished = { [weak self] record in
            self?.callHistory.add(record)
        }

        showLogin = accountStore.accounts.isEmpty
        appLock.lockIfNeeded(settings: settings)
    }

    func startup() {
        sip.start()
        NotificationManager.shared.requestAuthorization()
        autoRegisterActiveAccount()
        if settings.checkForUpdates {
            Task { await updateChecker.check() }
        }
    }

    /// تسجيل الحساب النشط تلقائياً إن كانت كلمة مروره محفوظة
    func autoRegisterActiveAccount() {
        guard let account = accountStore.activeAccount,
              let password = accountStore.password(for: account) else { return }
        sip.register(account: account, password: password)
    }

    /// التبديل بين الحسابات
    func switchTo(account: SIPAccount) {
        accountStore.activeAccountID = account.id
        if let password = accountStore.password(for: account) {
            sip.register(account: account, password: password)
        } else {
            sip.unregister()
            showLogin = true
        }
    }

    /// تسجيل الخروج
    func logout() {
        sip.unregister()
        showLogin = true
    }

    /// المظهر المفروض حسب الثيم المختار
    var preferredColorScheme: ColorScheme? {
        switch settings.theme {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// اتجاه الواجهة حسب اللغة
    var layoutDirection: LayoutDirection {
        settings.language == .arabic ? .rightToLeft : .leftToRight
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: settingsURL, options: .atomic)
        }
    }

    private func applyLaunchAtLogin() {
        do {
            if settings.launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            LogStore.shared.log(.app, "تعذّر ضبط التشغيل مع بدء النظام: \(error)", level: .warning)
        }
    }
}
