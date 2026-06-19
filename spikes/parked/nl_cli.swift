#!/usr/bin/env swift
// macOS NL analyzer (scratch — delete when done).
// Per-sentence probe of Apple NaturalLanguage for the A/B/C failure classes.
//
//   swift nl_cli.swift "Felt good today." "lets see if I can focus now."
//   echo "Lack of energy end of the day." | swift nl_cli.swift
//   swift nl_cli.swift            # no input → built-in defaults
//
// Faster on repeat: swiftc -O nl_cli.swift -o nl_cli && ./nl_cli "your text"
import Foundation
import NaturalLanguage

let irrealis: Set<String> = ["if","lets","let","hope","want","wanna","gonna",
    "will","might","maybe","could","can","should","trying","try","see"]
let anchorsEnergy = ["tired","sluggish","drained","low energy","energetic","charged","wired"]

// ── input: args > piped stdin > defaults ─────────────────────────────────────
func inputs() -> [String] {
    let args = Array(CommandLine.arguments.dropFirst())
    if !args.isEmpty { return args }
    if isatty(FileHandle.standardInput.fileDescriptor) == 0 {       // piped
        let data = FileHandle.standardInput.readDataToEndOfFile()
        let lines = (String(data: data, encoding: .utf8) ?? "")
            .split(whereSeparator: \.isNewline).map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !lines.isEmpty { return lines }
    }
    return ["Felt good today.",
            "Lack of energy end of the day.",
            "Took elvanse 50mg, lets see if I can focus now."]
}

let sentEmb = NLEmbedding.sentenceEmbedding(for: .english)

func sentiment(_ t: String) -> String {
    let tg = NLTagger(tagSchemes: [.sentimentScore]); tg.string = t
    return tg.tag(at: t.startIndex, unit: .paragraph, scheme: .sentimentScore).0?.rawValue ?? "∅"
}

func analyze(_ s: String) {
    print("\n──────────────────────────────────────────────")
    print("“\(s)”")

    // lemma + POS  (Class C: does 'felt' normalise to 'feel'?)
    let tg = NLTagger(tagSchemes: [.lemma, .lexicalClass]); tg.string = s
    var marks: [String] = []
    print("  tokens (surface → lemma [POS]):")
    tg.enumerateTags(in: s.startIndex..<s.endIndex, unit: .word, scheme: .lemma,
                     options: [.omitWhitespace, .omitPunctuation]) { tag, r in
        let w = String(s[r]); let lw = w.lowercased()
        let (cls, _) = tg.tag(at: r.lowerBound, unit: .word, scheme: .lexicalClass)
        let flag = irrealis.contains(lw) ? " ⟵ irrealis" : ""
        if irrealis.contains(lw) { marks.append(lw) }
        print("    \(w) → \(tag?.rawValue ?? "∅") [\(cls?.rawValue ?? "?")]\(flag)")
        return true
    }

    // Class A verdict
    let hypothetical = !marks.isEmpty || s.trimmingCharacters(in: .whitespaces).hasSuffix("?")
    print("  IRREALIS (Class A): \(hypothetical ? "YES → suppress state report (\(marks))" : "no")")

    // Class B: sentiment + nearest energy anchor
    print("  sentiment (Class B valence): \(sentiment(s))   (−1 … +1)")
    if let e = sentEmb {
        let ranked = anchorsEnergy
            .map { ($0, e.distance(between: s.lowercased(), and: $0, distanceType: .cosine)) }
            .sorted { $0.1 < $1.1 }.prefix(3)
        let str = ranked.map { "\($0.0)(\(String(format: "%.2f", $0.1)))" }.joined(separator: ", ")
        print("  nearest energy anchors: \(str)")
    }
}

print("Apple NaturalLanguage CLI probe — sentenceEmbedding: \(sentEmb == nil ? "UNAVAILABLE" : "ok")")
for s in inputs() { analyze(s) }
print("")
