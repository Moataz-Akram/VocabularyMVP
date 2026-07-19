import SwiftUI

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
            TextField("Search", text: $text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Theme.surface, in: Capsule())
    }
}
