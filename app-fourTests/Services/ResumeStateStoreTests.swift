import Foundation
import Testing

@testable import app_four

struct ResumeStateStoreTests {

    private func makeTemporaryStoreURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-state-store-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("resume_state.json")
    }

    @Test func loadEmptyWhenNoFile() async {
        let url = makeTemporaryStoreURL()
        let store = ResumeStateStore(storeURL: url)
        await store.load()

        #expect(await store.state(for: "model.safetensors") == nil)
    }

    @Test func setAndGetState() async {
        let url = makeTemporaryStoreURL()
        let store = ResumeStateStore(storeURL: url)
        await store.load()

        let state = ResumeState(
            fileKey: "model.safetensors",
            resumeData: Data("resume-payload".utf8),
            totalBytesExpected: 1_050_000_000,
            downloadedBytes: 500_000_000,
            etag: #""abc123""#,
            lastModified: "Wed, 21 Oct 2025 07:28:00 GMT"
        )
        await store.setState(state)

        #expect(await store.state(for: "model.safetensors") == state)
    }

    @Test func persistAndReload() async {
        let url = makeTemporaryStoreURL()
        let store = ResumeStateStore(storeURL: url)
        await store.load()

        let state = ResumeState(
            fileKey: "tokenizer.json",
            resumeData: Data("partial".utf8),
            totalBytesExpected: 2_000_000,
            downloadedBytes: 1_000_000,
            etag: nil,
            lastModified: nil
        )
        await store.setState(state)

        let reloaded = ResumeStateStore(storeURL: url)
        await reloaded.load()

        #expect(await reloaded.state(for: "tokenizer.json") == state)
    }

    @Test func removeState() async {
        let url = makeTemporaryStoreURL()
        let store = ResumeStateStore(storeURL: url)
        await store.load()

        let a = ResumeState(
            fileKey: "a.safetensors",
            resumeData: Data("a".utf8),
            totalBytesExpected: 100,
            downloadedBytes: 50,
            etag: nil,
            lastModified: nil
        )
        let b = ResumeState(
            fileKey: "b.safetensors",
            resumeData: Data("b".utf8),
            totalBytesExpected: 100,
            downloadedBytes: 50,
            etag: nil,
            lastModified: nil
        )
        await store.setState(a)
        await store.setState(b)
        await store.removeState(for: "a.safetensors")

        #expect(await store.state(for: "a.safetensors") == nil)
        #expect(await store.state(for: "b.safetensors") == b)
    }

    @Test func removeAll() async {
        let url = makeTemporaryStoreURL()
        let store = ResumeStateStore(storeURL: url)
        await store.load()

        let state = ResumeState(
            fileKey: "config.json",
            resumeData: Data("c".utf8),
            totalBytesExpected: 10,
            downloadedBytes: 5,
            etag: nil,
            lastModified: nil
        )
        await store.setState(state)
        await store.removeAll()

        #expect(await store.state(for: "config.json") == nil)
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
    }

    @Test func corruptFileResetsToEmpty() async {
        let url = makeTemporaryStoreURL()
        try? "not json".write(to: url, atomically: true, encoding: .utf8)

        let store = ResumeStateStore(storeURL: url)
        await store.load()

        #expect(await store.state(for: "any") == nil)
    }

    @Test func multipleStatesPersistIndependently() async {
        let url = makeTemporaryStoreURL()
        let store = ResumeStateStore(storeURL: url)
        await store.load()

        let one = ResumeState(
            fileKey: "1.safetensors",
            resumeData: Data("1".utf8),
            totalBytesExpected: 100,
            downloadedBytes: 10,
            etag: "e1",
            lastModified: nil
        )
        let two = ResumeState(
            fileKey: "2.safetensors",
            resumeData: Data("2".utf8),
            totalBytesExpected: 200,
            downloadedBytes: 20,
            etag: "e2",
            lastModified: nil
        )
        await store.setState(one)
        await store.setState(two)

        let reloaded = ResumeStateStore(storeURL: url)
        await reloaded.load()

        #expect(await reloaded.state(for: "1.safetensors") == one)
        #expect(await reloaded.state(for: "2.safetensors") == two)
    }
}
