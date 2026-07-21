import Foundation
import SwiftData

@Model
final class TranscriptionSegment {
    // CloudKit-compatible (spec 038): no `.unique`, inline defaults for the mirrored store.
    var id: UUID = UUID()
    var text: String = ""
    var startTime: TimeInterval = 0
    var endTime: TimeInterval = 0
    var isFinal: Bool = true
    var confidence: Double?
    var language: String = "en"
    
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
