import SwiftUI

struct WordCardView: View {
    let word: Word
    let isLiked: Bool
    let isBookmarked: Bool
    let voiceID: String?
    let onInfo: () -> Void
    let onShare: () -> Void
    let onLike: () -> Void
    let onBookmark: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(word.word)
                .font(.system(size: 40, weight: .bold, design: .serif))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            PronunciationCheckView(word: word, voiceID: voiceID)
            Text("(\(word.partOfSpeech)) \(word.definition)")
                .font(.system(size: 19, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Spacer()
            actions
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }

    private var actions: some View {
        HStack(spacing: 48) {
            Button(action: onInfo) {
                Image(systemName: "info.circle")
            }
            .accessibilityLabel("Details for \(word.word)")

            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Share \(word.word)")

            Button(action: onLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .symbolEffect(.bounce, value: isLiked)
            }
            .accessibilityLabel(isLiked ? "Unlike" : "Like")

            Button(action: onBookmark) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .symbolEffect(.bounce, value: isBookmarked)
            }
            .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark")
        }
        .font(.system(size: 24))
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
    }

}
