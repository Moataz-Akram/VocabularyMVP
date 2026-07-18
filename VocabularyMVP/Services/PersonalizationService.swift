import Foundation

// Orders each fetched page for the feed: words the user marked as known are
// dropped, then preferred topics and words near the assessed level float up.
// The final tie-break is a stable hash so the order is deterministic across
// launches. A real backend would rank server-side; this mirrors that contract.
struct PersonalizationService {
    private let knownWords: Set<String>
    private let topics: Set<String>
    private let userLevel: Int

    init(profile: OnboardingProfile?) {
        let flatKnown = profile?.knownWords.values.flatMap { $0 } ?? []
        knownWords = Set(flatKnown.map { $0.lowercased() })
        topics = Set((profile?.topics ?? []).map { $0.lowercased() })
        userLevel = Self.index(of: profile?.assessedLevel ?? .beginner)
    }

    func orderPage(_ words: [Word]) -> [Word] {
        words
            .filter { !knownWords.contains($0.word.lowercased()) }
            .sorted { sortKey($0) < sortKey($1) }
    }

    private func sortKey(_ word: Word) -> (Int, Int, UInt64) {
        let topicMiss = topics.isDisjoint(with: word.topics.map { $0.lowercased() }) ? 1 : 0
        let levelDistance = abs(Self.index(of: word.level) - userLevel)
        return (topicMiss, levelDistance, Self.stableHash(word.id))
    }

    private static func index(of level: WordLevel) -> Int {
        WordLevel.allCases.firstIndex(of: level) ?? 0
    }

    private static func stableHash(_ string: String) -> UInt64 {
        string.utf8.reduce(5381) { ($0 << 5) &+ $0 &+ UInt64($1) }
    }
}
