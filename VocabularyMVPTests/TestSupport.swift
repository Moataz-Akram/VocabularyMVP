import Foundation
import XCTest
@testable import VocabularyMVP

// MARK: - Word factory

func makeWord(_ word: String) -> Word {
    Word(word: word,
         phonetic: "/test/",
         partOfSpeech: "n.",
         definition: "definition of \(word)",
         examples: ["Example using \(word)."],
         synonyms: [],
         origin: "test",
         level: .beginner,
         topics: [])
}

func makeWords(_ count: Int, prefix: String = "word") -> [Word] {
    (0..<count).map { makeWord("\(prefix)-\($0)") }
}

// MARK: - Stub API client

// Serves canned WordsPage responses keyed by page number, recording every
// request so tests can assert call counts and pass-through parameters.
final class StubAPIClient: APIClient {
    var pages: [Int: WordsPage] = [:]
    var failuresRemaining = 0
    private(set) var requests: [(page: Int, pageSize: Int)] = []

    var sendCount: Int { requests.count }

    func send<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        switch endpoint {
        case .words(let page, let pageSize):
            requests.append((page, pageSize))
            if failuresRemaining > 0 {
                failuresRemaining -= 1
                throw APIError.invalidResponse
            }
            guard let response = pages[page] else { throw APIError.invalidResponse }
            let data = try JSONEncoder().encode(response)
            return try JSONDecoder().decode(T.self, from: data)
        }
    }
}

// MARK: - UserDefaults isolation

// The app persists onboarding and bookmarking state in UserDefaults.standard,
// and tests run hosted inside the app. Snapshot the app's keys before a test
// and restore them after so test runs never leak into (or depend on) whatever
// state the simulator already has.
enum TestDefaults {
    static let keys = [
        "onboardingProfile",
        OnboardingProfile.hasCompletedOnboardingKey,
        "lastCollectionID",
    ]

    static func snapshotAndClear() -> [String: Any] {
        let defaults = UserDefaults.standard
        var snapshot: [String: Any] = [:]
        for key in keys {
            if let value = defaults.object(forKey: key) { snapshot[key] = value }
            defaults.removeObject(forKey: key)
        }
        return snapshot
    }

    static func restore(_ snapshot: [String: Any]) {
        let defaults = UserDefaults.standard
        for key in keys {
            if let value = snapshot[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}

// MARK: - Async polling

// Waits for a condition produced by an unstructured Task the test cannot
// await directly (e.g. FeedViewModel.loadMoreIfNeeded).
@MainActor
func waitUntil(timeout: TimeInterval = 2,
               _ condition: () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        try? await Task.sleep(for: .milliseconds(10))
    }
}

// Loads the bundled words fixture the same way the app does.
func loadFixtureWords() throws -> [Word] {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "words", withExtension: "json"),
                            "words.json missing from app bundle")
    return try JSONDecoder().decode([Word].self, from: Data(contentsOf: url))
}
