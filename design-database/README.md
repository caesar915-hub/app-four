<!-- Created: 2026-07-18 02:15 (WEST) · Updated: 2026-07-18 18:35 (WEST) -->
# Design Database — Screens v3 a01–a08 (CSV Catalog)

Inventory of the **a01–a08 screens on the Screens v3 page** (`552:1163`) of the Figma file **Squil-Design** (`M0Meys9X89X1NLyT14qrX5`) — the working page going forward. v3 is a **byte-exact clone** of the original v2 source frames (page `76:2`), re-created 2026-07-18 12:48 WEST *after* all design fixes were applied, so every row below applies to v3 identically (re-verified against v3: 1,344 nodes, 342 texts, 61 instances, 0 Fraunces, 215 styled, 40/40 radius bound — all match). Data was captured via official Figma MCP Plugin-API reads.

**v3 frame IDs** (this catalog's scope): `578:1163` (a01) · `578:1385` (a02) · `578:1482` (a03) · `578:1760` (a04) · `578:3638` (a05) · `578:3659` (a06) · `578:3669` (a07) · `578:3959` (a08). *v2 lineage IDs (where the fixes were originally applied): a01 `308:1930`, a02 `308:1594`, a03 `308:1654`, a04 `447:821`, a05 `447:838`, a06 `447:855`, a07 `469:969`, a08 `500:1116`.*

Counts are exact, not sampled: 1,344 nodes scanned, 342 text nodes, 61 component instances, 0 raster images.

## Files

| File | Contents | Rows |
|---|---|---|
| [screens.csv](screens.csv) | The 8 a-frames with ids, sizes, positions, per-screen node counts | 8 |
| [typography-usage.csv](typography-usage.csv) | Every unique font/size/line-height/color combo with usage counts, sample strings, and `production_font` (SF Pro target) | 54 |
| [text-styles.csv](text-styles.csv) | All 48 file-level text styles with a used-on-a-screens flag (15 used, all `Tiimo/`) + `production_font` column | 48 |
| [color-usage.csv](color-usage.csv) | Every unique paint (hex@opacity, gradients) with text/fill/stroke role counts | 77 |
| [tokens-variables.csv](tokens-variables.csv) | All 101 variables in 3 collections with Light/Dark values and bound-use counts (incl. new `accent/medicationText`; Tiimo dark values added 2026-07-18) | 101 |
| [spacing-layout.csv](spacing-layout.csv) | Auto-layout direction, item-spacing, padding, corner-radius distributions | 60 |
| [effects.csv](effects.csv) | Shadows observed on the screens + the 6 file-level effect styles | 10 |
| [components.csv](components.csv) | Component/variant instance usage (glyphs, status bar, week day, icons, crescent ring) | 20 |
| [assets.csv](assets.csv) | Vector/shape/image asset inventory | 8 |
| [rules.csv](rules.csv) | 16 derived rules (R01–R16) + 16 flags (R17–R32; R17/R26 resolved, R19–R25/R27/R28 partial, R29–R32 perceptual audit) | 32 |
| [token-consistency-audit.csv](token-consistency-audit.csv) | Design audit №1 (token/consistency): color tokenization %, ramp/glyph hardcoding, color drift, radius/spacing/type outliers, with per-finding recommendations | 28 |
| [accessibility-audit.csv](accessibility-audit.csv) | Design audit №2 (accessibility): WCAG contrast per fg/bg pair with composited tint backgrounds, accepted-vs-new classification, dark-mode gap, min text size, touch-target heuristic | 18 |
| [design-conformance-audit.csv](design-conformance-audit.csv) | Design audit №3 (DESIGN.md conformance): canvas vs DESIGN.md vs shipping code per area — 2 stale DESIGN.md ramps, 1 canvas drift, dark-mode gap, spacing ambiguity | 24 |
| [perceptual-audit.csv](perceptual-audit.csv) | Design audit №4 (perceptual/consistency): 18 merged findings from 4 parallel Opus-max lenses (fresh-eyes, ui-ux-pro-max checklist, consistency matrix, Apple HIG) ranked by severity + cross-lens agreement — the "why it feels off" audit | 18 |

## Headline findings

- **Working token set is Tiimo Colors**: `ink/primary` ×201, `surface/card` ×156, `ink/secondary` ×154, `border/hairline` ×118, `accent/medication` ×55, `accent/selection` ×40 bound uses. Squirl Tokens contribute only the mood/energy/focus signal ramps + `sleepIndigo`; Structured Colors is absent.
- **Font system**: Inter, **342 of 342** text nodes (Fraunces eliminated 2026-07-18 — node + `Tiimo/Display/Day-40` style converted to Inter Semi Bold); 15 applied text styles, all `Tiimo/`; workhorse `Tiimo/Body/Small-13`; style coverage 62.9% (215/342). SF Pro is unrenderable through Figma's server environment (all 4 SF families measure width 0 — verified empirically), so Inter is the in-Figma stand-in; **SF Pro is the production target** — see the `production_font` column.
- **Card recipe**: white fill + 1px `#DBDDDE` hairline + two-layer shadow (`Tiimo/Shadow/Card`) + radius 20 (`radius/card` token, now bound on all 40 in-scope nodes). Radius tiers 14 fields/pills, 18 chips, 22 badges/avatars remain untokenized (proposed, deferred).
- **Design audits — REMEDIATED 2026-07-18 (owner accepted audit judgment)**: №1 token/consistency — color tokenization **70%→88.5%** (206 ramp/sleep/tertiary paints bound, non-visual; open: 36 raw blacks, 56 raw whites, spacing still 0%). №2 accessibility — of 15 audited-new AA failures, **8 FIXED** (medication text ×5 → new `accent/medicationText` `#6B4E8F`; destructive ×3 → `ink/destructive` retinted `#D54037`; all re-scan verified) and **7 accepted** with rationale; remaining 147/342 fails are all documented-accepted; Tiimo Colors now has a **Dark mode** (8 documented values; 19 light-copies flagged). №3 conformance — DESIGN.md §Signal ramps **corrected** to shipped code values; crescent gradient fixed to `#96C19F` (instances + master); open: gated-card stroke intent, spacing-scale decision. **№4 perceptual (4 Opus-max lenses, 2026-07-18)** — the "why it feels off" audit; all four converged on **3 root causes: (1) no emphasis/spacing hierarchy** (every card an equal r20 tile), **(2) one green means 5–7 things**, **(3) web/Material card grammar, not iOS grouped-table**. Plus a07's 3–5 chart idioms, glyph-fill inconsistency, fragmented chips, sub-44pt targets. Subjective design critique (not measured) — see `perceptual-audit.csv`, R29–R32.
- **Flag status** (rules.csv R17–R28): R17 Fraunces "Monday" ✅ resolved; R19 radius-20 cards ✅ bound to `radius/card` (14/18/22 tiers still open); R20 unstyled text 🟡 47 nodes styled + 3 new styles (~127 approximate/no-match remain, QA-gated); R21 stray `#000000` ✅ resolved (`#8E8E93` gray drift + invisible avatar fills deferred); R18 Squirl surface/text tokens still unbound.

Source of truth is the Figma page itself — every row now applies to the 8 a-frames on **Screens v3** (`552:1163`), no input from repo docs. Regenerate by re-running the extraction rather than hand-editing. **2026-07-18 change log**: (1) Figma mutations applied on the v2 source (font swap, `ink/primary` fallback sync, 19 radius bindings, 3 new styles, 47 style applications); `typography-usage.csv` fully re-extracted, other CSVs reconciled by exact delta. (2) v3 page re-created as a byte-exact clone of the fixed v2 frames; this catalog re-associated to v3 (`screens.csv` + `rules.csv` node IDs re-pointed).
