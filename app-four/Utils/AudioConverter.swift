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
    
    /// Placeholder for future PCM conversion if needed for raw buffer processing.
    static func convertToPCM(url: URL) async throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw AudioConverterError.conversionFailed("Failed to create buffer")
        }
        
        try file.read(into: buffer)
        
        guard let channelData = buffer.floatChannelData?[0] else {
            return []
        }
        
        let frameLength = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData, count: frameLength))
    }
}
