import SwiftUI

// Word summary card used by the Favorites and collection lists.
@MainActor
struct WordRowCard: View {
    let word: Word
    let date: Date?
    let viewModel: FeedViewModel
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(word.word)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Button {
                    SpeechService.shared.speak(word.word, voiceID: viewModel.voiceID)
                } label: {
                    HStack(spacing: 6) {
                        Text(word.phonetic)
                        Image(systemName: "speaker.wave.2")
                    }
                    .font(.system(.caption, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.background, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pronounce \(word.word)")
            }
            Text("(\(word.partOfSpeech)) \(word.definition)")
                .font(.system(size: 16, design: .rounded))
            if let example = word.examples.first {
                Text("(\(example))")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack {
                if let date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                HStack(spacing: 24) {
                    Button {
                        viewModel.toggleLike(word)
                    } label: {
                        Image(systemName: viewModel.isLiked(word) ? "heart.fill" : "heart")
                    }
                    .accessibilityLabel(viewModel.isLiked(word) ? "Unlike" : "Like")
                    Button {
                        viewModel.toggleBookmark(word)
                    } label: {
                        Image(systemName: viewModel.isBookmarked(word) ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel(viewModel.isBookmarked(word) ? "Remove from collection" : "Save to collection")
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share \(word.word)")
                }
                .font(.system(size: 18))
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
    }
}
