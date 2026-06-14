# Insights Redesign (Meadow) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (chosen: inline execution) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Companion skills: swiftui-design-principles, swiftui-pro, swift-accessibility-skill.

**Goal:** Rebuild `InsightsView` as a single five-section vertical scroll treating mood, energy, and focus as co-equal signals in the Meadow palette (M2 + E2 + F2), migrating the mood palette app-wide at the `Recording.moodColor` SSOT.

**Architecture:** Three layers. (1) A *level-color SSOT* — the existing ordinal enums `MoodLevel`/`EnergyLevel`/`FocusLevel` gain `color`/`gradientPartner`/`displayLabel` via a shared `SignalLevel` protocol; mood lives in `Recording+MoodDisplay`, energy/focus ramps in `Palette`. (2) An *InsightsViewModel* that derives five pure computations (`moodShares`, `signalStrips`, `signalAverages`, `rhythmMatrix`, `connections`) off the existing store pipeline. (3) Five *stateless SwiftUI views* rendering them with one shared gradient grammar. No new persistence.

**Tech Stack:** SwiftUI (iOS 26), SwiftData (read-only here), Swift Testing (`@Test`/`#expect`), dynamic `UIColor { trait in }` for the focus ramp.

**Spec:** `docs/superpowers/specs/2026-06-12-insights-redesign-design.md`. **Approved mockup:** `docs/superpowers/plans/2026-06-11-insights-redesign-mockup-v5.html` (the authoritative source for exact hexes, gradients, sizes, and layout).

**Build/test:** `env -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_SYSTEM -u GIT_CONFIG_COUNT xcodebuild test -scheme app-two -project app-two.xcodeproj -destination 'platform=iOS Simulator,id=667B75F8-4C75-4A14-ACE1-D5C46F3CBC0D'`. Scheme `app-two`; tests target `app-twoTests`.

---

## Decisions made during planning (autonomous, documented)

- **Branch:** stay on `nlp-extraction-hardening` (per user). The uncommitted `moodColor` edit (removed `case "alert"`) is folded into the M2 rewrite (Task 2) — the whole switch is replaced.
- **Text-on-fill contrast:** instead of per-level ink bookkeeping, one luminance helper `Color.contrastingInk(for:in:)` resolves dynamic colors and returns black/white. Used for the three places text sits on a colored fill (bubble %, gauge word, connection bar). This is the sanctioned black/white exception (like the monospaced-timer exception), documented in the helper.
- **Late-night bucket:** the existing time-of-day defs drop hours 0–5. To avoid silently dropping post-midnight check-ins from the rhythm matrix, "Late" = `hour >= 22 || hour < 6`. Morning 6–11, Afternoon 12–17, Evening 18–21. Documented in code.
- **Dominant-level tie-break (rhythm matrix):** max count wins; ties broken toward the **higher** `numericValue` (more positive), deterministically.
- **Gauge fill gradient:** straddles the two levels around the average — `LinearGradient(ceilLevel.gradientPartner → floorLevel.color)`, matching the mockup (`mood-good-l → mood-okay`).
- **`MoodLegend` "kept":** the file/component is kept but its data type changes from the (removed) `MoodBucket` to the new `MoodShare`; it renders the mockup's dot+label legend under the bubble chart.
- **Connections "afternoon focus":** the mockup says "afternoon focus"; we compute each medication day's *dominant* focus (more robust than requiring an afternoon check-in) and phrase it "your focus was Sharp or better".

## Palette reference (from mockup v5 — authoritative)

Mood M2 (static, both modes) — `base` / `partner(light end)`:
`low #C2503F/#D4705F · flat #DE8050/#EA9D72 · okay #E5C46A/#EFD68C · good #94C56F/#AED68C · great #4CAF6E/#6BC68A`

Energy E2 (static, both modes) — `base` / `partner`:
`sluggish #44546E/#5F6F8A · tired #4E6F94/#6B8BAE · steady #5889BA/#74A3D2 · alert #63A4E0/#82BCF0 · charged #79C4FF/#9CD6FF`

Focus F2 (dynamic) — `dark base/partner` ‖ `light base/partner`:
`foggy #3A3A3E/#4A4A50 ‖ #D8D8DE/#E6E6EA` · `distracted #58585E/#6A6A72 ‖ #B4B4BC/#C6C6CE` · `present #7E7E86/#92929C ‖ #8A8A94/#9C9CA6` · `sharp #ABABB5/#C2C2CC ‖ #5A5A64/#6E6E78` · `lockedIn #ECECF4/#FFFFFF ‖ #26262C/#3A3A42`

Gradient directions (mockup): beads `linear 160°`, blobs `150°`, gauge fill `175°`, connection bar `90°`, bubble `radial(circle at 32% 28%, partner, base 70%)`. The shared helper uses `topLeading → bottomTrailing` for linear fills (visually ≈155°); bubbles use a dedicated radial helper.

---

## File structure

**Create:**
- `app-two/DesignSystem/SignalLevel.swift` — `SignalLevel` protocol, conformances, `fillGradient`/`bubbleFill`, `Color.contrastingInk`, `Color(lightHex:darkHex:)`.
- `app-two/DesignSystem/Palette+Signals.swift` — `Palette.energyRamp/Partner`, `Palette.focusRamp/Partner` (dynamic). (Energy/focus level→color extensions live in `SignalLevel.swift`.)
- `app-two/Views/Insights/InsightsSectionHeader.swift` — serif left-aligned header + subtitle.
- `app-two/Views/Insights/MoodBubbleChart.swift`
- `app-two/Views/Insights/SignalStripsView.swift`
- `app-two/Views/Insights/SignalAverageGauges.swift`
- `app-two/Views/Insights/DailyRhythmMatrix.swift`
- `app-two/Views/Insights/ConnectionCardsView.swift`
- `app-twoTests/ViewModels/InsightsViewModelTests.swift`
- `app-twoTests/Models/RecordingMoodDisplayTests.swift`

**Modify:**
- `app-two/Models/Recording+MoodDisplay.swift` — M2 mood colors at SSOT; `MoodLevel` color/partner; recolor energy/focus/side-effect tags in `displayTags`.
- `app-two/DesignSystem/Typography.swift` — add `Typography.display`.
- `app-two/DesignSystem/Palette.swift` — keep `warning`; deprecate/retire `energy` single-color (callers migrated).
- `app-two/ViewModels/InsightsViewModel.swift` — add 5 computations + supporting types + `calendarDay(for:)`; remove dead computeds; add preview seed.
- `app-two/Views/InsightsView.swift` — recompose to 5 sections + empty state.
- `app-two/Views/Insights/MoodLegend.swift` — take `[InsightsViewModel.MoodShare]`.

