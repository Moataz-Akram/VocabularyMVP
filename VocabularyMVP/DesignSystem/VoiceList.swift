import SwiftUI

// VoiceList view, using native voices, in real app scenario, it's better depending on professional voice over recordings
struct VoiceList: View {
    @Binding var voiceID: String?

    private let speech = SpeechService.shared
    private static let samplePhrase = "Welcome to vocabulary, an app to learn new words!"

    var body: some View {
        VStack(spacing: 12) {
            ForEach(speech.voices) { voice in
                voiceRow(voice)
            }
        }
        .onAppear {
            if voiceID == nil { voiceID = speech.voices.first?.id }
        }
        .onChange(of: speech.voices.count) {
            if voiceID == nil { voiceID = speech.voices.first?.id }
        }
    }

    private func voiceRow(_ voice: SpeechService.Voice) -> some View {
        let isSelected = voiceID == voice.id
        let isSpeaking = speech.speakingVoiceID == voice.id
        return Button {
            voiceID = voice.id
            Haptics.selection()
        } label: {
            HStack(spacing: 12) {
                Button {
                    Haptics.selection()
                    if isSpeaking {
                        speech.pauseOrResume()
                    } else {
                        speech.speak(Self.samplePhrase, voiceID: voice.id)
                    }
                } label: {
                    Image(systemName: isSpeaking && !speech.isPaused ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSpeaking && !speech.isPaused
                    ? "Pause \(voice.name)"
                    : "Play sample of \(voice.name)")

                VStack(alignment: .leading, spacing: 2) {
                    Text(voice.name)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                    Text(voice.accent)
                        .font(.system(.subheadline, design: .rounded))
                        .opacity(0.7)
                }
                WaveformProgress(progress: isSpeaking ? speech.progress : 0,
                                 tint: Theme.onAccent,
                                 track: (isSelected ? Theme.onAccent : Theme.textSecondary).opacity(0.35))
                    .frame(maxWidth: .infinity)
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Theme.onAccent : Theme.textSecondary, lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if isSelected {
                        Circle()
                            .fill(Theme.onAccent)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .contentShape(Rectangle())
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(isSelected ? Theme.accent : Theme.surface, in: Capsule())
        }
        .buttonStyle(HardShadowButtonStyle(shape: Capsule()))
        .accessibilityLabel("\(voice.name), \(voice.accent)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// Speech progress bar, done hard coded as there's not actual record to make the real speech progress bar
private struct WaveformProgress: View {
    let progress: Double
    let tint: Color
    let track: Color

    private static let heights: [CGFloat] = [6, 12, 8, 16, 10, 18, 8, 14, 6, 12, 16, 9, 13, 7, 15, 10, 6, 11]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Self.heights.indices, id: \.self) { index in
                Capsule()
                    .fill(Double(index + 1) / Double(Self.heights.count) <= progress ? tint : track)
                    .frame(width: 2.5, height: Self.heights[index])
            }
        }
        .animation(.linear(duration: 0.15), value: progress)
        .accessibilityHidden(true)
    }
}
