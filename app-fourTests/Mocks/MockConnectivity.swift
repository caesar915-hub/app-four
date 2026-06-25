import Foundation
@testable import app_four

/// Scriptable `Connectivity` for tests: set the current interface and emit
/// changes so the deferral/resume path can be driven deterministically.
actor MockConnectivity: Connectivity {
    private var interface: NetworkInterface
    private var continuations: [UUID: AsyncStream<NetworkInterface>.Continuation] = [:]

    init(initial: NetworkInterface = .wifi) {
        self.interface = initial
    }

    var currentInterface: NetworkInterface {
        get async { interface }
    }

    nonisolated var interfaceChanges: AsyncStream<NetworkInterface> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.register(id, continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(id) }
            }
        }
    }

    /// Move to a new interface and notify every live subscriber.
    func set(_ newInterface: NetworkInterface) {
        interface = newInterface
        for continuation in continuations.values {
            continuation.yield(newInterface)
        }
    }

    private func register(_ id: UUID, _ continuation: AsyncStream<NetworkInterface>.Continuation) {
        continuations[id] = continuation
        continuation.yield(interface)
    }

    private func unregister(_ id: UUID) {
        continuations[id] = nil
    }
}