**Delete:**
- `app-two/Views/Insights/InsightsCarousel.swift`, `InsightsCardKind.swift`, `TimeOfDayBars.swift`, `WeeklyBars.swift`, `ActivityPillsGrid.swift`, `MoodPieChart.swift`, `EmotionFrequencyBars.swift`, `InsightsHeaderSection.swift`, `SectionDivider.swift`
- `app-two/Views/Components/CalendarGrid.swift` (only referenced by the carousel — re-grep before deleting)

**Kept (unchanged):** `MonthSelectorScrollView`, `DayDetailSheet`, `ScreenContainer`.

---

## Task 1: Color infrastructure

**Files:** Create `app-two/DesignSystem/SignalLevel.swift` (color helpers section).

- [ ] **Step 1 — `Color(lightHex:darkHex:)` + `contrastingInk`.** In `SignalLevel.swift`:

```swift
import SwiftUI
import UIKit

extension Color {
    /// A dynamic colour that resolves to `darkHex` in dark mode and `lightHex` in light mode.
    /// Used for the focus (graphite) ramp, which inverts between modes.
    init(lightHex: String, darkHex: String) {
        self = Color(uiColor: UIColor { trait in
            UIColor(Color(hex: trait.userInterfaceStyle == .dark ? darkHex : lightHex))
        })
    }

    /// Black or white, whichever reads on `fill` in the given scheme. Resolves dynamic
    /// colours first, so it is correct for the inverting focus ramp.
    /// Sanctioned use of literal black/white — text-on-coloured-fill contrast only.
    static func contrastingInk(for fill: Color, in scheme: ColorScheme) -> Color {
        let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
        let resolved = UIColor(fill).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var white: CGFloat = 0
        resolved.getWhite(&white, alpha: nil)
        return white > 0.6 ? .black : .white
    }
}
```

