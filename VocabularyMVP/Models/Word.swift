import Foundation

struct Word: Codable, Identifiable, Hashable {
    let word: String
    let phonetic: String?
    let partOfSpeech: String?
    let definition: String?
    let examples: [String]?
    let synonyms: [String]?
    let origin: String?
    let level: WordLevel?
    let topics: [String]?

    var id: String { word }

    // "(adj.) Lasting for a very short time" — omits whichever parts are missing.
    var definitionLine: String? {
        let parts = [partOfSpeech.map { "(\($0))" }, definition].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

struct WordsPage: Codable {
    let words: [Word]
    let page: Int
    let hasMore: Bool
}
