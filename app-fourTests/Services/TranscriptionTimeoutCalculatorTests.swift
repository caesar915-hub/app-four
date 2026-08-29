import Testing
import Foundation
@testable import app_four

@Suite struct TranscriptionTimeoutCalculatorTests {
    
    @Test func shortRecordingUsesMinimumTimeout() {
        let timeout = TranscriptionTimeoutCalculator.timeout(for: 5.0, thermalState: .nominal)
        #expect(timeout == 60.0)
    }
    
    @Test func nominalDurationUsesCorrectFormula() {
        // 300s * 0.4 + 30 = 150
        let timeout = TranscriptionTimeoutCalculator.timeout(for: 300.0, thermalState: .nominal)
        #expect(timeout == 150.0)
    }
    
    @Test func fairThermalMatchesNominal() {
        let timeout = TranscriptionTimeoutCalculator.timeout(for: 300.0, thermalState: .fair)
        #expect(timeout == 150.0)
    }
    
    @Test func seriousThermalScalesUp() {
        // 300s * 0.6 + 30 = 210
        let timeout = TranscriptionTimeoutCalculator.timeout(for: 300.0, thermalState: .serious)
        #expect(timeout == 210.0)
    }
    
    @Test func criticalThermalUsesHighestMultiplier() {
        // 480s * 0.8 + 30 = 414
        let timeout = TranscriptionTimeoutCalculator.timeout(for: 480.0, thermalState: .critical)
        #expect(timeout == 414.0)
    }
    
    @Test func longRecordingInCriticalStillExceedsFloor() {
        let timeout = TranscriptionTimeoutCalculator.timeout(for: 60.0, thermalState: .critical)
        #expect(timeout == 78.0)
        #expect(timeout > 60.0)
    }
    
    @Test func zeroDurationUsesFloor() {
        let timeout = TranscriptionTimeoutCalculator.timeout(for: 0.0, thermalState: .nominal)
        #expect(timeout == 60.0)
    }
}
