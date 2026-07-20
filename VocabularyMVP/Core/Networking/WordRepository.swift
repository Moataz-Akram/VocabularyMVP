import Foundation

struct WordRepository {
    let client: APIClient

    func words(page: Int, pageSize: Int = 20) async throws -> WordsPage {
        try await client.send(.words(page: page, pageSize: pageSize))
    }
}
