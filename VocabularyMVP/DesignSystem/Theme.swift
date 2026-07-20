import SwiftUI

enum Theme {
    static let background = adaptive(light: UIColor(red: 0.94, green: 0.93, blue: 0.89, alpha: 1),
                                     dark: UIColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1))
    static let surface = adaptive(light: .white,
                                  dark: UIColor(red: 0.23, green: 0.23, blue: 0.23, alpha: 1))
    static let textPrimary = adaptive(light: UIColor(red: 0.11, green: 0.11, blue: 0.1, alpha: 1),
                                      dark: UIColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1))
    static let textSecondary = adaptive(light: UIColor(red: 0.4, green: 0.4, blue: 0.38, alpha: 1),
                                        dark: UIColor(red: 0.7, green: 0.7, blue: 0.68, alpha: 1))
    static let accent = Color(red: 0.62, green: 0.8, blue: 0.78)
    static let onAccent = Color(red: 0.11, green: 0.11, blue: 0.1)

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

extension View {
    // offset shadow effect with spring effect on press
    func hardShadow<S: Shape>(in shape: S, offset: CGFloat = 4, pressed: Bool = false) -> some View {
        background(shape.fill(.black).offset(y: pressed ? 0 : offset))
            // Flattens view + shadow into one layer, so fades and dimming
            // can't show the black shape through the surface above it.
            .compositingGroup()
            .offset(y: pressed ? offset : 0)
            .animation(.spring(duration: 0.2), value: pressed)
    }
}

// offset shadow effect with spring effect on press
struct HardShadowButtonStyle<S: Shape>: ButtonStyle {
    var shape: S
    var offset: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .hardShadow(in: shape, offset: offset, pressed: configuration.isPressed)
    }
}

extension Font {
    static let serifLargeTitle = Font.system(size: 32, weight: .bold, design: .serif)
    static let serifTitle = Font.system(size: 26, weight: .bold, design: .serif)
}
