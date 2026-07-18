import SwiftUI

@MainActor
struct CollectionsListView: View {
    let viewModel: FeedViewModel

    var body: some View {
        Group {
            if viewModel.collections.isEmpty {
                VStack(spacing: 8) {
                    Text("No collections yet")
                        .font(.serifTitle)
                    Text("Create a collection to organize the words you save.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.collections) { collection in
                            NavigationLink {
                                CollectionDetailView(collection: collection, viewModel: viewModel)
                            } label: {
                                row(collection)
                            }
                            .buttonStyle(.plain)
                            if collection.id != viewModel.collections.last?.id {
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
                NavigationLink {
                    NewCollectionView(viewModel: viewModel)
                } label: {
                    Text("Add new")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.surface, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(_ collection: WordCollection) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text("^[\(viewModel.words(in: collection).count) word](inflect: true)")
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
