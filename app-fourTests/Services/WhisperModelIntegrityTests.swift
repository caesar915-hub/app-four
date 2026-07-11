import Testing
import Foundation
@testable import app_four

struct WhisperModelIntegrityTests {
    // MARK: - Helpers

    private func makeTempBase() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper-integrity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    private func makeModelDir(in base: URL) throws -> URL {
        let model = base.appendingPathComponent("openai_whisper-small", isDirectory: true)
        try FileManager.default.createDirectory(at: model, withIntermediateDirectories: true)
        return model
    }

    // MARK: - Tests

    @Test func directoryAloneIsNotEnough() throws {
        let base = try makeTempBase()
        defer { try? FileManager.default.removeItem(at: base) }
        _ = try makeModelDir(in: base)
        #expect(AIModelServiceImpl.findWhisperModelFolder(in: base) == nil)
    }

    // Mirrors the actual crash: skeleton creates AudioEncoder.mlmodelc/ but
    // weight move fails, so weights/ subdir never appears.
    @Test func encoderSkeletonWithoutWeightsIsNotEnough() throws {
        let base = try makeTempBase()
        defer { try? FileManager.default.removeItem(at: base) }
        let model = try makeModelDir(in: base)
        let encoder = model.appendingPathComponent("AudioEncoder.mlmodelc", isDirectory: true)
        try FileManager.default.createDirectory(at: encoder, withIntermediateDirectories: true)
        #expect(AIModelServiceImpl.findWhisperModelFolder(in: base) == nil)
    }

    @Test func missingConfigIsNotEnough() throws {
        let base = try makeTempBase()
        defer { try? FileManager.default.removeItem(at: base) }
        let model = try makeModelDir(in: base)
        let weights = model.appendingPathComponent("AudioEncoder.mlmodelc/weights", isDirectory: true)
        try FileManager.default.createDirectory(at: weights, withIntermediateDirectories: true)
        #expect(AIModelServiceImpl.findWhisperModelFolder(in: base) == nil)
    }

    @Test func missingEncoderWeightsIsNotEnough() throws {
        let base = try makeTempBase()
        defer { try? FileManager.default.removeItem(at: base) }
        let model = try makeModelDir(in: base)
        let config = model.appendingPathComponent("config.json")
        try Data().write(to: config)
        #expect(AIModelServiceImpl.findWhisperModelFolder(in: base) == nil)
    }

    @Test func completedModelIsRecognised() throws {
        let base = try makeTempBase()
        defer { try? FileManager.default.removeItem(at: base) }
        let model = try makeModelDir(in: base)
        let weights = model.appendingPathComponent("AudioEncoder.mlmodelc/weights", isDirectory: true)
        try FileManager.default.createDirectory(at: weights, withIntermediateDirectories: true)
        let config = model.appendingPathComponent("config.json")
        try Data().write(to: config)
        #expect(AIModelServiceImpl.findWhisperModelFolder(in: base) == model)
    }
}
