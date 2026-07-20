import XCTest
@testable import VocabularyMVP

final class OnboardingProfileTests: XCTestCase {
    private var defaultsSnapshot: [String: Any] = [:]

    override func setUp() {
        defaultsSnapshot = TestDefaults.snapshotAndClear()
    }

    override func tearDown() {
        TestDefaults.restore(defaultsSnapshot)
    }

    func testLoadReturnsNilWhenNothingSaved() {
        XCTAssertNil(OnboardingProfile.load())
    }

    func testSaveThenLoadRoundTrips() throws {
        var profile = OnboardingProfile()
        profile.name = "Moataz"
        profile.topics = ["Business", "Emotions"]
        profile.voiceID = "com.apple.voice.test"
        profile.knownWords = ["beginner": ["whisper"]]
        profile.save()

        let loaded = try XCTUnwrap(OnboardingProfile.load())
        XCTAssertEqual(loaded.name, "Moataz")
        XCTAssertEqual(loaded.topics, ["Business", "Emotions"])
        XCTAssertEqual(loaded.voiceID, "com.apple.voice.test")
        XCTAssertEqual(loaded.knownWords, ["beginner": ["whisper"]])
    }

    func testWordLevelTitles() {
        XCTAssertEqual(WordLevel.beginner.title, "Beginner")
        XCTAssertEqual(WordLevel.intermediate.title, "Intermediate")
        XCTAssertEqual(WordLevel.advanced.title, "Advanced")
    }
}

final class OnboardingCoordinatorTests: XCTestCase {
    private var defaultsSnapshot: [String: Any] = [:]

    override func setUp() {
        defaultsSnapshot = TestDefaults.snapshotAndClear()
    }

    override func tearDown() {
        TestDefaults.restore(defaultsSnapshot)
    }

    func testStartsAtFirstStep() {
        let coordinator = OnboardingCoordinator()
        XCTAssertEqual(coordinator.stepIndex, 0)
        XCTAssertEqual(coordinator.currentStep.id, coordinator.steps.first?.id)
    }

    func testAdvanceWalksEveryStepWithoutFinishing() {
        let coordinator = OnboardingCoordinator()
        for _ in 0..<(coordinator.steps.count - 1) {
            coordinator.advance()
        }
        XCTAssertEqual(coordinator.stepIndex, coordinator.steps.count - 1)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: OnboardingProfile.hasCompletedOnboardingKey))
    }

    func testAdvanceOnLastStepFinishesAndPersistsProfile() throws {
        let coordinator = OnboardingCoordinator()
        coordinator.profile.name = "Tester"
        for _ in 0..<coordinator.steps.count {
            coordinator.advance()
        }

        XCTAssertEqual(coordinator.stepIndex, coordinator.steps.count - 1,
                       "finishing must not advance past the last step")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: OnboardingProfile.hasCompletedOnboardingKey))
        XCTAssertEqual(try XCTUnwrap(OnboardingProfile.load()).name, "Tester")
    }
}

final class OnboardingFlowTests: XCTestCase {
    func testStepIDsAreUnique() {
        let ids = OnboardingFlow.steps.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testSelectStepsOfferAtLeastTwoOptions() {
        for step in OnboardingFlow.steps {
            switch step.template {
            case .singleSelect(_, let options, _), .multiSelect(_, let options, _):
                XCTAssertGreaterThanOrEqual(options.count, 2, "step \(step.id)")
            default:
                break
            }
        }
    }

    func testWordTestsCoverEveryLevel() {
        var testedLevels: Set<WordLevel> = []
        for step in OnboardingFlow.steps {
            if case .wordTest(let level, let words) = step.template {
                testedLevels.insert(level)
                XCTAssertFalse(words.isEmpty, "step \(step.id) has no words")
            }
        }
        XCTAssertEqual(testedLevels, Set(WordLevel.allCases))
    }
}
