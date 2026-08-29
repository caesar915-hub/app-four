import Foundation

/// Calculates a transcription timeout budget that scales with audio duration and
/// device thermal state, eliminating false-positive timeouts for long recordings
/// while still detecting genuine stalls quickly.
public struct TranscriptionTimeoutCalculator: Sendable {
    
    /// Returns the recommended timeout in seconds for a recording of the given
    /// duration and thermal state.
    ///
    /// Formula: `max(60, duration × rtfMultiplier + 30)` where the multiplier
    /// is chosen from the current thermal state.
    ///
    /// - Parameters:
    ///   - audioDuration: Length of the recording in seconds.
    ///   - thermalState: Optional thermal state to use. If `nil`, the current
    ///     process thermal state is read.
    /// - Returns: Timeout budget in seconds.
    public static func timeout(
        for audioDuration: TimeInterval,
        thermalState: ProcessInfo.ThermalState? = nil
    ) -> TimeInterval {
        let state = thermalState ?? ProcessInfo.processInfo.thermalState
        let rtfMultiplier: TimeInterval
        
        switch state {
        case .nominal, .fair:
            rtfMultiplier = 0.4
        case .serious:
            rtfMultiplier = 0.6
        case .critical:
            rtfMultiplier = 0.8
        @unknown default:
            rtfMultiplier = 0.4
        }
        
        return max(60.0, audioDuration * rtfMultiplier + 30.0)
    }
}
