import Foundation

/// جهة اتصال
struct Contact: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var number: String
    var company: String = ""
    var category: String = ""     // التصنيف
    var isFavorite: Bool = false  // مفضلة
    var notes: String = ""

    /// سطر CSV (name,number,company,category,favorite,notes)
    var csvRow: String {
        [name, number, company, category, isFavorite ? "1" : "0", notes]
            .map { field in
                if field.contains(",") || field.contains("\"") || field.contains("\n") {
                    return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                }
                return field
            }
            .joined(separator: ",")
    }

    static let csvHeader = "name,number,company,category,favorite,notes"
}
