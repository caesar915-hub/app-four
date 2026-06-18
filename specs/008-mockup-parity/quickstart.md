# Phase 1 — Quickstart / Verification

How to prove each screen matches its mockup section. No idb/tap tooling assumed.

## Prerequisites
- Xcode 16+, iPhone 17 simulator.
- Mockup open for side-by-side: `~/.gstack/projects/caesar915-hub-app-four/designs/design-system-20260615/squirl-design-system.html`.

## Build + test
```sh
xcodebuild build -project app-four.xcodeproj -scheme app-four \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -disableAutomaticPackageResolution -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO

xcodebuild test  -project app-four.xcodeproj -scheme app-four \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -disableAutomaticPackageResolution -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO
```
Expected: `BUILD SUCCEEDED`, `TEST SUCCEEDED` (unchanged count).

## Screenshot each screen (temporary, reverted)
1. Add a DEBUG-only `ParityHarnessRoot` that renders the target screen with representative preview data; point `WhisperNotesApp` at it.
2. Build → `xcrun simctl install` → `xcrun simctl launch` → wait → `xcrun simctl io <udid> screenshot`.
3. Diff against the mockup section. Flip `xcrun simctl ui <udid> appearance dark` and re-shoot for dark.
4. Revert `WhisperNotesApp` and delete the harness.

Verify with rich data: a recording with mood/energy/focus set (canonical rawValues), ≥1 catalog medication, summary bullets; for §04, log a dose ~30% elapsed (active) and ~5% (onset).

## Token-cleanliness check (SC-002)
```sh
grep -nE "cornerRadius: [0-9]|\.system\(size|\.padding\([0-9]|tracking\([0-9.]|Color\.(orange|indigo|pink|purple|red|green|blue|secondary|primary)|Color\(\.system" \
  app-four/Views/ExtractionReviewView.swift app-four/Views/RecordingDetailView.swift \
  app-four/Views/CheckIn/TextCheckInComposer.swift app-four/Views/Components/GlyphRampPicker.swift \
  app-four/Views/Components/ADHDSummarySection.swift app-four/Views/Components/MedicationBarView.swift
```
Expected: no matches (sanctioned exceptions: `contrastingInk`, SF-Symbol `.font` sizing, line weights 1/1.5, glyph render-size params).

## Acceptance
Each screen in [contracts/ui-parity.md](contracts/ui-parity.md) matches its section in light + dark; suite green; token grep clean; Calendar + §03b untouched.
