<!-- Created: 2026-07-18 20:01 (WEST) · Updated: 2026-07-18 20:01 (WEST) -->
# Contract — iOS Grouped-Table Grammar (visual contract for converted screens)

Every converted list screen (a02-b, a03-b, a08-b) MUST satisfy this contract; reviewers test against it literally. Values follow iOS inset-grouped conventions; where Apple varies by OS version, the value here is the contract. Non-list screens adopt §5–§8 only.

## 1 · Group anatomy
- Container: `surface/groupContainer` fill, **radius 10** (`radius/control`), **no shadow, no stroke** (exception: none — the gated-card hairline pattern is retired on list screens).
- Screen gutter: **16** (`spacing/l`) both sides; groups span full content width (358 on the 390 frame).
- Between groups: **24** (`spacing/xxl`); before a major section change: **32** (`spacing/section`).
- Caption header: uppercase, 13pt, `role/caption`, positioned **outside** the container, 16 leading inset, 8 below to container top.
- Footnote: 13pt `role/caption`, outside, 8 above from container bottom, sentence case.

## 2 · Row anatomy
- Min height **44** (also the touch floor — FR-018/rank-7); vertical padding scales with content.
- Horizontal insets: 16 leading / 16 trailing inside the container.
- Separator: `separator/hairline`, 0.5–1px, **inset to align with the text leading edge** (not full-bleed); no separator after the last row.
- Row kinds and their contracts: value rows (label left `ink/primary`, value right `role/caption`), toggle rows (system switch, `role/action` on), disclosure rows (chevron 13–17pt `role/caption`), selection rows (checkmark `role/action` + optional `role/selectionTint` bg), destructive rows (centered `role/destructive`).

## 3 · Controls
- Toggles: system-style switch, on = `role/action`. Never brand green.
- Multi-option (≤4 options): one `Control/Segmented`; detached pill rows are banned on list screens.
- Steppers/pickers: native idiom or disclosure to a picker sheet — no custom chip grids on list screens (a03's grids become selection rows or flow into wrap layouts with ≥44pt targets).

## 4 · Navigation
- a02, a08: **large-title** nav; title collapses inline on scroll (canvas shows the large state). Back affordance: native chevron permitted (old DESIGN.md no-back ruling is non-gating).
- a03 (modal): **sheet bar** — inline centered title, `Cancel` leading, `Save` trailing (`role/action` when enabled). Large titles banned in sheets (FR-005 corrected).

## 5 · Color roles (all screens)
- One role per color per context (SC-002). `role/action` = act/on. Selection = checkmark/neutral tint only. Mood ramp = data marks only, never chrome. Medication purple = medication identity only (audio player uses neutral controls — rank-16).
- Caption/secondary text ≥ **4.5:1** on its surface (FR-019); no waiver carry-over.

## 6 · Chrome (all screens)
- `Chrome/StatusBar` identical on all 8 frames (FR-010).
- `Chrome/MedBar` on a01/a02/a07/a08 only (research D3): pinned under status bar, thinner than a row (~36pt), tinted (not `surface/groupContainer`), never shadowed — must not read as content (FR-009).

## 7 · Typography roles (canvas = Inter stand-in)
- Group caption 13 uppercase · row label 17 regular · row value 17 (`role/caption`) · footnote 13 · large title 34 bold · sheet title 17 semibold. One card/group title role — the rank-9 drift (SB-17 vs eyebrow vs SB-15 vs Bold-24 as interchangeable leads) is disallowed.

## 8 · Retained-card surface (non-list screens only — FR-017)
- Radius 20 (`radius/card`), shadowless or single soft shadow ≤ the old two-layer (pilot decides once, then uniform), never used for settings/detail lists; content inside follows §5 color roles and §2 touch floors.

## Acceptance
A converted screen passes when every checkbox in quickstart.md §Contract-check (derived 1:1 from this file) is checked and no content from the original is missing (SC-005).
