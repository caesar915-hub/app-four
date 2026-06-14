import Testing
import Foundation
@testable import app_four

@MainActor struct SessionSnapshotTests {

    @Test func initialization() {
        let snapshot = SessionSnapshot(
            whisperDurationMs: 1200,
            screenName: "TestScreen"
        )

        #expect(snapshot.whisperDurationMs == 1200)
        #expect(snapshot.screenName == "TestScreen")
        #expect(snapshot.iOSVersion.isEmpty == false)
        #expect(snapshot.appBuild.isEmpty == false)
    }

    @Test(arguments: [
        (ProcessInfo.ThermalState.nominal, "nominal"),
        (ProcessInfo.ThermalState.fair, "fair"),
        (ProcessInfo.ThermalState.serious, "serious"),
        (ProcessInfo.ThermalState.critical, "critical"),
    ])
    func thermalStateMapping(state: ProcessInfo.ThermalState, expected: String) {
        let snapshot = SessionSnapshot(thermalState: state)
        #expect(snapshot.thermalState == expected)
    }

    @Test func codableRoundTrip() throws {
        let snapshot = SessionSnapshot(whisperDurationMs: 500, screenName: "CodableTest")

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: data)

        #expect(decoded.id == snapshot.id)
        #expect(decoded.whisperDurationMs == snapshot.whisperDurationMs)
        #expect(decoded.screenName == snapshot.screenName)
    }
}
