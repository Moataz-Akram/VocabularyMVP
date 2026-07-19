import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Theme.accent, in: Capsule())
        if isEnabled {
            label.hardShadow(in: Capsule(), pressed: configuration.isPressed)
        } else {
            // Flat and dimmed — a shadow would read as pressable.
            label.opacity(0.4)
        }
    }
}
