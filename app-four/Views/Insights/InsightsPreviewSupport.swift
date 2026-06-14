#if DEBUG
import Foundation
import SwiftData

extension InsightsViewModel {
    /// A pre-seeded ViewModel for SwiftUI Previews.
    /// Builds an in-memory SwiftData container so previews reflect real computation paths.
    @MainActor
    static func preview() -> InsightsViewModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: Recording.self, MedicationEvent.self, AppSettings.self,
                                                  configurations: config) else {
            fatalError("InsightsPreviewSupport: failed to create preview container")
        }
        let ctx = container.mainContext
        let cal = Calendar.current
        let june2025 = cal.date(from: DateComponents(year: 2025, month: 6, day: 1))!

        let seed: [(Int, Int, String?, String?, String?, String?)] = [
            (1,  9,  "good",  "alert",    "sharp",      "good"),
            (2,  14, "okay",  "steady",   "present",    nil),
            (3,  8,  "great", "charged",  "lockedIn",   "good"),
            (4,  20, "flat",  "tired",    "distracted", "poor"),
            (5,  10, "okay",  "steady",   "present",    nil),
            (6,  9,  "good",  "alert",    "sharp",      "good"),
            (7,  11, "great", "charged",  "lockedIn",   nil),
            (8,  8,  "low",   "sluggish", "foggy",      "poor"),
            (9,  14, "okay",  "steady",   "present",    nil),
            (10, 10, "good",  "alert",    "sharp",      "good"),
            (11, 9,  "good",  "charged",  "lockedIn",   nil),
            (12, 20, "flat",  "tired",    "foggy",      "poor"),
        ]
        for (day, hour, mood, energy, focus, sleep) in seed {
            let date = cal.date(from: DateComponents(year: 2025, month: 6, day: day, hour: hour))!
            let r = Recording(createdAt: date, audioFileName: "preview.m4a",
                              energyLevel: energy, focusLevel: focus, mood: mood, sleepQuality: sleep)
            ctx.insert(r)
            if [3, 6, 10, 11].contains(day) {
                let e = MedicationEvent(name: "Concerta", takenAt: date, taken: true, source: .manual)
                ctx.insert(e); e.recording = r
            }
        }
        try? ctx.save()
        let s = RecordingStore(context: ctx)
        let vm = InsightsViewModel(store: s)
        vm.currentMonth = june2025
        return vm
    }
}
#endif
