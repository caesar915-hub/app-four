import Testing
import Foundation
@testable import app_four

@Suite struct GemmaSignalsToolTests {
    @Test func decodesFromSignalsJSONKeys() throws {
        let json = """
        {"mood":"good","energy":"steady","focus":"sharp","sleepHours":7.5,
         "sleepQuality":"good","medications":[{"name":"Vyvanse","taken":true}],
         "emotions":["calm"],"activities":["work"],"topics":["Focus"],
         "lexicon":["locked in"],"sideEffects":["dry mouth"],"summary":"You had a steady day."}
        """
        let args = try JSONDecoder().decode(SignalsToolArguments.self, from: Data(json.utf8))
        #expect(args.mood == "good")
        #expect(args.energy == "steady")
        #expect(args.sleepHours == 7.5)
        #expect(args.medications.first?.name == "Vyvanse")
        #expect(args.emotions == ["calm"])
        #expect(args.summary == "You had a steady day.")
    }

    @Test func missingCollectionsDefaultToEmpty() throws {
        let args = try JSONDecoder().decode(SignalsToolArguments.self, from: Data(#"{"mood":"okay"}"#.utf8))
        #expect(args.mood == "okay")
        #expect(args.medications.isEmpty)
        #expect(args.emotions.isEmpty)
        #expect(args.topics.isEmpty)
        #expect(args.sideEffects.isEmpty)
        #expect(args.summary == nil)
    }

    @Test func mapsToUnifiedExtractionFieldForField() {
        let args = SignalsToolArguments(
            mood: "good", energy: "steady", focus: "sharp",
            sleepHours: 7.0, sleepQuality: "good",
            medications: [MedicationExtraction(name: "Vyvanse", dose: nil, taken: true)],
            emotions: ["calm"], activities: ["work"], topics: ["Focus"],
            lexicon: ["locked in"], sideEffects: ["dry mouth"], summary: "steady day"
        )
        let ue = SignalsTool.unifiedExtraction(from: args)
        #expect(ue.mood == "good")
        #expect(ue.energy == "steady")
        #expect(ue.focus == "sharp")
        #expect(ue.sleepHours == 7.0)
        #expect(ue.medications.first?.name == "Vyvanse")
        #expect(ue.topics == ["Focus"])
        #expect(ue.summary == "steady day")
    }

    /// The load-bearing invariant: the Tool-Use path and the free-form-JSON path
    /// converge on the SAME UnifiedExtraction for the same logical content.
    @Test func toolPathAndFreeFormPathConverge() throws {
        let args = SignalsToolArguments(
            mood: "good", energy: "steady", focus: "sharp",
            medications: [MedicationExtraction(name: "Vyvanse", dose: nil, taken: true)],
            emotions: ["calm"], topics: ["work"], summary: "You had a steady day."
        )
        let json = """
        {"mood":"good","energy":"steady","focus":"sharp",
         "medications":[{"name":"Vyvanse","taken":true}],
         "emotions":["calm"],"topics":["work"],"summary":"You had a steady day."}
        """
        let fromTool = SignalsTool.unifiedExtraction(from: args)
        let fromJSON = try #require(ExtractionValidator.parseExtraction(from: json))
        #expect(fromTool == fromJSON)
    }
}
