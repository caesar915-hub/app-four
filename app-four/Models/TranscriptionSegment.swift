import Foundation
import SwiftData

@Model
final class TranscriptionSegment {
    @Attribute(.unique) var id: UUID
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var isFinal: Bool
    var confidence: Double?
    var language: String
    
    var recording: Recording?
    
    init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        isFinal: Bool = true,
        confidence: Double? = nil,
        language: String = "en"
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.isFinal = isFinal
        self.confidence = confidence
        self.language = language
    }
}
