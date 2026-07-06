import Foundation

/// وسيلة النقل المستخدمة لبروتوكول SIP
enum SIPTransport: String, Codable, CaseIterable, Identifiable {
    case udp = "UDP"
    case tcp = "TCP"
    case tls = "TLS"
    case webSocket = "WebSocket"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

/// نوع الاتصال بالخادم
enum ConnectionMode: String, Codable, CaseIterable, Identifiable {
    case direct = "Direct"
    case proxy = "Proxy"
    case stun = "STUN"
    case turn = "TURN"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .direct: return "مباشر (Direct)"
        case .proxy:  return "وسيط (Proxy)"
        case .stun:   return "STUN"
        case .turn:   return "TURN"
        }
    }
}

/// أكواد الصوت المدعومة
enum AudioCodec: String, Codable, CaseIterable, Identifiable {
    case auto  = "Auto"
    case g711  = "G711"
    case g722  = "G722"
    case g729  = "G729"
    case opus  = "Opus"
    case aac   = "AAC"

    var id: String { rawValue }
    var displayName: String { rawValue }

    /// أسماء الـ MIME كما تعرفها مكتبة الوسائط
    var mimeTypes: [String] {
        switch self {
        case .auto: return []
        case .g711: return ["PCMU", "PCMA"]
        case .g722: return ["G722"]
        case .g729: return ["G729"]
        case .opus: return ["opus"]
        case .aac:  return ["mpeg4-generic", "AAC-ELD"]
        }
    }
}

/// طريقة إرسال نغمات DTMF
enum DTMFMode: String, Codable, CaseIterable, Identifiable {
    case rfc2833 = "RFC 2833"
    case sipInfo = "SIP INFO"
    case inband  = "In-Band"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

/// آلية اجتياز NAT
enum NATTraversalMode: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case stun = "STUN"
    case turn = "TURN"
    case ice  = "ICE"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none: return "بدون"
        case .stun: return "STUN"
        case .turn: return "TURN"
        case .ice:  return "ICE"
        }
    }
}

/// تشفير الوسائط
enum MediaEncryptionMode: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case srtp = "SRTP"
    case zrtp = "ZRTP"
    case dtls = "DTLS-SRTP"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none: return "بدون تشفير"
        case .srtp: return "SRTP"
        case .zrtp: return "ZRTP"
        case .dtls: return "DTLS-SRTP"
        }
    }
}

/// حساب SIP كامل بجميع خيارات الإعداد.
/// كلمات المرور لا تُخزَّن هنا أبداً — تُحفظ في Keychain عبر `KeychainHelper`.
struct SIPAccount: Codable, Identifiable, Equatable {
    var id: UUID = UUID()

    // — الأساسيات —
    var accountName: String = ""          // اسم الحساب (وصفي)
    var username: String = ""             // اسم المستخدم / رقم الامتداد
    var server: String = ""               // عنوان السيرفر أو IP
    var port: Int = 5060                  // المنفذ
    var transport: SIPTransport = .udp    // البروتوكول
    var connectionMode: ConnectionMode = .direct

    // — الهوية —
    var domain: String = ""               // Domain (يُستخدم السيرفر إن تُرك فارغاً)
    var realm: String = ""                // Realm
    var displayName: String = ""          // Display Name
    var authorizationName: String = ""    // Authorization Name

    // — الوسيط —
    var outboundProxy: String = ""        // Outbound Proxy
    var proxyEnabled: Bool = false        // تشغيل Proxy
    var proxyAddress: String = ""
    var proxyPort: Int = 5060
    var proxyUsername: String = ""        // كلمة مرور الوسيط في Keychain

    // — STUN / TURN —
    var stunServer: String = ""
    var turnServer: String = ""
    var turnUsername: String = ""         // كلمة مرور TURN في Keychain

    // — الصوت —
    var codec: AudioCodec = .auto
    var dtmfMode: DTMFMode = .rfc2833
    var echoCancellation: Bool = true     // إلغاء الصدى
    var noiseSuppression: Bool = true     // تقليل الضوضاء
    var jitterBufferMs: Int = 60          // Jitter Buffer (ملّي ثانية)
    var voiceActivityDetection: Bool = true

    // — التسجيل والاتصال —
    var registrationExpirySeconds: Int = 3600  // زمن التسجيل
    var keepAliveEnabled: Bool = true
    var natTraversal: NATTraversalMode = .none

    // — الأمان —
    var mediaEncryption: MediaEncryptionMode = .none  // SRTP
    var sslEnabled: Bool = false
    var tlsVerifyCertificate: Bool = true
    var certificatePath: String = ""      // مسار شهادة Certificate

    // — أخرى —
    var savePassword: Bool = false        // لا تُحفظ كلمة المرور إلا بعد موافقة المستخدم

    /// الدومين الفعلي المستخدم في عنوان SIP
    var effectiveDomain: String {
        domain.isEmpty ? server : domain
    }

    /// عنوان الهوية الكامل sip:user@domain
    var identityURI: String {
        "sip:\(username)@\(effectiveDomain)"
    }

    /// عنوان الخادم مع المنفذ ووسيلة النقل
    var serverURI: String {
        var uri = "sip:\(server):\(port)"
        if transport != .udp {
            uri += ";transport=\(transport.rawValue.lowercased())"
        }
        return uri
    }

    var isValid: Bool {
        !username.isEmpty && !server.isEmpty && port > 0
    }
}
