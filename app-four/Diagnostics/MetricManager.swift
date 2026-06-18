import Foundation
import MetricKit
import Observation

// MARK: - Architecture Note
//
// MetricKit provides daily aggregated metrics (MXMetricPayload) and diagnostic
// payloads (MXDiagnosticPayload) with a 24-hour delay. This is insufficient for
// real-time health app diagnostics because:
//   1. A user may experience a memory crash (jetsam) during a transcription and
//      never open the app again before MetricKit delivers the payload.
//   2. MetricKit does not expose per-operation timing (e.g. "this specific
//      Whisper inference took 8.6s"), only cumulative averages.
//   3. Thermal state and available RAM are not included in MetricKit payloads.
//
// SessionSnapshot bridges this gap by capturing lightweight system context
// (thermal state, available memory, operation duration, screen name) before and
// after every heavy operation. These snapshots are available immediately for
// user-initiated feedback reports, while MetricKit data provides the longer-term
// trend context.
//
// MFMailComposeViewController was chosen over a backend endpoint because:
//   1. The app has no backend and the prompt explicitly forbids auto-upload.
//   2. Email gives the user full control over what is sent and to whom.
//   3. It works entirely on-device without network dependencies.

/// Subscribes to MetricKit and logs aggregated device metrics to the console.
/// Does not display UI or request user permission.
@Observable
final class MetricManager: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricManager()
    
    private var metricManager: MXMetricManager?
    
    private override init() {
        super.init()
    }
    
    /// Call once on app launch (e.g. from `SquirlApp.init`).
    func start() {
        let manager = MXMetricManager.shared
        manager.add(self)
        self.metricManager = manager
        AppLogger.log("🚀 MetricManager subscribed to MXMetricManager")
    }
    
    /// Call on app termination to clean up the subscription.
    func stop() {
        if let manager = metricManager {
            manager.remove(self)
        }
    }
    
    // MARK: - MXMetricManagerSubscriber
    
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            AppLogger.log("--- MXMetricPayload received ---")
            
            // Memory pressure exits (jetsam events)
            if let appExitMetrics = payload.applicationExitMetrics {
                let memoryPressure = appExitMetrics.backgroundExitData.cumulativeMemoryResourceLimitExitCount
                AppLogger.log("Cumulative memory-pressure exits (jetsam): \(memoryPressure)")
                
                let cpuException = appExitMetrics.backgroundExitData.cumulativeCPUResourceLimitExitCount
                AppLogger.log("Cumulative CPU-exception exits: \(cpuException)")
            }
            
            // Cumulative disk writes
            if let diskWrites = payload.diskIOMetrics?.cumulativeLogicalWrites {
                let mb = diskWrites.value / (1024.0 * 1024.0)
                AppLogger.log("Cumulative logical disk writes: \(String(format: "%.2f", mb)) MB")
            }
            
            // Application launch times
            if let _ = payload.applicationLaunchMetrics {
                AppLogger.log("Application launch metrics received")
            }
            
            // Cellular network condition
            if let _ = payload.cellularConditionMetrics {
                AppLogger.log("Cellular condition metrics received")
            }
        }
    }
    
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            AppLogger.log("--- MXDiagnosticPayload received ---")
            
            // Hang diagnostics
            if let hangDiagnostics = payload.hangDiagnostics, !hangDiagnostics.isEmpty {
                AppLogger.log("Hang diagnostics received: \(hangDiagnostics.count)")
            } else {
                AppLogger.log("No hang diagnostics in payload")
            }
            
            // CPU exception diagnostics
            if let cpuDiagnostics = payload.cpuExceptionDiagnostics, !cpuDiagnostics.isEmpty {
                for cpu in cpuDiagnostics {
                    let duration = String(format: "%.3f", cpu.totalCPUTime.value)
                    AppLogger.log("CPU exception — total duration: \(duration)s, callStack: \(cpu.callStackTree)")
                }
            }
            
            // Disk write exception diagnostics
            if let diskDiagnostics = payload.diskWriteExceptionDiagnostics, !diskDiagnostics.isEmpty {
                for disk in diskDiagnostics {
                    let mb = disk.totalWritesCaused.value / (1024.0 * 1024.0)
                    let mbStr = String(format: "%.2f", mb)
                    AppLogger.log("Disk write exception — writes: \(mbStr) MB, callStack: \(disk.callStackTree)")
                }
            }
        }
    }
}
