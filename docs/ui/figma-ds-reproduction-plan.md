<!-- Created: 2026-06-30 18:22 (WEST) · Updated: 2026-06-30 18:56 (WEST) -->
# Plan — Code-derived Figma Design System + Calendar-flow reproduction (Squirl / app-four)

> Produced via the [deep-plan-review](../../.claude/skills/deep-plan-review/SKILL.md) flow (5 review agents). Linear: project **UX/UI Figma** (`squirl-dev`). Working copy: `~/.claude/plans/how-will-you-design-compressed-koala.md`.

## Context
Two deliverables in the **Squil-Design** Figma file, both with **Swift code as the single source of truth**:
1. **A Figma Design System** mirrored from the `SquirlDesignSystem` Swift package (foundations, glyph language, components).
2. **Hi-fi reproductions of 10 Calendar-flow views** that consume it.

No SwiftUI→Figma/`.sketch` auto-conversion exists; we rebuild natively via MCP, every value sourced from code. Device frame: **iPhone 16, 393×852pt** (content 361, 16pt margins).

### Tooling decision (chosen: `figma-bridge`)
A canonical code→Figma skill family is cached locally (`figma-generate-library`, `figma-swiftui`, `figma-use`, …) and would produce a **natively-linked** system (real Variables w/ modes + iOS code-syntax, Styles, Components/variants, editable vector glyphs) — but it needs the **`use_figma`** tool (official Figma MCP `mcp.figma.com`), which is **not installed**. app-four's only Figma MCP is **`figma-bridge`** (`@gethopp/figma-mcp-bridge`), already connected. **Owner chose to proceed on `figma-bridge` now.**
- Consequence stated plainly: the no-native-Variables/Styles/Components/vector-paths limits below are **`figma-bridge` limits, not Figma limits**. The output is therefore a faithful **picture** of a design system (visual fidelity high; system not natively *linked*). We build it **migration-ready** (naming + `tokens.json` shaped to the canonical conventions) so it can later be promoted to the native toolchain (or Tokens Studio) with minimal rework.
- DESIGN.md prose is partly stale; **code wins** (verified: Energy/Focus ramps, Card "12pt"→16, Opacity "0.16"→0.24, med-bar `.glassEffect`-in-a-comment, pencil-removed claim are all stale).

---

## Hard constraints (figma-bridge schemas — VERIFIED)
1. **Only 4 create_* tools** (`create_frame/text/shape/image`); **no** `create_variable/style/page/component`, **no JS exec**. ⇒ one **Page 1**, spatial sections; "components" are master frames duplicated as copies (drift becomes a review target — see Verify); tokens delivered as a specimen + `tokens.json` (optional Tokens Studio promotion).
2. **`create_shape` = RECTANGLE | ELLIPSE | LINE only — no vector paths; `create_image` REJECTS SVG** (verified Phase 0: "Image type is unsupported" for both data URI and file path — PNG only). ⇒ glyphs are authored as SVG, **rasterized to transparent PNG@3x via `cairosvg`** (`DYLD_LIBRARY_PATH=/opt/homebrew/lib python3 -m cairosvg in.svg -o out.png -s 3`), then imported via `create_image`. Pipeline proven; all 3 risk features (aperture `stroke-dasharray`, capsule two-tone left-mask, sprout variable stroke widths) survive. Consequence: glyphs are **flat raster images, not recolorable vectors** (acceptable for v1).
3. **`set_auto_layout` supports `layoutWrap:WRAP` + `counterAxisSpacing` + per-side padding + `itemSpacing`** ⇒ VStack/HStack + FlowLayout map (width-pinning still required, M4). Use `set_gradient_fill` (meadow gradient), `set_effects` DROP_SHADOW (card/button shadow), `set_stroke_properties` (aperture dashes, dividers), full `set_text_properties`.
4. **One WebSocket ⇒ serialize ALL calls** — even read-only `get_node`/`get_screenshot` queue on the one socket; "parallel" review means parallel *analysis*, serial *tool calls*. Keep the Figma tab **foreground** or it drops.
5. **Fonts (verified Phase 0):** **SF Pro = AVAILABLE** (read-back confirms, no substitution). **SF Mono = UNAVAILABLE** in this Figma file → mono roles (timer/duration/mono12) render in **Roboto Mono** as a stand-in, every mono node annotated "SF Mono on device"; `tokens.json` keeps the true family "SF Mono". Flagged to owner.

---

