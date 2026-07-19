import XCTest
@testable import VocabularyMVP

final class PersonalizationServiceTests: XCTestCase {

    // MARK: - Known-word filtering

    func testKnownWordsAreFiltered() {
        var profile = OnboardingProfile()
        profile.knownWords = ["beginner": ["Whisper"]]
        let service = PersonalizationService(profile: profile)

        let words = [makeWord(id: "1", word: "whisper"), makeWord(id: "2", word: "squint")]
        let ordered = service.orderPage(words)

        XCTAssertEqual(ordered.map(\.word), ["squint"])
    }

    func testKnownWordFilteringIsCaseInsensitive() {
        var profile = OnboardingProfile()
        profile.knownWords = ["advanced": ["QUIXOTIC"]]
        let service = PersonalizationService(profile: profile)

        let ordered = service.orderPage([makeWord(id: "1", word: "Quixotic")])

        XCTAssertTrue(ordered.isEmpty)
    }

    func testNilProfileFiltersNothing() {
        let service = PersonalizationService(profile: nil)
        let words = makeWords(5)

        XCTAssertEqual(service.orderPage(words).count, 5)
    }

    // MARK: - Ordering

    func testPreferredTopicsRankFirst() {
        var profile = OnboardingProfile()
        profile.topics = ["Business"]
        let service = PersonalizationService(profile: profile)

        let society = makeWord(id: "a", topics: ["society"])
        let business = makeWord(id: "b", topics: ["BUSINESS"])
        let ordered = service.orderPage([society, business])

        XCTAssertEqual(ordered.first?.id, "b", "topic matches must outrank non-matches, case-insensitively")
    }

    func testWordsClosestToAssessedLevelRankFirst() {
        // Empty knownWords assesses as beginner, so level distance is the
        // word level's own index.
        let service = PersonalizationService(profile: OnboardingProfile())

        let advanced = makeWord(id: "a", level: .advanced)
        let intermediate = makeWord(id: "i", level: .intermediate)
        let beginner = makeWord(id: "b", level: .beginner)
        let ordered = service.orderPage([advanced, intermediate, beginner])

        XCTAssertEqual(ordered.map(\.id), ["b", "i", "a"])
    }

    func testTopicMatchOutranksLevelDistance() {
        var profile = OnboardingProfile()
        profile.topics = ["emotions"]
        let service = PersonalizationService(profile: profile)

        let onLevelOffTopic = makeWord(id: "a", level: .beginner, topics: ["society"])
        let offLevelOnTopic = makeWord(id: "b", level: .advanced, topics: ["emotions"])
        let ordered = service.orderPage([onLevelOffTopic, offLevelOnTopic])

        XCTAssertEqual(ordered.first?.id, "b")
    }

    func testOrderingIsDeterministicAcrossShuffles() {
        let service = PersonalizationService(profile: OnboardingProfile())
        let words = (0..<30).map {
            makeWord(id: "word-\($0)",
                     level: WordLevel.allCases[$0 % 3],
                     topics: [$0.isMultiple(of: 2) ? "society" : "business"])
        }

        let reference = service.orderPage(words)
        for _ in 0..<5 {
            XCTAssertEqual(service.orderPage(words.shuffled()).map(\.id), reference.map(\.id))
        }
    }
}
