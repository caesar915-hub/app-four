# Insights Snap-Scroll Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Insights view snap to each section (Daylio-style), with the month selector pinned and the active section's heading at full emphasis while the next heading peeks in dimmed.

**Architecture:** Drive `InsightsView` through `ScreenContainer(scrollable: false)` so the month selector is pinned outside scrolling. Below it, own an inner vertical `ScrollView` whose 5 section units are snap targets via `.scrollTargetLayout()` + `.scrollTargetBehavior(.viewAligned)`. Track the snapped-to-top section with `.scrollPosition(id:)`; every non-active heading renders at reduced opacity, producing the dimmed peek. Tab-reselect scroll-to-top is driven by setting the bound section id. No new files — this is a refactor of one view.

**Tech Stack:** SwiftUI (iOS 26.4+), existing DesignSystem tokens (`Spacing`, `Motion`, `Theme`), `ScreenContainer`, `edgeFadeMask`. Verification via `xcodebuild` + iOS Simulator (XcodeBuildMCP / `ios-debugger-agent` skill).

**Spec:** [2026-06-12-insights-snap-scroll-spec.md](2026-06-12-insights-snap-scroll-spec.md)

---

## Source spec → task mapping

| Spec decision | Implemented by |
|---|---|
| Snap per section, variable height | Task 2 — `.scrollTargetLayout()` + `.viewAligned`, one `.id()` per section |
| Tall sections free-scroll, snap at boundaries | Task 2 — `.viewAligned` default `limitBehavior` (`.automatic`) allows resting inside tall content; verified Task 3 |
| Dimmed next-title peek, active = full | Task 2 — `.scrollPosition(id:)` + `headerOpacity()` |
| No page dots | Omitted by design (nothing to build) |
| Pinned top chrome | Task 2 — `ScreenContainer(scrollable: false)` + selector outside inner scroll |
| Content = existing sections, unchanged | Task 2 — section bodies copied verbatim from current code |
| Tab-reselect returns to top | Task 2 — `onChange(of: selectedTab)` sets `activeSectionID = .breakdown` |

---

## File structure

- **Modify only:** `app-two/Views/InsightsView.swift` — full rewrite of the view (body + section builders). No other files change. No section content views, VM, tests, or `ScreenContainer` are touched.

---

## Task 1: Baseline build (confirm clean starting state)

**Files:** none (verification only)

- [ ] **Step 1: Build the current project to confirm a green baseline**

Run:
```bash
cd /Users/caesargrey/Projects/app-two
env -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_SYSTEM -u GIT_CONFIG_COUNT \
  xcodebuild -project app-two.xcodeproj -scheme app-two \
  -destination 'platform=iOS Simulator,id=667B75F8-4C75-4A14-ACE1-D5C46F3CBC0D' \
  build 2>&1 | tail -5
```
Expected: ends with `** BUILD SUCCEEDED **`.

If SPM resolution fails with a git-config error, list and unset any remaining injected vars first:
```bash
env | grep '^GIT_CONFIG_' || echo "none"
```
Then add `-u <VAR>` for each one shown and re-run the build.

- [ ] **Step 2: Do not commit** — nothing changed. Proceed only if the baseline is green. If it is red for unrelated reasons, STOP and report; do not start the refactor on a broken tree.

---

## Task 2: Rewrite InsightsView — pinned selector, snapping sections, dimmed peek

**Files:**
- Modify (full rewrite): `app-two/Views/InsightsView.swift`

