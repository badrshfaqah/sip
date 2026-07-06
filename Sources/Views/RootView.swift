import SwiftUI

/// الواجهة الجذرية: تعرض القفل، ثم شاشة الدخول أو الواجهة الرئيسية.
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var lockProxy = ObservableProxy()

    var body: some View {
        Group {
            if appState.appLock.isLocked {
                LockView()
            } else if appState.showLogin {
                LoginView()
            } else {
                MainView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.showLogin)
        .onReceive(appState.appLock.objectWillChange) { _ in
            lockProxy.objectWillChange.send()
        }
    }
}

/// وسيط بسيط لإعادة رسم الواجهة عند تغيّر حالة القفل
private final class ObservableProxy: ObservableObject {}
