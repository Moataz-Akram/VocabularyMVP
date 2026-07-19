import SwiftUI

struct RootView: View {
    @AppStorage(OnboardingProfile.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                FeedView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasCompletedOnboarding)
    }
}

#Preview {
    RootView()
}
