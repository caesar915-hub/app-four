import Foundation
import SwiftData

@Model
final class ModelMetadata {
    // Inline defaults mirror `init` exactly (Constitution IX: optional-or-defaulted).
    @Attribute(.unique) var id: UUID = UUID()
    var modelName: String = "base"
    var modelType: String = AIModelType.whisper.rawValue
    var modelSize: Int64 = 74_000_000
    var isDownloaded: Bool = false
    var isCorrupted: Bool = false
    var version: String = "openai-whisper-base-v1"
    var checksum: String?

    init(
        id: UUID = UUID(),
        modelName: String = "base",
        modelType: String = AIModelType.whisper.rawValue,
        modelSize: Int64 = 74_000_000,
        isDownloaded: Bool = false,
        isCorrupted: Bool = false,
        version: String = "openai-whisper-base-v1",
        checksum: String? = nil
    ) {
        self.id = id
        self.modelName = modelName
        self.modelType = modelType
        self.modelSize = modelSize
        self.isDownloaded = isDownloaded
        self.isCorrupted = isCorrupted
        self.version = version
        self.checksum = checksum
    }
}
