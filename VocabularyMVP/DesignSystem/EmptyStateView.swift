import SwiftUI

// Centered placeholder for screens with nothing to list yet.
struct EmptyStateView: View {
    let title: String
    var message: String?

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.serifTitle)

            if let message {
                Text(message)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
