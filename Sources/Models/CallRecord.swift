import Foundation

/// اتجاه/نوع المكالمة في السجل
enum CallDirection: String, Codable, CaseIterable, Identifiable {
    case incoming = "incoming"   // واردة
    case outgoing = "outgoing"   // صادرة
    case missed   = "missed"     // فائتة

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .incoming: return "واردة"
        case .outgoing: return "صادرة"
        case .missed:   return "فائتة"
        }
    }

    var systemImage: String {
        switch self {
        case .incoming: return "phone.arrow.down.left"
        case .outgoing: return "phone.arrow.up.right"
        case .missed:   return "phone.badge.waveform"
        }
    }
}

/// عنصر واحد في سجل المكالمات
struct CallRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var number: String
    var displayName: String = ""
    var direction: CallDirection
    var date: Date
    var durationSeconds: Int = 0
    var accountID: UUID?

    var durationText: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
