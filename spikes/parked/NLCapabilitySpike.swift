import Testing
import Foundation
import NaturalLanguage

/// Capability spike: fires every NaturalLanguage tool discussed against the
/// screenshot's failing transcript + the three documented failure classes, and
/// prints what each one ACTUALLY returns on this run target (sim vs device
/// differences are the whole point — lemma/embedding assets are not uniform).
///
/// Run only on demand:  NL_SPIKE=1  (mirrors ExtractionEvalTests.report()).
/// Output goes to stdout (captured in the xcodebuild test log) and a recorded
/// summary Issue.
struct NLCapabilitySpike {

    // The exact transcript behind the screenshot's three errors.
    static let failing = "Felt good today. Lack of energy end of the day. Took elvanse 50mg, lets see if I can focus now."
    static let sentences = [
        "Felt good today.",                       // C: mood missed ("felt" ≠ "feel")
        "Lack of energy end of the day.",         // B: energy missed (paraphrase / "lack of")
        "Took elvanse 50mg, lets see if I can focus now."  // A: focus falsely "Sharp" (irrealis)
    ]

    @Test(.enabled(if: ProcessInfo.processInfo.environment["NL_SPIKE"] == "1"))
    func spike() {
        var log: [String] = []
        func banner(_ s: String) { print("\n=== \(s) ==="); log.append("\n=== \(s) ===") }
        func line(_ s: String) { print(s); log.append(s) }

        // ─────────────────────────────────────────────────────────────
        banner("PROBE 1 — NLTagger .lemma  (Class C: \"felt\" → \"feel\")")
        // ─────────────────────────────────────────────────────────────
        for s in Self.sentences {
            line("“\(s)”")
            line("  surface → lemma | class:")
            let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
            tagger.string = s
            let opts: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
            tagger.enumerateTags(in: s.startIndex..<s.endIndex, unit: .word,
                                 scheme: .lemma, options: opts) { tag, range in
                let surface = String(s[range])
                let (cls, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass)
                line("    \(surface) → \(tag?.rawValue ?? "∅")  [\(cls?.rawValue ?? "?")]")
                return true
            }
        }
        line("VERDICT: if 'felt'→'feel' here, multi-word lemma matching fixes Class C;")
        line("         if 'felt'→∅ (empty), the lemma model is ABSENT on this target — device only.")

        // ─────────────────────────────────────────────────────────────
        banner("PROBE 2 — NLTagger .lexicalClass  (Class A: is modality visible?)")
        // ─────────────────────────────────────────────────────────────
        let irrealis: Set<String> = ["if", "can", "could", "maybe", "hope", "lets", "let", "see", "will", "might", "should", "want"]
        let modSentence = Self.sentences[2]
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = modSentence
        line("“\(modSentence)”")
        tagger.enumerateTags(in: modSentence.startIndex..<modSentence.endIndex, unit: .word,
                             scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let w = String(modSentence[range]).lowercased()
            let flag = irrealis.contains(w) ? "  ⟵ irrealis marker" : ""
            line("    \(w)  [\(tag?.rawValue ?? "?")]\(flag)")
            return true
        }
        line("VERDICT: note NL gives NO 'modal/conditional' tag — 'can'/'if' look like ordinary")
        line("         verb/conjunction. Class A must be a RULE gate on these markers, not an NL feature.")

        // ─────────────────────────────────────────────────────────────
        banner("PROBE 3 — NLTagger .sentimentScore  (the re-investigation)")
        // ─────────────────────────────────────────────────────────────
        func sentiment(_ text: String) -> String {
            let t = NLTagger(tagSchemes: [.sentimentScore])
            t.string = text
            let (tag, _) = t.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
            return tag?.rawValue ?? "∅"
        }
        line("whole transcript: \(sentiment(Self.failing))   (range −1.0 … +1.0)")
        for s in Self.sentences { line("  \(sentiment(s))  ← “\(s)”") }
        line("VERDICT: compare to gold mood='good'. If neutral/positive sentences read negative,")
        line("         the documented bias is confirmed and sentiment ≠ mood.")

        // ─────────────────────────────────────────────────────────────
        banner("PROBE 4 — NLEmbedding.wordEmbedding  (Class B: word-level semantics)")
        // ─────────────────────────────────────────────────────────────
        if let emb = NLEmbedding.wordEmbedding(for: .english) {
            line("word embedding AVAILABLE — dimension \(emb.dimension)")
            func d(_ a: String, _ b: String) -> String {
                String(format: "%.3f", emb.distance(between: a, and: b, distanceType: .cosine))
            }
            line("  distance(tired, exhausted) = \(d("tired", "exhausted"))   (low = close)")
            line("  distance(tired, drained)   = \(d("tired", "drained"))")
            line("  distance(tired, charged)   = \(d("tired", "charged"))")
            line("  distance(tired, happy)     = \(d("tired", "happy"))")
            let neighbors = emb.neighbors(for: "tired", maximumCount: 8, distanceType: .cosine)
            line("  neighbors(tired) = \(neighbors.map { "\($0.0)(\(String(format: "%.2f", $0.1)))" }.joined(separator: ", "))")
            line("VERDICT: neighbors() can auto-EXPAND the lexicon offline (no hand-typed synonyms).")
        } else {
            line("word embedding UNAVAILABLE on this target.")
        }

        // ─────────────────────────────────────────────────────────────
        banner("PROBE 5 — NLEmbedding.sentenceEmbedding  (Class B: phrase semantics)")
        // ─────────────────────────────────────────────────────────────
        if let se = NLEmbedding.sentenceEmbedding(for: .english) {
            line("sentence embedding AVAILABLE — dimension \(se.dimension)")
            let phrase = "lack of energy end of the day"
            let anchors = ["tired", "sluggish", "drained", "low energy", "energetic", "charged", "wired"]
            let ranked = anchors
                .map { ($0, se.distance(between: phrase, and: $0, distanceType: .cosine)) }
                .sorted { $0.1 < $1.1 }
            line("nearest level-anchors to “\(phrase)”:")
            for (a, dist) in ranked { line("    \(String(format: "%.3f", dist))  \(a)") }
            line("VERDICT: if a low/sluggish anchor ranks first, embedding-fallback recovers Class B")
            line("         WITHOUT 'lack of energy' ever being in the lexicon.")
        } else {
            line("sentence embedding UNAVAILABLE on this target (often sim-only gap).")
        }

        // ─────────────────────────────────────────────────────────────
        banner("PROBE 6 — NLContextualEmbedding  (Class B rung 2: transformer)")
        // ─────────────────────────────────────────────────────────────
        if let ctx = NLContextualEmbedding(language: .english) {
            line("contextual embedding init OK — dimension \(ctx.dimension), revision \(ctx.revision)")
            line("hasAvailableAssets = \(ctx.hasAvailableAssets)  (false = needs one-time download)")
            if ctx.hasAvailableAssets {
                do {
                    try ctx.load()
                    let r = try ctx.embeddingResult(for: "lack of energy end of the day", language: .english)
                    line("loaded; sequenceLength = \(r.sequenceLength) token vectors of dim \(ctx.dimension)")
                    ctx.unload()
                    line("VERDICT: context-aware vectors available on-device; best paraphrase quality, asset cost.")
                } catch {
                    line("load/embeddingResult threw: \(error.localizedDescription)")
                }
            } else {
                line("VERDICT: assets not present — would require requestAssets() download (skipped in spike).")
            }
        } else {
            line("contextual embedding UNAVAILABLE for .english on this target.")
        }

        // ─────────────────────────────────────────────────────────────
        banner("PROBE 7 — NLGazetteer  (meds: replace hand-rolled matching)")
        // ─────────────────────────────────────────────────────────────
        do {
            let g = try NLGazetteer(dictionary: [
                "medication": ["elvanse", "lisdexamfetamine", "vyvanse", "concerta", "methylphenidate"]
            ], language: .english)
            for term in ["elvanse", "elvance", "Concerta", "banana"] {
                line("  label(\"\(term)\") = \(g.label(for: term.lowercased()) ?? "∅")")
            }
            line("VERDICT: exact gazetteer lookup is clean; note 'elvance' typo → ∅ (gazetteer is exact,")
            line("         so your edit-distance typo layer still earns its keep).")
        } catch {
            line("NLGazetteer threw: \(error.localizedDescription)")
        }

        // ─────────────────────────────────────────────────────────────
        banner("PROBE 8 — NLLanguageRecognizer  (you have EN/PT/ES eval cases)")
        // ─────────────────────────────────────────────────────────────
        let samples = [
            "Felt good today, took my meds.",
            "Tomei meu remédio hoje e me senti bem.",
            "Hoy me sentí con mucha energía después de la medicación."
        ]
        for s in samples {
            let rec = NLLanguageRecognizer()
            rec.processString(s)
            let hyp = rec.languageHypotheses(withMaximum: 2)
                .sorted { $0.value > $1.value }
                .map { "\($0.key.rawValue):\(String(format: "%.2f", $0.value))" }
                .joined(separator: ", ")
            line("  \(rec.dominantLanguage?.rawValue ?? "?")  [\(hyp)]  ← “\(s)”")
        }
        line("VERDICT: lets you route to per-language lexicons/embeddings instead of one EN list.")

        // ─────────────────────────────────────────────────────────────
        banner("PROBE 9 — NLModel  (Create ML classifier: the all-three fix)")
        // ─────────────────────────────────────────────────────────────
        line("Not run live — requires a trained .mlmodel. API shape:")
        line("    let model = try NLModel(contentsOf: urlToCompiledModel)")
        line("    model.predictedLabel(for: \"lets see if I can focus now\")  // → \"none\" if trained right")
        line("VERDICT: a sentence classifier learns modality + paraphrase + morphology from labeled")
        line("         examples at once. Your EvalSet.swift is the seed training set. On-device, no LLM.")

        Issue.record(Comment(rawValue: "NL SPIKE REPORT\n" + log.joined(separator: "\n")))
    }
}
