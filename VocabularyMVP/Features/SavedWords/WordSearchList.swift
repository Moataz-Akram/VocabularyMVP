import SwiftUI

// Shared scaffold for the Favorites and collection-detail screens: searchable
// word rows with an empty state, bottom search bar, and share cover. `words`
// receives the current search text and returns the rows to show.
@MainActor
struct WordSearchList: View {
    let emptyTitle: String
    let emptyMessage: String
    let date: (Word) -> Date?
    let words: (String) -> [Word]

    @State private var searchText = ""
    @State private var shareWord: Word?

    var body: some View {
        Group {
            let words = words(searchText)
            if words.isEmpty {
                EmptyStateView(title: searchText.isEmpty ? emptyTitle : "No matches",
                               message: searchText.isEmpty ? emptyMessage : nil)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(words) { word in
                            WordRowCard(word: word,
                                        date: date(word),
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
        .fullScreenCover(item: $shareWord) { word in
            WordShareSheet(word: word)
        }
    }
}
