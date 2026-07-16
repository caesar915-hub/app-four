<!-- Created: 2026-07-16 18:55 (WEST) · Updated: 2026-07-16 18:55 (WEST) -->
# Implementation Plan: New Look Check-in + Insights Re-skin (a04–a07)

**Branch**: `feat/036-newlook-checkin-insights` (stacked on feat/035) | **Date**: 2026-07-16 | **Spec**: [spec.md](spec.md)

## Technical Context

Swift 6.2 / SwiftUI, iOS 26. No storage/schema surface. Tests: Swift Testing. Grounding: Figma metadata + screenshots + `get_variable_defs` for all four frames (this session), two Explore code maps (CheckIn + Insights) with file:line evidence, canvas pixel samples for the ring gradient.

**Token authority (verified 1:1)**: `accent/selection #54b492`=`NewLook.selection` · `accent/medication #7e5ca8`=`Palette.medication` · inks/hairline/tintNeutral/card/screen = `NewLook.*` · `radius/card 20`=`Radius.newLookCard` · `radius/pill`=Capsule · `Tiimo/Shadow/Card`=`newLookCardShadow()` · `Tiimo/Display/Title-24`=`Typography.text(24,.bold,relativeTo:.title2)` · `Tiimo/Label/Caps-13`=`Typography.text(13,.semibold)+tracking(1.3)+uppercase` (existing patterns). **One new token**: `NewLook.selectionSoft` = light `#96C19F` (canvas ring bottom sample), dark derived — ring-gradient end only, documented like `medicationFillEnd`.

## Constitution Check (v1.2.0)
All PASS/N-A. I: no new views — existing screens restyled, canvas is the mockup (HTML-mockup gate satisfied by the owner-approved Figma screens). X: the one logic change (gauge level passed explicitly, FR-010) is test-first; dead-code deletion (FR-011) removes untested-unreachable UI only. IV: one additive token + no new abstractions. V: one revertable feature branch. Others N-A (no data/services/extraction).

## Architecture

### US1 — CheckIn (a04–a06), files: `CheckInView.swift`, `CrescentRing.swift`, `Metrics.swift`, `NewLook.swift`
1. **Ring** (`CrescentRing.swift:32-34`): AngularGradient stops `meadowGreen/meadowAmber/meadowGreen` → `selection/selectionSoft/selection` (same 270° geometry, spin/breathe/RM gates untouched).
2. **Hub** (`CheckInView.swift:193-233`): `hubOption` gains `NewLook.card` capsule fill + `newLookCardShadow()`; content hugs (drop the fixed 220 width; `Spacing.xl` horizontal padding, min height `Metrics.minTapTarget`). `speakButton` → `NewLook.selection` capsule + `NewLook.onSelection` label/mic + card shadow (meadow gradient + amber shadow deleted).
3. **Prompt card** (a05): `recordingHeader` wraps in `.newLookCard()`; `promptProgressBar` fill `Theme.accent.opacity(0.5)` → `NewLook.selection`, track stays `tintNeutral`-family; `Metrics.CheckIn.promptBarHeight` 3→4 (canvas); `promptDots` selected → `NewLook.selection`. `heroPrompt` question → `Typography.text(24,.bold,relativeTo:.title2)`; idle title likewise (canvas Title-24).
4. **Saved** (a06): disc `Theme.meadowGradient`→`NewLook.selection` (shadow → soft card shadow); Done: replace `.buttonStyle(.primary)` (shared meadow style — NOT touched) with a local full-width `NewLook.selection` capsule + `onSelection` label, `maxWidth .infinity`, min height 50, bottom-pinned as today.
5. **Recovery** (no canvas): "Try again" meadow capsule → `NewLook.inkPrimary` capsule + `onInk` label (stop-button grammar).
6. Med bar/tab bar: untouched (`ScreenContainer` params unchanged).

### US2 — Insights (a07), files: `InsightsView.swift`, `MonthSelectorScrollView.swift`, `MoodLegend.swift`, `SignalAverageGauges.swift`, `ConnectionCardsView.swift`, `SignalStripsView.swift`, `InsightsViewModel(+Signals).swift`; DELETE `DayDetailSheet.swift`
1. **Scroll host rewrite** (`InsightsView.swift:101-136`): GeometryReader + `page(height:)` + `.scrollTargetLayout/.paging` + `.scrollPosition(id:)` + `activeSectionID` + `headerOpacity` dimming + tab-change reset DELETED. New: plain `ScrollView { VStack(spacing: Spacing.l) { titleBlock; monthChips; breakdownCard; signalsCard; averagesCard; rhythmCard; connectionsBlock } }` + existing `.edgeFadeMask`. `scrollable:false` stays (own ScrollView, Calendar pattern).
2. **Cards**: each section wraps `.newLookCard()`; in-card headers = `Typography.headline` + `Typography.caption` subtitle (`InsightsSectionHeader` serif component deleted if it becomes unreferenced).
3. **Chips**: month chips → `newLookChip(selected:)` grammar; legend chips → white capsule + hairline + level dot + label + (count).
4. **Gauges** (FR-010, test-first): `SignalAverage` gains `level: Int` computed in the VM (`Int(avg)` — same integer the label logic uses); `SignalAverageGauges` consumes it for fill + glyph, deleting the `Int(fraction*5)` re-derivations. RED: a new `InsightsViewModelTests` case pinning `level` at a boundary average (e.g. avg 3.21 → level 3 while `fraction*5` truncation could yield 3.0499…→3 vs rounded glyph 3 — pin equality of label word and level).
5. **Connections**: `MiniBar` fill `Theme.accent` → `Palette.medication`; gated card gains `NewLook.card` fill under the dashed hairline (flat, no shadow).
6. **Dead code** (FR-011): delete `viewModel.selectedDay`, the `.sheet(item:)` wiring, `calendarDay(for:)`, `DayDetailSheet.swift`, and `SignalStripsView.onBeadTap`. Keep `signalStrips` + its 3 tests.

## What NOT to do
- Don't touch `Buttons.swift` `.primary` (meadow — used by other flows) — Done gets a local style.
- Don't change prompt copy/schedule (VM tests pin them) or any VM numbers beyond the additive `level`.
- Don't restyle `MedicationLogSheet`/`TextTextCheckInComposer` — already New Look.
- Don't introduce per-screen hexes: only `selectionSoft` enters the token file.

## Execution order
RED gauge-level test → GREEN VM field → CheckIn re-skin → Insights scroll rewrite + cards → chips/gauges/connections restyle → dead-code deletion → `swiftc -parse` + full-grep gates (SC-002) → docs → owner device QA (quickstart) → adversarial review → PR.
