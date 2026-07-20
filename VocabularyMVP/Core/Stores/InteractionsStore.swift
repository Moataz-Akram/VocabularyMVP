import Foundation
import Observation
import SwiftData

// Single source of truth for per-word state (likes, bookmarks, seen) and collections.
@Observable
@MainActor
final class InteractionsStore {
    private(set) var collections: [WordCollection] = []
    private(set) var savedToast: (word: Word, collection: WordCollection)?

    private let context: ModelContext
    private var interactions: [String: WordInteraction] = [:]
    // Word content is owned by the feed's paged responses; loaded pages are
    // registered here so favorites and collection lists can resolve
    // wordID -> Word without depending on the feed.
    private var knownWords: [Word] = []
    private var knownWordIDs: Set<String> = []
    private var toastTask: Task<Void, Never>?
    private static let lastCollectionKey = "lastCollectionID"
    let dailyGoal = 5

    var favoriteWords: [Word] {
        knownWords.filter { isLiked($0) }
    }

    var bookmarkedTodayCount: Int {
        interactions.values.filter {
            $0.bookmarkedAt.map(Calendar.current.isDateInToday) ?? false
        }.count
    }

    init(context: ModelContext) {
        self.context = context
        let all = (try? context.fetch(FetchDescriptor<WordInteraction>())) ?? []
        interactions = Dictionary(all.map { ($0.wordID, $0) }, uniquingKeysWith: { first, _ in first })
        let descriptor = FetchDescriptor<WordCollection>(sortBy: [SortDescriptor(\.createdAt)])
        collections = (try? context.fetch(descriptor)) ?? []
    }

    func register(_ words: [Word]) {
        for word in words where knownWordIDs.insert(word.id).inserted {
            knownWords.append(word)
        }
    }

    // MARK: - Likes & seen

    func isLiked(_ word: Word) -> Bool {
        interactions[word.id]?.liked ?? false
    }

    func likedDate(_ word: Word) -> Date? {
        interactions[word.id]?.likedAt
    }

    func toggleLike(_ word: Word) {
        let interaction = interaction(for: word)
        interaction.liked.toggle()
        interaction.likedAt = interaction.liked ? .now : nil
        Haptics.selection()
    }

    func markSeen(_ word: Word) {
        interaction(for: word).seenAt = .now
    }

    // MARK: - Bookmarks & collections

    func isBookmarked(_ word: Word) -> Bool {
        interactions[word.id]?.collectionID != nil
    }

    func bookmarkedDate(_ word: Word) -> Date? {
        interactions[word.id]?.bookmarkedAt
    }

    func collection(for word: Word) -> WordCollection? {
        guard let id = interactions[word.id]?.collectionID else { return nil }
        return collections.first { $0.id == id }
    }

    func words(in collection: WordCollection) -> [Word] {
        knownWords.filter { interactions[$0.id]?.collectionID == collection.id }
    }

    // Bookmarking saves into the last-used collection (creating a default one
    // on first ever use); tapping again removes the word from its collection.
    func toggleBookmark(_ word: Word) {
        let interaction = interaction(for: word)
        if interaction.collectionID != nil {
            interaction.collectionID = nil
            interaction.bookmarkedAt = nil
            dismissToast()
            Haptics.selection()
        } else {
            let target = lastUsedCollection ?? addCollection(named: "My words")
            assign(word, to: target)
        }
    }

    func assign(_ word: Word, to collection: WordCollection) {
        let interaction = interaction(for: word)
        interaction.collectionID = collection.id
        interaction.bookmarkedAt = .now
        UserDefaults.standard.set(collection.id.uuidString, forKey: Self.lastCollectionKey)
        Haptics.selection()
        showToast(word: word, collection: collection)
    }

    @discardableResult
    func addCollection(named name: String) -> WordCollection {
        let collection = WordCollection(name: name)
        context.insert(collection)
        collections.append(collection)
        return collection
    }

    func renameCollection(_ collection: WordCollection, to name: String) {
        collection.name = name
    }

    func deleteCollection(_ collection: WordCollection) {
        for interaction in interactions.values where interaction.collectionID == collection.id {
            interaction.collectionID = nil
            interaction.bookmarkedAt = nil
        }
        collections.removeAll { $0.id == collection.id }
        context.delete(collection)
    }

    func dismissToast() {
        toastTask?.cancel()
        savedToast = nil
    }

    private var lastUsedCollection: WordCollection? {
        let lastID = UserDefaults.standard.string(forKey: Self.lastCollectionKey).flatMap(UUID.init)
        return collections.first { $0.id == lastID } ?? collections.first
    }

    private func showToast(word: Word, collection: WordCollection) {
        toastTask?.cancel()
        savedToast = (word, collection)
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            savedToast = nil
        }
    }

    // MARK: - Storage

    private func interaction(for word: Word) -> WordInteraction {
        if let existing = interactions[word.id] { return existing }
        let interaction = WordInteraction(wordID: word.id)
        context.insert(interaction)
        interactions[word.id] = interaction
        return interaction
    }
}
