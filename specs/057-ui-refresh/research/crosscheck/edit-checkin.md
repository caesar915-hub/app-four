<!-- Created: 2026-09-27 22:27 WEST · Updated: 2026-09-27 22:27 WEST -->
# Cross-check — pen "iPhone 17 - 18" (Check-In Details · Edit Check-In) vs the shipping SwiftUI

Planning artefact only. No Swift changed, no repo file touched. Worktree read: `/Users/caesargrey/Projects/app-four/.claude/worktrees/057-ui-refresh` at `08ba8cba` (= `main`). Every code claim carries a `path:line` from that tree; every pen claim was re-verified against `pen/html-lite/iPhone-17-18.html` and `figma/iphone17-18.json` (not only the sibling spec). Where the pen is ambiguous the ambiguity is stated, not resolved.

**Independent verification of the sibling spec (`out/screens/edit-checkin.md`)** — all confirmed from the exports: title `Edit Check-In` Inter 18/600 `#17501d`; section titles 16/600 `#193024`; row labels 14/500 `#292d32`; level captions 12/600 `#2a9134`; `Low`/`High` 12/400 `#6f7f75`; 15 level tiles 56 × 56 r 20 stroke 1 `#e5f7e5`, three selected strokes `#70b577` / `#f3b09a` / `#f6cc8a`; 49 `Bill-shape` chips all 27 pt tall, padding 5/15, r 15, 1 pt `#e4ece4`, text 12/500 `#193024` (white on solid `#2a9134`); `Button / Filled` 344 × 44 r 999 `#2a9134`, label 16/500 white line-height 24, padding 10/18; 4 collapse pills 29.17 ⌀ stroke 0.729 `#e4ece4`; back pill 42.6 ⌀ stroke 1.065 `#e4ece4`; 2 fields 166 × 39 r 12 stroke `#1c1b1f`@10 %; exactly three chip rows carry `overflow: hidden` (`541_frame` Pleasant, `563_frame` Unpleasant, `592_frame` Side Effects) with `gap: 6px` and no `flex-wrap`. One correction to the sibling spec: the HTML export's `mood` text node has **no** trailing space (`>mood </` → 0 hits); the trailing space exists only in the Figma JSON copy. Not load-bearing.

---

## 1. Mapping — what implements this surface today

| Layer | File | Role |
|---|---|---|
| View | `app-four/Views/ExtractionReviewView.swift` (446 lines) | The whole edit form: nav row (L34–38), six cards in order When · Signals · Sleep · Medications · Emotions · Side effects (L41–46), chip/tile pickers, Save (L442–445). |
| View model | `app-four/ViewModels/ExtractionReviewViewModel.swift` (310 lines) | `@MainActor @Observable`; editable fields L20–28 (`date`, `mood: String`, `energy`, `focus`, `sleepLevel`, `sleepHours`, `medications: [MedEvent]`, `emotions`, `sideEffects`); seeding from `Recording` L61–103; `confirm()` L191–295; `cancel()` L297–302. |
| Presenter | `app-four/Views/RecordingDetailView.swift:53–73` | Trailing `pencil` toolbar button (44 pt circle, a11y "Edit check-in") builds the VM and presents `.sheet(item: $editViewModel)`. |
| Shared picker | `app-four/Views/Components/GlyphRampPicker.swift` (36 lines) | 30 pt glyph row, 1.5 pt ring on the selected one, tap-again clears; also used by `app-four/Views/CheckIn/TextCheckInComposer.swift:141`. |
| Chip grammar | `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/NewLook.swift:73–108` | `.newLookChip(selected:role:)`, roles `.standard/.medication/.checkIn`. |
| Nav row | `NewLook.swift:116–148` | `NewLookNavBar` — this sheet is its **only** call site. |
| Card | `NewLook.swift:52–66` | `.newLookCard()` r 20, borderless, two-layer black shadow. |
| Layout helper | `app-four/Views/Components/TagFlowView.swift:32` | `FlowLayout` (wrapping rows) used by every chip group here. |
| Models read/written | `app-four/Models/Recording.swift:7,27–37,58–59` (`createdAt`, `energyLevel`, `focusLevel`, `mood`, `sleepHours`, `sleepQuality`, `sleepLevelValue`, `sideEffectsJSON`, `emotionsJSON`, `medicationEvents`); `app-four/Services/NoteExtraction/NoteExtraction.swift:139–159` (`MedEvent` DTO); `app-four/Models/MedicationEvent.swift`; `app-four/Models/MedicationCatalog.swift:20–39`; `Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift` (level enums) | |
| Tests that pin the VM | `app-fourTests/ViewModels/ExtractionReviewViewModelTests.swift` — 12 `@Test`s (L54–217) | Title preservation, med time vs new date, JSON parity, provenance tags, sleep comma parsing, cancel status, nil-extraction defaults, production JSON rebuild. |

The surface **exists**. The pen redraws it; it does not introduce a new destination. Data write path (`confirm()` → `recording.applySummary` L256 → `setMedicationEvents` L257–261 → `RecordingTag` provenance L270–292 → `store.save()` L293) is untouched by anything the pen shows, so **no schema change** is implied (Constitution IX).

---

## 2. Delta table, section by section

Legend: **KEEP** = already matches in substance · **CHANGE** = exists, restyle/rearrange · **NEW** = does not exist · **REMOVE** = exists today, absent in the pen.

### 2.0 Screen chrome

