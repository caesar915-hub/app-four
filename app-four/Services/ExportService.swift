import Foundation
import CryptoKit
import SwiftData

// MARK: - Archive DTOs

/// A self-contained, `Codable` snapshot of the whole journal. SwiftData `@Model`
/// types are not `Codable` and not `Sendable`, so the graph is mapped to these
/// plain value types on the main actor before it is serialized and sealed off-main.
/// This DTO IS the plaintext that gets encrypted — it never touches disk unsealed.
struct JournalArchive: Codable, Sendable {
    /// Bumped if the on-disk shape ever changes, so a future importer can branch.
    let formatVersion: Int
    let exportedAt: Date
    let recordings: [RecordingDTO]

    static let currentFormatVersion = 1
}

struct RecordingDTO: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let updatedAt: Date
    let audioFileName: String
    let duration: TimeInterval
    let fileSize: Int64
    let status: String
    let fullTranscriptText: String
    let title: String
    let isFavorite: Bool

    let summary: String?
    let summaryStatus: String?
    let topicTagsJSON: String?
    let summaryGeneratedAt: Date?

    let hasMedication: Bool
    let medicationInfo: String?
    let energyLevel: String?
    let focusLevel: String?
    let mood: String?
    let sleepHours: Double?
    let sleepQuality: String?
    let summaryBulletsJSON: String?
    let noteExtractionJSON: String?
    let sideEffectsJSON: String?
    let sleepEventJSON: String?
    let feelingsJSON: String?
    let sleepLevelValue: String?

    /// Base64 of the recording's audio file, when it exists on disk. `nil` for
    /// text check-ins (no audio) and for any recording whose file is missing.
    let audioBase64: String?

    let segments: [SegmentDTO]
    let tags: [TagDTO]
    let medicationEvents: [MedicationEventDTO]
}

struct SegmentDTO: Codable, Sendable {
    let id: UUID
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let isFinal: Bool
    let confidence: Double?
    let language: String
}

struct TagDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let category: String
    let source: String
    let confidence: Double?
    let createdAt: Date
}

struct MedicationEventDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let dose: String?
    let takenAt: Date
    let taken: Bool
    let quantity: Double?
    let durationHours: Double
    let change: String?
    let timeLabel: String?
    let source: String
    let createdAt: Date
}

// MARK: - Result

/// The sealed archive plus the one-time key that opens it.
///
/// `key` is generated fresh per export by `SymmetricKey(size: .bits256)` (CryptoKit's
/// CSPRNG) and is **never** persisted — no Keychain, no UserDefaults, no file. The user
/// holds it (surfaced once as a recovery key); restore is a future spec. `data` is the
/// AES-GCM `combined` blob (nonce + ciphertext + tag) — the file written to disk.
struct ExportResult: Sendable {
    let data: Data
    let key: SymmetricKey
}

// MARK: - Service

/// Produces a single encrypted file from the SwiftData journal so the user can keep
/// or share a copy without plaintext ever leaving the device sandbox.
protocol ExportService: Sendable {
    /// Snapshots `context`'s recordings into a sealed archive and returns it with the
    /// fresh key that decrypts it. Reads the model graph on the main actor; serializes
    /// and seals off the main actor.
    @MainActor func export(from context: ModelContext) async throws -> ExportResult
}

struct ExportServiceImpl: ExportService {
    @MainActor
    func export(from context: ModelContext) async throws -> ExportResult {
        let archive = try Self.snapshot(context)

        // Serialize + seal off the main actor: JSON encode then AES-GCM seal.
        // The archive is a `Sendable` value graph, so it crosses the boundary cleanly.
        return try await Task.detached(priority: .userInitiated) {
            try seal(archive)
        }.value
    }

    /// Reads every `Recording` (with its segments, tags, medication events, and audio
    /// bytes) and maps the non-`Sendable` `@Model` graph to a `Sendable` archive.
    @MainActor
    private static func snapshot(_ context: ModelContext) throws -> JournalArchive {
        let descriptor = FetchDescriptor<Recording>(sortBy: [SortDescriptor(\.createdAt)])
        let recordings = try context.fetch(descriptor)
        return JournalArchive(
            formatVersion: JournalArchive.currentFormatVersion,
            exportedAt: .now,
            recordings: recordings.map(dto(for:))
        )
    }

    @MainActor
    private static func dto(for r: Recording) -> RecordingDTO {
        let audioBase64 = (try? Data(contentsOf: r.audioURL))?.base64EncodedString()
        return RecordingDTO(
            id: r.id,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
            audioFileName: r.audioFileName,
            duration: r.duration,
            fileSize: r.fileSize,
            status: r.status.rawValue,
            fullTranscriptText: r.fullTranscriptText,
            title: r.title,
            isFavorite: r.isFavorite,
            summary: r.summary,
            summaryStatus: r.summaryStatus,
            topicTagsJSON: r.topicTagsJSON,
            summaryGeneratedAt: r.summaryGeneratedAt,
            hasMedication: r.hasMedication,
            medicationInfo: r.medicationInfo,
            energyLevel: r.energyLevel,
            focusLevel: r.focusLevel,
            mood: r.mood,
            sleepHours: r.sleepHours,
            sleepQuality: r.sleepQuality,
            summaryBulletsJSON: r.summaryBulletsJSON,
            noteExtractionJSON: r.noteExtractionJSON,
            sideEffectsJSON: r.sideEffectsJSON,
            sleepEventJSON: r.sleepEventJSON,
            feelingsJSON: r.feelingsJSON,
            sleepLevelValue: r.sleepLevelValue,
            audioBase64: audioBase64,
            segments: (r.segments ?? []).map { s in
                SegmentDTO(
                    id: s.id, text: s.text, startTime: s.startTime, endTime: s.endTime,
                    isFinal: s.isFinal, confidence: s.confidence, language: s.language
                )
            },
            tags: (r.correctionTags ?? []).map { t in
                TagDTO(
                    id: t.id, name: t.name, category: t.category, source: t.source,
                    confidence: t.confidence, createdAt: t.createdAt
                )
            },
            medicationEvents: r.medicationEvents.map { m in
                MedicationEventDTO(
                    id: m.id, name: m.name, dose: m.dose, takenAt: m.takenAt, taken: m.taken,
                    quantity: m.quantity, durationHours: m.durationHours, change: m.change?.rawValue,
                    timeLabel: m.timeLabel, source: m.source.rawValue, createdAt: m.createdAt
                )
            }
        )
    }
}

/// JSON-encodes then AES-GCM-seals the archive under a fresh 256-bit key. AES-GCM
/// auto-generates a random nonce per seal and includes the auth tag in `combined`,
/// so no nonce is ever set or reused by hand. Pure value-in/value-out → `Sendable`,
/// safe to run on a detached task.
private func seal(_ archive: JournalArchive) throws -> ExportResult {
    let plaintext = try JSONEncoder().encode(archive)
    let key = SymmetricKey(size: .bits256)
    let sealed = try AES.GCM.seal(plaintext, using: key)
    guard let combined = sealed.combined else {
        throw ExportError.sealFailed
    }
    return ExportResult(data: combined, key: key)
}

enum ExportError: Error, Sendable {
    /// AES-GCM `combined` is only nil for a non-default (>12-byte) nonce, which we
    /// never set — defensive, should not occur.
    case sealFailed
}
