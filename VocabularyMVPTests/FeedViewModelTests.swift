import SwiftData
import XCTest
@testable import VocabularyMVP

@MainActor
final class FeedViewModelTests: XCTestCase {
    private var defaultsSnapshot: [String: Any] = [:]
    private var container: ModelContainer!
    private var context: ModelContext!
    private var client: StubAPIClient!

    override func setUp() async throws {
        defaultsSnapshot = TestDefaults.snapshotAndClear()
        container = try ModelContainer(
            for: WordCollection.self, WordInteraction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        client = StubAPIClient()
    }

    override func tearDown() {
        TestDefaults.restore(defaultsSnapshot)
        client = nil
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
        await viewModel.start(context: context)
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
        await viewModel.start(context: context)

        XCTAssertEqual(client.sendCount, 1)
        XCTAssertEqual(viewModel.words.count, 5)
    }

    func testLoadFailureSetsFlagAndRetryRecovers() async {
        client.failuresRemaining = 1
        client.pages[1] = WordsPage(words: makeWords(4), page: 1, hasMore: false)
        let viewModel = makeViewModel()

        await viewModel.start(context: context)
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

    // MARK: - Likes

    func testToggleLike() async {
        let viewModel = await startedViewModel()
        let word = viewModel.words[0]

        viewModel.toggleLike(word)
        XCTAssertTrue(viewModel.isLiked(word))
        XCTAssertNotNil(viewModel.likedDate(word))
        XCTAssertEqual(viewModel.favoriteWords.map(\.id), [word.id])

        viewModel.toggleLike(word)
        XCTAssertFalse(viewModel.isLiked(word))
        XCTAssertNil(viewModel.likedDate(word))
        XCTAssertTrue(viewModel.favoriteWords.isEmpty)
    }

    func testInteractionsPersistAcrossViewModelInstances() async {
        let first = await startedViewModel()
        let word = first.words[0]
        first.toggleLike(word)

        let second = makeViewModel()
        await second.start(context: context)

        XCTAssertTrue(second.isLiked(word))
    }

    // MARK: - Bookmarks & collections

    func testFirstBookmarkCreatesDefaultCollection() async {
        let viewModel = await startedViewModel()
        let word = viewModel.words[0]

        viewModel.toggleBookmark(word)

        XCTAssertEqual(viewModel.collections.map(\.name), ["My words"])
        XCTAssertTrue(viewModel.isBookmarked(word))
        XCTAssertNotNil(viewModel.bookmarkedDate(word))
        XCTAssertEqual(viewModel.collection(for: word)?.name, "My words")
        XCTAssertEqual(viewModel.words(in: viewModel.collections[0]).map(\.id), [word.id])
        XCTAssertEqual(viewModel.bookmarkedTodayCount, 1)
        XCTAssertEqual(viewModel.savedToast?.word.id, word.id)
    }

    func testToggleBookmarkOffRemovesFromCollection() async {
        let viewModel = await startedViewModel()
        let word = viewModel.words[0]

        viewModel.toggleBookmark(word)
        viewModel.toggleBookmark(word)

        XCTAssertFalse(viewModel.isBookmarked(word))
        XCTAssertNil(viewModel.bookmarkedDate(word))
        XCTAssertNil(viewModel.savedToast)
        XCTAssertEqual(viewModel.collections.count, 1, "the collection itself must survive")
        XCTAssertTrue(viewModel.words(in: viewModel.collections[0]).isEmpty)
    }

    func testBookmarkReusesLastUsedCollection() async {
        let viewModel = await startedViewModel()
        viewModel.addCollection(named: "First")
        let second = viewModel.addCollection(named: "Second")

        viewModel.assign(viewModel.words[0], to: second)
        viewModel.toggleBookmark(viewModel.words[1])

        XCTAssertEqual(viewModel.collection(for: viewModel.words[1])?.name, "Second")
    }

    func testRenameCollection() async {
        let viewModel = await startedViewModel()
        let collection = viewModel.addCollection(named: "Old")

        viewModel.renameCollection(collection, to: "New")

        XCTAssertEqual(viewModel.collections.map(\.name), ["New"])
    }

    func testDeleteCollectionClearsItsBookmarks() async {
        let viewModel = await startedViewModel()
        let collection = viewModel.addCollection(named: "Doomed")
        viewModel.assign(viewModel.words[0], to: collection)

        viewModel.deleteCollection(collection)

        XCTAssertTrue(viewModel.collections.isEmpty)
        XCTAssertFalse(viewModel.isBookmarked(viewModel.words[0]))
        XCTAssertNil(viewModel.bookmarkedDate(viewModel.words[0]))
    }

    func testBookmarkedTodayCountIgnoresOlderBookmarks() async throws {
        // Seed an interaction bookmarked yesterday before the view model loads.
        let stale = WordInteraction(wordID: "stale")
        stale.collectionID = UUID()
        stale.bookmarkedAt = Calendar.current.date(byAdding: .day, value: -1, to: .now)
        context.insert(stale)

        let viewModel = await startedViewModel()
        XCTAssertEqual(viewModel.bookmarkedTodayCount, 0)

        viewModel.toggleBookmark(viewModel.words[0])
        XCTAssertEqual(viewModel.bookmarkedTodayCount, 1)
    }

    func testDismissToast() async {
        let viewModel = await startedViewModel()
        viewModel.toggleBookmark(viewModel.words[0])
        XCTAssertNotNil(viewModel.savedToast)

        viewModel.dismissToast()
        XCTAssertNil(viewModel.savedToast)
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
