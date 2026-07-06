import SwiftUI

/// شاشة المكالمة الجارية: رد/إنهاء، كتم، مكبر صوت، تعليق، تحويل، مؤتمر، تسجيل، ولوحة أرقام DTMF.
struct InCallView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDialpad = false
    @State private var showTransfer = false
    @State private var transferNumber = ""
    @State private var elapsed: TimeInterval = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var call: ActiveCallInfo { appState.sip.activeCall }

    var body: some View {
        VStack(spacing: 26) {
            Spacer()

            // معلومات الطرف الآخر
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Brand.primary.opacity(0.15))
                        .frame(width: 110, height: 110)
                    Image(systemName: "person.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Brand.primary)
                }
                Text(displayName)
                    .font(.title.bold())
                Text(call.remoteNumber)
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text(stateText)
                    .font(.headline)
                    .foregroundColor(stateColor)
                    .monospacedDigit()
            }

            // جودة الاتصال المختصرة
            if call.state == .connected {
                HStack(spacing: 16) {
                    Label(String(format: "%.0f ms", call.quality.pingMs), systemImage: "wave.3.right")
                    Label(String(format: "%.1f%% فقد", call.quality.packetLossPercent), systemImage: "shippingbox")
                    Label(String(format: "%.0f ms jitter", call.quality.jitterMs), systemImage: "waveform.path.ecg")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if showDialpad {
                DialPadView(onDigit: { appState.sip.sendDTMF($0) }, compact: true)
                    .frame(maxHeight: 240)
            }

            if showTransfer {
                HStack {
                    TextField("رقم التحويل", text: $transferNumber)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                    Button("تحويل") {
                        appState.sip.transfer(to: transferNumber)
                        showTransfer = false
                        transferNumber = ""
                    }
                    .disabled(transferNumber.isEmpty)
                }
            }

            // أزرار التحكم
            if call.state == .incomingRinging {
                incomingButtons
            } else {
                controlGrid
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onReceive(timer) { _ in
            if let start = call.startDate {
                elapsed = Date().timeIntervalSince(start)
            }
        }
    }

    private var displayName: String {
        if !call.remoteDisplayName.isEmpty { return call.remoteDisplayName }
        if let contact = appState.contacts.contact(forNumber: call.remoteNumber) { return contact.name }
        return call.remoteNumber
    }

    private var stateText: String {
        switch call.state {
        case .incomingRinging: return "مكالمة واردة…"
        case .outgoingRinging: return "جاري الاتصال…"
        case .paused:          return "معلّقة"
        case .connected:
            let m = Int(elapsed) / 60, s = Int(elapsed) % 60
            return String(format: "%02d:%02d", m, s)
        default:               return ""
        }
    }

    private var stateColor: Color {
        switch call.state {
        case .connected: return Brand.success
        case .paused:    return Brand.warning
        default:         return .secondary
        }
    }

    /// أزرار الرد / الرفض للمكالمة الواردة
    private var incomingButtons: some View {
        HStack(spacing: 60) {
            circleButton(icon: "phone.down.fill", color: Brand.danger, label: "رفض") {
                appState.sip.hangUp()
            }
            circleButton(icon: "phone.fill", color: Brand.success, label: "رد") {
                appState.sip.answer()
            }
        }
    }

    /// شبكة أزرار التحكم أثناء المكالمة
    private var controlGrid: some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                toggleButton(icon: call.isMuted ? "mic.slash.fill" : "mic.fill",
                             label: "كتم", active: call.isMuted) {
                    appState.sip.toggleMute()
                }
                toggleButton(icon: "speaker.wave.2.fill",
                             label: "مكبر الصوت", active: call.isSpeakerOn) {
                    appState.sip.toggleSpeaker()
                }
                toggleButton(icon: "pause.fill",
                             label: "تعليق", active: call.isOnHold) {
                    appState.sip.toggleHold()
                }
                toggleButton(icon: "arrow.uturn.right",
                             label: "تحويل", active: showTransfer) {
                    showTransfer.toggle()
                }
            }
            HStack(spacing: 18) {
                toggleButton(icon: "person.3.fill",
                             label: "مؤتمر", active: call.isConference) {
                    appState.sip.startConference()
                }
                toggleButton(icon: "record.circle",
                             label: "تسجيل", active: call.isRecording,
                             activeColor: Brand.danger) {
                    appState.sip.toggleRecording()
                }
                toggleButton(icon: "circle.grid.3x3.fill",
                             label: "الأرقام", active: showDialpad) {
                    showDialpad.toggle()
                }
                circleButton(icon: "phone.down.fill", color: Brand.danger, label: "إنهاء") {
                    appState.sip.hangUp()
                }
            }
        }
    }

    private func toggleButton(icon: String, label: String, active: Bool,
                              activeColor: Color = Brand.primary,
                              action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(active ? .white : .primary)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(active ? activeColor : Color(nsColor: .controlBackgroundColor)))
            }
            .buttonStyle(.plain)
            Text(label).font(.caption)
        }
    }

    private func circleButton(icon: String, color: Color, label: String,
                              action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(color))
            }
            .buttonStyle(.plain)
            Text(label).font(.caption)
        }
    }
}
