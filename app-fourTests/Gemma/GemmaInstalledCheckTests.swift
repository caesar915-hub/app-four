import Testing
import Foundation
@testable import app_four

@Suite struct GemmaInstalledCheckTests {
    private func makeBase() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("gemma-installed-\(UUID().uuidString)")
    }

    private func modelFileURL(in base: URL) -> URL {
        base.appendingPathComponent("models")
            .appendingPathComponent(ModelConstants.gemmaLiteRTRepoID)
            .appendingPathComponent(ModelConstants.gemmaLiteRTFileName)
    }

    @Test func reportsInstalledWhenFilePresentAtExpectedSize() throws {
        let base = makeBase()
        let file = modelFileURL(in: base)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: file.path, contents: nil)
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: UInt64(ModelConstants.gemmaLiteRTExpectedBytes)) // sparse — no real 2.4 GB write
        try handle.close()
        defer { try? FileManager.default.removeItem(at: base) }

        #expect(AIModelServiceImpl.gemmaLiteRTModelInstalled(in: base) == true)
    }

    @Test func reportsNotInstalledWhenAbsent() {
        let base = makeBase()
        #expect(AIModelServiceImpl.gemmaLiteRTModelInstalled(in: base) == false)
    }

    @Test func reportsNotInstalledWhenTruncated() throws {
        let base = makeBase()
        let file = modelFileURL(in: base)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x00, 0x01, 0x02]).write(to: file)
        defer { try? FileManager.default.removeItem(at: base) }

        #expect(AIModelServiceImpl.gemmaLiteRTModelInstalled(in: base) == false)
    }
}
