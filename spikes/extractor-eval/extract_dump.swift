import Foundation

// Full-extraction dump: run the (improved) live NLNoteExtractor over a corpus and
// emit the complete signal set per record, for LLM-judge evaluation. Reads the
// ORIGINAL `text` field (not clean_text). Accepts JSON array or JSONL; dedups by id.

struct Rec: Codable {
    let id: String
    let text: String?
    let clean_text: String?
    let signals: [String]?
}

struct Extraction: Codable {
    let id: String
    let text: String
    let goldSignals: [String]   // presence labels, for the judge's reference
    let mood: String?
    let energy: String?
    let focus: String?
    let feelings: [String]
    let activities: [String]
    let meds: [String]
    let sleepHours: Double?
    let sideEffect: Bool
    let title: String
}

@main
struct Dump {
    static func load(_ path: String) -> [Rec] {
        guard let raw = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8) else { return [] }
        let dec = JSONDecoder()
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var recs: [Rec] = []
        if t.hasPrefix("[") {
            recs = (try? dec.decode([Rec].self, from: Data(t.utf8))) ?? []
        } else {
            for line in t.split(separator: "\n") {
                let l = line.trimmingCharacters(in: .whitespaces)
                if !l.isEmpty, let r = try? dec.decode(Rec.self, from: Data(l.utf8)) { recs.append(r) }
            }
        }
        var seen = Set<String>(); var out: [Rec] = []
        for r in recs where !seen.contains(r.id) { seen.insert(r.id); out.append(r) }
        return out
    }

    static func main() {
        let args = CommandLine.arguments
        let lexPath  = args.count > 1 ? args[1] : "app-four/Resources/lexicon.json"
        let dataPath = args.count > 2 ? args[2] : "spikes/extractor-eval/data/addrec_500_clean.json"
        let lexicon: Lexicon = {
            if let d = try? Data(contentsOf: URL(fileURLWithPath: lexPath)),
               let dec = try? JSONDecoder().decode(LexiconData.self, from: d) { return dec.toLexicon() }
            return Lexicon()
        }()
        let extractor = NLNoteExtractor(lexicon: lexicon)
        let recs = load(dataPath)
        var out: [Extraction] = []
        for rec in recs {
            let txt = rec.text ?? rec.clean_text ?? ""
            let r = extractor.extract(from: txt)
            out.append(Extraction(
                id: rec.id, text: txt, goldSignals: rec.signals ?? [],
                mood: r.mood, energy: r.energy?.rawValue, focus: r.focus?.rawValue,
                feelings: r.feelings, activities: r.activities,
                meds: r.medications.map(\.name), sleepHours: r.sleepHours,
                sideEffect: !(r.sideEffects.isEmpty && r.physicalSideEffects.isEmpty),
                title: r.title))
        }
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(out) { FileHandle.standardOutput.write(data) }
        FileHandle.standardError.write(Data("dumped \(out.count) extractions\n".utf8))
    }
}
