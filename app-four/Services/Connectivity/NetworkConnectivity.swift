import Foundation
import Network

/// `NWPathMonitor`-backed `Connectivity`. A thin, off-main adapter that maps the
/// system path to a `NetworkInterface` and republishes changes so a deferred
/// background download can resume the moment Wi-Fi returns.
actor NetworkConnectivity: Connectivity {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.squirl.connectivity")
    private var interface: NetworkInterface = .unsatisfied
    private var continuations: [UUID: AsyncStream<NetworkInterface>.Continuation] = [:]
    private var started = false

    init() {
        Task { await start() }
    }

    var currentInterface: NetworkInterface {
        get async {
            ensureStarted()
            return interface
        }
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

    /// The pure download decision — the only place that reads the cellular
    /// policy against the live interface. Kept static so it is trivially
    /// testable without spinning up `NWPathMonitor`.
    static func shouldStartDownload(overCellular: Bool, interface: NetworkInterface) -> Bool {
        switch interface {
        case .unsatisfied: false           // no usable path — nothing to download over
        case .cellular: overCellular       // gated by the user's preference
        case .wifi, .other: true           // a usable non-cellular path
        }
    }

    // MARK: - Private

    private func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let mapped = Self.map(path)
            Task { await self?.update(to: mapped) }
        }
        monitor.start(queue: queue)
    }

    private func ensureStarted() {
        if !started { start() }
    }

    private func update(to newInterface: NetworkInterface) {
        guard newInterface != interface else { return }
        interface = newInterface
        for continuation in continuations.values {
            continuation.yield(newInterface)
        }
    }

    private func register(_ id: UUID, _ continuation: AsyncStream<NetworkInterface>.Continuation) {
        ensureStarted()
        continuations[id] = continuation
        continuation.yield(interface)
    }

    private func unregister(_ id: UUID) {
        continuations[id] = nil
    }

    nonisolated private static func map(_ path: NWPath) -> NetworkInterface {
        guard path.status == .satisfied else { return .unsatisfied }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        return .other
    }
}