| Item | Verdict | Today (`ExtractionReviewView.swift`) | Pen | What changes |
|---|---|---|---|---|
| Container | CHANGE | `.sheet(item:)` from `RecordingDetailView.swift:71–73`, `presentationDetents([.large])` + drag indicator (L53–54), `NewLook.screen #EFF2EB` ground (L52) | Pushed full-screen page, canvas `#fbfffc`, status bar/home indicator, no tab bar, no FAB | Presentation mode (see §4); ground colour token. |
| Nav row | CHANGE | `NewLookNavBar("Edit check-in")` 24/bold centred (`NewLook.swift:133–134`) with leading 44 pt `cancelPill` (`chevron.backward` in `checkInGreen`, L60–72) and trailing capsule `savePill` "Save" (L74–84) | Back pill 42.6 ⌀ `#fff` / 1.065 `#e4ece4` / `arrow-left` 20 pt `#1e6725`; title `Edit Check-In` 18/600 `#17501d` **left-aligned 7 pt after the pill**; **no trailing action** | Drop the centred-title ZStack idiom; title moves next to the pill; Save leaves the nav. `NewLookNavBar` becomes a 0-call-site symbol (delete candidate). Casing "Edit check-in" → "Edit Check-In" (pen is Title Case throughout; owner copy rule pending, constraints §4.3 Q-V3). |
| Content column | CHANGE | `VStack(spacing: Spacing.m = 12)` padded `Spacing.l = 16` (L40–49) | `Frame 11` at x 29, width 344, **gap 24** | Gutter 16 → 29 (pen), card gap 12 → 24. |
| Primary action | CHANGE | trailing "Save" pill in nav; a11y "Save corrections" (L83) | full-width `Button / Filled` Medium 344 × 44 r 999 `#2a9134`, `Save Changes` 16/500 white, below the last card; Frame 3 states hovered `#1e6725`, focused `#17501d`, disabled `#e5e7eb`/`#9ca3af` | Move + restyle; decide dirty-gating (VM has no public `isDirty` — `editedFields` is `private`, VM L35). |

### 2.1 Date & Time

| Item | Verdict | Today | Pen | What changes |
|---|---|---|---|---|
| Section | CHANGE | Card "When" (`cardHeader("When")`, L120) inside `.newLookCard()` (L133) | Bare header `Date & Time` 16/600 `#193024` directly on canvas — **the only section without a card** | Un-card it; rename. |
| Fields | CHANGE | Two `dateBox`es side by side, `HStack(spacing: 8)` (L121–130): label "Date"/"Time" 12 `inkSecondary` **inside** the box on the left, compact `DatePicker` (`.labelsHidden()`, `in: ...Date()`) on the right; box `Radius.control` 10, 1 pt `NewLook.hairline` (L136–147) | Label 12/500 `#1c1b1f` **above** the field (gap 7); field 166 × 39 `#fff`, stroke 1 `#1c1b1f`@10 %, **r 12**, shadow 0/2/8 `#183c28`@8 %, padding 12/10; leading 15 pt outline icon `#6f7f75` (calendar / clock); value `Jun 29` / `9:15 AM` 12/600 `#193024` at x 32; columns 166 wide, gap 12 | Label placement, radius, shadow, leading icon, value typography. **The picker itself is not designed** — a compact `DatePicker` draws its own tinted capsule and cannot be restyled to this field; the field must be a `Button` that presents a graphical `DatePicker` (popover/sheet), or overlay a transparent `DatePicker` on the styled field (fragile). Open question O-3. |
| Data binding | KEEP | both pickers bind `viewModel.date` (L123, L127); max `Date()` | `Jun 29` (no year), `9:15 AM` 12-h | Keep the single `date` binding and the future-date guard; format `.dateTime.month(.abbreviated).day()` and `.hour().minute()` (locale decides 12/24 h — pen shows 12 h). |

### 2.2 "How Did You Feel?" card (mood · energy · focus · sleep)