- [ ] **Step 2 — build** (no dedicated test; exercised by Task 2's tests). Verify the file compiles in the full build at Task 3.

---

## Task 2: M2 mood palette at the SSOT (TDD)

**Files:** Modify `app-two/Models/Recording+MoodDisplay.swift`; Create `app-twoTests/Models/RecordingMoodDisplayTests.swift`.

- [ ] **Step 1 — failing test.** Create `RecordingMoodDisplayTests.swift`:

```swift
import Testing
import SwiftUI
@testable import app_two

@MainActor
struct RecordingMoodDisplayTests {
    private func rec(mood: String?) -> Recording {
        Recording(audioFileName: "t.m4a", mood: mood)
    }

    @Test func moodColorUsesM2Hexes() {
        #expect(rec(mood: "low").moodColor   == Color(hex: "#C2503F"))
        #expect(rec(mood: "flat").moodColor  == Color(hex: "#DE8050"))
        #expect(rec(mood: "okay").moodColor  == Color(hex: "#E5C46A"))
        #expect(rec(mood: "good").moodColor  == Color(hex: "#94C56F"))
        #expect(rec(mood: "great").moodColor == Color(hex: "#4CAF6E"))
    }

    @Test func moodColorUnknownIsSystemGray() {
        #expect(rec(mood: nil).moodColor == Color(.systemGray2))
        #expect(rec(mood: "alert").moodColor == Color(.systemGray2)) // energy word ≠ mood
    }

    @Test func moodLevelColorAndPartnerMatchM2() {
        #expect(MoodLevel.okay.color == Color(hex: "#E5C46A"))
        #expect(MoodLevel.okay.gradientPartner == Color(hex: "#EFD68C"))
        #expect(MoodLevel.great.displayLabel == "Great")
    }
}
```

- [ ] **Step 2 — run, verify it fails** (old coral palette + no `MoodLevel.color`). Run the test target filtered to `RecordingMoodDisplayTests`.

- [ ] **Step 3 — implement.** In `Recording+MoodDisplay.swift`, add a `MoodLevel` extension and rewrite `moodColor` to delegate (single source for the mapping):

```swift
extension MoodLevel {
    /// M2 "Meadow" valence ramp (low→great = red→amber→green). App-wide mood SSOT.
    var color: Color {
        switch self {
        case .low:   return Color(hex: "#C2503F")
        case .flat:  return Color(hex: "#DE8050")
        case .okay:  return Color(hex: "#E5C46A")
        case .good:  return Color(hex: "#94C56F")
        case .great: return Color(hex: "#4CAF6E")
        }
    }
    /// Lighter gradient partner (light end of the fill).
    var gradientPartner: Color {
        switch self {
        case .low:   return Color(hex: "#D4705F")
        case .flat:  return Color(hex: "#EA9D72")
        case .okay:  return Color(hex: "#EFD68C")
        case .good:  return Color(hex: "#AED68C")
        case .great: return Color(hex: "#6BC68A")
        }
    }
    var displayLabel: String {
        switch self {
        case .low: "Low"; case .flat: "Flat"; case .okay: "Okay"; case .good: "Good"; case .great: "Great"
        }
    }
}
```

Replace the `moodColor` body:

```swift
    var moodColor: Color {
        MoodLevel(rawValue: mood?.lowercased() ?? "")?.color ?? Color(.systemGray2)
    }
```

- [ ] **Step 4 — run, verify pass.**
- [ ] **Step 5 — commit:** `feat(insights): migrate mood palette to M2 at the moodColor SSOT`.

---

## Task 3: Energy/Focus ramps + `SignalLevel` protocol + gradient helper

**Files:** Create `app-two/DesignSystem/Palette+Signals.swift`; extend `app-two/DesignSystem/SignalLevel.swift`.

- [ ] **Step 1 — ramps.** `Palette+Signals.swift`:

```swift
import SwiftUI

extension Palette {
    /// E2 "Voltage" energy ramp, sluggish→charged (index 0…4). Static across modes.
    static let energyRamp: [Color] = [
        Color(hex: "#44546E"), Color(hex: "#4E6F94"), Color(hex: "#5889BA"),
        Color(hex: "#63A4E0"), Color(hex: "#79C4FF"),
    ]
    static let energyRampPartner: [Color] = [
        Color(hex: "#5F6F8A"), Color(hex: "#6B8BAE"), Color(hex: "#74A3D2"),
        Color(hex: "#82BCF0"), Color(hex: "#9CD6FF"),
    ]

    /// F2 "Graphite" focus ramp, foggy→lockedIn (index 0…4). Dynamic — inverts in light mode.
    static let focusRamp: [Color] = [
        Color(lightHex: "#D8D8DE", darkHex: "#3A3A3E"),
        Color(lightHex: "#B4B4BC", darkHex: "#58585E"),
        Color(lightHex: "#8A8A94", darkHex: "#7E7E86"),
        Color(lightHex: "#5A5A64", darkHex: "#ABABB5"),
        Color(lightHex: "#26262C", darkHex: "#ECECF4"),
    ]
    static let focusRampPartner: [Color] = [
        Color(lightHex: "#E6E6EA", darkHex: "#4A4A50"),
        Color(lightHex: "#C6C6CE", darkHex: "#6A6A72"),
        Color(lightHex: "#9C9CA6", darkHex: "#92929C"),
        Color(lightHex: "#6E6E78", darkHex: "#C2C2CC"),
        Color(lightHex: "#3A3A42", darkHex: "#FFFFFF"),
    ]
}
```

- [ ] **Step 2 — protocol + conformances + gradient helpers.** Append to `SignalLevel.swift`:

```swift
/// Shared grammar for the three Insights signals. One bead/blob/gauge renders any of them.
protocol SignalLevel {
    var numericValue: Int { get }   // 1…5
    var displayLabel: String { get }
    var color: Color { get }        // base (dark/saturated end of the fill)
    var gradientPartner: Color { get } // lighter end
}

extension SignalLevel {
    /// Standard filled-element gradient: partner (top-leading) → base (bottom-trailing).
    var fillGradient: LinearGradient {
        LinearGradient(colors: [gradientPartner, color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    /// Bubble radial fill (highlight at 32%/28%).
    var bubbleFill: RadialGradient {
        RadialGradient(colors: [gradientPartner, color],
                       center: UnitPoint(x: 0.32, y: 0.28), startRadius: 0, endRadius: 110)
    }
}

extension MoodLevel: SignalLevel {} // color/partner/displayLabel from Recording+MoodDisplay

extension EnergyLevel: SignalLevel {
    var color: Color { Palette.energyRamp[numericValue - 1] }
    var gradientPartner: Color { Palette.energyRampPartner[numericValue - 1] }
    var displayLabel: String { rawValue.capitalized } // sluggish→"Sluggish" … charged→"Charged"
}

extension FocusLevel: SignalLevel {
    var color: Color { Palette.focusRamp[numericValue - 1] }
    var gradientPartner: Color { Palette.focusRampPartner[numericValue - 1] }
    // displayLabel already exists on FocusLevel ("Locked In" etc.)
}
```

- [ ] **Step 3 — full build** (`xcodebuild build …`). Expected: succeeds; confirms Tasks 1–3 compile together.
- [ ] **Step 4 — commit:** `feat(insights): add energy/focus ramps and shared SignalLevel grammar`.

---

## Task 4: `displayTags` palette migration

**Files:** Modify `app-two/Models/Recording+MoodDisplay.swift`, `app-two/DesignSystem/Palette.swift`.

Rationale (spec): energy tags → ramp (colour by actual level); focus tag stops sharing indigo → graphite ramp; side-effect tags → `warning` (orange) so energy no longer shares orange; sleep keeps indigo; meds keep purple.

- [ ] **Step 1 — edit `displayTags`.** Replace the three tag colours:

```swift
        if let energy = energyLevel {
            let lvl = EnergyLevel(rawValue: energy.lowercased())
            tags.append(DisplayTag(id: "energy", label: "\(energy) energy", icon: "bolt.fill",
                                   color: lvl?.color ?? Palette.energyRamp[2]))
        }

        if let focus = focusLevel {
            let lvl = FocusLevel(rawValue: focus.lowercased())
            tags.append(DisplayTag(id: "focus", label: focus, icon: "target",
                                   color: lvl?.color ?? Palette.focusRamp[2]))
        }
```

…and side effects:

```swift
        for (i, effect) in decodedSideEffects.enumerated() {
            tags.append(DisplayTag(id: "se-\(i)", label: effect.capitalized, icon: "bandage.fill", color: Palette.warning))
        }
```

- [ ] **Step 2 — retire `Palette.energy`.** In `Palette.swift` remove `static let energy` (now unused) and update the doc comment. Re-grep `Palette.energy` across `app-two/` first; migrate any stragglers to `Palette.energyRamp[2]` or `Palette.warning` as appropriate.
- [ ] **Step 3 — build.** Expected: no references to `Palette.energy` remain.
- [ ] **Step 4 — commit:** `refactor(tags): recolor energy/focus/side-effect tags off the single orange`.

---

## Task 5: `Typography.display` + `InsightsSectionHeader`

**Files:** Modify `Typography.swift`; Create `app-two/Views/Insights/InsightsSectionHeader.swift`.

- [ ] **Step 1 — typography token.** In `Typography.swift` add under Display:

```swift
    /// Serif display header — Insights section titles only. New York, scales with Dynamic Type.
    static let display: Font = .system(.title, design: .serif, weight: .bold)
```

- [ ] **Step 2 — header view.** `InsightsSectionHeader.swift`:

```swift
import SwiftUI

/// Left-aligned serif section header + optional subtitle. Replaces the centered InsightsHeaderSection.
struct InsightsSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.display)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(Typography.callout)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.section)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
```

- [ ] **Step 3 — build; commit:** `feat(insights): add serif display header`.

---

## ViewModel supporting types (defined once, referenced by Tasks 6–13)

Add to `InsightsViewModel` (nested). `any SignalLevel` is used to erase the three level types into one strip/cell.

```swift
enum SignalKind: String, CaseIterable, Identifiable { case mood, energy, focus
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct MoodShare: Identifiable {
    let id = UUID()
    let level: MoodLevel
    let count: Int
    let fraction: Double        // share of mood-present check-ins
}

struct SignalBead: Identifiable {
    let id = UUID()
    let level: (any SignalLevel)?   // nil → empty/dashed bead
    let recordingID: UUID
    let date: Date
}

struct SignalStrip: Identifiable {
    let id = UUID()
    let kind: SignalKind
    let beads: [SignalBead]
    let summary: String         // "mostly Okay" or "no data"
}

struct SignalAverage: Identifiable {
    let id = UUID()
    let kind: SignalKind
    let fraction: Double        // avg/5, 0 when empty
    let fillLabel: String       // "Okay+", "Steady", "—"
    let caption: String         // "between Okay & Good" / "Steady on average" / "No data yet"
    let floorLevel: (any SignalLevel)?
    let ceilLevel: (any SignalLevel)?
    var isEmpty: Bool { floorLevel == nil }
}

struct RhythmCell: Identifiable { let id = UUID(); let dominant: (any SignalLevel)? }
struct RhythmRow: Identifiable { let id = UUID(); let kind: SignalKind; let cells: [RhythmCell] }

enum ConnectionState {
    case unlocked(runs: [SentenceRun], barFraction: Double, barColors: [Color], barLabel: String, caption: String)
    case gated(copy: String)
}
struct SentenceRun: Identifiable { let id = UUID(); let text: String; let emphasis: Color? }
struct Connection: Identifiable { let id = UUID(); let title: String; let state: ConnectionState }
```

Private level mappers (add once):

```swift
    private func moodLevel(_ r: Recording) -> MoodLevel? { MoodLevel(rawValue: r.mood?.lowercased() ?? "") }
    private func energyLevel(_ r: Recording) -> EnergyLevel? { EnergyLevel(rawValue: r.energyLevel?.lowercased() ?? "") }
    private func focusLevel(_ r: Recording) -> FocusLevel? { FocusLevel(rawValue: r.focusLevel?.lowercased() ?? "") }
    private func level(_ kind: SignalKind, _ r: Recording) -> (any SignalLevel)? {
        switch kind { case .mood: moodLevel(r); case .energy: energyLevel(r); case .focus: focusLevel(r) }
    }
    /// Chronological (oldest→newest) recordings in the current month.
    private var chronoRecordings: [Recording] { monthRecordings.sorted { $0.createdAt < $1.createdAt } }
```

`Date`-bucket helper (reused by rhythm + connections):

```swift
    enum TimeBucket: Int, CaseIterable { case morning, afternoon, evening, late
        var label: String { ["Morning","Afternoon","Evening","Late"][rawValue] }
        static func of(_ date: Date, _ cal: Calendar) -> TimeBucket {
            let h = cal.component(.hour, from: date)
            switch h { case 6..<12: .morning; case 12..<18: .afternoon; case 18..<22: .evening; default: .late }
        }
    }
```

---

## Task 6: `moodShares` (TDD)

**Files:** Modify `InsightsViewModel.swift`; Create/extend `app-twoTests/ViewModels/InsightsViewModelTests.swift`.

Spec: bubble area ∝ mood share; % inside each; mood-present check-ins only.

- [ ] **Step 1 — failing test.** Create `InsightsViewModelTests.swift` with the in-memory store harness (mirror `MoodLibraryViewModelTests`):

```swift
import Foundation
import Testing
import SwiftData
@testable import app_two

@MainActor
struct InsightsViewModelTests {
    let container: ModelContainer
    let context: ModelContext
    let store: RecordingStore
    let month = Date(timeIntervalSince1970: 1_749_000_000) // fixed, mid-2025

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, MedicationEvent.self, AppSettings.self, configurations: config)
        context = container.mainContext
        store = RecordingStore(context: context)
    }

    @discardableResult
    private func add(day: Int = 1, hour: Int = 10, mood: String? = nil, energy: String? = nil,
                     focus: String? = nil, sleepQuality: String? = nil, med: String? = nil) -> Recording {
        var comps = Calendar.current.dateComponents([.year, .month], from: month)
        comps.day = day; comps.hour = hour
        let date = Calendar.current.date(from: comps)!
        let r = Recording(createdAt: date, audioFileName: "r.m4a", mood: mood,
                          energyLevel: energy, focusLevel: focus, sleepQuality: sleepQuality)
        context.insert(r)
        if let med {
            let e = MedicationEvent(name: med, takenAt: date, taken: true, source: .manual)
            context.insert(e); e.recording = r
        }
        try? context.save(); store.loadRecordings()
        return r
    }
    private func vm() -> InsightsViewModel { let v = InsightsViewModel(store: store); v.currentMonth = month; return v }

    @Test func moodSharesCountsOnlyMoodPresent() {
        add(mood: "okay"); add(mood: "okay"); add(mood: "good"); add(energy: "alert") // no mood
        let shares = vm().moodShares
        #expect(shares.reduce(0) { $0 + $1.count } == 3)
        let okay = shares.first { $0.level == .okay }
        #expect(okay?.count == 2)
        #expect(abs((okay?.fraction ?? 0) - 2.0/3.0) < 0.0001)
    }

    @Test func moodSharesEmptyWhenNoMood() { add(energy: "alert"); #expect(vm().moodShares.isEmpty) }
}
```

> Confirm `MedicationEvent` initializer signature (Task ref) — adjust `add(med:)` to the real init.

- [ ] **Step 2 — run, fail.**
- [ ] **Step 3 — implement** in `InsightsViewModel`:

```swift
    var moodShares: [MoodShare] {
        let levels = monthRecordings.compactMap(moodLevel)
        let total = levels.count
        guard total > 0 else { return [] }
        return MoodLevel.allCases.compactMap { lvl in
            let c = levels.filter { $0 == lvl }.count
            guard c > 0 else { return nil }
            return MoodShare(level: lvl, count: c, fraction: Double(c) / Double(total))
        }
        .sorted { $0.count > $1.count }
    }
```

- [ ] **Step 4 — run, pass. Commit:** `feat(insights-vm): mood share breakdown`.

---

## Task 7: `signalStrips` (TDD)

Spec: one bead per check-in chronological; per-strip summary "mostly X"; missing signal → empty bead.

- [ ] **Step 1 — test** (append):

```swift
    @Test func signalStripsAreChronologicalWithEmptyBeads() {
        add(day: 2, mood: "good"); add(day: 1, mood: "okay"); add(day: 3, energy: "alert") // day3 has no mood
        let mood = vm().signalStrips.first { $0.kind == .mood }!
        #expect(mood.beads.count == 3)
        #expect((mood.beads[0].level as? MoodLevel) == .okay)  // day1 first
        #expect((mood.beads[1].level as? MoodLevel) == .good)  // day2
        #expect(mood.beads[2].level == nil)                    // day3 no mood → empty
        #expect(mood.summary.contains("Okay") || mood.summary.contains("Good"))
    }
    @Test func stripSummaryIsModalLabel() {
        add(mood: "okay"); add(mood: "okay"); add(mood: "great")
        #expect(vm().signalStrips.first { $0.kind == .mood }!.summary == "mostly Okay")
    }
```

- [ ] **Step 2 — fail. Step 3 — implement:**

```swift
    var signalStrips: [SignalStrip] {
        let recs = chronoRecordings
        return SignalKind.allCases.map { kind in
            let beads = recs.map { r in SignalBead(level: level(kind, r), recordingID: r.id, date: r.createdAt) }
            let present = beads.compactMap { $0.level }
            let summary: String
            if present.isEmpty { summary = "no data" }
            else {
                let modal = Dictionary(grouping: present, by: { $0.numericValue })
                    .max { a, b in a.value.count != b.value.count ? a.value.count < b.value.count : a.key < b.key }!
                summary = "mostly \(modal.value.first!.displayLabel)"
            }
            return SignalStrip(kind: kind, beads: beads, summary: summary)
        }
    }
```

- [ ] **Step 4 — pass. Commit:** `feat(insights-vm): three-signal bead strips`.

---

## Task 8: `signalAverages` (TDD)

Spec: mean ordinal → fraction (avg/5), fill label "Okay+" on half-steps, caption.

- [ ] **Step 1 — test:**

```swift
    @Test func averageHalfStepGetsPlusLabel() {
        add(mood: "okay"); add(mood: "good") // avg 3.5 → "Okay+", "between Okay & Good"
        let a = vm().signalAverages.first { $0.kind == .mood }!
        #expect(a.fillLabel == "Okay+")
        #expect(a.caption == "between Okay & Good")
        #expect(abs(a.fraction - 0.7) < 0.0001) // 3.5/5
    }
    @Test func averageWholeStepUsesWord() {
        add(energy: "steady"); add(energy: "steady")
        let a = vm().signalAverages.first { $0.kind == .energy }!
        #expect(a.fillLabel == "Steady")
        #expect(a.caption == "Steady on average")
    }
    @Test func averageEmptyWhenNoData() {
        add(mood: "okay")
        let f = vm().signalAverages.first { $0.kind == .focus }!
        #expect(f.isEmpty); #expect(f.fillLabel == "—")
    }
```

- [ ] **Step 2 — fail. Step 3 — implement.** Helper to build a level of a given kind by numeric value:

```swift
    private func levelOfKind(_ kind: SignalKind, value v: Int) -> (any SignalLevel)? {
        let i = max(1, min(5, v))
        switch kind {
        case .mood:   return MoodLevel.allCases[i - 1]
        case .energy: return EnergyLevel.allCases[i - 1]
        case .focus:  return FocusLevel.allCases[i - 1]
        }
    }

    var signalAverages: [SignalAverage] {
        SignalKind.allCases.map { kind in
            let vals = monthRecordings.compactMap { level(kind, $0)?.numericValue }
            guard !vals.isEmpty else {
                return SignalAverage(kind: kind, fraction: 0, fillLabel: "—",
                                     caption: "No data yet", floorLevel: nil, ceilLevel: nil)
            }
            let avg = Double(vals.reduce(0, +)) / Double(vals.count)
            let floorI = max(1, Int(avg.rounded(.down)))
            let frac = avg - Double(floorI)
            let isHalf = frac >= 0.25 && frac < 0.75
            let ceilI = min(5, floorI + 1)
            let floorL = levelOfKind(kind, value: floorI)!
            let ceilL = levelOfKind(kind, value: ceilI)!
            let roundedL = levelOfKind(kind, value: Int(avg.rounded()))!
            let fillLabel = isHalf ? "\(floorL.displayLabel)+" : roundedL.displayLabel
            let caption = isHalf ? "between \(floorL.displayLabel) & \(ceilL.displayLabel)"
                                 : "\(roundedL.displayLabel) on average"
            return SignalAverage(kind: kind, fraction: avg / 5.0, fillLabel: fillLabel,
                                 caption: caption, floorLevel: floorL, ceilLevel: ceilL)
        }
    }
```

- [ ] **Step 4 — pass. Commit:** `feat(insights-vm): per-signal average gauges`.

---

## Task 9: `rhythmMatrix` (TDD)

Spec: dominant level per (signal × time bucket); rows mood/energy/focus; 4 columns.

- [ ] **Step 1 — test:**

```swift
    @Test func rhythmDominantPerBucket() {
        add(hour: 8, mood: "okay"); add(hour: 9, mood: "okay"); add(hour: 9, mood: "great") // morning: okay×2 great×1
        add(hour: 14, mood: "good") // afternoon
        let mood = vm().rhythmMatrix.first { $0.kind == .mood }!
        #expect((mood.cells[0].dominant as? MoodLevel) == .okay)  // morning
        #expect((mood.cells[1].dominant as? MoodLevel) == .good)  // afternoon
        #expect(mood.cells[2].dominant == nil)                    // evening empty
        #expect(mood.cells[3].dominant == nil)                    // late empty
    }
    @Test func rhythmTieBreaksToHigherLevel() {
        add(hour: 8, mood: "okay"); add(hour: 8, mood: "great") // tie 1–1 → higher (great)
        #expect((vm().rhythmMatrix.first { $0.kind == .mood }!.cells[0].dominant as? MoodLevel) == .great)
    }
```

- [ ] **Step 2 — fail. Step 3 — implement:**

```swift
    var rhythmMatrix: [RhythmRow] {
        let recs = monthRecordings
        return SignalKind.allCases.map { kind in
            let cells = TimeBucket.allCases.map { bucket -> RhythmCell in
                let levels = recs
                    .filter { TimeBucket.of($0.createdAt, calendar) == bucket }
                    .compactMap { level(kind, $0) }
                guard !levels.isEmpty else { return RhythmCell(dominant: nil) }
                let dominant = Dictionary(grouping: levels, by: { $0.numericValue })
                    .max { a, b in a.value.count != b.value.count ? a.value.count < b.value.count : a.key < b.key }!
                    .value.first!
                return RhythmCell(dominant: dominant)
            }
            return RhythmRow(kind: kind, cells: cells)
        }
    }
    /// Column headers for the matrix.
    let rhythmColumns = TimeBucket.allCases.map(\.label)
```

- [ ] **Step 4 — pass. Commit:** `feat(insights-vm): daily rhythm matrix`.

---

## Task 10: `connections` (TDD)

Gates (spec): med×focus ≥ 4 medication days; energy×mood ≥ 5 high-energy check-ins; sleep×mood ≥ 3 days each side. Order: med×focus, energy×mood, sleep×mood. Co-occurrence copy only.

- [ ] **Step 1 — tests** (gating boundaries are the critical cases):

```swift
    @Test func medFocusGatedBelowFourDays() {
        for d in 1...3 { add(day: d, focus: "sharp", med: "Concerta") }
        if case .gated = vm().connections[0].state {} else { Issue.record("expected gated med×focus") }
    }
    @Test func medFocusUnlocksAtFourDays() {
        for d in 1...4 { add(day: d, hour: 14, focus: "sharp", med: "Concerta") }
        if case .unlocked(_, let frac, _, _, _) = vm().connections[0].state {
            #expect(abs(frac - 1.0) < 0.0001) // 4/4 sharp-or-better
        } else { Issue.record("expected unlocked med×focus") }
    }
    @Test func energyMoodGatesUnderFiveHighEnergy() {
        for d in 1...4 { add(day: d, energy: "alert", mood: "good") }
        if case .gated = vm().connections[1].state {} else { Issue.record("expected gated energy×mood") }
    }
    @Test func sleepMoodGatesWithoutThreeEachSide() {
        for d in 1...3 { add(day: d, mood: "good", sleepQuality: "good") } // only good-sleep side
        if case .gated = vm().connections[2].state {} else { Issue.record("expected gated sleep×mood") }
    }
```

- [ ] **Step 2 — fail. Step 3 — implement.** Day helpers + three builders:

```swift
    private func distinctDays(_ recs: [Recording]) -> [Date: [Recording]] {
        Dictionary(grouping: recs) { calendar.startOfDay(for: $0.createdAt) }
    }
    private var medColor: Color { Palette.medication }

    var connections: [Connection] { [medFocusConnection, energyMoodConnection, sleepMoodConnection] }

    private var medFocusConnection: Connection {
        let medDays = distinctDays(monthRecordings.filter { !$0.medicationEvents.filter(\.taken).isEmpty })
        let n = medDays.count
        let medName = monthRecordings.flatMap { $0.medicationEvents }.filter(\.taken)
            .map(\.name).mostFrequent ?? "medication"
        guard n >= 4 else {
            return Connection(title: "Medication × focus",
                state: .gated(copy: "Log medication on \(max(1, 4 - n)) more day\(4 - n == 1 ? "" : "s") to unlock how it moves with your focus."))
        }
        // each med day's dominant focus, count Sharp-or-better (≥4)
        let dayFocus: [FocusLevel] = medDays.values.compactMap { recs in
            recs.compactMap { focusLevel($0) }
                .max { $0.numericValue < $1.numericValue } // best focus that day
        }
        let hits = dayFocus.filter { $0.numericValue >= FocusLevel.sharp.numericValue }.count
        let denom = max(1, dayFocus.count)
        let runs: [SentenceRun] = [
            .init(text: "On days you logged ", emphasis: nil),
            .init(text: medName, emphasis: medColor),
            .init(text: ", your focus was ", emphasis: nil),
            .init(text: "Sharp or better", emphasis: FocusLevel.sharp.color),
            .init(text: " \(hits) out of \(denom) times.", emphasis: nil),
        ]
        return Connection(title: "Medication × focus", state: .unlocked(
            runs: runs, barFraction: Double(hits) / Double(denom),
            barColors: [FocusLevel.sharp.color, FocusLevel.lockedIn.color],
            barLabel: "\(Int((Double(hits) / Double(denom) * 100).rounded()))%",
            caption: "\(n) medication day\(n == 1 ? "" : "s") this month · shows together-ness, not cause"))
    }

    private var energyMoodConnection: Connection {
        let highEnergy = monthRecordings.filter { (energyLevel($0)?.numericValue ?? 0) >= EnergyLevel.alert.numericValue }
        let n = highEnergy.count
        guard n >= 5 else {
            return Connection(title: "Energy × mood",
                state: .gated(copy: "Check in on \(5 - n) more high-energy day\(5 - n == 1 ? "" : "s") to unlock how energy moves with mood."))
        }
        let hits = highEnergy.filter { (moodLevel($0)?.numericValue ?? 0) >= MoodLevel.good.numericValue }.count
        let runs: [SentenceRun] = [
            .init(text: "When your energy was ", emphasis: nil),
            .init(text: "Alert or Charged", emphasis: EnergyLevel.alert.color),
            .init(text: ", your mood was ", emphasis: nil),
            .init(text: "Good or Great", emphasis: MoodLevel.great.color),
            .init(text: " \(hits) out of \(n) times.", emphasis: nil),
        ]
        return Connection(title: "Energy × mood", state: .unlocked(
            runs: runs, barFraction: Double(hits) / Double(n),
            barColors: [MoodLevel.good.color, MoodLevel.great.color],
            barLabel: "\(Int((Double(hits) / Double(n) * 100).rounded()))%",
            caption: "\(n) high-energy check-ins this month"))
    }

    private var sleepMoodConnection: Connection {
        func quality(_ r: Recording) -> String? { (r.decodedSleepEvent?.quality ?? r.sleepQuality)?.lowercased() }
        let goodDays = distinctDays(monthRecordings.filter { quality($0) == "good" })
        let poorDays = distinctDays(monthRecordings.filter { ["poor","insomnia"].contains(quality($0) ?? "") })
        let needGood = max(0, 3 - goodDays.count), needPoor = max(0, 3 - poorDays.count)
        guard goodDays.count >= 3 && poorDays.count >= 3 else {
            let more = max(needGood, needPoor)
            return Connection(title: "Sleep × mood",
                state: .gated(copy: "Check in on \(more) more day\(more == 1 ? "" : "s") with sleep noted to unlock this connection."))
        }
        func avgMood(_ days: [Date: [Recording]]) -> Double {
            let vals = days.values.flatMap { $0.compactMap { moodLevel($0)?.numericValue } }
            return vals.isEmpty ? 0 : Double(vals.reduce(0, +)) / Double(vals.count)
        }
        let g = avgMood(goodDays), p = avgMood(poorDays)
        let gL = levelOfKind(.mood, value: Int(g.rounded())) as! MoodLevel
        let pL = levelOfKind(.mood, value: Int(p.rounded())) as! MoodLevel
        let runs: [SentenceRun] = [
            .init(text: "After nights you slept well your mood averaged ", emphasis: nil),
            .init(text: gL.displayLabel, emphasis: gL.color),
            .init(text: "; after poor sleep, ", emphasis: nil),
            .init(text: pL.displayLabel, emphasis: pL.color),
            .init(text: ".", emphasis: nil),
        ]
        return Connection(title: "Sleep × mood", state: .unlocked(
            runs: runs, barFraction: g / 5.0,
            barColors: [gL.gradientPartner, gL.color],
            barLabel: gL.displayLabel,
            caption: "\(goodDays.count) good- vs \(poorDays.count) poor-sleep days · shows together-ness, not cause"))
    }
```

Add a small `Array` helper (in the VM file, file-private):

```swift
private extension Array where Element: Hashable {
    var mostFrequent: Element? {
        Dictionary(grouping: self, by: { $0 }).max { $0.value.count < $1.value.count }?.key
    }
}
```

- [ ] **Step 4 — pass. Commit:** `feat(insights-vm): gated connection cards`.

> NOTE during execution: verify `MedicationEvent` has `.taken` and `source`/init as used; adjust to real API.

---

## Task 11: ViewModel cleanup + `calendarDay(for:)` + preview seed

- [ ] **Step 1 — remove dead members** from `InsightsViewModel`: `MoodBucket`, `FeelingFrequency`, `TimeOfDayBucket`, `WeeklyBucket`, `ActivityCount`, and the computeds `moodBuckets`, `totalCount`, `feelingFrequencies`, `timeOfDayBuckets`, `weeklyBuckets`, `activityCounts`, `calendarDays`, `monthSubtitle`. Keep `CalendarDay`, `availableMonths`, `monthLabel`, `isCurrentMonth`, nav methods, `recording(for:)`, `monthRecordings`.
- [ ] **Step 2 — add day mapper** (bead tap → sheet):

```swift
    func calendarDay(for date: Date) -> CalendarDay {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let recs = store.recordings.filter { $0.createdAt >= start && $0.createdAt < end }
            .sorted { $0.createdAt > $1.createdAt }
        return CalendarDay(date: start, isCurrentMonth: true, recordings: recs)
    }
    var hasAnyData: Bool { !monthRecordings.isEmpty }
```

- [ ] **Step 3 — preview seed.** Add a previews-only factory (used by every new view preview). Place in a new `app-two/Store/InsightsPreviewSupport.swift` guarded by `#if DEBUG`:

```swift
#if DEBUG
import Foundation
import SwiftData

@MainActor
extension InsightsViewModel {
    /// Deterministic in-memory VM with a month of varied mood/energy/focus/sleep/med data for previews.
    static func previewSeeded() -> InsightsViewModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Recording.self, MedicationEvent.self, AppSettings.self, configurations: config)
        let ctx = container.mainContext
        let store = RecordingStore(context: ctx)
        let cal = Calendar.current
        let base = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let rows: [(Int, Int, String?, String?, String?, String?, String?)] = [
            // day, hour, mood, energy, focus, sleepQuality, med
            (1, 9,  "okay",  "steady", "present", "good", "Concerta"),
            (2, 14, "good",  "alert",  "sharp",   nil,    "Concerta"),
            (3, 20, "low",   "tired",  "foggy",   "poor", nil),
            (4, 10, "great", "charged","lockedIn","good", "Concerta"),
            (5, 16, "okay",  "steady", "distracted", nil, "Concerta"),
            (7, 8,  "good",  "alert",  "sharp",   "good", nil),
            (9, 21, "okay",  "tired",  "present", "poor", nil),
            (11,13, "great", "charged","sharp",   "good", "Concerta"),
        ]
        for (d, h, m, e, f, s, med) in rows {
            let date = cal.date(from: DateComponents(year: 2026, month: 6, day: d, hour: h))!
            let r = Recording(createdAt: date, audioFileName: "p.m4a", title: "Check-in",
                              energyLevel: e, focusLevel: f, mood: m, sleepQuality: s)
            ctx.insert(r)
            if let med {
                let ev = MedicationEvent(name: med, takenAt: date, taken: true, source: .manual)
                ctx.insert(ev); ev.recording = r
            }
        }
        try? ctx.save()
        store.loadRecordings()
        let vm = InsightsViewModel(store: store)
        vm.currentMonth = base
        return vm
    }
}
#endif
```

- [ ] **Step 4 — build (app target). Commit:** `refactor(insights-vm): drop dead computeds, add day mapper + preview seed`.

---

## Task 12: `MoodBubbleChart` + `MoodLegend` rewrite

Mockup spec: bubble area ∝ share; largest ~195pt, scaled by √fraction; % label inside (real text, `contrastingInk`); legend = dot+label row below. Bubbles overlap, packed; for N≤5 use a simple deterministic layout.

- [ ] **Step 1 — `MoodLegend.swift`** (rewrite):

```swift
import SwiftUI

struct MoodLegend: View {
    let shares: [InsightsViewModel.MoodShare]
    var body: some View {
        FlowLayoutOrHStack { // simple wrap; or HStack with .fixedSize if small
            ForEach(shares) { s in
                HStack(spacing: Spacing.xs) {
                    Circle().fill(s.level.color).frame(width: 10, height: 10)
                    Text(s.level.displayLabel).font(Typography.caption).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.m)
    }
}
```

> If no wrap layout helper exists, use an `HStack(spacing: Spacing.m)` (≤5 items fit). Verify and keep it simple.

- [ ] **Step 2 — `MoodBubbleChart.swift`.** Area-proportional radii: `r_i = maxR * sqrt(fraction_i / maxFraction)`, `maxR ≈ 97`. Lay out by `ZStack` + `.offset` using a small packing table keyed by index (largest centered, others orbiting). Each bubble: `Circle().fill(level.bubbleFill)`, overlaid `Text("\(pct)%")` with `Color.contrastingInk(for: level.color, in: scheme)`. Container height 250. `accessibilityElement(children: .ignore)` + `accessibilityLabel` summary "Mood breakdown: 60% okay, 25% good, 15% low." Legend below.
- [ ] **Step 3 — light/dark `#Preview`** using `InsightsViewModel.previewSeeded()`.
- [ ] **Step 4 — build. Commit:** `feat(insights): mood bubble breakdown chart`.

---

## Task 13: `SignalStripsView`

Mockup: three strips, gap 22; head = name (bold) + avg (secondary, baseline-aligned); beads row `HStack(spacing:5)`, each bead `height 34, cornerRadius 10, flex equal width`. Filled = `level.fillGradient`; empty = `RoundedRectangle.strokeBorder(Theme.separator, dashed)`. Bead tap → `onTapBead(date)`. 44pt hit target: wrap each bead in a tappable area `.frame(minHeight: 44)` (overlay the visual 34pt bar; or use 44 contentShape). `accessibilityElement(children: .contain)` per strip + label "Mood strip: N check-ins, mostly Okay."

- [ ] **Step 1 — implement** with `onTapBead: (Date) -> Void` callback; the visual bead is 34pt but `.contentShape(Rectangle()).frame(height: 44)` ensures the hit target.
- [ ] **Step 2 — preview. Step 3 — build. Commit:** `feat(insights): three-signal bead strips view`.

---

## Task 14: `SignalAverageGauges`

Mockup: `HStack(spacing:18)`; each gauge = vertical track `height 280, cornerRadius 26, fill Theme... (--empty)`, 5 dashed tick rows overlaid, fill from bottom `height = fraction*track`, gradient `LinearGradient(ceilLevel.gradientPartner → floorLevel.color)`, fill-top label (`fillLabel`, `contrastingInk`), below: bold `kind.title` + secondary `caption`. Empty (`isEmpty`): no fill, track only, label "—". `accessibilityElement(children: .combine)` per gauge "Mood average: Okay+, between Okay and Good."

- [ ] **Step 1 — implement.** Track background = `Theme.cardBackground` (≈ `--empty`). Ticks: `VStack` of 5 `Rectangle().frame(height: 1).foregroundStyle(Theme.separator.opacity(0.4))` with dashed stroke or thin lines spaced via `Spacer`s.
- [ ] **Step 2 — preview (incl. an empty gauge). Step 3 — build. Commit:** `feat(insights): average gauges view`.

---

## Task 15: `DailyRhythmMatrix`

Mockup: column header row offset by the 64pt label gutter; each row = `mlabel(64, bold)` + 4 cells; cell = blob `height 52, cornerRadius 18` (`fillGradient`) or dashed empty, with `mword` (level `displayLabel` or "—") beneath in `Typography.caption`/secondary. Rows mood/energy/focus. 44pt min cell hit (cells aren't tappable per spec, but keep ≥44 visual+label). `accessibilityElement(children: .contain)` + per-row label.

- [ ] **Step 1 — implement** using `viewModel.rhythmMatrix` + `viewModel.rhythmColumns`.
- [ ] **Step 2 — preview. Step 3 — build. Commit:** `feat(insights): daily rhythm matrix view`.

---

## Task 16: `ConnectionCardsView`

Mockup: `VStack(spacing:16)`; unlocked card = `Theme.cardBackground`, cornerRadius 22, padding 20; serif sentence built from `runs` (concatenate `Text`, emphasis runs `.bold().foregroundStyle(run.emphasis)`); a mini bar `height 26, cornerRadius 13`, width = `barFraction` of available, `LinearGradient(barColors)`, inline `barLabel` (`contrastingInk`); caption below (`Typography.caption`/secondary). Gated card = transparent bg, dashed border, secondary serif copy only. `accessibilityElement(children: .combine)` per card; gated cards announce the unlock copy.

Serif sentence:

```swift
private func sentence(_ runs: [InsightsViewModel.SentenceRun]) -> Text {
    runs.reduce(Text("")) { acc, run in
        var t = Text(run.text)
        if let c = run.emphasis { t = t.fontWeight(.bold).foregroundColor(c) }
        return acc + t
    }
    .font(Typography.display.weight... ) // use serif body: .system(.body, design: .serif)
}
```

> Use a serif *body* font (`.system(.body, design: .serif)`) for sentences, not the large display token.

- [ ] **Step 1 — implement.** Bar width via `GeometryReader` or `containerRelativeFrame`. Step 2 — preview (one unlocked, one gated). Step 3 — build. **Commit:** `feat(insights): connection cards view`.

---

## Task 17: Recompose `InsightsView` + empty state

- [ ] **Step 1 — rewrite `InsightsView.body`.** Keep `ScreenContainer`, `MonthSelectorScrollView`, `scrollResetToken`, `.sheet(item: $viewModel.selectedDay)` → `DayDetailSheet`, `navigationDestination`. Compose, each under `InsightsSectionHeader`:

```
MonthSelectorScrollView
if !viewModel.hasAnyData {
    InsightsEmptyState()   // single shared "Check in to see your month"
} else {
    InsightsSectionHeader("Your overall check-in breakdown", subtitle: "\(viewModel.monthRecordings.count) check-ins")
    MoodBubbleChart(shares: viewModel.moodShares)
    InsightsSectionHeader("Your month in three signals", subtitle: "Each bead is one check-in, in order")
    SignalStripsView(strips: viewModel.signalStrips) { date in viewModel.selectedDay = viewModel.calendarDay(for: date) }
    InsightsSectionHeader("Where you averaged", subtitle: "Month average on each 5-step scale")
    SignalAverageGauges(averages: viewModel.signalAverages)
    InsightsSectionHeader("Your daily rhythm", subtitle: "Dominant level by time of day")
    DailyRhythmMatrix(rows: viewModel.rhythmMatrix, columns: viewModel.rhythmColumns)
    InsightsSectionHeader("Connections", subtitle: "How your signals move together")
    ConnectionCardsView(connections: viewModel.connections)
}
```

Sections separated by their own top padding (`Spacing.section` in the header) — no `Divider`/`SectionDivider`. Bottom padding `Spacing.hero`.

- [ ] **Step 2 — `InsightsEmptyState`** (inline or small view): centered, `Theme.textSecondary`, "Check in to see your month" + supporting line. Expose `monthRecordings` (make non-private or add `var checkInCount: Int`). 
- [ ] **Step 3 — build. Commit:** `feat(insights): recompose InsightsView into five-section scroll`.

---

## Task 18: Delete dead components

- [ ] **Step 1 — re-grep** each target for stragglers, then delete:
  `InsightsCarousel, InsightsCardKind, TimeOfDayBars, WeeklyBars, ActivityPillsGrid, MoodPieChart, EmotionFrequencyBars, InsightsHeaderSection, SectionDivider` (all in `Views/Insights/`) and `Views/Components/CalendarGrid.swift`.
  ```
  for f in InsightsCarousel InsightsCardKind TimeOfDayBars WeeklyBars ActivityPillsGrid MoodPieChart EmotionFrequencyBars InsightsHeaderSection SectionDivider CalendarGrid; do
    grep -rn "$f" app-two --include=*.swift | grep -v "Views/Insights/$f.swift\|Views/Components/$f.swift"; done
  ```
  Only delete a file when its sole remaining references are within files also being deleted.
- [ ] **Step 2 — `git rm`** the files; build. Expected: app + tests compile with no missing-symbol errors.
- [ ] **Step 3 — commit:** `chore(insights): remove carousel + legacy chart components`.

---

## Task 19: Final verification

- [ ] **Step 1 — full test suite:** `xcodebuild test …` (env-stripped, target sim). Expected: all green incl. new `InsightsViewModelTests` + `RecordingMoodDisplayTests`. Fix the 11 mood-color/other assertions if any reference old hexes.
- [ ] **Step 2 — preview sanity:** confirm every new view has working light + dark `#Preview` (focus ramp must invert).
- [ ] **Step 3 — a11y/CVD notes:** record in the final message that the pre-TestFlight VoiceOver + grayscale pass is still required (spec §Accessibility); verify level words appear as text beside every colour and counts are present.
- [ ] **Step 4 — final commit** if anything outstanding; summarize.

---

## Self-review (spec coverage)

- §Screen structure 1–5 → Tasks 12–16 + 17. ✅
- §Palette M2/E2/F2 + gradient rule → Tasks 1–3. ✅
- §Typography display + delete InsightsHeaderSection → Tasks 5, 18. ✅
- §Empty & edge states (dashed ≠ foggy, whole-month empty, missing signal = no bead) → bead/cell/gate rendering (13–16) + Task 17 empty state + VM nil-handling (7,9). ✅
- §Component inventory new/deleted/kept → Tasks 12–16 (new), 18 (deleted), kept untouched. ✅
- §ViewModel additions (signalSequences→signalStrips, signalAverages, rhythmMatrix, connections) → Tasks 7–10. ✅
- §Accessibility (real-text headers/%, contain+summary, level words+counts, 44pt) → headers (5), each view's a11y step. Grayscale pass flagged (19). ✅
- §Testing (4 VM computations incl. gates + missing-signal; mood-color M2; light/dark previews) → Tasks 6–10 tests, Task 2, view previews. ✅
- §Open items (uncommitted moodColor; branch) → resolved in Decisions. ✅

**Type-consistency:** `MoodShare`, `SignalBead/Strip`, `SignalAverage` (`floorLevel`/`ceilLevel`/`isEmpty`), `RhythmRow/Cell`, `Connection`/`ConnectionState`/`SentenceRun`, `SignalKind`, `TimeBucket`, helpers `level(_:_:)`/`levelOfKind(_:value:)`/`calendarDay(for:)`/`rhythmColumns`/`hasAnyData` — names used consistently across Tasks 6–17. `contrastingInk(for:in:)` and `fillGradient`/`bubbleFill` used by all views.
</content>
</invoke>
