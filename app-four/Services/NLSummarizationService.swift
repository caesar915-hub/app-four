import Foundation

/// Summarization adapter backed by the on-device NaturalLanguage-based
/// `NLNoteExtractor`. Instant; no model load or download required.
struct NLSummarizationService: SummarizationService {

    /// A fixed extractor (test seam — explicit `Lexicon`), or `nil` when the pack
    /// is selected per check-in from the detected language + device region.
    private let fixedExtractor: NLNoteExtractor?
    private let personalOverlay: PersonalLexicon?

    /// Tests pass an explicit `Lexicon` for deterministic, minimal vocabularies —
    /// this bypasses language detection.
    init(lexicon: Lexicon) {
        self.fixedExtractor = NLNoteExtractor(lexicon: lexicon)
        self.personalOverlay = nil
    }

    /// Production path: the language pack is chosen per check-in (with an optional
    /// personal overlay threaded through).
    init(personalOverlay: PersonalLexicon? = nil) {
        self.fixedExtractor = nil
        self.personalOverlay = personalOverlay
    }

    /// The extractor for one check-in: the fixed test extractor, or the pack chosen
    /// from the check-in's own language + device region (production).
    private nonisolated func extractor(for transcript: String) -> NLNoteExtractor {
        fixedExtractor ?? LanguagePackLoader.extractor(for: transcript, overlay: personalOverlay)
    }

    /// Run the (synchronous, CPU-bound) extraction off the main actor so the UI
    /// never blocks on a long transcript. `NLNoteExtractor` is `Sendable` and
    /// `extract` is `nonisolated`, so a detached task is safe; the extractor
    /// checks `Task.isCancelled` between sentences.
    private static nonisolated func runExtraction(_ extractor: NLNoteExtractor, on transcript: String) async -> NoteExtraction {
        await Task.detached(priority: .userInitiated) {
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
        let extractor = extractor(for: rawTranscription)
        let extraction = await Self.runExtraction(extractor, on: rawTranscription)
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
            emotions: extraction.emotions,
            topics: topics,
            noteExtraction: extraction
        )
    }
}
