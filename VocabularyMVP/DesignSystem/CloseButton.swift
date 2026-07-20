import SwiftUI

struct CloseButton: View {
    var size: CGFloat = 36
    var background: Color = Theme.surface

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: size, height: size)
                .background(background, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}
