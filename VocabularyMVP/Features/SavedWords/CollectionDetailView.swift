import SwiftUI

@MainActor
struct CollectionDetailView: View {
    let collection: WordCollection

    @Environment(InteractionsStore.self) private var interactions
    @Environment(\.dismiss) private var dismiss
    @State private var newestFirst = true
    @State private var showsRename = false
    @State private var showsDeleteConfirm = false
    @State private var renameText = ""

    var body: some View {
        WordSearchList(emptyTitle: "No words yet",
                       emptyMessage: "Tap the bookmark on any word to save it here.",
                       date: interactions.bookmarkedDate) { searchText in
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
