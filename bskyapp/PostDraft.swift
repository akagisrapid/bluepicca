import Foundation
import SwiftData

@Model
final class PostDraft {
    var text: String
    var createdAt: Date
    var updatedAt: Date

    init(text: String) {
        self.text = text
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
