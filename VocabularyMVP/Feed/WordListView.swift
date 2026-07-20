import SwiftUI

@MainActor
struct WordListView: View {
    @Environment(InteractionsStore.self) private var interactions

    var body: some View {
        WordSearchList(emptyTitle: "No favorites yet",
                       emptyMessage: "Tap the heart on any word to save it here.",
                       date: interactions.likedDate) { searchText in
            guard !searchText.isEmpty else { return interactions.favoriteWords }
            return interactions.favoriteWords.filter {
                $0.word.localizedCaseInsensitiveContains(searchText)
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton()
    }
}
