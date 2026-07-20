import SwiftUI

struct WordDetailSheet: View {
    let word: Word
    let voiceID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 8) {
                    Text(word.word)
                        .font(.system(size: 30, weight: .bold, design: .serif))
                    
                    PronouncePill(word: word.word, phonetic: word.phonetic, voiceID: voiceID)
                    
                    if let definitionLine = word.definitionLine {
                        Text(definitionLine)
                            .font(.system(.body, design: .rounded))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)

                if let examples = word.examples, !examples.isEmpty {
                    TitledSection("Examples") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                    Text(highlighted(example))
                                }
                            }
                        }
                    }
                }
                
                if let synonyms = word.synonyms, !synonyms.isEmpty {
                    TitledSection("Synonyms") {
                        FlowLayout(spacing: 8) {
                            ForEach(synonyms, id: \.self) { synonym in
                                Text(synonym)
                                    .font(.system(.subheadline, design: .rounded))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.background, in: Capsule())
                            }
                        }
                    }
                }
                
                if let origin = word.origin {
                    TitledSection("Origin") {
                        Text(origin)
                    }
                }
            }
            .font(.system(.body, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .padding(24)
        }
        .overlay(alignment: .topLeading) {
            CloseButton(background: Theme.background)
                .padding(16)
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
}
