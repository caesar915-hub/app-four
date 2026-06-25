import Foundation
import SwiftData

enum TagSource: String, Codable {
    case nlp
    case user
    case userCorrected
}

enum TagCategory: String, Codable {
    case mood
    case energy
    case focus
    case medication
    case emotions
}

@Model final class RecordingTag {
    var id: UUID
    var name: String
    var category: String
    var source: String
    var confidence: Double?
    var createdAt: Date

    var recording: Recording?

    init(
        id: UUID = UUID(),
        name: String,
        category: TagCategory,
        source: TagSource,
        confidence: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category.rawValue
        self.source = source.rawValue
        self.confidence = confidence
        self.createdAt = createdAt
    }
}
