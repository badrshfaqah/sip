import SwiftUI

/// عرض السجلات: SIP Logs، أخطاء التسجيل، أخطاء الاتصال — مع تصدير ومسح.
struct LogsView: View {
    @ObservedObject private var logStore = LogStore.shared
    @State private var kind: LogKind?
    @State private var errorsOnly = false

    private var entries: [LogEntry] {
        logStore.filtered(kind: kind, errorsOnly: errorsOnly)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary)
                    Text("لا توجد سجلات")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(entries) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Text(entry.date, format: .dateTime.hour().minute().second())
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)

                        Text(entry.kind.displayName)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badgeColor(entry).opacity(0.15))
                            .foregroundColor(badgeColor(entry))
                            .clipShape(Capsule())

                        Text(entry.message)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }
        }
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            Picker("", selection: $kind) {
                Text("الكل").tag(LogKind?.none)
                ForEach(LogKind.allCases) { k in
                    Text(k.displayName).tag(LogKind?.some(k))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 8) {
                Toggle("الأخطاء فقط", isOn: $errorsOnly)
                    .toggleStyle(.button)
                    .controlSize(.small)

                Spacer()

                Button {
                    exportLogs()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(logStore.entries.isEmpty)
                .help("تصدير Logs")

                Button(role: .destructive) {
                    logStore.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(logStore.entries.isEmpty)
                .help("مسح السجلات")
            }
        }
        .padding(10)
    }

    private func badgeColor(_ entry: LogEntry) -> Color {
        switch entry.level {
        case .error:   return Brand.danger
        case .warning: return Brand.warning
        case .info:    return Brand.primary
        }
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "softphone-logs.txt"
        if panel.runModal() == .OK, let url = panel.url {
            try? logStore.export(to: url)
        }
    }
}
