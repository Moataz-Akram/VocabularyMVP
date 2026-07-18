import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class FeedViewModel {
    private(set) var words: [Word] = []
    private(set) var isLoadingInitial = false
    private(set) var loadFailed = false

    let voiceID: String?

    private let repository: WordRepository
    private let personalization: PersonalizationService
    private var interactions: [String: WordInteraction] = [:]
    private var context: ModelContext?
    private var page = 0
    private var hasMore = true
    private var isLoadingPage = false

    init(repository: WordRepository = WordRepository(client: MockAPIClient())) {
        let profile = OnboardingProfile.load()
        self.repository = repository
        self.personalization = PersonalizationService(profile: profile)
        self.voiceID = profile?.voiceID
    }

    func start(context: ModelContext) async {
        guard words.isEmpty else { return }
        self.context = context
        loadInteractions()
        await loadNextPage()
    }

    func retry() async {
        await loadNextPage()
    }

    func loadMoreIfNeeded(nearWordID wordID: String?) {
        guard let wordID, let index = words.firstIndex(where: { $0.id == wordID }),
              index >= words.count - 3
        else { return }
        Task { await loadNextPage() }
    }

    private func loadNextPage() async {
        guard !isLoadingPage, hasMore else { return }
        isLoadingPage = true
        isLoadingInitial = words.isEmpty
        loadFailed = false
        do {
            let response = try await repository.words(page: page + 1)
            page = response.page
            hasMore = response.hasMore
            words += personalization.orderPage(response.words)
        } catch {
            loadFailed = true
        }
        isLoadingPage = false
        isLoadingInitial = false
    }

    // MARK: - Interactions

    var favoriteWords: [Word] {
        words.filter { isLiked($0) }
    }

    func isLiked(_ word: Word) -> Bool {
        interactions[word.id]?.liked ?? false
    }

    func isBookmarked(_ word: Word) -> Bool {
        interactions[word.id]?.collectionID != nil
    }

    func likedDate(_ word: Word) -> Date? {
        interactions[word.id]?.likedAt
    }

    func bookmarkedDate(_ word: Word) -> Date? {
        interactions[word.id]?.bookmarkedAt
    }

    func toggleLike(_ word: Word) {
        let interaction = interaction(for: word)
        interaction.liked.toggle()
        interaction.likedAt = interaction.liked ? .now : nil
        Haptics.selection()
    }

    func markSeen(wordID: String?) {
        guard let wordID, let word = words.first(where: { $0.id == wordID }) else { return }
        interaction(for: word).seenAt = .now
    }

    // MARK: - Collections

    private(set) var collections: [WordCollection] = []
    private(set) var savedToast: (word: Word, collection: WordCollection)?

    let dailyGoal = 5
    private var toastTask: Task<Void, Never>?
    private static let lastCollectionKey = "lastCollectionID"

    var bookmarkedTodayCount: Int {
        interactions.values.filter {
            $0.bookmarkedAt.map(Calendar.current.isDateInToday) ?? false
        }.count
    }

    func collection(for word: Word) -> WordCollection? {
        guard let id = interactions[word.id]?.collectionID else { return nil }
        return collections.first { $0.id == id }
    }

    func words(in collection: WordCollection) -> [Word] {
        words.filter { interactions[$0.id]?.collectionID == collection.id }
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
        context?.insert(collection)
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
        context?.delete(collection)
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
        context?.insert(interaction)
        interactions[word.id] = interaction
        return interaction
    }

    private func loadInteractions() {
        guard let context else { return }
        let all = (try? context.fetch(FetchDescriptor<WordInteraction>())) ?? []
        interactions = Dictionary(all.map { ($0.wordID, $0) }, uniquingKeysWith: { first, _ in first })
        let descriptor = FetchDescriptor<WordCollection>(sortBy: [SortDescriptor(\.createdAt)])
        collections = (try? context.fetch(descriptor)) ?? []
    }
}
