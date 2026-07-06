import SwiftUI

/// سجل المكالمات: واردة/صادرة/فائتة، بحث، إعادة اتصال، حذف، تصدير.
struct CallHistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var filter: CallDirection?
    @State private var search = ""
    @State private var confirmClear = false

    private var records: [CallRecord] {
        appState.callHistory.filtered(direction: filter, search: search)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if records.isEmpty {
                emptyState
            } else {
                List(records) { record in
                    row(record)
                        .contextMenu {
                            Button("إعادة الاتصال") { appState.sip.call(number: record.number) }
                            Button("حذف", role: .destructive) { appState.callHistory.delete(record) }
                        }
                }
                .listStyle(.inset)
            }
        }
        .confirmationDialog("هل تريد حذف سجل المكالمات بالكامل؟", isPresented: $confirmClear) {
            Button("حذف السجل", role: .destructive) { appState.callHistory.clear() }
            Button("إلغاء", role: .cancel) {}
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("", selection: $filter) {
                Text("الكل").tag(CallDirection?.none)
                ForEach(CallDirection.allCases) { d in
                    Text(d.displayName).tag(CallDirection?.some(d))
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 340)

            TextField("بحث…", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)

            Spacer()

            Button {
                exportHistory()
            } label: {
                Label("تصدير", systemImage: "square.and.arrow.up")
            }
            .disabled(appState.callHistory.records.isEmpty)

            Button(role: .destructive) {
                confirmClear = true
            } label: {
                Label("حذف السجل", systemImage: "trash")
            }
            .disabled(appState.callHistory.records.isEmpty)
        }
        .padding(12)
    }

    private func row(_ record: CallRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: record.direction.systemImage)
                .foregroundColor(record.direction == .missed ? Brand.danger : Brand.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(record)).fontWeight(.medium)
                Text(record.number).font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(record.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
                if record.direction != .missed {
                    Text(record.durationText)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }

            Button {
                appState.sip.call(number: record.number)
            } label: {
                Image(systemName: "phone.fill")
                    .foregroundColor(Brand.success)
            }
            .buttonStyle(.borderless)
            .help("إعادة الاتصال")
        }
        .padding(.vertical, 4)
    }

    private func displayName(_ record: CallRecord) -> String {
        if !record.displayName.isEmpty { return record.displayName }
        if let contact = appState.contacts.contact(forNumber: record.number) { return contact.name }
        return record.number
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 42))
                .foregroundColor(.secondary)
            Text("لا توجد مكالمات في السجل")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "call-history.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? appState.callHistory.exportCSV(to: url)
        }
    }
}
