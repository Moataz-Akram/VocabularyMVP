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
        for word in words {
            XCTAssertFalse(word.word.isEmpty, "\(word.id): empty word")
            XCTAssertFalse(word.phonetic.isEmpty, "\(word.id): empty phonetic")
            XCTAssertFalse(word.partOfSpeech.isEmpty, "\(word.id): empty partOfSpeech")
            XCTAssertFalse(word.definition.isEmpty, "\(word.id): empty definition")
            XCTAssertFalse(word.examples.isEmpty, "\(word.id): no examples")
            XCTAssertFalse(word.origin.isEmpty, "\(word.id): empty origin")
            XCTAssertFalse(word.topics.isEmpty, "\(word.id): no topics")
        }
    }

    func testFixtureIDsAreUnique() throws {
        let ids = try loadFixtureWords().map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testFixtureCoversEveryLevel() throws {
        let levels = Set(try loadFixtureWords().map(\.level))
        XCTAssertEqual(levels, Set(WordLevel.allCases))
    }
}
