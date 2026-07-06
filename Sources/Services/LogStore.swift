import Foundation

/// نوع سطر السجل
enum LogKind: String, Codable, CaseIterable, Identifiable {
    case sip          = "SIP"           // رسائل SIP
    case registration = "Registration"  // أخطاء/أحداث التسجيل
    case call         = "Call"          // أحداث الاتصال
    case app          = "App"           // عام

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .sip:          return "SIP"
        case .registration: return "التسجيل"
        case .call:         return "الاتصال"
        case .app:          return "التطبيق"
        }
    }
}

enum LogLevel: String, Codable {
    case info, warning, error
}

struct LogEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var kind: LogKind
    var level: LogLevel = .info
    var message: String
}

/// سجلات التطبيق: عرض SIP Logs وأخطاء التسجيل والاتصال، مع تصدير ومسح.
@MainActor
final class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published private(set) var entries: [LogEntry] = []
    private let maxEntries = 5000

    func log(_ kind: LogKind, _ message: String, level: LogLevel = .info) {
        entries.append(LogEntry(kind: kind, level: level, message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    /// استدعاء آمن من أي Thread
    nonisolated func logAsync(_ kind: LogKind, _ message: String, level: LogLevel = .info) {
        Task { @MainActor in
            self.log(kind, message, level: level)
        }
    }

    /// مسح السجلات
    func clear() { entries = [] }

    func filtered(kind: LogKind?, errorsOnly: Bool) -> [LogEntry] {
        entries.filter {
            (kind == nil || $0.kind == kind) && (!errorsOnly || $0.level == .error)
        }.reversed()
    }

    /// تصدير Logs إلى ملف نصي
    func export(to url: URL) throws {
        let formatter = ISO8601DateFormatter()
        let text = entries
            .map { "[\(formatter.string(from: $0.date))] [\($0.kind.rawValue)] [\($0.level.rawValue)] \($0.message)" }
            .joined(separator: "\n")
        try text.data(using: .utf8)?.write(to: url, options: .atomic)
    }
}
