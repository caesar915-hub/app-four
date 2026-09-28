# Implementation Plan: UI Refresh from the Pencil design (057)

**Branch**: `feat/057-ui-refresh` | **Date**: 2026-09-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/057-ui-refresh/spec.md`; the detailed step plan is `shipaton_plan/UI_REFRESH_PLAN.md` (this file is the Spec Kit view of it, not a second plan).

## Feature Definition & Scope

Re-skin the eight pen screens on a new token set, shared components and redrawn glyphs, in the plan's order: foundations (Phase B) → check-in trio → Calendar → secondary surfaces → wave-1 release; then Day Details → Edit → Insights → Settings → polish → wave-2 release. Out of scope: any SwiftData schema change, the RevenueCatUI paywall's look (dashboard-owned), real waveform amplitudes, the summary-correction editor (UI-43, deferred).

## Technical Context

### 1. Language & Runtime Environment
Swift 6.2 / SwiftUI, iOS 26 deployment target, Xcode 26.6; the design-system package `Packages/SquirlDesignSystem` (Swift 5 language mode) depends on `SquirlSignals`.

### 2. Core Dependencies & Frameworks
SwiftUI `Canvas` for glyphs; `TabView` + `Tab` for state with the system bar hidden and a custom overlay; `PreferenceKey` for chrome visibility; `UIFontMetrics` for Dynamic Type. No new third-party dependency.

### 3. State Management & Data Flow
Unchanged: `@Observable @MainActor` view models, `RecordingStore`, `AppIntentRouter` as the one check-in choke point. New computed state only (`CheckInViewModel.flowProgress`, `audioLevel`; `MedicationBarViewModel.DoseStatus`; `RecordingDetailViewModel.relativeTitle`; `ExtractionReviewViewModel.isDirty`).

### 4. Storage & Persistence Strategy
No schema change (Constitution IX). Two new `@AppStorage` keys for the medication bar's taken/end-time toggles.

### 5. Performance & Constraints
Glyphs are `Canvas` drawings from cached `Path`s (`GlyphArt` statics); no per-frame path parsing. The custom tab bar is one overlay per root, not per screen.

## Constitution Check

| Principle | Status | Note |
|---|---|---|
| I SwiftUI-First | ✅ with waiver | All SwiftUI, iOS 26 APIs. **Waiver**: per-screen HTML mockups replaced by `#Preview`s + simulator screenshots (owner unavailable; pen screens are the approved design) — see Complexity Tracking. |
| II Test-Build-Ship | ✅ | Every phase: `xcodebuild test … -parallel-testing-enabled NO` green before its commit; `xcodebuild`'s own exit code is read (not the wrapper's). |
| III Correctness Over Speed | ✅ | Pen defects (typos, wrong axes, placeholder data) are normalised, never transcribed; nothing deleted while a consumer remains. |
| IV Minimal Surface | ✅ | Two coexistence windows tracked below; every pre-057 alias is scheduled for deletion in UI-49. |
| V Solo Git Discipline | ✅ | One branch, sequential commits per step, PR with `/code-review`; merges stay the owner's. |
| VI On-Device Privacy | ✅ | No data flow changes. |
| VII On-Device LLM Extraction | ✅ | Level words only from the level enums; `SleepLevel` gains `displayLabel`. |
| VIII Service-Oriented Architecture | ✅ | Views never touch services directly; new state lives in view models. |
| IX Pre-Release Data Posture | ✅ | No schema change. |
| X Test-First | ✅ | Each view-model addition ships RED → GREEN in its step (tasks.md); token/glyph helpers covered by `TokenContrastTests` / `SignalGlyphTests`. |
| XI Architectural Exhaustiveness | ✅ | Every undrawn state (empty, transcribing, failed, text check-in, disabled) is named per screen in `DESIGN.md` §15 and handled in the screen step. |

## Project Structure

### Documentation (this feature)
```
specs/057-ui-refresh/
├── spec.md · plan.md · tasks.md
└── research/          # screen specs, verified cross-checks, design-system spec, code maps, constraints
docs/design/pen/       # PNG / JSON / HTML exports of the pen; glyphs/extracted-glyphs.json
DESIGN.md              # the design system, pen-derived
shipaton_plan/UI_REFRESH_PLAN.md   # the step plan (D1–D26, UI-01…UI-54)
```

### Source Code (repository root)
```
Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/
├── Tokens/{Palette+Ramps,Surface,Ink,Accent,Stroke,Elevation}.swift
├── Typography.swift · Spacing.swift · Radius.swift · Metrics.swift · Motion.swift · Icons.swift · Buttons.swift
├── Components/{CardStyle,HairlineDivider,SectionHeading,PageTitleBlock,FlowLayout,BillChip,NavPill,ToggleRow,
│               RadioRow,SegmentedPicker,InfoRow,IdentityIcon,MedicationBadge,CheckInRing,LevelTilePicker,
│               ChromeVisibility,FloatingTabBar}.swift
├── Glyphs/{SVGPath,GlyphArt,SproutGlyph,BoltGlyph,TargetGlyph,MoonGlyph,CapsuleGlyph}.swift
├── SignalGlyph.swift · GlyphSignal.swift · SignalLevel.swift · MoodLevel+Palette.swift
└── NewLook.swift · Theme.swift · Palette.swift · Palette+Signals.swift   # aliases until UI-49
app-four/
├── Views/RootTabView.swift · DesignSystem/ScreenContainer.swift            # chrome-less roots + floating chrome
├── Views/CheckIn/*, Views/Library/*, Views/RecordingDetailView.swift, Views/ExtractionReviewView.swift,
│   Views/InsightsView.swift + Views/Insights/*, Views/SettingsView.swift + Views/Settings/*   # per-screen steps
└── ViewModels/*                                                            # test-first additions
app-fourTests/
├── DesignSystem/TokenContrastTests.swift · SignalGlyphTests.swift · Models/*PaletteTests.swift
└── ViewModels/*Tests.swift                                                 # RED → GREEN per step
```

**Structure Decision**: single iOS project with the design system as a local SPM package (existing layout); atoms live in the package, screens in the app.

### File Manifest & Responsibilities
See `shipaton_plan/UI_REFRESH_PLAN.md` §3.1 (token package), §3.2 (components → consumers), §3.3 (data gaps → tests) and §4 (files per step).

## Complexity Tracking

| Violation | Why needed | Simpler alternative rejected because |
|---|---|---|
| Two token namespaces coexist between UI-06 and UI-49 (`NewLook`/`Theme`/`Palette` aliases beside `Surface`/`Ink`/`Accent`/`Stroke`) | 261 `NewLook.` references across 36 files cannot migrate in one PR without violating "one PR = one revertable feature" | Replacing values under the old names keeps semantically wrong names forever; deleting first breaks 36 files. |
| Custom floating tab bar overlay instead of the native iOS 26 tab bar | The pen's most visible brand element (white pill, icon-only green active pill, violet Add button); the native bar cannot drop labels or host the Add button | Native bar tinted green is HIG-perfect but is not the design (D4); fallback kept at 2 h if the a11y device QA fails. |
| Constitution I mockup waiver: SwiftUI `#Preview`s + simulator screenshots instead of per-screen HTML mockups | Owner unavailable to review mockups; asked for implementation ASAP; the pen screens are the approved design | Building unreviewed mockups spends credits the owner asked to save without producing a reviewable artefact before code. |
