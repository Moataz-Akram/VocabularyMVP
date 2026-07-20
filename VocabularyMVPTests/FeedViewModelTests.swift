import SwiftData
import XCTest
@testable import VocabularyMVP

@MainActor
final class FeedViewModelTests: XCTestCase {
    private var defaultsSnapshot: [String: Any] = [:]
    private var container: ModelContainer!
    private var context: ModelContext!
    private var store: InteractionsStore!
    private var client: StubAPIClient!

    override func setUp() async throws {
        defaultsSnapshot = TestDefaults.snapshotAndClear()
        container = try ModelContainer(
            for: WordCollection.self, WordInteraction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        store = InteractionsStore(context: context)
        client = StubAPIClient()
    }

    override func tearDown() {
        TestDefaults.restore(defaultsSnapshot)
        client = nil
        store = nil
        context = nil
        container = nil
    }

    private func makeViewModel() -> FeedViewModel {
        FeedViewModel(repository: WordRepository(client: client))
    }

    /// Starts a view model on a single already-stubbed page of `count` words.
    private func startedViewModel(wordCount: Int = 5, hasMore: Bool = false) async -> FeedViewModel {
        client.pages[1] = WordsPage(words: makeWords(wordCount), page: 1, hasMore: hasMore)
        let viewModel = makeViewModel()
        await viewModel.start(interactions: store)
        return viewModel
    }

    // MARK: - Loading

    func testStartLoadsFirstPage() async {
        let viewModel = await startedViewModel(wordCount: 5)

        XCTAssertEqual(Set(viewModel.words.map(\.id)), Set(makeWords(5).map(\.id)))
        XCTAssertFalse(viewModel.isLoadingInitial)
        XCTAssertFalse(viewModel.loadFailed)
    }

    func testStartIsIdempotent() async {
        let viewModel = await startedViewModel(wordCount: 5)
        await viewModel.start(interactions: store)

        XCTAssertEqual(client.sendCount, 1)
        XCTAssertEqual(viewModel.words.count, 5)
    }

    func testStartRegistersWordsWithStore() async {
        let viewModel = await startedViewModel(wordCount: 5)

        store.toggleLike(viewModel.words[0])

        XCTAssertEqual(store.favoriteWords.map(\.id), [viewModel.words[0].id])
    }

    func testLoadFailureSetsFlagAndRetryRecovers() async {
        client.failuresRemaining = 1
        client.pages[1] = WordsPage(words: makeWords(4), page: 1, hasMore: false)
        let viewModel = makeViewModel()

        await viewModel.start(interactions: store)
        XCTAssertTrue(viewModel.loadFailed)
        XCTAssertTrue(viewModel.words.isEmpty)

        await viewModel.retry()
        XCTAssertFalse(viewModel.loadFailed)
        XCTAssertEqual(viewModel.words.count, 4)
    }

    func testLoadMoreNearEndFetchesNextPage() async {
        client.pages[2] = WordsPage(words: makeWords(3, prefix: "extra"), page: 2, hasMore: false)
        let viewModel = await startedViewModel(wordCount: 5, hasMore: true)

        viewModel.loadMoreIfNeeded(nearWordID: viewModel.words.last?.id)
        await waitUntil { viewModel.words.count == 8 }

        XCTAssertEqual(viewModel.words.count, 8)
        XCTAssertEqual(client.requests.map { $0.page }, [1, 2])
    }

    func testLoadMoreFarFromEndDoesNothing() async {
        let viewModel = await startedViewModel(wordCount: 10, hasMore: true)

        viewModel.loadMoreIfNeeded(nearWordID: viewModel.words.first?.id)
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(client.sendCount, 1)
    }

    func testLoadMoreStopsWhenNoMorePages() async {
        let viewModel = await startedViewModel(wordCount: 5, hasMore: false)

        viewModel.loadMoreIfNeeded(nearWordID: viewModel.words.last?.id)
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(client.sendCount, 1)
    }

    // MARK: - Seen tracking

    func testMarkSeenPersistsInteraction() async throws {
        let viewModel = await startedViewModel()
        let word = viewModel.words[0]

        viewModel.markSeen(wordID: word.id)

        let interactions = try context.fetch(FetchDescriptor<WordInteraction>())
        XCTAssertNotNil(interactions.first { $0.wordID == word.id }?.seenAt)
    }

    func testMarkSeenIgnoresUnknownAndNilIDs() async throws {
        let viewModel = await startedViewModel()

        viewModel.markSeen(wordID: nil)
        viewModel.markSeen(wordID: "not-in-feed")

        XCTAssertTrue(try context.fetch(FetchDescriptor<WordInteraction>()).isEmpty)
    }
}
