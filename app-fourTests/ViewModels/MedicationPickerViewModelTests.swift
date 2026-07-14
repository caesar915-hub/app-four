import Foundation
import SwiftData
import Testing
@testable import app_four

@Suite(.serialized)
@MainActor
struct MedicationPickerViewModelTests {

    private static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: Recording.self, MedicationEvent.self, AppSettings.self,
            configurations: config
        )
    }()

    private let context: ModelContext

    init() throws {
        context = Self.container.mainContext
        try context.delete(model: Recording.self)
        try context.delete(model: MedicationEvent.self)
        try context.delete(model: AppSettings.self)
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
