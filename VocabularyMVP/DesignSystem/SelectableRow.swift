import SwiftUI

struct SelectableRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .multilineTextAlignment(.leading)
                Spacer()
                RadioIndicator(isSelected: isSelected)
            }
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(isSelected ? Theme.accent : Theme.surface, in: Capsule())
        }
        .buttonStyle(HardShadowButtonStyle(shape: Capsule()))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
