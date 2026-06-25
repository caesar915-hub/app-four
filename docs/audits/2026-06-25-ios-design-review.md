# iOS Design Review (Lens C) — app-four

**Date:** 2026-06-25 · **Branch:** feat/nlp-multilang-demo · **Target:** iOS 26.5, iPhone 17 sim
**Rubric:** `ios-design-review` 10 dimensions (Apple HIG + [DESIGN.md](../../DESIGN.md)), scored 0-10 with "what makes it a 10".
**Companion:** static architecture/quality audit in [2026-06-25-views-audit.md](2026-06-25-views-audit.md).

## Method & honest limits

The skill's native transport (gstack `DebugBridge` + ios-qa daemon) isn't wired into app-four, and XcodeBuildMCP's tools weren't reachable this session; a CLI `xcodebuild` was blocked by a `safe.bareRepository` git-config quirk in the SwiftPM cache. **Capture was done via the `xcode` MCP's `RenderPreview`** (Xcode.app's resolved package graph), rendering each screen's SwiftUI `#Preview` to real pixels, including **Dark** and **Dynamic Type AX5** variant overrides.

What this **can't** assess (flagged, not silently dropped):
- **Populated data screens.** The screen-level previews seed an empty store, so all three tabs render their *empty states*. The data-rich timeline (`DayCard` populated) and Insights analytics (charts the static audit flagged for perf) did not render — only their empty/placeholder variants.
- **`ExtractionReviewView` has no `#Preview`** — the densest screen could not be captured at all. Recommend adding one.
- **Motion / animation** (dimension 7) and **real loading states** (part of dimension 5) — not observable from static snapshots.
- A real-device pass is still owed for true-hardware contrast and haptics.

Captured: CheckIn (Light + Dark), Calendar (empty), Insights (empty), Settings, DayCard (empty day), TimelineChip @ AX5.

---

## Headline

**The visual language is genuinely strong and distinctly *not* AI-slop** — Fraunces display + DM Sans body, a custom "Paper & Pollen" palette, hand-drawn Canvas glyphs, generous on-grid spacing, exemplary native `Form` on Settings, and dark mode that's clearly designed rather than auto-derived. The empty states across all three tabs are warm and well-formed (icon + heading + next-step guidance).

**One real defect, confirmed in pixels:** at Dynamic Type **AX5**, `TimelineChip`'s labels ("Happy", "5h sleep", "Taken Concerta 36mg") stay frozen at 12pt — they don't scale at all. This is the static audit's **M11** ([TimelineChip.swift:25](../../app-four/Views/Components/TimelineChip.swift#L25), `.font(.system(size: 12))`) verified visually. A low-vision user gets unreadable medication labels — the highest-leverage fix.

---

## Dimension scores (aggregate across captured screens)

| # | Dimension | Score | Notes / what makes it a 10 |
|---|---|---|---|
| 1 | Typography hierarchy | **9** | Fraunces display vs DM Sans body/caption, consistent and legible. Already near-ideal. |
| 2 | Spacing rhythm | **9** | Airy, on the 4/8pt grid; safe-area respected. No magic paddings spotted. |
| 3 | Color hierarchy | **8** | Meadow-gradient primary = clear highest-contrast action; ghost secondaries; medication purple distinct; dark mode adapts well. →10: verify the muted **subtitle/secondary text contrast in dark** (looked borderline for WCAG AA body text). |
| 4 | Touch targets | **9** | Primary/secondary buttons and toggles read ≥44pt. →10: confirm the calendar day cells and the `June 2026 >` month control hit 44pt. |
| 5 | Loading / empty / error | **8** | Empty states excellent and consistent across 3 tabs. →10: **not verifiable here** — confirm loading (transcription/summarization) and error states have the same intentionality (the static audit found `ProcessingViewModel`'s state machine is unwired, so a real in-progress indicator may be missing). |
| 6 | Accessibility | **5** | Strong baseline (labeled icon buttons, decorative glyphs hidden, Reduce-Motion guards per static audit) **dragged down by the confirmed AX5 frozen-font defect** on `TimelineChip`. →10: fix M11, then re-score; spot-check other `.font(.system(size:))` on user text. |
| 7 | Animation discipline | **n/a** | Not assessable from snapshots. Static audit found `Motion.swift` defines 2 disciplined curves (0.3/0.4s) and Reduce-Motion guards — promising; needs a live pass. |
| 8 | iOS idiom alignment | **8** | Native `Form`/grouped list, `NavigationStack`, system sheets. →10: migrate the legacy `.tabItem`+`.tag` tab bar to the modern `Tab(value:)` builder (static audit **M8**) and fix the Calendar-sheet `NavigationStack` bug (static **🔴**) so the detail toolbar renders. |
| 9 | Information density | **9** | Intentionally calm and uncluttered; no horizontal scroll. The dense `ExtractionReviewView` couldn't be captured — re-score once it has a preview. |
| 10 | AI-slop check | **10** | Distinctive, opinionated aesthetic; custom glyphs; real domain copy. No stock layouts, no cargo-cult Material, no lorem ipsum. A genuine strength. |

**Overall (captured surface): ~8.0/10**, with accessibility the one soft spot and a clear path to 9+.

---

## Per-screen

- **CheckIn (hero)** — 9. Fraunces "Ready when you are.", meadow crescent, gradient primary + two ghost actions. Calm, confident. Minor: the incomplete-circle crescent reads faintly like a loading spinner at rest; intentional per DESIGN.md, but worth a glance.
- **Calendar (empty)** — 8. Clean week strip, today filled black, future days dimmed; warm empty state. Minor HIG nit: single-letter weekday header `M T W T F S S` is ambiguous (Tue/Thu, Sat/Sun) — acceptable and standard, but `T`/`T` can momentarily confuse.
- **Insights (empty)** — 8. Eyebrow + underline, friendly "Check in to see your month." Populated analytics not assessable here.
- **Settings** — 9. Exemplary: grouped inset cards, eyebrow section headers, custom glyph row-icons, green accent values/toggles, helper subtext. Reference-quality native form.
- **DayCard (empty day)** — 8. Foldable card, dashed empty mood disc, "No check-ins this day. That's alright." Populated timeline (with chips) not assessable here.
- **TimelineChip @ AX5** — **3**. Frozen 12pt at max Dynamic Type. The defect.
- **CheckIn (Dark)** — 8. White title holds contrast, gradient glows on near-black, secondaries get hairline borders. Watch subtitle contrast.

---

## Biggest-leverage fixes (visual)

1. **Fix the AX5 frozen font** — `TimelineChip.swift:25` → `.font(Typography.label)`. Single line; lifts Accessibility 5→~8 and unblocks medication-label legibility for low-vision users. (= static **M11**.)
2. **Verify dark-mode secondary-text contrast** against WCAG AA (4.5:1 body) — the muted subtitle on near-black looked borderline.
3. **Add a `#Preview` to `ExtractionReviewView`** (and seed a populated-day preview for `DayCard`/Insights) so the dense + data-rich screens are reviewable — both visually and in future automated passes.
4. **Confirm real loading/error states** for transcription/summarization are as intentional as the empty states (ties to the static audit's unwired `ProcessingViewModel.state`).
5. Mechanical idiom polish already in the static report: `Tab(value:)` migration (M8) and the Calendar-sheet `NavigationStack` fix (🔴).

## Net

Design quality is a strength, not a liability — the work to do is **accessibility (one confirmed defect) and preview/coverage plumbing**, not a visual overhaul. Re-run this review after M11 lands and after `ExtractionReviewView`/populated previews exist, ideally on real hardware for contrast + motion.
