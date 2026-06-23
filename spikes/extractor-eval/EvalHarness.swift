import Foundation

struct EvalCaseOutput: Codable {
    let id: String
    let transcript: String
    let expected: String?
    let actual: String?
}

@main
struct EvalHarness {
    static nonisolated func deriveTopics(from extraction: NoteExtraction) -> [String] {
        var topics: [String] = []
        if !extraction.medications.isEmpty { topics.append("Medications") }
        if !extraction.sideEffects.isEmpty || !extraction.physicalSideEffects.isEmpty
            || !extraction.reboundTerms.isEmpty || !extraction.appetiteLoss.isEmpty {
            topics.append("Symptoms")
        }
        if !extraction.appointments.isEmpty { topics.append("Appointments") }
        return topics
    }

    static func main() async throws {
        let lexiconUrl = URL(fileURLWithPath: "app-four/Resources/lexicon.json")
        let lexiconData = try Data(contentsOf: lexiconUrl)
        let decodedLexicon = try JSONDecoder().decode(LexiconData.self, from: lexiconData)
        let lexicon = decodedLexicon.toLexicon(personalOverlay: nil)
        
        let extractor = NLNoteExtractor(lexicon: lexicon)
        var results: [String: [EvalCaseOutput]] = [
            "mood": [],
            "energy": [],
            "focus": [],
            "feelings": [],
            "activities": [],
            "meds": [],
            "sleepHours": [],
            "topics": [],
            "sideEffectFlag": []
        ]

        for c in EvalSet.cases {
            let r = extractor.extract(from: c.transcript)
            
            // mood
            results["mood"]?.append(EvalCaseOutput(id: c.id, transcript: c.transcript, expected: c.mood, actual: r.mood))
            
            // energy
            results["energy"]?.append(EvalCaseOutput(id: c.id, transcript: c.transcript, expected: c.energy?.rawValue, actual: r.energy?.rawValue))
            
            // focus
            results["focus"]?.append(EvalCaseOutput(id: c.id, transcript: c.transcript, expected: c.focus?.rawValue, actual: r.focus?.rawValue))
            
            // feelings
            results["feelings"]?.append(EvalCaseOutput(id: c.id, transcript: c.transcript, 
                expected: c.feelings.sorted().joined(separator: ","), 
                actual: r.feelings.sorted().joined(separator: ",")))
            
            // activities
            results["activities"]?.append(EvalCaseOutput(id: c.id, transcript: c.transcript, 
                expected: c.activities.sorted().joined(separator: ","), 
                actual: r.activities.sorted().joined(separator: ",")))
            
            // meds
            results["meds"]?.append(EvalCaseOutput(id: c.id, transcript: c.transcript, 
                expected: c.medNames.sorted().joined(separator: ","), 
                actual: r.medications.map { $0.name }.sorted().joined(separator: ",")))
            
            // sleepHours
            results["sleepHours"]?.append(EvalCaseOutput(id: c.id, transcript: c.transcript, 
                expected: c.sleepHours.map { String($0) }, 
                actual: r.sleepHours.map { String($0) }))
            
            // topics
            let expectedTopics = c.topics.sorted().joined(separator: ",")
            let actualTopics = Set(deriveTopics(from: r)).sorted().joined(separator: ",")
            results["topics"]?.append(EvalCaseOutput(id: c.id, transcript: c.transcript, 
                expected: expectedTopics, 
                actual: actualTopics))
            
            // sideEffectFlag
            let expectedSideFx = c.anySideEffect ? "yes" : nil
            let actualSideFx = !(r.sideEffects.isEmpty && r.physicalSideEffects.isEmpty) ? "yes" : nil
            results["sideEffectFlag"]?.append(EvalCaseOutput(id: c.id, transcript: c.transcript, 
                expected: expectedSideFx, 
                actual: actualSideFx))
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(results)
        
        let url = URL(fileURLWithPath: "spikes/extractor-eval/eval_dump.json")
        try data.write(to: url)
        print("Wrote results to spikes/extractor-eval/eval_dump.json")
    }
}
