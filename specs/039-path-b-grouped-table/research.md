<!-- Created: 2026-07-18 20:01 (WEST) · Updated: 2026-07-18 20:01 (WEST) -->
# Research — Path B Grouped-Table Redesign (Phase 0)

Resolves the six plan-level decisions the clarify session deferred (2026-07-18). Grounding sources: `design-database/tokens-variables.csv` (live variable inventory), `design-database/perceptual-audit.csv` (findings), the 2026-07-18 audit workflow (re-usable), and the clarified spec.

## D1 — Where do the semantic color roles and spacing tiers live?

**Decision**: **Hybrid.** New Figma variable collection **`iOS Semantic`** for the color *roles* (action/on-state `#34C759`, selection-neutral, caption `#6C6C70`, destructive `#D54037` aliased, status); **spacing reuses Squirl Tokens' existing `spacing/*` FLOAT scale** (4/8/12/16/20/24/32/40 — already defined, currently ~0 uses per `tokens-variables.csv` L46–53); container radius reuses `radius/control = 10`.

**Rationale**: Role tokens are a *new semantic layer* — putting them in Tiimo Colors would mix two systems and tempt re-pointing 992 bound paints mid-redesign. A clean collection makes the pilot reversible and maps 1:1 to the future SwiftUI semantic colors. The Squirl spacing FLOATs are exactly the tier scale the spec needs and are sitting unused — reusing them avoids a duplicate scale (the audit's own R23-style drift lesson).

**Alternatives considered**: extend Tiimo Colors (rejected: entangles legacy + new, hard to revert); all-new collection incl. spacing (rejected: duplicates an existing identical scale).

## D2 — Conversion in place, beside, or on a new page?

**Decision**: **Build beside on Screens v3** — each Path-B frame is created next to its original, named `a0N-b`, starting with `a02-b`. Originals are deleted only after full-set acceptance.

**Rationale**: The gate rule is *iterate until pass* with owner side-by-side judgment — the comparison surface must live on one page at one zoom. The backup page stays frozen (FR-014) as the disaster-recovery reference, not the review surface. In-place editing would destroy the comparison during iteration; a new page splits review across pages for no benefit.

**Alternatives considered**: in-place (rejected: no side-by-side during iterate-until-pass); new "Screens v4" page (rejected: review friction, page proliferation).

## D3 — Which frames render the medication bar?

**Decision**: **The frames that show it today — a01, a02, a07, a08 — keep it** (dose-on-board state), restyled once as the new pinned-chrome component; a04–a06 (capture flow) remain without it. SC-007 is read as *"consistently styled across every frame that displays it."*

**Rationale**: The bar's presence is app logic (dose on board), not per-screen styling choice; adding it to check-in frames would change information, violating FR-015 (conversion changes grammar, not content). The audit's complaint (rank-6) was styling — it reads as a content card — not placement.

**Alternatives considered**: all-8 literal SC-007 (rejected: fabricates state on capture screens); pilot-only (rejected: leaves the chrome unvalidated on long screens).

## D4 — Dark-mode authoring scope

**Decision**: **Light frames only; every new `iOS Semantic` variable is authored with both Light and Dark values at creation.** Dark *frames* are deferred to the SwiftUI spec.

**Rationale**: The R28 lesson — Tiimo shipped 0/26 dark values and the gap had to be backfilled. Authoring dark values at variable-creation time costs minutes and keeps the system dark-ready; authoring dark *frames* doubles canvas work for a deliverable the pilot gate doesn't judge. System-green and system-gray roles have canonical Apple dark counterparts (e.g. `#34C759` → `#30D158`), so values are mechanical, not design work.

**Alternatives considered**: dark frames for the pilot (rejected: doubles pilot iteration cost); defer dark entirely (rejected: recreates R28 debt knowingly).

## D5 — SC-004 chart-vocabulary strictness (a07)

**Decision**: **One primary mark family + one part-to-whole exception.** All signal-over-time/comparison sections use a single bar-family mark (glyph-annotated bars allowed — glyphs stay as *labels*, not as the data mark); part-to-whole composition (the breakdown) may use a stacked bar or donut — never a third idiom, and never overlapping bubbles (explicitly banned by FR-011).

**Rationale**: Matches the audit's own recommendation ("commit to 1–2 marks"); pure single-family would force part-to-whole into bars-only, which is workable but reads worse for a 5-way composition. The exact art stays a pilot-phase exploration; the *criterion* is fixed now so SC-004 is testable: count distinct mark families on a07 ≤ 2, with family #2 used only for part-to-whole.

**Alternatives considered**: strictly one family (rejected: fights the composition chart); decide-after-exploration (rejected: leaves SC-004 unmeasurable).

## D6 — Review & acceptance procedure

**Decision**: Two-stage, both owner-gated.
1. **Pilot gate (a02-b)**: 4-lens agent re-audit scoped to the pilot frame (same workflow as 2026-07-18) → fix findings → **owner side-by-side judgment** (a02-b vs a02 vs backup, per quickstart). Iterate until owner passes it. Agents advise; the owner is the gate.
2. **Full acceptance (all 8)**: `design-database` re-extraction of the converted set + full 4-lens re-audit → SC-001–SC-005/SC-007/SC-008 checked against it → owner final sign-off. DESIGN.md is then updated *from* the outcome (per the non-gating ruling) and the originals are removed from v3.

**Rationale**: Mirrors the project's proven QA shape (agent review advises, owner gates); makes every SC mechanically checkable against the same harness that produced the baseline numbers.

**Alternatives considered**: agent-only gate (rejected: owner explicitly gates design in this project); owner-only (rejected: loses the measurable SC checks the spec commits to).

## Resolved-unknowns summary

| # | Unknown | Resolution |
|---|---------|-----------|
| D1 | Variable home | New `iOS Semantic` color collection + reuse Squirl `spacing/*` + `radius/control` |
| D2 | Page mechanics | Build `a0N-b` beside originals on v3; delete originals at full acceptance |
| D3 | Med-bar frames | a01/a02/a07/a08 (today's state), one pinned-chrome component |
| D4 | Dark scope | Light frames; dual-mode values on every new variable |
| D5 | Chart strictness | ≤2 mark families; #2 only for part-to-whole; bubbles banned |
| D6 | Acceptance | Pilot: agent audit + owner side-by-side, iterate-until-pass · Full: re-extraction + 4-lens re-audit + owner |
