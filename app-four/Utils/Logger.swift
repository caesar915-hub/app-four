import Foundation

/// A simple debug helper for unified logging across services.
enum AppLogger {
    nonisolated static func log(_ message: String, file: String = #file, function: String = #function) {
        let filename = (file as NSString).lastPathComponent
        // Wall-clock prefix so QA console captures can be timed (download
        // durations, transcription latency) — print() carries no timestamp.
        let time = Date.now.formatted(date: .omitted, time: .standard)
        print("[\(time)] [\(filename):\(function)] \(message)")
    }
}
