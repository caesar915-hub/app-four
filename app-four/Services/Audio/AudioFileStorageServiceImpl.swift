import Foundation
import SwiftData

/// Service implementation for managing audio files and metadata persistence.
final class AudioFileStorageServiceImpl: AudioFileStorageService {
    private let context: ModelContext
    
    private let recordingsDir: URL
    private let exportsDir: URL
    
    init(context: ModelContext) {
        self.context = context
        self.recordingsDir = AppPaths.recordings
        self.exportsDir = AppPaths.exports
    }

    @MainActor func saveRecording(from temporaryURL: URL, duration: TimeInterval) throws -> Recording {
        let id = UUID()
        let fileName = "recording_\(id.uuidString.lowercased()).m4a"
        let destinationURL = recordingsDir.appendingPathComponent(fileName)
        
        // Copy (not move) so a save failure leaves the temp capture intact for the
        // view-model's retry path (FR-005); the temp is removed only after the row
        // is durably saved.
        try FileManager.default.copyItem(at: temporaryURL, to: destinationURL)

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0
        let createdAt = Date()
        let title = "Recording \(createdAt.formatted(date: .abbreviated, time: .shortened))"
        
        let recording = Recording(
            id: id,
            createdAt: createdAt,
            updatedAt: createdAt,
            audioFileName: fileName,
            duration: duration,
            fileSize: fileSize,
            status: .recorded,
            title: title
        )
        
        context.insert(recording)
        do {
            try context.save()
        } catch {
            // Never orphan a file with no row: roll back the copy and keep the temp
            // so the caller can retry from the same buffer.
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
        try? FileManager.default.removeItem(at: temporaryURL)

        AppLogger.log("File saved: \(fileSize) bytes at \(destinationURL.path)")
        return recording
    }
    
    @MainActor func deleteRecording(_ recording: Recording) throws {
        let fileName = recording.audioFileName
        let fileURL = recordingsDir.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        
        context.delete(recording)
        try context.save()
        
        AppLogger.log("File deleted: \(fileName)")
    }
    
    @MainActor func getAudioURL(for recording: Recording) -> URL? {
        let url = recordingsDir.appendingPathComponent(recording.audioFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    @MainActor func exportTranscript(_ recording: Recording, format: ExportFormat) async throws -> URL {
        struct ExportDTO: Encodable {
            let id: String
            let title: String?
            let createdAt: Date
            let duration: TimeInterval
            let audioFormat: String
            let transcript: String
        }
        
        let dto = ExportDTO(
            id: recording.id.uuidString,
            title: recording.title,
            createdAt: recording.createdAt,
            duration: recording.duration,
            audioFormat: AudioConstants.formatLabel,
            transcript: recording.fullTranscriptText
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(dto)
        let exportURL = exportsDir.appendingPathComponent("\(recording.id.uuidString).json")
        try data.write(to: exportURL)
        
        AppLogger.log("Transcript exported to: \(exportURL.path)")
        return exportURL
    }
    
    @MainActor func calculateTotalStorageUsed() async -> Int64 {
        let descriptor = FetchDescriptor<Recording>()
        let recordings = (try? context.fetch(descriptor)) ?? []
        return recordings.reduce(0) { $0 + $1.fileSize }
    }
    
    func availableStorage() async -> Int64 {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let attributes = (try? FileManager.default.attributesOfFileSystem(forPath: path)) ?? [:]
        return (attributes[.systemFreeSize] as? Int64) ?? 0
    }
}
