import Foundation

/// التحقق من التحديثات عبر ملف JSON على خادم الشركة.
/// شكل الملف المتوقع: {"version": "1.1.0", "url": "https://.../DeveloperSoftPhone.dmg", "notes": "..."}
@MainActor
final class UpdateChecker: ObservableObject {
    struct UpdateInfo: Codable {
        let version: String
        let url: String
        let notes: String?
    }

    /// ضع هنا رابط ملف التحديثات على خادم الشركة
    static let feedURL = URL(string: "https://badr-s.com/softphone/appcast.json")

    @Published var availableUpdate: UpdateInfo?
    @Published var lastCheckError: String?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func check() async {
        guard let url = Self.feedURL else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let info = try JSONDecoder().decode(UpdateInfo.self, from: data)
            if info.version.compare(currentVersion, options: .numeric) == .orderedDescending {
                availableUpdate = info
            } else {
                availableUpdate = nil
            }
            lastCheckError = nil
        } catch {
            lastCheckError = error.localizedDescription
        }
    }
}
