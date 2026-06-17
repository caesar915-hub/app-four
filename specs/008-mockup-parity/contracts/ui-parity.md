# Phase 1 — UI Parity Contract

The "interface" this feature exposes is the rendered screen. The contract is: **each mockup section renders identically (within token deltas) in the app**, verified by an on-simulator screenshot diff in light and dark. `MUST` items are the acceptance bar.

## §04 Medication bar → `MedicationBarView`
- MUST: paper card row; leading capsule glyph (`Palette.medication`); top row = bold name·dose (left) + bold purple state word (right); slim `Theme.surface2` track with solid `Palette.medication` fill (empty→full); onset pulse <12% (Reduce-Motion-safe); mono sub-line. Never red.

## §05 Check-in → `CheckInView`, `CrescentRing`
- Idle MUST: med overlay pill when on board; uppercase date; Fraunces "Ready when you are."; breathing crescent; gradient Speak; ghost Log-meds/Type-note; tab bar.
- Listening MUST: mono timer + amber rec-dot + circular ✕; Fraunces nudge; progress bar + 4 dots; revolving crescent; dark "Stop & save" pill.
- Saved MUST: popping gradient checkmark; Fraunces "Captured."; muted subtitle; gradient Done + ghost "Check in again"; no machinery/card.

## §06 Type-note → `TextCheckInComposer`
- MUST: custom navbar (circular ✕ · Fraunces "Type a check-in" · spacer); 3 signal rows (semibold name + mono "5 · Great" + bare glyph ramp, selected ringed, hairline divider); editable note box with muted placeholder; gradient "Save check-in". No meds/sleep rows.

## §06 Insights → `InsightsView` + `Insights/*`
- MUST: Fraunces "Insights" + muted "June · today vs your usual"; existing snapping scroll; glyph-ramp readback; dashed "Sleep · not tracked yet" chip.

## §07 Recording detail → `RecordingDetailView`, `ADHDSummarySection`, `AudioPlayerView`
- MUST: navbar with no back button (empty left · centered mono date · circular ⋯); 2-line Fraunces title; mono meta; signal-glyph summary row; Summary card (eyebrow + accent ↻ + green-dot bullets); Meds card = capsule + single line "Name dose · Name dose"; Audio card LAST (gradient play + accent/hairline waveform); gradient "Edit check-in".

## §07 Edit sheet → `ExtractionReviewView`
- MUST: grab handle + sticky Cancel/"Edit check-in"/Save; hairline-separated fields (not cards).
- 01 When: two boxes Date/Time.
- 02–04 Mood/Energy/Focus: bare glyph ramp (selected ringed) + name·synonym on header (name accent / synonym muted).
- 05 Sleep: bed glyph + "05 Sleep" + "no synonyms"; named pill scale Restless→Deep (selected purple); hour presets + custom-hours input.
- 06 Medications: "Stimulants · no limit"; selected meds as inline-expand cards (capsule · name · purple Taken · × · dose pills · "08:00 · info" · editable duration box defaulted shortest); stimulant add/remove grid; helper line.
- 07/08 Feelings/Side effects: chip groups.
- Gradient "Save corrections".

## Cross-cutting (all screens)
- MUST: tokens only (no literals) — grep-verified.
- MUST: light + dark both correct; Reduce Motion + Dynamic Type respected.
- MUST: nothing unshown changed; Calendar + §03b untouched; full test suite green.
