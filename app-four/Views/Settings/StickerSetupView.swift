import SwiftUI

/// 030 / US4 — "Set up your sticker" guided walkthrough (FR-019/020, D12).
/// Two paths (dose / check-in) picked by a segmented control; each shows the same
/// five-step Shortcuts walkthrough with a plain `shortcuts://` hand-off (never claims
/// to create the automation — iOS owns that), honest no-shame lock-behavior copy, and
/// an antenna tip. Pure guidance, no journal behavior — view-only per Constitution X;
/// correctness is the build + device QA (quickstart S21–S24), so no unit tasks.
struct StickerSetupView: View {
    private enum StickerPath: String, CaseIterable, Identifiable {
        case dose, checkIn
        var id: String { rawValue }
        var label: String { self == .dose ? "Dose sticker" : "Check-in sticker" }
        var tint: Color { self == .dose ? .purple : Theme.meadowGreen }
        var action: String { self == .dose ? "Log My Meds" : "Check In" }
        var doneLine: String {
            self == .dose ? "log your default dose" : "open Squirl already recording"
        }
        var needsMedication: Bool { self == .dose }
        var stepsHeader: String {
            self == .dose ? "Log a dose · 5 steps" : "Start a check-in · 5 steps"
        }
        var footnote: String {
            self == .dose
            ? "Squirl can't create the automation for you (iOS doesn't allow that). The button just opens Shortcuts at the right place; you tap through the steps once."
            : "A check-in sticker opens the app and starts recording. On a locked phone it asks you to unlock first, which is expected for anything that opens Squirl."
        }
    }

    private struct Step: Identifiable {
        let id = UUID()
        let text: String
        var detail: String?
        var handoff = false
        var recommended = false
    }

    @State private var path: StickerPath = .dose
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScreenContainer(title: "Set up your sticker", showsMedicationBar: false) {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                Text("Turn any blank NFC sticker into a one-tap Squirl action. About a minute, once per sticker. Squirl walks you through the Shortcuts app.")
                    .font(Typography.callout)
                    .foregroundStyle(Theme.textSecondary)

                Picker("Sticker type", selection: $path) {
                    ForEach(StickerPath.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: path) { } // segmented control drives the reveal below

                needSection
                stepsSection
                lockCallout
                tipCallout
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(reduceMotion ? nil : Motion.snappy, value: path)
        }
    }

    // MARK: - What you'll need

    private var needSection: some View {
        card(header: "What you'll need") {
            row(symbol: "tag", tint: Theme.textSecondary,
                title: "A blank NFC sticker", subtitle: "Any cheap NDEF tag, nothing pre-written")
            if path.needsMedication {
                Divider().overlay(Theme.separator).padding(.leading, 40)
                row(symbol: "pills.fill", tint: .purple,
                    title: "A default medication set", subtitle: "Settings › My Medication")
            }
        }
    }

    // MARK: - Steps

    private var steps: [Step] {
        [
            Step(text: "Open the **Shortcuts** app.",
                 detail: "It's built into iOS. The button below opens it for you.", handoff: true),
            Step(text: "Go to the **Automation** tab, tap **+**, then **Create Personal Automation → NFC**."),
            Step(text: "Tap **Scan**, then hold your blank sticker to the phone. Give it a name.",
                 detail: "Hold the top-back of the phone to the tag for a second."),
            Step(text: "Tap **Add Action**, search **Squirl**, and choose **\(path.action)**."),
            Step(text: "Turn **off** “Ask Before Running”, then confirm **Run Immediately**.",
                 detail: "This is the zero-tap setup: a tap fires the action with no confirmation screen.",
                 recommended: true)
        ]
    }

    private var stepsSection: some View {
        card(header: path.stepsHeader, footnote: path.footnote) {
            let items = steps
            ForEach(Array(items.enumerated()), id: \.element.id) { index, step in
                if index > 0 { Divider().overlay(Theme.separator).padding(.leading, 40) }
                stepRow(number: "\(index + 1)", step: step)
            }
            Divider().overlay(Theme.separator).padding(.leading, 40)
            doneRow
        }
    }

    private func stepRow(number: String, step: Step) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            marker(number)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                    Text(.init(step.text))
                        .font(Typography.body)
                        .foregroundStyle(Theme.textPrimary)
                    if step.recommended {
                        Text("Recommended")
                            .font(Typography.label)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.s)
                            .padding(.vertical, 2)
                            .background(path.tint, in: .capsule)
                    }
                }
                if let detail = step.detail {
                    Text(detail)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                if step.handoff {
                    Button {
                        if let url = URL(string: "shortcuts://") { openURL(url) }
                    } label: {
                        Label("Open Shortcuts", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(path.tint)
                    .padding(.top, Spacing.xs)
                }
            }
        }
    }

    private var doneRow: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(path.tint)
                .frame(width: 28, height: 28)
            Text(.init("**Done.** Tap the sticker to \(path.doneLine). No app-opening, no menus."))
                .font(Typography.body)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: - Callouts

    private var lockCallout: some View {
        card {
            calloutHeader(symbol: "iphone.gen3", tint: Theme.accent, title: "What to expect when you tap it")
            VStack(alignment: .leading, spacing: Spacing.s) {
                lockLine("Unlocked", "It runs instantly, no prompt. This is the zero-tap setup working.")
                lockLine("Locked", "iPhone shows a notification instead. Tap it and the action runs.")
                Text("The tap is never lost, and a locked phone showing a notification is just how iOS handles it, not something you did wrong.")
                    .font(Typography.callout)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, Spacing.xs)
            }
            .padding(.leading, 40)
        }
    }

    private var tipCallout: some View {
        card {
            calloutHeader(symbol: "sensor.tag.radiowaves.forward", tint: Theme.meadowAmber, title: "Can't get it to read?")
            Text(.init("Hold the **top-back of your phone**, up by the cameras, flat against the sticker for a second. That's where the NFC reader is. A thick case or a metal surface behind the sticker can block it."))
                .font(Typography.callout)
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 40)
        }
    }

    // MARK: - Building blocks

    private func marker(_ number: String) -> some View {
        Text(number)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(path.tint, in: .circle)
    }

    private func row(symbol: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Typography.body).foregroundStyle(Theme.textPrimary)
                Text(subtitle).font(Typography.caption).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func calloutHeader(symbol: String, tint: Color, title: String) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
            Text(title).font(Typography.headline).foregroundStyle(Theme.textPrimary)
        }
    }

    private func lockLine(_ state: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(state).font(Typography.subheadline).foregroundStyle(Theme.textPrimary)
            Text(detail).font(Typography.callout).foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private func card<Content: View>(
        header: String? = nil,
        footnote: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if let header {
                Text(header.uppercased())
                    .font(Typography.label)
                    .tracking(0.5)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Spacing.xs)
            }
            VStack(alignment: .leading, spacing: Spacing.m) {
                content()
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.cardStroke, lineWidth: 1))
            if let footnote {
                Text(footnote)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Spacing.xs)
            }
        }
    }
}

#Preview {
    NavigationStack {
        StickerSetupView()
    }
}
