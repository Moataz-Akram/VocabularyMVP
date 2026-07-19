import SwiftUI

// Circular back button matching the app's chrome, replacing the system one.
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

// Hiding the system back button disables the interactive edge-swipe pop;
// this restores it for the whole app.
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        true
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
