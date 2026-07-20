import Foundation

// Serves bundled JSON fixtures with simulated latency so the app exercises the
// same async loading paths it would against a real backend. Swap for
// URLSessionAPIClient at the injection point once a backend exists.
struct MockAPIClient: APIClient {
    var latency: Duration = .milliseconds(300)

    func send<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        try await Task.sleep(for: latency)
        return try JSONDecoder().decode(T.self, from: responseData(for: endpoint))
    }

    private func responseData(for endpoint: Endpoint) throws -> Data {
        switch endpoint {
        case .words(let page, let pageSize):
            let all = try fixture("words", as: [Word].self)
            let start = (page - 1) * pageSize
            let slice = Array(all.dropFirst(start).prefix(pageSize))
            let response = WordsPage(words: slice, page: page, hasMore: start + slice.count < all.count)
            return try JSONEncoder().encode(response)
        }
    }

    private func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw APIError.missingFixture(name)
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
