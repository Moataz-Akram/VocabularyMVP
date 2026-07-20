import SwiftUI

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 40, height: 40)
                .background(Theme.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

extension View {
    func customBackButton() -> some View {
        navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { BackButton() }
            }
    }
}

