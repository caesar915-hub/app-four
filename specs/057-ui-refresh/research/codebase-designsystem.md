<!-- Created: 2026-09-27 22:06 WEST · Updated: 2026-09-27 22:06 WEST -->
# Current design-system code map — `SquirlDesignSystem` + `app-four/DesignSystem/`

Read-only survey of the worktree at `feat/057-ui-refresh` (HEAD `08ba8cba`). Purpose: give the UI-refresh plan an exact inventory of every token, type, modifier and style the shipping app depends on, with usage counts, so each item can be marked **keep / migrate / delete** against the Pencil design. No Swift was changed.

Counting method: `grep -rE` over `app-four/**/*.swift` (the app target; `app-four/wireframes/` is included in the raw grep but is called out separately — it is compiled-but-unreferenced dead code). `tests` = `app-fourTests/`. `inPkg` = self-references inside `Packages/SquirlDesignSystem/Sources`. Occurrence counts are token mentions, not view instances.

---

## 1. Package inventory

### `Packages/SquirlDesignSystem/Package.swift`
- `swift-tools-version: 6.0`, `platforms: [.iOS("26.0")]`, `swiftLanguageModes: [.v5]`.
- **One product / one target**: `.library(name: "SquirlDesignSystem", targets: ["SquirlDesignSystem"])`, `.target(name: "SquirlDesignSystem", dependencies: ["SquirlSignals"])`.
- **No test target in the package.** Every test that pins a design-system value lives in `app-fourTests/` and reaches the package through `@testable import app_four` (see §13).
- Dependency: `.package(path: "../SquirlSignals")` — a Foundation-only leaf that owns `MoodLevel`, `EnergyLevel`, `FocusLevel`, `SleepLevel` (`Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift`, 171 lines, no SwiftUI).

### Source files (25 files, 1 127 lines)
| File | Lines | Exposes |
|---|---|---|
| `Palette.swift` | 25 | `enum Palette` — 4 adaptive colours |
| `Palette+Signals.swift` | 41 | `Palette.energyRamp/energyRampPartner/focusRamp/focusRampPartner` |
| `NewLook.swift` | 148 | `enum NewLook` (11 colours), `.newLookCard()`, `.newLookCardShadow()`, `.newLookChip(selected:role:)`, `enum NewLookChipRole`, `struct NewLookNavBar` |
| `Theme.swift` | 24 | `enum Theme` — 6 colours + `meadowGradient` |
| `Typography.swift` | 74 | `enum Typography` — 14 roles + `text(_:weight:relativeTo:)` + `mono(...)`; `View.typography(_:)` |
| `Spacing.swift` | 25 | `enum Spacing` — 9 constants |
| `Radius.swift` | 15 | `enum Radius` — 5 constants |
| `Metrics.swift` | 68 | `enum Metrics` — 10 constants + `IconSize` (3) + `CheckIn` (7) |
| `Opacity.swift` | 16 | `enum Opacity` — 3 constants |
| `Motion.swift` | 15 | `enum Motion` — 3 animations + 1 duration |
| `Haptics.swift` | 16 | `@MainActor enum Haptics` — 3 funcs |
| `Icons.swift` | 15 | `enum Icons` — 6 SF-Symbol names |
| `Buttons.swift` | 63 | `PrimaryButtonStyle`, `CheckInPrimaryButtonStyle`, `SecondaryButtonStyle` + `.primary/.checkInPrimary/.secondary` statics |
| `Card.swift` | 33 | `Text.cardEyebrow()` (+ a `#Preview`) |
| `GlyphSignal.swift` | 83 | `enum GlyphSignal`, `struct GlyphBadge`, 4 `nonisolated` pure funcs |
| `SignalGlyph.swift` | 92 | `struct SignalGlyph: View` (+ private `EmptySignalGlyph`) |
| `SignalLevel.swift` | 64 | `protocol SignalLevel`, `fillGradient`, `bubbleFill`, `Color.contrastingInk(for:in:)`, conformances for `MoodLevel/EnergyLevel/FocusLevel` |
| `MoodLevel+Palette.swift` | 82 | `MoodLevel.color/gradientPartner/fill/deepFill/blockTint/badgeTint/wordColor/displayLabel/onColor/averageDeep` |
| `Glyphs/SproutGlyph.swift` | 57 | `struct SproutGlyph: View` (Canvas) |
| `Glyphs/BoltGlyph.swift` | 39 | `struct BoltGlyph: View` (Canvas) |
| `Glyphs/ApertureGlyph.swift` | 44 | `struct ApertureGlyph: View` (Canvas) |
| `Glyphs/BedIcon.swift` | 35 | `struct BedIcon: View` (Canvas) |
| `Glyphs/CapsuleGlyph.swift` | 25 | `struct CapsuleGlyph: View` (GeometryReader + shapes) |
| `Reexport.swift` | 4 | `@_exported import SquirlSignals` |
| `Color+Hex.swift` | 24 | `Color(hex:)`, `Color(lightHex:darkHex:)` |

### Consumers (who links the product)
| Consumer | How | Evidence |
|---|---|---|
| `app-four` app target | `packageProductDependencies` → `SquirlDesignSystem` + `SquirlSignals` | `app-four.xcodeproj/project.pbxproj` L179–180 |
| `app-fourTests` | same two products linked | pbxproj L154–155 |
| `SandboxApp` (xcodegen, `SandboxApp/project.yml`) | `packages: SquirlDesignSystem: path: ../Packages/SquirlDesignSystem` | explicit `import SquirlDesignSystem` in 4 sandbox files; `DesignGallery.swift` renders "the real atoms — zero drift" and touches `NewLook.*`, `Theme.*`, `Palette.*`, `Typography.*`, `SignalGlyph`, `.newLookCard`, `.buttonStyle(.primary/.secondary)` |
| `WhisperCLI/` | not linked | — |

### How the app sees the package — the one thing to know before deleting anything
`app-four/App/SignalsReexport.swift` (5 lines):
```swift
@_exported import SquirlSignals
@_exported import SquirlDesignSystem
```
Every file in the app module therefore uses `NewLook.*`, `Theme.*`, `Typography.*`, `SignalGlyph` … **unqualified and without an import line**. Only one app file imports the package explicitly (`app-four/Views/Components/DayCardSummary.swift` — a Foundation-only model file). Consequence: you cannot find dependents by grepping for `import SquirlDesignSystem`; you must grep for each symbol. Removing any `public` symbol breaks compile at every call site in §4–§7 below, plus `SandboxApp`.

---

## 2. The two coexisting languages

| | **Paper & Pollen** (`Theme` + `Palette`) | **New Look** (`NewLook`, spec 032/033) |
|---|---|---|
| Intent (doc-comments) | "Retained from the retired Paper & Pollen system: semantic colours with no New Look equivalent" | "As of spec 033, New Look is the app-wide default … Values map 1:1 to the Figma 'Tiimo Colors' variables" |
| Surfaces | none left — the P&P paper/loam/surface/ink/hairline tokens in the old DESIGN.md foundation table (`#F6F1E7`, `#FCF8EF`, `#EFE8D8`, `#221E16`, `#7A7361`, `#E3DAC7`) **no longer exist in code** | `screen`, `card`, `inkPrimary`, `inkSecondary`, `hairline`, `tintNeutral`, `onInk` |
| Accents | `Theme.accent` (bronze), `meadowGreen`, `meadowAmber`, `danger`, `statusDone/InProgress`, `meadowGradient` | `selection` (mint), `onSelection`, `checkInGreen`, `checkInGreenSoft` |
| Domain colours | `Palette.medication`, `medicationFillEnd`, `warning`, `sleepIndigo`, energy/focus ramps; `MoodLevel` ramp | (reuses `Palette.medication`) |
| Card | none (`Radius.card` 16 survives as one call) | `.newLookCard()` r20 borderless + 2-layer shadow |
| Chip | `Chip.swift` (app-side, `Radius.control` 10, tinted 15 %) | `.newLookChip()` capsule, hairline/filled |
| Buttons | `PrimaryButtonStyle` (meadow gradient) | `CheckInPrimaryButtonStyle`, `SecondaryButtonStyle` (uses `NewLook.card/hairline/inkPrimary`) |

