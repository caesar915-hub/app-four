import Foundation
import SwiftData

/// Builds a `PersonalLexicon` from the user's own corrections (P2.3).
///
/// `RecordingTag(source: .userCorrected)` rows are written in review confirm. The
/// med and feeling names the user added are personal vocabulary we can layer over
/// the bundled base so future extractions recognise them. (Mood/energy/focus
/// corrections are *value* changes, not new phrases, so they don't extend the
/// lexicon here.)
enum PersonalLexiconBuilder {

    @MainActor
    static func build(from context: ModelContext) -> PersonalLexicon? {
        let userCorrected = TagSource.userCorrected.rawValue
        let medCategory = TagCategory.medication.rawValue
        let feelingsCategory = TagCategory.feelings.rawValue

        let descriptor = FetchDescriptor<RecordingTag>(
            predicate: #Predicate { $0.source == userCorrected }
        )
        guard let tags = try? context.fetch(descriptor), !tags.isEmpty else { return nil }

        var meds: [String] = []
        var feelings: [String] = []
        var seenMeds = Set<String>()
        var seenFeelings = Set<String>()

        for tag in tags {
            let name = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            switch tag.category {
            case medCategory:
                if seenMeds.insert(name.lowercased()).inserted { meds.append(name) }
            case feelingsCategory:
                if seenFeelings.insert(name.lowercased()).inserted { feelings.append(name.lowercased()) }
            default:
                continue
            }
        }

        guard !meds.isEmpty || !feelings.isEmpty else { return nil }
        return PersonalLexicon(medications: meds, feelings: feelings)
    }
}
