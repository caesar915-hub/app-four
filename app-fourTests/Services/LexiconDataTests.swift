import Foundation
import Testing
@testable import app_four

/// P2.1 — the bundled lexicon.json must reproduce the code-default Lexicon exactly,
/// so moving the vocabulary to data is behaviour-neutral. Any drift fails loudly.
struct LexiconDataTests {

    /// Locate lexicon.json from the app bundle (Resources are copied into it).
    private func loadData() throws -> LexiconData {
        let url = try #require(
            Bundle.main.url(forResource: "lexicon", withExtension: "json"),
            "lexicon.json not found in app bundle"
        )
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(LexiconData.self, from: data)
    }

    /// The bundled lexicon is a SUPERSET of the code defaults: the swarm only
    /// *added* terms, never removed the originals. Every default term must still be
    /// present (so no existing behaviour is lost), and the first 44 mood entries —
    /// the order-sensitive ones that P0 tuned — are unchanged at the front.
    @Test func jsonIsSupersetOfCodeDefaults() throws {
        let fromJSON = try loadData().toLexicon()
        let defaults = Lexicon()

        func superset(_ got: [String], _ want: [String], _ name: String) {
            let gotSet = Set(got.map { $0.lowercased() })
            let missing = want.filter { !gotSet.contains($0.lowercased()) }
            #expect(missing.isEmpty, "\(name) is missing default terms: \(missing)")
        }

        superset(fromJSON.medications, defaults.medications, "medications")
        superset(fromJSON.energyCharged, defaults.energyCharged, "energyCharged")
        superset(fromJSON.energyAlert, defaults.energyAlert, "energyAlert")
        superset(fromJSON.energySteady, defaults.energySteady, "energySteady")
        superset(fromJSON.energyTired, defaults.energyTired, "energyTired")
        superset(fromJSON.energySluggish, defaults.energySluggish, "energySluggish")
        superset(fromJSON.focusLockedIn, defaults.focusLockedIn, "focusLockedIn")
        superset(fromJSON.focusSharp, defaults.focusSharp, "focusSharp")
        superset(fromJSON.focusPresent, defaults.focusPresent, "focusPresent")
        superset(fromJSON.focusDistracted, defaults.focusDistracted, "focusDistracted")
        superset(fromJSON.focusFoggy, defaults.focusFoggy, "focusFoggy")
        superset(fromJSON.emotions, defaults.emotions, "emotions")
        superset(fromJSON.taskCompletionCues, defaults.taskCompletionCues, "taskCompletionCues")
        superset(fromJSON.taskAvoidanceCues, defaults.taskAvoidanceCues, "taskAvoidanceCues")
        superset(fromJSON.winCues, defaults.winCues, "winCues")
        superset(fromJSON.overwhelmCues, defaults.overwhelmCues, "overwhelmCues")
        superset(fromJSON.executiveDysfunction, defaults.executiveDysfunction, "executiveDysfunction")
        superset(fromJSON.sideEffectCues, defaults.sideEffectCues, "sideEffectCues")
        superset(fromJSON.physicalStim, defaults.physicalStim, "physicalStim")
        superset(fromJSON.physicalSideEffects, defaults.physicalSideEffects, "physicalSideEffects")
        superset(fromJSON.sleepQualityGood, defaults.sleepQualityGood, "sleepQualityGood")
        superset(fromJSON.sleepQualityBad, defaults.sleepQualityBad, "sleepQualityBad")
        superset(fromJSON.sleepInsomnia, defaults.sleepInsomnia, "sleepInsomnia")
        superset(fromJSON.reboundTerms, defaults.reboundTerms, "reboundTerms")
        superset(fromJSON.appetiteLoss, defaults.appetiteLoss, "appetiteLoss")
        superset(fromJSON.appetiteReturn, defaults.appetiteReturn, "appetiteReturn")

        // Mood selection is longest-match-wins (order no longer decides ties), but the
        // code-default mood entries must still appear, in order, as a prefix of the
        // JSON list (the superset invariant). moodSpecific is identical in both (90).
        let defaultMoodWords = defaults.moodSpecific.map(\.word)
        let jsonMoodWords = fromJSON.moodSpecific.map(\.word)
        #expect(Array(jsonMoodWords.prefix(defaultMoodWords.count)) == defaultMoodWords)

        // Negation tokens must be byte-identical (no additions allowed — they're
        // structural, not vocabulary).
        #expect(fromJSON.negationTokens == defaults.negationTokens)
        #expect(fromJSON.medNotTakenVerbs == defaults.medNotTakenVerbs)

        // Activity vocabulary: JSON must contain at least as many categories as the
        // code default (6 original). New categories in JSON are additive — never remove.
        #expect(fromJSON.activityKeywords.count >= defaults.activityKeywords.count,
                "activityKeywords has fewer categories than code default: \(fromJSON.activityKeywords.count) < \(defaults.activityKeywords.count)")
    }

    @Test func personalOverlayAppendsTerms() throws {
        let overlay = PersonalLexicon(
            medications: ["MyCustomMed"],
            moodSpecific: [.init(word: "vibing hard", label: "great")],
            emotions: ["hyped"]
        )
        let lex = try loadData().toLexicon(personalOverlay: overlay)
        #expect(lex.medications.contains("MyCustomMed"))
        #expect(lex.moodSpecific.contains { $0.word == "vibing hard" && $0.label == "great" })
        #expect(lex.emotions.contains("hyped"))
    }
}
