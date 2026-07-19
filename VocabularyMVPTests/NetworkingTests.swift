import XCTest
@testable import VocabularyMVP

final class EndpointTests: XCTestCase {
    func testWordsEndpointPathAndQuery() {
        let endpoint = Endpoint.words(page: 2, pageSize: 30)

        XCTAssertEqual(endpoint.path, "/v1/words")
        XCTAssertEqual(endpoint.queryItems, [
            URLQueryItem(name: "page", value: "2"),
            URLQueryItem(name: "pageSize", value: "30"),
        ])
    }
}

final class WordRepositoryTests: XCTestCase {
    func testPassesPageAndDefaultPageSizeToClient() async throws {
        let client = StubAPIClient()
        client.pages[3] = WordsPage(words: [], page: 3, hasMore: false)

        _ = try await WordRepository(client: client).words(page: 3)

        XCTAssertEqual(client.requests.map { $0.page }, [3])
        XCTAssertEqual(client.requests.map { $0.pageSize }, [20])
    }

    func testPassesCustomPageSizeToClient() async throws {
        let client = StubAPIClient()
        client.pages[1] = WordsPage(words: [], page: 1, hasMore: false)

        _ = try await WordRepository(client: client).words(page: 1, pageSize: 5)

        XCTAssertEqual(client.requests.map { $0.pageSize }, [5])
    }
}

final class MockAPIClientTests: XCTestCase {
    private let client = MockAPIClient(latency: .zero)

    func testFirstPageReturnsPageSizeWordsInFixtureOrder() async throws {
        let fixture = try loadFixtureWords()
        let page: WordsPage = try await client.send(.words(page: 1, pageSize: 20))

        XCTAssertEqual(page.page, 1)
        XCTAssertEqual(page.words.map(\.id), fixture.prefix(20).map(\.id))
        XCTAssertTrue(page.hasMore)
    }

    func testPaginationCoversFixtureExactlyOnce() async throws {
        let fixture = try loadFixtureWords()
        var collected: [Word] = []
        var page = 0
        var hasMore = true
        while hasMore {
            page += 1
            let response: WordsPage = try await client.send(.words(page: page, pageSize: 20))
            collected += response.words
            hasMore = response.hasMore
            XCTAssertLessThan(page, 50, "pagination must terminate")
        }

        XCTAssertEqual(collected.map(\.id), fixture.map(\.id))
    }

    func testPageBeyondEndIsEmptyWithNoMore() async throws {
        let page: WordsPage = try await client.send(.words(page: 99, pageSize: 20))

        XCTAssertTrue(page.words.isEmpty)
        XCTAssertFalse(page.hasMore)
    }
}

// Intercepts every request of an ephemeral URLSession so the production
// client's URL building, status handling, and decoding run without a network.
final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw APIError.invalidResponse }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}

final class URLSessionAPIClientTests: XCTestCase {
    private var client: URLSessionAPIClient!

    override func setUp() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        client = URLSessionAPIClient(baseURL: URL(string: "https://api.example.com")!,
                                     session: URLSession(configuration: configuration))
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
    }

    private static func response(for request: URLRequest, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    func testBuildsURLAndDecodesResponse() async throws {
        let expected = WordsPage(words: makeWords(2), page: 1, hasMore: false)
        var requestedURL: URL?
        StubURLProtocol.handler = { request in
            requestedURL = request.url
            return (Self.response(for: request, status: 200), try JSONEncoder().encode(expected))
        }

        let page: WordsPage = try await client.send(.words(page: 1, pageSize: 20))

        XCTAssertEqual(requestedURL?.absoluteString,
                       "https://api.example.com/v1/words?page=1&pageSize=20")
        XCTAssertEqual(page.words.map(\.id), expected.words.map(\.id))
    }

    func testNon2xxStatusThrowsInvalidResponse() async {
        StubURLProtocol.handler = { request in
            (Self.response(for: request, status: 500), Data())
        }

        do {
            let _: WordsPage = try await client.send(.words(page: 1, pageSize: 20))
            XCTFail("expected invalidResponse")
        } catch APIError.invalidResponse {
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testMalformedBodyThrowsDecodingError() async {
        StubURLProtocol.handler = { request in
            (Self.response(for: request, status: 200), Data("not json".utf8))
        }

        do {
            let _: WordsPage = try await client.send(.words(page: 1, pageSize: 20))
            XCTFail("expected a decoding error")
        } catch is DecodingError {
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
