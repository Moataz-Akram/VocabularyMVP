import Foundation
import SwiftData

@Model
final class WordInteraction {
    @Attribute(.unique) var wordID: String
    var liked = false
    var likedAt: Date?
    var bookmarked = false
    var seenAt: Date?

    init(wordID: String) {
        self.wordID = wordID
    }
}
