import SwiftUI

struct WordCardPreviewStepView: View {
    let voiceID: String?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Get deeper insight into each word you learn")
                .font(.serifTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            sampleCard
            Spacer()
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var sampleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                Text("ephemeral")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                Button {
                    SpeechService.shared.speak("ephemeral", voiceID: voiceID)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.wave.2")
                        Text("/ɪˈfɛməɹəl/")
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.background, in: Capsule())
                }
                .buttonStyle(.plain)
                Text("(adj.) Lasting for a very short time")
                    .font(.system(.body, design: .rounded))
            }
            .frame(maxWidth: .infinity)

            section("Example") {
                Text("The beauty of cherry blossoms is ephemeral, gone within a week.")
            }
            section("Synonyms") {
                HStack(spacing: 8) {
                    ForEach(["fleeting", "transient", "short-lived"], id: \.self) { synonym in
                        Text(synonym)
                            .font(.system(.subheadline, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.background, in: Capsule())
                    }
                }
            }
            section("Origin") {
                Text("From Greek ephémeros, meaning “lasting only a day.”")
            }
        }
        .font(.system(.body, design: .rounded))
        .foregroundStyle(Theme.textPrimary)
        .padding(24)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 28))
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }
}
