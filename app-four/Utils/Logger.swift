import Foundation
import os

/// A simple debug helper for unified logging across services.
enum AppLogger {
    /// Unified-logging channel so device QA can retrieve logs after the fact with
    /// `log show --predicate 'subsystem == "squirl-app.app-four"' --last 10m`,
    /// instead of holding a live `--console` session. Messages are counts / durations /
    /// status only (Principle VI: no transcript or medication content), so `.public`
    /// is safe and keeps them legible in `log show`.
    private static let logger = Logger(subsystem: "squirl-app.app-four", category: "app")

    nonisolated static func log(_ message: String, file: String = #file, function: String = #function) {
        let filename = (file as NSString).lastPathComponent
        // Wall-clock prefix so QA console captures can be timed (download
        // durations, transcription latency) — print() carries no timestamp.
        let time = Date.now.formatted(date: .omitted, time: .standard)
        print("[\(time)] [\(filename):\(function)] \(message)")
        logger.log("[\(filename, privacy: .public):\(function, privacy: .public)] \(message, privacy: .public)")
    }
}
