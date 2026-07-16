import SwiftUI

/// §06 Type-note (Layout A) — signals-first: a custom close/title navbar, the three
/// mood/energy/focus glyph pickers, a single free-text notebox, and a gradient
/// "Save check-in" pill. Meds and sleep are captured by voice and the Edit sheet, not here.
struct TextCheckInComposer: View {
    /// Returns `true` when the save persisted; `false` keeps the composer open with
    /// the draft intact so the inline retry surface can re-attempt (FR-009).
    let onSave: (CheckInDraft) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var draft = CheckInDraft()
    @State private var showSaveFailed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .background(NewLook.screen.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    // MARK: - Navbar

    private var navbar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(Typography.subheadline)
                    .foregroundStyle(NewLook.inkPrimary)
                    .frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)
                    .background(NewLook.card, in: Circle())
                    .overlay(Circle().strokeBorder(NewLook.hairline, lineWidth: 1))
            }
            .accessibilityLabel("Close")
            .contentShape(.circle)

            Spacer()
            Text("Type a check-in")
                .font(Typography.title)
                .foregroundStyle(NewLook.inkPrimary)
            Spacer()

            Color.clear.frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
    }

    // MARK: - Signal pickers

    private var signalPickers: some View {
        VStack(spacing: 0) {
            SignalScaleRow(title: "Mood", kind: .mood, selection: $draft.mood)
            Divider().overlay(NewLook.hairline)
            SignalScaleRow(title: "Energy", kind: .energy, selection: $draft.energy)
            Divider().overlay(NewLook.hairline)
            SignalScaleRow(title: "Focus", kind: .focus, selection: $draft.focus)
        }
    }

    // MARK: - Note

    private var noteBox: some View {
        ZStack(alignment: .topLeading) {
            if draft.note.isEmpty {
                Text("Anything you want to remember about today?")
                    .font(Typography.callout)
                    .foregroundStyle(NewLook.inkSecondary)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.m)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $draft.note)
                .font(Typography.body)
                .foregroundStyle(NewLook.inkPrimary)
                .scrollContentBackground(.hidden)
                .padding(Spacing.s)
                .frame(minHeight: noteMinHeight)
        }
        .newLookCard()
    }

    /// Note-box content height (a content dimension, not a spacing-scale value).
    private let noteMinHeight: CGFloat = 120

    // MARK: - Save

    private var saveButton: some View {
        VStack(spacing: Spacing.s) {
            Button("Save check-in") {
                if onSave(draft) {
                    dismiss()
                } else {
                    showSaveFailed = true
                    Haptics.error()
                }
            }
            .buttonStyle(.checkInPrimary)
            .disabled(draft.isEmpty)

            if showSaveFailed {
                Text("Couldn't save — tap to try again. Your note is safe.")
                    .font(Typography.callout)
                    .foregroundStyle(NewLook.inkSecondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Motion.smooth, value: showSaveFailed)
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
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(NewLook.inkPrimary)
                Spacer()
                Text(readout)
                    .font(Typography.mono12)
                    .foregroundStyle(NewLook.inkSecondary)
            }
            GlyphRampPicker(kind: kind, selection: $selection)
        }
        .padding(.vertical, Spacing.m)
    }

    private var readout: String {
        guard let selection else { return "—" }
        return "\(selection.numericValue) · \(selection.displayLabel)"
    }
}

#Preview {
    TextCheckInComposer { _ in true }
}
