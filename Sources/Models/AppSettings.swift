import Foundation

/// لغة الواجهة
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case arabic  = "ar"
    case english = "en"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .arabic:  return "العربية"
        case .english: return "English"
        }
    }
}

/// ثيم التطبيق
enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .system: return "تلقائي (النظام)"
        case .light:  return "فاتح"
        case .dark:   return "داكن"
        }
    }
}

/// إعدادات التطبيق العامة
struct AppSettings: Codable, Equatable {
    var language: AppLanguage = .arabic
    var theme: AppTheme = .system

    // — السلوك —
    var launchAtLogin: Bool = false        // التشغيل مع بدء macOS
    var runInBackground: Bool = true       // تشغيل في الخلفية
    var closeToMenuBar: Bool = true        // إغلاق إلى شريط النظام
    var checkForUpdates: Bool = true       // التحقق من التحديثات

    // — الإشعارات —
    var notifyOnIncomingCall: Bool = true  // إشعار عند الاتصال
    var notifyOnCallEnded: Bool = true     // إشعار عند انتهاء المكالمة
    var notifyOnConnectionLost: Bool = true// إشعار عند فقد الاتصال
    var notifyOnRegistration: Bool = true  // إشعار عند تسجيل الدخول

    // — الأمان —
    var appLockEnabled: Bool = false       // قفل البرنامج بكلمة مرور
}
