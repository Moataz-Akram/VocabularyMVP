import SwiftUI

struct RootView: View {
    @AppStorage(OnboardingProfile.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            FeedView()
                .transition(.opacity)
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    RootView()
}
