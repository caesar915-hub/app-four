import XCTest
@testable import app_four

final class MedicalTermCorrectorTests: XCTestCase {
    
    func testEnglishCorrections() {
        let corrector = MedicalTermCorrector(language: "en")
        
        // Test medication names
        XCTAssertEqual(corrector.correct("I took some Concert today"), "I took some Concerta today")
        XCTAssertEqual(corrector.correct("The vyvans worked well"), "The Vyvanse worked well")
        XCTAssertEqual(corrector.correct("Took 36mg of concerta"), "Took 36mg of concerta") // Preserves lowercase
        
        // Test therapy terms
        XCTAssertEqual(corrector.correct("I had a see bee tea session"), "I had a CBT session")
        XCTAssertEqual(corrector.correct("Dealing with executive function"), "Dealing with executive dysfunction")
        
        // Test split words
        XCTAssertEqual(corrector.correct("I am very hyper focus"), "I am very hyperfocus")
        XCTAssertEqual(corrector.correct("The adder all was strong"), "The Adderall was strong")
    }
    
    func testPortugueseCorrections() {
        let corrector = MedicalTermCorrector(language: "pt")
        
        XCTAssertEqual(corrector.correct("Meu tdah está difícil"), "Meu TDAH está difícil")
        XCTAssertEqual(corrector.correct("Tomei venvanse de manhã"), "Tomei Venvanse de manhã")
        XCTAssertEqual(corrector.correct("Sinto muito hiper foco"), "Sinto muito hiperfoco")
    }
    
    func testWordBoundaries() {
        let corrector = MedicalTermCorrector(language: "en")
        
        // Should NOT match "concert" inside "concertina"
        XCTAssertEqual(corrector.correct("I play the concertina"), "I play the concertina")
        
        // Should match "Concert" as a whole word
        XCTAssertEqual(corrector.correct("The Concert was effective"), "The Concerta was effective")
    }
}
