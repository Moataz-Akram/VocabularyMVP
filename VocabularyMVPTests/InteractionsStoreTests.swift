import SwiftData
import XCTest
@testable import VocabularyMVP

@MainActor
final class InteractionsStoreTests: XCTestCase {
    private var defaultsSnapshot: [String: Any] = [:]
    private var container: ModelContainer!
    private var context: ModelContext!
    private var store: InteractionsStore!
    private var words: [Word]!

    override func setUp() async throws {
        defaultsSnapshot = TestDefaults.snapshotAndClear()
        container = try ModelContainer(
            for: WordCollection.self, WordInteraction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        words = makeWords(5)
        store = makeStore()
    }

    override func tearDown() {
        TestDefaults.restore(defaultsSnapshot)
        words = nil
        store = nil
        context = nil
        container = nil
    }

    /// Builds a store on the shared context with the test words registered,
    /// the same way the feed registers its loaded pages.
    private func makeStore() -> InteractionsStore {
        let store = InteractionsStore(context: context)
        store.register(words)
        return store
    }

    // MARK: - Likes

    func testToggleLike() {
        let word = words[0]

        store.toggleLike(word)
        XCTAssertTrue(store.isLiked(word))
        XCTAssertNotNil(store.likedDate(word))
        XCTAssertEqual(store.favoriteWords.map(\.id), [word.id])

        store.toggleLike(word)
        XCTAssertFalse(store.isLiked(word))
        XCTAssertNil(store.likedDate(word))
        XCTAssertTrue(store.favoriteWords.isEmpty)
    }

    func testInteractionsPersistAcrossStoreInstances() {
        store.toggleLike(words[0])

        let second = makeStore()

        XCTAssertTrue(second.isLiked(words[0]))
    }

    func testRegisterIgnoresDuplicates() {
        store.register(words)
        store.toggleLike(words[0])

        XCTAssertEqual(store.favoriteWords.map(\.id), [words[0].id])
    }

    // MARK: - Bookmarks & collections

    func testFirstBookmarkCreatesDefaultCollection() {
        let word = words[0]

        store.toggleBookmark(word)

        XCTAssertEqual(store.collections.map(\.name), ["My words"])
        XCTAssertTrue(store.isBookmarked(word))
        XCTAssertNotNil(store.bookmarkedDate(word))
        XCTAssertEqual(store.collection(for: word)?.name, "My words")
        XCTAssertEqual(store.words(in: store.collections[0]).map(\.id), [word.id])
        XCTAssertEqual(store.bookmarkedTodayCount, 1)
        XCTAssertEqual(store.savedToast?.word.id, word.id)
    }

    func testToggleBookmarkOffRemovesFromCollection() {
        let word = words[0]

        store.toggleBookmark(word)
        store.toggleBookmark(word)

        XCTAssertFalse(store.isBookmarked(word))
        XCTAssertNil(store.bookmarkedDate(word))
        XCTAssertNil(store.savedToast)
        XCTAssertEqual(store.collections.count, 1, "the collection itself must survive")
        XCTAssertTrue(store.words(in: store.collections[0]).isEmpty)
    }

    func testBookmarkReusesLastUsedCollection() {
        store.addCollection(named: "First")
        let second = store.addCollection(named: "Second")

        store.assign(words[0], to: second)
        store.toggleBookmark(words[1])

        XCTAssertEqual(store.collection(for: words[1])?.name, "Second")
    }

    func testRenameCollection() {
        let collection = store.addCollection(named: "Old")

        store.renameCollection(collection, to: "New")

        XCTAssertEqual(store.collections.map(\.name), ["New"])
    }

    func testDeleteCollectionClearsItsBookmarks() {
        let collection = store.addCollection(named: "Doomed")
        store.assign(words[0], to: collection)

        store.deleteCollection(collection)

        XCTAssertTrue(store.collections.isEmpty)
        XCTAssertFalse(store.isBookmarked(words[0]))
        XCTAssertNil(store.bookmarkedDate(words[0]))
    }

    func testBookmarkedTodayCountIgnoresOlderBookmarks() {
        // Seed an interaction bookmarked yesterday before the store loads.
        let stale = WordInteraction(wordID: "stale")
        stale.collectionID = UUID()
        stale.bookmarkedAt = Calendar.current.date(byAdding: .day, value: -1, to: .now)
        context.insert(stale)

        let store = makeStore()
        XCTAssertEqual(store.bookmarkedTodayCount, 0)

        store.toggleBookmark(words[0])
        XCTAssertEqual(store.bookmarkedTodayCount, 1)
    }

    func testDismissToast() {
        store.toggleBookmark(words[0])
        XCTAssertNotNil(store.savedToast)

        store.dismissToast()
        XCTAssertNil(store.savedToast)
    }

    // MARK: - Seen tracking

    func testMarkSeenPersistsInteraction() throws {
        store.markSeen(words[0])

        let interactions = try context.fetch(FetchDescriptor<WordInteraction>())
        XCTAssertNotNil(interactions.first { $0.wordID == words[0].id }?.seenAt)
    }
}
