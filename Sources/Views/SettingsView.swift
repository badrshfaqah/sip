import SwiftUI

/// إعدادات التطبيق: السلوك، الإشعارات، المظهر، الأمان، والتحديثات.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLockSetup = false
    @State private var lockPassword = ""
    @State private var confirmReset = false

    var body: some View {
        Form {
            behaviorSection
            notificationsSection
            appearanceSection
            securitySection
            aboutSection
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showLockSetup) { lockSetupSheet }
        .confirmationDialog("سيتم حذف كل الحسابات والإعدادات. هل أنت متأكد؟", isPresented: $confirmReset) {
            Button("إعادة تعيين الإعدادات", role: .destructive) {
                appState.accountStore.resetAll()
                appState.settings = AppSettings()
                appState.appLock.removePassword()
                appState.showLogin = true
            }
            Button("إلغاء", role: .cancel) {}
        }
    }

    private var behaviorSection: some View {
        Section {
            Toggle("تشغيل البرنامج مع بدء تشغيل macOS", isOn: $appState.settings.launchAtLogin)
            Toggle("تشغيل في الخلفية", isOn: $appState.settings.runInBackground)
            Toggle("إغلاق إلى شريط النظام", isOn: $appState.settings.closeToMenuBar)
            Toggle("التحقق من التحديثات تلقائياً", isOn: $appState.settings.checkForUpdates)
        } header: {
            Text("السلوك").font(.headline)
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle("إشعار عند مكالمة واردة", isOn: $appState.settings.notifyOnIncomingCall)
            Toggle("إشعار عند انتهاء المكالمة", isOn: $appState.settings.notifyOnCallEnded)
            Toggle("إشعار عند فقد الاتصال", isOn: $appState.settings.notifyOnConnectionLost)
            Toggle("إشعار عند تسجيل الدخول", isOn: $appState.settings.notifyOnRegistration)
        } header: {
            Text("الإشعارات").font(.headline)
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("اللغة", selection: $appState.settings.language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            Picker("الثيم", selection: $appState.settings.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
        } header: {
            Text("المظهر واللغة").font(.headline)
        } footer: {
            Text("الواجهة الإنجليزية ستُفعّل نصوصها الكاملة في إصدار قادم.")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private var securitySection: some View {
        Section {
            Toggle("قفل البرنامج بكلمة مرور", isOn: Binding(
                get: { appState.settings.appLockEnabled },
                set: { enabled in
                    if enabled {
                        showLockSetup = true
                    } else {
                        appState.settings.appLockEnabled = false
                        appState.appLock.removePassword()
                    }
                }
            ))

            Button("تسجيل الخروج من الحساب الحالي") {
                appState.logout()
            }

            Button("إعادة تعيين الإعدادات", role: .destructive) {
                confirmReset = true
            }
        } header: {
            Text("الأمان").font(.headline)
        } footer: {
            Text("كلمات المرور تُخزَّن مشفّرة في Keychain الخاص بالنظام، ولا تُحفظ إلا بعد موافقتك.")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("إصدار البرنامج", value: appState.appVersion)
            if let update = appState.updateChecker.availableUpdate {
                LabeledContent("تحديث متوفر", value: update.version)
                if let url = URL(string: update.url) {
                    Link("تنزيل التحديث", destination: url)
                }
            }
            Button("التحقق من التحديثات الآن") {
                Task { await appState.updateChecker.check() }
            }
            if let error = appState.updateChecker.lastCheckError {
                Text(error).font(.caption).foregroundColor(Brand.danger)
            }
        } header: {
            Text("حول").font(.headline)
        }
    }

    private var lockSetupSheet: some View {
        VStack(spacing: 16) {
            Text("تعيين كلمة مرور القفل").font(.headline)
            SecureField("كلمة المرور الجديدة", text: $lockPassword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            HStack {
                Button("إلغاء") {
                    lockPassword = ""
                    showLockSetup = false
                }
                Spacer()
                Button("حفظ") {
                    appState.appLock.setPassword(lockPassword)
                    appState.settings.appLockEnabled = true
                    lockPassword = ""
                    showLockSetup = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(lockPassword.count < 4)
            }
        }
        .padding()
        .frame(width: 320)
    }
}