## Phase 0 — Discovery, capability spike & gap analysis (blocking)
- **Gap analysis (print before any writes):** list every code↔DESIGN.md conflict + resolution (ramps, Card radius, Opacity, glassEffect, pencil) → feeds the Deviations artifact.
- **Capability/SVG spike (blocking exit criteria):** prove `create_image` renders an SVG data URI at final sizes, AND that the **3 features most likely to silently drop** survive (Penpot's toolchain drops `stroke-dasharray` — real precedent): **(1) aperture dashed outer ring `[3,3]`, (2) capsule left-half mask + two-tone fill, (3) sprout variable stroke widths.** `get_node`/screenshot-verify each. Any drop ⇒ **PNG@3x fallback for that glyph is mandatory before Phase 3.**
- **Font availability:** confirm SF Pro/SF Mono selectable in Figma; if absent, flag typography-fidelity risk to owner now.
- Confirm `set_auto_layout` WRAP break-points, `set_effects` shadow, `set_gradient_fill`.

**OUTCOME (executed 2026-06-30, Sonnet agent) — GO-WITH-CHANGES:** SVG import blocked → PNG@3x via `cairosvg` (proven; all features survive). SF Mono unavailable → Roboto Mono stand-in (annotated). SF Pro available; `set_auto_layout` WRAP, `set_effects` DROP_SHADOW, `set_gradient_fill` LINEAR all PASS. All 6 deviations confirmed (incl. DESIGN.md "card 18" vs `Radius.card=16`). Test nodes cleaned up.

## Phase 1 — Token manifest FROM Swift (mechanical, gated)
Regex parsing is rejected (values are computed; stale doc comments would poison it).
- **1a Golden table** (below) read from code with `file:line`; **line-number re-verify gate** (grep each token at Phase 1 start AND Phase 4 — package is active).
- **1b `tokens.json` via a mechanical gate** — preferred: a compiled-Swift dump importing `SquirlDesignSystem` that prints resolved values (evaluates `min()`, `.opacity()`, ramps, glyph formulas at all 5 levels). *If the SPM build is infeasible in the automation sandbox (gitconfig issue, memory `spm-resolve-sandbox-gitconfig`) and can't be run via the owner toolchain/`dangerouslyDisableSandbox`, the accepted equivalent is a **re-grep script** that extracts each token directly from the Swift sources and **diffs against the golden table, failing on any mismatch**.* Either way the gate is mechanical, never eyeball; the golden table is the cross-check, not the source. Never hand-author silently.
- **headerMoodBadge/badgeTint "unused" gate:** grep `app-four/Views/` for usage; if used, the DayCard repro changes (unverified assumption).
- Glyph SVGs generated by the engine evaluating the formulas per level.

### `tokens.json` schema (migration-ready: slash-paths + iOS code-syntax + adapts flag)
```
{ "color": { "bg/primary": {"light":"#F6F1E7","dark":"#14130F","adapts":true,"ios":"Color.bgPrimary"}, ... },
  "mood":  { "base":[5],"partner":[5],"wordColor":{"light":[5],"dark":[5]},"onColor":"#1C1C1E",
             "blockTint":"base@0.24","badgeTint":"base@0.50" },
  "energy":{ "base":[5],"partner":[5],"adapts":false }, "focus":{ "base":[5],"partner":[5],"adapts":false },
  "type": { "title": {"family":"SF Pro","size":22,"weight":"semibold","dynamic":".title2"}, ... },
  "textStyle": { "cardEyebrow":{"base":"label","uppercase":true,"tracking":0.7} },
  "spacing":{name→px}, "radius":{...}, "opacity":{...}, "metrics":{...},
  "shadow": { "card":{...}, "button":{"color":"meadowAmber","opacity":0.34,"radius":12,"y":5} },
  "glyph": { "sprout":{"canvas":[24,26],"perLevel":[{lift,fill,...}×5],"paths":{...}}, ... } }
```

### Golden table (verified this session)
**Foundation (adapts):** bg `#F6F1E7`/`#14130F` · card `#FCF8EF`/`#1E1C16` · surface2 `#EFE8D8`/`#272419` · textPrimary `#221E16`/`#F3EEE0` · textSecondary `#7A7361`/`#9A917C` · separator/cardStroke `#E3DAC7`/`#322E22` · accent `#B8842A`/`#D4A24A` · meadowGreen `#5F8A4C`/`#6E9A58` · meadowAmber `#E0A33A`/`#E8B255` · danger `#B5503A`/`#CF6A52` · medication `#7E5CA8`/`#9277BE` · sleepIndigo `#5566A6`(fixed) · warning `#C2772E`/`#D98A3E`. Card shadow `#221E16`/`#000000`@6% r10 y3.
**Mood:** base `#DA7A2A·#EDA94A·#9FCB79·#5FB36E·#2E8B57` · partner `#EA9248·#FDC06C·#B9DB9C·#7EC38A·#459B6B` · wordColor-L `#8E470F·#8A5600·#41691F·#2C6B3B·#1E5C38` · wordColor-D `#E89A5A·#EDA94A·#B7D897·#79C98E·#57C98A` · onColor `#1C1C1E` · blockTint base@.24 · badgeTint base@.50.
**Energy(fixed):** base `#7C6E2E·#A89236·#D2BB40·#EEDA4C·#FCEE64` · partner `#8C7F44·#B8A450·#E2CD5F·#FEEC6E·#FFF482`. **Focus(fixed):** base `#44546E·#4E6F94·#5889BA·#63A4E0·#79C4FF` · partner `#5C697E·#6985A4·#77A0CA·#85BDF0·#96D1FF`.
**Type (13, SF):** display28sb`.title1`·largeTitle34b·title22sb`.title2`·dayCardDate16sb`.subheadline`·headline16sb·subheadline14med·body16reg·callout15reg·caption12reg`.caption1`·label12med(**plain; UPPER+0.7 is `cardEyebrow`**)·timer22med mono·duration12reg mono·mono12 12reg mono. In-row mood17sb, time13mono.
**Spacing(name→px):** xs4·s8·m12·l16·xl20·xxl24·section32·hero40·ringStroke3.3. **Radius:** card16·control10·button16·chip15. **Opacity:** deEmphasis.34·moodBlock.24·moodBadge.50.
**Metrics:** timeBead36·headerMoodBadge42*·summarySignal15·rowMoodText17·rowTime13·rowSignal12·rowHeadTop7·dayHeaderGlyph40·crescent300·savedDisc78·savedCheck32·IconSize32/48/72. *(headerMoodBadge/badgeTint currently unused — verify via grep gate.)*
**Glyph formulas (→SVG):** Sprout `lift=.66+l*.068`,`fill=min(1,.42+l*.145)`, crown top11(L1-3)/9(L4-5), notch≥L3, dot L5, stem1.5@.6/crown1.3 · Bolt `lift=.6+l*.08`,`fill=min(1,.35+l*.15)`,`stroke=.9+l*.16`, 6-pt round · Aperture outer `op=.3+l*.12`(dash`[3,3]`≤L2/solid>2), middle `op=.4+l*.11`≥L2, sharp r3.3@.92≥L4, core `op=.5+l*.1` r=`(l-1)*.85`≥L3 · Bed frame1.7/pillow1.4r0.8 `#5566A6` · Capsule two-tone .22/.5+left-mask, stroke2, seam`1.6×capH*.66`@.8.

## Naming grammar + state ledger
- **Node names (scriptable for get_node checks):** `Token/color/bg-primary`, `Token/type/title`, `Cmp/TagTag`, `Cmp/DayCard-folded`, `Screen/01-Calendar-Week`, `Glyph/aperture-3`. Specimen swatches + master layers use slash-paths matching `tokens.json` keys → clean Tokens-Studio/`use_figma` migration later.
- **State ledger:** scratchpad `dsb-state.json` mapping logical key→`figma-bridge` nodeId, re-read each turn (build spans many calls; survives socket drop / context reset).

---

## Part A — Figma Design System (built from `tokens.json`)
Section order mirrors a standard DS file: **Cover → Foundations → Components** (then SCREENS).
- **DS/Cover** — title + provenance + Paper & Pollen principles + Deviations list.
- **DS/Foundations:** Color (all foundation + Palette + **all four** mood tables + energy/focus base+partner, light/dark, labeled hex), Typography (specimen per role incl. `duration`; `cardEyebrow` as its own style; **family pinned SF**), Spacing·Radius·Opacity (scale bars name→px), Elevation·Motion·Metrics (real card + button shadow; motion documented; metrics table w/ unused flagged).
- **DS/Iconography — 18-asset glyph inventory** (sprout×5, bolt×5, aperture×5, bed, capsule, EmptySignalGlyph) each with per-asset accept status, rendered at the **actual sizes used** (12/15/30/40pt); encoding legend (shape+hue+fill).
- **DS/Components** — masters (each annotated): `Card`, `PrimaryButton`(+pressed.9, shadow amber@.34 r12 y5), `SecondaryButton`(+pressed.85), `Chip-topic`, `Chip-filter`, `TagTag`(TagFlowView capsule, color@.13, glyph-or-SF — **detail cards use this**), `SegPill`(r10), `DosePill`(Capsule), `MedGridPill`, `StatusPill`(4), `DoseTrack`(**4 states**: kicking in/active/wearing off/worn off), `SignalGlyph`(+Empty), `GlyphRampPicker`, `dateBox`, `selectedMedCard`, `sheetNav`.

## Part B — The 10 views (consume Part A; absolute source paths, lines re-verify)
**Screens (393×852):** 1 **Calendar-week** (`app-four/Views/Library/CalendarLibraryView.swift`,`.../Components/CalendarHeaderView.swift`,`.../CalendarDayCell.swift`): pinned header(month`headline`+chevron, weekday caps, week row gap4)+divider+`LazyVStack(12)` folded DayCards, 16h/12top/24bot, fade32; selected=filled primary circle≤40+6pt dot. 2 **Calendar-month** (full grid, chevron rotated). 3 **Calendar-empty** (header+illustration+copy, top hero40). 4 **Med-bar overlay** (`app-four/DesignSystem/MedicationBarOverlay.swift` safeAreaInset 16h/8top + `.../Components/MedicationBarView.swift`): bar=**`.card(12)` NOT glass**; dose row 28pt glyph+name`subheadline`+state`label`purple+`DoseTrack`8pt+sub`mono12`. 5 **Recording detail** (`app-four/Views/RecordingDetailView.swift`): `VStack(16)` title22sb+meta mono12 → signal row(glyphs@30, xl=20) → **4 ADHDSummarySection cards** (`.../Components/ADHDSummarySection.swift`: Medications[if≠∅], Sleep`#5566A6`(bed glyph, moon.fill SF fallback—glyph wins), Emotions`heart.fill`accent, Side Effects`bandage.fill`warning; each `.card()`; tags via **TagTag**) → transcript card(expandable+StatusPill) → audio card → **Delete**(danger full-width). Nav: date title + **pencil 30×30 circle**→Edit *(code wins vs DESIGN.md)*. 6 **Edit** (`app-four/Views/ExtractionReviewView.swift`, `.large`): 8 fields (When 2 dateBoxes · Mood/Energy/Focus GlyphRampPicker+synonym · Sleep segPills+presets+custom · Medications selectedMedCard+DosePill+MedGridPill · Emotions/Side-effects Chip-filter); Cancel/Save + bottom PrimaryButton. 7 **Log Dose** (`app-four/Views/Components/MedicationLogSheet.swift`): sheetNav + sections Medication/Dose(onset"≈XX min")/Effect Duration/Taken At (cards r16).
**Component-showcase (w361):** 8 **DayCard-folded** (`.../Components/DayCard.swift`+`FoldedDayCardHeader.swift`): HStack(12) 40pt **dayHeaderGlyph** + VStack(4)[title"Mood·Weekday"dayCardDate, mood-word=**wordColor**; summary FlowLayout(**8**) glyph15+caption | empty copy] + chevron(0°); pad16h/12v, bg blockTint(base@24%)|clear, r16. 9 **DayCard-unfolded-single** (`.../Components/TimelineRow.swift`): header(chevron180°)+block(16h/12top/16bot) one row: TimelineBead 36 (disc fill = mood **badgeTint** = base@50%)+1pt connector+content VStack(8) top7: L1 mood17sb(**wordColor**)+time13mono+chevron.right; L2 energy/focus glyph12+caption; L3 FlowLayout(**12**) meds(purple sb)+sleep(indigo); L4 FlowLayout(**12**) feelings+side-effects secondary cap4(+N). 10 **DayCard-unfolded-multi** (≥3 rows; non-last connector+32pt bottom; last omits).

### FlowLayout strategy (M4) — width-pinned
Per instance, pin container width + Figma `WRAP` with exact spacing: summary **8**, timeline L3/L4 **12**, dose pills **4**, emotions/side-effects **8**. Widths: card inner 361−32=**329**; timeline content 329−(bead36+gap12)=**~281**. Verify break-points vs ground-truth render; hard-place runs if Figma wrap diverges.

---

## Build mechanics & order (canonical lineage: tokens→structure→components→screens)
- **Phase 0** discovery/spike (above) → **Phase 1** manifest (gated) → **Phase 2** Foundations → **Phase 3** Components (one at a time, never batch; full chip family so screens instance not copy) → **Phase 4** Screens, serially, **validate-pipeline-first**: Log Dose → med-bar → Calendar empty → week → month → detail → Edit → DayCard folded → unfolded-single → unfolded-multi.
- Serialize **all** MCP calls (Constraint 4); `set_auto_layout` mirrors stacks; `export`/screenshot after each edit to force sync; update the state ledger.
- **Incremental validation:** `get_node`/metadata value checkpoints at end of **Phase 2** and **Phase 3** (before screens consume masters), not only at the end.

## Phase 5 — Review→Correction loop (hardened)
- **Ground truth per view (required):** capture a real render of each of the 10 views from the actual app (owner builds on device — repo no-simulator rule; sim screenshots disallowed) OR from existing `html-mockups/squirl-current-ui-hifi.html` / the Penpot hi-fi boards. The review agent diffs Figma screenshot ↔ this reference + `tokens.json` values, not prose alone.
- **Per-view check order:** `get_metadata` (structural: child counts/positions) → `get_node` (exact values) → `get_screenshot` (visual). Large frames: `get_metadata` first, then per-child `get_node` (read-payload decomposition).
- **Review agent (analysis parallel, calls serial):** structured deviation list; hex/size/weight via `get_node` **exact equality**, position/spacing via `get_node` **±1pt**; use a screenshot→diagnosis→fix mapping (e.g. all-black → fill failed; stacked → re-layout).
- **Correction agent (serial mutations):** apply, re-screenshot, re-`get_node`. After any edit to a **shared master**, run a **global regression pass** (re-check every view instancing it).
- **Convergence:** cap ~3 rounds; **stop on no-progress** (don't oscillate, e.g. FlowLayout breaks). **Escalation output** = per-view defect list (nodeId, expected from `tokens.json`, actual from `get_node`, why unfixable) → owner.

## Verification (acceptance rubric)
- **Tolerance:** **Blocker** = wrong token (any hex mismatch, wrong glyph/level, wrong master used) or wrong structure; **Major** = spacing >1pt off or wrong font size/weight; **Minor** = ≤1pt / sub-pixel (logged, not fixed). Accept = 0 blocker + 0 major per view.
- **Token gate:** `tokens.json` == compiled dump (zero diffs) — build fails otherwise.
- **Instance-parity audit:** since no real components, each duplicated copy `get_node`-diffed vs its master within tolerance (drift = defect).
- **Font assertion:** read back text nodes; family == SF Pro/SF Mono (catch silent substitution).
- **A11y/contrast gate:** compute each wordColor-on-blockTint-on-card pair vs the code's stated ratio (values in `tokens.json`); confirm triple-redundant glyph legend renders.
- **Glyphs:** 18-asset inventory complete; each overlay vs 24×26 spec at actual size; level encoding intact (crown open≥L4, aperture dash≤L2, dot L5, Empty dashed).

## Deviations & flags-to-owner (review agents read first — don't "correct" these)
- Detail **pencil** exists in code (DESIGN.md:94/109 say removed) — code wins; flag.
- **headerMoodBadge42** unused in `app-four/Views/` (DayCard folded header uses `dayHeaderGlyph40`) — grep-confirmed. **`badgeTint` IS used** by `TimelineBead.swift:43` (timeline-bead mood disc fill = mood **base@50%**) — Phase-1 grep correction; capture in the TimelineBead component (views 9/10), NOT the folded header.
- **Emit a DESIGN.md correction list** as a build artifact (Energy/Focus ramps, Card 12pt→16, Opacity 0.16→0.24, glassEffect comment, pencil) — **do not auto-edit** DESIGN.md (needs owner approval).

## Deliverables & artifacts
1. **Reusable Skill** — `.claude/skills/deep-plan-review/SKILL.md` (the generic multi-agent planning flow).
2. **Durable plan copy** — this file (`docs/ui/figma-ds-reproduction-plan.md`).
3. **Linear — project "UX/UI Figma"** (`939de648-155f-4c5f-9911-06cebf7a203d`, team SQU): concise overview in the description + full plan as a project Document.
4. Per CLAUDE.md process: update BACKLOG/DEVLOG/WORKLOG at the checkpoint.

## Scope / risks
- **Dark deferred for v1 render;** `tokens.json` carries dark column + adapts/fixed flags so it's a clean later pass — no mandatory dark-frame verification now.
- Glyphs are **flat images** (not recolorable vector components) — fine for v1; would be native vectors under `use_figma`.
- **Migration-ready, not migrated:** naming + `tokens.json` (slash-paths + iOS code-syntax) let a later switch to `use_figma`/Tokens Studio promote this to a natively-linked system.
- Socket drop if tab backgrounded → foreground; reconnect by re-running the bridge plugin; state ledger enables resume.