### Dominance in views (app target, excluding the package)
| Namespace | Occurrences | Files |
|---|---|---|
| `NewLook.` | **261** | **36** |
| `Theme.` | 33 (31 in code, 2 in doc-comments) | 15 |
| `Palette.` | 27 | 13 |
| `Typography.` | 187 | 33 |
| `Spacing.` | 302 | 36 |

**New Look is dominant by ~8×.** `Theme` survives as a small semantic set, and one of its members — `Theme.meadowGreen` `#5F8A4C` — is structurally load-bearing: it is the **tab-bar and navigation tint** (`RootTabView.swift:36`, `ScreenContainer.swift:56`), the check-in ring (`CrescentRing.swift:32`), the solid "Speak check-in" pill (`CheckInView.swift:246/410/494`), and the **selected fill of every standard `.newLookChip`** (`NewLookChipRole.standard.selectedFill` → `Theme.meadowGreen`, `NewLook.swift:82`).

Per-file split (files with any of the three):

| File | NewLook | Theme | Palette |
|---|---|---|---|
| `Views/ExtractionReviewView.swift` | 36 | 0 | 2 |
| `Views/CheckIn/CheckInView.swift` | 28 | 6 | 1 |
| `Views/Components/MedicationLogSheet.swift` | 21 | 1 | 2 |
| `Views/RecordingDetailView.swift` | 19 | 4 | 2 |
| `Views/Settings/StickerSetupView.swift` | 16 | 3 | 2 |
| `Views/CheckIn/TextCheckInComposer.swift` | 12 | 0 | 0 |
| `Views/Insights/ConnectionCardsView.swift` | 11 | 0 | 1 |
| `Views/InsightsView.swift` | 11 | 0 | 0 |
| `Views/Onboarding/SiriOnboardingView.swift` | 9 | 0 | 0 |
| `Views/Components/FoldedDayCardHeader.swift` | 8 | 0 | 1 |
| `Views/Components/TimelineRow.swift` | 8 | 0 | 2 |
| `Views/Onboarding/LLMDownloadView.swift` | 7 | 1 | 0 |
| `Views/Onboarding/DownloadPermissionView.swift` | 6 | 1 | 0 |
| `Views/Components/ModelDownloadRow.swift` | 5 | **7** | 0 |
| `Views/Components/RecordingRow.swift` | 5 | 1 | 0 |
| `Views/Insights/DailyRhythmMatrix.swift` | 5 | 0 | 0 |
| `Views/Insights/SignalAverageGauges.swift` | 5 | 0 | 0 |
| `Views/Settings/JournalExportSection.swift` | 5 | 0 | 0 |
| `Views/SettingsView.swift` | 5 | 0 | 0 |
| `Views/Components/Chip.swift` | 4 | 0 | 0 |
| `Views/Insights/MoodLegend.swift` | 4 | 0 | 0 |
| `Views/Onboarding/WelcomeView.swift` | 4 | 0 | 0 |
| `Views/Settings/YourDataSection.swift` | 4 | 1 | 0 |
| `DesignSystem/ScreenContainer.swift` | 3 | 1 | 0 |
| `Views/Components/MedicationBarView.swift` | 3 | 0 | 3 |
| `Views/Insights/SignalStripsView.swift` | 3 | 0 | 0 |
| `Views/Library/CalendarLibraryView.swift` | 3 | 0 | 0 |
| `Views/Components/ADHDSummarySection.swift` | 2 | 1 | 3 |
| `Views/Components/CalendarHeaderView.swift` | 2 | 0 | 0 |
| `Views/Components/GlyphRampPicker.swift` | 1 (comment) | 2 | 0 |
| `Views/Components/AudioPlayerView.swift` | 1 | 0 | 1 |
| `Views/Components/CalendarDayCell.swift` | 1 | 0 | 0 |
| `Views/Components/DayCard.swift` | 1 | 0 | 0 |
| `Views/Components/PlaybackWaveformBars.swift` | 1 | 1 | 0 |
| `Views/Feedback/FeedbackButton.swift` | 1 | 0 | 0 |
| `Views/Settings/MedicalInfoSection.swift` | 1 | 0 | 0 |
| `Views/CheckIn/CrescentRing.swift` | 0 | 2 | 0 |
| `Views/RootTabView.swift` | 0 | 1 | 0 |
| `Models/Recording+MoodDisplay.swift` | 0 | 0 | 4 |
| `Views/Settings/MyMedicationSection.swift` | 0 | 0 | 3 |

Files with **zero** design-system colour tokens but view code: `Views/Settings/DoseGuardSection.swift`, `Views/Feedback/IssueReportView.swift`, `Views/TestServicesView.swift` (unmounted debug console), `Views/Components/TagFlowView.swift`, `Views/Components/EdgeFadeMask.swift`, and all of `wireframes/` — these run on system colours (`.secondary`, `.primary`, `Color.accentColor`, `Color(.tertiarySystemFill)`).

---

## 3. Colour tokens — values and usage

`Color(lightHex:darkHex:)` builds a `UIColor { trait in … }` dynamic provider; `Color(hex:)` is static sRGB (no dark variant). All hex strings are quoted verbatim from source.

### 3.1 `NewLook` (`NewLook.swift`)
| Token | Light | Dark | Doc-comment role | app occ / files |
|---|---|---|---|---|
| `NewLook.screen` | `#EFF2EB` | `#12140F` | "Screen ground — cool sage" | 16 / 12 |
| `NewLook.card` | `#FFFFFF` | `#1C1E19` | "Card surface — raised, borderless" | 17 / 11 |
| `NewLook.inkPrimary` | `#1C1B1F` | `#F2F3EE` | primary text | 66 / 24 |
| `NewLook.onInk` | `#F2F3EE` | `#1C1B1F` | label on an `inkPrimary` fill (stop capsule) | 1 / 1 (`CheckInView.swift:432`) |
| `NewLook.inkSecondary` | `#8A8A8E` | `#9BA09A` | secondary text; **documented AA failure in light (3.0:1 on screen, 3.4:1 on card), kept by owner decision 2026-07-12** | **105 / 27** (most-used colour in the app) |
| `NewLook.hairline` | `#DBDDDE` | `#33362F` | chip/field borders, "never a card border" | 21 / 13 |
| `NewLook.tintNeutral` | `#ECEAE6` | `#272A22` | grooves, tracks, segmented fills | 10 / 9 |
| `NewLook.selection` | `#54B492` | `#5FC49F` | "selected chip fill (non-medication)" — **but see §6: `NewLookChipRole.standard` no longer uses it** | 5 / 3 (`Chip.swift:58,62`; `RecordingDetailView.swift:179,270`) |
| `NewLook.onSelection` | `#FFFFFF` | `#1C1B1F` | label on selection/medication fill (flips to dark ink in dark mode, owner 2026-07-16) | 7 / 2 (`CheckInView` ×6, `ExtractionReviewView:302`) |
| `NewLook.checkInGreen` | `#5FB36E` | `#6FC47E` | capture-flow accent (check-in · onboarding · recording-detail edit); same light hex as `MoodLevel.good.color` | 13 / 4 |
| `NewLook.checkInGreenSoft` | `#96C19F` | `#86BC9D` | ring-gradient end-stop | **0 in app**; 1 in package (`CheckInPrimaryButtonStyle`) |

