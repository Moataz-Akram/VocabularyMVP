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

    var bookmarkedWords: [Word] {
        words.filter { isBookmarked($0) }
    }

    func isLiked(_ word: Word) -> Bool {
        interactions[word.id]?.liked ?? false
    }

    func isBookmarked(_ word: Word) -> Bool {
        interactions[word.id]?.bookmarked ?? false
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

    func toggleBookmark(_ word: Word) {
        interaction(for: word).bookmarked.toggle()
        Haptics.selection()
    }

    func markSeen(wordID: String?) {
        guard let wordID, let word = words.first(where: { $0.id == wordID }) else { return }
        interaction(for: word).seenAt = .now
    }

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
    }
}
