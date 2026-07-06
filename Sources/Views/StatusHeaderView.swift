import SwiftUI

/// رأس الحالة: حالة الاتصال، الامتداد، المستخدم، الشركة، السيرفر، وجودة الاتصال.
struct StatusHeaderView: View {
    @EnvironmentObject var appState: AppState

    private var account: SIPAccount? { appState.accountStore.activeAccount }

    var body: some View {
        HStack(spacing: 16) {
            statusBadge

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(account?.displayName.isEmpty == false ? account!.displayName : (account?.username ?? "—"))
                        .font(.headline)
                    if let username = account?.username, !username.isEmpty {
                        Text("امتداد \(username)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Brand.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text("\(Brand.companyName) · \(account?.server ?? "—")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if appState.sip.activeCall.state == .connected {
                qualityIndicators
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var statusBadge: some View {
        let (color, text): (Color, String) = {
            switch appState.sip.registrationStatus {
            case .registered:   return (Brand.success, "متصل")
            case .registering:  return (Brand.warning, "جاري التسجيل…")
            case .unregistered: return (.gray, "غير متصل")
            case .failed:       return (Brand.danger, "خطأ")
            }
        }()
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text).font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .help(appState.sip.registrationStatus.displayName)
    }

    /// مؤشرات جودة الاتصال: Ping وPacket Loss وJitter وLatency
    private var qualityIndicators: some View {
        let q = appState.sip.activeCall.quality
        return HStack(spacing: 14) {
            qualityItem(label: "Ping", value: String(format: "%.0f ms", q.pingMs))
            qualityItem(label: "فقد الحزم", value: String(format: "%.1f%%", q.packetLossPercent))
            qualityItem(label: "Jitter", value: String(format: "%.0f ms", q.jitterMs))
            qualityItem(label: "Latency", value: String(format: "%.0f ms", q.latencyMs))
        }
        .font(.caption.monospacedDigit())
    }

    private func qualityItem(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(value).fontWeight(.semibold)
            Text(label).foregroundColor(.secondary)
        }
    }
}
