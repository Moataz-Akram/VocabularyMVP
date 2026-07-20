import SwiftUI

// Presented from the "Saved to …" toast; moves the word between collections.
@MainActor
struct CollectionPickerSheet: View {
    let word: Word

    @Environment(InteractionsStore.self) private var interactions
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(interactions.collections) { collection in
                        Button {
                            interactions.assign(word, to: collection)
                            dismiss()
                        } label: {
                            row(collection)
                        }
                        .buttonStyle(.plain)
                        if collection.id != interactions.collections.last?.id {
                            Divider().padding(.leading, 20)
                        }
                    }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    AddNewCollectionLink { newCollection in
                        interactions.assign(word, to: newCollection)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.96)])
    }

    private func row(_ collection: WordCollection) -> some View {
        let isCurrent = interactions.collection(for: word)?.id == collection.id
        return HStack {
            Text(collection.name)
                .font(.system(.body, design: .rounded).weight(.semibold))
            
            Spacer()
            
            Image(systemName: isCurrent ? "bookmark.fill" : "bookmark")
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(20)
        .contentShape(Rectangle())
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
