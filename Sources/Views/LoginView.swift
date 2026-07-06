import SwiftUI
import UniformTypeIdentifiers

/// شاشة تسجيل الدخول وإعداد الحساب — تشمل جميع خيارات SIP الأساسية والمتقدمة.
struct LoginView: View {
    @EnvironmentObject var appState: AppState

    @State private var account = SIPAccount()
    @State private var password = ""
    @State private var proxyPassword = ""
    @State private var turnPassword = ""
    @State private var selectedTab = 0
    @State private var testMessage: String?

    var body: some View {
        HStack(spacing: 0) {
            sidePanel
            Divider()
            formPanel
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - اللوحة الجانبية: الشعار + الحسابات المحفوظة

    private var sidePanel: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 20)
            CompanyLogoView(size: 96)
            Text("Developer SoftPhone")
                .font(.title2.bold())
            Text(Brand.companyName)
                .font(.headline)
                .foregroundColor(Brand.primary)

            if !appState.accountStore.accounts.isEmpty {
                Divider().padding(.horizontal)
                Text("الحسابات المحفوظة")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                List {
                    ForEach(appState.accountStore.accounts) { saved in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(saved.accountName.isEmpty ? saved.username : saved.accountName)
                                    .fontWeight(.medium)
                                Text("\(saved.username)@\(saved.server)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                account = saved
                                password = appState.accountStore.password(for: saved) ?? ""
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }
                            .buttonStyle(.borderless)
                            .help("تعديل")
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.switchTo(account: saved)
                            if appState.accountStore.password(for: saved) != nil {
                                appState.showLogin = false
                            }
                        }
                        .contextMenu {
                            Button("نسخ الإعدادات") { appState.accountStore.duplicate(saved) }
                            Button("حذف", role: .destructive) { appState.accountStore.remove(saved) }
                        }
                    }
                }
                .listStyle(.inset)
            }

            Spacer()

            HStack {
                Button("استيراد الإعدادات") { importSettings() }
                Button("تصدير الإعدادات") { exportSettings() }
            }
            .controlSize(.small)
            .padding(.bottom, 16)
        }
        .frame(width: 280)
    }

    // MARK: - نموذج الإعداد

    private var formPanel: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("الأساسيات").tag(0)
                Text("الصوت").tag(1)
                Text("الشبكة والمتقدم").tag(2)
                Text("الأمان").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                Group {
                    switch selectedTab {
                    case 0:  basicsForm
                    case 1:  audioForm
                    case 2:  advancedForm
                    default: securityForm
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            Divider()
            footer
        }
    }

    private var basicsForm: some View {
        Form {
            Section {
                TextField("اسم الحساب", text: $account.accountName)
                TextField("اسم المستخدم (Username)", text: $account.username)
                SecureField("كلمة المرور", text: $password)
                Toggle("حفظ كلمة المرور (تُخزَّن مشفّرة في Keychain)", isOn: $account.savePassword)
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
                    Text("Jitter Buffer (ملّي ثانية)")
                    Spacer()
                    TextField("", value: $account.jitterBufferMs, format: .number)
                        .frame(width: 80)
                    Stepper("", value: $account.jitterBufferMs, in: 0...500, step: 10)
                        .labelsHidden()
                }
            } header: {
                Text("إعدادات الصوت").font(.headline)
            }
        }
        .formStyle(.grouped)
    }

    private var advancedForm: some View {
        Form {
            Section {
                HStack {
                    Text("زمن التسجيل (Registration Expiry)")
                    Spacer()
                    TextField("", value: $account.registrationExpirySeconds, format: .number.grouping(.never))
                        .frame(width: 90)
                    Text("ثانية").foregroundColor(.secondary)
                }
                Toggle("Keep Alive", isOn: $account.keepAliveEnabled)
                Picker("اجتياز NAT (NAT Traversal)", selection: $account.natTraversal) {
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
                    TextField("شهادة Certificate (مسار الملف)", text: $account.certificatePath)
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
    }

    // MARK: - الشريط السفلي

    private var footer: some View {
        VStack(spacing: 8) {
            if let testMessage {
                Text(testMessage)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            switch appState.sip.registrationStatus {
            case .failed(let error):
                Text(error).font(.callout).foregroundColor(Brand.danger)
            case .registering:
                ProgressView().controlSize(.small)
            default:
                EmptyView()
            }

            HStack(spacing: 12) {
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

                Button {
                    saveAndConnect()
                } label: {
                    Text("حفظ واتصال").frame(minWidth: 110)
                }
                .brandButtonStyle()
                .buttonStyle(.plain)
                .disabled(!account.isValid || password.isEmpty)
            }
        }
        .padding()
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
