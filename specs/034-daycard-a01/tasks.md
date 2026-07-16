# Tasks: DayCard a01 Redesign — Folded + Unfolded

**Branch**: `feat/034-daycard-a01` · **Spec**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md) · **Research**: [research.md](research.md)

Owner builds/QAs on device (no simulator). Test-first for the one logic change (Constitution X). All colours/opacities/radii from existing tokens; new **layout** dims go in `Metrics`.

## Phase 1: Foundational

- [ ] T001 Add layout dims to `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Metrics.swift`: `rowMoodDisc = 43` (unfolded row disc) and `moreAffordance = 30` (⋯ circle), with doc comments citing a01 nodes. No colour tokens.

## Phase 2: User Story 1 — Folded card (P1)

- [ ] T002 [US1] RED: in `app-fourTests/Views/FoldedDayCardHeaderTests.swift`, add sleep tests referencing `DayCardSummary.sleep` (does not exist yet): `sleepComesFromMostRecentRecording`, `sleepFallsBackToOlderNode`, `noSleepAnywhereYieldsNil`, `sleepHoursFormatsWithoutDecimalWhenWhole`. Extend the `rec` helper to set `sleepHours`. Confirm they FAIL to compile/run.
- [ ] T003 [US1] GREEN: in `app-four/Views/Components/DayCardSummary.swift`, add `@MainActor var sleep: String?` = first node's non-nil `recording?.sleepLabel` (newest-first). Confirm T002 passes.
- [ ] T004 [US1] Rework the folded layout in `app-four/Views/Components/FoldedDayCardHeader.swift`: mood word `Typography.text(24,.bold,.title2)` in `level.wordColor`; weekday → 3-letter uppercase derived from `day.date` (static `"EEE"` formatter + `.textCase(.uppercase)` + `.tracking(1.3)`), caps-13, with a middle "·" in `inkSecondary`. Keep the bare sprout at `Metrics.dayHeaderGlyph`, the `level.blockTint` background, and the empty-day path unchanged.
- [ ] T005 [US1] Rework the folded summary chip row in `FoldedDayCardHeader.swift` to a01: `FlowLayout` of energy (bolt+word, primary) · focus (aperture+word, primary) · med (capsule + `summary.mostRecentMedicationName`, `Palette.medication`) · sleep (`SignalGlyph(.sleep)` + `summary.sleep`, primary text) with 5px `inkSecondary` dot separators between chips. Only render chips whose value is present.
- [ ] T006 [US1] Verify the folded VoiceOver label in `FoldedDayCardHeader.swift` includes sleep (add `summary.sleep` to the combined `accessibilityLabel`); keep the element combined and the sprout decorative.

## Phase 3: User Story 2 — Unfolded band + rows (P2)

- [ ] T007 [US2] Add the collapsed caps band: a small view (in `FoldedDayCardHeader.swift` or `DayCard.swift`) rendering `level.blockTint` strip, "WORD · WEEKDAY" caps-13 (word=`wordColor`, ·=`inkSecondary`, weekday=`inkPrimary`), and an up-chevron; wire `DayCard` to show the band (not the folded header) when `isExpanded && !summary.isEmpty`.
- [ ] T008 [US2] In `app-four/Views/Components/TimelineRow.swift`, delete the bead/connector column (`beadColumn`, `TimelineBead`, the connector `Rectangle`, `.zIndex`) and the `isLast` connector logic. Row becomes `HStack(spacing: Spacing.l)` of avatar disc + content.
- [ ] T009 [US2] Add the avatar disc: `Circle().fill(rowLevel.badgeTint)` at `Metrics.rowMoodDisc`, holding `SignalGlyph(.mood, level: rowLevel, size: 30, decorative: true)`; `rowLevel = MoodLevel(name: recording?.mood)`.
- [ ] T010 [US2] Rebuild the row headline in `TimelineRow.swift`: `HStack` with mood word `Typography.text(24,.bold,.title2)` in `rowLevel.wordColor` + time "HH:mm" 13-regular `inkSecondary`, `Spacer`, then the ⋯ affordance (`Circle().strokeBorder(NewLook.hairline or inkSecondary, lineWidth: 1.5)` at `Metrics.moreAffordance` with an `ellipsis` glyph inside, `inkSecondary`, `accessibilityHidden`).
- [ ] T011 [US2] Rebuild the row body as a single wrapping chip line (`FlowLayout`, 5px dot separators): energy (bolt+word primary) · focus (aperture+word primary) · each distinct med name (capsule + name, `Palette.medication`, **name only** — no "Taken"/dose) · sleep (`recording.sleepLabel` text only, `Palette.sleepIndigo`) · feelings ("♥ " + joined, cap 4 + overflow, `inkSecondary`) · side-effects (joined, cap 4 + overflow, `inkSecondary`). Replace the old 4-line `rowHead`/`medicationSleepLine`/`feelingsSideEffectsLine`.
- [ ] T012 [US2] Preserve navigation + a11y: whole row (incl. ⋯) tappable → `onTapRecording(recording.id)`; row stays one combined VoiceOver element; carry the check-in's mood/time/signals into the label.
- [ ] T013 [US2] Update `DayCard.swift` expanded section: remove the `TimelineRow(isLast:)` argument if dropped; set the inter-row spacing to the a01 `gap 22` (`Spacing.xxl`) and the entries padding (16h / top 16 / bottom 18).

## Phase 4: Polish

- [ ] T014 Grep for other `TimelineBead(` consumers repo-wide; if `TimelineRow` was the only one, delete `TimelineBead.swift` (Constitution IV) and any now-dead `Metrics.timeBead`; else leave it and note why.
- [ ] T015 Style-literal audit of all touched files: zero raw colour/opacity/radius values outside tokens; the only bespoke numerics are the new `Metrics` dims and the 5px dot / 1.5 border (named locals).
- [ ] T016 Accessibility pass (Dynamic Type wrap, VoiceOver combined labels incl. sleep, Reduce Motion on the fold animation) per `swift-accessibility-skill`.
- [ ] T017 Adversarial review (correctness / a11y / design-fidelity agents) against the diff + Figma nodes; fix confirmed findings.
- [ ] T018 (OWNER GATE — no simulator) Build + test on device; run the folded/unfolded QA in [quickstart.md](quickstart.md), light + dark + accessibility text size; confirm the 3 owner-approved flags read acceptably.

## Dependencies

T001 → T004/T009/T010. T002 (RED) → T003 (GREEN) → T005/T006. US1 (T002-T006) independent of US2 (T007-T013) except T007 depends on the summary. Polish (T014-T017) after both stories. T018 is the owner merge gate.
