import SwiftUI

/// جهات الاتصال: إضافة، تعديل، حذف، مفضلة، تصنيفات، بحث سريع، CSV.
struct ContactsView: View {
    @EnvironmentObject var appState: AppState
    @State private var search = ""
    @State private var category: String?
    @State private var favoritesOnly = false
    @State private var editingContact: Contact?
    @State private var showEditor = false

    private var contacts: [Contact] {
        appState.contacts.filtered(search: search, category: category, favoritesOnly: favoritesOnly)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if contacts.isEmpty {
                emptyState
            } else {
                List(contacts) { contact in
                    row(contact)
                        .contextMenu {
                            Button("اتصال") { appState.sip.call(number: contact.number) }
                            Button("تعديل") { editingContact = contact; showEditor = true }
                            Button(contact.isFavorite ? "إزالة من المفضلة" : "إضافة إلى المفضلة") {
                                appState.contacts.toggleFavorite(contact)
                            }
                            Button("حذف", role: .destructive) { appState.contacts.delete(contact) }
                        }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showEditor) {
            ContactEditorView(contact: editingContact ?? Contact(name: "", number: ""))
                .environmentObject(appState)
        }
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("بحث سريع…", text: $search)
                    .textFieldStyle(.roundedBorder)

                Toggle(isOn: $favoritesOnly) {
                    Image(systemName: "star.fill")
                }
                .toggleStyle(.button)
                .help("المفضلة فقط")

                Menu {
                    Button("استيراد CSV…") { importCSV() }
                    Button("تصدير CSV…") { exportCSV() }
                        .disabled(appState.contacts.contacts.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                Button {
                    editingContact = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n")
                .help("إضافة جهة اتصال")
            }

            if !appState.contacts.categories.isEmpty {
                Picker("التصنيف", selection: $category) {
                    Text("كل التصنيفات").tag(String?.none)
                    ForEach(appState.contacts.categories, id: \.self) { c in
                        Text(c).tag(String?.some(c))
                    }
                }
            }
        }
        .padding(10)
    }

    private func row(_ contact: Contact) -> some View {
        HStack(spacing: 12) {
            Button {
                appState.contacts.toggleFavorite(contact)
            } label: {
                Image(systemName: contact.isFavorite ? "star.fill" : "star")
                    .foregroundColor(contact.isFavorite ? Brand.secondary : .secondary)
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name).fontWeight(.medium)
                HStack(spacing: 6) {
                    Text(contact.number)
                    if !contact.company.isEmpty { Text("· \(contact.company)") }
                    if !contact.category.isEmpty {
                        Text(contact.category)
                            .padding(.horizontal, 6)
                            .background(Brand.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                appState.sip.call(number: contact.number)
            } label: {
                Image(systemName: "phone.fill").foregroundColor(Brand.success)
            }
            .buttonStyle(.borderless)
            .help("اتصال")
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2")
                .font(.system(size: 42))
                .foregroundColor(.secondary)
            Text("لا توجد جهات اتصال")
                .foregroundColor(.secondary)
            Button("إضافة جهة اتصال") {
                editingContact = nil
                showEditor = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        if panel.runModal() == .OK, let url = panel.url {
            try? appState.contacts.importCSV(from: url)
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "contacts.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? appState.contacts.exportCSV(to: url)
        }
    }
}

/// نافذة إضافة/تعديل جهة اتصال
struct ContactEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State var contact: Contact

    var body: some View {
        VStack(spacing: 16) {
            Text(contact.name.isEmpty ? "إضافة جهة اتصال" : "تعديل جهة الاتصال")
                .font(.headline)

            Form {
                TextField("الاسم", text: $contact.name)
                TextField("الرقم", text: $contact.number)
                TextField("الشركة", text: $contact.company)
                TextField("التصنيف", text: $contact.category)
                Toggle("مفضلة", isOn: $contact.isFavorite)
                TextField("ملاحظات", text: $contact.notes)
            }
            .formStyle(.grouped)

            HStack {
                Button("إلغاء") { dismiss() }
                Spacer()
                Button("حفظ") {
                    appState.contacts.upsert(contact)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(contact.name.isEmpty || contact.number.isEmpty)
            }
        }
        .padding()
        .frame(width: 420, height: 400)
    }
}
