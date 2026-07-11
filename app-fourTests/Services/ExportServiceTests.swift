import Testing
import SwiftData
import Foundation
import CryptoKit
@testable import app_four

/// T032 — RED-first spec for the encrypted single-file journal export.
///
/// The export must produce ONE opaque blob that is (a) genuinely encrypted — no
/// seeded plaintext marker survives in the bytes — and (b) losslessly recoverable
/// with the returned key. The key is surfaced once to the user (recovery key) and
/// never persisted, so the round-trip here is the only proof of correctness.
@MainActor
struct ExportServiceTests {
    private static let plaintextMarker = "ZZQ_SECRET_MARKER_42_methylphenidate"

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Recording.self, TranscriptionSegment.self, RecordingTag.self, MedicationEvent.self,
            DayCalendarContext.self,
            configurations: config
        )
    }

    /// Seeds two recordings: one rich (transcript marker, signals, a transcript-sourced
    /// medication event, a segment, a tag) and one minimal, so the archive exercises the
    /// whole graph. Returns the marker that must NOT appear in the encrypted bytes.
    @discardableResult
    private func seed(_ context: ModelContext) throws -> (recordingCount: Int, medCount: Int) {
        let rich = Recording(
            audioFileName: "seed-rich.m4a",
            duration: 123,
            fileSize: 4096,
            status: .completed,
            fullTranscriptText: "Took my \(Self.plaintextMarker) this morning, felt sharp.",
            title: "Sharp Morning",
            isFavorite: true,
            hasMedication: true,
            energyLevel: "high",
            focusLevel: "locked_in",
            mood: "good",
            sleepHours: 7.5,
            sleepQuality: "rested"
        )
        context.insert(rich)

        let segment = TranscriptionSegment(text: "Took my \(Self.plaintextMarker) this morning", startTime: 0, endTime: 3)
        context.insert(segment)
        segment.recording = rich

        let tag = RecordingTag(name: "focus", category: .focus, source: .nlp, confidence: 0.9)
        context.insert(tag)
        tag.recording = rich

        let med = MedicationEvent(
            name: Self.plaintextMarker,
            dose: "20mg",
            takenAt: Date(timeIntervalSince1970: 1_700_000_000),
            taken: true,
            durationHours: 8,
            source: .transcript
        )
        context.insert(med)
        med.recording = rich

        let minimal = Recording(
            audioFileName: "seed-minimal.m4a",
            status: .completed,
            fullTranscriptText: "",
            title: "Check-in"
        )
        context.insert(minimal)

        try context.save()
        return (2, 1)
    }

    // MARK: - Single archive + encryption

    @Test func exportProducesSingleEncryptedArchive() async throws {
        let container = try makeContainer()
        try seed(container.mainContext)

        let service: ExportService = ExportServiceImpl()
        let result = try await service.export(from: container.mainContext)

        #expect(!result.data.isEmpty, "Export must produce a non-empty archive")

        // The seeded plaintext marker must be unreadable in the ciphertext — proves
        // the blob is encrypted, not just serialized.
        let markerBytes = Data(Self.plaintextMarker.utf8)
        #expect(
            result.data.range(of: markerBytes) == nil,
            "Plaintext marker leaked into the archive — output is not encrypted"
        )
    }

    // MARK: - Round-trip with the returned key

    @Test func exportRoundTripsWithReturnedKey() async throws {
        let container = try makeContainer()
        let seeded = try seed(container.mainContext)

        let service: ExportService = ExportServiceImpl()
        let result = try await service.export(from: container.mainContext)

        // Decrypt with the surfaced key and decode the archive DTO.
        let box = try AES.GCM.SealedBox(combined: result.data)
        let json = try AES.GCM.open(box, using: result.key)
        let archive = try JSONDecoder().decode(JournalArchive.self, from: json)

        #expect(archive.recordings.count == seeded.recordingCount)

        let rich = try #require(archive.recordings.first { $0.title == "Sharp Morning" })
        #expect(rich.fullTranscriptText.contains(Self.plaintextMarker))
        #expect(rich.mood == "good")
        #expect(rich.energyLevel == "high")
        #expect(rich.sleepHours == 7.5)
        #expect(rich.isFavorite == true)
        #expect(rich.segments.count == 1)
        #expect(rich.tags.count == 1)
        #expect(rich.medicationEvents.count == seeded.medCount)

        let med = try #require(rich.medicationEvents.first)
        #expect(med.name == Self.plaintextMarker)
        #expect(med.dose == "20mg")
    }

    /// A fresh key per export (CSPRNG, never reused) means two exports of the same
    /// data are NOT byte-equal — a reused key/nonce would make them identical.
    @Test func eachExportUsesAFreshKey() async throws {
        let container = try makeContainer()
        try seed(container.mainContext)

        let service: ExportService = ExportServiceImpl()
        let first = try await service.export(from: container.mainContext)
        let second = try await service.export(from: container.mainContext)

        #expect(first.data != second.data, "Identical ciphertext implies a reused key/nonce")
    }

    // MARK: - Empty journal

    @Test func emptyJournalExportsValidEmptyArchive() async throws {
        let container = try makeContainer()

        let service: ExportService = ExportServiceImpl()
        let result = try await service.export(from: container.mainContext)

        #expect(!result.data.isEmpty, "An empty journal still produces a valid archive")

        let box = try AES.GCM.SealedBox(combined: result.data)
        let json = try AES.GCM.open(box, using: result.key)
        let archive = try JSONDecoder().decode(JournalArchive.self, from: json)

        #expect(archive.recordings.isEmpty)
        #expect(archive.dayContexts.isEmpty)
    }

    // MARK: - Format version

    @Test func archiveFormatVersionIsTwo() async throws {
        let container = try makeContainer()

        let service: ExportService = ExportServiceImpl()
        let result = try await service.export(from: container.mainContext)

        let box = try AES.GCM.SealedBox(combined: result.data)
        let json = try AES.GCM.open(box, using: result.key)
        let archive = try JSONDecoder().decode(JournalArchive.self, from: json)

        #expect(archive.formatVersion == 2)
    }

    // MARK: - Day context round-trip

    @Test func dayContextsRoundTripThroughArchive() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let dayKey = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_750_000_000))
        let capturedAt = Date(timeIntervalSince1970: 1_750_003_600)
        let payload = CapturedDayEvents(events: [
            CapturedEvent(
                title: "Team Sync",
                start: Date(timeIntervalSince1970: 1_750_010_000),
                end: Date(timeIntervalSince1970: 1_750_013_600),
                isAllDay: false,
                attendeeCount: 3,
                availability: "busy"
            )
        ])

        let row = DayCalendarContext(
            dayKey: dayKey,
            capturedAt: capturedAt,
            titlesIncluded: true,
            isMockData: false
        )
        row.encodeEvents(payload)
        ctx.insert(row)
        try ctx.save()

        let service: ExportService = ExportServiceImpl()
        let result = try await service.export(from: container.mainContext)

        let box = try AES.GCM.SealedBox(combined: result.data)
        let json = try AES.GCM.open(box, using: result.key)
        let archive = try JSONDecoder().decode(JournalArchive.self, from: json)

        #expect(archive.formatVersion == 2)
        #expect(archive.dayContexts.count == 1)

        let dc = try #require(archive.dayContexts.first)
        #expect(dc.dayKey == dayKey)
        #expect(dc.capturedAt == capturedAt)
        #expect(dc.titlesIncluded == true)
        #expect(dc.events == payload)
    }

    @Test func dayContextWithNilEventsJSONFallsBackToEmpty() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let dayKey = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_750_000_000))
        let row = DayCalendarContext(
            dayKey: dayKey,
            eventsJSON: nil,
            capturedAt: Date(timeIntervalSince1970: 1_750_003_600),
            titlesIncluded: false,
            isMockData: false
        )
        ctx.insert(row)
        try ctx.save()

        let service: ExportService = ExportServiceImpl()
        let result = try await service.export(from: container.mainContext)

        let box = try AES.GCM.SealedBox(combined: result.data)
        let json = try AES.GCM.open(box, using: result.key)
        let archive = try JSONDecoder().decode(JournalArchive.self, from: json)

        #expect(archive.dayContexts.count == 1)
        let dc = try #require(archive.dayContexts.first)
        #expect(dc.events.events.isEmpty, "nil eventsJSON must fall back to CapturedDayEvents(events: [])")
    }
}
