import SwiftUI

struct RootView: View {
    @AppStorage(OnboardingProfile.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            HomePlaceholderView()
                .transition(.opacity)
        } else {
            OnboardingView()
        }
    }
}

// Temporary stand-in until the word feed lands.
private struct HomePlaceholderView: View {
    private let name = OnboardingProfile.load()?.name

    var body: some View {
        VStack(spacing: 12) {
            Text(name.map { "Welcome, \($0)!" } ?? "Welcome!")
                .font(.serifLargeTitle)
            Text("Your personalized feed is on its way.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

#Preview {
    RootView()
}
