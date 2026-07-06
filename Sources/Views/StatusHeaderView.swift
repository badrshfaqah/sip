import SwiftUI

/// رأس الحالة المدمج: حالة الاتصال، الامتداد، السيرفر، والتبديل بين الحسابات.
struct StatusHeaderView: View {
    @EnvironmentObject var appState: AppState

    private var account: SIPAccount? { appState.accountStore.activeAccount }

    var body: some View {
        HStack(spacing: 10) {
            statusBadge

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(account?.displayName.isEmpty == false ? account!.displayName : (account?.username ?? "—"))
                        .font(.system(size: 12.5, weight: .bold))
                        .lineLimit(1)
                    if let username = account?.username, !username.isEmpty {
                        Text("امتداد \(username)")
                            .font(.system(size: 9.5, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Brand.secondary.opacity(0.13))
                            .foregroundColor(Brand.secondary)
                            .clipShape(Capsule())
                    }
                }
                Text("\(Brand.companyName) · \(account?.server ?? "—")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            accountMenu
        }
        .padding(.horizontal, 12)
        .padding(.top, 26)   // مساحة لأزرار النافذة مع شريط العنوان المخفي
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var statusBadge: some View {
        let (color, text): (Color, String) = {
            switch appState.sip.registrationStatus {
            case .registered:   return (Brand.success, "متصل")
            case .registering:  return (Brand.warning, "التسجيل…")
            case .unregistered: return (.gray, "غير متصل")
            case .failed:       return (Brand.danger, "خطأ")
            }
        }()
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .help(appState.sip.registrationStatus.displayName)
    }

    /// قائمة التبديل بين الحسابات وإدارتها
    private var accountMenu: some View {
        Menu {
            ForEach(appState.accountStore.accounts) { acc in
                Button {
                    appState.switchTo(account: acc)
                } label: {
                    if acc.id == appState.accountStore.activeAccountID {
                        Label(title(acc), systemImage: "checkmark")
                    } else {
                        Text(title(acc))
                    }
                }
            }
            Divider()
            Button("إدارة الحسابات…") { appState.showLogin = true }
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("التبديل بين الحسابات")
    }

    private func title(_ acc: SIPAccount) -> String {
        acc.accountName.isEmpty ? acc.username : acc.accountName
    }
}
