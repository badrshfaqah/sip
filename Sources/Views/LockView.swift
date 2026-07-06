import SwiftUI

/// شاشة قفل التطبيق بكلمة مرور
struct LockView: View {
    @EnvironmentObject var appState: AppState
    @State private var password = ""
    @State private var error = false

    var body: some View {
        VStack(spacing: 24) {
            CompanyLogoView(size: 90)
            Text("التطبيق مقفل")
                .font(.title.bold())
            Text("أدخل كلمة المرور لفتح التطبيق")
                .foregroundColor(.secondary)

            SecureField("كلمة المرور", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .onSubmit(unlock)

            if error {
                Text("كلمة المرور غير صحيحة")
                    .foregroundColor(Brand.danger)
                    .font(.callout)
            }

            Button(action: unlock) {
                Text("فتح")
                    .frame(width: 120)
            }
            .brandButtonStyle()
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func unlock() {
        if appState.appLock.unlock(with: password) {
            error = false
            password = ""
        } else {
            error = true
        }
    }
}
