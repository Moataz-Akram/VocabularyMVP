import SwiftUI

@MainActor
struct WordListView: View {
    enum Kind {
        case favorites, collections

        var title: String {
            switch self {
            case .favorites: "Favorites"
            case .collections: "Collections"
            }
        }
    }

    let kind: Kind
    let viewModel: FeedViewModel

    @State private var shareWord: Word?

    private var words: [Word] {
        switch kind {
        case .favorites: viewModel.favoriteWords
        case .collections: viewModel.bookmarkedWords
        }
    }

    var body: some View {
        Group {
            if words.isEmpty {
                VStack(spacing: 8) {
                    Text(kind == .favorites ? "No favorites yet" : "No saved words yet")
                        .font(.serifTitle)
                    Text(kind == .favorites
                         ? "Tap the heart on any word to save it here."
                         : "Tap the bookmark on any word to save it here.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(words) { word in
                            row(word)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $shareWord) { word in
            WordShareSheet(word: word)
        }
    }

    private func row(_ word: Word) -> some View {
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
                .font(.system(.body, design: .rounded))
            if let example = word.examples.first {
                Text("(\(example))")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack {
                if let likedAt = viewModel.likedDate(word) {
                    Text(likedAt.formatted(date: .abbreviated, time: .omitted))
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
                    .accessibilityLabel(viewModel.isBookmarked(word) ? "Remove bookmark" : "Bookmark")
                    Button {
                        shareWord = word
                    } label: {
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
