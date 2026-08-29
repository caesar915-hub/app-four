import Testing
import Foundation
@testable import app_four

@Suite struct UnifiedExtractionTests {
    
    @Test func decodesCompleteJSON() throws {
        let json = """
        {
            "mood": "good",
            "energy": "steady",
            "focus": "sharp",
            "sleepHours": 7.5,
            "sleepQuality": "good",
            "medications": [
                {
                    "name": "Vyvanse",
                    "dose": "30mg",
                    "taken": true
                }
            ],
            "emotions": ["excited"],
            "activities": ["Work"],
            "topics": ["Medications"],
            "lexicon": ["took my addy"],
            "summary": "You had a good day",
            "sideEffects": ["appetite loss"]
        }
        """
        
        let data = json.data(using: .utf8)!
        let extraction = try JSONDecoder().decode(UnifiedExtraction.self, from: data)
        
        #expect(extraction.mood == "good")
        #expect(extraction.energy == "steady")
        #expect(extraction.focus == "sharp")
        #expect(extraction.sleepHours == 7.5)
        #expect(extraction.sleepQuality == "good")
        #expect(extraction.medications.count == 1)
        #expect(extraction.medications[0].name == "Vyvanse")
        #expect(extraction.medications[0].dose == "30mg")
        #expect(extraction.medications[0].taken == true)
        #expect(extraction.emotions == ["excited"])
        #expect(extraction.activities == ["Work"])
        #expect(extraction.topics == ["Medications"])
        #expect(extraction.lexicon == ["took my addy"])
        #expect(extraction.summary == "You had a good day")
        #expect(extraction.sideEffects == ["appetite loss"])
    }
    
    @Test func decodesPartialJSON() throws {
        let json = """
        {
            "mood": "good",
            "energy": "steady"
        }
        """
        
        let data = json.data(using: .utf8)!
        let extraction = try JSONDecoder().decode(UnifiedExtraction.self, from: data)
        
        #expect(extraction.mood == "good")
        #expect(extraction.energy == "steady")
        #expect(extraction.focus == nil)
        #expect(extraction.sleepHours == nil)
        #expect(extraction.sleepQuality == nil)
        #expect(extraction.medications.isEmpty)
        #expect(extraction.emotions.isEmpty)
        #expect(extraction.activities.isEmpty)
        #expect(extraction.topics.isEmpty)
        #expect(extraction.lexicon.isEmpty)
        #expect(extraction.summary == nil)
        #expect(extraction.sideEffects.isEmpty)
    }
    
    @Test func medicationExtractionDecodes() throws {
        let json = """
        {
            "name": "Concerta",
            "dose": "36mg",
            "taken": true
        }
        """
        
        let data = json.data(using: .utf8)!
        let med = try JSONDecoder().decode(MedicationExtraction.self, from: data)
        
        #expect(med.name == "Concerta")
        #expect(med.dose == "36mg")
        #expect(med.taken == true)
        
        let jsonPartial = """
        {
            "name": "Concerta"
        }
        """
        let dataPartial = jsonPartial.data(using: .utf8)!
        let medPartial = try JSONDecoder().decode(MedicationExtraction.self, from: dataPartial)
        
        #expect(medPartial.name == "Concerta")
        #expect(medPartial.dose == nil)
        #expect(medPartial.taken == true)
    }
}
