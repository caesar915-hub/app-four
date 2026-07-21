import Foundation
import SwiftData
import Testing
@testable import app_four

@MainActor
struct MedicationPickerViewModelTests {

    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        let config = ModelConfiguration(schema: Schema(versionedSchema: SquirlSchemaV1.self), isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Schema(versionedSchema: SquirlSchemaV1.self),
            migrationPlan: SquirlMigrationPlan.self,
            configurations: [config]
        )
        context = container.mainContext
    }

    @Test func mergePutsCatalogFirstThenNovelHistory() {
        let result = MedicationPickerViewModel.merge(
            catalog: ["Concerta", "Ritalin", "Elvanse"],
            history: ["Vyvanse", "Adderall"]
        )
        #expect(result == ["Concerta", "Ritalin", "Elvanse", "Vyvanse", "Adderall"])
    }

    @Test func mergeFoldsHistoryThatMatchesACatalogBaseName() {
        let result = MedicationPickerViewModel.merge(
            catalog: ["Concerta", "Ritalin", "Elvanse"],
            history: ["Concerta 36mg", "concerta", "Vyvanse"]
        )
        // Both Concerta variants fold into the catalog entry; only Vyvanse is novel.
        #expect(result == ["Concerta", "Ritalin", "Elvanse", "Vyvanse"])
    }

    @Test func mergeDedupesWithinHistory() {
        let result = MedicationPickerViewModel.merge(
            catalog: [],
            history: ["Vyvanse 30mg", "vyvanse", "Adderall"]
        )
        #expect(result == ["Vyvanse 30mg", "Adderall"])
    }

    @Test func baseNameStripsDoseAndLowercases() {
        #expect(MedicationPickerViewModel.baseName("Concerta 36 mg") == "concerta")
        #expect(MedicationPickerViewModel.baseName("RITALIN") == "ritalin")
        #expect(MedicationPickerViewModel.baseName("Elvanse") == "elvanse")
    }

    @Test func catalogEntryResolvesKnownAndUnknown() {
        let vm = MedicationPickerViewModel(context: context)
        #expect(vm.catalogEntry(for: "Concerta 36 mg")?.name == "Concerta")
        #expect(vm.catalogEntry(for: "Vyvanse") == nil)
    }
}
