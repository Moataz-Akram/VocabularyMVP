import SwiftUI

@MainActor
struct CollectionDetailView: View {
    let collection: WordCollection

    @Environment(InteractionsStore.self) private var interactions
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var newestFirst = true
    @State private var shareWord: Word?
    @State private var showsRename = false
    @State private var showsDeleteConfirm = false
    @State private var renameText = ""

    private var words: [Word] {
        var result = interactions.words(in: collection)
        if !searchText.isEmpty {
            result = result.filter { $0.word.localizedCaseInsensitiveContains(searchText) }
        }
        return result.sorted {
            let first = interactions.bookmarkedDate($0) ?? .distantPast
            let second = interactions.bookmarkedDate($1) ?? .distantPast
            return newestFirst ? first > second : first < second
        }
    }

    var body: some View {
        Group {
            if words.isEmpty {
                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "No words yet" : "No matches")
                        .font(.serifTitle)
                    if searchText.isEmpty {
                        Text("Tap the bookmark on any word to save it here.")
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
                                        date: interactions.bookmarkedDate(word),
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
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newestFirst.toggle()
                    Haptics.selection()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel(newestFirst ? "Sort oldest first" : "Sort newest first")
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename") {
                        renameText = collection.name
                        showsRename = true
                    }
                    
                    Button("Delete collection", role: .destructive) {
                        showsDeleteConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .tint(Theme.textPrimary)
        .fullScreenCover(item: $shareWord) { word in
            WordShareSheet(word: word)
        }
        .alert("Rename collection", isPresented: $showsRename) {
            TextField("Name", text: $renameText)
            
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    interactions.renameCollection(collection, to: trimmed)
                }
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete “\(collection.name)”?",
                            isPresented: $showsDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                interactions.deleteCollection(collection)
                dismiss()
            }
        } message: {
            Text("Words in this collection won't be deleted, only unsaved.")
        }
    }
}
