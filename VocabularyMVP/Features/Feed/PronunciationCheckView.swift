import SwiftUI

/// The phonetic pill plus a mic button that listens for the user saying the
/// word and shows a pass/fail verdict beneath.
@MainActor
struct PronunciationCheckView: View {
    let word: Word
    let voiceID: String?

    @State private var showsPermissionAlert = false
    @State private var isPressing = false

    private var service: PronunciationService { PronunciationService.shared }
    private var phase: PronunciationService.Phase {
        service.activeWordID == word.id ? service.phase : .idle
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                phoneticPill
                
                micButton
            }
            
            feedback
        }
        .animation(.spring(duration: 0.3), value: phase)
        .onChange(of: phase) { _, newPhase in
            if newPhase == .denied { showsPermissionAlert = true }
        }
        .onDisappear {
            if service.activeWordID == word.id { service.cancel() }
        }
        .alert("Allow microphone access", isPresented: $showsPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            
            Button("Not now", role: .cancel) {}
        } message: {
            Text("To check your pronunciation, allow microphone and speech recognition access in Settings.")
        }
    }

    private var phoneticPill: some View {
        HStack(spacing: 8) {
            if let phonetic = word.phonetic {
                Text(phonetic)
            }
            
            Button {
                Haptics.selection()
                if service.activeWordID == word.id { service.cancel() }
                SpeechService.shared.speak(word.word, voiceID: voiceID)
            } label: {
                Image(systemName: "speaker.wave.2")
                    // Keeps the tap target finger-sized while the pill stays compact.
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(-8)
            .accessibilityLabel("Pronounce \(word.word)")
        }
        .font(.system(.subheadline, design: .rounded))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface, in: Capsule())
    }

    private var micButton: some View {
        Button {} label: {
            micIcon
                .font(.system(size: 15, weight: .medium))
                .frame(width: 40, height: 40)
                .background(phase == .listening ? Theme.accent : Theme.surface, in: Circle())
                .scaleEffect(isPressing ? 0.9 : 1)
                .animation(.spring(duration: 0.2), value: isPressing)
        }
        .buttonStyle(HoldButtonStyle(onPressingChanged: pressingChanged))
        .accessibilityLabel("Hold and say \(word.word) to check your pronunciation")
    }

    private func pressingChanged(_ pressed: Bool) {
        isPressing = pressed
        if pressed {
            switch phase {
            case .idle, .success, .failure, .unavailable:
                Haptics.selection()
                service.begin(word: word.word, wordID: word.id, localeID: localeID)
            case .denied:
                showsPermissionAlert = true
            case .preparing, .listening:
                break
            }
        } else if service.activeWordID == word.id {
            service.finish()
        }
    }

    @ViewBuilder
    private var micIcon: some View {
        switch phase {
        case .preparing:
            ProgressView()
                .controlSize(.small)
        case .listening:
            Image(systemName: "waveform")
                .symbolEffect(.variableColor.iterative, options: .repeating)
                .foregroundStyle(Theme.onAccent)
        case .success:
            Image(systemName: "checkmark")
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
        case .failure:
            Image(systemName: "xmark")
                .foregroundStyle(.red)
                .transition(.scale.combined(with: .opacity))
        case .unavailable:
            Image(systemName: "mic.slash")
        case .idle, .denied:
            Image(systemName: "mic")
        }
    }

    @ViewBuilder
    private var feedback: some View {
        switch phase {
        // The first attempt in a language downloads its speech model.
        case .preparing:
            feedbackText("Getting ready…")
        case .listening:
            feedbackText(isPressing ? "Say “\(word.word)”…" : "Checking…")
        case .success:
            feedbackText("Sounded great!")
        case .failure:
            feedbackText("Not quite — hold the mic and try again")
        case .unavailable:
        #if targetEnvironment(simulator)
            feedbackText("Pronunciation check isn’t available on simulator")
        #else
            feedbackText("Pronunciation check isn’t available")
        #endif
        case .idle, .denied:
            EmptyView()
        }
    }

    private func feedbackText(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(Theme.textSecondary)
            .multilineTextAlignment(.center)
            .transition(.opacity)
    }

    private var localeID: String {
        SpeechService.shared.voices.first { $0.id == voiceID }?.systemVoice.language ?? "en-US"
    }
}

private struct HoldButtonStyle: ButtonStyle {
    let onPressingChanged: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                onPressingChanged(pressed)
            }
    }
}
