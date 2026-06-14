import Foundation

/// A lightweight, privacy-safe snapshot of system state captured before/after
/// heavy on-device operations (e.g. Whisper transcription).
///
/// This struct intentionally NEVER includes transcript text, summary text,
/// or audio file paths. It is designed for local diagnostic use only.
struct SessionSnapshot: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let thermalState: String
    let availableMemoryMB: UInt64
    let whisperDurationMs: Double
    let transcriptionTokenEstimate: Int
    let summaryTokenEstimate: Int
    let iOSVersion: String
    let appBuild: String
    let screenName: String

    nonisolated init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState,
        availableMemoryMB: UInt64 = SessionSnapshot.currentAvailableMemoryMB(),
        whisperDurationMs: Double = 0,
        transcriptionTokenEstimate: Int = 0,
        summaryTokenEstimate: Int = 0,
        iOSVersion: String = SessionSnapshot.currentOSVersion(),
        appBuild: String = SessionSnapshot.currentAppBuild(),
        screenName: String = "unknown"
    ) {
        self.id = id
        self.timestamp = timestamp
        self.thermalState = SessionSnapshot.thermalStateString(thermalState)
        self.availableMemoryMB = availableMemoryMB
        self.whisperDurationMs = whisperDurationMs
        self.transcriptionTokenEstimate = transcriptionTokenEstimate
        self.summaryTokenEstimate = summaryTokenEstimate
        self.iOSVersion = iOSVersion
        self.appBuild = appBuild
        self.screenName = screenName
    }

    // MARK: - Helpers

    private nonisolated static func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:  return "nominal"
        case .fair:     return "fair"
        case .serious:  return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    /// Returns available physical memory in megabytes.
    /// Uses `os_proc_available_memory` (iOS 16+), falling back to `vm_statistics64`.
    private nonisolated static func currentAvailableMemoryMB() -> UInt64 {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            // os_proc_available_memory returns bytes available to the process
            let bytes = os_proc_available_memory()
            return UInt64(bytes) / (1024 * 1024)
        }
        #endif

        // Fallback: use vm_statistics64
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let pageSize = UInt64(vm_kernel_page_size)
        let freePages = UInt64(info.free_count)
        return (freePages * pageSize) / (1024 * 1024)
    }

    nonisolated static func currentOSVersion() -> String {
        let info = ProcessInfo.processInfo.operatingSystemVersion
        return "\(info.majorVersion).\(info.minorVersion).\(info.patchVersion)"
    }

    nonisolated static func currentAppBuild() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        return "\(version) (\(build))"
    }
}

/// Backing type for JSON array storage.
struct SessionSnapshotArchive: Sendable {
    var snapshots: [SessionSnapshot]
}

extension SessionSnapshotArchive: Codable {
    enum CodingKeys: String, CodingKey {
        case snapshots
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.snapshots = try container.decode([SessionSnapshot].self, forKey: .snapshots)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(snapshots, forKey: .snapshots)
    }
}
