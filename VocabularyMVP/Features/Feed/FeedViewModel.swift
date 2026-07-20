import Foundation
import Observation

@Observable
@MainActor
final class FeedViewModel {
    private(set) var words: [Word] = []
    private(set) var isLoadingInitial = false
    private(set) var loadFailed = false

    private let repository: WordRepository
    private var interactions: InteractionsStore?
    private var page = 0
    private var hasMore = true
    private var isLoadingPage = false

    //TODO: in production we will use the real APIClient instead of MockAPIClient
    init(repository: WordRepository = WordRepository(client: MockAPIClient())) {
        self.repository = repository
    }

    func start(interactions: InteractionsStore) async {
        guard words.isEmpty else { return }
        self.interactions = interactions
        await loadNextPage()
    }

    func retry() async {
        await loadNextPage()
    }

    func markSeen(wordID: String?) {
        guard let wordID, let word = words.first(where: { $0.id == wordID }) else { return }
        interactions?.markSeen(word)
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
            words += response.words
            interactions?.register(response.words)
        } catch {
            loadFailed = true
        }
        isLoadingPage = false
        isLoadingInitial = false
    }
}
