import Foundation
import SwiftData

@Model
final class PostDraft {
    var text: String
    var imageFilenames: [String]
    var createdAt: Date
    var updatedAt: Date

    init(text: String, imageFilenames: [String] = []) {
        self.text = text
        self.imageFilenames = imageFilenames
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
