# Plan — App-Wide New Look Migration (proposed spec-033)

**Date**: 2026-07-11 · **Worktree**: `~/Projects/app-four-spm` · **Base branch to plan from**: `feat/032-newlook-screens` (or a fresh `feat/033-newlook-app-wide` off it) · **Status**: PLAN — no migration code written.

Planned using the Figma-skill discipline (Phase 0 Discovery → lock scope → foundations → per-surface → QA). Grounded in a live Figma read of file **Squil-Design** (`M0Meys9X89X1NLyT14qrX5`), not memory.

---

## 0. What this is, and why it's a new spec

spec-032 introduced the **New Look** language (sage `#EFF2EB` ground, borderless white `.newLookCard()` r20) but **deliberately scoped it to exactly two screens** (Edit check-in, Recording detail) and **froze the rest**:

- [spec-032 FR-010](../../../specs/032-newlook-screens/spec.md) — the mixed look (New Look on 2 screens, Paper & Pollen elsewhere) is an **accepted transition state**.
- [FR-011](../../../specs/032-newlook-screens/spec.md) — mascot tab bar, `RootTabView`, status chrome **must not change**.
- [contract X4](../../../specs/032-newlook-screens/contracts/newlook-tokens.md) — `RecordingRow`, `MedicationBarView`, and every `Theme.*` screen are **out of contract, unchanged on purpose**.

**This effort reverses FR-010/FR-011** and takes New Look app-wide. That is a new feature, not a spec-032 edit → **spec-033**. It builds on spec-032's proven `NewLook` token contract (nothing there is thrown away).

**Owner decisions locked (2026-07-11):**
1. **Full consistency** — migrate every screen, including the documented exceptions (`RecordingRow`, Onboarding, Settings) and the tab bar.
2. **Slice-first execution** — one high-leverage PR flips the whole look, then the ink-text long tail.
3. **Med bar** — re-skin to New Look **and** fix the data-gating so real logged doses appear.

---

## 1. Phase 0 — Discovery & Gap Analysis

### 1.1 Code ↔ Figma token reconciliation (live read of a03 `308:1654` + a02 `308:1594`)

| Figma variable (collection "Tiimo") | Value | Code token | Status |
|---|---|---|---|
| `surface/screen` | `#eff2eb` | `NewLook.screen` | ✅ 1:1 |
| `surface/card` | `#ffffff` | `NewLook.card` | ✅ 1:1 |
| `ink/primary` | `#1c1b1f` | `NewLook.inkPrimary` | ✅ 1:1 |
| `ink/secondary` | `#8a8a8e` | `NewLook.inkSecondary` | ✅ 1:1 |
| `border/hairline` | `#dbddde` | `NewLook.hairline` | ✅ 1:1 |
| `accent/selection` | `#54b492` | `NewLook.selection` | ✅ 1:1 |
| `accent/medication` | `#7e5ca8` | `Palette.medication` | ✅ 1:1 |
| `radius/card` | `20` | `Radius.newLookCard` | ✅ 1:1 |
| `spacing/l` | `16` | `Spacing.l` | ✅ 1:1 |
| **`tint/neutral`** | **`#eceae6`** | **— (missing)** | ⚠️ **add `NewLook.tintNeutral`** |
| `Tiimo/Shadow/Card` | 2-layer (`#0000000D` r8 y2 + `#00000008` r2 y1) | `newLookCard` (1-layer `0.06` r8 y2) | ⚠️ minor fidelity gap |
| `ink/destructive` | `#e0443a` | `Theme.danger` `#B5503A` | 🔒 intentional deviation (C15 — warm clay, not raw red) |

**Conclusion:** the core New Look palette is already **1:1 with Figma**. Only three deltas, all resolved below. No blocking conflict.

### 1.2 The `tint/neutral` finding (resolves the surface-2 groove question)

