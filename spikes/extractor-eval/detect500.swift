import Foundation

// Large-scale DETECTION eval: run the live NLNoteExtractor over an addrec corpus and
// record, per record, which of {mood, energy, focus} the extractor fired on (non-nil)
// vs. the gold `signals` presence labels. Gold is presence-only (no values), so this
// measures detection/coverage — chiefly recall (paraphrase blindness). Precision is
// reported but unreliable (a missing gold label does not mean the signal is absent).
//
// Accepts a JSON array OR JSONL (.jsonl). Deduplicates by `id` (keeps first).

struct AddrecRecord: Codable {
    let id: String
    let text: String?
    let clean_text: String?
    let signals: [String]
    let word_count: Int?
    let clean_word_count: Int?
}

struct DetectOut: Codable {
    let id: String
    let gold: [String]         // sorted subset of {mood, energy, focus}
    let detected: [String]     // categories the extractor produced (non-nil)
    let wordCount: Int
    let snippet: String        // first ~120 chars, for eyeballing misses
}

@main
struct Detect {
    static func loadRecords(_ path: String) -> [AddrecRecord] {
        guard let raw = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8) else {
            FileHandle.standardError.write(Data("ERROR: cannot read \(path)\n".utf8)); return []
        }
        let dec = JSONDecoder()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var records: [AddrecRecord] = []
        if trimmed.hasPrefix("[") {
            records = (try? dec.decode([AddrecRecord].self, from: Data(trimmed.utf8))) ?? []
        } else {
            for line in trimmed.split(separator: "\n") {
                let l = line.trimmingCharacters(in: .whitespaces)
                if l.isEmpty { continue }
                if let r = try? dec.decode(AddrecRecord.self, from: Data(l.utf8)) { records.append(r) }
            }
        }
        // Dedup by id, keep first occurrence.
        var seen = Set<String>(); var deduped: [AddrecRecord] = []
        for r in records where !seen.contains(r.id) { seen.insert(r.id); deduped.append(r) }
        FileHandle.standardError.write(Data("records: \(records.count) raw, \(deduped.count) deduped\n".utf8))
        return deduped
    }

    static func main() {
        let args = CommandLine.arguments
        let lexPath  = args.count > 1 ? args[1] : "app-four/Resources/lexicon.json"
        let dataPath = args.count > 2 ? args[2] : "spikes/extractor-eval/data/addrec_1082_summaries.jsonl"

        let lexicon: Lexicon
        if let d = try? Data(contentsOf: URL(fileURLWithPath: lexPath)),
           let decoded = try? JSONDecoder().decode(LexiconData.self, from: d) {
            lexicon = decoded.toLexicon()
        } else {
            FileHandle.standardError.write(Data("WARN: lexicon.json not found; using defaults\n".utf8))
            lexicon = Lexicon()
        }
        let extractor = NLNoteExtractor(lexicon: lexicon)
        let records = loadRecords(dataPath)

        let tracked = ["mood", "energy", "focus"]
        var outs: [DetectOut] = []
        outs.reserveCapacity(records.count)
        for rec in records {
            let txt = rec.clean_text ?? rec.text ?? ""
            let r = extractor.extract(from: txt)
            var detected: [String] = []
            if r.mood != nil   { detected.append("mood") }
            if r.energy != nil { detected.append("energy") }
            if r.focus != nil  { detected.append("focus") }
            let gold = rec.signals.filter { tracked.contains($0) }.sorted()
            let snippet = String(txt.replacingOccurrences(of: "\n", with: " ").prefix(120))
            outs.append(DetectOut(
                id: rec.id, gold: gold, detected: detected.sorted(),
                wordCount: rec.clean_word_count ?? rec.word_count ?? txt.split(separator: " ").count,
                snippet: snippet))
        }

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(outs) { FileHandle.standardOutput.write(data) }
    }
}