This replaces the entire file. The section *bodies* (charts, paddings, subtitles) are copied verbatim from the current implementation — only the surrounding structure changes:
- `ScreenContainer(scrollable: false, path: $path)` instead of the scrollable default (keep `path: $path` — the `DayDetailSheet` navigates via `path.append`).
- Month selector pinned above the inner `ScrollView`.
- Each section wrapped in its own `VStack` with a stable `.id(SectionID.…)` so it is one snap target; the enclosing `VStack` gets `.scrollTargetLayout()`.
- `.scrollTargetBehavior(.viewAligned)` + `.scrollPosition(id: $activeSectionID, anchor: .top)` on the inner scroll.
- `edgeFadeMask(top: 0, bottom: 36)` re-applied to the inner scroll (parity with `ScreenContainer`'s scrollable branch).
- Each heading dimmed unless its section is active; opacity change animated with `Motion.snappy`, suppressed under Reduce Motion.
- `scrollResetToken` removed (dead once we own the scroll); tab-reselect resets by setting `activeSectionID = .breakdown`.

- [ ] **Step 1: Replace the entire contents of `app-two/Views/InsightsView.swift` with:**

```swift
import SwiftUI

struct InsightsView: View {
    @Binding var selectedTab: Tab
    @State private var viewModel: InsightsViewModel
    @State private var path = NavigationPath()
    @State private var activeSectionID: SectionID? = .breakdown
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let store: RecordingStore

    private enum SectionID: Hashable {
        case breakdown, signals, averages, rhythm, connections
    }

    init(store: RecordingStore, selectedTab: Binding<Tab>) {
        self.store = store
        _viewModel = State(wrappedValue: InsightsViewModel(store: store))
        _selectedTab = selectedTab
    }

    var body: some View {
        ScreenContainer(title: "", scrollable: false, path: $path) {
            VStack(spacing: 0) {
                MonthSelectorScrollView(
                    currentMonth: $viewModel.currentMonth,
                    availableMonths: viewModel.availableMonths
                )
                .padding(.vertical, Spacing.s)

                if viewModel.hasAnyData {
                    sectionsScroll
                } else {
                    emptyState
                    Spacer(minLength: 0)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let recording = viewModel.recording(for: id) {
                    RecordingDetailView(recording: recording, store: store, services: services)
                }
            }
        }
        .trackScreen("InsightsView")
        .sheet(item: $viewModel.selectedDay) { day in
            DayDetailSheet(day: day) { id in path.append(id) }
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == .insights else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                activeSectionID = .breakdown
            }
        }
    }

    // MARK: - Snapping scroll

    private var sectionsScroll: some View {
        ScrollView {
            VStack(spacing: 0) {
                breakdownSection
                signalsSection
                averagesSection
                rhythmSection
                connectionsSection
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $activeSectionID, anchor: .top)
        .edgeFadeMask(top: 0, bottom: 36)
    }

    /// Active heading at full emphasis; every other heading (incl. the peeking
    /// next one) dimmed. 0.4 ≈ the dimmed peek in the reference video.
    private func headerOpacity(_ id: SectionID) -> Double {
        activeSectionID == id ? 1.0 : 0.4
    }

    private var headerAnimation: Animation? {
        reduceMotion ? nil : Motion.snappy
    }

    // MARK: - Sections

    @ViewBuilder
    private var breakdownSection: some View {
        let count = viewModel.monthRecordings.count
        let subtitle = "\(count) check-in\(count == 1 ? "" : "s")"
        VStack(spacing: 0) {
            InsightsSectionHeader(title: "Your overall check-in breakdown", subtitle: subtitle)
                .opacity(headerOpacity(.breakdown))
            if !viewModel.moodShares.isEmpty {
                MoodBubbleChart(shares: viewModel.moodShares)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.s)
                MoodLegend(shares: viewModel.moodShares)
                    .padding(.top, Spacing.xs)
            }
        }
        .id(SectionID.breakdown)
        .animation(headerAnimation, value: activeSectionID)
    }

    private var signalsSection: some View {
        VStack(spacing: 0) {
            InsightsSectionHeader(
                title: "Your month in three signals",
                subtitle: "Each bead is one check-in day, in order"
            )
            .opacity(headerOpacity(.signals))
            SignalStripsView(strips: viewModel.signalStrips) { date in
                viewModel.selectedDay = viewModel.calendarDay(for: date)
            }
            .padding(.top, Spacing.s)
        }
        .id(SectionID.signals)
        .animation(headerAnimation, value: activeSectionID)
    }

    private var averagesSection: some View {
        VStack(spacing: 0) {
            InsightsSectionHeader(title: "Where you averaged")
                .opacity(headerOpacity(.averages))
            SignalAverageGauges(averages: viewModel.signalAverages)
                .padding(.top, Spacing.s)
        }
        .id(SectionID.averages)
        .animation(headerAnimation, value: activeSectionID)
    }

    private var rhythmSection: some View {
        VStack(spacing: 0) {
            InsightsSectionHeader(
                title: "Your daily rhythm",
                subtitle: "Dominant level per signal by time of day"
            )
            .opacity(headerOpacity(.rhythm))
            DailyRhythmMatrix(matrix: viewModel.rhythmMatrix)
                .padding(.top, Spacing.s)
        }
        .id(SectionID.rhythm)
        .animation(headerAnimation, value: activeSectionID)
    }

    private var connectionsSection: some View {
        VStack(spacing: 0) {
            InsightsSectionHeader(
                title: "Connections",
                subtitle: "Patterns across signals — 3 or more days to unlock"
            )
            .opacity(headerOpacity(.connections))
            ConnectionCardsView(connections: viewModel.connections)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.hero)
        }
        .id(SectionID.connections)
        .animation(headerAnimation, value: activeSectionID)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary)
            Text("Check in to see your month")
                .font(Typography.headline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.bottom, Spacing.hero)
    }
}

#Preview {
    InsightsView(store: .preview, selectedTab: .constant(.insights))
        .withPreviewEnvironment()
}
```

- [ ] **Step 2: Build**

Run:
```bash
cd /Users/caesargrey/Projects/app-two
env -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_SYSTEM -u GIT_CONFIG_COUNT \
  xcodebuild -project app-two.xcodeproj -scheme app-two \
  -destination 'platform=iOS Simulator,id=667B75F8-4C75-4A14-ACE1-D5C46F3CBC0D' \
  build 2>&1 | tail -15
```
Expected: `** BUILD SUCCEEDED **`.

Common failure → fix:
- `value of type ... has no member 'scrollPosition(id:anchor:)'` → none expected on iOS 26; if seen, drop `anchor: .top` (default top behavior is acceptable).
- `Cannot find 'edgeFadeMask'` → ensure no typo; it is a `View` extension in `EdgeFadeMask.swift`.
- Missing-argument error on `ScreenContainer` → confirm the call is `ScreenContainer(title: "", scrollable: false, path: $path)`.

- [ ] **Step 3: Commit**

```bash
cd /Users/caesargrey/Projects/app-two
git add app-two/Views/InsightsView.swift
git commit -m "feat(insights): snap-to-section scroll with pinned selector + dimmed peek

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: On-simulator visual verification (snapping, peek, tall-section, reset)

**Files:** none (verification only)

There is no automated test for scroll-snap behavior. Verify on the simulator using the `ios-debugger-agent` skill (XcodeBuildMCP): build & launch `app-two` on iPhone 17 Pro (id `667B75F8-4C75-4A14-ACE1-D5C46F3CBC0D`), seed/enable the on-device debug dummy data if needed so Insights has ≥3 check-in days, open the **Insights** tab, then screenshot while scrolling.

- [ ] **Step 1: Launch and navigate**

Build+run via XcodeBuildMCP, boot the sim, open the app, tap the **Insights** tab. Capture a screenshot of the initial state.

- [ ] **Step 2: Acceptance checks** — confirm each, screenshot as evidence:

1. **Pinned selector:** the month strip (e.g. `MAY / JUN 2026`) stays fixed while content scrolls beneath it.
2. **Snap to section:** a slow drag + release never rests mid-section — it settles with a section heading at the same top anchor every time.
3. **Dimmed peek:** at rest, the active heading is full-opacity; the next heading is visible at the bottom edge, clearly dimmed (~0.4).
4. **Active swap on scroll:** scrolling to the next section promotes its heading to full opacity and dims the previous one (animated, not instant — unless Reduce Motion).
5. **Tall section:** if any section exceeds the viewport, you can scroll freely *inside* it; it snaps only when you reach its top/bottom. (If no section is tall with current data, note this as not-exercised.)
6. **Tab-reselect reset:** scroll down, switch to another tab, return to Insights → it animates back to the first section.
7. **Med bar + tab bar:** the floating medication capsule sits above the pinned selector (no overlap); content fades into the bottom tab bar.

- [ ] **Step 3: Tune if needed**

- Peek too faint/strong → adjust the `0.4` in `headerOpacity(_:)`.
- Heading sits too high/low under the selector → adjust the header's `.padding(.top, Spacing.section)` is shared; if Insights specifically needs less, add `.padding(.top, …)` to `sectionsScroll`'s `VStack` rather than editing the shared header.
- If `.viewAligned` fights free-scroll inside a tall section, change to `.viewAligned(limitBehavior: .alwaysByOne)` and re-verify check #5.

If you tuned anything, rebuild (Task 2 Step 2 command) and commit:
```bash
cd /Users/caesargrey/Projects/app-two
git add app-two/Views/InsightsView.swift
git commit -m "fix(insights): tune snap anchor/peek opacity

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
If nothing changed, skip the commit.

---

## Task 4: Accessibility verification

**Files:** none (verification only; tune `InsightsView.swift` if a check fails)

The dimmed headers must stay reachable and ordered for assistive tech (opacity does not remove them from the accessibility tree). Verify with the `ios-debugger-agent` skill on the same simulator.

- [ ] **Step 1: VoiceOver** — enable VoiceOver, swipe through Insights. Confirm: every section heading is announced as a header (trait `.isHeader`, already set in `InsightsSectionHeader`), in top-to-bottom order, including the dimmed/peeking one. Charts/content remain reachable.

- [ ] **Step 2: Dynamic Type** — set an accessibility text size (e.g. AX3). Confirm headings wrap (not truncate) and sections still snap cleanly; the anchor stays consistent.

- [ ] **Step 3: Reduce Motion** — enable Reduce Motion. Confirm the heading dim/undim changes instantly (no fade) while snapping still works. This is driven by `headerAnimation` returning `nil`.

- [ ] **Step 4: Commit any fixes**

If a check required a code change:
```bash
cd /Users/caesargrey/Projects/app-two
git add app-two/Views/InsightsView.swift
git commit -m "fix(insights): a11y for snap-scroll headers

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
Otherwise skip.

---

## Self-review notes (author)

- **Spec coverage:** all locked decisions mapped in the table above; page-dots intentionally absent.
- **Type consistency:** `SectionID` cases (`breakdown/signals/averages/rhythm/connections`) are used identically in `headerOpacity`, each section's `.id()`, and `activeSectionID`'s default/reset.
- **No behavior change to content:** section bodies (charts, subtitles, paddings, `selectedDay` tap, `bottom Spacing.hero`) are byte-for-byte the originals; only the wrapper/structure changed.
- **Preserved contracts:** `path: $path` still passed to `ScreenContainer` (navigation from `DayDetailSheet` depends on it); `.trackScreen`, `.sheet`, `navigationDestination` unchanged. `scrollResetToken` intentionally removed (it only existed to drive `ScreenContainer`'s now-unused scroll).
- **Risk:** `.viewAligned` interaction with over-tall sections is the one behavior that can't be proven without the simulator → explicit acceptance check (Task 3, #5) + fallback (`limitBehavior: .alwaysByOne`).
```