| Item | Verdict | Today | Pen | What changes |
|---|---|---|---|---|
| Card | CHANGE | Card "Signals" (L151–173) `.newLookCard()` r 20 no border; sleep is a **separate** card "Sleep" (L198–225) | One card 344 wide, r **24**, stroke **1** `#e4ece4`, shadow 0/4/8 `#183c28`@8 %, inset 16; header `How Did You Feel?` 16/600 + collapse pill; **divider** 312 × 1 `#000`@10 %; body gap 13; **Your Sleep is block 4 inside this card** | Merge Sleep into the signals card; add header row, divider, chevron; card metrics. |
| Collapse control | NEW | none | 29.167 ⌀ pill, `#fff`, stroke 0.729 `#e4ece4`, `vuesax/twotone/arrow-up` 18.76 stroke `#26842f` ≈1.71; state shown: expanded. **Collapsed state not designed.** | New per-card `@State` (or persisted key — not in `AppSettings`, would be `@AppStorage`, no schema change). Hit target 29 pt < 44 → make the whole header row the button. Open question O-5. |
| Row label | CHANGE | `groupEyebrow("MOOD")` — `Typography.label` 12/medium **uppercase** tracking 0.6 `inkSecondary` (L98–104, L154–166) | `mood` / `Energy Level` / `focus level` 14/500 `#292d32` (inconsistent case in the pen) | Sentence/Title Case 14/500 labels; casing to normalise (spec copy rule). |
| Current-value caption | CHANGE | `synonym(name, syn)` → "Great · bright, thriving": name `caption.semibold` in `checkInGreen #5FB36E`, synonym `caption` `inkSecondary` (L106–114) | Single word 12/600 `#2a9134` right-aligned: `Good` / `Charged` / `Present` | Drop the synonym half (see REMOVE); colour `#5FB36E` → `#2a9134`. Word = `displayLabel` (data exists, §3). |
| Level picker | CHANGE (component NEW) | `GlyphRampPicker` (`GlyphRampPicker.swift:15–34`): `HStack(spacing: 12)` of five 30 pt `SignalGlyph`s + `padding(4)`, selected ring `RoundedRectangle(Radius.control = 10)` 1.5 pt in `ringTint` (`checkInGreen`, L155/161/166), tap-again clears (`GlyphRampPicker.swift:19`), a11y "\(kind.title) \(level.displayLabel)" + `.isSelected` (L29–30) | Five **56 × 56 r 20** tiles, gap 8, stroke 1 `#e5f7e5`, **no fill**; glyph 33.55 centred; selected = stroke swaps to a **level tint** (`#70b577` L5, `#f3b09a` L1, `#f6cc8a` L2 — L3/L4 tints not drawn), fill unchanged | New tile component (shared with nothing else in the pen — the check-in screens 4/5/6 show no glyph picker). Keep the a11y contract and the tap-again-clears behaviour (not designed in the pen; today's behaviour, and needed because `mood` may legitimately be empty — VM L51, L209). Whether tap-again-clears survives is O-7. |
| Low / High captions | NEW | none | `Low` left / `High` right, 12/400 `#6f7f75`, under each tile row | Two static strings per signal (×3). |
| Glyph art | NEW (asset) | `SignalGlyph` → Canvas `SproutGlyph` / `BoltGlyph` / `ApertureGlyph` tinted from `MoodLevel.color` / `Palette.energyRamp` / `Palette.focusRamp` (`SignalGlyph.swift:31–60`) | Frame 12 filled multi-colour vectors: sprout (per-level leaf colours), bolt over a **black block** whose height grows per level, target ring with blue arc + amber arrow; **not tintable** | Swap the rendering behind the same `SignalGlyph(kind, level, size, decorative)` API so the 16 other call sites (map `codebase-designsystem.md` §7) are untouched. The black block on Energy (Q-C9 in constraints) blocks asset cutting. |
| Your Sleep | CHANGE | Card "Sleep": header + `SignalGlyph(.sleep, 16)` + "no synonyms" caption (L200–205); row 1 = `SleepLevel.allCases` chips `rawValue.capitalized` → `Restless · Light · Okay · Good · Deep` (L206–212); row 2 = `2h · 4h · 6h · 8h · 10h` presets + `customHoursBox` `TextField("7.5")` (L213–221, L237–260) | Label `Your Sleep` 14/500; **one** chip row `Low · Flat · Good · Okay · Great` (Bill-shape, `Okay` solid); no hours, no glyph, no caption | Fold into the signals card; five words only. **The pen's words are not `SleepLevel` rawValues** (`Levels.swift:152–157`) — see §3 and REMOVE. Order `Good` before `Okay` is a pen defect (sibling spec §4.2 #5). |

### 2.3 Medication card

| Item | Verdict | Today (L275–399) | Pen | What changes |
|---|---|---|---|---|
| Card | CHANGE | Card "Medications" with trailing caption `Stimulants · no limit` (L277–279) | `Medication` 16/600 + collapse pill; divider; card **342** wide, stroke **0.5** `#000`@10 %, r 24 (card geometry differs from card 1 — sibling spec §4.2 #10) | Rename (singular), drop caption, add header/divider/chevron. |
| Medication chips | CHANGE (semantics) | `medGrid` (L389–399): `FlowLayout` of `MedicationCatalog.all` names as chips with `role: .medication` (**purple** `Palette.medication` when on, `NewLook.swift:83`), toggling `addMedication` / `removeMedication(name)` — **multi-select**, each on-chip adds an independent `MedEvent` row | Row of three Bill-shape chips `Concerta · Ritalin · Elvense`, **one solid** (`Elvense`) in **green** `#2a9134` | Colour: purple → green (conflicts with the chip-role grammar and the 2026-06-15 "medication = purple" decision). Cardinality: the pen reads single-select; today's model is a list. **Owner decision O-2** — the biggest semantic delta on the screen. |
| Selected-med rows | REMOVE | `selectedMedCard` per `MedEvent` (L292–351): capsule glyph 22 + name + `Taken`/`Missed` toggle + `×` remove; `Grid` with `Dose` chips, `Time` "\(time) · info" (read-only), `Dur` `DurationField` + "shortest" (L317–342); purple 1 pt border r 20 | none — a flat `Concerta Dose` label + one dose row | Removing loses: (a) **effect-duration editing** — `MedEvent.durationHours` (NoteExtraction.swift:147) is what `setMedicationEvents` persists and what the medication bar's fill window reads (`MedicationEvent.durationHours` L19, `effectProgress` L68–72); (b) per-row remove for **two doses of the same med** (`editRowID` L305–309 exists precisely for this); (c) the read-only dose time. Owner may still want (a). |
| Dose label | NEW | eyebrow `Dose` inside each med row (L320) | `Concerta Dose` 14/500 `#292d32` — should follow the selected med (pen shows `Concerta Dose` while `Elvense` is selected) | Interpolate `"\(name) Dose"`. |
| Dose chips | CHANGE | `entry.doseOptions` chips (`"18 mg"`, `"27 mg"`, `"36 mg"`, `"54 mg"` for Concerta — `MedicationCatalog.swift:23`) role `.medication`, single-select per row (L321–327) | `60mg · 18mg · 27mg · 36mg` (green solid `60mg`) then `Missed · Taken` in the **same row**; row not clipped, spills past the card | Dose strings: catalog writes `"18 mg"` (space) — pen `18mg`; `60mg` is an Elvanse strength (`MedicationCatalog.swift:35`), not Concerta. Normalise to catalog strings. |
| Taken / Missed | CHANGE | Toggle pill per med row: "Taken" purple fill / "Missed" `tintNeutral` (L299–309), a11y label + value | Two Bill-shape chips `Missed` (outline) / `Taken` (solid green) appended to the dose row — reads as a second single-select group | Separate it visually from strengths (own row or trailing segment); keep `toggleMedTaken` (VM L150–154). "Missed" vocabulary vs "medication never nags" is constraints Q-P5. |
| Add / remove | CHANGE | on-chip = add row, off-chip = remove all rows of that name (L392–394) | tap = select | Depends on O-2. |

### 2.4 Emotions card

| Item | Verdict | Today (L403–422) | Pen | What changes |
|---|---|---|---|---|
| Card + groups | CHANGE | Card "Emotions"; eyebrows `PLEASANT` / `UNPLEASANT` uppercase 12 (L408); `FlowLayout(spacing: 8)` wrapping rows (L409) | `Emotions` 16/600 + collapse pill; divider; group labels `Pleasant` / `Unpleasant` 14/500 `#292d32`; chip rows `gap 6`, **`overflow: hidden` single row** (only Excited · Joyful · Proud · Serene + a sliver visible) | Labels to 14/500; row behaviour = **wrap vs horizontal scroll** is undecided in the pen (O-4). Wrapping = today's `FlowLayout`, gap 8 → 6. |
| Chip list | KEEP | 20 emotions hard-coded L17–22, mirroring `Lexicon.defaultEmotions` (`app-four/Services/NoteExtraction/Lexicon.swift:271–278`), `.capitalized` (L411), toggle `toggleEmotion` (VM L138–141) | same 20 words; Pleasant order differs (`Serene` 4th in pen, 10th in code); Unpleasant order identical | Keep the list; order is cosmetic. |
| Chip style | CHANGE | `.newLookChip(role: .checkIn)` (L229–235): `Typography.caption` medium, padding 12/8, `NewLook.card` + 1 pt `hairline #DBDDDE` / selected `#5FB36E` + white | Bill-shape: padding 15/5, r 15, `#fff` + 1 pt `#e4ece4`, text 12/500 `#193024`; selected fill+stroke `#2a9134`, white text | Token swap + padding; capsule already. |

### 2.5 Side Effects card

| Item | Verdict | Today (L424–438) | Pen | What changes |
|---|---|---|---|---|
| Card | CHANGE | "Side effects" + `FlowLayout` | `Side Effects` 16/600 + collapse pill; divider; single clipped row (Dry Mouth · Headache · Nausea · "Appe…"); card **r 23** (pen drift, the others are 24) | Title case; header/divider/chevron; row behaviour (O-4). |
| Chip list | KEEP | 15 hard-coded (L24–28) — same 15 as the pen, **same order**; `.capitalized` gives `Appetite Gone`, `Grinding Teeth`, `Flat Affect` exactly as drawn | 15 chips, 3 solid | Keep. Note the existing seam: `Lexicon.defaultSideEffectCues` has 30 cues (`Lexicon.swift:311–318`); a stored effect outside the 15 is invisible here but preserved on Save (`sideEffects` seeded from `decodedSideEffects`, VM L58, L247). The pen does not fix this. |

### 2.6 REMOVE — consolidated, with function-loss assessment

| Removed element | Where today | Loses a function the owner may still want? |
|---|---|---|
| Cancel pill + trailing Save pill (`NewLookNavBar`) | L34–38, L60–84 | Explicit Cancel becomes "back". `viewModel.cancel()` (VM L297–302) flips `summaryStatus` → `failed` when not completed; that call must move to the back action / `onDisappear` (§4). `NewLookNavBar` then has no caller — delete. |
| Synonym line ("Great · bright, thriving") | L106–114, L157–168 | **Yes, an explicit owner decision** (2026-06-15: "Edit pickers keep named 1–5 scale + synonyms"). The pen reverses it. `subtitle` on the enums (`Levels.swift:23–31, 68–76, 122–130`) stays — `signalSynonym` is pinned by `SignalGlyphTests`. Log as a dated reversal, not a silent drop. |
| Sleep hours presets + custom-hours field | L30, L213–221, L237–271; VM `setSleepHours` L126–136 | **Yes.** `sleepHours` (`Recording.swift:30`) is displayed on the calendar ("7h sleep", `app-four/Models/Recording+MoodDisplay.swift:94–103`) and the detail Sleep card; after the change it is stored and shown but **never editable**. `confirm()` still round-trips the seeded value (VM L215, L243), so nothing is lost on Save. Test `sleepNormalisationParsesCommasAsDots` (tests L153) becomes dead if the setter goes. Also a 2026-06-15 owner decision ("Sleep drops synonyms + adds custom-hours input"). |
| Sleep card header caption "no synonyms" + bed glyph | L200–205 | No. |
| `Stimulants · no limit` caption; helper "Tap to add · expands inline · × to remove · independent events" | L278, L284–286 | No (the helper describes the removed inline-expand). |
| Medication inline-expand: per-row card, `Time` info row, `Dur` `DurationField` ("shortest"), `×` remove, multi-row per med | L292–387 | **Yes — three functions**: duration editing (drives the bar window), removing one of two same-name doses, and the read-only time. Owner decision 2026-06-15 ("multi-select, removable, P1 inline-expand, independent events, no limit") is reversed by the pen. |
| Purple medication grammar on this screen (`role: .medication`, purple border) | L323, L350, L393 | Colour only; but it breaks "medication = purple" (DESIGN decision 2026-06-15) and constraints Q-P7. |
| Uppercase eyebrows (`groupEyebrow`) | L98–104 | No. |
| Sheet furniture: drag indicator, `.large` detent | L53–54 | Only if the screen becomes a push (§4). |
| `GlyphRampPicker` at this site | L155–166 | Component survives in `TextCheckInComposer.swift:141`; the two capture surfaces would then use **different** pickers unless the composer is redesigned too (the pen does not design the type-note flow). |

Not in the pen and **not** in the current view either (no delta): title editing (VM `name` L10–19 exists, no field), manual doses (`source == .manual` filtered out, VM L69), transcript/summary text, audio, regenerate, delete.

---

## 3. Data availability — every pen field

| Pen field / label | Exists? | Source | Note |
|---|---|---|---|
| `Jun 29` (date) | **yes** | `viewModel.date` (VM L20) ← `recording.createdAt` (`Recording.swift:7`) | Format without year; pen shows none. |
| `9:15 AM` (time) | **yes** | same `date` | Locale 12/24 h; the pen is 12 h. |
| mood tiles L1–L5 | **yes** | `viewModel.mood: String` (VM L21) → `MoodLevel(rawValue:)` (`Levels.swift:8–13`, `low…great`) | Pen asset names `mood-low…great` match the rawValues 1:1. |
| mood caption `Good` | **yes** | `MoodLevel.displayLabel` (`Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/MoodLevel+Palette.swift:65–73`, "Low/Flat/Okay/Good/Great") | Pen shows `Good` with tile 5 selected — code would show `Great`. Placeholder data. |
| energy caption `Charged` | **yes** | `EnergyLevel.displayLabel = rawValue.capitalized` (`SignalLevel.swift:57`) → Sluggish/Tired/Steady/Alert/Charged | Level 1 renders `Sluggish` — a word the pen never shows (constraints Q-V1). Pen shows `Charged` with tile 1 selected. |
| focus caption `Present` | **yes** | `FocusLevel.displayLabel` (`Levels.swift:113–121`) → Foggy/Distracted/Present/Sharp/Locked In | Level 1 `Foggy` never appears in the pen. |
| `Low` / `High` end captions | yes (static copy) | new strings | — |
| Sleep chips `Low · Flat · Good · Okay · Great` | **NO (vocabulary)** | `viewModel.sleepLevel: SleepLevel?` (VM L24) — cases `restless · light · okay · good · deep` (`Levels.swift:152–157`); no `displayLabel` (views use `rawValue.capitalized`, view L208) | The pen's five words are mood words. Constitution VII: a value not in `Levels.swift` clamps to `nil`. Needed: either a `SleepLevel.displayLabel` mapping (e.g. restless→"Low"? light→"Flat"?) — a **product decision**, since "Flat" is not a sleep quality — or keep `Restless · Light · Okay · Good · Deep`. Also: `sleepHours` (VM L25) has **no field** in the pen (see REMOVE). |
| Medication chips `Concerta · Ritalin · Elvense` | **yes** | `MedicationCatalog.all` (`MedicationCatalog.swift:20–39`) — names `Concerta`, `Ritalin`, **`Elvanse`** | Spelling: code is `Elvanse`; pen `Elvense` is a typo. History names (`MedicationPickerViewModel`) are **not** offered by this sheet today either. |
| Selected medication | **partial** | `viewModel.medications: [MedEvent]` (VM L26) — a **list**, seeded from `.transcript` events only (VM L68–70) | Pen = one solid chip. Single-select would need a VM rule (replace list with one row, or "primary" row) — not defined anywhere. Manual doses stay invisible (existing seam, map §8.7). |
| `Concerta Dose` label | yes (derived) | `"\(med.name) Dose"` | Follow the selection; the pen doesn't. |
| Dose chips `18mg · 27mg · 36mg` (+ `54 mg`) | **yes** | `MedicationCatalogEntry.doseOptions` (`MedicationCatalog.swift:23`) | Stored as `"18 mg"` (with space) → chip copy `18mg` requires a display transform or a copy decision. `60mg` belongs to Elvanse (L35). |
| `Missed` / `Taken` | **yes** | `MedEvent.taken: Bool` (`NoteExtraction.swift:144`); `toggleMedTaken` (VM L150–154) | Persisted to `MedicationEvent.taken` (`MedicationEvent.swift:16`); bar hides untaken doses (`MedicationBarViewModel`, map §5.1). |
| Emotions ×20 | **yes** | `viewModel.emotions: Set<String>` (VM L27) ← `decodedEmotions` (`Recording.swift:36`, L158–174 per map); list L17–22 | Lower-case stored, `.capitalized` displayed. |
| Side effects ×15 | **yes** | `viewModel.sideEffects` (VM L28) ← `decodedSideEffects` (`Recording.swift:34`); list L24–28 | Same 15, same order. |
| `Save Changes` | **yes** | `viewModel.confirm()` (VM L191–295) | No dirty flag is exposed (`editedFields` private, L35); a disabled-until-dirty button needs a new `var isDirty` (trivial, test-first). |
| Collapse state ×4 | **NO** | nothing | New per-card `@State`; if it should persist, an `@AppStorage` key (no `AppSettings` schema change). Pen shows only expanded. |
| Selected-tile tints `#70b577 / #f3b09a / #f6cc8a` | **NO** | `MoodLevel.color` is `#DA7A2A…#2E8B57` (`MoodLevel+Palette.swift:16–35`); energy/focus ramps are unrelated (`Palette+Signals.swift`) | Three new level-tint tokens (L1, L2, L5 only); **L3 and L4 tints are not drawn anywhere in the file** — must be invented or the rule changed (O-6). |
| Glyph assets ×15 (+5 sleep unused here) | **NO** | Canvas glyphs, tinted (`SignalGlyph.swift:31–60`) | Frame 12 vector art, 64-box, non-tintable; export as PDF/SVG. Energy/sleep black-block artefact unresolved (constraints Q-C9). |
| Field icons calendar / clock | NO | `DatePicker` draws its own | Two SF Symbols (`calendar`, `clock`) or vuesax vectors — icon-family decision (design-system spec §5.1). |
| Back pill / collapse pill icons (`arrow-left`, `arrow-up`) | NO | `chevron.backward` SF | Same icon-family decision. |

Data **not** shown by the pen but carried by the VM and round-tripped silently on Save: `name` (L10), `sleepHours` (L25), per-row `time`/`timeLabel`/`quantity`/`change`/`durationHours` on each `MedEvent`, `originalResult.noteExtraction` extras (activities/triage, L208). None is lost by the redesign as long as `confirm()` is left alone.

---

## 4. Navigation delta

| Aspect | Today | Pen | Delta / consequence |
|---|---|---|---|
| Presentation | Modal `.sheet` from the detail's trailing `pencil` (`RecordingDetailView.swift:53–73`); `.large` detent, drag indicator (`ExtractionReviewView.swift:53–54`) | Full-screen page with a **back pill** and no Cancel/Done pair, no grabber → reads as a **push** onto the stack that already holds `RecordingDetailView` (pushed from Calendar via `NavigationPath.append(UUID)` → `.navigationDestination(for: UUID.self)`, `app-four/Views/Library/CalendarLibraryView.swift:47–54`; also registered in `app-four/Views/InsightsView.swift:32–39`) | If push: add a second `navigationDestination` (e.g. for a `Recording.ID`-keyed edit route) on the same stack; the sheet-only modifiers go. **O-1.** |
| Dismiss semantics | Cancel pill → `viewModel.cancel()` + `dismiss()` (L61–63). **Existing gap:** swipe-down on the sheet dismisses **without** calling `cancel()` (no `interactiveDismissDisabled`, no `onDisappear` hook), so `summaryStatus` is not set to `failed` on that path | Back pill; no discard-changes prompt designed | A push adds the system back gesture, which bypasses `cancel()` the same way. Either hook `onDisappear` (and treat "not saved" as cancel) or make `cancel()` idempotent in `onDisappear`. Decide whether unsaved edits prompt (O-8). |
| Tab bar | Classic `TabView` (`app-four/Views/RootTabView.swift:19–36`); tab-bar background painted from each tab root (`app-four/DesignSystem/ScreenContainer.swift:56–60`) | **Hidden** on this screen (present on `iPhone 17 - 1` Day Details with the FAB — constraints Q-L2) | With the native `TabView`, hide via `.toolbar(.hidden, for: .tabBar)` on the pushed view. If the refresh replaces it with the Frame 4 custom pill bar, hiding becomes root state. Either way this screen needs "no bar" while its parent has one. |
| FAB (Frame 15 `Add Button`) | none exists | absent here | No delta on this screen; the FAB is a root-screen concern. |
| Medication bar overlay | The sheet does **not** show `medicationBarOverlay` (only the detail does, `RecordingDetailView.swift:40`) | not drawn | KEEP absent. |
| Entry point | `pencil` circle, a11y "Edit check-in" (`RecordingDetailView.swift:61–67`) | Day Details (`iPhone 17 - 1`) shows a `•••` pill with **no menu designed** (constraints Q-L8) | Out of this screen's scope but it is the only way in; the pen must say where Edit lives. |
| Nested pickers | compact `DatePicker`s pop their own overlays | not designed | Popover/sheet for date and time (§2.1). |

---

## 5. Accessibility, Dynamic Type, dark mode — this screen

**Contrast (light, from Frame 5 and computed):**
- Level captions `Good/Charged/Present` 12/600 `#2a9134` on white: **4.04:1** (Frame 5 green-500 white-text value) — below AA 4.5:1 for normal text; 12 pt semibold is not "large". Same colour today? No — today's `checkInGreen #5FB36E` is worse; this is not a regression but the pen still fails. green-600 `#26842f` (4.75) or green-700 `#1e6725` (6.95) would pass (design-system spec §7.2).
- White 12/500 on solid `#2a9134` chips and white 16/500 on the `Save Changes` button: **4.04:1** — fails AA for normal text. Today's `#5FB36E` fill is the documented 2.52:1 exception; the pen improves it but does not clear the bar.
- `Low`/`High` 12/400 `#6f7f75` on white: **≈4.2:1** (computed; not a Frame 5 token) — fails 4.5:1 by a hair.
- **Selected-tile state is a 1 pt border in a pale tint** — `#f6cc8a` ≈1.5:1, `#f3b09a` ≈1.9:1, `#70b577` 2.45:1 against white — all fail the 3:1 non-text-contrast floor (WCAG 1.4.11), and the glyph inside does not change. This also contradicts PRODUCT.md principle 5 ("colour is never the only cue") since the only selected/unselected difference is a faint colour. Today's picker uses a 1.5 pt `#5FB36E` ring (2.5:1) — also weak. Recommend a fill tint and/or a 2 pt stroke in the 500-step green, and `.isSelected` (already emitted, `GlyphRampPicker.swift:30`) for VoiceOver.

**Touch targets:** chips 27 pt tall (pen) vs 44 pt floor — today's `.newLookChip` is ≈28 pt (caption 12 + 8/8 padding) so no regression, but neither meets the floor; give rows a 44 pt hit height (`.contentShape` + `frame(minHeight: 44)`) while drawing 27. Collapse pill 29 pt → header row is the button. Back pill 42.6 → frame 44. Tiles 56 pt ✓. Fields 39 pt tall → frame 44.

**VoiceOver:** tiles carry no text — keep the current label contract `"\(kind.title) \(level.displayLabel)"` + `.isSelected` (`GlyphRampPicker.swift:29–30`) and add `accessibilityValue` on the row so the caption word is read; `Low/High` are decorative. Chips keep `"\(word), selected"` (view L414, L432). Collapse buttons need label + `accessibilityValue("Expanded"/"Collapsed")`. Date/time fields keep "Check-in date"/"Check-in time" (L124, L128).

**Dynamic Type:** the pen is Inter at fixed sizes; every current role scales via `UIFontMetrics` (`Typography.swift`, map §4). Mapping: 18/600 title → `Typography.text(18, .semibold, relativeTo: .title3)`; 16/600 section → `headline`; 14/500 row label → `subheadline`; 12/600 caption → `caption.weight(.semibold)`; 12/500 chip → `caption.weight(.medium)` (today's `.newLookChip`); 12/400 `Low/High` → `caption`; button 16/500 → `headline`-ish with `minHeight 44` instead of the fixed 24 line-height. Fixed geometry: 5 × 56 + 4 × 8 = **312 pt** in a 344 column — fits on 402-wide (iPhone 17) and 393/390-wide devices; on a 375-wide device the column is 317, still fits. Glyphs are imagery and do not scale (current rule, `Metrics` doc). **Chip rows must wrap at AX sizes** — a horizontally scrolling single row at AX5 hides most options; the 12 pt captions at AX5 become ~33 pt and single-line `nowrap` labels (pen) will truncate unless allowed to wrap. The `Date`/`Time` columns should stack vertically at ≥ AX3.

**Dark mode:** not designed (constraints Q-C10). Today every colour on this screen has a derived dark value (`NewLook.swift:13–44`). New pen colours (`#fbfffc`, `#193024`, `#292d32`, `#6f7f75`, `#e4ece4`, `#e5f7e5`, `#183c28` shadow, the three tile tints, `#000`@10 % divider) need derived dark values. Two hard cases: the **black energy block** (Frame 12) vanishes on a dark tile; the L5 sprout `#175723` and the `#e5f7e5` tile hairline are near-invisible on a dark card. Glyph art being non-tintable means dark needs a second asset set or a fill rule.

**Reduce Motion:** collapse/expand and chevron rotation must be gated on `accessibilityReduceMotion` like every animation today (map `codebase-views-journal.md` §1.5); use `Motion.smooth` (`Motion.swift`).

**Increase Contrast / Differentiate Without Colour:** provide a stronger selected-tile treatment under `\.accessibilityDifferentiateWithoutColor` (e.g. 2 pt ink stroke or a check badge) — the pen has none.

---

## 6. Risks and open questions

### Risks
1. **Medication model collapse.** Pen = one medication + one dose row; code = `[MedEvent]` with per-row time/duration/quantity, `editRowID` diffing (VM L305–309), `setMedicationEvents` replacing all `.transcript` rows (`Recording.swift:301–344` per map). Reducing to single-select silently drops multi-dose editing and **duration editing that the medication bar depends on** (`MedicationEvent.durationHours` L19, `effectProgress` L68–72). Three of the 12 VM tests (`medTimeResolvesAgainstNewDate` L72, `jsonKeepsColumnlessFieldsDropsRedundant` L103, `productionPathRebuildsNoteExtractionJSON` L217) exercise that path and will need rewriting test-first (Principle X — VMs are not exempt).
2. **Sleep vocabulary outside `Levels.swift`** (Principle VII) and the dropped hours input; `sleepHours` becomes write-once. Reverses the 2026-06-15 decision.
3. **Selection state fails non-text contrast and the "never colour-only" principle** (§5) — a design defect to fix in the spec, not just implement.
4. **Text contrast below AA** on green-500 captions/buttons/chips and on `#6f7f75` captions (§5); the paywall-fine-print ruling in the old DESIGN.md shows the owner does draw a line somewhere — ask where for this screen.
5. **Clipped chip rows** hide 6/10 emotions and 11/15 side effects in an edit form; the Concerta-dose row overflows the card in the pen itself. Two of three exports disagree (HTML clips, Figma JSON wraps).
6. **Dismiss path bypasses `cancel()`** today (swipe) and would with the back gesture — `summaryStatus` can stay `generating`; fix by hooking `onDisappear`.
7. **Glyph asset ambiguity** (Energy/Sleep black block; two "great" sprouts `#428d52/#175723` vs `#4caf50/#388e3c` on other screens) blocks the tile picker until resolved.
8. **Inter → SF** (constraints Q-C1): chip widths in the pen (e.g. `Disappointed` 109) were measured in Inter; SF is slightly wider at 12/500 — wrapping points move.
9. **Picker divergence**: replacing `GlyphRampPicker` here but not in `TextCheckInComposer.swift:141` leaves two 1–5 input grammars; the pen does not design the type-note flow.
10. **Sequencing**: Swift skills CLAUDE.md requires are only on `feat/055` (constraints §1.4); 055 is unmerged; the constitution check must cite the branch's version (2.2.0 vs 3.0.0).
11. **Three explicit owner decisions reversed by the pen** (synonyms; sleep hours; medication multi-select/inline-expand — all 2026-06-15). They should be re-decided on the record, not overwritten because the file is "the source of truth".

### Open questions for the owner (only what the pen cannot answer)
- **O-1 Push or sheet?** Back pill says push; the current entry is a sheet from the pencil. Where does Edit live on Day Details now that `•••` has no menu?
- **O-2 Medication cardinality.** One medication per check-in (pen) or independent multiple `MedicationEvent`s (code, 2026-06-15 decision)? If one: what happens to a recording that already has two `.transcript` doses? Is per-dose **duration** editing dropped, knowing the bar's window reads it?
- **O-3 Date/time pickers.** Popover graphical picker, a system sheet, or accept the compact `DatePicker`'s own look inside the field?
- **O-4 Chip rows: wrap or horizontal scroll?** Recommendation: wrap (today's `FlowLayout`), because scroll hides 11 of 15 side effects and breaks at AX sizes.
- **O-5 Collapsible cards.** Real, and persisted across visits? Can "How Did You Feel?" collapse at all (it is the reason the screen exists)?
- **O-6 Selected-tile treatment.** Per-level tints as drawn (then L3/L4 tints are needed) or per-signal? And may the selected tile take a fill, given the 3:1 non-text-contrast failure and "colour is never the only cue"?
- **O-7 Tap-again-to-clear.** Keep today's clear-on-retap (needed to un-set a wrong extraction)? The pen shows no "none selected" state.
- **O-8 Save semantics.** Always enabled (pen) or dirty-gated; prompt on back with unsaved edits; success haptic?
- **O-9 Sleep words and hours.** `Low·Flat·Okay·Good·Great` mapped onto `restless…deep`, or `Restless·Light·Okay·Good·Deep`? Is the hours input dropped for good?
- **O-10 Synonym line.** Confirm dropping "Great · bright, thriving" (reverses 2026-06-15).
- **O-11 Copy normalisation.** `Elvanse`, `18 mg` vs `18mg`, `Edit Check-In` casing, `mood`/`focus level` label case — normalise to code `displayLabel`s and Title Case per HIG?
- **O-12 Contrast policy for this screen.** Accept green-500 (4.04:1) for 12–16 pt text, or shift text to green-600/700 and captions to grey-400 `#4d5154`?

---

## 7. Effort — senior SwiftUI engineer, hours

Assumptions: the token set (Frame 5 palette + the 12 off-palette values named), Inter→SF role mapping, and the shared components — `Bill-shape` chip, `Button / Filled`, card L with header/divider, back pill, collapse pill, 56 pt level tile, date/time field, and the 20 glyph assets — already exist in `SquirlDesignSystem`. Excludes `/speckit` paperwork, code review and owner device QA. Includes the mandatory HTML mockup (Principle I), build + simulator run, and test-first VM changes.

| Bucket | Item | h |
|---|---|---|
| NEW | Push destination + back pill nav + tab-bar hiding + `onDisappear` cancel hook (O-1/O-8) | 2.0 |
| NEW | Date/time styled fields presenting graphical pickers (O-3) | 2.0 |
| NEW | Level-tile picker wiring ×3 with caption word, `Low/High`, a11y value, Differentiate-Without-Colour fallback | 2.0 |
| NEW | Collapsible card wiring ×4 (state, header-as-button, Reduce Motion) | 1.5 |
| NEW | Medication single-select + "<Med> Dose" + dose row + Taken/Missed regrammar in the VM, test-first (rewrites 3 VM tests) | 4.0 |
| NEW | Chip-row layout rule (wrap; AX stacking of the date columns) | 1.0 |
| NEW | Full-width `Save Changes` + `isDirty` on the VM (test-first) | 1.0 |
| NEW | Dark-mode derivation for this screen's new colours + glyph fallback | 1.5 |
| NEW | HTML mockup of the screen (light + dark + AX5 toggles) | 3.0 |
| **NEW subtotal** | | **18.0** |
| CHANGE | Card/chip/ground/typography token swap across the six sections; sleep folded into the signals card; label case/copy | 3.0 |
| CHANGE | Emotions / side-effects groups restyle (labels 14/500, gap 6) | 0.5 |
| CHANGE | Nav title/row restyle, gutters 29 / gap 24 | 0.5 |
| **CHANGE subtotal** | | **4.0** |
| REMOVE | Synonym line, sleep hours + custom box + VM setters (+ dead test), inline-expand med rows + `DurationField`, captions, `NewLookNavBar` deletion | 1.5 |
| REMOVE | Verify `GlyphRampPicker` still compiles for the composer; delete only if the composer is redesigned in the same slice | 0.5 |
| **REMOVE subtotal** | | **2.0** |
| Verification | Build + simulator run light/dark/AX5, VoiceOver pass, run the suite (`ExtractionReviewViewModelTests`, `SignalGlyphTests`, `RecordingMoodDisplayTests`) | 2.0 |
| **Total** | | **26 h** (range 22–32 depending on O-2 and O-3) |

If O-2 resolves to "keep multiple events" the medication line drops to ≈2 h (restyle only) and the total to ≈24 h; if the date/time picker must be a bespoke calendar, add 3–4 h.
