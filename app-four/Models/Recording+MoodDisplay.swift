import Foundation

extension Recording {
    /// Human sleep label ("5h sleep", "calm sleep") or nil when no sleep was logged.
    @MainActor var sleepLabel: String? {
        if let event = decodedSleepEvent {
            if let h = event.hours { return h == h.rounded() ? "\(Int(h))h sleep" : "\(h)h sleep" }
            if let q = event.quality { return "\(q) sleep" }
            return "sleep"
        }
        if let hours = sleepHours { return hours == hours.rounded() ? "\(Int(hours))h sleep" : "\(hours)h sleep" }
        if let quality = sleepQuality { return "\(quality) sleep" }
        return nil
    }
}
