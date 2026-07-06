import SwiftUI

/// لوحة الاتصال: أرقام كاملة 0-9 و * و # مع اتصال وإعادة طلب.
struct DialPadView: View {
    @EnvironmentObject var appState: AppState
    @State private var number = ""

    /// عند تمرير إغلاق، تُستخدم اللوحة لإرسال DTMF أثناء المكالمة
    var onDigit: ((Character) -> Void)?
    var compact = false

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["*", "0", "#"],
    ]

    var body: some View {
        VStack(spacing: compact ? 10 : 18) {
            if onDigit == nil {
                numberField
            }

            VStack(spacing: compact ? 8 : 12) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: compact ? 8 : 12) {
                        ForEach(row, id: \.self) { key in
                            dialKey(key)
                        }
                    }
                }
            }

            if onDigit == nil {
                actionRow
            }
        }
        .padding(compact ? 8 : 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var numberField: some View {
        HStack {
            TextField("أدخل الرقم…", text: $number)
                .textFieldStyle(.plain)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .onSubmit(dial)

            if !number.isEmpty {
                Button {
                    number.removeLast()
                } label: {
                    Image(systemName: "delete.backward.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.delete, modifiers: [])
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: 420)
    }

    private func dialKey(_ key: String) -> some View {
        Button {
            if let digit = key.first {
                if let onDigit {
                    onDigit(digit)
                } else {
                    number.append(key)
                }
            }
        } label: {
            Text(key)
                .font(.system(size: compact ? 18 : 26, weight: .medium, design: .rounded))
                .frame(width: compact ? 52 : 72, height: compact ? 42 : 60)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    private var actionRow: some View {
        HStack(spacing: 20) {
            // إعادة طلب آخر رقم
            Button {
                if number.isEmpty {
                    appState.sip.redial()
                } else {
                    dial()
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("إعادة طلب آخر رقم")

            // زر الاتصال
            Button(action: dial) {
                Image(systemName: "phone.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 68, height: 68)
                    .background(Circle().fill(Brand.success))
            }
            .buttonStyle(.plain)
            .disabled(number.isEmpty && appState.sip.lastDialedNumber.isEmpty)
            .keyboardShortcut(.return, modifiers: [])
            .help("اتصال")

            // مسافة موازنة
            Color.clear.frame(width: 48, height: 48)
        }
    }

    private func dial() {
        let target = number.isEmpty ? appState.sip.lastDialedNumber : number
        guard !target.isEmpty else { return }
        appState.sip.call(number: target)
        number = ""
    }
}
