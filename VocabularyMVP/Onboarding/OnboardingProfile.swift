import Foundation

enum WordLevel: String, Codable, CaseIterable {
    case beginner, intermediate, advanced

    var title: String { rawValue.capitalized }
}

struct OnboardingProfile: Codable {
    var source: String?
    var gender: String?
    var name: String?
    var weeklyGoal: String?
    var topics: [String] = []
    var curiosity: String?
    var level: String?
    var encounterFrequency: String?
    var selfRating: String?
    var weakestArea: String?
    var voiceID: String?
    var knownWords: [String: [String]] = [:]

    var assessedLevel: WordLevel {
        let score = knownCount(.beginner) + knownCount(.intermediate) * 2 + knownCount(.advanced) * 3
        switch score {
        case ..<8: return .beginner
        case ..<20: return .intermediate
        default: return .advanced
        }
    }

    private func knownCount(_ level: WordLevel) -> Int {
        knownWords[level.rawValue]?.count ?? 0
    }
}

extension OnboardingProfile {
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    private static let storageKey = "onboardingProfile"

    static func load() -> OnboardingProfile? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(OnboardingProfile.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
