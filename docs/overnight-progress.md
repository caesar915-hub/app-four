# Overnight progress — SPM packages + UI sandbox ✅ COMPLETE

**Branch:** `feat/spm-packages` · **Worktree:** `/Users/caesargrey/Projects/app-four-spm` (off `main` @ 55201477)
**Result:** all three planned phases landed, each committed green. Main app + tests pass; a runnable
`SquirlSandbox` shows Gallery + Calendar (fold/unfold) + Insights on mock data, light **and** dark.

## ⚠️ Read first — two things for the morning
1. **Concurrency:** another process was active in the shared main checkout `/Users/caesargrey/Projects/app-four`
   (it switched branches, advanced `main` to 55201477, added `specs/022-view-audit-remediation/`) and
   **clobbered my first Phase-1 attempt**. I moved all work into the isolated worktree above and committed
   after every step. If that other process touched `Views/` or the design system, expect merge friction.
2. **To integrate:** review/merge `feat/spm-packages` → `main`. I did **not** merge (kept `main` releasable).

## What shipped (commits, oldest→newest)
| Commit | What |
|---|---|
| `2ad9e030` | **SquirlSignals** package — 4 level enums hoisted out of `NoteExtraction.swift` (Foundation-only) |
| `d2578787` | **SquirlDesignSystem** package — tokens/Palette/glyphs/SignalGlyph/Buttons/Card + `MoodLevel+Palette` + fonts; app repointed; **app build + full test suite green** |
| `63f70fe7` | **Sandbox** (XcodeGen) + **DesignGallery** on the real package |
| `9d6b4d47` | Sandbox **Calendar** tab — fold/unfold day cards on mock data |
| `0e10b108` | `-dark`/`-gallery`/`-insights` launch args for screenshots |
| `ceb16a0a` | Sandbox **Insights** tab — bubbles, signal strips, gauges, connection card |

## Architecture (as built)
```
Packages/SquirlSignals/        MoodLevel/EnergyLevel/FocusLevel/SleepLevel (leaf, Foundation only)
Packages/SquirlDesignSystem/   tokens, Palette, glyphs, SignalGlyph/SignalLevel, Buttons, Card,
                               MoodLevel+Palette, fonts (SquirlFonts.register via CTFontManager)
app-four/  (main app)          consumes both via ONE @_exported import each (App/SignalsReexport.swift);
                               stays on its synchronized-folder .pbxproj (NOT migrated). Only
                               MedicationBarOverlay.swift + ScreenContainer.swift remain app-side (store-coupled).
SandboxApp/  (XcodeGen)         SquirlSandbox — UI-only app, depends on both packages, mock data, no SwiftData.
```
Key techniques: `@_exported import` to avoid ~47 per-file import edits; the `xcodeproj` Ruby gem to wire
packages into the synchronized-folder pbxproj (round-trip-verified safe; sync groups preserved); offline
builds via `-clonedSourcePackagesDirPath` (shared WhisperKit/transformers checkouts) + `-disableAutomaticPackageResolution`.

## Screenshots (in `docs/sandbox/`)
- `gallery-light.png` / `gallery-dark.png` — design-system catalog (glyphs ×levels, ramps, type, buttons, card)
- `calendar-light.png` / `calendar-dark.png` — fold/unfold day list (mood-tint header, sprout badge, timeline
  rows with the purple med carry-over ring + Taken/emotion/sleep chips)
- `insights-light.png` / `insights-dark.png` — mood bubbles, signal strips, gauges, connection card

Fonts verified on-device: **Fraunces + DM Sans render, no system fallback** (the #1 risk — handled).

## How to run the sandbox
```bash
cd SandboxApp && xcodegen generate && open SquirlSandbox.xcodeproj   # then Run
# headless: xcodebuild -project SquirlSandbox.xcodeproj -scheme SquirlSandbox \
#   -destination 'platform=iOS Simulator,name=iPhone 17' build
# launch args: -dark, -gallery, -insights
```
**Important:** the generated `SquirlSandbox.xcodeproj` is gitignored — run `xcodegen generate` after pulling
or after adding any file under `SandboxApp/Sources/`.

## Decisions made (from the plan's open questions)
- **Module names:** `SquirlSignals` + `SquirlDesignSystem` (per your pick).
- **XcodeGen:** used ONLY for the new sandbox, not the main app (its synchronized-folder pbxproj is untouched).
- **Fonts:** main app keeps its `UIAppFonts` (safety); package registers via `SquirlFonts.register()` for the sandbox.
  Removing the duplicate app-bundle fonts is left as a deliberate follow-up.
- **Sandbox screens:** re-composed from package atoms on mock data (the @Model-coupled real DayCard/Insights stay
  in the app). Atoms are the real package = zero drift; the screen *compositions* are sandbox re-creations.

## Not done / possible next
- Deployment-target split (app 26.4 / tests 26.5) left as-is — unify if you want.
- Sandbox Check-in / Detail / Edit screens (lower priority) not built.
- The main app's design-system file moves may conflict with `specs/022` work on `main` — resolve at merge.
