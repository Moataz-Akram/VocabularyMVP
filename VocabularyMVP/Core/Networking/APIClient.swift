import Foundation

protocol APIClient {
    func send<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

enum Endpoint {
    case words(page: Int, pageSize: Int)

    var path: String {
        switch self {
        case .words: "/v1/words"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .words(let page, let pageSize):
            [URLQueryItem(name: "page", value: String(page)),
             URLQueryItem(name: "pageSize", value: String(pageSize))]
        }
    }
}

enum APIError: Error {
    case invalidResponse
    case missingFixture(String)
}
