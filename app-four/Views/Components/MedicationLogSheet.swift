import SwiftUI

struct MedicationLogSheet: View {
    let onLog: (String, String?, Date) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var dose = ""
    @State private var takenAt = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                    TextField("Dose (optional)", text: $dose)
                        .autocorrectionDisabled()
                }

                Section("Taken at") {
                    DatePicker("Time", selection: $takenAt, displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle("Log Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onLog(name, dose.isEmpty ? nil : dose, takenAt)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    MedicationLogSheet(onLog: { _, _, _ in })
}
