import SwiftUI

/// Type-note (Layout A, signals first — carried decision): the three level-tile pickers in one
/// card, a note box, and a full-width "Save check-in". Meds and sleep are captured by voice and
/// the Edit screen, not here. Undrawn in the pen; built from the Edit screen's atoms (UI-33a).
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
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    signalPickers
                    noteBox
                    saveButton
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .background(Surface.screen.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        NavHeader(title: "Type a check-in", onBack: { dismiss() })
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.m)
    }

    // MARK: - Signal pickers

    private var signalPickers: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("How do you feel?")
                .font(Typography.cardTitle)
                .foregroundStyle(Ink.primary)
                .accessibilityAddTraits(.isHeader)
            HairlineDivider()
            LevelTilePicker(.mood, label: "Mood", selection: $draft.mood)
            LevelTilePicker(.energy, label: "Energy level", selection: $draft.energy)
            LevelTilePicker(.focus, label: "Focus level", selection: $draft.focus)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .raisedCard(.large, padding: Spacing.l)
    }

    // MARK: - Note

    private var noteBox: some View {
        ZStack(alignment: .topLeading) {
            if draft.note.isEmpty {
                Text("Anything you want to remember about today?")
                    .font(Typography.narrative)
                    .foregroundStyle(Ink.placeholder)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.m)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $draft.note)
                .font(Typography.narrative)
                .foregroundStyle(Ink.primary)
                .scrollContentBackground(.hidden)
                .padding(Spacing.s)
                .frame(minHeight: noteMinHeight)
        }
        .card(.small)
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
            .buttonStyle(.filled(fullWidth: true))
            .disabled(draft.isEmpty)

            if showSaveFailed {
                Text("Couldn't save — tap to try again. Your note is safe.")
                    .font(Typography.cardSubtitle)
                    .foregroundStyle(Ink.tertiary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Motion.smooth, value: showSaveFailed)
    }
}

#Preview {
    TextCheckInComposer { _ in true }
}
