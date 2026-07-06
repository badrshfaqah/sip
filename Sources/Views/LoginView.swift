import SwiftUI
import UniformTypeIdentifiers

/// شاشة تسجيل الدخول وإعداد الحساب — بتصميم عمود واحد يناسب النافذة المدمجة،
/// وتشمل جميع خيارات SIP الأساسية والمتقدمة.
struct LoginView: View {
    @EnvironmentObject var appState: AppState

    @State private var account = SIPAccount()
    @State private var password = ""
    @State private var proxyPassword = ""
    @State private var turnPassword = ""
    @State private var selectedTab = 0
    @State private var testMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            tabs
            ScrollView {
                Group {
                    switch selectedTab {
                    case 0:  basicsForm
                    case 1:  audioForm
                    case 2:  advancedForm
                    default: securityForm
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - الرأس: الشعار + الحسابات المحفوظة

    private var header: some View {
        VStack(spacing: 6) {
            CompanyLogoView(size: 54)
                .padding(.top, 30)   // مساحة لأزرار النافذة
            Text("Developer SoftPhone")
                .font(.system(size: 15, weight: .bold))
            Text(Brand.companyName)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(Brand.secondary)
            Text("الإصدار \(appState.appVersion)")
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)

            if !appState.accountStore.accounts.isEmpty {
                Menu {
                    ForEach(appState.accountStore.accounts) { saved in
                        Menu(saved.accountName.isEmpty ? saved.username : saved.accountName) {
                            Button("اتصال بهذا الحساب") {
                                appState.switchTo(account: saved)
                                if appState.accountStore.password(for: saved) != nil {
                                    appState.showLogin = false
                                }
                            }
                            Button("تعديل") {
                                account = saved
                                password = appState.accountStore.password(for: saved) ?? ""
                            }
                            Button("نسخ الإعدادات") { appState.accountStore.duplicate(saved) }
                            Button("حذف", role: .destructive) { appState.accountStore.remove(saved) }
                        }
                    }
                    Divider()
                    Button("استيراد الإعدادات…") { importSettings() }
                    Button("تصدير الإعدادات…") { exportSettings() }
                } label: {
                    Label("الحسابات المحفوظة (\(appState.accountStore.accounts.count))",
                          systemImage: "person.crop.circle")
                        .font(.system(size: 11.5))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .padding(.top, 2)
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }

    private var tabs: some View {
        Picker("", selection: $selectedTab) {
            Text("الأساسيات").tag(0)
            Text("الصوت").tag(1)
            Text("الشبكة").tag(2)
            Text("الأمان").tag(3)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: - النماذج

    private var basicsForm: some View {
        Form {
            Section {
                TextField("اسم الحساب", text: $account.accountName)
                TextField("اسم المستخدم (Username)", text: $account.username)
                SecureField("كلمة المرور", text: $password)
                Toggle("حفظ كلمة المرور (Keychain)", isOn: $account.savePassword)
                TextField("عنوان السيرفر أو IP", text: $account.server)
                TextField("المنفذ (Port)", value: $account.port, format: .number.grouping(.never))
            } header: {
                Text("بيانات الحساب").font(.headline)
            }

            Section {
                Picker("البروتوكول", selection: $account.transport) {
                    ForEach(SIPTransport.allCases) { t in Text(t.displayName).tag(t) }
                }
                Picker("نوع الاتصال", selection: $account.connectionMode) {
                    ForEach(ConnectionMode.allCases) { m in Text(m.displayName).tag(m) }
                }
                TextField("Outbound Proxy", text: $account.outboundProxy)
                TextField("Domain", text: $account.domain)
                TextField("Realm", text: $account.realm)
                TextField("Display Name", text: $account.displayName)
                TextField("Authorization Name", text: $account.authorizationName)
            } header: {
                Text("الاتصال والهوية").font(.headline)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    private var audioForm: some View {
        Form {
            Section {
                Picker("اختيار Codec", selection: $account.codec) {
                    ForEach(AudioCodec.allCases) { c in Text(c.displayName).tag(c) }
                }
                Picker("وضع DTMF", selection: $account.dtmfMode) {
                    ForEach(DTMFMode.allCases) { d in Text(d.displayName).tag(d) }
                }
                Toggle("إلغاء الصدى (Echo Cancellation)", isOn: $account.echoCancellation)
                Toggle("تقليل الضوضاء (Noise Suppression)", isOn: $account.noiseSuppression)
                Toggle("كشف النشاط الصوتي (VAD)", isOn: $account.voiceActivityDetection)
                HStack {
                    Text("Jitter Buffer (ms)")
                    Spacer()
                    TextField("", value: $account.jitterBufferMs, format: .number)
                        .frame(width: 60)
                    Stepper("", value: $account.jitterBufferMs, in: 0...500, step: 10)
                        .labelsHidden()
                }
            } header: {
                Text("إعدادات الصوت").font(.headline)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    private var advancedForm: some View {
        Form {
            Section {
                HStack {
                    Text("زمن التسجيل (Expiry)")
                    Spacer()
                    TextField("", value: $account.registrationExpirySeconds, format: .number.grouping(.never))
                        .frame(width: 70)
                    Text("ثانية").foregroundColor(.secondary)
                }
                Toggle("Keep Alive", isOn: $account.keepAliveEnabled)
                Picker("اجتياز NAT", selection: $account.natTraversal) {
                    ForEach(NATTraversalMode.allCases) { n in Text(n.displayName).tag(n) }
                }
                TextField("خادم STUN", text: $account.stunServer)
                    .disabled(account.natTraversal == .none && account.connectionMode != .stun)
                TextField("خادم TURN", text: $account.turnServer)
                TextField("اسم مستخدم TURN", text: $account.turnUsername)
                SecureField("كلمة مرور TURN", text: $turnPassword)
            } header: {
                Text("الشبكة").font(.headline)
            }

            Section {
                Toggle("تشغيل Proxy", isOn: $account.proxyEnabled)
                Group {
                    TextField("عنوان Proxy", text: $account.proxyAddress)
                    TextField("منفذ Proxy", value: $account.proxyPort, format: .number.grouping(.never))
                    TextField("اسم مستخدم Proxy", text: $account.proxyUsername)
                    SecureField("كلمة مرور Proxy", text: $proxyPassword)
                }
                .disabled(!account.proxyEnabled)
            } header: {
                Text("الوسيط (Proxy)").font(.headline)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    private var securityForm: some View {
        Form {
            Section {
                Picker("تشفير الوسائط (SRTP)", selection: $account.mediaEncryption) {
                    ForEach(MediaEncryptionMode.allCases) { e in Text(e.displayName).tag(e) }
                }
                Toggle("تفعيل SSL/TLS", isOn: $account.sslEnabled)
                Toggle("التحقق من شهادة الخادم", isOn: $account.tlsVerifyCertificate)
                HStack {
                    TextField("شهادة Certificate", text: $account.certificatePath)
                    Button("اختيار…") { pickCertificate() }
                }
            } header: {
                Text("الأمان والتشفير").font(.headline)
            } footer: {
                Text("عند اختيار البروتوكول TLS يُنصح بتفعيل التحقق من الشهادة وتشفير SRTP.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    // MARK: - الشريط السفلي

    private var footer: some View {
        VStack(spacing: 8) {
            if let testMessage {
                Text(testMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            switch appState.sip.registrationStatus {
            case .failed(let error):
                Text(error).font(.caption).foregroundColor(Brand.danger).lineLimit(2)
            case .registering:
                ProgressView().controlSize(.small)
            default:
                EmptyView()
            }

            HStack(spacing: 8) {
                Button("اختبار الاتصال") {
                    testMessage = "جاري اختبار الاتصال…"
                    appState.sip.testConnection(account: account, password: password)
                }
                .disabled(!account.isValid || password.isEmpty)

                Button("حساب جديد") {
                    account = SIPAccount()
                    password = ""
                }
                Spacer()
            }
            .controlSize(.small)

            Button {
                saveAndConnect()
            } label: {
                Text("حفظ واتصال")
                    .frame(maxWidth: .infinity)
            }
            .brandButtonStyle()
            .buttonStyle(.plain)
            .disabled(!account.isValid || password.isEmpty)
        }
        .padding(12)
        .onChange(of: appState.sip.registrationStatus) { status in
            if case .registered = status { testMessage = "نجح الاتصال بالخادم ✓" }
        }
    }

    // MARK: - أفعال

    private func saveAndConnect() {
        appState.accountStore.upsert(account, password: password)
        if account.proxyEnabled && !proxyPassword.isEmpty {
            KeychainHelper.save(password: proxyPassword, for: KeychainHelper.proxyPasswordKey(account.id))
        }
        if !turnPassword.isEmpty {
            KeychainHelper.save(password: turnPassword, for: KeychainHelper.turnPasswordKey(account.id))
        }
        appState.accountStore.activeAccountID = account.id
        appState.sip.register(account: account, password: password)
        appState.showLogin = false
    }

    private func pickCertificate() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "pem"), UTType(filenameExtension: "crt"), UTType(filenameExtension: "cer")].compactMap { $0 }
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url {
            account.certificatePath = url.path
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? appState.accountStore.importAccounts(from: url)
        }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "softphone-accounts.json"
        if panel.runModal() == .OK, let url = panel.url {
            try? appState.accountStore.exportAccounts(to: url)
        }
    }
}
