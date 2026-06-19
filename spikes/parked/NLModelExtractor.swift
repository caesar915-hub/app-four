import Foundation
import NaturalLanguage
import CoreML
import os

/// ML-backed extractor for mood / energy / focus.
///
/// Runs the lexicon extractor first (meds, sleep, activities, feelings are better
/// handled by regex), then overrides mood/energy/focus with the three trained
/// NLModel classifiers. For each signal it aggregates per-sentence predictions by
/// `confidence × tense weight` (present-tense wins, matching the lexicon's mood
/// policy), and only overrides the lexicon when the model is confident (≥ `tau`).
///
/// Models load from the app bundle; on a host without the contextual-embedding
/// asset (e.g. the iOS Simulator) `load` returns nil and every signal transparently
/// falls back to the lexicon. The Logger lines make that fallback visible instead of
/// silent — filter Console by subsystem `app-four`, category `MLExtractor`.
public nonisolated struct NLModelExtractor: NoteExtractor, Sendable {

    private let tau: Double
    private let lexicon: NLNoteExtractor
    private let tense = TenseClassifier()

    // NLModel is thread-safe for concurrent reads after init; loaded once, never mutated.
    private nonisolated(unsafe) let moodModel: NLModel?
    private nonisolated(unsafe) let energyModel: NLModel?
    private nonisolated(unsafe) let focusModel: NLModel?

    private static let log = Logger(subsystem: "app-four", category: "MLExtractor")

    public init(lexicon: NLNoteExtractor = NLNoteExtractor(), tau: Double = 0.45) {
        self.lexicon = lexicon
        self.tau = tau
        self.moodModel   = NLModelExtractor.load("MoodClassifier")
        self.energyModel = NLModelExtractor.load("EnergyClassifier")
        self.focusModel  = NLModelExtractor.load("FocusClassifier")
        let (m, e, f) = (moodModel != nil, energyModel != nil, focusModel != nil)
        Self.log.notice("models loaded — mood:\(m, privacy: .public) energy:\(e, privacy: .public) focus:\(f, privacy: .public)")
    }

    public func extract(from transcript: String) -> NoteExtraction {
        var result = lexicon.extract(from: transcript)
        let sentences = splitSentences(transcript)

        if let model = moodModel {
            let ml = classify(sentences, model)
            log("mood", ml, lexiconValue: result.mood)
            if let label = ml?.label, let v = MoodLevel(rawValue: label)?.rawValue { result.mood = v }
        }
        if let model = energyModel {
            let ml = classify(sentences, model)
            log("energy", ml, lexiconValue: result.energy?.rawValue)
            if let label = ml?.label, let v = EnergyLevel(rawValue: label) { result.energy = v }
        }
        if let model = focusModel {
            let ml = classify(sentences, model)
            log("focus", ml, lexiconValue: result.focus?.rawValue)
            if let label = ml?.label, let v = FocusLevel(rawValue: label) { result.focus = v }
        }

        return result
    }

    // MARK: - Private

    /// Aggregate per-sentence predictions: `confidence × tense weight`, strongest wins.
    /// Tense weighting makes present-tense statements ("now I have no focus") beat
    /// past-tense ones ("I was able to focus") so a note's *current* state is the headline.
    private func classify(_ sentences: [String], _ model: NLModel) -> (label: String, score: Double, raw: Double)? {
        var best: (label: String, score: Double, raw: Double)?
        for sentence in sentences {
            let hypotheses = model.predictedLabelHypotheses(for: sentence, maximumCount: 1)
            guard let top = hypotheses.max(by: { $0.value < $1.value }),
                  top.key != "none",
                  top.value >= tau else { continue }
            let score = top.value * tense.tense(of: sentence).temporalWeight
            if best == nil || score > best!.score {
                best = (top.key, score, top.value)
            }
        }
        return best
    }

    private func log(_ signal: String, _ ml: (label: String, score: Double, raw: Double)?, lexiconValue: String?) {
        if let ml {
            Self.log.notice("\(signal, privacy: .public): ML \(ml.label, privacy: .public) (raw \(ml.raw, format: .fixed(precision: 2), privacy: .public), weighted \(ml.score, format: .fixed(precision: 2), privacy: .public)) — lexicon was \(lexiconValue ?? "nil", privacy: .public)")
        } else {
            Self.log.notice("\(signal, privacy: .public): ML abstained — keeping lexicon \(lexiconValue ?? "nil", privacy: .public)")
        }
    }

    private func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = String(text[range]).trimmingCharacters(in: .whitespaces)
            if s.count > 3 { sentences.append(s) }
            return true
        }
        return sentences
    }

    private static func load(_ name: String) -> NLModel? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc")
                     ?? Bundle.main.url(forResource: name, withExtension: "mlmodel") else {
            return nil
        }
        return try? NLModel(contentsOf: url)
    }
}
