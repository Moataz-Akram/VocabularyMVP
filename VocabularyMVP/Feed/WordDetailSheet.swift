import SwiftUI

struct WordDetailSheet: View {
    let word: Word
    let voiceID: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 8) {
                    Text(word.word)
                        .font(.system(size: 34, weight: .bold, design: .serif))
                    Button {
                        SpeechService.shared.speak(word.word, voiceID: voiceID)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "speaker.wave.2")
                            Text(word.phonetic)
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.background, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Text("(\(word.partOfSpeech)) \(word.definition)")
                        .font(.system(.body, design: .rounded))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                section("Examples") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(word.examples.enumerated()), id: \.offset) { index, example in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                Text(highlighted(example))
                            }
                        }
                    }
                }
                section("Synonyms") {
                    HStack(spacing: 8) {
                        ForEach(word.synonyms, id: \.self) { synonym in
                            Text(synonym)
                                .font(.system(.subheadline, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.background, in: Capsule())
                        }
                    }
                }
                section("Origin") {
                    Text(word.origin)
                }
            }
            .font(.system(.body, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .padding(24)
        }
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Theme.background, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel("Close")
        }
        .presentationDetents([.fraction(0.96)])
        .presentationBackground(Theme.surface)
    }

    // Bolds the first occurrence of the word (covers inflections like "imbrued").
    private func highlighted(_ example: String) -> AttributedString {
        var attributed = AttributedString(example)
        if let range = attributed.range(of: word.word, options: .caseInsensitive) {
            attributed[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return attributed
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
