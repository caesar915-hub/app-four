import Testing
@testable import app_four

struct MedicationCatalogTests {

    @Test func hasExactlyThreeNamedEntries() {
        #expect(MedicationCatalog.all.count == 3)
        #expect(Set(MedicationCatalog.all.map(\.name)) == ["Concerta", "Ritalin", "Elvanse"])
    }

    @Test func everyEntryIsWellFormed() {
        for entry in MedicationCatalog.all {
            #expect(!entry.doseOptions.isEmpty)
            #expect(entry.onsetMinutes > 0)
            #expect(entry.durationHours > 0)
        }
    }

    @Test func namesAreUnique() {
        let names = MedicationCatalog.all.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test func concertaData() {
        let concerta = MedicationCatalog.entry(matching: "Concerta")
        #expect(concerta?.doseOptions.count == 4)
        #expect(concerta?.onsetMinutes == 60)
        #expect(concerta?.durationHours == 12)
    }

    @Test func elvanseAndRitalinData() {
        #expect(MedicationCatalog.entry(matching: "Elvanse")?.doseOptions.count == 6)
        #expect(MedicationCatalog.entry(matching: "Elvanse")?.onsetMinutes == 90)
        #expect(MedicationCatalog.entry(matching: "Ritalin")?.durationHours == 3)
    }

    @Test func entryMatchingIsCaseAndDoseInsensitive() {
        #expect(MedicationCatalog.entry(matching: "concerta")?.name == "Concerta")
        #expect(MedicationCatalog.entry(matching: "Concerta 36 mg")?.name == "Concerta")
        #expect(MedicationCatalog.entry(matching: "ELVANSE")?.name == "Elvanse")
    }

    @Test func entryMatchingReturnsNilForUnknown() {
        #expect(MedicationCatalog.entry(matching: "Vyvanse") == nil)
        #expect(MedicationCatalog.entry(matching: "") == nil)
        #expect(MedicationCatalog.entry(matching: "   ") == nil)
    }
}
