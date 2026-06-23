import Foundation

// Standalone performance-review harness for NLNoteExtractor.
//
// Compiled by run.sh together with the LIVE extractor sources (not copies), so it
// always measures the current app behavior. Loads the real lexicon.json directly
// (replicating LexiconLoader.loadBundled without Bundle.main, which a CLI lacks),
// runs the extractor over EvalSet.cases, and writes one JSON row per case with the
// expected (gold) and actual signals side by side. All scoring/analysis is done in
// Python (analyze.py) — this tool only produces faithful extractions.

let lexiconPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "app-four/Resources/lexicon.json"

let lexicon: Lexicon
if let data = try? Data(contentsOf: URL(fileURLWithPath: lexiconPath)),
   let decoded = try? JSONDecoder().decode(LexiconData.self, from: data) {
    lexicon = decoded.toLexicon()
} else {
    FileHandle.standardError.write(
        Data("WARN: could not load lexicon.json at \(lexiconPath); using code defaults\n".utf8))
    lexicon = Lexicon()
}

let extractor = NLNoteExtractor(lexicon: lexicon)

struct Signals: Codable {
    var mood: String?
    var energy: String?
    var focus: String?
    var feelings: [String]
    var activities: [String]
    var meds: [String]
    var sleepHours: Double?
    var sideEffect: Bool
}

struct Row: Codable {
    let id: String
    let language: String
    let transcript: String
    let expected: Signals
    let actual: Signals
}

// Mirror ExtractionEvalTests.swift semantics exactly (same accessors, same
// sideEffect-flag definition) so this harness and the in-target floor test agree.
var rows: [Row] = []
for c in EvalSet.cases {
    let r = extractor.extract(from: c.transcript)
    let expected = Signals(
        mood: c.mood,
        energy: c.energy?.rawValue,
        focus: c.focus?.rawValue,
        feelings: c.feelings.sorted(),
        activities: c.activities.sorted(),
        meds: c.medNames.sorted(),
        sleepHours: c.sleepHours,
        sideEffect: c.anySideEffect
    )
    let actual = Signals(
        mood: r.mood,
        energy: r.energy?.rawValue,
        focus: r.focus?.rawValue,
        feelings: r.feelings.sorted(),
        activities: r.activities.sorted(),
        meds: r.medications.map(\.name).sorted(),
        sleepHours: r.sleepHours,
        sideEffect: !(r.sideEffects.isEmpty && r.physicalSideEffects.isEmpty)
    )
    rows.append(Row(id: c.id, language: c.language, transcript: c.transcript,
                    expected: expected, actual: actual))
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
FileHandle.standardOutput.write(try encoder.encode(rows))
