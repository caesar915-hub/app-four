import SwiftUI

/// §06 Type-note (Layout A) — signals-first: a custom close/title navbar, the three
/// mood/energy/focus glyph pickers, a single free-text notebox, and a gradient
/// "Save check-in" pill. Meds and sleep are captured by voice and the Edit sheet, not here.
struct TextCheckInComposer: View {
    let onSave: (CheckInDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = CheckInDraft()

    var body: some View {
        VStack(spacing: 0) {
            navbar
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    signalPickers
                    noteBox
                    saveButton
                }
                .padding(Spacing.l)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    // MARK: - Navbar

    private var navbar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(Typography.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(Theme.cardBackground, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.separator, lineWidth: 1))
            }
            .accessibilityLabel("Close")

            Spacer()
            Text("Type a check-in")
                .font(Typography.title)
                .foregroundStyle(Theme.textPrimary)
            Spacer()

            Color.clear.frame(width: 30, height: 30)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
    }

    // MARK: - Signal pickers

    private var signalPickers: some View {
        VStack(spacing: 0) {
            SignalScaleRow(title: "Mood", kind: .mood, selection: $draft.mood)
            Divider().overlay(Theme.separator)
            SignalScaleRow(title: "Energy", kind: .energy, selection: $draft.energy)
            Divider().overlay(Theme.separator)
            SignalScaleRow(title: "Focus", kind: .focus, selection: $draft.focus)
        }
    }

    // MARK: - Note

    private var noteBox: some View {
        ZStack(alignment: .topLeading) {
            if draft.note.isEmpty {
                Text("Anything you want to remember about today?")
                    .font(Typography.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Spacing.s + 5)
                    .padding(.vertical, Spacing.s + 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $draft.note)
                .font(Typography.body)
                .foregroundStyle(Theme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(Spacing.s)
                .frame(minHeight: 120)
        }
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.control))
        .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Theme.separator, lineWidth: 1))
    }

    // MARK: - Save

    private var saveButton: some View {
        Button("Save check-in") {
            onSave(draft)
            dismiss()
        }
        .buttonStyle(.primary)
        .disabled(draft.isEmpty)
    }
}

/// One signal picker row — a sentence-case title, a mono "N · Name" readout, and the
/// bare 1→5 glyph ramp with the selected glyph ringed in accent.
struct SignalScaleRow<Level: SignalLevel & CaseIterable & Equatable>: View {
    let title: String
    let kind: GlyphSignal
    @Binding var selection: Level?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(title)
                    .font(Typography.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(readout)
                    .font(Typography.mono12)
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: Spacing.s) {
                ForEach(Array(Level.allCases), id: \.numericValue) { level in
                    Button {
                        selection = selection == level ? nil : level
                    } label: {
                        SignalGlyph(kind, level: level.numericValue, size: 26, decorative: true)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.control)
                                    .strokeBorder(Theme.accent, lineWidth: selection == level ? 1.5 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(level.displayLabel)")
                    .accessibilityAddTraits(selection == level ? [.isSelected] : [])
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, Spacing.m)
    }

    private var readout: String {
        guard let selection else { return "—" }
        return "\(selection.numericValue) · \(selection.displayLabel)"
    }
}

#Preview {
    TextCheckInComposer { _ in }
}
