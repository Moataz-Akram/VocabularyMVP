import Foundation

// Production implementation; not selected while the app runs on fixtures.
struct URLSessionAPIClient: APIClient {
    let baseURL: URL
    var session: URLSession = .shared

    func send<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        var components = URLComponents(url: baseURL.appending(path: endpoint.path),
                                       resolvingAgainstBaseURL: false)
        components?.queryItems = endpoint.queryItems
        guard let url = components?.url else { throw APIError.invalidResponse }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
