import Testing
import Foundation
@testable import app_four

/// The background-download decision: honor `downloadOverCellular`, defer to
/// Wi-Fi when off and on cellular, never start when there is no usable path.
struct NetworkConnectivityTests {

    // MARK: - downloadOverCellular == false

    @Test func cellularWithPreferenceOff_defers() {
        #expect(NetworkConnectivity.shouldStartDownload(overCellular: false, interface: .cellular) == false)
    }

    @Test func wifiWithPreferenceOff_proceeds() {
        #expect(NetworkConnectivity.shouldStartDownload(overCellular: false, interface: .wifi) == true)
    }

    @Test func unsatisfiedWithPreferenceOff_defers() {
        #expect(NetworkConnectivity.shouldStartDownload(overCellular: false, interface: .unsatisfied) == false)
    }

    @Test func otherInterfaceWithPreferenceOff_proceeds() {
        // Wired/loopback/unknown-but-connected: not cellular, so the cellular
        // policy doesn't apply — a usable path is a usable path.
        #expect(NetworkConnectivity.shouldStartDownload(overCellular: false, interface: .other) == true)
    }

    // MARK: - downloadOverCellular == true

    @Test func cellularWithPreferenceOn_proceeds() {
        #expect(NetworkConnectivity.shouldStartDownload(overCellular: true, interface: .cellular) == true)
    }

    @Test func wifiWithPreferenceOn_proceeds() {
        #expect(NetworkConnectivity.shouldStartDownload(overCellular: true, interface: .wifi) == true)
    }

    @Test func unsatisfiedWithPreferenceOn_defers() {
        // No usable path: even with cellular allowed, there is nothing to download over.
        #expect(NetworkConnectivity.shouldStartDownload(overCellular: true, interface: .unsatisfied) == false)
    }

    // MARK: - Driven through the Connectivity seam

    @Test func decisionReadsLiveInterfaceFromConnectivity() async {
        let mock = MockConnectivity(initial: .cellular)
        let onCellular = NetworkConnectivity.shouldStartDownload(
            overCellular: false,
            interface: await mock.currentInterface
        )
        #expect(onCellular == false)

        await mock.set(.wifi)
        let onWifi = NetworkConnectivity.shouldStartDownload(
            overCellular: false,
            interface: await mock.currentInterface
        )
        #expect(onWifi == true)
    }
}
