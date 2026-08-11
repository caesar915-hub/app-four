import Testing
import Foundation
@testable import app_four

@Suite struct ParseExtractionTests {
    let baseJson = """
    {"mood":"good","medications":[],"emotions":[],"activities":[],"topics":[],"lexicon":[],"sideEffects":[]}
    """
    
    @Test func directDecodeSucceeds() {
        let result = ExtractionValidator.parseExtraction(from: baseJson)
        #expect(result != nil)
        #expect(result?.mood == "good")
    }
    
    @Test func backtickWrappedJsonRecovered() {
        let string = "```json\n\(baseJson)\n```"
        let result = ExtractionValidator.parseExtraction(from: string)
        #expect(result != nil)
        #expect(result?.mood == "good")
    }
    
    @Test func proseWrappedJsonRecovered() {
        let string = "Here is the extraction:\n\(baseJson)\nI hope this helps!"
        let result = ExtractionValidator.parseExtraction(from: string)
        #expect(result != nil)
        #expect(result?.mood == "good")
    }
    
    @Test func totallyUnparseableReturnsNil() {
        let result = ExtractionValidator.parseExtraction(from: "just some random text")
        #expect(result == nil)
    }
    
    @Test func emptyStringReturnsNil() {
        let result = ExtractionValidator.parseExtraction(from: "")
        #expect(result == nil)
    }
}
