import Foundation
import SwiftData

@Model
final class ModelMetadata {
    @Attribute(.unique) var id: UUID
    var modelName: String
    var modelType: String
    var modelSize: Int64
    var isDownloaded: Bool
    var isCorrupted: Bool
    var version: String
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
