import Foundation
import UserNotifications

/// إشعارات النظام: مكالمة واردة، انتهاء مكالمة، فقد الاتصال، تسجيل الدخول.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private(set) var settings = AppSettings()

    func configure(with settings: AppSettings) {
        self.settings = settings
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func notifyIncomingCall(from caller: String) {
        guard settings.notifyOnIncomingCall else { return }
        post(title: "مكالمة واردة", body: "مكالمة من \(caller)", sound: true)
    }

    func notifyCallEnded(with number: String, duration: String) {
        guard settings.notifyOnCallEnded else { return }
        post(title: "انتهت المكالمة", body: "المكالمة مع \(number) — المدة \(duration)")
    }

    func notifyConnectionLost(account: String) {
        guard settings.notifyOnConnectionLost else { return }
        post(title: "انقطع الاتصال", body: "فُقد الاتصال بالحساب \(account)")
    }

    func notifyRegistered(account: String) {
        guard settings.notifyOnRegistration else { return }
        post(title: "تم تسجيل الدخول", body: "تم تسجيل الحساب \(account) بنجاح")
    }

    private func post(title: String, body: String, sound: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if sound { content.sound = .default }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
