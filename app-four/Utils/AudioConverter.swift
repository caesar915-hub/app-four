import Foundation
import AVFoundation

enum AudioConverterError: Error {
    case conversionFailed(String)
}

enum AudioConverter {
    /// Returns the duration of an audio file in seconds.
    nonisolated static func getDuration(url: URL) -> TimeInterval {
        do {
            let file = try AVAudioFile(forReading: url)
            return Double(file.length) / file.fileFormat.sampleRate
        } catch {
            return 0
        }
    }
}