### 3.2 `Theme` (`Theme.swift`) — Paper & Pollen survivors
| Token | Light | Dark | app occ / files | Call sites |
|---|---|---|---|---|
| `Theme.accent` (bronze) | `#B8842A` | `#D4A24A` | 5 / 4 | `ADHDSummarySection:89` (emotion tag colour), `GlyphRampPicker:13` (default ring tint), `PlaybackWaveformBars:18` (played bars @0.6), `StickerSetupView:170` |
| `Theme.meadowGreen` | `#5F8A4C` | `#6E9A58` | **15 / 7** | `RootTabView:36` + `ScreenContainer:56` (**tint**), `CheckInView:246,340,384,410,467,494`, `CrescentRing:32`, `MedicationLogSheet:59`, `ModelDownloadRow:73,109,151`, `StickerSetupView:17`; also `NewLookChipRole.standard` in package |
| `Theme.meadowAmber` | `#E0A33A` | `#E8B255` | 2 / 2 | `RecordingDetailView:268` ("Recorded" status), `StickerSetupView:185` |
| `Theme.statusDone` | = `meadowGreen` | | 3 / 3 | `ModelDownloadRow:117`, `RecordingRow:109`, `RecordingDetailView:272` |
| `Theme.statusInProgress` | = `meadowAmber` | | 1 / 1 | `ModelDownloadRow:117` |
| `Theme.danger` | `#B5503A` | `#CF6A52` | 7 / 5 | `ModelDownloadRow:112,131`, `DownloadPermissionView:60`, `LLMDownloadView:51`, `RecordingDetailView:274,307`, `YourDataSection:17` |
| `Theme.meadowGradient` | green→amber, `.topLeading`→`.bottomTrailing` | | **0 in app** | only `PrimaryButtonStyle` (package) |

The asset catalog `AccentColor.colorset` is **`#B8842A` / `#D4A24A` = `Theme.accent` (bronze)**, but the live tint is `Theme.meadowGreen`. `Color.accentColor` is read directly in `DoseGuardSection:34` and `MyMedicationSection:94` — whether those resolve to the bronze asset or the meadow `.tint()` is **not verified here** (flag for device QA; `.tint` and `Color.accentColor` are different mechanisms).

### 3.3 `Palette` (`Palette.swift`, `Palette+Signals.swift`)
| Token | Light | Dark | app occ / files |
|---|---|---|---|
| `Palette.medication` | `#7E5CA8` | `#957BC1` (nudged from `#9277BE`, 2026-07-16, for AA) | **17 / 11** (+1 test) |
| `Palette.medicationFillEnd` | `#AF99C3` | `#B3A1D6` (derived) | 1 / 1 (`MedicationBarView:150` dose-track gradient) |
| `Palette.warning` | `#C2772E` | `#D98A3E` | 2 / 2 (side-effect tags: `Recording+MoodDisplay:71`, `ADHDSummarySection:105`) |
| `Palette.sleepIndigo` | `#5566A6` | `#8E9BD4` | 3 / 2 (`ADHDSummarySection:65,70`, `TimelineRow:143`) + `BedIcon` default |
| `Palette.energyRamp` (static, no dark) | `#7C6E2E · #A89236 · #D2BB40 · #EEDA4C · #FCEE64` (sluggish→charged) | — | 2 / 2 (`Recording+MoodDisplay:42` fallback `[2]`, `RecordingDetailView:177`) + `EnergyLevel.color`, `SignalGlyph` |
| `Palette.energyRampPartner` | `#8C7F44 · #B8A450 · #E2CD5F · #FEEC6E · #FFF482` | — | 0 in app; `EnergyLevel.gradientPartner` |
| `Palette.focusRamp` (static) | `#44546E · #4E6F94 · #5889BA · #63A4E0 · #79C4FF` (foggy→lockedIn) | — | 2 / 2 (`Recording+MoodDisplay:49`, `RecordingDetailView:178`) + `FocusLevel.color`, `SignalGlyph` |
| `Palette.focusRampPartner` | `#5C697E · #6985A4 · #77A0CA · #85BDF0 · #96D1FF` | — | 0 in app; `FocusLevel.gradientPartner` |

### 3.4 `MoodLevel` palette (`MoodLevel+Palette.swift`) — "the app-wide mood SSOT"
| Level | `color` / `deepFill` (base, static) | `gradientPartner` / `fill` (static) | `wordColor` light | `wordColor` dark |
|---|---|---|---|---|
| `.low` | `#DA7A2A` | `#EA9248` | `#8E470F` | `#E89A5A` |
| `.flat` | `#EDA94A` | `#FDC06C` | `#8A5600` | `#EDA94A` |
| `.okay` | `#9FCB79` | `#B9DB9C` | `#41691F` | `#B7D897` |
| `.good` | `#5FB36E` | `#7EC38A` | `#2C6B3B` | `#79C98E` |
| `.great` | `#2E8B57` | `#459B6B` | `#1E5C38` | `#57C98A` |

Derived: `blockTint = color.opacity(Opacity.moodBlock)` (0.24), `badgeTint = color.opacity(Opacity.moodBadge)` (0.50), `onColor = Color(hex: "#1C1C1E")` (static), `displayLabel` ("Low/Flat/Okay/Good/Great"), `averageDeep(of:)`.

