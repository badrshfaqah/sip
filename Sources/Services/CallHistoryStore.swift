import Foundation

/// سجل المكالمات: واردة، صادرة، فائتة — مع بحث وتصدير وحذف.
@MainActor
final class CallHistoryStore: ObservableObject {
    @Published private(set) var records: [CallRecord] = []

    private let fileURL = AppPaths.applicationSupport.appendingPathComponent("call-history.json")

    init() { load() }

    func add(_ record: CallRecord) {
        records.insert(record, at: 0)
        persist()
    }

    func delete(_ record: CallRecord) {
        records.removeAll { $0.id == record.id }
        persist()
    }

    /// حذف السجل كاملاً
    func clear() {
        records = []
        persist()
    }

    func filtered(direction: CallDirection?, search: String) -> [CallRecord] {
        records.filter { record in
            (direction == nil || record.direction == direction)
            && (search.isEmpty
                || record.number.localizedCaseInsensitiveContains(search)
                || record.displayName.localizedCaseInsensitiveContains(search))
        }
    }

    /// تصدير السجل إلى CSV
    func exportCSV(to url: URL) throws {
        let formatter = ISO8601DateFormatter()
        var lines = ["date,direction,number,name,duration_seconds"]
        for r in records {
            lines.append("\(formatter.string(from: r.date)),\(r.direction.rawValue),\(r.number),\(r.displayName),\(r.durationSeconds)")
        }
        try lines.joined(separator: "\n").data(using: .utf8)?.write(to: url, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([CallRecord].self, from: data) else { return }
        records = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
