import SwiftUI

struct TextCheckInComposer: View {
    let recentMedicationNames: [String]
    let onSave: (CheckInDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = CheckInDraft()
    @State private var showMedSheet = false

    private let sleepOptions = ["poor", "okay", "good"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    SignalScaleRow(title: "Mood", selection: $draft.mood)
                    SignalScaleRow(title: "Energy", selection: $draft.energy)
                    SignalScaleRow(title: "Focus", selection: $draft.focus)
                    medsRow
                    sleepRow
                    noteRow
                }
                .padding(Spacing.l)
            }
            .navigationTitle("New note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.isEmpty)
                }
            }
            .sheet(isPresented: $showMedSheet) {
                MedicationLogSheet { name, dose, takenAt, durationHours in
                    draft.meds.append(
                        CheckInDraft.DraftMedication(name: name, dose: dose, takenAt: takenAt, durationHours: durationHours)
                    )
                }
            }
        }
    }

    private var medsRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            fieldLabel("Meds")
            FlowChips {
                ForEach(recentMedicationNames, id: \.self) { name in
                    let isOn = draft.meds.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                    chip(name + (isOn ? " ✓" : ""), on: isOn, tint: Palette.medication) {
                        if isOn {
                            draft.meds.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                        } else {
                            draft.meds.append(CheckInDraft.DraftMedication(name: name, dose: nil))
                        }
                    }
                }
                ForEach(draft.meds.filter { med in
                    !recentMedicationNames.contains { $0.caseInsensitiveCompare(med.name) == .orderedSame }
                }) { med in
                    chip(med.name + " ✓", on: true, tint: Palette.medication) {
                        draft.meds.removeAll { $0.id == med.id }
                    }
                }
                chip("+ add", on: false, tint: nil) { showMedSheet = true }
            }
        }
    }

    private var sleepRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            fieldLabel("Sleep")
            FlowChips {
                ForEach(sleepOptions, id: \.self) { option in
                    chip(option.capitalized, on: draft.sleepQuality == option, tint: nil) {
                        draft.sleepQuality = draft.sleepQuality == option ? nil : option
                    }
                }
            }
        }
    }

    private var noteRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                fieldLabel("Note")
                Spacer()
                Text("optional")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            TextEditor(text: $draft.note)
                .font(Typography.body)
                .scrollContentBackground(.hidden)
                .padding(Spacing.m)
                .frame(minHeight: 110)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.label)
            .textCase(.uppercase)
            .foregroundStyle(Theme.textSecondary)
    }

    private func chip(_ label: String, on: Bool, tint: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Typography.callout)
                .foregroundStyle(on ? (tint ?? Theme.accent) : Theme.textPrimary)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .background(Theme.cardBackground, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(on ? (tint ?? Theme.accent) : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Five equal segments; the selected one fills with the level's gradient.
struct SignalScaleRow<Level: SignalLevel & CaseIterable & Equatable>: View {
    let title: String
    @Binding var selection: Level?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(title)
                    .font(Typography.label)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(selection?.displayLabel ?? "—")
                    .font(Typography.callout)
                    .foregroundStyle(selection == nil ? Theme.textSecondary : Theme.textPrimary)
            }
            HStack(spacing: Spacing.xs + 2) {
                ForEach(Array(Level.allCases), id: \.numericValue) { level in
                    Button {
                        selection = selection == level ? nil : level
                    } label: {
                        RoundedRectangle(cornerRadius: Radius.control)
                            .fill(selection == level ? AnyShapeStyle(level.fillGradient) : AnyShapeStyle(Theme.cardBackground))
                            .frame(height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(level.displayLabel)")
                    .accessibilityAddTraits(selection == level ? [.isSelected] : [])
                }
            }
        }
    }
}

/// Minimal wrapping chip row.
struct FlowChips<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: Spacing.s)], alignment: .leading, spacing: Spacing.s) {
            content
        }
    }
}

#Preview {
    TextCheckInComposer(recentMedicationNames: ["Concerta", "Magnesium"]) { _ in }
}
