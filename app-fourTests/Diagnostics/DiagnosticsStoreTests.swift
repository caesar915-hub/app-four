import Testing
import Foundation
@testable import app_four

@MainActor struct DiagnosticsStoreTests {

    private func makeStore() -> DiagnosticsStore {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("snapshots.json")
        return DiagnosticsStore(fileURL: url)
    }

    @Test func recordAndRetrieveSnapshots() async {
        let store = makeStore()

        await store.record(SessionSnapshot(screenName: "Screen 1"))
        await store.record(SessionSnapshot(screenName: "Screen 2"))

        let snapshots = await store.recentSnapshots()
        #expect(snapshots.count == 2)
    }

    @Test(.timeLimit(.minutes(1))) func bufferLimitCapsAt50() async {
        let store = makeStore()

        for i in 0..<60 {
            await store.record(SessionSnapshot(screenName: "Screen \(i)"))
        }

        let snapshots = await store.recentSnapshots()
        #expect(snapshots.count == 50, "Buffer should cap at 50 snapshots")
    }

    @Test func clearRemovesAllSnapshots() async {
        let store = makeStore()

        await store.record(SessionSnapshot(screenName: "A"))
        await store.record(SessionSnapshot(screenName: "B"))
        await store.clear()

        let snapshots = await store.recentSnapshots()
        #expect(snapshots.count == 0)
    }

    @Test func recentSnapshotsReturnsNewestFirst() async throws {
        let store = makeStore()

        await store.record(SessionSnapshot(screenName: "Oldest"))
        await store.record(SessionSnapshot(screenName: "Newest"))

        let snapshots = await store.recentSnapshots(limit: 2)
        let first = try #require(snapshots.first)
        #expect(first.screenName == "Newest")
    }
}
