import Foundation
import Combine
import linphonesw

/// حالة تسجيل الحساب
enum RegistrationStatus: Equatable {
    case unregistered        // غير متصل
    case registering         // جاري التسجيل
    case registered          // متصل
    case failed(String)      // خطأ

    var displayName: String {
        switch self {
        case .unregistered:      return "غير متصل"
        case .registering:       return "جاري التسجيل…"
        case .registered:        return "متصل"
        case .failed(let error): return "خطأ: \(error)"
        }
    }
}

/// حالة المكالمة الجارية
enum ActiveCallState: Equatable {
    case idle
    case incomingRinging
    case outgoingRinging
    case connected
    case paused
    case ended
}

/// مقاييس جودة الاتصال
struct CallQualityMetrics: Equatable {
    var pingMs: Double = 0          // Ping (زمن الذهاب والإياب)
    var packetLossPercent: Float = 0
    var jitterMs: Double = 0
    var latencyMs: Double = 0
    var rating: Float = 0           // 0...5 من مكتبة الوسائط
}

/// معلومات المكالمة الحالية المعروضة في الواجهة
struct ActiveCallInfo: Equatable {
    var remoteNumber: String = ""
    var remoteDisplayName: String = ""
    var state: ActiveCallState = .idle
    var isMuted: Bool = false
    var isSpeakerOn: Bool = false
    var isOnHold: Bool = false
    var isRecording: Bool = false
    var isConference: Bool = false
    var startDate: Date?
    var quality = CallQualityMetrics()
}

/// محرك SIP: غلاف حول liblinphone يدعم UDP/TCP/TLS/WebSocket،
/// وSTUN/TURN/ICE، وSRTP/ZRTP، وأكواد G711/G722/G729/Opus،
/// ومتوافق مع Asterisk وFreePBX و3CX وYeastar وIssabel وCisco وAvaya وغيرها.
@MainActor
final class SIPManager: ObservableObject {
    @Published var registrationStatus: RegistrationStatus = .unregistered
    @Published var activeCall = ActiveCallInfo()
    @Published var lastDialedNumber: String = ""

    /// يُستدعى عند انتهاء مكالمة لإضافتها إلى السجل
    var onCallFinished: ((CallRecord) -> Void)?

    private var core: Core?
    private var coreDelegate: CoreDelegate?
    private var currentCall: Call?
    private var currentAccount: SIPAccount?
    private var iterateTimer: Timer?
    private var qualityTimer: Timer?
    private var callWasConnected = false

    private let log = LogStore.shared

    // MARK: - دورة الحياة

