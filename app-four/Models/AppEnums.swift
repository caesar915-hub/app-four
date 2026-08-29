import Foundation
import SwiftUI

/// The current status of a recording in the system.
enum RecordingStatus: String, Codable, Sendable {
    case recorded
    case transcribing
    /// Captured before the transcription model was ready; awaiting the model to land.
    /// Distinct from `.transcribing` (orphan recovery must not sweep it to `.failed`)
    /// and from `.failed` (a late model is not a failure — the UI stays calm).
    case pendingTranscription
    case completed
    case failed
    case placeholder
}

/// The state of the audio recording process.
enum RecordingState: String, Codable, Sendable {
    case idle
    case recording
    case paused
    case processing
    case done
}

/// Errors that can occur during audio recording or management.
enum RecordingError: Error, Codable, Sendable {
    case permissionDenied
    case hardwareFailure
    case storageFull
    case deviceDiskFull
    case interruption(InterruptionType)
    case timeout
    case unknown
}

/// Types of interruptions that can halt a recording.
enum InterruptionType: String, Codable, Sendable {
    case phoneCall
    case systemOverload
    case appBackgrounded
}

/// The current status of the Whisper model.
enum ModelStatus: String, Codable, Sendable {
    case notInstalled
    case downloading
    case installing
    case ready
    case corrupted
}

/// Supported formats for exporting transcription data.
enum ExportFormat: String, Codable, Sendable {
    case json
    case text
    case srt
}

// MARK: - Summarization Enums

enum TopicCategory: String, Codable, CaseIterable, Sendable {
    case medications = "Medications"
    case symptoms = "Symptoms"
    case appointments = "Appointments"
    case procedures = "Procedures"
    case general = "General"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .medications: "pill.fill"
        case .symptoms: "heart.fill"
        case .appointments: "calendar"
        case .procedures: "stethoscope"
        case .general: "doc.text"
        }
    }

    var color: Color {
        switch self {
        case .medications: .purple
        case .symptoms: .orange
        case .appointments: .blue
        case .procedures: .green
        case .general: .gray
        }
    }
}

enum SummaryStatus: String, Codable, Sendable {
    case notGenerated
    case generating
    case completed
    case failed
}

enum AIModelType: String, Codable, Sendable {
    case whisper
    case llm
}

enum DownloadStatus: String, Codable, Sendable {
    case notInstalled
    case downloading
    case installed
    case failed
}
