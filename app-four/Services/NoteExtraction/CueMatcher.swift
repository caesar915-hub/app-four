import Foundation
import NaturalLanguage

/// Pre-tokenized cue lists: every cue's token sequence is computed once (at
/// extractor init) instead of on every (sentence × cue) check. Pure value type.
public nonisolated struct CueMatcher: Sendable {

    /// A sentence token plus, for verbs only, its base-form lemma. `verbLemma` is
    /// non-nil ONLY when the token was tagged `.verb` and its lemma differs from
    /// the surface — this is what keeps the lemma fallback verb-only (a noun like
    /// "wires" gets `verbLemma == nil`, so it can never lemma-match a verb cue).
    public struct Token: Sendable {
        public let surface: String
        public let verbLemma: String?
    }

    /// A single cue's pre-tokenized form. `tokens` is the surface token sequence
    /// (used for multi-word contiguous matching). `lemma` is the verb lemma of a
    /// SINGLE-WORD cue (nil for multi-word cues and for cues that don't lemmatize
    /// to a distinct verb form); it lets an inflected sentence verb match a
    /// base-form cue and vice-versa.
    public struct Cue: Sendable {
        let surface: String
        let tokens: [String]
        let lemma: String?
        /// Inflected surface variants that match this cue but emit its canonical
        /// `surface`. Deterministic, sim/device-identical — unlike `lemma`, which
        /// rides `NLTagger`'s lemma model (absent on the iOS simulator).
        let altForms: [String]
    }

    public struct CueList: Sendable {
        let cues: [Cue]
    }

    /// Surface-only word tokenizer. Kept for callers that only need surface tokens
    /// (e.g. highlight dedup); the lemma-aware pipeline uses `tokenizeWithLemmas`.
    public static func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        let lower = text.lowercased()
        tokenizer.string = lower
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: lower.startIndex..<lower.endIndex) { range, _ in
            tokens.append(String(lower[range]))
            return true
        }
        return tokens
    }

    /// Surface tokens via `NLTokenizer` (byte-identical to `tokenize`, so every
    /// existing surface match stays exactly as before). This deliberately does NOT
    /// use `NLTagger`'s `.word` enumeration for boundaries: that splits possessives
    /// and contractions ("doctor's" → "doctor" + "'s"), which would let a bare
    /// "doctor" spuriously match the single-word "doctor" cue. A single `NLTagger`
    /// is built once for the sentence and each token's verb lemma is looked up at
    /// its start index. `verbLemma` is non-nil only for `.verb` tokens whose
    /// non-empty lemma differs from the surface.
    public static func tokenizeWithLemmas(_ text: String) -> [Token] {
        let lower = text.lowercased()
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = lower
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = lower
        var tokens: [Token] = []
        tokenizer.enumerateTokens(in: lower.startIndex..<lower.endIndex) { range, _ in
            let surface = String(lower[range])
            var verbLemma: String?
            let (classTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass)
            if classTag == .verb {
                let (lemmaTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma)
                if let l = lemmaTag?.rawValue.lowercased(), !l.isEmpty, l != surface {
                    verbLemma = l
                }
            }
            tokens.append(Token(surface: surface, verbLemma: verbLemma))
            return true
        }
        return tokens
    }

    /// Lemma of a single-word cue, if it tags as a verb with a distinct base form.
    private static func cueLemma(_ surface: String) -> String? {
        let lower = surface.lowercased()
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = lower
        var result: String?
        tagger.enumerateTags(in: lower.startIndex..<lower.endIndex, unit: .word,
                             scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            guard tag == .verb else { return false }
            let (lemmaTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma)
            if let l = lemmaTag?.rawValue.lowercased(), !l.isEmpty, l != lower {
                result = l
            }
            return false
        }
        return result
    }

    /// `lemmaEnabled` controls the single-word verb-lemma fallback per category.
    /// Default ON for feeling/state/task cues where inflected verbs should reach
    /// their base-form cue ("panicking"→"panicked"). Categories whose single-word
    /// cues are polysemous gerunds or where lemma-bridging hurt precision in the
    /// eval (activities, side-effect/rebound/appetite/appointment topic feeders)
    /// pass `false` and stay surface-only.
    public static func makeList(_ cues: [String], lemmaEnabled: Bool = true) -> CueList {
        CueList(cues: cues.map { surface in
            let tokens = tokenize(surface)
            let lemma = (lemmaEnabled && tokens.count == 1) ? cueLemma(surface) : nil
            let altForms = tokens.count == 1 ? (canonicalInflections[surface.lowercased()] ?? []) : []
            return Cue(surface: surface, tokens: tokens, lemma: lemma, altForms: altForms)
        })
    }

    /// Curated inflected surfaces that denote the SAME feeling/state as their
    /// canonical lexicon entry, matched deterministically. The verb-lemma bridge
    /// (`cue.lemma` ↔ `Token.verbLemma`) rides `NLTagger`'s lemma model, which is
    /// absent on the iOS simulator and so no-ops on-device — this table is the
    /// model-independent path. Only meaning-identical forms are listed:
    /// "panicking" (actively in panic) → "panicked". Cause-describing inflections
    /// ("exhausting", "overwhelming") are deliberately excluded — they don't
    /// denote the feeling and would cost precision.
    static let canonicalInflections: [String: [String]] = [
        "panicked": ["panicking"],
    ]

    /// Longest cue (by surface length) whose tokens appear as a contiguous run.
    public static func longestMatch(in tokens: [Token], list: CueList) -> String? {
        var best: String?
        for cue in list.cues where contains(tokens, cue) {
            if best == nil || cue.surface.count > best!.count { best = cue.surface }
        }
        return best
    }

    public static func anyMatch(in tokens: [Token], list: CueList) -> Bool {
        list.cues.contains { contains(tokens, $0) }
    }

    /// True iff Damerau-Levenshtein distance (substitution/insertion/deletion/
    /// adjacent transposition) between a and b is exactly 1.
    public static func editDistanceIsOne(_ a: String, _ b: String) -> Bool {
        let x = Array(a), y = Array(b)
        if abs(x.count - y.count) > 1 { return false }
        if x == y { return false }
        if x.count == y.count {
            let diffs = zip(x, y).enumerated().filter { $0.element.0 != $0.element.1 }.map(\.offset)
            if diffs.count == 1 { return true }
            if diffs.count == 2, diffs[1] == diffs[0] + 1,
               x[diffs[0]] == y[diffs[1]], x[diffs[1]] == y[diffs[0]] { return true }  // transposition
            return false
        }
        let (longer, shorter) = x.count > y.count ? (x, y) : (y, x)
        var i = 0, j = 0, skipped = false
        while i < longer.count && j < shorter.count {
            if longer[i] == shorter[j] { i += 1; j += 1 }
            else if skipped { return false }
            else { skipped = true; i += 1 }    // one insertion in the longer string
        }
        return true
    }

    /// Multi-word cue: contiguous run of `Token.surface` equal to the cue's surface
    /// tokens. Single-word cue: exact surface OR the verb-lemma fallback — a verb
    /// token whose lemma equals the cue's own verb lemma. The fallback requires BOTH
    /// sides to be inflected verbs sharing a base form ("panicking"/"panicked" →
    /// "panic"), so it only fires when the cue itself is a distinct verb inflection
    /// (`cue.lemma != nil`, i.e. surface ≠ lemma). This deliberately excludes the
    /// base-form / present-tense / state cues ("focus", "present", "clear") — they
    /// keep surface-only matching, which is what prevents the lemma rule from
    /// over-broadening focus/activity/topic precision. A token can only carry a
    /// `verbLemma` when tagged `.verb`, so nouns ("wires") never lemma-match.
    /// A single-word cue also matches any of its curated `altForms` (deterministic
    /// inflections, e.g. "panicking" → "panicked") — the sim/device-stable path
    /// the lemma model can't provide; the canonical `surface` is still what's emitted.
    static func contains(_ tokens: [Token], _ cue: Cue) -> Bool {
        let cueTokens = cue.tokens
        guard !cueTokens.isEmpty else { return false }
        if cueTokens.count == 1 {
            let cs = cueTokens[0]
            let cl = cue.lemma
            let alts = cue.altForms
            return tokens.contains { t in
                if t.surface == cs { return true }
                if alts.contains(t.surface) { return true }
                if let cl, let lemma = t.verbLemma, lemma == cl { return true }
                return false
            }
        }
        guard tokens.count >= cueTokens.count else { return false }
        for start in 0...(tokens.count - cueTokens.count) {
            var matched = true
            for offset in 0..<cueTokens.count where tokens[start + offset].surface != cueTokens[offset] {
                matched = false
                break
            }
            if matched { return true }
        }
        return false
    }
}
