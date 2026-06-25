# Phase 0 Research: Medication Bar Consistency

**Feature**: `002-medication-bar-consistency` | **Branch**: `feat/feedback-specs` | **Date**: 2026-06-15
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)
**Provenance**: `docs/superpowers/2026-06-15-screen-recording-feedback-plan.md` §1.5, §2.1, §4.3, §4.4 and "Decisions — resolved 2026-06-15".

> **Scope note**: the fade-under-the-bar item (§1.3) was removed from this feature — it is covered by the separate calendar header scroll-fade work (`fix/calendar-header-scroll-fade`). The decisions below are the tap target, the below-bar spacing, and the recording-detail presentation.

All three decisions below were either resolved by the owner on 2026-06-15 or follow directly from the verified codebase. Each cites the file:line confirmed by opening the real file under `app-four/`.

---

## D1 — Tap target: `contentShape` on the row label (§2.1)

**Decision**: Add `.contentShape(Rectangle())` to the dose-row button label so the full `maxWidth: .infinity × height` frame is hit-testable.

**Why**: [`MedicationBarView.doseRow`](../../app-four/Views/Components/MedicationBarView.swift) (~L56–92) is a `.plain` `Button` (L90) whose label is a `ZStack` (L60) containing a **partial-width** progress `Rectangle` (`.scaleEffect(x: progress…)`, L61–64) and an `HStack` of two `Text`s pinned left/right (L66–78). The row frame is `maxWidth: .infinity` (L81) but with no `.contentShape`, SwiftUI hit-tests only the opaque sub-views — so the transparent gap between the labels and beyond the progress fill is dead. A `contentShape(Rectangle())` makes the whole frame the hit region. The confirmation dialog (L25–44) already provides log/delete/cancel — only the hit area is wrong.

**Alternatives rejected**:
- *Add a transparent background fill (`Color.clear`) behind the ZStack* — works, but `contentShape` is the idiomatic, intent-revealing API for "the whole frame is tappable" and reads better than a sentinel clear layer.
- *Expand the progress Rectangle to full width and dim the unfilled portion* — changes the visual design (the partial fill is the elapsed-progress signal) to fix a hit-testing problem; wrong layer.

---

## D2 — Spacing: one shared "below-the-bar" token (§1.5)

**Decision**: Define a single spacing token for "gap below the medication bar" and apply it on every screen that shows the bar.

**Why**: The gap is set independently per screen today: [`CalendarLibraryView.timelineList`](../../app-four/Views/Library/CalendarLibraryView.swift) uses `.padding(.top, Spacing.m)` (L74) while the bar's own insets live in [`MedicationBarOverlay`](../../app-four/DesignSystem/MedicationBarOverlay.swift) (`.padding(.top, Spacing.s)` L21–22). Independent values drift, which is the owner's "always align — something like this space" complaint. One token in the existing `Spacing` design-system enum gives a single source of truth (FR-008, SC-005).

**Alternatives rejected**:
- *Per-screen padding left as-is* — the status quo that produced the inconsistency.
- *Bake the gap into the overlay only* — the gap is between the bar and the *content*, which different screens own; a shared token applied at each content root is clearer than coupling content layout into the overlay.

---

## D3 — Recording detail as a sheet (§4.3, §4.4)

> **⚠️ SUPERSEDED 2026-06-26** (branch `feat/calendar-detail-push`). The owner reversed D3 back to a **right-push**, unifying Calendar with the Insights entry point. D3's "chevron displaces the bar" worry no longer holds: the med bar sits *below* the nav bar via `safeAreaInset(edge: .top)`, and the nav bar already carries the date title + `⋯` Delete (spec-022); the bar's Y is a stack-wide inset that does not move across the push, whether the back chevron is hidden (this branch's MVP) or shown as a standard control (spec-023's complementary change). The bar travels with the push transition rather than the sheet's fixed placement; pinning it outside the stack is a deferred follow-up. See DEVLOG 2026-06-26.

**Decision**: Present the recording detail as a **sheet** (swipe-down dismiss, no back chevron), not a nav push. The bar stays fixed at the top.

**Why**: [`RecordingDetailView`](../../app-four/Views/RecordingDetailView.swift) is pushed via `navigationDestination(for: UUID.self)` in [`CalendarLibraryView`](../../app-four/Views/Library/CalendarLibraryView.swift) (L50–53) — mirrored in [`InsightsView`](../../app-four/Views/InsightsView.swift) (L38) — so the **system** back button renders in the nav bar *above* the `.medicationBarOverlay()` ([`RecordingDetailView`](../../app-four/Views/RecordingDetailView.swift) L36). That is the chevron sitting on the bar, and the nav bar is also what displaces the bar on the pushed screen. The bar's placement uses `safeAreaInset(edge: .top)` ([`MedicationBarOverlay`](../../app-four/DesignSystem/MedicationBarOverlay.swift) L18): with no nav bar there is no displacement. The owner confirmed (2026-06-15) "present the detail as a sheet." A sheet removes the chevron entirely and keeps the bar fixed, resolving both §4.3 and the root cause of §4.4 in one move.

**Open implementation detail (resolved at implementation, not a spec ambiguity)**: whether a standard `.sheet(item:)` suffices or `.fullScreenCover` is needed so the bar is visible *inside* the detail. The plan notes both; the deciding factor is whether the bar must remain rendered over the detail content. Either way the back chevron is gone and the bar does not move on the presenting screen. The selection/deep-link path that resolves a recording by `UUID` must be re-pointed from `navigationDestination` to the sheet's `item` binding and verified.

**Alternatives rejected**:
- *Keep the push, hide the system back button (`.navigationBarBackButtonHidden`) + custom control below the bar* — the plan lists this as option 2; rejected by the owner in favour of the sheet because it leaves the nav-bar chrome that still risks displacing the bar and adds a bespoke control.
- *Keep the push as-is* — the reported defect (chevron over the bar, bar moves).

---

## Cross-cutting rationale

Per the feedback plan's "Cross-cutting themes," items §1.5, §2.1, §4.3, §4.4 all serve one requirement — "the bar is a single, fixed, always-tappable element … never overlaps, never moves, never half-responds." Consolidating them into one feature (rather than isolated fixes) lets the fixed-position work (D3, top-chrome standardisation), the tap target (D1), and the spacing (D2) be validated together against one consistent bar, and keeps the change set one revertable slice (Principle V). The related fade-under-the-bar treatment (§1.3) is handled separately by `fix/calendar-header-scroll-fade`.
