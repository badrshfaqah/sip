import SwiftUI
import AppKit

@main
struct DeveloperSoftPhoneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        // نافذة مدمجة صغيرة بحجم سماعة هاتف — تعمل بجانب البرامج الأخرى ولا تشغل الشاشة
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environment(\.layoutDirection, appState.layoutDirection)
                .preferredColorScheme(appState.preferredColorScheme)
                .frame(minWidth: 360, idealWidth: 380, maxWidth: 480,
                       minHeight: 560, idealHeight: 660, maxHeight: 860)
                .onAppear {
                    appDelegate.appState = appState
                    appState.startup()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 380, height: 660)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // أيقونة شريط النظام: الحالة + إظهار النافذة + خروج
        MenuBarExtra("Developer SoftPhone", systemImage: "phone.fill") {
            MenuBarContent()
                .environmentObject(appState)
                .environment(\.layoutDirection, appState.layoutDirection)
        }
    }
}

/// محتوى قائمة شريط النظام
struct MenuBarContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Text(appState.sip.registrationStatus.displayName)
        Divider()
        Button("إظهار النافذة") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
        }
        Button("خروج") {
            NSApp.terminate(nil)
        }
    }
}

/// مندوب التطبيق: يتحكم في سلوك الإغلاق إلى شريط النظام والعمل في الخلفية
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appState: AppState?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // إغلاق النافذة الأخيرة لا يُنهي التطبيق عند تفعيل "إغلاق إلى شريط النظام"
        guard let appState else { return true }
        return !(appState.settings.closeToMenuBar || appState.settings.runInBackground)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
