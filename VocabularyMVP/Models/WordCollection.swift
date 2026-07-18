import Foundation
import SwiftData

@Model
final class WordCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    init(name: String) {
        id = UUID()
        self.name = name
        createdAt = .now
    }
}
