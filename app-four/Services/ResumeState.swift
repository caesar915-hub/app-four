import Foundation

/// Persisted resume metadata for a single model file download.
///
/// The opaque `resumeData` is the plist blob produced by
/// `URLSessionDownloadTask.cancelByProducingResumeData()`. The remaining fields
/// are plain-text mirrors that let the download engine sanity-check a resumed
/// file (size, validator) before asking `URLSession` to replay the blob.
public struct ResumeState: Codable, Equatable, Sendable {
    /// Stable identifier for the file (e.g. the repo-relative path).
    public let fileKey: String

    /// Opaque resume packet from `URLSessionDownloadTask`.
    public let resumeData: Data

    /// Total bytes expected for the complete file.
    public let totalBytesExpected: Int64

    /// Bytes already downloaded when the state was captured.
    public let downloadedBytes: Int64

    /// ETag validator for the remote resource, if provided by the server.
    public let etag: String?

    /// Last-Modified validator for the remote resource, if provided.
    public let lastModified: String?

    public nonisolated init(
        fileKey: String,
        resumeData: Data,
        totalBytesExpected: Int64,
        downloadedBytes: Int64,
        etag: String?,
        lastModified: String?
    ) {
        self.fileKey = fileKey
        self.resumeData = resumeData
        self.totalBytesExpected = totalBytesExpected
        self.downloadedBytes = downloadedBytes
        self.etag = etag
        self.lastModified = lastModified
    }
}
