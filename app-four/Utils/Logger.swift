import Foundation

/// A simple debug helper for unified logging across services.
enum AppLogger {
    nonisolated static func log(_ message: String, file: String = #file, function: String = #function) {
        let filename = (file as NSString).lastPathComponent
        print("[\(filename):\(function)] \(message)")
    }
}
