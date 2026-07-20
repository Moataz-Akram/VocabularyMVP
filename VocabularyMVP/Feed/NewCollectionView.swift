import SwiftUI

@MainActor
struct NewCollectionView: View {
    var onCreated: ((WordCollection) -> Void)?

    @Environment(InteractionsStore.self) private var interactions
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var isFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Enter a name for your new collection. You can rename it later.")
                .font(.system(.body, design: .rounded))
            TextField("My new collection", text: $name)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                .focused($isFocused)
                .submitLabel(.done)
            Spacer()
            Button("Save") {
                let collection = interactions.addCollection(named: trimmedName)
                Haptics.success()
                onCreated?(collection)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(trimmedName.isEmpty)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(20)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("New collection")
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton()
        .onAppear { isFocused = true }
    }
}
