import Testing
import Foundation
@testable import app_four

/// 030 / US4 — copy contract for `StickerSetupView.StickerPath` (D12: never promises
/// automation; FR-020: honest lock-behavior copy). Exercises the pure per-path string/
/// color mapping, not the SwiftUI rendering — the view itself is device-QA'd
/// (quickstart S21–S24) per its own header comment.
@MainActor
@Suite struct StickerSetupViewTests {

    private typealias Path = StickerSetupView.StickerPath

    @Test func exactlyTwoPaths() {
        #expect(Path.allCases == [.dose, .checkIn])
    }

    // The walkthrough tells the user to search Shortcuts for this exact shortcut name
    // (step 4: "search Squirl, and choose \(path.action)"). If it drifts from the
    // intent's real title, the instructions send the user looking for a shortcut
    // that doesn't exist.
    @Test func actionNamesMatchTheRealAppIntentTitles() {
        #expect(Path.dose.action == String(localized: LogDefaultDoseIntent.title))
        #expect(Path.checkIn.action == String(localized: StartCheckInIntent.title))
    }

    @Test func labelsAreDistinctAndNamePath() {
        #expect(Path.dose.label == "Dose sticker")
        #expect(Path.checkIn.label == "Check-in sticker")
    }

    @Test func onlyDoseNeedsAMedicationConfigured() {
        #expect(Path.dose.needsMedication == true)
        #expect(Path.checkIn.needsMedication == false)
    }

    @Test func tintsMatchEachActionsDesignToken() {
        #expect(Path.dose.tint == Accent.violet)
        #expect(Path.checkIn.tint == Accent.primaryFill)
    }

    // D12 — the footnote is the one place users are told what the button does and
    // does not do; it must own the "Squirl can't do this for you" framing, never
    // imply Squirl creates or runs the automation itself.
    @Test func doseFootnoteNeverClaimsSquirlCreatesTheAutomation() {
        let footnote = Path.dose.footnote
        #expect(footnote.localizedCaseInsensitiveContains("can't create the automation"))
        #expect(!footnote.localizedCaseInsensitiveContains("automatically sets up"))
        #expect(!footnote.localizedCaseInsensitiveContains("squirl creates"))
    }

    // FR-020 — a locked phone showing a notification instead of running instantly is
    // expected iOS behavior, not a defect; the copy must say so rather than reading
    // like an apology or a warning.
    @Test func checkInFootnoteFramesTheLockPromptAsExpected() {
        let footnote = Path.checkIn.footnote
        #expect(footnote.localizedCaseInsensitiveContains("expected"))
        #expect(footnote.localizedCaseInsensitiveContains("unlock"))
        // A substring check for "expected" is also satisfied by "unexpected" — the exact
        // apology/defect framing FR-020 forbids. Pin the negation out so a regression to
        // "…on a locked phone this is unexpected…" fails instead of passing green.
        #expect(!footnote.localizedCaseInsensitiveContains("unexpected"))
    }

    @Test func doneCopyNamesTheCorrectOutcomePerPath() {
        #expect(Path.dose.doneLine == "log your default dose")
        #expect(Path.dose.doneTail == "No app-opening, no menus.")
        #expect(Path.checkIn.doneLine == "open Squirl already recording")
        #expect(Path.checkIn.doneTail == "No menus, no taps. Just start talking.")
    }

    @Test func stepsHeadersAreDistinctAndAdvertiseFiveSteps() {
        #expect(Path.dose.stepsHeader.contains("5 steps"))
        #expect(Path.checkIn.stepsHeader.contains("5 steps"))
        #expect(Path.dose.stepsHeader != Path.checkIn.stepsHeader)
    }
}
