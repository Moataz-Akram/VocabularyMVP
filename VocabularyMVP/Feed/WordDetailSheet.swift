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
                        .font(.system(size: 30, weight: .bold, design: .serif))
                    
                    HStack(spacing: 6) {
                        if let phonetic = word.phonetic {
                            Text(phonetic)
                        }
                        
                        Button {
                            SpeechService.shared.speak(word.word, voiceID: voiceID)
                        } label: {
                            Image(systemName: "speaker.wave.2")
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(-8)
                        .accessibilityLabel("Pronounce \(word.word)")
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.background, in: Capsule())
                    
                    if let definitionLine = word.definitionLine {
                        Text(definitionLine)
                            .font(.system(.body, design: .rounded))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)

                if let examples = word.examples, !examples.isEmpty {
                    section("Examples") {
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
                    section("Synonyms") {
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
                    section("Origin") {
                        Text(origin)
                    }
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

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let positions = arrange(in: bounds.width, subviews: subviews).positions
        for (subview, position) in zip(subviews, positions) {
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                          proposal: .unspecified)
        }
    }

    private func arrange(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
