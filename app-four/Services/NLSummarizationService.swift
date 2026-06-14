import Foundation

/// Summarization adapter backed by the on-device NaturalLanguage-based
/// `NLNoteExtractor`. Instant; no model load or download required.
struct NLSummarizationService: SummarizationService {

    private let extractor: NLNoteExtractor

    /// Production path loads the bundled, swarm-expanded vocabulary (with an
    /// optional personal overlay). Tests pass an explicit `Lexicon` for
    /// deterministic, minimal vocabularies.
    init(lexicon: Lexicon) {
        self.extractor = NLNoteExtractor(lexicon: lexicon)
    }

    init(personalOverlay: PersonalLexicon? = nil) {
        self.extractor = NLNoteExtractor(lexicon: LexiconLoader.loadBundled(overlay: personalOverlay))
    }

    /// Run the (synchronous, CPU-bound) extraction off the main actor so the UI
    /// never blocks on a long transcript. `NLNoteExtractor` is `Sendable` and
    /// `extract` is `nonisolated`, so a detached task is safe; the extractor
    /// checks `Task.isCancelled` between sentences.
    private nonisolated func runExtraction(on transcript: String) async -> NoteExtraction {
        let extractor = self.extractor
        return await Task.detached(priority: .userInitiated) {
            extractor.extract(from: transcript)
        }.value
    }

    /// Topic categories derived from an extraction's presence signals. Shared so the
    /// eval harness scores the exact same derivation the production pipeline persists.
    static nonisolated func deriveTopics(from extraction: NoteExtraction) -> [String] {
        var topics: [String] = []
        if !extraction.medications.isEmpty { topics.append(TopicCategory.medications.rawValue) }
        if !extraction.sideEffects.isEmpty || !extraction.physicalSideEffects.isEmpty
            || !extraction.reboundTerms.isEmpty || !extraction.appetiteLoss.isEmpty {
            topics.append(TopicCategory.symptoms.rawValue)
        }
        if !extraction.appointments.isEmpty { topics.append(TopicCategory.appointments.rawValue) }
        return topics
    }

    nonisolated func summarize(rawTranscription: String) async throws -> SummaryResult {
        let extraction = await runExtraction(on: rawTranscription)
        let lexicon = extractor.lexicon
        let topics = Self.deriveTopics(from: extraction)

        let sleepEvent: SleepEvent? = extraction.sleep?.mentioned == true ? SleepEvent(
            mentioned: true,
            hours: extraction.sleepHours,
            quality: extraction.sleep?.quality
        ) : nil

        let sleepLevel: SleepLevel? = {
            guard extraction.sleep?.mentioned == true else { return nil }
            if let quality = extraction.sleep?.quality {
                switch quality {
                case "insomnia": return .restless
                case "poor":     return .restless
                case "good":     return .good
                default: break
                }
            }
            if let hours = extraction.sleepHours {
                switch hours {
                case ..<5:   return .restless
                case 5..<6:  return .light
                case 6..<7:  return .okay
                case 7..<9:  return .good
                default:     return .deep
                }
            }
            return nil
        }()

        var seen = Set<String>()
        let sideEffectKeywords = (
            lexicon.sideEffectCues.filter { cue in
                extraction.sideEffects.contains { $0.lowercased().contains(cue) }
            } +
            lexicon.physicalSideEffects.filter { cue in
                extraction.physicalSideEffects.contains { $0.lowercased().contains(cue) }
            }
        ).filter { seen.insert($0).inserted }

        return SummaryResult(
            bullets: extraction.highlights,
            medications: extraction.medications,
            generatedTitle: extraction.title,
            energyLevel: extraction.energy?.rawValue,
            focusLevel: extraction.focus?.rawValue,
            mood: extraction.mood,
            sleepHours: extraction.sleepHours,
            sleepQuality: extraction.sleep?.quality,
            sleepEvent: sleepEvent,
            sleepLevel: sleepLevel?.rawValue,
            sideEffects: sideEffectKeywords,
            feelings: extraction.feelings,
            topics: topics,
            noteExtraction: extraction
        )
    }
}
