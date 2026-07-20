import Foundation
import Observation

// The user's chosen pronunciation voice, persisted on the onboarding profile.
// Shared through the environment so any screen can read or change it.
@Observable
@MainActor
final class VoiceSettings {
    private(set) var voiceID: String?

    init() {
        voiceID = OnboardingProfile.load()?.voiceID
    }

    // Picks up a voice chosen during onboarding, which writes the profile
    // directly after this object was created at launch.
    func reload() {
        voiceID = OnboardingProfile.load()?.voiceID
    }

    func setVoice(_ voiceID: String?) {
        self.voiceID = voiceID
        var profile = OnboardingProfile.load() ?? OnboardingProfile()
        profile.voiceID = voiceID
        profile.save()
    }
}
