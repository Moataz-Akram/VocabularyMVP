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
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Theme.onAccent : Theme.textSecondary, lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if isSelected {
                        Circle()
                            .fill(Theme.onAccent)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(isSelected ? Theme.accent : Theme.surface, in: Capsule())
            .hardShadow(in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
