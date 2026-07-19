//
//  VocabularyMVPTests.swift
//  VocabularyMVPTests
//
//  Created by Moataz Akram on 16/07/2026.
//

import XCTest
@testable import VocabularyMVP

// The bundled words.json is the app's entire data source, so a malformed
// entry breaks the feed at runtime. These tests keep the fixture honest.
final class WordFixtureTests: XCTestCase {

    func testFixtureDecodesAndFieldsAreComplete() throws {
        let words = try loadFixtureWords()

        XCTAssertFalse(words.isEmpty)
        // Every field except `word` is optional in the model; the curated
        // fixture must still fill them all in (nil counts as missing).
        for word in words {
            XCTAssertFalse(word.word.isEmpty, "\(word.id): empty word")
            XCTAssertFalse(word.phonetic?.isEmpty ?? true, "\(word.id): missing phonetic")
            XCTAssertFalse(word.partOfSpeech?.isEmpty ?? true, "\(word.id): missing partOfSpeech")
            XCTAssertFalse(word.definition?.isEmpty ?? true, "\(word.id): missing definition")
            XCTAssertFalse(word.examples?.isEmpty ?? true, "\(word.id): no examples")
            XCTAssertFalse(word.origin?.isEmpty ?? true, "\(word.id): missing origin")
            XCTAssertFalse(word.topics?.isEmpty ?? true, "\(word.id): no topics")
        }
    }

    func testFixtureIDsAreUnique() throws {
        let ids = try loadFixtureWords().map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testFixtureCoversEveryLevel() throws {
        let levels = Set(try loadFixtureWords().compactMap(\.level))
        XCTAssertEqual(levels, Set(WordLevel.allCases))
    }
}
