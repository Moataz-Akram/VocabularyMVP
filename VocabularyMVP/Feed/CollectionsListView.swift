import SwiftUI

@MainActor
struct CollectionsListView: View {
    @Environment(InteractionsStore.self) private var interactions

    var body: some View {
        Group {
            if interactions.collections.isEmpty {
                EmptyStateView(title: "No collections yet",
                               message: "Create a collection to organize the words you save.")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(interactions.collections) { collection in
                            NavigationLink {
                                CollectionDetailView(collection: collection)
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
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Collections")
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AddNewCollectionLink()
            }
        }
    }

    private func row(_ collection: WordCollection) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text("^[\(interactions.words(in: collection).count) word](inflect: true)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(20)
        .contentShape(Rectangle())
    }
}
