import SwiftUI

/// أقسام التطبيق الرئيسية
enum MainSection: String, CaseIterable, Identifiable {
    case dialpad  = "لوحة الاتصال"
    case history  = "سجل المكالمات"
    case contacts = "جهات الاتصال"
    case settings = "الإعدادات"
    case logs     = "السجلات"

    var id: String { rawValue }
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

/// الواجهة الرئيسية: شريط جانبي + رأس الحالة + المحتوى
struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var section: MainSection = .dialpad

    var body: some View {
        NavigationSplitView {
            List(MainSection.allCases, selection: $section) { item in
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
            .safeAreaInset(edge: .bottom) {
                accountSwitcher
            }
        } detail: {
            VStack(spacing: 0) {
                StatusHeaderView()
                Divider()
                content
            }
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

    /// التبديل بين الحسابات من أسفل الشريط الجانبي
    private var accountSwitcher: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            if appState.accountStore.accounts.count > 1 {
                Menu {
                    ForEach(appState.accountStore.accounts) { account in
                        Button {
                            appState.switchTo(account: account)
                        } label: {
                            if account.id == appState.accountStore.activeAccountID {
                                Label(accountTitle(account), systemImage: "checkmark")
                            } else {
                                Text(accountTitle(account))
                            }
                        }
                    }
                    Divider()
                    Button("إضافة حساب…") { appState.showLogin = true }
                } label: {
                    Label(accountTitle(appState.accountStore.activeAccount), systemImage: "person.crop.circle")
                        .lineLimit(1)
                }
                .menuStyle(.borderlessButton)
            } else {
                Button {
                    appState.showLogin = true
                } label: {
                    Label("إدارة الحسابات", systemImage: "person.crop.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(10)
    }

    private func accountTitle(_ account: SIPAccount?) -> String {
        guard let account else { return "بدون حساب" }
        return account.accountName.isEmpty ? account.username : account.accountName
    }
}
