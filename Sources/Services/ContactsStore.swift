import Foundation

/// جهات الاتصال: إضافة، تعديل، حذف، مفضلة، تصنيفات، واستيراد/تصدير CSV.
@MainActor
final class ContactsStore: ObservableObject {
    @Published private(set) var contacts: [Contact] = []

    private let fileURL = AppPaths.applicationSupport.appendingPathComponent("contacts.json")

    init() { load() }

    var categories: [String] {
        Array(Set(contacts.map(\.category).filter { !$0.isEmpty })).sorted()
    }

    func upsert(_ contact: Contact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
        } else {
            contacts.append(contact)
        }
        sortAndPersist()
    }

    func delete(_ contact: Contact) {
        contacts.removeAll { $0.id == contact.id }
        persist()
    }

    func toggleFavorite(_ contact: Contact) {
        guard let index = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        contacts[index].isFavorite.toggle()
        persist()
    }

    func contact(forNumber number: String) -> Contact? {
        contacts.first { $0.number == number }
    }

    func filtered(search: String, category: String?, favoritesOnly: Bool) -> [Contact] {
        contacts.filter { c in
            (search.isEmpty
             || c.name.localizedCaseInsensitiveContains(search)
             || c.number.localizedCaseInsensitiveContains(search)
             || c.company.localizedCaseInsensitiveContains(search))
            && (category == nil || c.category == category)
            && (!favoritesOnly || c.isFavorite)
        }
    }

    // MARK: - CSV

    func exportCSV(to url: URL) throws {
        var lines = [Contact.csvHeader]
        lines.append(contentsOf: contacts.map(\.csvRow))
        try lines.joined(separator: "\n").data(using: .utf8)?.write(to: url, options: .atomic)
    }

    func importCSV(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        var lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        // تخطي رأس الجدول إن وجد
        if let first = lines.first, first.lowercased().hasPrefix("name,") {
            lines.removeFirst()
        }
        for line in lines {
            let fields = Self.parseCSVLine(line)
            guard fields.count >= 2, !fields[1].isEmpty else { continue }
            var contact = Contact(name: fields[0], number: fields[1])
            if fields.count > 2 { contact.company = fields[2] }
            if fields.count > 3 { contact.category = fields[3] }
            if fields.count > 4 { contact.isFavorite = fields[4] == "1" || fields[4].lowercased() == "true" }
            if fields.count > 5 { contact.notes = fields[5] }
            // تجاهل المكرر بنفس الرقم
            if self.contact(forNumber: contact.number) == nil {
                contacts.append(contact)
            }
        }
        sortAndPersist()
    }

    static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        while let ch = iterator.next() {
            if inQuotes {
                if ch == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { current.append("\"") }
                        else if next == "," { inQuotes = false; fields.append(current); current = "" }
                        else { inQuotes = false; current.append(next) }
                    } else { inQuotes = false }
                } else { current.append(ch) }
            } else if ch == "\"" && current.isEmpty {
                inQuotes = true
            } else if ch == "," {
                fields.append(current); current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current)
        return fields.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func sortAndPersist() {
        contacts.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Contact].self, from: data) else { return }
        contacts = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(contacts) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
