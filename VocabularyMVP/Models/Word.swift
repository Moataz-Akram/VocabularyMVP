import Foundation

struct Word: Codable, Identifiable, Hashable {
    let id: String
    let word: String
    let phonetic: String
    let partOfSpeech: String
    let definition: String
    let examples: [String]
    let synonyms: [String]
    let origin: String
    let level: WordLevel
    let topics: [String]
}

struct WordsPage: Codable {
    let words: [Word]
    let page: Int
    let hasMore: Bool
}