    func start() {
        guard core == nil else { return }
        do {
            let factory = Factory.Instance
            // توجيه سجلات liblinphone إلى سجل التطبيق
            LoggingService.Instance.logLevel = .Message

            let configDir = AppPaths.applicationSupport.path
            let core = try factory.createCore(
                configPath: configDir + "/linphonerc",
                factoryConfigPath: "",
                systemContext: nil
            )
            core.videoActivationPolicy?.automaticallyAccept = false
            core.videoCaptureEnabled = false
            core.videoDisplayEnabled = false

            let delegate = CoreDelegateStub(
                onCallStateChanged: { [weak self] (_: Core, call: Call, state: Call.State, message: String) in
                    Task { @MainActor in self?.handleCallState(call: call, state: state, message: message) }
                },
                onAccountRegistrationStateChanged: { [weak self] (_: Core, _: Account, state: RegistrationState, message: String) in
                    Task { @MainActor in self?.handleRegistrationState(state: state, message: message) }
                }
            )
            core.addDelegate(delegate: delegate)
            try core.start()

            self.core = core
            self.coreDelegate = delegate

            // liblinphone تحتاج إلى iterate() بشكل دوري
            iterateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.core?.iterate() }
            }
            log.log(.app, "تم تشغيل محرك SIP")
        } catch {
            log.log(.app, "فشل تشغيل محرك SIP: \(error)", level: .error)
        }
    }

    func stop() {
        iterateTimer?.invalidate(); iterateTimer = nil
        qualityTimer?.invalidate(); qualityTimer = nil
        core?.stop()
        core = nil
        registrationStatus = .unregistered
    }

    // MARK: - التسجيل

    /// تسجيل حساب SIP (يزيل أي حساب سابق)
    func register(account: SIPAccount, password: String) {
        guard let core else {
            start()
            if self.core != nil { register(account: account, password: password) }
            return
        }
        do {
            unregisterInternal()
            currentAccount = account
            registrationStatus = .registering
            log.log(.registration, "بدء تسجيل الحساب \(account.identityURI) عبر \(account.transport.rawValue)")

            let factory = Factory.Instance

            // بيانات المصادقة
            let authUsername = account.authorizationName.isEmpty ? account.username : account.authorizationName
            let authInfo = try factory.createAuthInfo(
                username: account.username,
                userid: authUsername,
                passwd: password,
                ha1: "",
                realm: account.realm,
                domain: account.effectiveDomain
            )
            core.addAuthInfo(info: authInfo)

            // معطيات الحساب
            let params = try core.createAccountParams()

            let identity = try factory.createAddress(addr: account.identityURI)
            if !account.displayName.isEmpty {
                try identity.setDisplayname(newValue: account.displayName)
            }
            try params.setIdentityaddress(newValue: identity)

            let serverAddress = try factory.createAddress(addr: account.serverURI)
            try serverAddress.setTransport(newValue: Self.linphoneTransport(account.transport))
            try params.setServeraddress(newValue: serverAddress)

            // Outbound Proxy / وسيط
            if account.connectionMode == .proxy || account.proxyEnabled || !account.outboundProxy.isEmpty {
                params.outboundProxyEnabled = true
                if !account.outboundProxy.isEmpty {
                    let routes = try factory.createAddress(addr: "sip:\(account.outboundProxy)")
                    try params.setRoutesaddresses(newValue: [routes])
                } else if account.proxyEnabled && !account.proxyAddress.isEmpty {
                    let routes = try factory.createAddress(addr: "sip:\(account.proxyAddress):\(account.proxyPort)")
                    try params.setRoutesaddresses(newValue: [routes])
                }
            }

            params.registerEnabled = true
            params.expires = account.registrationExpirySeconds

            let linAccount = try core.createAccount(params: params)
            try core.addAccount(account: linAccount)
            core.defaultAccount = linAccount

            // إعدادات عامة على مستوى المحرك
            applyEngineSettings(for: account, core: core)
        } catch {
            registrationStatus = .failed(error.localizedDescription)
            log.log(.registration, "فشل إعداد الحساب: \(error)", level: .error)
        }
    }

    /// إلغاء التسجيل وتسجيل الخروج
    func unregister() {
        unregisterInternal()
        registrationStatus = .unregistered
        log.log(.registration, "تم تسجيل الخروج")
    }

    private func unregisterInternal() {
        guard let core else { return }
        for account in core.accountList {
            if let params = account.params?.clone() {
                params.registerEnabled = false
                account.params = params
            }
        }
        core.clearAccounts()
        core.clearAllAuthInfo()
    }

    /// اختبار الاتصال: محاولة تسجيل مؤقتة وإرجاع النتيجة عبر حالة التسجيل
    func testConnection(account: SIPAccount, password: String) {
        log.log(.app, "اختبار الاتصال بالخادم \(account.server):\(account.port)…")
        register(account: account, password: password)
    }

    // MARK: - إعدادات المحرك

    private func applyEngineSettings(for account: SIPAccount, core: Core) {
        // أكواد الصوت
        for payload in core.audioPayloadTypes {
            let enabled: Bool
            if account.codec == .auto {
                enabled = true
            } else {
                enabled = account.codec.mimeTypes.contains { $0.caseInsensitiveCompare(payload.mimeType) == .orderedSame }
            }
            _ = payload.enable(enabled: enabled)
        }

        // اجتياز NAT: STUN / TURN / ICE
        do {
            let effectiveNAT: NATTraversalMode
            switch account.connectionMode {
            case .stun: effectiveNAT = .stun
            case .turn: effectiveNAT = .turn
            default:    effectiveNAT = account.natTraversal
            }
            if effectiveNAT != .none {
                let natPolicy = try core.createNatPolicy()
                switch effectiveNAT {
                case .stun:
                    natPolicy.stunEnabled = true
                    natPolicy.stunServer = account.stunServer
                case .turn:
                    natPolicy.stunEnabled = true
                    natPolicy.turnEnabled = true
                    natPolicy.stunServer = account.turnServer
                    if !account.turnUsername.isEmpty {
                        natPolicy.stunServerUsername = account.turnUsername
                    }
                case .ice:
                    natPolicy.iceEnabled = true
                    natPolicy.stunEnabled = !account.stunServer.isEmpty
                    natPolicy.stunServer = account.stunServer
                case .none:
                    break
                }
                core.natPolicy = natPolicy
            } else {
                core.natPolicy = nil
            }
        } catch {
            log.log(.app, "تعذّر تطبيق سياسة NAT: \(error)", level: .warning)
        }

        // تشفير الوسائط SRTP
        do {
            let encryption: MediaEncryption
            switch account.mediaEncryption {
            case .none: encryption = .None
            case .srtp: encryption = .SRTP
            case .zrtp: encryption = .ZRTP
            case .dtls: encryption = .DTLS
            }
            try core.setMediaencryption(newValue: encryption)
        } catch {
            log.log(.app, "تعذّر تفعيل تشفير الوسائط: \(error)", level: .warning)
        }

        // شهادة TLS مخصصة
        if account.sslEnabled || account.transport == .tls {
            if !account.certificatePath.isEmpty {
                core.rootCa = account.certificatePath
            }
            // التحقق من الشهادة
            core.verifyServerCertificates(yesno: account.tlsVerifyCertificate)
        }

        // DTMF
        switch account.dtmfMode {
        case .rfc2833:
            core.useRfc2833ForDtmf = true
            core.useInfoForDtmf = false
        case .sipInfo:
            core.useRfc2833ForDtmf = false
            core.useInfoForDtmf = true
        case .inband:
            core.useRfc2833ForDtmf = false
            core.useInfoForDtmf = false
        }

        // الصوت: إلغاء الصدى، Jitter Buffer، VAD، تقليل الضوضاء
        core.echoCancellationEnabled = account.echoCancellation
        core.audioJittcomp = account.jitterBufferMs
        core.audioAdaptiveJittcompEnabled = true
        core.micEnabled = true
        core.config?.setBool(section: "sound", key: "noisegate", value: account.noiseSuppression)
        core.config?.setBool(section: "sound", key: "vad", value: account.voiceActivityDetection)

        // Keep-Alive
        core.keepAliveEnabled = account.keepAliveEnabled
    }

    private static func linphoneTransport(_ transport: SIPTransport) -> TransportType {
        switch transport {
        case .udp:       return .Udp
        case .tcp:       return .Tcp
        case .tls:       return .Tls
        case .webSocket: return .Tcp // يُضبط عبر transport=ws في العنوان عند الحاجة
        }
    }

    // MARK: - المكالمات

    /// إجراء مكالمة صادرة
    func call(number: String) {
        guard let core, !number.isEmpty else { return }
        do {
            let address = try core.interpretUrl(url: number)
            let params = try core.createCallParams(call: nil)
            params.audioEnabled = true
            params.videoEnabled = false
            currentCall = core.inviteAddressWithParams(addr: address, params: params)
            lastDialedNumber = number
            callWasConnected = false
            activeCall = ActiveCallInfo(remoteNumber: number, state: .outgoingRinging, startDate: nil)
            log.log(.call, "مكالمة صادرة إلى \(number)")
        } catch {
            log.log(.call, "فشل إجراء المكالمة إلى \(number): \(error)", level: .error)
        }
    }

    /// إعادة طلب آخر رقم
    func redial() {
        guard !lastDialedNumber.isEmpty else { return }
        call(number: lastDialedNumber)
    }

    /// الرد على مكالمة واردة
    func answer() {
        guard let call = currentCall else { return }
        do {
            try call.accept()
        } catch {
            log.log(.call, "فشل الرد على المكالمة: \(error)", level: .error)
        }
    }

    /// إنهاء المكالمة
    func hangUp() {
        guard let call = currentCall else { return }
        do {
            try call.terminate()
        } catch {
            log.log(.call, "فشل إنهاء المكالمة: \(error)", level: .error)
        }
    }

    /// كتم / إلغاء كتم الميكروفون
    func toggleMute() {
        guard let core else { return }
        core.micEnabled.toggle()
        activeCall.isMuted = !core.micEnabled
    }

    /// تشغيل مكبر الصوت أو سماعة الجهاز
    func toggleSpeaker() {
        guard let core else { return }
        let wantSpeaker = !activeCall.isSpeakerOn
        let target: AudioDevice.Kind = wantSpeaker ? .Speaker : .Microphone
        for device in core.audioDevices where device.type == target || (!wantSpeaker && device.type == .Headphones) {
            core.outputAudioDevice = device
            break
        }
        activeCall.isSpeakerOn = wantSpeaker
    }

    /// تعليق / استئناف المكالمة (Hold)
    func toggleHold() {
        guard let call = currentCall else { return }
        do {
            if activeCall.isOnHold {
                try call.resume()
            } else {
                try call.pause()
            }
        } catch {
            log.log(.call, "فشل تعليق/استئناف المكالمة: \(error)", level: .error)
        }
    }

    /// تحويل المكالمة إلى رقم آخر (Transfer)
    func transfer(to number: String) {
        guard let core, let call = currentCall, !number.isEmpty else { return }
        do {
            let address = try core.interpretUrl(url: number)
            try call.transferTo(referTo: address)
            log.log(.call, "تحويل المكالمة إلى \(number)")
        } catch {
            log.log(.call, "فشل تحويل المكالمة: \(error)", level: .error)
        }
    }

    /// مكالمة جماعية: ضم كل المكالمات الحالية إلى مؤتمر
    func startConference() {
        guard let core else { return }
        do {
            try core.addAllToConference()
            activeCall.isConference = true
            log.log(.call, "بدء مكالمة جماعية")
        } catch {
            log.log(.call, "فشل بدء المكالمة الجماعية: \(error)", level: .error)
        }
    }

    /// بدء / إيقاف تسجيل المكالمة
    func toggleRecording() {
        guard let call = currentCall else { return }
        do {
            if activeCall.isRecording {
                call.stopRecording()
                activeCall.isRecording = false
                log.log(.call, "تم إيقاف تسجيل المكالمة")
            } else {
                try call.startRecording()
                activeCall.isRecording = true
                log.log(.call, "بدأ تسجيل المكالمة")
            }
        } catch {
            log.log(.call, "فشل تسجيل المكالمة: \(error)", level: .error)
        }
    }

    /// إرسال نغمة DTMF أثناء المكالمة
    func sendDTMF(_ digit: Character) {
        guard let call = currentCall else { return }
        do {
            try call.sendDtmf(dtmf: CChar(digit.asciiValue ?? 0))
        } catch {
            log.log(.call, "فشل إرسال DTMF: \(error)", level: .error)
        }
    }

    // MARK: - معالجة الأحداث

    private func handleRegistrationState(state: RegistrationState, message: String) {
        let accountName = currentAccount?.accountName ?? currentAccount?.username ?? ""
        switch state {
        case .Progress:
            registrationStatus = .registering
        case .Ok:
            let wasRegistered = registrationStatus == .registered
            registrationStatus = .registered
            log.log(.registration, "تم التسجيل بنجاح: \(message)")
            if !wasRegistered {
                NotificationManager.shared.notifyRegistered(account: accountName)
            }
        case .Failed:
            registrationStatus = .failed(message)
            log.log(.registration, "فشل التسجيل: \(message)", level: .error)
            NotificationManager.shared.notifyConnectionLost(account: accountName)
        case .Cleared, .None:
            if case .registered = registrationStatus {
                NotificationManager.shared.notifyConnectionLost(account: accountName)
            }
            registrationStatus = .unregistered
        default:
            break
        }
    }

    private func handleCallState(call: Call, state: Call.State, message: String) {
        let remoteAddress = call.remoteAddress
        let remoteNumber = remoteAddress?.username ?? ""
        let remoteName = remoteAddress?.displayName ?? ""

        switch state {
        case .IncomingReceived, .PushIncomingReceived:
            currentCall = call
            callWasConnected = false
            activeCall = ActiveCallInfo(remoteNumber: remoteNumber,
                                        remoteDisplayName: remoteName,
                                        state: .incomingRinging)
            log.log(.call, "مكالمة واردة من \(remoteNumber)")
            NotificationManager.shared.notifyIncomingCall(from: remoteName.isEmpty ? remoteNumber : remoteName)

        case .OutgoingInit, .OutgoingProgress, .OutgoingRinging:
            currentCall = call
            activeCall.state = .outgoingRinging

        case .Connected, .StreamsRunning:
            callWasConnected = true
            if activeCall.startDate == nil { activeCall.startDate = Date() }
            activeCall.state = .connected
            activeCall.isOnHold = false
            startQualityMonitor()

        case .Paused, .PausedByRemote:
            activeCall.state = .paused
            activeCall.isOnHold = true

        case .End, .Released, .Error:
            guard currentCall != nil else { break }
            let duration = call.duration
            let direction: CallDirection
            if call.dir == .Incoming {
                direction = callWasConnected ? .incoming : .missed
            } else {
                direction = .outgoing
            }
            let record = CallRecord(number: remoteNumber,
                                    displayName: remoteName,
                                    direction: direction,
                                    date: activeCall.startDate ?? Date(),
                                    durationSeconds: duration,
                                    accountID: currentAccount?.id)
            onCallFinished?(record)
            if state == .Error {
                log.log(.call, "خطأ في المكالمة: \(message)", level: .error)
            } else {
                log.log(.call, "انتهت المكالمة مع \(remoteNumber) — المدة \(record.durationText)")
            }
            if callWasConnected {
                NotificationManager.shared.notifyCallEnded(with: remoteNumber, duration: record.durationText)
            }
            stopQualityMonitor()
            currentCall = nil
            callWasConnected = false
            activeCall = ActiveCallInfo()

        default:
            break
        }
    }

    // MARK: - جودة الاتصال

    private func startQualityMonitor() {
        qualityTimer?.invalidate()
        qualityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateQuality() }
        }
    }

    private func stopQualityMonitor() {
        qualityTimer?.invalidate()
        qualityTimer = nil
    }

    private func updateQuality() {
        guard let call = currentCall else { return }
        var metrics = CallQualityMetrics()
        metrics.rating = call.currentQuality
        if let stats = call.audioStats {
            metrics.pingMs = Double(stats.roundTripDelay * 1000)
            metrics.latencyMs = Double(stats.roundTripDelay * 500) // اتجاه واحد تقريباً
            metrics.jitterMs = Double(stats.jitterBufferSizeMs)
            metrics.packetLossPercent = stats.receiverLossRate
        }
        activeCall.quality = metrics
    }
}
