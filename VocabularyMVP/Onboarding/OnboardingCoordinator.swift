import Foundation
import Observation

@Observable
final class OnboardingCoordinator {
    let steps = OnboardingFlow.steps
    private(set) var stepIndex = 0
    var profile = OnboardingProfile()

    var currentStep: OnboardingStep { steps[stepIndex] }

    func advance() {
        guard stepIndex < steps.count - 1 else { return finish() }
        Haptics.stepAdvance()
        stepIndex += 1
    }

    private func finish() {
        Haptics.success()
        profile.save()
        UserDefaults.standard.set(true, forKey: OnboardingProfile.hasCompletedOnboardingKey)
    }
}