Every New Look track/groove/segmented-fill binds Figma **`tint/neutral #eceae6`** — the New Look replacement for Paper & Pollen `Theme.surface2`. Add it once as `NewLook.tintNeutral`; do not invent a bespoke value and do not overload `hairline` (RecordingDetailView's L161 level-bar groove currently uses `hairline` — a small existing deviation to correct toward `tintNeutral`).

### 1.3 Migration surface (grep-verified, `app-four-spm`)

- **12 files** reference `Theme.background/cardBackground/elevatedBackground`; **2 components** use `.card()` (`RecordingRow`, `MedicationBarView`).
- **2 screens already on New Look** (`RecordingDetailView`, `ExtractionReviewView`, + `ADHDSummarySection`) — **verify only, never re-Theme**. A `Theme.*` grep is blind to these.
- **`RootTabView`** sets no tab-bar appearance → the bar falls back to system material on sage. Must be **added**, not migrated.
- **`FeedbackButton`** uses `.ultraThinMaterial` → reads as chrome on sage; give it an explicit `NewLook.card` fill.
- **`DayCardPaletteTests`** asserts `Theme.cardBackground` → breaks unless updated with the DayCard change.

### 1.4 Med bar — root cause of "missing" (fully wired, empty by data filter)

- Built + env-injected app-wide ([SquirlApp.swift:33](../../../app-four/App/SquirlApp.swift#L33)); mounted on every `ScreenContainer` + `RecordingDetailView`.
- Renders nothing when `showBar && !activeDoses.isEmpty` fails. `refresh()` filters `isMockData == debugMockMode`.
- **`debugMockMode` registers `true` by default** ([SquirlApp.swift:16](../../../app-four/App/SquirlApp.swift#L16)); `logManualDose` never sets `isMockData` (defaults `false`). **Net: a DEBUG build shows only mock doses and hides every real logged dose; Release inverts it.** That is the "missing" — plus the empty-state when no dose is within its active window.

---

## 2. Locked scope

**In:** `NewLook.tintNeutral` token + Figma variable; ScreenContainer ground; all `.card()`/`Theme.cardBackground` card surfaces → borderless r20; all `Theme.textPrimary/Secondary` → ink; grooves/tracks → `tintNeutral`; med-bar re-skin + data-gating fix; RootTabView tab-bar appearance; FeedbackButton fill; test updates; SandboxApp; final Theme surface/ink token deletion.

**Out (unchanged):** semantic colours — `Theme.accent`, `meadowGreen/Amber`, `meadowGradient`, `statusDone/InProgress`, `danger` (warm clay), `Palette.medication`, all signal ramps, mood tints, `category.color`, `tag.color`; glyph shapes (FR-008 carries forward); non-colour tokens (`Spacing`, `Typography`, `Motion`). Calendar timeline a01/US3 stays gated on spec-029 **unless** the owner opens that gate as part of "full consistency" (open decision D4).

**Token strategy — migrate call sites, do NOT alias.** Re-pointing `Theme.background`→sage is one line but cannot produce the target card: `.card()` is bordered r16, `.newLookCard()` is **borderless r20** — a *shape* change, not a colour swap. Only the `.card()`→`.newLookCard()` migration satisfies the brief. `Theme` survives as an accent/status module (New Look has no accent tokens); a later, separate spec can rename/retire it.

---

## 3. Foundations (PR-0 — no visible change)

1. **`NewLook.swift`** — add `NewLook.tintNeutral = Color(lightHex: "#ECEAE6", darkHex: <derive>)` (scope: fills). Update the doc comment (L30-31) that names `RecordingRow`/`MedicationBarView` as retained `.card()` consumers — spec-033 overrides that contract.
2. **`Card.swift` / `NewLook.swift`** — bring `newLookCard`'s shadow to the **two-layer** `Tiimo/Shadow/Card` spec (`#0000000D` r8 y2 + `#00000008` r2 y1) so cards match Figma exactly.
3. **DESIGN.md** — extend the New Look section: "New Look is now app-wide; Paper & Pollen (`Theme`) retained only for accent/status/danger." Add `tintNeutral`.
4. **Figma (design-system parity, `figma-generate-library` Phase 1)** — add a `tint/neutral` sibling only if the DS foundations page lacks it (a-screens already bind it, so the variable exists; confirm it's documented on the Design System page `59:2`). No new screens required here.

---

## 4. Figma workstream (design source-of-truth parity)

The a01/a02/a03 screens already define the language; the app-wide migration is a **mechanical application** of an already-designed system, so per-screen New Look mockups are **not required for the constitution's mockup gate** for the colour-swap surfaces. Two exceptions where a Figma mockup adds real value (card *shape* changes, not just colour) — **recommend mocking before code**:

- **Insights** cards (`ConnectionCardsView` unlocked/gated dashed cards, gauges) — borderless r20 + track contrast on white.
- **Settings** — decide inset-grouped-recolour vs true r20 card language (open decision D3).

Everything else (ScreenContainer ground, DayCard, med bar, Check-in, Onboarding, modals) is a token swap against the existing a-screen language → no new mockup. If the owner wants full Figma parity, a follow-up `figma-generate-design` pass can rebuild the remaining Screens-(v2) boards in New Look, but that is **decoupled** from shipping the code.

---

## 5. Code migration — slice-first PR sequence

### PR 1 — "The Look" (highest leverage; flips the whole app)
- **`ScreenContainer`** L52/L53 `Theme.background` → `NewLook.screen` (ground + toolbar for every tab). Keep `.tint(Theme.meadowGreen)`.
- **All card surfaces** → borderless r20: `DayCard` (drop clipShape/r16 → `.newLookCard()`), `RecordingRow` `.card()`→`.newLookCard()`, `MedicationBarView` (§6), Insights `UnlockedCard`/gated card, `MedicationLogSheet` field-cards (drop the 4 border overlays), `TextCheckInComposer` note-box, `SettingsView` list-row background.
- **Grooves/tracks** → `NewLook.tintNeutral`: `SignalAverageGauges` (L35/L81), `ConnectionCards` MiniBar (L124), med-bar `DoseTrack` (L167), RecordingDetail level-bar (L161 hairline→tintNeutral).
- **`RootTabView`** — add the sage/white tab-bar appearance (FR-011 reversed).
- **`FeedbackButton`** — `.ultraThinMaterial` → `NewLook.card`.
- **`DayCardPaletteTests`** — update `Theme.cardBackground`→`NewLook.card` in the same PR.
- Exit: every screen renders sage ground + borderless white r20 cards, light **and** dark. `/code-review` + owner device QA.

### PR 2 — "Ink" (text-token long tail)
- `Theme.textPrimary`→`NewLook.inkPrimary`, `Theme.textSecondary`→`NewLook.inkSecondary`, `Theme.separator`/`cardStroke` dividers→`NewLook.hairline` across: `CheckInView` (~18), `TextCheckInComposer`, `SettingsView` + `JournalExportSection`, `WelcomeView` (Onboarding), `Chip`, `TimelineBead`, `SignalAverageGauges`, `ConnectionCardsView`, `Card.cardEyebrow`, `Buttons`.
- Deferred contrast pairs decided here: CheckIn stop-button inverted pair (D5), MedLogSheet unselected chip, Chip selection colour (D6).
- Exit: zero `Theme.textPrimary/Secondary` outside semantic use. `/code-review` + QA.

### PR 3 — "Cleanup" ("no dead code")
- Grep-gate: zero refs to `background/cardBackground/surface2/elevatedBackground/textPrimary/textSecondary/separator/cardStroke/.card(`.
- Delete those tokens from `Theme.swift` + `.card()` from `Card.swift`. Theme keeps only accent/meadow/status/danger. Migrate `SandboxApp/` first (it blocks deletion).

---

## 6. Med bar — re-skin + data-gating fix

**Re-skin (visual, PR 1):** `MedicationBarView` L21 `.card()`→`.newLookCard(padding:)`; L17 divider `Theme.separator`→`NewLook.hairline`; L62 name `textPrimary`→`inkPrimary`; L74 subline `textSecondary`→`inkSecondary`; L167 `DoseTrack` groove `Theme.surface2`→`NewLook.tintNeutral`. **Keep locked purple** — L67 state word + L169 fill `Palette.medication`, glyph L56.

**Data-gating fix (logic — needs a RED test first, Constitution X):** the bug is that `logManualDose` doesn't tag `isMockData`, so real doses vanish in DEBUG. Recommended minimal fix: `logManualDose` sets `isMockData = UserDefaults.standard.bool(forKey: "debugMockMode")` so a dose logged in the current mode is visible in that mode. This is a **behavioural change** → write a failing `MedicationBarViewModelTests` case (real dose logged in mock mode is visible), then implement. Note `debugMockMode` is unregistered under XCTest, so the test must set it explicitly. (Owner decision D7: this minimal fix vs a broader "always show real doses" partition redesign.)

---

## 7. Tests & verification (owner builds on device — no simulator)

- Per PR: grep migrated files for residual `Theme` surface/ink tokens + `.card(` → expect zero.
- `swift build --package-path Packages/SquirlDesignSystem` + full app suite green before each PR (Constitution).
- `/code-review` each diff.
- Device QA **light + dark**, default + one accessibility text size: sage on every tab, borderless r20 cards, hairline/`tintNeutral` groove contrast (bead outline, MiniBar, med-bar groove), tab-bar appearance, FeedbackButton, med bar (toggle `debugMockMode` or log a real dose to populate `activeDoses`), and the two already-New-Look screens for regressions.
- Final PR: full-repo grep of the 8 deleted tokens → zero, then delete + clean rebuild.

---

## 8. Open decisions (minimized — recommendation first)

- **D1 — `tintNeutral` dark value.** Derive a cool-dark inset (~`#272A22`) to sit above `NewLook.card` dark `#1C1E19`. *Rec: derive now, QA in dark.*
- **D2 — Card shadow.** Adopt the 2-layer `Tiimo/Shadow/Card`. *Rec: yes (exact Figma parity, cheap).*
- **D3 — Settings card language.** Recolour system inset-grouped rows (keep system radius) **or** rebuild as r20 borderless cards. *Rec: recolour now (lower risk); mock r20 Settings in Figma if you want the full language later.*
- **D4 — Calendar timeline (US3/a01).** "Full consistency" implies migrating it, but it's gated on spec-029. *Rec: keep gated; migrate Calendar under this spec only once 029's fate is decided, else it's a merge-conflict magnet.*
- **D5 — CheckIn stop-button inverted pair.** Naive ink swap may weaken contrast. *Rec: introduce a small on-ink token or keep on Theme; decide at PR 2 with a device look.*
- **D6 — Chip selection colour.** Filter chips use `Theme.accent` (bronze); New Look convention is `NewLook.selection` (green). *Rec: move to green for consistency.*
- **D7 — Med-bar partition semantics.** Minimal fix (tag logged dose with current mode) vs redesign. *Rec: minimal fix now + RED test; redesign only if the mock/real split proves wrong in use.*
- **D8 — Figma parity depth.** Confirm `tint/neutral` is documented on DS page `59:2`; decide whether to rebuild remaining Screens-(v2) boards in New Look (decoupled, optional).

---

## 9. Recommended next actions

1. **Formalize as spec-033** via Spec Kit (`/speckit.specify` → `plan` → `tasks`), seeding from §1–§6 here. Constitution gates it.
2. **Land Foundations (PR-0)** — `NewLook.tintNeutral` + 2-layer shadow + DESIGN.md. No visible change; unblocks everything.
3. **Answer D1–D8** (most have a clear rec).
4. Then execute PR 1 → 2 → 3, `/code-review` + device QA each.

No Swift is written until the owner approves this plan and D1–D8 are settled.