Usage (app): `.displayLabel` 35 / 17 files (mostly the level enums' label, not colour); `.color` 13 / 8; `.wordColor` 3 / 2 (`TimelineRow:75`, `FoldedDayCardHeader`); `.blockTint` 2 / 1; `.badgeTint` 1 / 1; `.deepFill` 1 / 1; `.averageDeep` 1 / 1; `.fill` via `Recording.moodColor` (`Recording+MoodDisplay:10`, fallback `Color(.systemGray4)`); `.gradientPartner` 0 direct (used through `fillGradient`/`bubbleFill`); **`MoodLevel.onColor` 0 anywhere**.

Note the base ramp is `Color(hex:)` — **static, identical in dark mode**; only `wordColor` adapts.

### 3.5 Colour helpers (`Color+Hex.swift`, `SignalLevel.swift`)
- `Color(hex:)` — 32 uses in package, **0 in app views**, 14 in tests (they pin hexes).
- `Color(lightHex:darkHex:)` — 24 in package, 0 in app. Good: no raw hex leaks in views.
- `Color.contrastingInk(for:in:)` — black/white by resolved luminance `> 0.6`; app 2 / 2 (`MoodBubbleChart:61`, `SignalAverageGauges:85`).
- `SignalLevel.fillGradient` (partner→base, topLeading→bottomTrailing) — 5 / 3 (`DailyRhythmMatrix:52`, `MoodLegend:15`, `SignalAverageGauges:79`).
- `SignalLevel.bubbleFill` (radial, centre `(0.32, 0.28)`, endRadius 110) — 1 / 1 (`MoodBubbleChart:64`).

---

## 4. Typography (`Typography.swift`) and Dynamic Type

Mechanism: every role is `Font(UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont.systemFont(ofSize:weight:)))` (or `monospacedSystemFont`). **Every role scales with Dynamic Type relative to a text style**; there is no fixed-size role. Faces: SF Pro / SF Mono only (typography reversal, spec 023) — no `UIAppFonts`, no font registration.

| Role | Size / weight / relativeTo | Mono | app occ / files |
|---|---|---|---|
| `display` | 28 / semibold / `.title1` | | 1 / 1 (`ConnectionCardsView:57`) |
| `largeTitle` | 34 / bold / `.largeTitle` | | 4 / 4 (onboarding heroes, `InsightsView:191`) |
| `title` | 22 / semibold / `.title2` | | 6 / 6 |
| `dayCardDate` | 16 / semibold / `.subheadline` | | **0** |
| `moodWord` | 24 / bold / `.title2` | | 2 / 2 (`FoldedDayCardHeader:76`, `TimelineRow:75`) |
| `headline` | 16 / semibold / `.headline` | | 20 / 10 (+ all 3 button styles) |
| `subheadline` | 14 / medium / `.subheadline` | | 14 / 10 |
| `body` | 16 / regular / `.body` | | 24 / 12 |
| `callout` | 15 / regular / `.callout` | | 17 / 8 |
| `caption` | 12 / regular / `.caption1` | | **63 / 21** (+ `newLookChip`) |
| `label` | 12 / medium / `.caption1` ("call `.textCase(.uppercase)` separately") | | 22 / 11 (+ `cardEyebrow`) |
| `timer` | 22 / medium / `.title2` | mono | 1 / 1 (`CheckInView:294`) |
| `duration` | 12 / regular / `.caption1` | mono | 1 / 1 (`AudioPlayerView:27`) |
| `mono12` | 12 / regular / `.caption1` | mono | 3 / 3 |
| `text(_:weight:relativeTo:)` | bespoke | | 9 / 6 — signatures: `(24, .bold, .title2)` ×4 (`CheckInView:206,355,478`, `InsightsView:56`; **identical to `moodWord`**, also used by `NewLookNavBar`), `(13, .semibold, .subheadline)`, `(13, .subheadline)`, `(15, .semibold, .subheadline)`, `(17, .semibold, .body)`, `(9, .medium, .caption1)` (`SignalStripsView:79`) |
| `mono(_:weight:relativeTo:)` | bespoke | mono | **0** |
| `View.typography(_:)` | wrapper | | **0** |

Bypasses of `Typography` in the app target (system text styles — these still scale, but drift from the token set): `.font(.caption…)` 19 occ / 11 files, `.font(.subheadline…)` 10 / 7, `.font(.headline)` 7 / 4, `.font(.footnote)` 5 / 2, `.font(.title…)` 5 / 4, `.font(.body…)` 3 / 2, `.font(.callout…)` 1, `.font(.largeTitle)` 1, `.font(.system(size:))` 4 / 4 — of which the non-wireframe, non-debug sites are: `CalendarHeaderView:75`, `FoldedDayCardHeader:56,133`, `MedicationLogSheet:172`, `TagFlowView:18`, `TimelineRow:90`, `IssueReportView:107,114,121`, `DoseGuardSection:24,33,46`, `MyMedicationSection:30,102,125,150,155,157,191`, `StickerSetupView:157,197,206,219`, `CheckInView:471` (`.system(size: Metrics.CheckIn.savedCheck, weight: .bold)` — decorative glyph), `DownloadPermissionView:41` + `LLMDownloadView:32` (`.system(size: 64)` hero symbols). **Settings sections are the least tokenised screens.**

Other Dynamic-Type handling in views: `@ScaledMetric(relativeTo: .body)` in `CalendarDayCell:13` (diameter 30) and `StickerSetupView:48` (badge 28); `dynamicTypeSize >= .accessibility1` forces week view in `CalendarHeaderView:20`; `minimumScaleFactor` 3 sites; `lineLimit` 8 sites. Glyph sizes (`Metrics.*`) are **fixed-point by design** ("imagery, not copy").

---

## 5. Layout tokens

### `Spacing` (base-4/8)
| Token | pt | app occ / files |
|---|---|---|
| `xs` | 4 | 53 / 16 |
| `s` | 8 | 85 / 27 |
| `m` | 12 | 75 / 25 |
| `l` | 16 | 47 / 25 |
| `xl` | 20 ("legacy — prefer .l") | 9 / 7 |
| `xxl` | 24 | 10 / 9 |
| `section` | 32 | 14 / 7 |
| `hero` | 40 | 9 / 8 |
| `ringStroke` | 3.3 | **0** |

Literal bypasses (non-wireframe): `.padding(<number>)` 15 sites (6 in `MyMedicationSection`), `spacing: <number>` 37 sites (spread thin — 1–5 per file; `MyMedicationSection` 5, `CalendarLibraryView` 4). `Spacing.xs + 2` (=6) appears in `Chip.swift:48,60`.

### `Radius`
| Token | pt | app occ / files |
|---|---|---|
| `card` | 16 | 1 / 1 (`JournalExportSection:55`) |
| `control` | 10 | 12 / 5 (`Chip`, `GlyphRampPicker`, …) |
| `button` | 16 | 0 in app; 4 in package (all three button styles) |
| `chip` | 15 | **0 anywhere** |
| `newLookCard` | 20 | 5 / 3 (`DayCard:14`, `ExtractionReviewView:349–350`, `ConnectionCardsView:97–99`) + `newLookCard()` |

Literal radii in the app target: `MyMedicationSection:153` (`cornerRadius: 7`), `:163` (`cornerRadius: 12`). Capsules are used by shape (`.capsule`, `Capsule()`) rather than a token — chips, pills, status labels, dose track.

### `Metrics`
| Token | Value | app occ / files |
|---|---|---|
| `minTapTarget` | 44 | 17 / 6 (+ buttons) |
| `maxContentWidth` | 600 | 4 / 4 (onboarding) |
| `rowMinHeight` | 44 | **0** |
| `headerMoodBadge` | 42 | **0** |
| `summarySignal` | 15 | 1 / 1 |
| `rowSignal` | 12 | 1 / 1 |
| `dayHeaderGlyph` | 40 | 1 / 1 |
| `rowMoodDisc` | 43 | 2 / 1 |
| `rowMoodGlyph` | 28 | 1 / 1 |
| `moreAffordance` | 21 | 2 / 1 |
| `IconSize.control / illustration / hero` | 32 / 48 / 72 | **0 / 0 / 0** (onboarding uses literal `.system(size: 64)`) |
| `CheckIn.crescentDiameter` | 300 | 1 |
| `CheckIn.stopGlyph` / `stopGlyphRadius` | 11 / 3 | 2 / 1 |
| `CheckIn.promptDot` | 6 | 3 |
| `CheckIn.promptBarHeight` | 4 | 1 |
| `CheckIn.savedDisc` / `savedCheck` | 78 / 32 | 2 / 1 |

### `Opacity`
| Token | Value (doc says) | app occ |
|---|---|---|
| `deEmphasis` | 0.34 | 1 (`CheckInView:150`) |
| `moodBlock` | **0.24** (doc-comment still says "0.16") | 0 in app; used by `MoodLevel.blockTint` + 3 test refs |
| `moodBadge` | 0.50 | 0 in app; `MoodLevel.badgeTint` + 2 test refs |

Ad-hoc opacities in views (not tokenised): `.opacity(0.15)` tints ×4 (`Chip:49,62`, `RecordingDetailView:285`), `0.12` (`RecordingRow:89`), `0.13` (`TagFlowView:23`), `0.25` (`MedicationLogSheet:176`), `0.3`/`0.4` (`DailyRhythmMatrix:62,68`, `CheckInView:385`), `0.35` (`ExtractionReviewView:350`), `0.6` (`PlaybackWaveformBars:18`), `0.7` (`CheckInView:215,327`).

### `Motion`, `Haptics`, `Icons`
| Token | Value | app occ / files |
|---|---|---|
| `Motion.snappy` | `.snappy(duration: 0.3)` | 7 / 4 |
| `Motion.smooth` | `.smooth(duration: 0.4)` | 14 / 8 |
| `Motion.smoothDuration` | 0.4 | **0** |
| `Motion.expand` | `.easeInOut(duration: 0.25)` | 1 / 1 (`CalendarLibraryView:133`, reduce-motion guarded) |
| `Haptics.success / error / selection` | UIKit generators | 2 / 2 · 2 / 2 · 5 / 3 |
| `Icons.calendar` | `"calendar"` | 1 (`RootTabView`) |
| `Icons.checkIn` | `"checkmark.circle"` | 1 |
| `Icons.insights` | `"chart.bar.fill"` | 1 |
| `Icons.settings` | `"gear"` | 1 |
| `Icons.medication` | `"pills.fill"` | 1 |
| `Icons.sideEffect` | `"bandage.fill"` | **0** (literal `"bandage.fill"` used instead ×2) |

Non-tokenised animations that bypass `Motion`: `CrescentRing` (`.linear(duration: 7).repeatForever`, `.easeInOut(duration: 5)`), `DoseTrack` (`.easeInOut(duration: 0.5)`), `ScreenContainer` scroll-to-top (`.easeOut(duration: 0.25)`). 18 literal `systemImage: "…"` strings outside `Icons`.

---

## 6. Chip / button / card / nav components and their call sites

### `.newLookCard(padding: = Spacing.l)` — `NewLook.swift:52`
`padding` → `.background(NewLook.card, in: .rect(cornerRadius: Radius.newLookCard))` → `.newLookCardShadow()`. **29 call sites / 12 files**: `CheckInView:278`, `TextCheckInComposer:90`, `ADHDSummarySection:42,81,97,113`, `MedicationBarView:19` (`padding: Spacing.m`), `MedicationLogSheet:82,117,144,158`, `RecordingRow:30` (`Spacing.m`), `ExtractionReviewView:133,172,224,289,421,437`, `ConnectionCardsView:68`, `InsightsView:139,149,157,166`, `SiriOnboardingView:84`, `RecordingDetailView:142,220,261,297`, `StickerSetupView:247`.

### `.newLookCardShadow()` — `NewLook.swift:62`
`.shadow(.black.opacity(0.05), radius: 8, y: 2)` + `.shadow(.black.opacity(0.03), radius: 2, y: 1)`. 5 direct sites / 2 files: `DayCard:37` (full-bleed card with own `.clipShape`), `CheckInView:247,264,318,469` (pills). The only inline `.shadow(` outside the token is `FeedbackButton:23` (`.shadow(radius: 4)`).

Hand-rolled cards that reproduce the token but add a **border** (contradicts the "no border in New Look" rule): `ConnectionCardsView:97–99` (dashed `NewLook.hairline` locked-state card), `ExtractionReviewView:349–350` (`Palette.medication.opacity(0.35)` 1pt border on the med card). `JournalExportSection:55` uses `Radius.card` (16) on a `tintNeutral` well.

### `.newLookChip(selected:role:)` + `NewLookChipRole` — `NewLook.swift:73–107`
Capsule; `Typography.caption` medium; unselected = `NewLook.card` fill + 1pt `NewLook.hairline` + `inkPrimary`; selected = `role.selectedFill` + `onSelection`; padding `Spacing.m` × `Spacing.s`.
- `.standard` → **`Theme.meadowGreen`** (not `NewLook.selection`, despite `selection`'s doc-comment); `.medication` → `Palette.medication`; `.checkIn` → `NewLook.checkInGreen`.
- 2 call sites: `MonthSelectorScrollView:25` (`.standard`, Insights month pill, `.tracking(1.3)` uppercase), `ExtractionReviewView:231` (`chipButton`, default `role: .checkIn`).

Other chip implementations in the app (not using the token): `Views/Components/Chip.swift` (`.topic` = `TopicCategory.color` @0.15 rounded-rect `Radius.control`; `.filter` = `NewLook.selection` text + `.opacity(0.15)` fill / `inkSecondary` + `NewLook.card`), `RecordingRow:89` (`tag.color.opacity(0.12)` capsule), `TagFlowView:23` (`tag.color.opacity(0.13)`), `RecordingDetailView:285` `statusLabel` (`color.opacity(0.15)` capsule + `Typography.label`), `MedicationLogSheet:176` (`Palette.medication.opacity(0.25)` / `tintNeutral`), `InsightsView` sleep-deferred chip, `TimelineRow` `Chip(kind:level:text:color:)` (its own private struct). **At least five chip grammars coexist.**

### Button styles — `Buttons.swift`
| Style | Fill | Label | Shape | Shadow | app sites |
|---|---|---|---|---|---|
| `.primary` (`PrimaryButtonStyle`) | `Theme.meadowGradient` | `.white`, `Typography.headline` | `Radius.button` 16, `minHeight: 44`, `maxWidth: .infinity` | `Theme.meadowAmber.opacity(0.34)`, r12, y5 | 1: `JournalExportSection:71` |
| `.checkInPrimary` | `LinearGradient([NewLook.checkInGreen, NewLook.checkInGreenSoft])` | `NewLook.onSelection` | same | `checkInGreen.opacity(0.3)` r12 y5 | 5: `TextCheckInComposer:108`, `DownloadPermissionView:84`, `LLMDownloadView:75`, `SiriOnboardingView:42`, `WelcomeView:82` |
| `.secondary` | `NewLook.card` + 1pt `NewLook.hairline` | `NewLook.inkPrimary` | same | none; pressed 0.85 | 3: `DownloadPermissionView:89`, `LLMDownloadView:84`, `RecordingDetailView:238` |

The check-in hub's own pills bypass the styles: `CheckInView:236–247` solid `Theme.meadowGreen` capsule + `onSelection` + `newLookCardShadow` ("Speak check-in"), `:252–266` `NewLook.card` capsule (`hubOption`), `:398–410` / `:492–494` further `meadowGreen` capsules, `:432` `onInk` on an ink capsule (stop button).

### `Text.cardEyebrow()` — `Card.swift:7`
`Typography.label` + `.textCase(.uppercase)` + `.tracking(0.7)` + `NewLook.inkSecondary`. **1 call site**: `StickerSetupView:241`. Equivalent hand-rolled eyebrows exist (`MedicationBarView:58–61` uses `.tracking(0.5)` + `Palette.medication`; `CheckInView:201–204` `Typography.label` uppercase without tracking).

### `NewLookNavBar(_:leading:trailing:)` — `NewLook.swift:116`
ZStack: centred title `Typography.text(24, weight: .bold, relativeTo: .title2)` in `inkPrimary` + `.isHeader`; leading/trailing pills in an HStack; padding `Spacing.l` × `Spacing.s`. **1 call site**: `ExtractionReviewView:34` ("Edit check-in" sheet, replaces the system nav bar).

---

## 7. Signal glyphs — shapes and level → colour mapping

All five glyph views are `Canvas`/shape drawings in a 24×26 (or 24×24) design space, scaled to the frame, **no SF Symbols and no image assets**. None is used directly by the app (0 sites each); the app goes through `SignalGlyph`.

| `GlyphSignal` | View | Varies by level | Level encoding (grayscale-safe) | Colour source |
|---|---|---|---|---|
| `.mood` | `SproutGlyph` | yes | crown bud→open at ≥4, size lift `0.66 + level·0.068`, fill `0.42 + level·0.145`, stem notch ≥3, crown dot at 5 | `MoodLevel.color` (§3.4), fallback `.secondary` |
| `.energy` | `BoltGlyph` | yes | size lift `0.6 + level·0.08`, fill `0.35 + level·0.15`, stroke `0.9 + level·0.16` | `Palette.energyRamp[level-1]` |
| `.focus` | `ApertureGlyph` | yes | outer ring dashed `[3,3]` at ≤2, ring 6 at ≥2, ring 3.3 at ≥4, core radius `(level-1)·0.85` at ≥3 | `Palette.focusRamp[level-1]` |
| `.sleep` | `BedIcon` | **no** ("ramp deferred") | side-profile bed, stroke 1.7 | `Palette.sleepIndigo` |
| `.medication` | `CapsuleGlyph` | **no** | two-tone horizontal capsule, 2pt border, seam | `Palette.medication` |
| absent level (mood/energy/focus with `nil`) | private `EmptySignalGlyph` | — | dashed circle `Color.secondary.opacity(0.3)`, `[2,2]` | — |

`SignalGlyph(_ kind:, level: Int? = nil, size: CGFloat = 22, decorative: Bool = false)` — clamps via `clampedSignalLevel` (1…5, `nil` passes through), owns the VoiceOver label (`"Energy: Alert, 4 of 5"` / `"Sleep"`), `accessibilityHidden(decorative)`.

**16 app call sites / 12 files — every one passes `decorative: true`** (the surrounding row/chip carries the label): `ADHDSummarySection:34` (med, 18), `FoldedDayCardHeader:40` (mood, `Metrics.dayHeaderGlyph` 40), `:89` (chip glyph, `summarySignal` 15), `GlyphRampPicker:21` (picker, size 30 default), `MedicationBarView:55` (med, 24), `RecordingRow:78` (16), `TagFlowView:11` (15), `TimelineRow:51` (mood, `rowMoodGlyph` 28), `:117` (`rowSignal` 12), `ExtractionReviewView:202` (sleep, 16), `:296` (med, 22), `SignalAverageGauges:28`, `SignalStripsView:33` (18), `:76` (28), `InsightsView:69` (sleep, 15), `RecordingDetailView:147` (30). Sizes used: 12, 15, 16, 18, 22, 24, 28, 30, 40 — five of nine are literals rather than `Metrics`.

Supporting types: `GlyphBadge(kind:level:)` — 9 sites / 2 files (`Recording+MoodDisplay` builds `DisplayTag`s; `ADHDSummarySection`). `SignalKind` (app, `InsightsViewModel+Signals.swift`) bridges to `GlyphSignal` via `.glyphSignal`. The four pure functions (`clampedSignalLevel`, `signalName`, `signalSynonym`, `signalAccessibilityLabel`) are **not called by app views**; they are used by `SignalGlyph` and pinned by `SignalGlyphTests` (26 assertions).

`SleepLevel` (`restless/light/okay/good/deep`) exists in `SquirlSignals` and is picked in `ExtractionReviewView:207`, but has **no colour ramp and no `SignalLevel` conformance** — the design deliberately renders sleep as a single indigo icon, and Insights shows a "Sleep · not tracked yet" chip (`InsightsView:66–75`).

---

## 8. `app-four/DesignSystem/` (app-side, 2 files) and adjacent app-side "system" views

### `ScreenContainer.swift` (111 lines) — used 12× / 7 files (every tab root)
- `NavigationStack(path:)` with `.navigationTitle(title)` + `.navigationBarTitleDisplayMode(.inline)`.
- `.background(NewLook.screen.ignoresSafeArea())`, `.toolbarBackground(NewLook.screen, for: .navigationBar)`.
- **`.tint(Theme.meadowGreen)`** on the stack.
- **Tab-bar appearance lives here, not on the `TabView`**: `.toolbarBackground(NewLook.screen, for: .tabBar)` + `.toolbarBackgroundVisibility(.visible, for: .tabBar)` — with the comment "it must live here (every tab's root), not on the TabView, where it silently no-ops".
- Optional `ScrollView` wrapper with `.scrollContentBackground(.hidden)`, `ScrollPosition` reset token, `.edgeFadeMask(top: 0, bottom: 36)` (`tabBarFadeHeight = 36`, `barFadeHeight = 0`).
- Pins `.medicationBarOverlay(shown:)`.

### `MedicationBarOverlay.swift` (36 lines) — `.medicationBarOverlay(shown:)` 5× / 3 files
`safeAreaInset(edge: .top, spacing: 0)` hosting `MedicationBarView` with `.padding(.horizontal, Spacing.l)` + `.padding(.top, Spacing.s)`. **Doc-comment is stale**: it says the bar is "a floating Liquid Glass capsule (`.glassEffect`)", but the only `glassEffect` string in the app target is that comment — `MedicationBarView` is a `.newLookCard(padding: Spacing.m)`. No `.glassEffect`, `.ultraThinMaterial`, `.regularMaterial` or `.thinMaterial` appears anywhere in `app-four/`.

### Adjacent app-side components that behave like design-system atoms (in `Views/Components/`, not the package)
- `EdgeFadeMask.swift` — `.edgeFadeMask(top:bottom: = 36)`, 4 sites.
- `Chip.swift` — see §6.
- `GlyphRampPicker.swift` — generic over `SignalLevel & CaseIterable`; `ringTint` default `Theme.accent`, ring `RoundedRectangle(Radius.control)` 1.5pt; `HStack(spacing: Spacing.m)`.
- `CrescentRing.swift` — `Circle().stroke(Theme.meadowGreen, lineWidth: 22)`; breathing scale 1.035 / opacity 0.94 over 5 s; recording spin 7 s linear; reduce-motion guarded.
- `MedicationBarView.swift` — `DoseTrack` capsule `NewLook.tintNeutral` groove, `[Palette.medication, Palette.medicationFillEnd]` leading→trailing fill, onset pulse `<20 %`.
- `DayCard.swift` — full-bleed `NewLook.card` + `.clipShape(RoundedRectangle(Radius.newLookCard, .continuous))` + `.newLookCardShadow()`.
- `Recording+MoodDisplay.swift` (`Models/`) — `DisplayTag` colours: **`.indigo`** for sleep ×3 (not `Palette.sleepIndigo`), **`.pink`** for emotions (`ADHDSummarySection` uses `Theme.accent` for the same tags), `Palette.warning` side-effects, `Palette.medication` meds, `TopicCategory.color` = **`.purple/.orange/.blue/.green/.gray`** (`Models/AppEnums.swift:81–89`).

---

## 9. Tab bar, tint and navigation setup

- `RootTabView.swift`: classic `TabView(selection:)` with four `.tabItem { Label(_, systemImage: Icons.*) }` — `Icons.calendar "calendar"`, `Icons.checkIn "checkmark.circle"`, `Icons.insights "chart.bar.fill"`, `Icons.settings "gear"`; `.tint(Theme.meadowGreen)` on the `TabView`. **No iOS 18+ `Tab(…)` builder, no `tabViewStyle`, no `tabBarMinimizeBehavior`, no search tab, no `UITabBar.appearance()` / `UINavigationBar.appearance()` anywhere.**
- Tab-bar background is forced opaque `NewLook.screen` from inside each tab root (`ScreenContainer`), so the system Liquid Glass tab bar is effectively painted over.
- Nav bar: inline titles (mostly empty string `""`), `toolbarBackground(NewLook.screen)`; `RecordingDetailView:44` repeats the nav-bar background. `ExtractionReviewView` replaces the nav bar with `NewLookNavBar`.
- Other `.tint(` sites (7 total): `ScreenContainer:56`, `RootTabView:36`, `ModelDownloadRow:73` (toggle), `CheckInView:398` (`ProgressView().tint(NewLook.onSelection)`), `DownloadPermissionView:74` + `LLMDownloadView:65` (progress, `checkInGreen`), `StickerSetupView:147` (`path.tint` = medication purple or meadow green).
- `Color.accentColor` read directly: `DoseGuardSection:34`, `MyMedicationSection:94` (see §3.2 caveat).
- No `preferredColorScheme` override; `@Environment(\.colorScheme)` is read in `ConnectionCardsView`, `MoodBubbleChart`, `SignalAverageGauges` for `contrastingInk`.

---

## 10. Drift, leaks and stale statements found while mapping

1. **Three greens, plus a fourth by coincidence**: `Theme.meadowGreen #5F8A4C` (tint, ring, speak pill, standard chip fill, status), `NewLook.selection #54B492` (filter chip, transcribing status, ramp fallback), `NewLook.checkInGreen #5FB36E` (capture flow) = `MoodLevel.good.color #5FB36E`. The `NewLook.selection` doc-comment ("filled selected chips") no longer matches `NewLookChipRole.standard` (commit `02f83b17` moved it to meadow).
2. `Typography.text(24, weight: .bold, relativeTo: .title2)` is re-spelled at 4 sites + `NewLookNavBar` although `Typography.moodWord` is exactly that.
3. `Opacity.moodBlock` doc-comment says 0.16; the value is `0.24`.
4. `MedicationBarOverlay` / `ScreenContainer` comments describe Liquid Glass / translucent `.bar` material; the code paints opaque `NewLook.screen` and a white card.
5. Sleep colour is split: `Palette.sleepIndigo` in views vs `.indigo` (system) in `Recording+MoodDisplay` `DisplayTag`s; emotion colour is `.pink` there vs `Theme.accent` in `ADHDSummarySection`.
6. `TopicCategory.color` is raw system colours (`.purple/.orange/.blue/.green/.gray`) rendered by `Chip.topic`.
7. `AccentColor.colorset` (bronze `#B8842A`/`#D4A24A`) ≠ live tint (meadow green); two Settings rows read `Color.accentColor`.
8. Settings sections (`MyMedicationSection`, `DoseGuardSection`, `IssueReportView`) run on `.secondary/.primary`, `.footnote`, `Color(.tertiarySystemFill)`, literal `cornerRadius: 7/12`, literal paddings — the least tokenised surface.
9. `app-four/wireframes/*.swift` (5 files, system colours/fonts, `.gray`, `.orange`, `Color.purple`) are **compiled into the app target** (the synchronized group's only exception is `Info.plist`) but referenced nowhere. `Views/TestServicesView.swift` is likewise compiled but "UNMOUNTED as of 1.1".
10. Hand-rolled cards with borders: `ConnectionCardsView:97–99`, `ExtractionReviewView:349–350` (rule: "never a card border in New Look").
11. The old DESIGN.md (`git show HEAD:DESIGN.md`) foundation table still lists Paper & Pollen surface hexes and `#9277BE` for medication dark, and lists `accent/medicationText #6B4E8F` and `ink/destructive #D54037` as "code role pending" — **neither exists in code**; `Theme.danger` is still `#B5503A`/`#CF6A52`.

---

## 11. Dead or package-only symbols (0 app-target uses) — delete candidates

| Symbol | Notes |
|---|---|
| `Typography.dayCardDate`, `Typography.mono(_:)`, `View.typography(_:)` | 0 anywhere outside definition |
| `Spacing.ringStroke` (3.3) | 0 |
| `Radius.chip` (15) | 0 anywhere; `Radius.button` (16) and `Radius.card` (16) are duplicates of each other (`button` only inside the package) |
| `Metrics.rowMinHeight`, `Metrics.headerMoodBadge`, `Metrics.IconSize.control/illustration/hero` | 0 |
| `Motion.smoothDuration` | 0 |
| `Icons.sideEffect` | 0 (literal used instead) |
| `MoodLevel.onColor` (`#1C1C1E`) | 0 anywhere |
| `NewLook.checkInGreenSoft` | only `CheckInPrimaryButtonStyle` |
| `Theme.meadowGradient` | only `PrimaryButtonStyle` (1 app site) |
| `Palette.energyRampPartner`, `Palette.focusRampPartner` | only via `SignalLevel.gradientPartner` → `fillGradient`/`bubbleFill` (Insights) |
| `GlyphSignal.variesByLevel`, `GlyphSignal.selfState`, `GlyphSignal.title` | package-internal + preview |
| `Opacity.moodBlock/moodBadge` | package-internal (`MoodLevel`) + tests |
| `SproutGlyph/BoltGlyph/ApertureGlyph/BedIcon/CapsuleGlyph` | never instantiated directly by the app; reachable only through `SignalGlyph` (so they are *not* dead, but their `public` surface is unused) |
| `Card.swift` `#Preview`, `SignalGlyph` `#Preview`, glyph `#Preview`s | package previews reference `.green`, `.blue`, `.yellow` literals |

---

## 12. Build-break matrix — what a deletion takes down

| If you remove… | Compile breaks in (app target) | Also |
|---|---|---|
| `NewLook.inkSecondary` / `inkPrimary` / `card` / `screen` / `hairline` | 27 / 24 / 11 / 12 / 13 files | `SandboxApp` (4 files), `DayCardPaletteTests` (`NewLook.card` as surface) |
| `.newLookCard()` | 12 files, 29 sites | `SandboxApp/DesignGallery` |
| `.newLookCardShadow()` | `DayCard`, `CheckInView` | — |
| `.newLookChip` / `NewLookChipRole` | `MonthSelectorScrollView`, `ExtractionReviewView` | — |
| `NewLookNavBar` | `ExtractionReviewView` | — |
| `Theme.meadowGreen` | 7 files incl. `RootTabView`, `ScreenContainer`, `CrescentRing` | `NewLookChipRole.standard` (package), `StickerSetupViewTests:39` |
| `Theme.accent` / `danger` / `meadowAmber` / `statusDone` / `statusInProgress` | 4 / 5 / 2 / 3 / 1 files | `SandboxApp` |
| `Palette.medication` | 11 files | `StickerSetupViewTests:38`, `SignalGlyph`, `CapsuleGlyph`, `NewLookChipRole.medication` |
| `Palette.sleepIndigo` / `warning` / `medicationFillEnd` | 2 / 2 / 1 files | `BedIcon` default |
| `Palette.energyRamp` / `focusRamp` | `Recording+MoodDisplay`, `RecordingDetailView` | `EnergyLevel/FocusLevel: SignalLevel`, `SignalGlyph` |
| `MoodLevel.color/gradientPartner/fill/deepFill/wordColor/blockTint/badgeTint/displayLabel` | 8+ files (`TimelineRow`, `FoldedDayCardHeader`, `MoodBubbleChart`, `MoodLegend`, `DailyRhythmMatrix`, `SignalAverageGauges`, `Recording+MoodDisplay`, …) | `RecordingMoodDisplayTests` (pins all 10 hexes), `DayCardPaletteTests` (pins `#5FB36E`, `#2E8B57`, AA ≥ 4.5 on `NewLook.card`) |
| `SignalGlyph` | 12 files | `GlyphRampPicker`, `SandboxApp` |
| `GlyphSignal` / `GlyphBadge` | `Recording+MoodDisplay`, `ADHDSummarySection`, `InsightsViewModel+Signals`, `GlyphRampPicker`, `RecordingDetailView`, `SignalStripsView` | `SignalGlyphTests` (all 26 assertions) |
| `SignalLevel` protocol + `fillGradient`/`bubbleFill`/`contrastingInk` | 6 files (Insights charts, `GlyphRampPicker`, `InsightsViewModel+Signals`) | 9 test refs |
| `Typography.caption` / `headline` / `body` / `label` / `subheadline` / `callout` | 21 / 10 / 12 / 11 / 10 / 8 files | all three button styles, `newLookChip`, `cardEyebrow` |
| `Typography.text(_:weight:relativeTo:)` | 6 files | `NewLookNavBar` |
| `Spacing.s/m/l/xs` | 27 / 25 / 25 / 16 files | every package component |
| `Radius.control` / `newLookCard` | 5 / 3 files | `newLookCard()` |
| `Metrics.minTapTarget` | 6 files | button styles |
| `Motion.smooth` / `snappy` | 8 / 4 files | — |
| `Haptics.*` | 5 files | — |
| `Icons.*` (tabs + medication) | `RootTabView`, 1 more | — |
| `PrimaryButtonStyle` / `.primary` | `JournalExportSection` | `SandboxApp` |
| `CheckInPrimaryButtonStyle` / `.checkInPrimary` | 5 files (onboarding + composer) | — |
| `SecondaryButtonStyle` / `.secondary` | 3 files | `SandboxApp` |
| `Color(hex:)` | 0 app files | 14 test assertions build `Color(hex:)` literals; every package colour |
| `Color(lightHex:darkHex:)` | 0 app files | every adaptive package colour |
| `Reexport.swift` (`@_exported import SquirlSignals`) | any app file naming `MoodLevel/EnergyLevel/FocusLevel/SleepLevel` — the app *also* re-exports `SquirlSignals` itself in `SignalsReexport.swift`, so this one is redundant for the app but needed inside the package | — |
| `app-four/App/SignalsReexport.swift` | **the whole app module** (every unqualified token) | — |

---

## 13. Tests that pin design-system values (all in `app-fourTests/`, Swift Testing, `@testable import app_four`)

| Test file | What it pins | Breaks when |
|---|---|---|
| `SignalGlyphTests.swift` (12 `@Test`) | `clampedSignalLevel` (nil pass-through, clamp 1…5), `signalName` (`"Low"`, `"Great"`, `"Alert"`, `"Foggy"`, `"Locked In"`, nil for sleep/med), `signalSynonym` (`"bright, thriving"`, `"slow, heavy"`, `"hazy, drifting"`), `signalAccessibilityLabel` (`"Energy: Alert, 4 of 5"`, `"Focus: Locked In, 5 of 5"`, `"Energy: Charged, 5 of 5"`, `"Sleep"`, `"Medication"`, `"Mood"`) | level names, the 1…5 grammar, or the a11y string format changes |
| `Models/DayCardPaletteTests.swift` (5 `@Test`, `@MainActor`) | `blockTint == color.opacity(Opacity.moodBlock)`, `badgeTint == color.opacity(Opacity.moodBadge)`, `wordColor != deepFill`, **WCAG ≥ 4.5:1 of `wordColor` on `color @ moodBlock` composited over `NewLook.card`, light AND dark**, `MoodLevel.good.blockTint == Color(hex: "#5FB36E")…`, `MoodLevel.great.badgeTint == Color(hex: "#2E8B57")…` | any mood hex, `NewLook.card`, `Opacity.moodBlock/moodBadge`, or `wordColor` changes |
| `Models/RecordingMoodDisplayTests.swift` | `Recording.moodColor` == `#EA9248 / #FDC06C / #B9DB9C / #7EC38A / #459B6B`; unknown → `Color(.systemGray4)`; `MoodLevel.okay.color == #9FCB79`, `.deepFill == #9FCB79`, `.gradientPartner == #B9DB9C`, `.fill == #B9DB9C`, `.low.color == #DA7A2A`, `.flat.color == #EDA94A`, `.great.color == #2E8B57`; `displayLabel` "Low"/"Great" | any mood ramp hex or the fill/partner wiring |
| `Views/StickerSetupViewTests.swift:38–39` | `Path.dose.tint == Palette.medication`, `Path.checkIn.tint == Theme.meadowGreen` | either token is renamed/retuned |
| `ViewModels/CalendarMonthModelTests.swift`, `ViewModels/InsightsViewModelTests.swift`, `PromptBuilderTests.swift` | reference `MoodLevel`/`EnergyLevel`/`FocusLevel` (SquirlSignals) only — no colour/typography tokens | level enums change |

No package-level tests exist; no snapshot/render tests exist; glyph `View`s are "exempt (verified by build + simulator render)".

---

## 14. Ambiguities to resolve before the plan commits

- **Which green survives?** `Theme.meadowGreen` (tint + chip fill), `NewLook.selection` (filter chip + status), `NewLook.checkInGreen` (capture) — the code does not say which is canonical; the Pencil palette (violet/green/neutral 50–900) will decide, and the `NewLookChipRole` enum + `Chip.swift` + `CheckInView` pills must all move together.
- **`Color.accentColor` in Settings** — unverified whether it resolves to the bronze asset or the meadow `.tint()`; check on device before deciding whether the asset catalog colour needs updating alongside the tokens.
- **Sleep**: `SleepLevel` has 5 cases but no ramp; the Pencil glyph frame shows a sleep moon with 5 levels — this contradicts the current "single indigo icon, ramp deferred" rule and `BedIcon` (a bed, not a moon), and would need `SleepLevel: SignalLevel` + a ramp + `GlyphSignal.sleep.variesByLevel = true`.
- **Dark values are all "derived"** (per doc-comments) — none is Figma/Pencil-locked; the Pencil export shows light only unless the palette frame has dark ramps (not checked here).
- **`Radius.card` 16 vs `Radius.button` 16 vs `Radius.newLookCard` 20** — three names for two values; the plan should pick one radius scale from the Pencil components.
- **`inkSecondary` AA exception** (owner ruling 2026-07-12) — carried by 105 call sites; if the Pencil neutral ramp gives a compliant grey, this is the single highest-impact token swap.
