import SwiftUI

/// أقسام التطبيق الرئيسية
enum MainSection: String, CaseIterable, Identifiable {
    case dialpad  = "لوحة الاتصال"
    case history  = "سجل المكالمات"
    case contacts = "جهات الاتصال"
    case settings = "الإعدادات"
    case logs     = "السجلات"

    var id: String { rawValue }

    /// عنوان مختصر لشريط التبويبات المدمج
    var shortTitle: String {
        switch self {
        case .dialpad:  return "الاتصال"
        case .history:  return "السجل"
        case .contacts: return "جهات"
        case .settings: return "الإعدادات"
        case .logs:     return "Logs"
        }
    }

    var systemImage: String {
        switch self {
        case .dialpad:  return "circle.grid.3x3.fill"
        case .history:  return "clock.arrow.circlepath"
        case .contacts: return "person.2.fill"
        case .settings: return "gearshape.fill"
        case .logs:     return "doc.text.magnifyingglass"
        }
    }
}

/// الواجهة الرئيسية المدمجة: رأس الحالة + المحتوى + شريط تبويبات سفلي.
/// مصممة لنافذة صغيرة (~380 نقطة) تعمل بجانب البرامج الأخرى.
struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var section: MainSection = .dialpad

    var body: some View {
        VStack(spacing: 0) {
            StatusHeaderView()
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            tabBar
        }
        .overlay {
            // شاشة المكالمة تغطي الواجهة أثناء أي مكالمة
            if appState.sip.activeCall.state != .idle {
                InCallView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.sip.activeCall.state != .idle)
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .dialpad:  DialPadView()
        case .history:  CallHistoryView()
        case .contacts: ContactsView()
        case .settings: SettingsView()
        case .logs:     LogsView()
        }
    }

    /// شريط التبويبات السفلي المدمج
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainSection.allCases) { item in
                Button {
                    section = item
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 16, weight: .medium))
                        Text(item.shortTitle)
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .foregroundColor(section == item ? Brand.secondary : .secondary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.rawValue)
            }
        }
        .padding(.vertical, 7)
        .background(.bar)
    }
}
