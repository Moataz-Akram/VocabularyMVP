import Foundation
import SwiftData

@Model
final class WordInteraction {
    @Attribute(.unique) var wordID: String
    var liked = false
    var likedAt: Date?
    var collectionID: UUID?
    var bookmarkedAt: Date?
    var seenAt: Date?

    init(wordID: String) {
        self.wordID = wordID
    }
}
