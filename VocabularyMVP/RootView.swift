import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage(OnboardingProfile.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @Environment(VoiceSettings.self) private var voiceSettings

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
        .onChange(of: hasCompletedOnboarding) { _, completed in
            if completed { voiceSettings.reload() }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WordInteraction.self, WordCollection.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return RootView()
        .environment(InteractionsStore(context: container.mainContext))
        .environment(VoiceSettings())
}
