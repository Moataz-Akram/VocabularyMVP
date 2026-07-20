import SwiftUI

@MainActor
struct WordListView: View {
    @Environment(InteractionsStore.self) private var interactions

    @State private var searchText = ""
    @State private var shareWord: Word?

    private var words: [Word] {
        guard !searchText.isEmpty else { return interactions.favoriteWords }
        return interactions.favoriteWords.filter {
            $0.word.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if words.isEmpty {
                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "No favorites yet" : "No matches")
                        .font(.serifTitle)
                    
                    if searchText.isEmpty {
                        Text("Tap the heart on any word to save it here.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(words) { word in
                            WordRowCard(word: word,
                                        date: interactions.likedDate(word),
                                        onShare: { shareWord = word })
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            SearchBar(text: $searchText)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton()
        .fullScreenCover(item: $shareWord) { word in
            WordShareSheet(word: word)
        }
    }
}
