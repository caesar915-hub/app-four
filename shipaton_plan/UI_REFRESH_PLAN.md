<!-- Created: 2026-09-28 00:45 (WEST) · Updated: 2026-09-28 00:45 (WEST) -->
# UI Refresh (057) — Implementation Plan

> Planning document. **No Swift changes, no implementation.** Source of truth for the visual target is `untitled.pen` (read through its exports); source of truth for what ships today is the worktree `feat/057-ui-refresh` at `08ba8cba` (= `main`). Every screen fact below comes from the eight verified cross-checks (`specs/057-ui-refresh/research/crosscheck/*.verified.md`), the design-system spec (`specs/057-ui-refresh/research/design-system.md`), the three code maps and `specs/057-ui-refresh/research/constraints.md` — the research pack is on disk **untracked** until UI-01 commits it. Where the pen is ambiguous this plan says so and routes it to a decision (§1) or an open question (§7) instead of guessing.
>
> Every step in §4 is independently approvable: goal · files · deliverable · verification · estimate · dependencies · `☐ Approved`. Nothing in Phase B–F starts until Phase A is approved.

---

## 0. Executive summary and the timeline reality

- **What this is.** A full re-skin of the eight pen screens (check-in A/B/C, Calendar/Mood Journal, Day Details, Edit Check-In, Insights, Settings) on top of a new token set (violet/green/neutral 50–900, `#fbfffc` ground, r 24/18/12 hairlined cards, green-500 primaries, floating pill tab bar + violet FAB, Frame 12 glyphs). It is **not** a restyle-in-place: the pen changes navigation topology (back pills, hidden tab bar on the capture flow and Edit, a FAB), retires four owner decisions from 2026-06-15/06-24 (Calendar unchanged · Settings on native `List` · synonym line · medication inline-expand), and omits nine surfaces that product rules or App Review require (export, privacy/terms, restore, LLM model row, My Medication, medical disclaimer, Clear All Data, transcript/retry, version).
- **Size.** From the verified cross-checks: **≈ 205 h** for the eight screens (incl. their HTML mockups), **≈ 68 h** of shared foundations no screen counted (tokens, typography, components, glyphs, ring, tab bar + FAB), **≈ 16 h** of secondary surfaces the pen never drew but the app has (Log Dose, Text composer, onboarding, recovery-key sheet, custom paywall surfaces), **≈ 34 h** of accessibility/dark/copy/dead-code passes (incl. the wave-1 mini-pass UI-53), **≈ 38.5 h** of docs + Spec Kit (Phase A incl. the design-system mockup UI-05b, plus the five per-slice specs UI-20/24/26/29/31), **≈ 2 h** of pure-logic fixes shipped early as their own PRs (UI-40, UI-54), **≈ 6 h** deferred outside waves 1–2 (UI-43), and **≈ 55.5 h** of PR gates (~25 PRs) + two releases. **Total ≈ 425 h ± 20 %** (§2 and §4.8 sum to the same figure; §5 reconciles to it). This is 10–12 weeks of a solo dev + Claude at 35–40 focused h/week, dominated by owner device QA and decision latency, not by typing.
- **Timeline reality (today Sunday 2026-09-27).** The Shipaton release train has passed: 1.1 was never submitted (RC work sits unmerged on `feat/055-revenuecat`, 64 commits ahead of `main`), the "last safe submission ~Sep 23" gate is gone, Devpost closes Wed Sep 30. **Nothing from this refresh can reach a Shipaton-judged build.** "1.2 in October after RC 1.1" implies: (1) 1.1 must be device-QA'd, merged and submitted first (RC epic, first days of October); (2) `feat/057` must be re-cut from the post-055 `main` (it is currently identical to `main`); (3) an October **submission** of the *full* refresh is not achievable at any honest pace — the earliest full-scope submission is ~Dec 18 at 40 h/week. **Recommendation (§5): ship in two waves** — **1.2 = foundations + tab bar/FAB + check-in trio + Calendar** (submit ~Fri Nov 13, live ~Nov 17) and **1.3 = Day Details + Edit + Insights + Settings + full dark/AX polish** (submit ~Fri Dec 18, before the year-end App Review slowdown). The only way to hit "October" literally is a chrome-only 1.2 (tokens + tab bar + glyphs on the existing layouts, submit ~Oct 23) — offered, not recommended.
- **What blocks code.** Twenty-five decisions (§1) — five are load-bearing and must be answered before a single token is written: **D1 font**, **D3 glyph strategy (and the black-block artefact)**, **D4/D5 tab bar + FAB topology**, **D14 contrast policy**, **D12 fate of 053/054**. Then the sequencing chain: `UI-01/UI-03 docs → main` (before #44/#45) → `#44 → #45 → #41 resolved` → `feat/055 merge + 1.1 submit` (RC-epic ETA, external) → `053/054 archived` → `Oct 1 exit ritual` → `worktrees removed, feat/057 re-cut from main` → `Spec Kit`. Any Swift written before that chain completes creates the exact stacked-branch conflict Constitution V forbids. **PR #45's true footprint** (`git diff main...fix/audit-high-medium`, merge-base `2553e251` — GitHub's 34-file list is a stale merge-base artefact) is 2 commits / 15 files: `AudioFileStorageServiceImpl`, `AudioRecordingServiceImpl`, `MLXJournalService`, `ExtractionValidator`, `WhisperKitTranscriptionService`, `RecordingStore`, `InsightsViewModel+Signals`, `RecordingDetailViewModel` (+ `setMedicationEvents` in `performSummarization`), `FoldedDayCardHeader`, `TimelineRow` + 5 test files — **no** `DESIGN.md`, `PRODUCT.md`, `CLAUDE.md` or constitution hunk exists to resolve. 055 touches Settings, onboarding, the constitution and vendors the Swift skills CLAUDE.md requires.
- **Non-negotiables carried into every step.** Constitution I (HTML mockup before SwiftUI — the pen's HTML-lite export does **not** satisfy it: light-only, 402 pt, no states), II (build + full suite, serial), III/IV (no dead code, no second token set without a Complexity Tracking row), VII (level names only from `Levels.swift` — the pen's sleep words and range-bar axes are rejected), X (test-first for every VM/pure computation in Phase D), XI (no summaries — every edge state named). CLAUDE.md monetization: export never gated, privacy sequencing, restore twice, fail-open, no dark patterns. PRODUCT.md: no streaks/nags/emoji, colour never the only cue, WCAG AA as a hard floor (the pen fails it in six places — §1 D14).

---

## 1. Decisions the owner must make BEFORE any code

Each: options · trade-offs · recommendation. Answers are recorded in UI-02 (DEVLOG + the new DESIGN.md Decisions Log). ★ = blocks Phase B.

### D1 ★ Typeface — Inter (pen) vs native SF (app rule, spec 023)
- **Options.** (a) Bundle Inter (re-add `UIAppFonts`, register faces, reverse spec 023). (b) Keep SF and map the pen ramp 1:1 by size/weight through `Typography` (`UIFontMetrics`-scaled, as today). (c) SF Rounded — not what is drawn.
- **Trade-offs.** (a) pixel fidelity to the pen; costs ~4 h, a licence check, loses nothing in Dynamic Type if metrics are wired, but re-opens a closed owner decision and adds an asset the app never needed. (b) zero cost, Dynamic Type stays free, SF is ~2–3 % wider at 12/500 so pen chip widths and wrap points shift slightly (edit cross-check Risk 8); every cross-check's role mapping assumed SF.
- **Recommendation.** **(b) SF.** Record as "spec 023 stands; the pen's Inter is a working stand-in (design-database R01 precedent)". All sizes/weights in the new DESIGN.md are family-agnostic.

### D2 ★ Dark mode — derive now vs light-only 1.x
- **Options.** (a) Every new token ships with a derived dark pair (`Color(lightHex:darkHex:)`, the spec-033 precedent "Figma specs light only; dark is derived", 2026-07-16) and the pass is device-QA'd. (b) Ship light-only and force `.light` (the app has never done this; `preferredColorScheme` is not set anywhere today).
- **Trade-offs.** (a) ~6 h in UI-06 + ~6 h QA (UI-45); hard cases: green-800 `#17501d` titles vanish on a dark ground (needs ≈ green-200 `#9dcca2`), `#000000@0.10` card strokes are invisible on dark (needs a light hairline), `#183c28` shadows drop to ~0, the energy/sleep "black block" disappears on `#12140F`-class grounds, violet-50 `#f4f0fb` tints need dark partners. (b) a visible regression for every dark-mode user and an App Review screenshot mismatch if the store listing shows dark.
- **Recommendation.** **(a) derive now**, per token, documented in DESIGN.md §Color with the derivation rule; light values stay 1:1 with the pen.

### D3 ★ Glyph asset strategy — vector assets vs redrawn `Shape`s (+ the black-block artefact)
- **Facts.** Frame 12's twenty glyphs are plain multi-colour `VECTOR` paths, not tintable; energy and sleep encode level by a rising mask that **exported as a solid black rectangle** — and the same black block appears *on the screens* (journal "Alert", Insights weekday row, edit tiles), so it may be intended. The mood sprout encodes level by **colour only** (shape constant), which breaks PRODUCT.md principle 5. Two "great" sprouts exist (`#428d52/#175723` in Frame 12 vs `#4caf50/#388e3c` on screens). Sizes on screens: 33.55 / 24 / 23 / 20 / 18 / 16 / 14.
- **Options.** (a) Cut PDF/SVG assets from the pen and place at the seven sizes (non-tintable, light-only, stroke thinning at 14 pt, second asset set for dark). (b) Redraw all four signals as SwiftUI `Canvas`/`Shape` views **behind the existing `SignalGlyph(kind:level:size:decorative:)` API** (16 call sites untouched), with the rising fill drawn as a *clip mask* (not a black tile), a subtle shape cue kept on the sprout (crown opens at ≥ 4, as today), and colours from tokens (dark-mode-able). (c) Hybrid: (b) for the four signals, (a) for the one-off illustrations (medication pill on cards, AI sparkle).
- **Trade-offs.** (a) is fastest to a first pixel but multiplies assets (7 sizes × 20 × 2 modes) and cannot satisfy "colour is never the only cue" for mood without a waiver. (b) costs ~8 h once, keeps grayscale safety, dark mode and Dynamic-Type-independent crispness, and lets the black-block question be answered as "fill mask" without waiting on a re-export. (c) is (b) plus two small template images.
- **Recommendation.** **(c).** Owner must still rule on three sub-points: **D3.1** black block = fill-mask (recommended) or literal black tile; **D3.2** which "great" sprout is canonical (recommend Frame 12 `#428d52/#175723`); **D3.3** waiver for colour-only mood, or keep the crown-opens shape cue (recommend keep the cue — it is invisible at a glance and satisfies principle 5).

### D4 ★ Tab bar — custom floating pill bar (pen) vs native iOS 26 tab bar
- **Options.** (a) Custom: keep `TabView(selection:)` for state/lifecycle, hide the system bar (`.toolbarVisibility(.hidden, for: .tabBar)` on every root), overlay `FloatingTabBar` 274 × 60 (white, r 75, shadow `#183c28@0.16` 0/8/24) + `AddButton` 50 ⌀ violet-500 at the trailing end; own hit areas ≥ 44, VoiceOver "Tab, 1 of 4" + `.isSelected`, Reduce Transparency, keyboard avoidance, bottom `safeAreaInset` ≥ 60 + 8 + home indicator on every root, hide on pushed Edit / B / C. (b) Native iOS 26 tab bar (`Tab` builder) tinted green-500 — already a floating pill on iOS 26, but labels cannot be dropped, the active fill is glass not solid green, and there is no FAB slot (using `Tab(role: .search)` for "+" is a semantic hack).
- **Trade-offs.** (a) ≈ 12 h, loses the iOS 26 minimize-on-scroll and re-tap-to-root behaviours unless re-implemented, but is the single most visible brand element in the pen. (b) ≈ 2 h, HIG-perfect, but is not the design.
- **Recommendation.** **(a)**, with one layout for all four roots: the **compact** variant (icon-only active pill 64 × 44 + FAB) that three of four pen screens use; the Settings frame's labelled 346-wide variant with a floating FAB is treated as pen drift. Inactive icon grey `#999b9d` (2.79:1) is raised to grey-300 `#6a6d70` (5.21:1) to clear the 3:1 UI floor (see D14). **The FAB is hidden on the Check In root** (shown on Calendar, Insights, Settings and Day Details as drawn): with D5 (a) the FAB = start a voice check-in, and the hub already carries a 182-pt "Speak Check-In" that does the same thing 60 pt above it — two identical primary actions on the one screen whose job is that action is what "one primary action per screen" forbids (HIG has no FAB convention to lean on). The A frame draws neither bar nor FAB; showing the bar and hiding the FAB is logged as the deviation. DESIGN.md §9.2 states this recommendation identically. A11y mechanism: container `.accessibilityElement(children: .contain)` + `.accessibilityAddTraits(.isTabBar)`, items `.isSelected`; "1 of 4" is verified on device in UI-18 with an `accessibilityValue("\(i) of 4")` fallback.

### D5 ★ What the FAB does, and where the check-in hub lives
- **Facts.** Frame 4 defines a `Status=Check In` tab; the pen's A/B/C frames have no tab bar and a back pill; the FAB sits on Calendar, Insights, Settings and Day Details. Today the deep link / Siri path is `router.requestCheckIn()` → `selectedTab = .checkIn; shouldAutoStartRecording = true` → `consumeAutoStart()` lands on B. `ScreenContainer` owns its own `NavigationStack`, so a *push* of the hub onto another tab's stack cannot reuse it; a `fullScreenCover` can.
- **Options.** (a) Hub A stays the Check In **tab root** (with the tab bar, no back pill — a deviation from the A frame, consistent with Frame 4); tapping Speak enters B and B/C hide the tab bar + medication bar by state — **mechanism: a `ChromeVisibilityKey` `PreferenceKey`** set by B/C (`state != .idle`) and by the pushed Edit screen, read in `RootContainerView`, which owns the custom overlay (with D4 = (a) `.toolbar(.hidden, for: .tabBar)` only affects the already-hidden system bar, and `@Environment` flows down, so a pushed screen cannot raise a flag through it) — the back pill = cancel. FAB = **start a voice check-in now**: reuses the deep-link plumbing verbatim (select tab + auto-start → B). (b) The whole A→B→C flow is a `fullScreenCover` launched by the FAB and by the tab (tab root becomes a launcher). (c) Drop the tab; FAB only.
- **Trade-offs.** (a) zero new presentation code, keeps the two router tests, satisfies "one primary action per screen" because the FAB is the *app's* one primary action everywhere, and gives ADHD users a one-tap path to recording. (b) matches the frame literally, costs ~4 h + router rewrite + two test changes, and forks the deep-link path. (c) contradicts Frame 4.
- **Recommendation.** **(a)**, with the FAB hidden on the Check In root (D4). Consequences: "Go Back Home" on C = `reset()` to the hub (no `selectedTab` binding needed); back pill on B = `cancelRecording()` without a confirm (audio is discarded immediately, as today) and the edge-swipe pop is irrelevant because nothing is pushed; back pill on C = same as "Go Back Home". Tab bar on pushed Day Details stays visible (pen), hidden on Edit (pen).

### D6 Calendar / Mood Journal redesign (old rule: "Calendar. Unchanged — do not redesign without explicit ask")
- **Options.** (a) Accept the pen (the owner's "pen file is the source of truth" is the explicit ask) and log a dated reversal. (b) Keep the current calendar and re-skin tokens only.
- **Sub-decisions the pen leaves open.** **D6.1** month chevron: keep the week ↔ month expand (today; the pen chevron equals today's collapsed state) — recommend keep. **D6.2** week-strip dot: keep "has check-ins" per day recoloured green-400 `#55a75d`, selected disc green-800 `#17501d` — recommend keep the semantics (the pen shows a placeholder week). **D6.3** strip fade + compact title band (spec 035, 10 tests, owner ruling 2026-07-16): the pen has no scrolled state, so there is no evidence to remove it — recommend keep. **D6.4** "Previous Days" scope: month-scoped (today) vs rolling cross-month — recommend month-scoped; the pen's three identical `Aug 30` cards under `September 2026` are placeholder noise. **D6.5** row ⋯ menu contents: Edit · Delete — recommend exactly those two (Edit hoists the `ExtractionReviewView` presentation to `CalendarLibraryView`). **D6.6** emotions/side effects leave the row (pen) and live on Day Details only — recommend accept.
- **Recommendation.** **(a)** with the sub-decisions as recommended.

### D7 Fate of every REMOVE the cross-checks found (K = keep, R = remove, M = move/restyle)
| Screen | Removed in the pen | Recommendation | Why |
|---|---|---|---|
| A idle | Medication bar overlay on the capture flow | **M** — show on the hub (tab root), hide while `state != .idle` | The bar's tap is the only in-flow dose management; mid-recording it is noise |
| A | First-launch hint `checkInHintSeen` (US5/FR-018) | **R** — the permanent caption "A few words are enough" carries the message | Log as a dated retirement of FR-018's one-time behaviour |
| A | `.paused` UI + `RecordingState.paused` (never assigned) | **R** — delete the case; retire spec 016 FR-017 on the record | Dead code (Principle III). Open: wire the audio service's interruption pause into the VM later (§7) |
| A | Hand-rolled `speakButton` / `hubOption`; `CrescentRing.swift` | **R** after the shared button styles / `CheckInRing` land (incl. Welcome migration) | No dead components |
| B | Prompt progress bar (spec 036 a05) | **K** as a 1 pt hairline under the dots | Tells a time-blind user when the prompt advances; dropping it also kills `promptProgress` + its test |
| B | Ring rotation (7 s) + voice-level glow (logged 2026-06-15 crescent rule) | **OWNER — DESIGN.md D-R2**: (a) carry / (b) static arc / (c) arc step 33→66 % + level-driven glow (recommended), each with a Reduce Motion fallback | A logged owner motion rule is not reversed by an author; the pen draws no motion and the listening spec's Q2/Q8 route it to the owner |
| B | `Typography.timer` (SF Mono 22) | **R** — replaced by the 72/500 hero role with `.monospacedDigit()` | Single call site |
| B | Cap cue "Wrapping up soon" (spec 016 FR-014), save-failed recovery (US2/FR-005), processing spinner | **K** restyled — hint-line text swap; Filled + Underline buttons; spinner in the stop pill | Not drawn ≠ removed |
| C | 78 pt disc + SF check, `Metrics.CheckIn.savedDisc/savedCheck`, dead `recording` param, spring pop | **R** (pop becomes a Reduce-Motion-gated settle of the ring 66→100 %) | Old motion rule "settles to a check"; no confetti |
| Journal | Row chips for meds / sleep / feelings / side effects | **M** — meds + sleep move to the collapsed card (pen); emotions/side effects → Day Details only | D6.6 |
| Journal | Month grid + month swipe; strip fade + compact band | **K** | D6.1 / D6.3 |
| Journal | Bar tap dialog (Log new dose / Delete) | **K** (invisible affordance, AX "Tap to manage" already) | Only bar-level dose management |
| Journal | Mood-tinted header band → fixed mint `#e6f5ee` | **M** accept the pen | |
| Day Details | Title block (`displayTitle` + time · duration) | **M** — time moves into the nav subtitle (`"Monday, Jun 29 · 18:30"`), duration into the player | Three same-day check-ins must stay distinguishable |
| Day Details | Medication bar overlay | **R** on pushed screens (global rule: bar on the four tab roots only) | Pen draws none on any pushed frame |
| Day Details | Bottom "Delete check-in" | **M** → `•••` menu (keep the deferred-delete-in-`onDisappear` pattern) | SwiftData trap when deleting under a mounted sheet |
| Day Details | Sleep card | **K** as a chip row after Emotions (the pen simply forgot sleep here; data + edit UI exist) | Otherwise sleep is captured, editable, never readable |
| Day Details | Side-effects card | **K** as a chip row | The pen transcript itself mentions "dry mouth" |
| Day Details | Transcript card + status pill + **Retry transcription** (the only caller of `retryTranscription()`) | **K** — "Transcript" disclosure under the AI summary; transcribing / pending / failed / retry states rendered **in the AI card** | Recovery copy in `RecordingStore.swift:40` and `CheckInViewModel.swift:349/357` literally sends users here |
| Day Details | Audio card (separate) | **M** into the AI card (pen); hidden entirely for text check-ins (`audioFileName` prefix `"text-"`) | |
| Day Details | Dead VM/store code: `toggleFavorite`, `updateTitle/Date/Mood`, `generateSummary`, `regenerateSummary`, `startRegenerate` (+ its test), `RecordingStore.toggleFavorite/updateTitle`, `Recording.isFavorite` UI remnants, `wireframes/` (`Components/Chip.swift` and `RecordingRow.swift` are **gone with PR #44**) | **R** — Regenerate is **not** adopted into `•••`. #45's `performSummarization` med-refresh hunk (`RecordingDetailViewModel.swift:144-151`, `setMedicationEvents`) and its test are deleted with the rest: merge #45 whole on Oct 1, delete in UI-27 (or ask the audit PR to drop that hunk) — said here so the plan does not merge work in October only to delete it silently in November | Principle III; nothing in the pen asks for regenerate |
| Edit | Cancel + Save pills, `NewLookNavBar` (single call site) | **R** — back pill + full-width "Save changes"; `cancel()` moves to `onDisappear` (also fixes today's swipe-dismiss bypass) | |
| Edit | Synonym line "Great · bright, thriving" (owner decision 2026-06-15) | **R** per the pen; **log the reversal** | `subtitle` stays on the enums (`SignalGlyphTests` pins `signalSynonym`) |
| Edit | Sleep hours presets + custom-hours field (owner decision 2026-06-15) | **K** a compact "Hours" field on the Sleep row | `sleepHours` is displayed on Calendar ("8h Sleep") — it must not become write-once |
| Edit | Medication inline-expand: per-row card, `DurationField`, `Time` info, `×`, multi-row per med (owner decision 2026-06-15) | **M** — keep the multi-event model (`[MedEvent]`), render **one row per medication** (dose chips + Taken/Missed) and a remove affordance; drop **duration editing** from the UI (catalog default drives the bar) | See D21 |
| Edit | Purple medication chip grammar (`role: .medication`) | **M** → green-500 solid (pen); log "violet is no longer the chip colour, only the glyph/bar colour" | D10 |
| Edit | `"Stimulants · no limit"` caption, inline helper, uppercase eyebrows, sheet furniture | **R** | |
| Edit | `GlyphRampPicker` | **R** once `LevelTilePicker` replaces it here **and** in `TextCheckInComposer` (UI-33a) | Two 1–5 grammars must not coexist |
| Insights | `SignalAverageGauges` (three 64 × 280 vertical gauges) | **R** → `RangeBar` | |
| Insights | "Sleep · not tracked yet" dashed chip | **R** (a 4th Sleep row is cheap later — §7) | |
| Insights | Dead `navigationDestination(UUID)` + unused `selectedTab` | **R** | |
| Insights | `MiniBar` leading/trailing captions ("Med days" / "Sharp+ focus") | **R** per the pen; the sentence explains the bar | |
| Insights | Medication bar on Insights | **R** on this tab? — **K** (global rule: roots show the bar) | Pen omission, not intent |
| Insights | 053 shape cards (never on `main`) | see D12 | |
| Settings | LLM "Journal Insights" model row | **K** — must (only way back after "Skip for Now"; the check-in alert points here) | |
| Settings | My Medication picker (default med/dose) | **K** — must (App Intent `LogDefaultDoseIntent` continuation target) | |
| Settings | Medication info disclaimer (1.4.1) | **K** | |
| Settings | Journal export + `RecoveryKeySheet` | **K** — non-negotiable (CLAUDE.md "Export is never gated") | |
| Settings | Clear All Data | **K** (the app's only destructive control; needs a destructive row style — the pen has none) | |
| Settings | Version label | **K** | |
| Settings | Privacy Policy (+ Terms on 055) | **K** — hard gate; in-app `LegalDocumentView` per 055 | |
| Settings | Subscription / Restore (055) | **K** — App Review 3.1.1 "Restore appears twice" | |
| Settings | Ephemeral-store warning | **K** as an undrawn state | |
| Settings | SF leading icons on rows (14 symbols) | **R** per the pen (pen keeps 5 icons) | |
| Settings | Native `List` chrome (owner decision 2026-06-24) | **R** → cards; **log the reversal**; delete the two doc comments citing DESIGN.md §114 | |
| Settings | Dose Guard | **not removed** — restyled (radio rows, chips with check badge) | The task's REMOVE list names it; it is CHANGE |
| App | Feedback button (unmounted), sticker setup (unmounted), Siri onboarding (not in pen), 5-tap debug console (PR #41) | **K as-is**; Siri onboarding restyled with tokens in UI-33a; sticker stays unmounted; #41 is merged or closed in UI-04 (3) — never left open into UI-18/UI-32, which rewrite both files it touches | Out of the pen's scope |

### D8 Copy fixes — normalise, never transcribe
- **Typos to fix (verbatim pen → shipped):** `Breackdoen` → Breakdown · `Claendar` → Calendar · `Vyvans` → Vyvanse · `Elvense` → Elvanse (the catalog name) · `Okey` → Okay · `How's Your Mode?` → "How's your mood?" (test-pinned) · `How Does It Feels Today?` → "How do you feel today?" · `Blocked While A Does Is Still Active` → "Blocked while a dose is still active" (code copy) · `Make The App Works For You` → "Make the app work for you" · `A few Words Is Enough` → "A few words are enough" · `Sept 11` → system date style · `Fr Fr` / `Tue Mon Wed Thur` → locale-derived · `AFTERNOO N` → abbreviate at narrow widths · `3More` → "3 more" · `mobile Data` → "cellular data" · `34MB` → "34 MB" (`ByteCountFormatter`) · `18mg` → "18 mg" (catalog strings) · `voice-model downloads` → "model downloads" (the flag gates both models) · `Acknowledgement` → "Acknowledgements".
- **Casing policy.** Options: Title Case everywhere (pen) vs sentence case for sentences, Title Case only for page/nav/tab titles and section headings (HIG, and what the code + pinned tests do). **Recommend sentence case**; it avoids touching `nudgePromptContents`, `averageHalfStepGetsPlusLabel`, `averageWholeStepUsesWord`, and the gated-copy tests.
- **Ampersands / dashes.** Keep "Stop & Save"; keep the code's spaced em dash and full stops in hints.

### D9 Signal vocabulary — canonical set only (Constitution VII)
- Mood `Low · Flat · Okay · Good · Great`; Energy `Sluggish · Tired · Steady · Alert · Charged`; Focus `Foggy · Distracted · Present · Sharp · Locked In` (always via `displayLabel` — PR #45 fixes the raw `alert`/`lockedIn` rows); Sleep **`Restless · Light · Okay · Good · Deep`** — the pen's `Low · Flat · Good · Okay · Great` sleep chips and its Energy/Focus range-bar axes (`Steady Alert Tired Good Great`, mood words on Focus) are copy defects, not vocabulary. Needs `SleepLevel.displayLabel` + `SleepLevel: SignalLevel` (UI-13). "Where you averaged" labels must fit 60.8 pt pills: `ViewThatFits` → two lines → labels only under the bracketed pair.
- **Recommendation.** As stated; level-1 words (`Sluggish`, `Foggy`) will appear where the pen never showed them — accepted.

### D10 Medication status semantics and the violet question
- **Status words.** Today `kicking in` (< 20 % fill) · `active` (< 80 %) · `wearing off` (< 100 %) · `worn off`, purple, uppercase. Pen: `Active` / `Kicking In` in green-500, Title Case; worn-off undrawn. Options: keep fill-fraction thresholds (tested) vs catalog `onsetMinutes` (Ritalin 20 min, Elvanse 90 min). **Recommend** keep the fraction thresholds now (hoisted to the VM, UI-35), Title Case, green-**600** `#26842f` for AA at 12 pt, worn-off in grey-300 and the row fades — "a worn-off dose just goes quiet".
- **"Missed" / "Taken".** Keep (factual state, not a nag); revisit wording only if device QA shows it reads as judgment.
- **Violet.** Old rule: purple = medication only. Pen: violet-500 also carries the FAB, the AI sparkle, Connections lock tiles/eyebrows and the sleep moon. **Recommend** accept violet as brand accent + medication; shape disambiguates (capsule ≠ moon ≠ sparkle), which is exactly "colour is never the only cue". Log the retirement of "purple is medication-only" and of "sleep must be bluer than medication".

### D11 Paywall restyle
- **Facts.** The pen designs no paywall (A), trial-ended (B), fail-open (C) or Settings subscription (D) screen, and no Welcome/onboarding. On `feat/055` the root/Settings paywall is **RevenueCatUI (dashboard-designed, draft)**; custom SwiftUI remains for the onboarding `PaywallStepView`, `FailOpenView`, `ExportJournalButton`, `LegalDocumentView`, `SubscriptionSection` (7 states).
- **Options.** (a) Apply the new palette in the RevenueCat dashboard (owner task, RC-38) and restyle the custom surfaces with tokens in UI-33b. (b) Leave the paywall visually separate for 1.2/1.3. **Recommend (a)** for the custom surfaces in wave 2 (they inherit tokens cheaply) and the dashboard restyle as an owner task before 1.3 (custom surfaces restyled in UI-33b); the old DESIGN.md §Paywall rules carry over unchanged except the four `NewLook.*`-specific bullets (rewritten in the pen language).

### D12 ★ Parked work — 053 (Insights shape views) and 054 (Settings topic hub)
- **Facts.** `feat/053-insights-shape-views`: 23 commits ahead of `main` + uncommitted edits in `stash@{0}`; adds five cards the pen does not show and `InsightGatedCard`. `feat/054`: spec only, in the stash's untracked half; the pen Settings is a flat page, not a hub.
- **Options.** (a) Merge 053 then re-skin (re-skins Insights twice, guaranteed `InsightsView.swift` conflict). (b) Archive both. The stash stack is **shared across all worktrees and holds 16 entries** (`stash@{0}` = `59a9529a`, "WIP 053 insights shape views + 054 spec"; 15 older WIPs from feat/042, 029, healthkit, spm-designsystem …) — only the 053 entry belongs to this plan. Procedure: `git stash apply 59a9529a` (by SHA, **never `pop`**) onto a fresh `feat/053-insights-shape-views` checkout, commit, tag `archive/053-insights-shape-views`; `git checkout 59a9529a^3 -- specs/054-settings-topic-hub` for the untracked 054 spec, commit on `feat/054-settings-topic-hub`, tag `archive/054-settings-topic-hub`; then re-find the entry by SHA (`git stash list --format='%H %gd %gs' | grep 59a9529a`) and `git stash drop stash@{n}` with the index it prints at that moment (`git stash drop <sha>` is not a valid reference). **Never `git stash clear`.** Delete `feat/ui-refresh` (0 commits) after `git worktree remove .claude/worktrees/ui-refresh`. Cherry-pick only VM logic the pen needs later (053's `usualRange` ≈ "Where you averaged").
- **Recommendation.** **(b) archive.** The pen is the Insights and Settings scope. Never use bare `git stash pop`; verify = the 053 entry is gone and `git stash list | wc -l` = 15.

### D13 Spec Kit — generate spec/plan/tasks from this plan? When?
- **Recommendation: yes**, one spec per shippable slice, each cut at the start of its phase (not all up front, so specs never go stale): **057** foundations + chrome (tokens, typography, components, glyphs, ring, tab bar + FAB), **058** check-in trio, **059** Calendar, **060** Day Details + Edit, **061** Insights, **062** Settings + secondary surfaces (056 is taken by PR #46). `/speckit-clarify` uses §7 as its question list; every `/speckit-plan` carries a Constitution Check I–XI against **the version on the branch at cut time** — expected **3.1.0** (055 lands 3.0.0; the Oct 1 exit ritual removes the sprint override as 3.0.0 → 3.1.0; the SEPTEMBER_PLAN ritual text still says "2.2.0 → 2.3.0" and is corrected in UI-04 (6)) — and a Complexity Tracking row for the token-coexistence window (D15) and, for 057, for the custom tab bar (D4). `.specify/feature.json` still points at 043 — `/speckit-specify` moves it. Spec/plan/tasks files are committed before `scripts/worklog.sh` runs.

### D14 ★ Contrast policy (WCAG AA is PRODUCT.md's hard floor; the pen fails it six ways)
- **Failures (recomputed):** white text on green-500 `#2a9134` 4.04:1 (every filled button, chip, tab pill, "Great" bubble); green-500 as 12-pt text ("Installed", "Active", captions) 4.04:1; `#6f7f75` captions 4.19:1 on `#fbfffc`; amber `#e38400` text 2.78:1; inactive tab icons `#999b9d` 2.79:1 (< 3:1 UI floor); `#8a8a8e` placeholder 3.44:1 (the 2026-07-12 exception the pen re-imports); level-tile selection strokes 1.5–2.45:1 (< 3:1, and colour-only).
- **Options.** (a) Accept as new exceptions (extends the 07-12 ruling). (b) **Text-carrying fills use green-600 `#26842f` (4.75:1); green-500 stays for non-text (ring arc, dots, icons, bars, the FAB's neighbour); 12-pt green text → green-600/700; captions → grey-300 `#6a6d70` (5.21:1); amber never carries text (tags in an AA-safe darkened amber, candidate ≥ 4.5:1 to be measured, or grey-400); inactive tab icons → grey-300; `#8a8a8e` retired; selected tiles get a 2 pt green-600 stroke + a tint fill (+ Differentiate-Without-Colour badge).**
- **Recommendation.** **(b).** Today's buttons already fail at 4.02:1 (`#5F8A4C`), so this is the moment to close it, not re-inherit it. Add an AA test helper (extend `DayCardPaletteTests`' luminance check) so every text/fill pair in the token file is asserted, not remembered.

### D15 Token strategy — coexist (alias) → migrate per screen → delete
- **Options.** (a) Coexist via aliases: new semantic tokens land in UI-06 and `NewLook.*` / `Theme.*` / `Palette.medication` become **aliases** of them (so ground, cards, inks, primary green change app-wide on day one); screens migrate to the new names as they are rebuilt; `NewLook.swift`/`Theme.swift` and the old ramps are deleted in UI-49 when the last consumer goes. (b) Replace values in place under the old names (fast, semantically wrong names linger). (c) Delete first (breaks 36 files / 261 `NewLook.` references; `SignalsReexport.swift` re-exports everything unqualified so nothing compiles).
- **Recommendation.** **(a)** with a Complexity Tracking row bounding the coexistence to the two waves. Grep counts that size the migration: `NewLook.` 261 / 36 files (`inkSecondary` 106, `inkPrimary` 66, `.newLookCard` 29 / 12, `card` 17, `screen` 16, `hairline` 21, `tintNeutral` 10, `selection` 5, `onSelection` 7, `checkInGreen` 13), `Theme.` 33 / 15 (`meadowGreen` 15 / 7 incl. the tab/nav tint and the standard chip fill), `Palette.` 27 / 13 (`medication` 17 / 11), `Typography.` 187 / 33, `Spacing.` 302 / 36. Tests that pin old values and must be rewritten with UI-06: `DayCardPaletteTests` (5), `RecordingMoodDisplayTests` (7), `StickerSetupViewTests:38–39`.

### D16 Gutter and card geometry
- Pen gutters drift 28–31; cards 342–344; card inset 11 vs 15; radii 24/18/12 (+20 tile, Figma variable says 20). **Recommend** one `Spacing.gutter = 28` (cards = width − 56), `cardInset = 15` (11 only inside the medication bar and journal rows), `Radius.cardL 24 / cardM 18 / cardS 12 / tile 20 / chip 15 / field 12 / pill 999`. Narrow-device rule (393/390/375 pt): the 5 × 56 + 4 × 8 = 312 pt tile row fits only at 402 pt — tiles shrink to 52/50/48 with the gap fixed at 8 (UI-16).

### D17 Sleep encoding
- Pen: 5-level moon + star (violet). Code: single bed icon, `SleepLevel` enum with no ramp. **Recommend** adopt the 5-level moon (`SleepLevel: SignalLevel`, `variesByLevel = true`, `displayLabel` per D9); hours stay as data and as the "8h Sleep" caption on cards; `SignalGlyphTests` rows for "Sleep" as level-less are rewritten.

### D18 Day Details scope — one check-in (code) vs day aggregate (pen copy "Today's Mood", "Daily Check-In")
- **Recommend one check-in**; title = relative day (`Today` / `Yesterday` / weekday) and the subtitle carries `EEEE, MMM d · HH:mm` so three same-day check-ins stay distinct. A day aggregate is a different VM — out of scope.

### D19 "Written by on-device AI … tap to correct" — editable summary?
- Needs a write path (`summaryBulletsJSON` + `summary`), a provenance flag (`TagCategory.summary` row — no schema change — vs a new column under constitution 3.0.0's no-wipe rule) and an editor. **Recommend defer** (UI-43, wave 3 or drop); wave 2 renders the caption as text with "tap Edit to correct" pointing at the `•••` → Edit route, exactly as today's copy does.

### D20 Emotion chip valence
- Pen: every emotion is a solid green chip. Today: one bronze tint for all. **Recommend** all solid green-600 (display-only chips), no valence colour; log it.

### D21 Medication cardinality in Edit (pen: one med, one dose row; code: independent `[MedEvent]`, 2026-06-15)
- **Recommend keep the model**, change the presentation: one row per medication present on the recording (dose chips from the catalog, `Taken/Missed` as its own segment, `×` remove), catalog chips add a row; duration editing leaves the UI (`setMedicationEvents` falls back to catalog `durationHours`, so the bar keeps a sane window); the Elvanse 6-strength case wraps. Three `ExtractionReviewViewModelTests` are rewritten test-first (UI-39).

### D22 Settings controls — native `Toggle`/radio semantics vs drawn custom sizes
- **Recommend native `Toggle` tinted green-600, one size** (VoiceOver "switch, on/off", Switch Control, 44 pt for free); radio rows = today's `Button` rows with `.isSelected` and a drawn 20 ⌀ radio; chips get a 44 pt hit frame.

### D23 Date/time fields in Edit
- Pen draws styled fields, no picker. **Recommend** a styled field `Button` presenting a graphical `DatePicker` in a sheet (popover on iPad), single `date` binding, `max Date()` guard kept.

### D24 Waveform
- Pen: 55 quantised bars. Code: 32 seeded (hash of `recording.id`) bars — fiction either way. **Recommend** keep seeded bars, width-derived count, five quantised heights, played violet-500 / unplayed a token with ≥ 1.5:1 luminance step; real amplitudes (+6 h, off-main decode + cache) deferred.

### D25 Medication bar placement
- **Recommend** pinned top `safeAreaInset` on the four tab roots only (today's mechanism, new skin: badge + split title + green status + 10 pt track), hidden on pushed/cover screens and while capturing. The pen's Calendar draws it in-content; pinned is the accessible choice and needs no scroll rule.

### D26 DESIGN.md `Created` stamp
- Same path, whole-file rewrite. Git records a delete + add of the same path in one commit as a **modification**, and the CLAUDE.md recovery rule (`git log --diff-filter=A -- DESIGN.md | tail -1`) returns `2026-06-18 12:13` whatever the commit shape; the path's 79 inbound references persist. **Recommend** treat it as an **edit**: keep `Created: 2026-06-18 12:13 (WEST)`, bump `Updated` (DESIGN.md v2 is stamped this way and records the ruling as D-P1 in its §1). If the owner instead rules "new file", that is a policy decision that overrides the recovery command and is recorded in the file's own header comment. Either way the old Decisions Log rows are carried verbatim as history (⛔ superseded / ⚠ pending / ✅ carried).

---

## 2. Scope table — the 8 pen screens

Counts are rows of the verified delta tables (KEEP = already matches · CHANGE = exists, restyle/rearrange · NEW = must be built · REMOVE = exists today, absent in the pen — see D7 for which removals are refused). Hours are the cross-checks' senior-SwiftUI-engineer estimates, adjusted only where this plan moves shared work into Phase B (noted).

| # | Pen frame | Screen | Current files (primary) | K | C | N | R | Hours | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | iPhone 17 - 4 | Check-in A · idle hub | `Views/CheckIn/CheckInView.swift` (idle branch), `CrescentRing.swift`, `ViewModels/CheckInViewModel.swift`, `RootTabView.swift`, `DesignSystem/ScreenContainer.swift` | 8 | 14 | 5 | 5 | **15** | Cross-check 21 h; −5 h ring (→ UI-15), −3 h because D5 = tab (taken), +2 h mockup; 3 new icon assets |
| 2 | iPhone 17 - 5 | Check-in B · listening | same view (`.recording` branch), `Utils/AccessibilityHelpers.swift`, `Models/PromptPace.swift` | 7 | 11 | 4 | 4 | **19** | 24 h − 5 h ring; includes mockup 2 h, `flowProgress` 1 h |
| 3 | iPhone 17 - 6 | Check-in C · saved | `CheckInSavedView` (private, same file) | 7 | 12 | 3 | 3 | **10** | range 8–12 (Q: motion, back pill) |
| 4 | iPhone 17 - 19 | Mood Journal · Calendar tab | `Views/Library/CalendarLibraryView.swift`, `ExpandedDayCards.swift`, `CalendarStripFade.swift`, `Components/{CalendarHeaderView,CalendarDayCell,DayCard,FoldedDayCardHeader,DayCardSummary,TimelineRow,MedicationBarView}.swift`, `ViewModels/{MoodLibraryViewModel,CalendarMonthModel,DayTimeline,MedicationBarViewModel}.swift` | 28 | 36 | 10 | 4 | **30** | 27 h + 3 h mockup; excludes tab bar/FAB and glyphs (Phase B); +2–3 h if D6.4 = rolling |
| 5 | iPhone 17 - 1 | Day Details | `Views/RecordingDetailView.swift`, `ViewModels/RecordingDetailViewModel.swift`, `Components/{ADHDSummarySection,TagFlowView,AudioPlayerView,PlaybackWaveformBars}.swift`, `ViewModels/AudioPlaybackViewModel.swift` | 5 | 23 | 5 | 8 | **35** | the 6 h summary-correction editor is D19-deferred to UI-43 (listed below, outside waves 1–2); includes 3 h mockup; +6 h if real waveform; the duration-format fix ships early (UI-54) |
| 6 | iPhone 17 - 18 | Edit Check-In | `Views/ExtractionReviewView.swift`, `ViewModels/ExtractionReviewViewModel.swift`, `Components/GlyphRampPicker.swift`, `Packages/…/NewLook.swift` (`NewLookNavBar`) | 3 | 19 | 4 | 11 | **27** | range 23–33 (D21, D23); includes 3 h mockup; tile component → UI-16 |
| 7 | iPhone 17 - 7 | Insights | `Views/InsightsView.swift`, `Views/Insights/{MonthSelectorScrollView,MoodBubbleChart,MoodLegend,SignalStripsView,SignalAverageGauges,DailyRhythmMatrix,ConnectionCardsView}.swift`, `ViewModels/InsightsViewModel(+Signals).swift` | 17 | 34 | 7 | 4 | **29.5** | 28 h + 3 h mockup − 1.5 h: the Sleep × Mood gate fix ships early as its own PR (UI-40) |
| 8 | iPhone 17 - 16 | Settings | `Views/SettingsView.swift`, `Views/Settings/{DayCardSettingsSection,DoseGuardSection,JournalExportSection,MedicalInfoSection,MedicationBarSettingsSection,MyMedicationSection,YourDataSection}.swift`, `Components/ModelDownloadRow.swift`, `ViewModels/SettingsViewModel.swift` | 1 | 18 | 5 | 10 | **39.5** | 36.5 h (incl. 7.5 h for the eight must-keep undrawn rows) + 3 h mockup; ≈ 29 h if the owner cuts them (he cannot — D7) |
| | | **Screens subtotal** | | **76** | **167** | **43** | **49** | **205** | |
| — | (not in pen) | Secondary surfaces: Log Dose sheet, Text composer, onboarding ×4, `RecoveryKeySheet`, Acknowledgements/legal, custom paywall surfaces (055) | `Components/MedicationLogSheet.swift`, `Views/CheckIn/TextCheckInComposer.swift`, `Views/Onboarding/*`, `Views/Settings/JournalExportSection.swift`, `Views/Paywall/*` (055) | | | | | **16** | UI-33a (wave 1, 8 h) + UI-33b (wave 2, 8 h): token inheritance + the 30 pt close-button a11y fix |
| — | Frames 2/3/4/5/12/15 | Foundations (Phase B) | `Packages/SquirlDesignSystem/**` | | | | | **68** | §3.2 |
| — | | Docs + Spec Kit 057 + design-system mockup (Phase A: UI-01…05, UI-05b) | `DESIGN.md`, `CLAUDE.md`, `PRODUCT.md`, `shipaton_plan/*`, `specs/057…`, `html-mockups/057-design-system.html` | | | | | **22.5** | |
| — | | Spec Kit slices 058–062 (UI-20/24/26/29/31) | `specs/058…062` | | | | | **16** | 3 + 3 + 4 + 3 + 3 |
| — | | Data gaps (Phase D) | see §3.3 | | | | | **2** as their own early `fix/` PRs (UI-40 1.5, UI-54 0.5); ≈ 24 h already inside the screen rows | |
| — | | Deferred outside waves 1–2 | UI-43 summary-correction editor | | | | | **6** | wave 3 or drop |
| — | | A11y · dark · copy · dead code · token deletion (Phase E) + wave-1 mini-pass (UI-53) | app-wide | | | | | **34** | 28 + 6 |
| — | | PR gates (~25 PRs × 1.5 h) + two releases (Phase F) | | | | | | **55.5** | 37.5 + 9 + 9 |
| | | **Total** | | | | | | **≈ 425 h ± 20 %** | 340–510 h; equals the §4.8 ticket sum (205 + 16 + 68 + 22.5 + 16 + 2 + 6 + 34 + 55.5) |

---

## 3. Architecture of the change

### 3.1 Token package strategy (`Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/`)

**Today:** 25 files / 1 127 lines; two languages coexist (`Theme` = Paper & Pollen survivors, `NewLook` = spec 033) plus `Palette` (medication, sleep indigo, energy/focus ramps) and `MoodLevel+Palette`; no package tests; every symbol reaches the app unqualified through `app-four/App/SignalsReexport.swift`. Four greens coexist (`Theme.meadowGreen #5F8A4C`, `NewLook.selection #54B492`, `NewLook.checkInGreen #5FB36E`, `checkInGreenSoft #96C19F`).

**Target (D15 — alias → migrate → delete):**

| New file | Exposes (proposed names; all `Color(lightHex:darkHex:)`) |
|---|---|
| `Tokens/Palette+Ramps.swift` | `Palette.violet50…900`, `green50…900`, `grey50…900` — the thirty Frame 5 literals, e.g. `green500 #2a9134`, `green600 #26842f`, `green700 #1e6725`, `green800 #17501d`, `green100 #bdddc0`, `green200 #9dcca2`, `green400 #55a75d`, `violet500 #8c68d3`, `violet600 #7f5fc0`, `violet800 #4d3974`, `violet50 #f4f0fb`, `grey500 #212529`, `grey400 #4d5154`, `grey300 #6a6d70`, `grey200 #999b9d`, `grey100 #babbbd`, `grey50 #e9e9ea` |
| `Tokens/Surface.swift` | `Surface.screen #fbfffc` · `card #ffffff` · `track #fafafa` · `bandMint #e6f5ee` · `ringDisc #ebf8ee` · `fieldFill #ffffff` · `dayCardFill(level)` (`#f8fffc` great · `#fffdfd` low · `#fefdfa` flat · okay/good to be derived) · `medicationTint = violet50` · `connectionUnlocked #e3d8f9` |
| `Tokens/Ink.swift` | `Ink.title = green800` · `primary = grey500` · `secondary = grey400` · `tertiary = grey300` · `nav #6f7f75` (retuned to grey300 per D14) · `chip #193024` (collapsed into `primary` unless the owner objects) · `onAccent #ffffff` · `placeholder` (retire `#8a8a8e` → grey300) · `tabInactive` (grey200 drawn → grey300 per D14) — names identical to DESIGN.md §4.2 |
| `Tokens/Accent.swift` | `Accent.primary = green500` (non-text) · `primaryFill = green600` (text-carrying fills, D14) · `primaryText = green600` · `pressed = green700` · `deep = green800` · `violet = violet500` · `violetDeep = violet800` · `connection = violet600` · `medicationBarGradient (#8061bf → #8c68d3)` · `focusBlue #4278a8` / `focusText #447097` · `energyAmber #eda94a` / `energyDark #d98232` / `energyPale #f8e4c7` · `energyText` (AA-safe, to be measured) |
| `Tokens/Stroke.swift` | `Stroke.card (#000000@0.10, 0.5)` · `separator (#000000@0.10, 1)` · `chip #e4ece4 1` · `tile #e5f7e5 1` · `outlinedButton #cbd5e1 1` · `field (#1c1b1f@0.10, 1)` · `empty #dbddde 1` · dark pairs as light hairlines |
| `Tokens/Elevation.swift` | `Elevation.card (0,3,8 #183c28@0.08)` · `raised (0,4,8)` · `field (0,2,8)` · `chip (0,7,6 @0.06)` · `tabBar (0,8,24 @0.16)` · `fab (0,7,17 #000000@0.17)` · `ring (0,2,18 #000000@0.08)` · `thumb (0,1,3 #193024@0.07)` — one tint, `#183c28` |
| `Typography.swift` (rewrite) | The DESIGN.md §5.2 ramp **verbatim** (same names in both files): `pageTitle 34/600 .largeTitle` · `pageSubtitle 16/500 .body` · `navTitle 18/600 .title3` · `navSubtitle 12/500` · `promptTitle 24/500 .title2` · `promptSubtitle 12/500` · `question 20/600 .title3` · `sectionTitle 16/600 .headline` · `cardTitle 16/600` · `cardSubtitle 14/400 .subheadline` · `rowLabel 14/500 .subheadline` · `rowTitle 14/600` · `entryTitle 14/600` · `narrative 16/400 .body` (the AI summary — the pen's 12 pt refused, D-T2/§7 Q31) · `bodyEmphasis 12/500` · `caption 12/500 .caption1` · `captionQuiet 12/400 .caption1` · `chipLabel 12/500` · `status 12/600` · `micro 11/500 .caption2` · `buttonS/M/L 14/16/18 /500` · `tabLabel 12/500` · `bubbleValue 14/500` · `stripDay/stripNumber 12/500–600` · `segmentLabel 12/500` · `timerHero 72/500 .largeTitle, monospacedDigit, clamped`. **D15 applies to typography too — old role names stay as aliases until UI-49** with this map (UI-07): `largeTitle`/`display` → `pageTitle` · `title` (22/600, 6 sites) → `question` · `headline` (20) → `sectionTitle` · `subheadline` (14) → `rowLabel` · `body` (24) → `narrative` · `callout` (15/400, 17) → `cardSubtitle` · today's `caption` (12/**400**, 63 sites) → `captionQuiet` · `label` (12/500, 22) → `caption` · `moodWord` (2) → `entryTitle` · `timer` (1) → `timerHero` · `duration`/`mono12` (4) → `captionQuiet` + `.monospacedDigit()`. Deleted outright (0 sites): `dayCardDate`, `mono(_:)`, `View.typography(_:)`. Keeps `text(_:weight:relativeTo:)`. The 187 `Typography.` references in 33 files keep compiling; nothing re-weights by accident (the new 12/500 `caption` is never aliased from the old 12/400 one). |
| `Spacing.swift` / `Radius.swift` / `Metrics.swift` | add `gutter 28`, `cardInset 15`, `rowInset 11`, `chipGap 6`, `cardGap 24`, `tilePitch 64`, `chipRowPitch` (≥ 44, D-K6); `Radius.cardL 24 / cardM 18 / cardS 12 / tile 20 / chip 15 / field 12 / pill 999 / tabBar 75`. **Delete in Phase B only what has 0 consumers today** (verified): `Metrics.ringStroke`, `Metrics.rowMinHeight`, `Metrics.headerMoodBadge`, `Metrics.IconSize.*`, `Motion.smoothDuration`, `Typography.dayCardDate/mono/View.typography`. **Alias until the consumer migrates, delete in UI-49** (D15 — every Phase B PR must pass Constitution II at its own gate): `Radius.card` (← `JournalExportSection.swift:55`, migrates in UI-32) and `Radius.newLookCard` (← `DayCard.swift:14` UI-25, `ExtractionReviewView.swift:349–350` UI-28, `ConnectionCardsView.swift:97–99` UI-30) → `Radius.cardL/cardS`; `Radius.button/control` → `pill`; `Palette.sleepIndigo` (← `ADHDSummarySection.swift:65,70` UI-27, `TimelineRow.swift:143` UI-25); `Opacity.moodBlock/moodBadge` (explicit pastel tokens replace opacity tints). **Deleted in the consumer's own PR, never in Phase B**: `Metrics.CheckIn.crescentDiameter` + `CrescentRing.swift` (← `CheckInView.swift:148–149,195`, UI-21), `Metrics.CheckIn.promptBarHeight` (← `:348`, UI-22), `Metrics.CheckIn.savedDisc/savedCheck` (← `:468,471`, UI-23). |
| `Signal/MoodLevel+Palette.swift` (retune) | per level: `bubble` (`#da7a2a · #eda94a · #9dcca2 · #55a75d · #2a9134`), `word` (`#842626` low · `#da7a2a` flat → **AA-fixed** · `#1e6725` okay · good (derived) · `#17501d` great), `avatarTint` (`#f4dddd · #fee8d1 · #e5f7e5 · (derived) · #ddf4de`), `dayCardFill/Stroke` (3 given, 2 derived), `tileRing` (`#f3b09a · #f6cc8a · (derived) · (derived) · #70b577`), `bubbleInk` (dark on 1–4, white on 5) |
| `Signal/EnergyLevel+Palette.swift`, `FocusLevel+Palette.swift`, `SleepLevel+Palette.swift` (new) | fill fractions 30/48/65/83/100 % (energy, sleep moon), star 40.74…54.5, focus arc sweeps; identity colours; `SleepLevel: SignalLevel` + `displayLabel` |
| `NewLook.swift`, `Theme.swift`, `Palette.swift`, `Palette+Signals.swift` | **UI-06:** become aliases (`NewLook.screen = Surface.screen`, `Theme.meadowGreen = Accent.primaryFill`, **`Palette.medication = Accent.violet` (violet-500 `#8c68d3`) and `Palette.medicationFillEnd = #8c68d3`** with the gradient start `#8061bf` drawn only inside `ProgressTrack` — never violet-800: the 17 `Palette.medication` sites (chips, tags, `MedicationBarView:150` gradient start, sticker, `NewLookChipRole.medication`) would otherwise go near-black on day one; `Accent.violetDeep` (violet-800) is used only inside `MedicationBadge` / `CapsuleGlyph`; energy/focus ramps → new signal colours; `Palette.sleepIndigo` → the sleep moon's `#8c68d3`). DESIGN.md §4.2 states the same mapping. **UI-49:** deleted with `Card.swift` (`cardEyebrow`), `Reexport.swift` kept. |

Complexity Tracking row (constitution IV): "Two token namespaces coexist between UI-06 and UI-49 (≤ 2 release waves); justified by 261 `NewLook.` references across 36 files that cannot migrate in one PR without violating 'one PR = one revertable feature'."

### 3.2 Shared components to build once (Phase B), with the screens that consume them

| Component (proposed path under `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Components/`) | Spec (pen) | Consumers |
|---|---|---|
| `FloatingTabBar.swift` | 274 × 60 white r 75, `Elevation.tabBar`; active pill 64 × 44 green-500 (icon only, white 24 pt); inactive 24 pt grey-300; order Calendar · Check In · Insights · Settings; a11y: container `.contain` + `.isTabBar`, items `.isSelected`, "1 of 4" verified on device (fallback `accessibilityValue`); hidden on Edit / B / C via `ChromeVisibilityKey` (D5) | `RootTabView` (all roots), Day Details |
| `AddButton.swift` | 50 ⌀ violet-500, `+` `#e9e9ea` 1.71, `Elevation.fab`; label "New check-in"; action → `router.requestCheckIn()`; **hidden on the Check In root** (D4) | root overlay (Calendar, Insights, Settings), Day Details |
| `NavPill.swift` (`.back`, `.more`, `.circleIcon(24/43)`) | 43 ⌀ white, stroke 1.065 `#e4ece4`, r 21.3, chevron 20 pt green-700; 44 pt hit; 24 ⌀ variant for row chevrons / `•••` | A/B/C, Day Details, Edit, Journal rows |
| `PageTitleBlock.swift`, `SectionHeading.swift` | 34/600 green-800 + 16/500 grey-300, `.isHeader`; 16/600 grey-500 headings with 12 pt gap to card | Insights, Settings; every card section |
| `CardStyle.swift` (`.card(.large/.medium/.small/.day(level)/.expandedDay)`) | r 24/18/12, `Stroke.card`, `Elevation.card/raised`, inset 15; day variant tinted fill + stroke@0.50; expanded variant with 52-high mint header 24/24/0/0 | every screen |
| `HairlineDivider.swift` | 1 pt `#000000@0.10`, inset 15 | cards with rows |
| `Buttons.swift` (rewrite: `FilledButtonStyle`, `OutlinedButtonStyle`, `UnderlineButtonStyle`, sizes S/M/L, icon slot, `tint: .green/.violet`) | pill 999; S 36/14 · M 44/16 · L 52/18; pressed = green-700 fill / `#f8fafc` bg; disabled `#e5e7eb`/`#9ca3af`; replaces `PrimaryButtonStyle`, `CheckInPrimaryButtonStyle`, `SecondaryButtonStyle` (9 call sites) **and 055's `PaywallButtonStyle`** (`Views/Paywall/`, present after the re-cut) | A/B/C, Edit, onboarding, composer, export, recovery sheet, paywall surfaces |
| `BillChip.swift` (`.outline`, `.solid`, `.withDot(color)`, `.solidWithCheck`) + `ChipRow` (wrapping `FlowLayout`; **display rows gap 6/6; interactive rows a ≥ 44-pt row pitch** — chip 27 + gap 17 or chip 36 + gap 8, D-K6 — because a 44-pt hit frame on a 33-pt pitch overlaps the next row by 11 pt; horizontal hit extension only where neighbours are ≥ 44 apart) | 27 high, padding 5/15, r 15, 12/500 `#193024` / white on green-600 | Day Details, Edit, Insights legend, Settings — precondition: the app's private `Chip` (`TimelineRow`, `FoldedDayCardHeader`) and `SettingsChip` are deleted in the consuming PR (they would shadow the package type) |
| `LevelTilePicker.swift` | 5 × 56 (52/50/48 on narrow) r 20 stroke `#e5f7e5`, glyph 33.55, pitch 64, `Low`/`High` captions, selected = 2 pt green-600 + tint (D14), tap-again clears, `.isSelected`, Differentiate-Without-Colour badge | Edit, Text composer |
| `Glyphs/{SproutGlyph,BoltGlyph,TargetGlyph,MoonGlyph,CapsuleGlyph}.swift` (rewrite/new) + `IdentityIcon.swift` | Frame 12 geometry (§ design-system 1.3); rising-fill masks; identity (level-less) variants for Insights headers | `SignalGlyph` (16 sites), Insights, Journal, Day Details, Edit |
| `MedicationBadge.swift`, `MedicationPill.swift`, `ProgressTrack.swift`, `SignalMiniBar.swift` | 26–28 ⌀ violet-50 tile + violet-800 outline capsule; card pill icon (`#ff9522/#dd7917/#f0cf9e`); 10 pt track `#fafafa` + 0.25 hairline, gradient fill `#8061bf → #8c68d3` r 9.5 (6 pt variant for Connections); 86 × 4 signal bar. Names chosen to avoid the app's `private struct DoseTrack` (`MedicationBarView.swift:133`) and `MiniBar` (`ConnectionCardsView.swift:110`), which are deleted in UI-25 / UI-30 | Medication bar, A "Log Medications", Day Details, Settings preview, Insights |
| `app-four/Views/CheckIn/CheckInRing.swift` (app target) | 347 ⌀ (width-relative, ≤ 347) / 211 ⌀ saved; disc `#ebf8ee`, track 21.33 / 12.97 green-100, gradient arc `#26842f → #3fbb4b → #25832e` from 3 o'clock, `progress` 1/3 · 2/3 · 1, butt caps, `Elevation.ring`, Reduce-Motion gate, `accessibilityHidden` | A/B/C, Welcome |
| `ToggleRow.swift`, `RadioRow.swift`, `SegmentedPicker.swift`, `InfoRow.swift`, `RhythmTile.swift`, `ChipGroupView.swift` | native `Toggle` tinted green-600 (D22 — DESIGN.md §8.7 says the same); `RhythmTile` (not `RhythmCell`, an existing model in `InsightsViewModel+Signals.swift:74`) and `ChipGroupView` (not `ChipGroup`, a private model in `ExtractionReviewView.swift:8`); 20 ⌀ radio (6 pt green ring on); 344 × 38 `#fafafa` track / white thumb `Elevation.thumb`; icon 21 + hugging 12/500 note | Settings, Insights month selector, Dose Guard |
| `Icons.swift` (rewrite) | SF Symbol map for the vuesax set: `arrow-left → chevron.left`, `more → ellipsis`, `arrow-up/right → chevron.up/right`, `add → plus`, `calendar → calendar`, `task-square → checkmark.square` (tab Check In), `chart → chart.bar`, `setting-2 → gearshape`, `microphone-2 → mic.fill`, `edit-2 → square.and.pencil`, `stop → stop.fill`, `lock/unlock → lock.fill/lock.open.fill`, `record-circle → record.circle`, `info-circle → info.circle`, `voice-cricle → waveform.circle`, accessibility figure → `accessibility`; sparkle → `sparkles` | everywhere |

### 3.3 Data / view-model changes (Phase D — each test-first, constitution X)

| # | Gap (from the cross-checks) | Model / computation to add | Test to write first (Swift Testing) | Consumer |
|---|---|---|---|---|
| 1 | Ring progress has no source (A idle 33 %, B 66 %, C 100 %) | `CheckInViewModel.flowProgress: Double` — `.idle → 1/3`, `.recording/.processing → 2/3`, `.done → 1` | `flowProgressPerState` in `CheckInViewModelTests` | UI-22/23 |
| 2 | Bar status word is a private view func; pen wants Title Case, green, worn-off quiet | `MedicationBarViewModel.DoseDisplay.status: DoseStatus` (`kickingIn < 0.2`, `active < 0.8`, `wearingOff < 1`, `wornOff`) + `displayLabel` | thresholds + boundary cases in `MedicationBarViewModelTests` | UI-25 |
| 3 | Collapsed card needs dose text and a sleep **level** | `DayCardSummary.mostRecentMedicationDose: String?` (`node.intakeDoses.first?.dose`), `DayCardSummary.sleepLevel: SleepLevel?` (newest recording's `decodedSleepLevel`) | two `@Test`s in `FoldedDayCardHeaderTests` | UI-25 |
| 4 | Rows print raw `alert` / `lockedIn` | `displayLabel` in `TimelineRow` + AX label — **absorbed by PR #45** | already in #45 | UI-04 |
| 5 | Day Details title "Today's Mood" hard-coded (UI-38, inside UI-27); **two duration formats coexist — a pure-logic bug shipped today, fixed early as its own PR (UI-54, `fix/duration-format`)** | `RecordingDetailViewModel.relativeTitle` (`Today` / `Yesterday` / `EEEE`) + `subtitle` (`EEEE, MMM d · HH:mm`); one `formattedDuration` (`"%d:%02d"`) | `relativeTitleByDay` in `RecordingDetailViewModelTests`; `durationFormatIsSingle` in `RecordingTests` | UI-27 · UI-54 |
| 6 | Save must be dirty-gated; `editedFields` misses sleep/side effects/date/name; medication rows collapse; swipe-dismiss bypasses `cancel()` | `ExtractionReviewViewModel.isDirty` via a seeded-value snapshot; `medicationRows: [MedicationRow]` (one per name, holding its `[MedEvent]`); `cancelIfUnsaved()` idempotent | `isDirtyTracksEveryField`, `medicationRowsGroupByName`, rewrite `medTimeResolvesAgainstNewDate`, `jsonKeepsColumnlessFieldsDropsRedundant`, `productionPathRebuildsNoteExtractionJSON` | UI-28 |
| 7 | Sleep × Mood connection **can never unlock** on shipped data (word lists vs canonical `SleepLevel` rawValues) — a live logic bug in 1.1's code, independent of the refresh: **its own PR `fix/insights-sleep-mood-gate` (UI-40), mergeable now, shippable in 1.1.x**; bundling it into a 30-h restyle PR would break "one PR = one revertable feature" (Constitution V) and delay a user-visible fix to December | gate on `Recording.decodedSleepLevel`: poor = `restless/light`, good = `good/deep` | RED test with canonical values in `InsightsViewModelTests` (copy unchanged) | UI-40 → UI-29/UI-30 depend on it |
| 8 | Bubble sizing, rhythm tints, range-bar span are undefined / nine literals | pure fns: `MoodBubbleLayout.diameter(fraction:)` (rule per §7 Q), `RhythmTint.tint(signal:level:)` (one formula), `RangeSpan.segments(for average:)` incl. the whole-number case; caption capitalisation helper or VM string change (+ 2 test edits) | three small test files | UI-30 |
| 9 | "Show Taken Time" / "Show End Time" toggles have no keys | `@AppStorage("medicationBarShowTakenTime")`, `("medicationBarShowEndTime")` read by the VM; `titleLine` branches; rule for "nothing left to show" | `titleLineVariants` in `MedicationBarViewModelTests` | UI-32 |
| 10 | Summary "tap to correct" has no write path or provenance | `TagCategory.summary` + `RecordingDetailViewModel.updateSummary(_:)` (deferred, D19) | `summaryEditWritesTagAndColumns` | UI-43 |
| 11 | Sleep has no ramp / label | `SleepLevel: SignalLevel`, `displayLabel`, `numericValue`; `GlyphSignal.sleep.variesByLevel = true` | rewrite `SignalGlyphTests` sleep rows | UI-13 |
| 12 | Month selector "next" segment at the current month | rule: disabled/blank when `isCurrentMonth` | `nextSegmentDisabledAtCurrentMonth` | UI-30 |
| 13 | Mood word/tint AA guard must follow the new token model | extend `DayCardPaletteTests`' luminance helper to every text/fill pair in `Ink`/`Accent`/`MoodLevel` (light + dark) | `aaTextOnFillsPass` | UI-06 |

Schema: **none of the above changes the SwiftData schema** (all `@AppStorage`, computed, or `RecordingTag` rows) — constitution IX (3.0.0: no store wipe in release) is respected.

---

## 4. The steps

Format: goal · files · deliverable · verify · est (focused hours) · type · owner · depends · approval. IDs are stable once assigned (`UI-01` is re-described, never reissued). "PR" = feature branch off the post-055 `main` → build + serial tests → PR → `/code-review` → owner device QA → merge (UI-50).

### Phase A — Docs & decisions (no Swift)

#### UI-01 · DESIGN.md v2 landed (pen-derived) + CLAUDE.md / PRODUCT.md reconciled
- **Goal:** replace the deleted `DESIGN.md` with the pen-derived system in the same commit, so the 79 references (incl. CLAUDE.md L82/103/104/108, PRODUCT.md L4) stop dangling.
- **Files:** `DESIGN.md` (keeps `Created: 2026-06-18`, bumps `Updated` — D26), `CLAUDE.md` §Design System paragraph + Stack "Design tokens" line + the sprint section's "The paywall obeys the Product Posture rules" reference (kept) + **L105 "Visual companion (HTML)"** — the file `docs/superpowers/plans/2026-06-15-paper-pollen-design-system.html` does not exist in the repo: delete the line or point it at the pen exports (Q80), `PRODUCT.md` §Brand Personality ("Warm pressed paper" → the new language), the pen exports committed as `docs/design/pen/` (SVG + 2× PNG + Figma JSON; Q80) so DESIGN.md §1's evidence row resolves.
- **Deliverable:** DESIGN.md with: Product Context (carried) · Aesthetic (pen) · Typography (D1) · Color (ramps, semantic roles, dark derivation rule, D14 policy, contrast exceptions table) · Glyphs (D3) · Spacing/Radius/Elevation (D16) · Components (§3.2) · Navigation & chrome (D4/D5/D25) · Motion (carried rules + ring/settle) · Product Posture (carried verbatim) · Paywall & Purchase (carried; four bullets rewritten; 09-04 reversal folded in) · Screen Specs (8 pen screens + secondary surfaces + undrawn states) · Decisions Log (new dated rows for D1–D26 + the old log verbatim as history).
- **Verify:** `git grep -n 'DESIGN.md'` — every reference resolves; `test -e` on **every path the rewritten CLAUDE.md §Design System paragraph cites** (incl. the companion line); CLAUDE.md no longer says Paper & Pollen / sprout-lightning-aperture / bed icon; timestamp comment first line reads `Created: 2026-06-18 12:13 (WEST)`.
- **Est:** 6 h · **Type:** Design · **Owner:** Claude · **Depends:** D1–D5, D8, D9, D14 answered (UI-02 can run in parallel; the doc records the rest as open) · **PR:** a **docs-only PR based on `main`** (branch `docs/057-design-md-v2`, or a direct docs commit as CLAUDE.md §Git allows for non-code), **merged before #44/#45** — never committed to `feat/057`, which is deleted and re-cut in UI-04 (7). No DESIGN.md conflict with #45 exists (§0: its true delta has no DESIGN.md hunk).
- ☐ Approved

#### UI-02 · Decisions D1–D26 recorded
- **Goal:** every ★ decision answered; every other decision answered or explicitly parked with an owner and a date.
- **Files:** `shipaton_plan/DEVLOG.md` (one dated "Direction" entry), DESIGN.md §Decisions Log rows.
- **Deliverable:** the D-table of §1 with an "Answer" column; reversals of 2026-06-15 / 06-24 rulings logged as such.
- **Verify:** no ★ item unanswered; §7 questions either answered or assigned.
- **Est:** 2 h · **Type:** Task · **Owner:** Owner · **Depends:** this plan read.
- ☐ Approved

#### UI-03 · Plan approved → SEPTEMBER_PLAN Epic UI + BACKLOG + DEVLOG
- **Goal:** put the §4.8 ticket table into `shipaton_plan/SEPTEMBER_PLAN.md` Epic UI (re-describing `UI-01`), mark every row `🧊 Deferred to October` on `shipaton_plan/BACKLOG.md` (changelog ≤ 15 rows), log the why.
- **Files:** `shipaton_plan/SEPTEMBER_PLAN.md` (Epic UI only — never the `## Today` block), `shipaton_plan/BACKLOG.md`, `shipaton_plan/DEVLOG.md`; `docs/WORKLOG.md` regenerated after the commit (`scripts/worklog.sh`). **PR:** same docs-only route to `main` as UI-01 (before Oct 1, while `shipaton_plan/` is still the live board).
- **Deliverable:** rows in `ID | Summary | Type | Est | Owner | Depends | Acceptance criteria` format; the Oct 1 exit ritual will carry them into `docs/BACKLOG.md`.
- **Verify:** IDs unique and stable; `UI-01` not renumbered; timestamps bumped (`Updated`, never `Created`).
- **Est:** 1.5 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-02.
- ☐ Approved

#### UI-04 · Pre-flight sequencing (the chain that must complete before any Swift)
- **Goal:** land the unmerged work that the refresh touches, in the order the audits prescribe, then re-cut the branch.
- **Steps (each a checkbox in the log named under Files):** (0) UI-01 + UI-03 docs PRs merged to `main` → (1) merge PR #44 (`fix/audit-safe-cleanup`: deletes `Chip.swift`/`RecordingRow.swift`, wraps `TestServicesView.swift` in `#if DEBUG`) → (2) merge PR #45 (`fix/audit-high-medium`; the `alert`/`lockedIn` label fix + the 15-file delta in §0 — **no** DESIGN.md/PRODUCT.md hunk to resolve) → (3) **merge or close PR #41 on Oct 1, after #44**: #41 adds an unconditional `.sheet(isPresented: $showingDebug) { TestServicesView() }` at `SettingsView.swift:97–99` while #44 makes `TestServicesView` DEBUG-only (and `TESTFLIGHT` is not defined in `project.pbxproj`, so `#if DEBUG || TESTFLIGHT` = `#if DEBUG`) — merging #41 as-is after #44 breaks the Release/TestFlight build (`cannot find 'TestServicesView' in scope`); if merged, first guard the `.sheet` + `showingDebug` state with the same `#if DEBUG` and confirm a Release build → (4) **external dependency, owned by the RC epic with its own ETA:** `feat/055-revenuecat` — RC dashboard paywall out of DRAFT, ASC products / offer code (RC-03b…07, RC-40), RC-26 screenshots, the CLAUDE.md privacy-sequencing hard gate (policy + `PrivacyInfo.xcprivacy` + nutrition label **before** the RC build is submitted), owner device QA (RC-24/28), merge, tag on TestFlight upload, submit **1.1** — none of it is UI hours and one day is not a credible estimate; **T0 = 055 merged + 1 day** anchors Phase B (§5) → (5) D12: archive 053/054 as specified (apply `59a9529a` by SHA, never pop; drop the entry re-found by SHA; never `git stash clear`), delete `feat/ui-refresh` after `git worktree remove .claude/worktrees/ui-refresh` → (6) run the Oct 1 exit ritual (docs) — **before running it, edit SEPTEMBER_PLAN §October 1 step 3 from the stale "2.2.0 → 2.3.0" to "3.0.0 → 3.1.0"**; if 055 has not merged by the time the ritual runs, defer only the constitution step until it has, so 055 never has to rebase its 3.0.0 amendment → (7) **verify `git log --oneline main..feat/057-ui-refresh` is empty (abort if the UI-01/UI-03 docs commits are not on `main`)**, discard this worktree's uncommitted `D DESIGN.md` and move `outsource_design/` out (Q80), `git worktree remove .claude/worktrees/057-ui-refresh` (a `git branch -D` fails while the worktree exists), then delete and re-cut `feat/057-ui-refresh` from the new `main` — the docs are already on `main`, so nothing is lost by construction; confirm `.claude/skills/` now holds the seven Swift skills and `.specify/memory/constitution.md` reads **3.1.0** (sprint override removed).
- **Files:** git state; `shipaton_plan/DEVLOG.md` for steps (0)–(3) on Oct 1 (before the ritual); `docs/DEVLOG.md` for steps (4)–(7), which run after the ritual re-activates it and freezes `shipaton_plan/`.
- **Verify:** `git log --oneline main..feat/057-ui-refresh` empty after the re-cut; `git stash list --format='%H %gs' | grep 59a9529a` returns nothing and `git stash list | wc -l` = **15** (the other entries untouched — an "empty" list is unreachable without destroying 15 unrelated WIPs); `gh pr list` shows #42/#43/#46 only (#41 merged or closed); `git worktree list` no longer shows `ui-refresh` or the old `057-ui-refresh`; constitution ≥ 3.0.0 with the sprint override removed (3.1.0); Release build green after (3).
- **Est:** 5 h Claude (+ the RC epic's own hours for (4), uncounted here) · **Type:** Task · **Owner:** Owner + Claude · **Depends:** UI-03; (4) on the RC epic's ETA.
- ☐ Approved

#### UI-05 · Spec Kit slice 057 — foundations + chrome
- **Goal:** `/speckit-clarify` (§7 as the question list) → `/speckit-specify` → `/speckit-plan` (Constitution Check I–XI **against the version on the branch at cut time, expected 3.1.0**; Complexity Tracking: token coexistence, custom tab bar) → `/speckit-tasks` (TDD-ordered; view tasks marked "build + simulator"). Clarify/specify may be **drafted before 055 merges** (docs only, via a docs PR to `main`); the plan step and its Constitution Check run after UI-04 (6). Re-enumerate 055's view files (`Views/Paywall/{FailOpenView,PaywallButtonStyle,PaywallLegalFooter,PaywallStepView,PaywallView,PaywallViewModel,PlanCard,RevenueCatPaywallHost,TrialTimeline}.swift`, `SubscriptionSection`, `LegalDocumentView`, `ExportJournalButton`) once `main` includes them, so UI-09/UI-33b's lists are complete.
- **Files:** `specs/057-ui-refresh/{spec,plan,research,data-model,quickstart,tasks}.md`, `.specify/feature.json`.
- **Deliverable:** tasks that map 1:1 onto UI-06…UI-19; committed before `scripts/worklog.sh`.
- **Verify:** Constitution Check passes; every UI-06…19 step has ≥ 1 task; no task spans model + view + test.
- **Est:** 4 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-04 (6) for the plan step.
- ☐ Approved

#### UI-05b · Design-system HTML mockup (Constitution I for the Phase B atoms)
- **Goal:** Constitution I says *"New views MUST start as an HTML mockup before SwiftUI"*, and A3 rules that the pen's HTML-lite export does not satisfy it; the same ruling applies to the ~20 new atoms Phase B creates. So `html-mockups/057-design-system.html` shows **every Phase B atom** — tab bar + FAB, nav pills, ring at 33/66/100 %, level tiles, `BillChip`/`ChipRow` (incl. the D-K6 interactive pitch), the three button styles × S/M/L, the five card styles, `ToggleRow`/`RadioRow`/`SegmentedPicker`/`InfoRow`, the four glyph ramps + identity icons, `MedicationBadge`/`ProgressTrack` — in default / pressed / disabled / selected, light **and** dark, 1× and AX5, at 402 and 375 widths; owner approves it before UI-06 starts. (The alternative — a written Constitution I waiver for package atoms in 057's Complexity Tracking, approved by the owner in UI-05 — is rejected here: the plan already refused the pen export for screens on the same grounds.)
- **Files:** `html-mockups/057-design-system.html` (+ the dark/AX toggles the screen mockups use).
- **Deliverable:** the approved mockup, linked from `specs/057-ui-refresh/plan.md`.
- **Verify:** owner approval recorded in DEVLOG; every atom in §3.2 appears in all its states; contrast of every text/fill pair checked in the page (the D14 table).
- **Est:** 4 h · **Type:** Design · **Owner:** Claude (+ owner approval) · **Depends:** UI-02 (D1–D5, D14), DESIGN.md v2; may run **before 055 merges** (docs-only PR to `main`).
- ☐ Approved

### Phase B — Foundations (package-first; each step = tests/previews; grouped into 4 PRs: B1 = UI-06–08, B2 = UI-09–11 + UI-17, B3 = UI-12–16, B4 = UI-18–19). In Phase B the **revert unit is the PR**; commits are ordered one-per-step so a single step can still be reverted by commit range. Every B PR must pass Constitution II at its own gate, so Phase B **never deletes a symbol that a Phase C screen still consumes** (§3.1 alias list).

#### UI-06 · Colour tokens — ramps, semantic roles, dark pairs, aliases, AA test
- **Goal:** land §3.1's `Palette+Ramps`, `Surface`, `Ink`, `Accent`, `Stroke`, `Elevation` with derived dark pairs; alias `NewLook.*`, `Theme.*`, `Palette.medication/medicationFillEnd/sleepIndigo/warning` and the energy/focus ramps to the new tokens so the whole app moves to `#fbfffc` ground / white hairlined cards / green-600 fills on day one; retune `MoodLevel+Palette`.
- **Files:** new `Tokens/*.swift`; `NewLook.swift`, `Theme.swift`, `Palette.swift`, `Palette+Signals.swift`, `MoodLevel+Palette.swift`, `SignalLevel.swift` (`contrastingInk` replaced by explicit `bubbleInk`), `Color+Hex.swift` (unchanged); `app-four/Assets.xcassets/AccentColor.colorset` → green-600; tests `DayCardPaletteTests`, `RecordingMoodDisplayTests`, `StickerSetupViewTests:38–39`, new `TokenContrastTests`.
- **Deliverable:** compile-clean app with the new palette everywhere; a `#Preview` swatch sheet (light/dark). **B1 is a full-app visual change, not an inert foundation:** because `NewLook.*`/`Theme.*` become aliases here, every screen re-colours under the old layouts, glyphs and tab bar. It is the single most visible PR of the project and it leaves `main` in a state no store screenshot matches (risk #4).
- **Verify:** `TokenContrastTests` asserts ≥ 4.5:1 for every text-on-fill pair and ≥ 3:1 for UI pairs in both modes (D14); full suite green serially; **owner device QA = all 8 screens + onboarding + paywall surfaces, light and dark, with a before/after screenshot pack attached to PR B1**. Rule from here to 1.2: **any 1.1.x hotfix is cut from the `v1.1.0` tag, not from `main`.**
- **Est:** 8 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-05; D2, D14, D15.
- ☐ Approved

#### UI-07 · Typography roles (SF, Dynamic-Type-scaled)
- **Goal:** the §3.1 role ramp (DESIGN.md §5.2 names) **with the old role names kept as aliases** (D15 applied to typography): `largeTitle`/`display` → `pageTitle` · `title` → `question` · `headline` → `sectionTitle` · `subheadline` → `rowLabel` · `body` → `narrative` · `callout` → `cardSubtitle` · `caption` (12/400, 63 sites) → `captionQuiet` · `label` (12/500) → `caption` · `moodWord` → `entryTitle` · `timer` → `timerHero` · `duration`/`mono12` → `captionQuiet` + `.monospacedDigit()`; delete only the 0-site roles (`dayCardDate`, `mono(_:)`, `View.typography(_:)`); keep `text(_:weight:relativeTo:)`. 187 `Typography.` references in 33 files cannot be migrated in 3 h and must not be — they migrate screen by screen and UI-49 deletes the aliases. The new 12/500 `caption` is **never** aliased from today's 12/400 `caption` (a name-only alias would silently re-weight 63 call sites).
- **Files:** `Typography.swift` only (aliases carry every call site).
- **Deliverable:** roles + aliases + a preview at 1× / AX5.
- **Verify:** build + suite with zero call-site edits; a one-line grep count per old role recorded in the PR (baseline for UI-49); AX5 preview shows no clipping in the sample sheet; B1 screenshot pack reviewed for the two metric changes (`callout` 15 → 14, `title` 22 → 20).
- **Est:** 3 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-06; D1.
- ☐ Approved

#### UI-08 · Layout tokens + card modifiers + hairline + headings
- **Goal:** `Spacing`/`Radius`/`Metrics` additions and the **0-consumer** deletions only (§3.1); `Radius.card`, `Radius.newLookCard`, `Radius.button/control`, `Palette.sleepIndigo`, `Opacity.*` and every `Metrics.CheckIn.*` member stay as **aliases** until their consumer's PR (UI-21/22/23/25/27/28/30/32) migrates them — UI-49 deletes; `CardStyle` (`.large/.medium/.small/.day/.expandedDay`), `HairlineDivider`, `SectionHeading`, `PageTitleBlock`; `.newLookCard()` becomes an alias of `.card(.large)` until UI-49.
- **Files:** `Spacing.swift`, `Radius.swift`, `Metrics.swift`, new `Components/{CardStyle,HairlineDivider,SectionHeading,PageTitleBlock}.swift`, `NewLook.swift` (alias), `Card.swift` (delete `cardEyebrow`, 1 site).
- **Deliverable:** previews of the five card variants with a row + divider, light/dark.
- **Verify:** build + suite; every card on every tab renders with r 24/18/12 + hairline + tinted shadow (simulator pass).
- **Est:** 5 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-06, UI-07; D16.
- ☐ Approved

#### UI-09 · Button styles (Filled / Outlined / Underline × S/M/L, pressed, disabled, icon slot, violet tint)
- **Goal:** replace `PrimaryButtonStyle`, `CheckInPrimaryButtonStyle`, `SecondaryButtonStyle` (9 call sites) **and 055's `PaywallButtonStyle`** (`app-four/Views/Paywall/PaywallButtonStyle.swift`, present after the re-cut) with the Frame 3 family; pressed = green-700; `.tint(.violet)` for "Log Medications".
- **Files:** `Buttons.swift` (rewrite), call sites `JournalExportSection:71`, `TextCheckInComposer:108`, `DownloadPermissionView:84/89`, `LLMDownloadView:75/84`, `SiriOnboardingView:42`, `WelcomeView:82`, `RecordingDetailView:238`, plus `PaywallButtonStyle`'s call sites in `PaywallStepView`/`PaywallView`/`FailOpenView` (enumerated in UI-05 once `main` includes 055).
- **Deliverable:** previews of the 3 × 3 matrix in default / pressed / disabled, light/dark.
- **Verify:** build + suite; `grep -rn 'checkInPrimary\|\.buttonStyle(.primary)\|\.buttonStyle(.secondary)\|PaywallButtonStyle'` empty; a11y inspector shows button traits and ≥ 44 pt.
- **Est:** 5 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-06–08; D14.
- ☐ Approved

#### UI-10 · BillChip + ChipRow
- **Goal:** the Frame 15 chip (outline / solid / with-dot / solid-with-check) and the wrapping row rule: **display-only rows gap 6/6; interactive rows a ≥ 44-pt row pitch** (chip 27 + gap 17 or chip 36 + gap 8 — D-K6, owner picks; a 44-pt hit frame on a 33-pt pitch would overlap the next row by 11 pt), horizontal hit extension only where neighbours are ≥ 44 apart; `.newLookChip` aliases `.solid`/`.outline` until UI-49.
- **Files:** new `Components/BillChip.swift`, `Components/ChipRow.swift` (moves `FlowLayout` from `app-four/Views/Components/TagFlowView.swift` into the package), `NewLook.swift` (alias `NewLookChipRole` → tint).
- **Deliverable:** previews incl. a 15-chip wrap at 1× and AX5.
- **Verify:** build + suite; `MonthSelectorScrollView` and `ExtractionReviewView` still compile through the alias.
- **Est:** 3 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-06–08.
- ☐ Approved

#### UI-11 · Nav pills, circle icon button, ToggleRow, RadioRow, SegmentedPicker, InfoRow
- **Goal:** the small controls every screen shares (§3.2), each with VoiceOver semantics baked in.
- **Files:** new `Components/{NavPill,ToggleRow,RadioRow,SegmentedPicker,InfoRow}.swift`.
- **Deliverable:** previews; `NavPill` 44 pt hit with 43/24 ⌀ visuals; `SegmentedPicker` with disabled segment state (§3.3 #12).
- **Verify:** build; a11y inspector: pill = button "Back"; toggle = switch; radio group = `.contain` "Dose Guard"; segments ≥ 44 pt hit.
- **Est:** 6 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-06–08; D22.
- ☐ Approved

#### UI-12 · Signal glyphs — mood / energy / focus redraw + identity icons
- **Goal:** Frame 12 geometry as `Canvas` drawings behind the unchanged `SignalGlyph` API (D3): sprout (leaf A/B/vein colours per level + kept crown cue), bolt (`#f8e4c7` base, `#d98232` fill rising 30/48/65/83/100 % via clip mask, `#eda94a` facet), target (`#d6e5f0` ring, `#4278a8` arc sweep per level, `#8ab8d6` disc, `#eda94a` arrow); `IdentityIcon` (level-less) for Insights headers; sizes 14–33.55 with stroke floors.
- **Files:** `Glyphs/SproutGlyph.swift`, `Glyphs/BoltGlyph.swift`, new `Glyphs/TargetGlyph.swift` (deletes `ApertureGlyph.swift`), new `Components/IdentityIcon.swift`, `SignalGlyph.swift`, `GlyphSignal.swift`.
- **Deliverable:** a 4 × 5 preview grid at 33.55 / 24 / 16 in light/dark and a grayscale variant (principle 5 check).
- **Verify:** `SignalGlyphTests` green (names/clamping unchanged); grayscale preview shows five distinguishable levels per signal; build.
- **Est:** 8 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-06; D3 (incl. D3.1–3.3) — **blocked until answered**.
- ☐ Approved

#### UI-13 · Sleep moon glyph + `SleepLevel` ramp / label (logic, test-first)
- **Goal:** `MoonGlyph` (`#e3d7f3` base, `#8c68d3` fill rising 30–100 %, `#bca5e8` highlight, star `#f8e4c7`/`#eda94a` 40.74…54.5), `SleepLevel: SignalLevel` + `displayLabel` (`Restless…Deep`), `GlyphSignal.sleep.variesByLevel = true`; delete `BedIcon.swift` (0 consumers once `SignalGlyph` routes sleep to the moon); **`Palette.sleepIndigo` stays as an alias** of the moon violet — its consumers `ADHDSummarySection.swift:65,70` (UI-27) and `TimelineRow.swift:143` (UI-25) migrate later; UI-49 deletes it.
- **Files:** new `Glyphs/MoonGlyph.swift`, new `Signal/SleepLevel+Palette.swift`, `SignalLevel.swift`, `GlyphSignal.swift`, `SignalGlyph.swift`; tests `SignalGlyphTests` (sleep rows), `RecordingMoodDisplayTests.sleepLabel`.
- **Deliverable:** RED → GREEN tests, then the glyph.
- **Verify:** tests green; preview 5 levels light/dark/grayscale.
- **Est:** 3 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-12; D9, D17.
- ☐ Approved

#### UI-14 · Medication glyphs + ProgressTrack
- **Goal:** `MedicationBadge` (26–28 ⌀ violet-50 tile, 0.42 hairline, violet-800 diagonal outline capsule), `MedicationPill` (card illustration), `ProgressTrack` (10 pt / 6 pt, `#fafafa`, 0.25 hairline, gradient `#8061bf → #8c68d3`, r 9.5, min fill = height); `CapsuleGlyph` restyled to the outline capsule.
- **Files:** `Glyphs/CapsuleGlyph.swift`, new `Components/{MedicationBadge,MedicationPill,ProgressTrack}.swift`.
- **Deliverable:** previews at 0 / 6 / 52 / 100 % fill; onset pulse Reduce-Motion-gated.
- **Verify:** build; `MedicationBarView` still compiles (consumes in UI-25).
- **Est:** 3 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-06, UI-12; D10.
- ☐ Approved

#### UI-15 · `CheckInRing` (+ Welcome migration; `CrescentRing` deleted in UI-21)
- **Goal:** the ring of §3.2 with `progress`, `size` (347 clamp = `min(width − 55, 347)`; 211 saved variant, stroke 12.97), gradient arc, `Elevation.ring`, Reduce-Motion gate, `accessibilityHidden`; `WelcomeView` uses it at 232 pt with `progress: 0`.
- **Files:** new `app-four/Views/CheckIn/CheckInRing.swift`, `WelcomeView.swift:23,52–53`. **`CrescentRing.swift` and `Metrics.CheckIn.crescentDiameter` are not deleted here** — `CheckInView.swift:148–149,195` still consumes both until UI-21 swaps in `CheckInRing(progress: 1/3)`; deleting them in Phase B would fail Constitution II at this PR's gate.
- **Deliverable:** previews at 33 / 66 / 100 %, 347 and 211, light/dark.
- **Verify:** build + suite; onboarding Welcome renders on a 375-wide simulator without overflow; `CrescentRing` has exactly one remaining consumer (`CheckInView`) recorded in the PR.
- **Est:** 5 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-06; D5.
- ☐ Approved

#### UI-16 · `LevelTilePicker`
- **Goal:** the 5-tile picker (D16 narrow rule, D14 selected treatment, tap-again clears, `Low/High` captions, `.isSelected`, Differentiate-Without-Colour badge); generic over `SignalLevel & CaseIterable` like `GlyphRampPicker`.
- **Files:** new `Components/LevelTilePicker.swift` (package); `GlyphRampPicker.swift` deleted in UI-33a after the composer migrates.
- **Deliverable:** previews at 402 / 393 / 375 pt widths and AX5.
- **Verify:** build; a11y inspector reads **"Mood: Good, 4 of 5, selected"** — the pinned `signalAccessibilityLabel` contract (`SignalGlyphTests`) + `.isSelected`, one contract for tiles and glyphs (DESIGN.md §12).
- **Est:** 3 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-12, UI-13; D14, D16.
- ☐ Approved

#### UI-17 · Icon mapping (SF Symbols for the vuesax set)
- **Goal:** the §3.2 map in `Icons.swift`; no icon assets bundled; the `sideEffect` literal sites use the token.
- **Files:** `Icons.swift`; the 18 literal `systemImage:` sites listed in the code map.
- **Deliverable:** the `Icons.swift` table (vuesax name → SF name → sites) + a preview strip of every icon at 13/21/24 pt.
- **Verify:** `grep -rn 'systemImage: "' app-four/Views` → only `Icons.*`.
- **Est:** 1 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-06 · **PR:** B2 (executed with UI-09–11, not parked nine days for B4).
- ☐ Approved

#### UI-18 · `FloatingTabBar` + `AddButton` + root wiring
- **Goal:** D4/D5 as specified: keep `TabView(selection:)`, hide the system bar on every root, overlay bar + FAB in `RootContainerView`, bottom `safeAreaInset` modifier (`.floatingChromeInset()`), hide chrome on Edit / B / C through the **`ChromeVisibilityKey` `PreferenceKey`** (set by those views, read in `RootContainerView` — not `@Environment`, which flows down, and not `.toolbar(.hidden, for: .tabBar)`, which only touches the already-hidden system bar), **FAB hidden on the Check In root** and shown on Calendar / Insights / Settings / Day Details, FAB → `router.requestCheckIn()`, remove `ScreenContainer`'s dead `toolbarBackground(.tabBar)` lines and the stale "Liquid Glass" comments.
- **Files:** new `Components/{FloatingTabBar,AddButton}.swift` (package), `app-four/Views/RootTabView.swift`, `app-four/App/SquirlApp.swift` (`RootContainerView`), `app-four/DesignSystem/ScreenContainer.swift`, `MedicationBarOverlay.swift` (comment), `app-fourTests/Intents/AppIntentRouterTests.swift` (unchanged if D5 = a).
- **Deliverable:** four roots with the pill bar; FAB on three roots + Day Details, absent on the hub; FAB starts B; a11y: container `.accessibilityElement(children: .contain)` + `.accessibilityAddTraits(.isTabBar)`, items `.isSelected`.
- **Verify:** build + suite; device: VoiceOver tab traversal reads "Calendar, tab, 1 of 4, selected" — `.isSelected` alone does not produce "1 of 4" in SwiftUI, so if it is not spoken fall back to `accessibilityValue("\(i) of 4")` and record which path shipped; no FAB on the Check In root; keyboard-up case (composer sheet), Reduce Transparency, iPad (sidebar not required — flag if it breaks), deep link `whispernotes://checkin` still lands on B.
- **Est:** 12 h · **Type:** Story · **Owner:** Claude · **Depends:** UI-06–11, UI-17; D4, D5 — **blocked until answered**.
- ☐ Approved

#### UI-19 · Design gallery + component snapshot pack
- **Goal:** `SandboxApp/Sources/DesignGallery.swift` (xcodegen `project.yml` + `Sources/`; there is no `SandboxApp/DesignGallery.swift`) re-pointed at the new atoms ("real atoms — zero drift"); a snapshot pack (simulator PNGs at 1× / AX5 / dark) of every Phase B component as the review artefact for the B PRs — **attached to the PRs, not committed** to the repo. SandboxApp is knowingly **broken between B2 and B4** (it references atoms B2/B3 replace) and repaired here; it is not a gate for B1–B3.
- **Files:** `SandboxApp/Sources/**`.
- **Verify:** SandboxApp builds; pack attached to the B4 PR.
- **Est:** 3 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-06–18.
- ☐ Approved

### Phase C — Screens (order: check-in trio → Calendar → Day Details → Edit → Insights → Settings)

**Why this order.** The check-in trio is the app's front door and the smallest consumer of foundations (ring, buttons, pills) — it proves the language with the least data risk. Calendar is the launch tab (`selectedTab = .calendar`) and the FAB/tab bar's first real host; it must ship in the same wave as the bar. Day Details is pushed from Calendar and shares its row atoms; Edit is reached only from Day Details' `•••`, so they are one slice (060). Insights has the heaviest data work and the 053 dependency; Settings is last because it is the least tokenised screen, has eight must-keep undrawn rows, and depends on #41 having been resolved in UI-04 (3) and on 055's subscription/legal rows. Each screen: (a) Spec Kit slice (where noted) → (b) HTML mockup with light/dark/AX5 toggles **and the undrawn states** → owner approves the mockup → (c) SwiftUI → build + serial tests → simulator at 402/393/375 → PR.

#### UI-20 · Spec Kit slice 058 — check-in trio
- **Goal:** spec + plan + tasks for A/B/C (UI-21/22/23) + UI-34; Constitution Check vs the branch version (expected 3.1.0); Complexity row if new tokens/components; `/speckit-clarify` uses the matching §7 group.
- **Files:** `specs/058-checkin-trio/*`. **Deliverable:** `specs/058-checkin-trio/{spec,plan,research,data-model,quickstart,tasks}.md` committed before `scripts/worklog.sh`. **Verify:** every UI-xx step in the slice has ≥ 1 task; no task spans model + view + test; Constitution Check passes. **Est:** 3 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-19 merged; D5, D8. ☐ Approved

#### UI-21 · Check-in A · idle hub
- **Goal:** the A frame per D5(a): tab root with the bar and **no FAB** (D4); header (date `weekday(.wide).month(.abbreviated).day()`, 34/600 green-800 "How do you feel?", permanent 16/500 subtitle), `CheckInRing(progress: 1/3)`, button stack Speak (Filled M, `mic.fill`) → Log Medications (Outlined M, violet tint, capsule badge) → Write Notes (Outlined M, `square.and.pencil`), caption 14/500 grey-300; medication bar shown only in `.idle`; `checkInHintSeen` retired; `.paused` deleted; AX ≥ .accessibility1 moves the stack below the ring.
- **Files:** `Views/CheckIn/CheckInView.swift` (idle branch, `captureStage` layout; `:148–149,195` swap `CrescentRing` → `CheckInRing(progress: 1/3)`), **delete `Views/CheckIn/CrescentRing.swift` and `Metrics.CheckIn.crescentDiameter`** (their last consumer is this file — moved here from UI-15), `ViewModels/CheckInViewModel.swift` (`.paused` removal), `Models/AppEnums.swift` (`RecordingState.paused`), `html-mockups/058-checkin-a.html`.
- **Deliverable:** mockup + screen; log FR-017/FR-018 retirements in DEVLOG.
- **Verify:** `CheckInViewModelTests` 32 green (minus `.paused` references); `grep -rn 'CrescentRing\|crescentDiameter'` empty; simulator 402/393/375 × light/dark × 1×/AX5; VoiceOver order date → title (header) → subtitle → Speak → Log → Write → caption; no FAB on this root; Siri deep link still auto-starts.
- **Est:** 15 h · **Type:** Story · **Owner:** Claude · **Depends:** UI-20, UI-15, UI-09, UI-11, UI-14; D7 rows for A.
- ☐ Approved

#### UI-22 · Check-in B · listening
- **Goal:** prompt card (r 18, 24/500 green-800 "How's your mood?", 12→13/500 hint, dots 7.25 ⌀ green-500/green-100 + hairline progress), ring at 2/3 (`flowProgress`, §3.3 #1; listening motion per the owner's D-R2 answer — (a) rotation + glow / (b) static / (c) step + level glow, Reduce-Motion-gated), 72/500 timer (`.monospacedDigit`, clamped), Stop & Save (Filled M, 16 pt `stop.fill`) + Cancel (Outlined M), hint "Take your time, speak freely." with the "Wrapping up soon" text swap, save-failed recovery restyled (Filled + Underline), tab bar + medication bar hidden while `state != .idle`, back pill = `cancelRecording()`.
- **Files:** `CheckInView.swift` (recording branch), `CheckInViewModel.swift` (`flowProgress`), `Typography.swift` (`timer` deleted), `Metrics.swift` (`CheckIn.promptBarHeight/stopGlyph*/promptDot` retuned), tests `CheckInViewModelTests` (+`flowProgressPerState`), `html-mockups/058-checkin-b.html`.
- **Verify:** tests green incl. the pinned prompt copy; timer does not jitter; a 4-s cap cue appears at 7:30 on a simulated clock; device: interruption (phone call) leaves the recording recoverable (documents §7 Q on paused).
- **Est:** 19 h · **Type:** Story · **Owner:** Claude · **Depends:** UI-21, UI-34.
- ☐ Approved

#### UI-23 · Check-in C · saved
- **Goal:** ring at 1.0 (211 ⌀), 96.95 pt green square tile with the check (decorative, hidden), "Check-in saved" 34/600 + two-line 14/500 subtitle (copy per D8; return-nudge question in §7), "Go back home" full-width Filled M pinned to the bottom safe area, hero centred on the frame, Reduce-Motion-gated settle, VoiceOver announcement matches the copy; back pill = same as Go back home; text check-ins also land here (as today).
- **Files:** `CheckInView.swift` (`CheckInSavedView`), `Metrics.swift` (`savedDisc/savedCheck` deleted), `html-mockups/058-checkin-c.html`.
- **Verify:** tests green; SE-class height (667 pt) at AX5 scrolls the hero, CTA never scrolls off.
- **Est:** 10 h · **Type:** Story · **Owner:** Claude · **Depends:** UI-22.
- ☐ Approved

#### UI-24 · Spec Kit slice 059 — Calendar
- **Goal:** spec + plan + tasks for UI-25 + UI-35/36 (and the wave-1 half of the secondary surfaces, UI-33a, if 058 did not carry it); Constitution Check vs the branch version (expected 3.1.0); Complexity row if new tokens/components; `/speckit-clarify` uses the matching §7 group; mockup 059 must show the expanded previous-day card (Q25b).
- **Files:** `specs/059-calendar-journal/*`. **Deliverable:** `specs/059-calendar-journal/{spec,plan,research,data-model,quickstart,tasks}.md` committed before `scripts/worklog.sh`. **Verify:** every UI-xx step in the slice has ≥ 1 task; no task spans model + view + test; Constitution Check passes. **Est:** 3 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-23 merged; D6. ☐ Approved

#### UI-25 · Calendar / Mood Journal
- **Goal:** the iPhone 17 - 19 frame per D6: medication bar restyle (badge, split title 14/600 + 12/500, Title-Case green-600 status via §3.3 #2, 10 pt track), month header 14/600 + chevron (expand kept), week strip (3-letter locale labels per cell, 12/600 numbers, 32 ⌀ green-800 selected disc, green-400 "has check-ins" dots), expanded day card (r 24, fixed mint band `#e6f5ee` with `Okay · Fri 08`, rows with 44 ⌀ pastel avatar + 14/600 word + 14/500 time + 18 pt energy/focus glyphs, dividers, `•••` `Menu` Edit/Delete), "Previous days" heading + tinted collapsed cards (word 16/600 + `MMM d`, signals incl. sleep moon + "8h sleep", medication line name + dose), bottom inset for the floating bar, empty state in the new language, strip fade/compact band kept.
- **Files:** `Views/Library/CalendarLibraryView.swift`, `Components/{CalendarHeaderView,CalendarDayCell,DayCard,FoldedDayCardHeader,DayCardSummary,TimelineRow,MedicationBarView}.swift`, `ViewModels/{MedicationBarViewModel,DayCardSummary}` (§3.3 #2–3), `DesignSystem/MedicationBarOverlay.swift`; tests `FoldedDayCardHeaderTests` (+2), `MedicationBarViewModelTests` (+status), `DayCardPaletteTests` (rewritten in UI-06); `html-mockups/059-calendar.html` (incl. empty / dose-only / transcribing / **expanded previous-day** states). **Preconditions (named, first commits of the PR):** delete `private struct DoseTrack` (`MedicationBarView.swift:133`) before `ProgressTrack` enters the file; delete the private `Chip` in `TimelineRow.swift:99` and `FoldedDayCardHeader.swift:102` before `BillChip`; migrate `Radius.newLookCard` (`DayCard.swift:14`) and `Palette.sleepIndigo` (`TimelineRow.swift:143`) off their aliases.
- **Verify:** suite green (`CalendarStripFadeTests` 10 untouched); simulator: 3-row bar state, AX5 weekday labels fall back to single letters, VoiceOver row label reads `displayLabel`s; device QA on a month with cross-month data (Aug 30 must **not** appear under September — D6.4).
- **Est:** 30 h · **Type:** Story · **Owner:** Claude · **Depends:** UI-24, UI-18, UI-12–14, UI-35, UI-36, UI-37 (#45 merged in UI-04).
- ☐ Approved

#### UI-26 · Spec Kit slice 060 — Day Details + Edit
- **Goal:** spec + plan + tasks for UI-27/28 + UI-38/39; Constitution Check vs the branch version (expected 3.1.0); Complexity row if new tokens/components; `/speckit-clarify` uses the matching §7 group.
- **Files:** `specs/060-day-details-edit/*`. **Deliverable:** `specs/060-day-details-edit/{spec,plan,research,data-model,quickstart,tasks}.md` committed before `scripts/worklog.sh`. **Verify:** every UI-xx step in the slice has ≥ 1 task; no task spans model + view + test; Constitution Check passes. **Est:** 4 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-25 merged (wave 1 shipped); D18, D19, D21, D23, D24. ☐ Approved

#### UI-27 · Day Details
- **Goal:** the iPhone 17 - 1 frame per D7/D18: custom header (back pill, relative title 18/600 + `EEEE, MMM d · HH:mm` 12/500, `•••` `Menu` = Edit · Transcript · Delete), tab bar + FAB visible, "How do you feel today?" signal card (Mood · Focus · Energy columns, 14/500 label + 12/600 AA-safe value + `level/5` 86 × 4 bar, diagonal hairlines, AX-size vertical fallback), Emotions chip row (solid green-600, no card), Sleep + Side-effects chip rows (kept), "Your medications" style-S rows (`Name · dose` formatter, badge; `(missed)` shown as a status word — §7), "Daily check-in" composite card (sparkle caption above, `narrative` 16 pt body, divider, inline player 27.75 visual / 44 hit, width-derived quantised waveform, single duration format; states: generating · fallback-transcript guard · text check-in (player hidden) · transcribing · pending · failed + Retry), Transcript disclosure, bottom inset, deferred delete pattern kept.
- **Files:** `Views/RecordingDetailView.swift`, `ViewModels/RecordingDetailViewModel.swift` (§3.3 #5; dead methods deleted with their tests, **including #45's `performSummarization` med-refresh hunk and its test** — D7), `Components/{ADHDSummarySection,TagFlowView,AudioPlayerView,PlaybackWaveformBars}.swift` (`ADHDSummarySection.swift:65,70` migrates off the `Palette.sleepIndigo` alias), `Store/RecordingStore.swift` + `CheckInViewModel.swift` recovery copy (still true: "Tap to retry in the recording detail view"), `html-mockups/060-day-details.html` (all six card states + text check-in + AX5 + dark). The single duration format is already on `main` via UI-54.
- **Verify:** `RecordingDetailViewModelTests` — **re-baselined after #45** (#45 adds +13 lines to this file; count = post-#45 count − the regenerate tests + `relativeTitleByDay`); simulator: text check-in shows no player and no AI byline on a fallback transcript; device: swipe-back still pops with the custom header.
- **Est:** 35 h (the 6 h summary-correction editor is deferred to UI-43, outside waves 1–2) · **Type:** Story · **Owner:** Claude · **Depends:** UI-26, UI-38, UI-54 merged.
- ☐ Approved

#### UI-28 · Edit Check-In
- **Goal:** the iPhone 17 - 18 frame per D7/D21/D23: pushed page (second `navigationDestination` on the Calendar stack), back pill + 18/600 title, tab bar hidden, "Date & time" bare heading + styled fields → sheet pickers, "How did you feel?" collapsible card (mood/energy/focus `LevelTilePicker` rows with 12/600 value word, `Low/High`, Sleep chip row `Restless…Deep` + compact hours field), Medication card (catalog chips green; one row per med: `<Name> dose` label, dose chips, Taken/Missed segment, remove), Emotions / Side effects cards (wrapping `ChipRow`, 14/500 group labels), full-width "Save changes" (dirty-gated, §3.3 #6), `cancelIfUnsaved()` on disappear, narrow-device tile rule, Reduce-Motion-gated collapse.
- **Files:** `Views/ExtractionReviewView.swift` (**precondition:** delete the private `ChipGroup` model at `:8` and migrate `Radius.newLookCard` at `:349–350` before the package `ChipGroupView` / `BillChip` enter the file), `ViewModels/ExtractionReviewViewModel.swift`, `Views/Library/CalendarLibraryView.swift` (destination), `Views/RecordingDetailView.swift` (`•••` → push), `NewLook.swift` (`NewLookNavBar` deleted), tests `ExtractionReviewViewModelTests` (12 → 12 rewritten/added), `html-mockups/060-edit-checkin.html` (incl. collapsed cards, Elvanse 6-strength row, the D-K6 interactive chip pitch, AX5).
- **Verify:** tests green; provenance tags still written for mood/energy/focus/medication/emotions; simulator 393 pt shows 52-pt tiles; VoiceOver: tiles announce **`"Mood: Good, 4 of 5, selected"`** (the pinned `signalAccessibilityLabel` contract + `.isSelected` — same string as UI-16), collapse buttons announce `Expanded/Collapsed`; no two interactive chips' hit areas overlap (a11y inspector).
- **Est:** 27 h · **Type:** Story · **Owner:** Claude · **Depends:** UI-27, UI-16, UI-39.
- ☐ Approved

#### UI-29 · Spec Kit slice 061 — Insights
- **Goal:** spec + plan + tasks for UI-30 + UI-41; Constitution Check vs the branch version (expected 3.1.0); Complexity row if new tokens/components; `/speckit-clarify` uses the matching §7 group.
- **Files:** `specs/061-insights/*`. **Deliverable:** `specs/061-insights/{spec,plan,research,data-model,quickstart,tasks}.md` committed before `scripts/worklog.sh`. **Verify:** every UI-xx step in the slice has ≥ 1 task; no task spans model + view + test; Constitution Check passes. **Est:** 3 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-28 merged; D12 executed; UI-40 merged. ☐ Approved

#### UI-30 · Insights
- **Goal:** the iPhone 17 - 7 frame: page title block, `SegmentedPicker` month selector (prev · selected · next, next disabled at the current month, `MMMM yyyy`), Card 1 "Mood check-in breakdown" (bubbles per §3.3 #8 rule, explicit inks, divider, `BillChip(.withDot)` legend wrapping), Card 2 "Your month in three signals" (identity icon + 14/500 label + AA-safe tag, 33.55 glyphs, 12/500 weekdays, solid 18 ⌀ empty circles, dividers; no sleep chip), Card 3 "Where you averaged" (`RangeBar` rows with canonical Energy/Focus words, bracket, whole-number rule), Card 4 "Your daily rhythm" (uppercase headers with narrow fallback, icon row labels, 44 ⌀ tinted cells with glyphs via the tint fn), Connections (16/600 title + caption with the **real** gates, r 18 cards with lock/unlock tiles, gradient bar, code copy kept, order per §7), dead route + `selectedTab` removed, bottom inset. (The Sleep × Mood gate fix is **not** in this PR — UI-40 shipped it earlier as `fix/insights-sleep-mood-gate`.)
- **Files:** `Views/InsightsView.swift`, `Views/Insights/*` (`SignalAverageGauges.swift` deleted; new `RangeBar.swift`; the month selector uses the package `SegmentedPicker`; **preconditions:** delete `private struct ConnectionCard` / `GatedCard` / `MiniBar` in `ConnectionCardsView.swift:19/74/110` before the package `ConnectionCard` / `SignalMiniBar` enter the file, and migrate `Radius.newLookCard` at `:97–99`; the rhythm view uses `RhythmTile`, leaving the `RhythmCell` model untouched), `ViewModels/InsightsViewModel+Signals.swift`, tests `InsightsViewModelTests` (**re-baselined after #45**, which adds +10 lines; + ~5 new), `html-mockups/061-insights.html` (incl. the per-month empty state).
- **Verify:** tests green incl. the two caption tests per D8; simulator: `Distracted`/`Locked In` fit or wrap by rule; empty month renders the picker + empty state; device: 24 check-ins vs mood-resolved count question answered in the header copy.
- **Est:** 29.5 h (31 − the 1.5 h now in UI-40) · **Type:** Story · **Owner:** Claude · **Depends:** UI-29, UI-40 merged, UI-41.
- ☐ Approved

#### UI-31 · Spec Kit slice 062 — Settings + wave-2 secondary surfaces
- **Goal:** spec + plan + tasks for UI-32 + UI-42 + UI-33b; Constitution Check vs the branch version (expected 3.1.0); Complexity row if new tokens/components; `/speckit-clarify` uses the matching §7 group; the 062 mockup designs every undrawn `ModelDownloadRow` state (not installed / downloading / error / delete) so nothing is re-implemented in UI-32.
- **Files:** `specs/062-settings/*`. **Deliverable:** `specs/062-settings/{spec,plan,research,data-model,quickstart,tasks}.md` committed before `scripts/worklog.sh`. **Verify:** every UI-xx step in the slice has ≥ 1 task; no task spans model + view + test; Constitution Check passes. **Est:** 3 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-30 merged; #41 resolved in UI-04 (3); 055 rows present; D11, D22. ☐ Approved

#### UI-32 · Settings
- **Goal:** the iPhone 17 - 16 frame plus the eight must-keep rows (D7): `List` → `ScrollView` of `[heading → card]` groups (scroll-to-top and the My-Medication intent anchor ported to `ScrollPosition`), page title block, Check-in calendar card (Voice prompts chips Brisk/Relaxed explicit order + description; Calendar cards toggles Auto-expand → Always expand), Voice & storage card (Voice Transcription **and** Journal Insights `ModelDownloadRow` **restyled only** — tokens, card, chips, sizes from the 062 mockup; its state machine, view-model bindings and tests are **untouched**: CLAUDE.md marks the model-download path as load-bearing and already hardened by specs 041/044, and a 39.5-h UI PR is not where it gets re-opened — the ~150 MB / ~740 MB copy fix belongs to UI-48; Recording "34 MB · N recordings"; Download over cellular + corrected description), Confirmations card (top-aligned toggle + description; preview chip mirrors `DoseConfirmationCopy` exactly incl. OFF state; **My Medication** picker kept as chips), Dose Guard card (radio rows, 1h–4h chips with check badge shown only for Time window, three footnotes), Medication bar card (4 toggle rows incl. Show taken time / Show end time via §3.3 #9, dependency rule), Accessibility info row, Your data card (statement + Privacy Policy + Terms (055) + Acknowledgements + export row + `RecoveryKeySheet` restyle + Subscription/Restore (055) + Clear all data destructive row + version + ephemeral warning state), medical disclaimer row, bottom inset ≥ 170.
- **Files:** `Views/SettingsView.swift` (`TestServicesView` sheet stays DEBUG-only as #44/#41 left it), `Views/Settings/*` (all seven + 055's `SubscriptionSection`, `LegalDocumentView`, `ExportJournalButton`; **precondition:** delete `private struct SettingsChip` in `MyMedicationSection.swift:182` before `BillChip`; migrate `Radius.card` in `JournalExportSection.swift:55`), `Components/ModelDownloadRow.swift` (view body only), `ViewModels/SettingsViewModel.swift` (unchanged unless the bar keys move in; if the owner wants the medical-prompt toggle surfaced, it is added here and nothing is deleted — see UI-44), `MedicationBarView.swift` (`titleLine`), tests `MedicationBarViewModelTests` (+3), `SettingsViewModelTests` (22 untouched), `html-mockups/062-settings.html` (all model-row states, OFF preview, destructive row, AX5, dark).
- **Verify:** suite green; simulator: skip-then-download LLM path works from Settings; `LogDefaultDoseIntent` "not configured" continuation scrolls to My Medication; VoiceOver: headings, switches, radio group; device: export → recovery key → copy works with no subscription.
- **Est:** 39.5 h · **Type:** Story · **Owner:** Claude · **Depends:** UI-31, UI-42; UI-04 (#41 resolved).
- ☐ Approved

#### UI-33a · Secondary surfaces, wave 1 (never drawn in the pen)
- **Goal:** token/component inheritance for the surfaces wave 1 ships with: `MedicationLogSheet` (nav → back pill + Filled Save; 30 pt close → 44; chips → `BillChip`), `TextCheckInComposer` (`LevelTilePicker` replaces `GlyphRampPicker`, which is then deleted; note box card S; Filled Save), onboarding ×4 restyle (Filled/Outlined buttons, card M for the Siri phrases, progress tint — the Welcome ring migration itself is **UI-15's**, not re-counted here), Feedback/sticker left unmounted.
- **Files:** `Components/MedicationLogSheet.swift`, `Views/CheckIn/TextCheckInComposer.swift`, `Views/Onboarding/*`; `Components/GlyphRampPicker.swift` deleted. **Spec:** 058 or 059 (the slice cut before it runs — never spec-less).
- **Verify:** build + suite (`OnboardingViewModelTests` 12, `CheckInNoteStoreTests` 5); simulator run of the whole onboarding chain on a fresh install; a11y: composer close button 44 pt; `grep -rn GlyphRampPicker` empty.
- **Est:** 8 h · **Type:** Story · **Owner:** Claude · **Depends:** UI-20/UI-24; UI-09–16.
- ☐ Approved

#### UI-33b · Secondary surfaces, wave 2
- **Goal:** `RecoveryKeySheet` (card S key well, Filled "Copy key"), 055 custom paywall surfaces (`PaywallStepView`, `PaywallView`, `TrialTimeline`, `FailOpenView`, `PlanCard`, `PaywallLegalFooter` — fine print in `Ink.primary`, D11; `RevenueCatPaywallHost` is **untouched**, dashboard-styled), `AcknowledgementsView` restyle only — adding the **MLX + Qwen** credits is a legal-credits fix, not a refresh item: its own `fix/acknowledgements-credits` ticket, mergeable any time.
- **Files:** `Views/Settings/JournalExportSection.swift` (`RecoveryKeySheet`), `Views/Paywall/*` except `RevenueCatPaywallHost.swift`, `Views/Settings/AcknowledgementsView.swift`.
- **Verify:** build + suite (purchase suites); paywall surfaces at AX5 stack without clipping; export → recovery key → copy works with no subscription.
- **Est:** 8 h · **Type:** Story · **Owner:** Claude · **Depends:** UI-31; UI-09–16.
- ☐ Approved

### Phase D — Data gaps (test-first; each scheduled immediately before its consumer; hours already inside the screen estimates unless marked NEW)

| ID | Step (§3.3 #) | Files | Test first | Est | Depends | Consumer |
|---|---|---|---|---|---|---|
| UI-34 | `CheckInViewModel.flowProgress` (#1) | `ViewModels/CheckInViewModel.swift`, `CheckInViewModelTests` | `flowProgressPerState` | 1 h (in UI-22) | UI-20 | UI-22 ☐ |
| UI-35 | `DoseStatus` hoist + status semantics (#2, D10) | `ViewModels/MedicationBarViewModel.swift`, `MedicationBarView.swift`, `MedicationBarViewModelTests` | threshold + boundary tests | 2 h (in UI-25) | UI-24 | UI-25 ☐ |
| UI-36 | `DayCardSummary` dose + `sleepLevel` (#3) | `Components/DayCardSummary.swift`, `FoldedDayCardHeaderTests` | two `@Test`s | 1.5 h (in UI-25) | UI-13 | UI-25 ☐ |
| UI-37 | `displayLabel` in `TimelineRow` + AX (#4) | — | — | 0 h (PR #45) | UI-04 | UI-25 ☐ |
| UI-38 | `RecordingDetailViewModel.relativeTitle/subtitle` (#5) | `ViewModels/RecordingDetailViewModel.swift`, `RecordingDetailViewModelTests` | `relativeTitleByDay` | 0.5 h (in UI-27) | UI-26 | UI-27 ☐ |
| UI-39 | `ExtractionReviewViewModel.isDirty`, `medicationRows`, `cancelIfUnsaved()` (#6, D21) | `ViewModels/ExtractionReviewViewModel.swift`, `ExtractionReviewViewModelTests` | 3 new + 3 rewritten | 5.5 h (in UI-28) | UI-26 | UI-28 ☐ |
| UI-40 | Sleep × Mood gate on `decodedSleepLevel` (#7) — **own PR `fix/insights-sleep-mood-gate`, mergeable now, shippable in 1.1.x** (copy unchanged) | `ViewModels/InsightsViewModel+Signals.swift`, `InsightsViewModelTests` | RED with canonical values | 1.5 h (own PR) | UI-04 (#45 merged) | UI-29/UI-30 depend on it ☐ |
| UI-41 | Bubble diameter fn · rhythm tint fn · range-bar span fn · caption case (#8, #12) | new `Views/Insights/{MoodBubbleLayout,RhythmTint,RangeSpan}.swift`, `InsightsViewModel.swift`, tests | three test files + 2 edits | 3 h (in UI-30) | UI-29 | UI-30 ☐ |
| UI-42 | `medicationBarShowTakenTime` / `ShowEndTime` keys + `titleLine` (#9) | `ViewModels/MedicationBarViewModel.swift`, `MedicationBarView.swift`, `Views/Settings/MedicationBarSettingsSection.swift`, `MedicationBarViewModelTests` | `titleLineVariants` | 3 h (in UI-32) | UI-31 | UI-32 ☐ |
| UI-43 | Summary correction persistence (#10, D19) — **deferred, outside waves 1–2** | `Models/RecordingTag.swift` (`TagCategory.summary`), `RecordingDetailViewModel`, tests | `summaryEditWritesTagAndColumns` | 6 h (wave 3 or drop) | owner | ☐ |
| UI-54 | Single `formattedDuration` (#5, second half) — **own PR `fix/duration-format`, mergeable now** | `Models/Recording.swift`, `RecordingTests` | `durationFormatIsSingle` | 0.5 h NEW (own PR) | UI-04 | UI-27 ☐ |

### Phase E — Accessibility · dark mode · copy · dead code · token deletion (one PR per pass)

#### UI-44 · Dead-code sweep
- **Goal:** delete **only what the refresh itself orphans**, listed per screen PR: `Card.swift` `cardEyebrow` (UI-08), `app-four/wireframes/*` (5 files compiled but unreferenced — orphaned by the screen rewrites), `RecordingDetailViewModel` dead methods + `RecordingStore.toggleFavorite/updateTitle` (UI-27), `InsightsViewModel.prevMonth/nextMonth/jumpToToday` if UI-30 did not wire them, `GlyphRampPicker` (UI-33a), `NewLookNavBar` (UI-28) — each with its test edits. **Not in scope:** `RecordingRow.swift` and `Components/Chip.swift` are **gone with PR #44**; `TestServicesView.swift` **stays** (DEBUG-only after #44) regardless of #41; `SettingsViewModel.medicalPromptEnabled` (`:43–51`) + its `SettingsViewModelTests` test (`:77–99`) and `DayTimeline.Node.rings` are **pre-existing** orphans that belong to the audit PRs or a follow-up `fix/`, not to a refresh PR (if the owner wants the medical-prompt toggle surfaced, UI-32 adds it and nothing is deleted). **`Constants.swift:46–58` (`SettingsKeys.medicalPromptEnabled` + `UserDefaults.medicalPromptEnabled`) is live code — `WhisperKitTranscriptionService.swift:134` reads it to decide whether Whisper gets the medical prompt tokens; deleting it breaks transcription or silently changes its quality for every user. Never delete.**
- **Verify:** build + suite; `grep` proofs in the PR description; `grep -rn medicalPromptEnabled app-four/Services` still hits `WhisperKitTranscriptionService.swift:134`.
- **Est:** 3 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-32. ☐ Approved

#### UI-45 · Dark-mode pass (wave-2 screens; wave 1 was covered by UI-53)
- **Goal:** device QA of every derived pair (D2) on Day Details, Edit, Insights, Settings + the wave-2 secondary surfaces (the four wave-1 screens were passed in UI-53 and are re-checked only where a wave-2 token changed); fixes to tokens only.
- **Verify:** `TokenContrastTests` dark half green; screenshot pack light/dark per screen attached to the PR.
- **Est:** 6 h · **Type:** Task · **Owner:** Claude + Owner · **Depends:** UI-33b. ☐ Approved

#### UI-46 · Dynamic Type / AX-size layout pass
- **Goal:** AX1–AX5 on the wave-2 screens (+ a re-check of wave 1): check-in stack below the ring, Day Details columns stack, Edit date columns stack, weekday labels fall back, range-bar labels wrap, chip rows wrap, fixed-height boxes hug, no `lineLimit(1)` corner cuts.
- **Verify:** simulator matrix (402/393/375 × 1×/AX3/AX5) screenshots; no clipping, no overlap.
- **Est:** 6 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-45. ☐ Approved

#### UI-47 · VoiceOver + Reduce Motion pass
- **Goal:** every custom control has label/value/traits (tab bar, FAB, pills, chips, tiles, radio, toggles, `•••` menus, ring value if meaningful); every animation gated; announcements match copy.
- **Verify:** device VoiceOver walkthrough script (one per screen) checked off in the PR.
- **Est:** 4 h · **Type:** Task · **Owner:** Claude + Owner · **Depends:** UI-46. ☐ Approved

#### UI-48 · Copy normalisation sweep (D8)
- **Goal:** **pen-screen strings only** — the D8 typo list, casing policy, units (`34 MB`, `18 mg`, `2 h`), the Connections caption vs real gates, and the `ModelDownloadRow` size copy (`~150 MB` / `~740 MB`) that UI-32 deliberately left alone. Out of scope (pre-existing drift, own `fix/` tickets if wanted): the "approx. 40MB" download alert, onboarding "three-screen" comments.
- **Verify:** pinned copy tests unchanged; `grep -rn` for each old string empty.
- **Est:** 3 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-32. ☐ Approved

#### UI-49 · Token deletion (close the coexistence window)
- **Goal:** delete `NewLook.swift`, `Theme.swift`, the old `Palette` members and ramps, `.newLookCard/.newLookChip/.newLookCardShadow` aliases, `NewLookChipRole`, `Opacity.moodBlock/moodBadge`, `Radius.newLookCard/card/button`; update `SandboxApp/DesignGallery`; close the Complexity Tracking row in `specs/057-ui-refresh/plan.md`.
- **Verify:** `grep -rn 'NewLook\.\|Theme\.\|newLookCard\|newLookChip' app-four Packages SandboxApp` empty; build + suite.
- **Est:** 6 h · **Type:** Task · **Owner:** Claude · **Depends:** UI-44–48. ☐ Approved

#### UI-53 · Wave-1 dark / AX / VoiceOver mini-pass (A/B/C + Calendar + Log Dose / composer)
- **Goal:** the pass that actually gates 1.2 — UI-45/46/47 depend on UI-33b → wave 2, so a wave-1 release cannot wait for them. Light/dark device check of every derived pair on the four wave-1 screens + `MedicationLogSheet` / `TextCheckInComposer`; AX1–AX5 matrix (402/393/375) for the same; VoiceOver script per screen (tab bar "1 of 4", FAB label, ring hidden, tile contract, `•••` menus).
- **Files:** token fixes only in `Packages/SquirlDesignSystem`; per-screen VoiceOver scripts attached to the PR.
- **Verify:** light/dark screenshot pack for the four screens + two sheets; VoiceOver scripts checked off on device; `TokenContrastTests` green.
- **Est:** 6 h · **Type:** Task · **Owner:** Claude + Owner · **Depends:** UI-25 merged, UI-33a merged.
- ☐ Approved

### Phase F — QA gates and release

#### UI-50 · PR gate (recurring, every PR) and PR strategy
- **Rule:** one PR per **step** in Phase B is too granular for owner QA, so Phase B ships as **four PRs** (B1 tokens/typography/layout · B2 buttons/chips/controls/icons · B3 glyphs/ring/tiles · B4 tab bar/FAB/gallery) — but **B1 is not inert**: it re-colours every screen app-wide (UI-06), so its gate is a full-app device QA (all 8 screens + onboarding + paywall surfaces, light and dark, before/after screenshot pack), and from B1 until 1.2 ships any 1.1.x hotfix is cut from the `v1.1.0` tag, not from `main`. In Phase B the revert unit is the PR, with commits ordered one-per-step so a step can be reverted by commit range. Phase C ships **one PR per screen** (user-visible, needs device QA each — "one PR = one revertable feature"); pure-logic bugs the cross-checks found ship **early as their own `fix/` PRs** (UI-40, UI-54), never inside a restyle; the other Phase D steps ride inside their consumer's PR (test-first commits come first in the PR history); Phase E ships one PR per pass. PRs are **sequential, never stacked**: the next branch is cut only after the previous PR merges (Constitution V).
- **Gate per PR:** build → full suite **serially** (`-parallel-testing-enabled NO`; the suite is not parallel-safe) → fresh `-resultBundlePath` → `xcrun xcresulttool` summary in the PR → `/code-review` findings addressed → **owner device QA on the iPhone 12 Pro / 17 class** (checklist from the step's Verify line) → merge → `scripts/worklog.sh` → DEVLOG line at real checkpoints. **Known CLI landmine (risk #11):** the full suite can crash under `xcodebuild test` with a nondeterministic SwiftData `EXC_BREAKPOINT` in `DoseLogServiceTests` (0 assertion failures; clean under the owner's ⌘U — `docs/DEVLOG.md:123`), and `ios-debugger-agent`/XcodeBuildMCP has historically been "not connected" — on a 0-assertion-failure crash, rerun once, then the owner's ⌘U run counts; record the workaround per PR.
- **Est:** ≈ 1.5 h × ~25 PRs = 37.5 h · **Type:** Task · **Owner:** Owner + Claude. ☐ Approved

#### UI-51 · Release 1.2 (wave 1: foundations + chrome + check-in trio + Calendar)
- **Goal:** App Store submission with **refreshed screenshots** (App Review 2.3 Accurate Metadata / **2.3.3** — screenshots must reflect the shipping UI; 6.7"/6.1" sets, light; dark optional), What's New copy (no growth tactics), privacy nutrition label unchanged (no new data flows), `PrivacyInfo.xcprivacy` unchanged, tag `v1.2.0` on the TestFlight upload commit, TestFlight sanity build first.
- **Files:** `fastlane/`-free manual ASC upload; `docs/release/1.2-screenshots/`; **`docs/BACKLOG.md` only** moved to ✅ Shipped (`shipaton_plan/` is a frozen archive after the Oct 1 ritual).
- **Verify:** TestFlight build installs on a grandfathered 1.0 device without the paywall (055 rule); export works signed-out of any subscription.
- **Est:** 9 h · **Type:** Task · **Owner:** Owner + Claude · **Depends:** UI-25 merged, UI-33a merged, **UI-53** (UI-45/46/47 are wave-2 and cannot gate a wave-1 release). ☐ Approved

#### UI-52 · Release 1.3 (wave 2: Day Details + Edit + Insights + Settings + polish)
- Same gate as UI-51 (2.3.3 screenshots for the four wave-2 screens); tag `v1.3.0`; `docs/BACKLOG.md` rows → ✅ Shipped; submit before the year-end App Review slowdown (target Fri Dec 18).
- **Est:** 9 h · **Depends:** UI-49. ☐ Approved

### 4.8 Ticket table (copy into `shipaton_plan/SEPTEMBER_PLAN.md` Epic UI before Oct 1, `docs/BACKLOG.md` after — format `ID | Summary | Type | Est | Owner | Depends | Acceptance criteria`; one row = one issue key, so every Phase D id has its own row and "in UI-xx" marks hours already inside the consumer's estimate; the Est column sums to 425 h)

| ID | Summary | Type | Est | Owner | Depends | Acceptance criteria |
|---|---|---|---|---|---|---|
| UI-01 | DESIGN.md v2 (pen-derived) + CLAUDE.md/PRODUCT.md reconciled + pen exports committed | Design | 6 | Claude | D1–D5, D8, D9, D14 | docs PR to `main` before #44; all 79 references + `test -e` paths resolve; posture/paywall sections carried; decisions log seeded |
| UI-02 | Decisions D1–D26 answered and logged | Task | 2 | Owner | — | no ★ item open |
| UI-03 | Plan → Epic UI table, BACKLOG 🧊 rows, DEVLOG | Task | 1.5 | Claude | UI-02 | docs PR to `main`; IDs stable; WORKLOG regenerated |
| UI-04 | Pre-flight: docs on main → #44 → #45 → #41 resolved → 055 merge + 1.1 (RC ETA) → 053/054 archived → ritual → worktrees removed, 057 re-cut | Task | 5 | Owner + Claude | UI-03; RC epic | `main..feat/057` empty; 053 stash entry gone, 15 others intact; Release build green; skills + constitution 3.1.0 present |
| UI-05 | Spec Kit 057 foundations | Task | 4 | Claude | UI-04 (6) | Constitution Check I–XI vs branch version (3.1.0); tasks map to UI-06…19; 055 view files enumerated |
| UI-05b | Design-system HTML mockup (Constitution I for Phase B atoms) | Design | 4 | Claude + Owner | UI-02, UI-01 | every §3.2 atom in all states, light/dark, 1×/AX5, 402/375; owner approval logged |
| UI-06 | Colour tokens + dark pairs + aliases + AA tests (PR B1 = full-app visual change) | Task | 8 | Claude | UI-05, UI-05b | `TokenContrastTests` green; full-app device QA light/dark with before/after pack; `Palette.medication` = violet-500 |
| UI-07 | Typography roles + alias map (old names kept until UI-49) | Task | 3 | Claude | UI-06 | zero call-site edits; 0-site roles gone; no silent re-weight; AX5 preview clean |
| UI-08 | Layout tokens + card modifiers + heading atoms (0-consumer deletions only) | Task | 5 | Claude | UI-07 | five card variants preview light/dark; consumed symbols aliased, not deleted |
| UI-09 | Button styles (Frame 3) replace three old styles + `PaywallButtonStyle` | Task | 5 | Claude | UI-08 | all call sites migrated; pressed/disabled states |
| UI-10 | BillChip + ChipRow (display 6/6; interactive ≥ 44 pt pitch, D-K6) | Task | 3 | Claude | UI-08 | four variants; wrap at AX5; no overlapping hit areas |
| UI-11 | NavPill, ToggleRow, RadioRow, SegmentedPicker, InfoRow | Task | 6 | Claude | UI-08 | a11y traits verified |
| UI-12 | Mood/energy/focus glyph redraw + identity icons | Task | 8 | Claude | UI-06, D3 | grayscale-distinct levels; `SignalGlyphTests` green |
| UI-13 | Sleep moon + `SleepLevel` ramp/label (`sleepIndigo` aliased) | Task | 3 | Claude | UI-12 | tests first; bed icon deleted; alias compiles |
| UI-14 | Medication glyphs + ProgressTrack + SignalMiniBar | Task | 3 | Claude | UI-12 | previews 0–100 % |
| UI-15 | `CheckInRing` + Welcome migration (`CrescentRing` kept until UI-21) | Task | 5 | Claude | UI-06, D5 | 375 pt fits; one remaining `CrescentRing` consumer recorded |
| UI-16 | `LevelTilePicker` | Task | 3 | Claude | UI-13 | narrow-device rule; "Mood: Good, 4 of 5, selected" |
| UI-17 | SF Symbol icon map (PR B2) | Task | 1 | Claude | UI-06 | `Icons.swift` table + preview strip; no literal `systemImage:` in views |
| UI-18 | FloatingTabBar + AddButton + root wiring (`ChromeVisibilityKey`; FAB hidden on hub) | Story | 12 | Claude | UI-11, UI-17, D4, D5 | VoiceOver "tab, 1 of 4" verified or fallback; deep link → B; chrome hides on Edit/B/C; no FAB on Check In |
| UI-19 | Design gallery (`SandboxApp/Sources/DesignGallery.swift`) + snapshot pack attached to PRs | Task | 3 | Claude | UI-18 | SandboxApp builds; pack attached to B4 PR |
| UI-20 | Spec Kit 058 check-in trio | Task | 3 | Claude | UI-19 | spec/plan/tasks committed; every step has ≥ 1 task |
| UI-21 | Check-in A idle hub (+ `CrescentRing`/`crescentDiameter` deleted) | Story | 15 | Claude | UI-20 | mockup approved; 32 VM tests green; FR-017/018 retired on record; no FAB on hub |
| UI-22 | Check-in B listening (motion per D-R2) | Story | 19 | Claude | UI-21, UI-34 | prompt copy tests green; timer stable |
| UI-23 | Check-in C saved | Story | 10 | Claude | UI-22 | SE-height AX5 OK; announcement matches copy |
| UI-24 | Spec Kit 059 Calendar (incl. expanded previous-day card, Q25b) | Task | 3 | Claude | UI-23 | spec/plan/tasks committed |
| UI-25 | Calendar / Mood Journal (private `Chip`/`DoseTrack` deleted first) | Story | 30 | Claude | UI-24, UI-35, UI-36, UI-37 | month-scoped previous days; `displayLabel`s spoken |
| UI-26 | Spec Kit 060 Day Details + Edit | Task | 4 | Claude | UI-25 | spec/plan/tasks committed |
| UI-27 | Day Details (#45 regenerate hunk deleted here) | Story | 35 | Claude | UI-26, UI-38, UI-54 | six card states; no AI byline on fallback transcript; tests re-baselined post-#45 |
| UI-28 | Edit Check-In (private `ChipGroup` deleted first) | Story | 27 | Claude | UI-27, UI-39 | 12 VM tests green; provenance intact; tile contract string |
| UI-29 | Spec Kit 061 Insights | Task | 3 | Claude | UI-28, D12, UI-40 | spec/plan/tasks committed |
| UI-30 | Insights (private `ConnectionCard`/`GatedCard`/`MiniBar` deleted first) | Story | 29.5 | Claude | UI-29, UI-40, UI-41 | tests re-baselined post-#45; `RhythmTile` view, `RhythmCell` model untouched |
| UI-31 | Spec Kit 062 Settings + wave-2 secondary surfaces | Task | 3 | Claude | UI-30, UI-04 (#41) | spec/plan/tasks committed; every `ModelDownloadRow` state mocked |
| UI-32 | Settings (`ModelDownloadRow` restyled, state machine untouched; `SettingsChip` deleted first) | Story | 39.5 | Claude | UI-31, UI-42 | eight must-keep rows present; model-row tests untouched |
| UI-33a | Secondary surfaces, wave 1 (Log Dose, composer, onboarding restyle) | Story | 8 | Claude | UI-20/24, UI-09–16 | onboarding chain runs; 44 pt close buttons; `GlyphRampPicker` gone |
| UI-33b | Secondary surfaces, wave 2 (recovery key, 055 paywall surfaces, Acknowledgements restyle) | Story | 8 | Claude | UI-31 | paywall surfaces AX5 clean; export works unsubscribed |
| UI-34 | `CheckInViewModel.flowProgress` (test-first) | Task | 1 (in UI-22) | Claude | UI-20 | RED → GREEN before UI-22 |
| UI-35 | `DoseStatus` hoist + status semantics (D10) | Task | 2 (in UI-25) | Claude | UI-24 | threshold + boundary tests green |
| UI-36 | `DayCardSummary` dose + `sleepLevel` | Task | 1.5 (in UI-25) | Claude | UI-13 | two `@Test`s green |
| UI-37 | `displayLabel` in `TimelineRow` + AX | Task | 0 (PR #45) | — | UI-04 | merged with #45 |
| UI-38 | `RecordingDetailViewModel.relativeTitle/subtitle` | Task | 0.5 (in UI-27) | Claude | UI-26 | `relativeTitleByDay` green |
| UI-39 | `ExtractionReviewViewModel.isDirty`, `medicationRows`, `cancelIfUnsaved()` (D21) | Task | 5.5 (in UI-28) | Claude | UI-26 | 3 new + 3 rewritten tests green |
| UI-40 | Sleep × Mood gate on `decodedSleepLevel` — own PR `fix/insights-sleep-mood-gate`, 1.1.x-shippable | Task | 1.5 | Claude | UI-04 | RED with canonical values → GREEN; copy unchanged; mergeable before Phase B |
| UI-41 | Bubble diameter · rhythm tint · range-bar span fns · caption case | Task | 3 (in UI-30) | Claude | UI-29 | three test files green |
| UI-42 | `medicationBarShowTakenTime` / `ShowEndTime` keys + `titleLine` | Task | 3 (in UI-32) | Claude | UI-31 | `titleLineVariants` green |
| UI-43 | Summary correction persistence (deferred, outside waves 1–2) | Story | 6 | Claude | owner | — |
| UI-44 | Dead-code sweep (refresh-orphaned code only; `Constants.swift` never) | Task | 3 | Claude | UI-32 | grep proofs; `WhisperKitTranscriptionService:134` still reads `medicalPromptEnabled` |
| UI-45 | Dark-mode pass (wave-2 screens) | Task | 6 | Claude + Owner | UI-33b | screenshot pack |
| UI-46 | Dynamic Type / AX pass (wave-2 screens) | Task | 6 | Claude | UI-45 | 3 × 3 matrix clean |
| UI-47 | VoiceOver + Reduce Motion pass (wave-2 screens) | Task | 4 | Claude + Owner | UI-46 | per-screen scripts |
| UI-48 | Copy normalisation sweep (pen-screen strings only) | Task | 3 | Claude | UI-32 | old strings gone |
| UI-49 | Token + typography alias deletion; Complexity row closed | Task | 6 | Claude | UI-48 | no `NewLook`/`Theme`/old `Typography` symbols |
| UI-50 | PR gate (recurring, ~25 PRs; risk #11 workaround) | Task | 37.5 | Owner + Claude | — | build · serial tests · review · device QA |
| UI-51 | Release 1.2 (wave 1) | Task | 9 | Owner + Claude | UI-25, UI-33a, UI-53 | 2.3.3 screenshots refreshed; `v1.2.0`; `docs/BACKLOG.md` rows shipped |
| UI-52 | Release 1.3 (wave 2) | Task | 9 | Owner + Claude | UI-49 | `v1.3.0` by Dec 18 |
| UI-53 | Wave-1 dark / AX / VoiceOver mini-pass (A/B/C + Calendar + Log Dose/composer) | Task | 6 | Claude + Owner | UI-25, UI-33a | light/dark pack + VoiceOver scripts for the four screens |
| UI-54 | Single `formattedDuration` — own PR `fix/duration-format` | Task | 0.5 | Claude | UI-04 | `durationFormatIsSingle` green; mergeable before Phase B |

---

## 5. Timeline

**Assumptions (stated so they can be rejected):** engineering throughput ≈ 6 focused h/day on weekdays (Claude sessions + owner review), ≈ 35 h/week; owner device QA and decisions happen the same or next day; Sep 28–30 are Devpost days (docs only); Oct 1 is the exit ritual + #44/#45/#41; **055's merge + 1.1 submission is an external dependency with the RC epic's own ETA — every Phase B date below is anchored on T0 = 055 merged + 1 day (nominal Mon Oct 5) and slides one-for-one with it**; docs-only work (UI-01/03/05 drafting/05b) and the two `fix/` PRs (UI-40/54) run before T0 on `main`; App Review turnaround 1–3 days; no vacation days planned in. Hours per step from §4.

| Date | Day | Work (ID) | Notes |
|---|---|---|---|
| Mon Sep 28 | 1 | UI-02 decisions (owner, 2 h) · UI-01 DESIGN.md v2 drafting (Claude, 4 h) | Devpost video in parallel |
| Tue Sep 29 | 2 | UI-01 finish + review (2 h) · UI-03 Epic UI / BACKLOG / DEVLOG (1.5 h) | docs PRs to **`main`** (never `feat/057`) |
| Wed Sep 30 | 3 | Devpost close (11:45 pm PDT) · UI-04 prep: read 055 device-QA checklist, #44/#45/#41 diffs · UI-05b design-system mockup start (docs only) | no Swift |
| Thu Oct 1 | 4 | Fix the ritual text (3.0.0 → 3.1.0) · exit ritual (docs; constitution step deferred if 055 is not yet on `main`) · #44 merge · #45 merge (no DESIGN.md conflict) · #41 merged with the `#if DEBUG` guard or closed | UI-04 (1)–(3), (6) |
| Fri Oct 2 | 5 | UI-04 (5) 053/054 archived · UI-05b mockup finish (4) → owner approval · UI-40 + UI-54 `fix/` PRs (2) · UI-05 clarify/specify drafting | 055 merge + 1.1 submission = RC epic (external, own ETA); nothing here waits on it |
| T0 − 1 | — | 055 merged → tag → **1.1 submitted** · constitution step of the ritual if deferred · worktrees removed, `feat/057` re-cut | UI-04 (4), (7); RC hours not counted here |
| Sat–Sun Oct 3–4 | — | buffer (055 QA spill-over) | |
| Mon Oct 5 = **T0** | 6 | UI-05 plan/tasks (Constitution Check vs 3.1.0) · UI-06 start | Phase B begins; D2/D14/D15 answered by T0 − 3 (Oct 2) |
| Tue Oct 6 | 7 | UI-06 colour tokens (8 h total) | |
| Wed Oct 7 | 8 | UI-07 typography (3) · UI-08 layout/cards (start) | D1 answered by T0 + 1 (Oct 6) |
| Thu Oct 8 | 9 | UI-08 finish · **PR B1** (tokens/typography/layout) → review → **full-app owner QA light/dark + before/after pack** | first visible change app-wide; 1.1.x hotfixes from `v1.1.0` from here |
| Fri Oct 9 | 10 | UI-09 buttons (5) · UI-10 chips (start) | |
| Mon Oct 12 | 11 | UI-10 finish · UI-11 controls (6) | |
| Tue Oct 13 | 12 | UI-17 icons (1) · UI-11 finish · **PR B2** (buttons/chips/controls/icons) | D3.1–3.3 answered by T0 + 6 (Oct 13) |
| Wed Oct 14 | 13 | UI-12 glyphs (8) — requires D3 | critical path |
| Thu Oct 15 | 14 | UI-12 finish · UI-13 sleep (3) | |
| Fri Oct 16 | 15 | UI-14 medication glyphs (3) · UI-15 ring (start) | |
| Mon Oct 19 | 16 | UI-15 finish · UI-16 tiles (3) · **PR B3** | |
| Tue Oct 20 | 17 | UI-18 tab bar + FAB (12) — requires D4/D5, answered by T0 + 10 (Oct 19) | critical path |
| Wed Oct 21 | 18 | UI-18 cont. | |
| Thu Oct 22 | 19 | UI-18 finish · UI-19 gallery/snapshots (3) · **PR B4** | Phase B done (≈ 68 h) |
| Fri Oct 23 | 20 | UI-20 Spec Kit 058 (3) · UI-21 mockup (2) → owner approves | *(T3 "October" cut would submit here — §0)* |
| Mon Oct 26 | 21 | UI-21 A idle (13) | |
| Tue Oct 27 | 22 | UI-21 cont. | |
| Wed Oct 28 | 23 | UI-21 finish · **PR** · UI-34 test-first (1) · UI-22 mockup | |
| Thu Oct 29 | 24 | UI-22 B listening (19) | |
| Fri Oct 30 | 25 | UI-22 cont. | |
| Mon Nov 2 | 26 | UI-22 finish · **PR** · UI-23 mockup | |
| Tue Nov 3 | 27 | UI-23 C saved (10) | |
| Wed Nov 4 | 28 | UI-23 finish · **PR** · UI-24 Spec Kit 059 (3) | |
| Thu Nov 5 | 29 | UI-35/36 test-first (3.5) · UI-25 mockup (3) → owner approves | |
| Fri Nov 6 | 30 | UI-25 Calendar (27) | |
| Mon Nov 9 | 31 | UI-25 cont. | |
| Tue Nov 10 | 32 | UI-25 cont. | |
| Wed Nov 11 | 33 | UI-25 finish · **PR** · UI-33a Log Dose, composer, onboarding (8) · **PR** | |
| Thu Nov 12 | 34 | **UI-53** wave-1 dark/AX/VO mini-pass on the 4 screens + 2 sheets (6) · **PR** · TestFlight build | |
| **Fri Nov 13** | 35 | **UI-51 Release 1.2 submitted** — screenshots (6), What's New, tag `v1.2.0` | live ≈ Nov 16–17 |
| Mon Nov 16 – Fri Nov 20 | 36–40 | UI-26 Spec Kit 060 (4) · UI-38 (0.5) · UI-27 Day Details (35) | |
| Mon Nov 23 – Fri Nov 27 | 41–45 | UI-27 finish · **PR** · UI-39 (5.5) · UI-28 Edit (27) | |
| Mon Nov 30 – Fri Dec 4 | 46–50 | UI-28 finish · **PR** · UI-29 (3) · UI-41 (3) · UI-30 Insights (29.5) | |
| Mon Dec 7 – Fri Dec 11 | 51–55 | UI-30 finish · **PR** · UI-31 (3) · UI-42 (3) · UI-32 Settings (39.5) | #41 was resolved on Oct 1 (UI-04) |
| Mon Dec 14 – Thu Dec 17 | 56–59 | UI-32 finish · **PR** · UI-33b (8) · UI-44 dead code (3) · UI-45/46/47/48 passes (19) · UI-49 token deletion (6) | compressed — needs ~40 h/week |
| **Fri Dec 18** | 60 | **UI-52 Release 1.3 submitted**, tag `v1.3.0` | at 35 h/week this slips to ~Jan 8 |

**Critical path:** 055 merge (T0 − 1, external) → UI-06 → UI-12 (glyphs) → UI-15 (ring) → UI-18 (tab bar) → UI-21/22/23 → UI-25 → UI-53 → 1.2. **Per-decision deadlines** (no blanket date): D12 and D2/D14/D15 by Oct 2 (before UI-05's plan step and UI-06); D1 by Oct 6 (before UI-07); D3.1–3.3 by Oct 13 (before UI-12); D4/D5 by Oct 19 (before UI-18); D-R2 by Oct 28 (before UI-22); the rest per their consumer's Spec Kit slice. Every day a decision is late moves its consumer and everything after it by a day. **Owner-bound items on the path:** 055 QA + submission (RC epic), the dated decisions above, UI-05b approval (Oct 2), five B/fix-PR QAs (Oct 8/13/19/22 + B1's full-app pass), four wave-1 screen QAs, UI-53, screenshots (Nov 13).

**Totals:** wave 1 ≈ 215 h (Sep 28 → Nov 13, 7 weeks incl. the RC/exit week, UI-05b, UI-40/54, UI-33a and UI-53); wave 2 ≈ 210 h (Nov 16 → Dec 18, 5 weeks at 40 h/week, or → ~Jan 8 at 35 h/week); **≈ 425 h, 12–14 weeks wall-clock** — the same figure as §2 and §4.8. The single-release alternative (everything in one 1.2) lands ~Dec 18 with the same hours and a bigger App Review/screenshot risk; the chrome-only October 1.2 (UI-01–19 + release, ≈ 105 h, submit Oct 23) is feasible but ships a half-designed product and forces a second screenshot refresh three weeks later.

---

## 6. Risk register (top 10)

| # | Risk | Likelihood / impact | Mitigation |
|---|---|---|---|
| 1 | **Custom tab bar vs iOS 26 Liquid Glass / HIG** — loses minimize-on-scroll and re-tap-to-root, must re-implement tab a11y, keyboard avoidance, Reduce Transparency; App Review does not reject custom bars but users notice regressions | M / H | D4 decided up front; `TabView` kept for state; a11y checklist in UI-18's Verify; device QA with VoiceOver + Switch Control before B4 merges; fallback = native bar tinted (2 h) if QA fails |
| 2 | **Glyph asset fidelity + the black-block artefact** — assets cut before D3 are cut twice; colour-only mood breaks principle 5; two "great" sprouts | H / M | D3.1–3.3 answered by Oct 13 (T0 + 6); redraw as `Shape`s behind `SignalGlyph` (one API, no asset matrix); grayscale preview is a gate in UI-12 |
| 3 | **Scope creep from REMOVE items** — the pen omits nine surfaces that rules require (export, privacy/terms, restore, LLM row, My Medication, disclaimer, Clear All Data, transcript/retry, version); "the pen is the source of truth" invites dropping them | H / H | D7 table is the contract; the eight Settings rows are costed (7.5 h) and mandatory; every removal that loses a function is logged, never silent (Constitution III) |
| 4 | **App Review screenshot mismatch (2.3 Accurate Metadata / 2.3.3)** — store screenshots must reflect the shipping UI; two waves = two refreshes; a half-refreshed app in wave 1 must still match its screenshots; **after PR B1 `main` matches no screenshot at all** | M / H | screenshots are a costed step in UI-51/52; wave 1 is chosen so its four screens are internally consistent; 1.1.x hotfixes are cut from `v1.1.0`, never from the re-coloured `main`; no dark-mode screenshots until UI-53/45 pass |
| 5 | **Dark mode is entirely derived** — no pen values; green-800 titles, black strokes, `#183c28` shadows and the black block all vanish on dark | H / M | D2 = derive now with a documented rule per token; `TokenContrastTests` covers dark; UI-45 device pass before each release |
| 6 | **Regressions in the extraction-review (Edit) flow** — medication model collapse would drop duration editing the bar depends on; dismiss paths bypass `cancel()`; 12 VM tests pin the round-trip | M / H | D21 keeps the `[MedEvent]` model; UI-39 rewrites tests RED→GREEN before the view; `cancelIfUnsaved()` in `onDisappear`; provenance tags asserted |
| 7 | **Test coverage gaps** — views have no tests; pinned copy/colour tests (`nudgePromptContents`, `averageHalfStepGetsPlusLabel`, `DayCardPaletteTests`, `RecordingMoodDisplayTests`, `SignalGlyphTests`) break on casing/colour changes; the suite is not parallel-safe | H / M | casing policy = sentence case (D8) keeps copy tests; token tests rewritten in UI-06 with an AA helper; serial `xcodebuild test` in every gate; simulator snapshot packs as the view evidence |
| 8 | **Branch stacking / merge conflicts** — 055 (64 commits, Settings/onboarding/constitution/skills), #44/#45 (`TimelineRow`, `FoldedDayCardHeader`, `RecordingStore`, `RecordingDetailViewModel`, `InsightsViewModel+Signals` — no doc files), #41 (`SettingsView`, `SquirlApp`, `TestServicesView`; breaks the Release build if merged after #44 unguarded), 053 stash (`InsightsView`), and this session's own worktrees (`ui-refresh`, `057-ui-refresh`) which block `git branch -D` | H / H | UI-01/03 docs to `main` first; UI-04 chain before any Swift; sequential PRs only; `feat/057` re-cut from post-055 `main` after `git worktree remove`; #41 resolved on Oct 1 |
| 9 | **Contrast failures carried over** — six AA failures in the pen; today's buttons already fail at 4.02:1 | H / M | D14 policy (green-600 for text fills, grey-300 captions, no amber text); enforced by `TokenContrastTests`, not memory |
| 10 | **Timeline / owner bandwidth** — "1.2 in October" is not achievable; the owner is on the critical path ~12 times (decisions, 055 QA, per-PR device QA, screenshots); year-end App Review slowdown | H / H | two waves with an honest Nov 13 / Dec 18 plan anchored on T0; per-decision deadlines (§5); QA checklists pre-written in each step; 1.3 date protected by trimming UI-43/real-waveform/rolling-previous-days into a later release |
| 11 | **CLI test-host crash and tool availability** — the full suite can crash under `xcodebuild test` with a nondeterministic SwiftData `EXC_BREAKPOINT` in `DoseLogServiceTests` (0 assertion failures; clean under ⌘U — `docs/DEVLOG.md:123`), and `ios-debugger-agent`/XcodeBuildMCP has historically been "not connected" (constraints §6) — the very first B1 gate may fail for reasons unrelated to the change | H / M | gate = serial CLI run (`-parallel-testing-enabled NO`); on a 0-assertion-failure crash, rerun once, then the owner's ⌘U run counts; record the workaround per PR (UI-50) |

Also tracked (not top-10): Sleep × Mood never unlocking on production data (fixed **early** in UI-40 as its own PR — shippable in 1.1.x, and the re-skin depends on it); 393/390/375-pt device fit for the tile row (D16 rule); `Color.accentColor` runtime resolution (asset bronze vs meadow tint — device check in UI-06); `AVAudioSession` interruption never mirrored to the VM (§7); RevenueCatUI paywall memory regression #6018 (055's risk, unchanged by this plan).

---

## 7. Assumptions and open questions (consolidated, deduplicated)

**Assumptions this plan makes (reject any and the plan changes):**
- A1 The owner accepts the recommendations in §1 unless he says otherwise **by each decision's deadline in §5** (D12, D2/D14/D15 Oct 2 · D1 Oct 6 · D3 Oct 13 · D4/D5 Oct 19 · D-R2 Oct 28); D1 = SF, D2 = derive dark, D3 = redraw, D4 = custom bar with the FAB hidden on the hub, D5 = tab root + FAB→B, D12 = archive, D14 = green-600 text fills, D26 = keep `Created`.
- A2 055 merges and 1.1 is submitted on the RC epic's ETA; Phase B starts at T0 = that merge + 1 day (nominal Oct 5) and every later date in §5 slides one-for-one with it.
- A3 The pen's HTML-lite export does **not** satisfy Constitution I; each screen gets a mockup with light/dark/AX5 toggles and its undrawn states (2–3 h each, costed).
- A4 Pen placeholder noise is not a requirement: `Tue 7 · Mon 6`, `Aug 30` ×3 under September, `18:30` ×3, `Fri 08` under a selected `10`, `Okey`, `Fr Fr`, `Sept`, 58 % fill labelled `70%` beside a `75%` sentence, energy bar 24 % under "Charged".
- A5 Screen frames are 402 × 874; every fixed geometry gets a width-relative rule.
- A6 No SwiftData schema change is needed in waves 1–2 (all new state is `@AppStorage`, computed, or `RecordingTag`).
- A7 The tab bar's Check In icon maps to SF `checkmark.square` (vuesax `task-square`); if the owner prefers the current `checkmark.circle`, that is a one-line change.

**Open questions (only those the code or the pen cannot answer; grouped; ★ blocks a step):**
- ★ **Navigation.** Q1 Confirm D5(a) (hub = tab root with bar; B/C hide chrome; FAB = start recording). Q2 Back pill on B = immediate cancel (no confirm)? Q3 Back pill on C = "Go back home"? Q4 Tab bar visible on Day Details (pen) but hidden on Edit (pen) — confirm the rule "hidden on any screen without a tab-root parent view visible". Q5 What does "Home" mean on C — the hub (recommended) or Calendar?
- ★ **Ring.** Q6 The arc is a 3-step flow indicator (33/66/100 %), not elapsed time — confirm; does it animate 33→66 on tap and settle 66→100 on save (Reduce Motion → static)? Q7 **D-R2 (DESIGN.md §10):** listening motion = (a) carry the logged 2026-06-15 rule (7 s/rev rotation + voice-level glow), (b) static arc as drawn, or (c) arc step + level-driven glow (recommended) — and is idle breathing (5 s) kept or dropped? Q7b **D-K6:** interactive chip rows at a ≥ 44-pt pitch — chip 27 + gap 17 or chip 36 + gap 8 (both deviate from the pen)?
- ★ **Glyphs.** Q8 Black block = fill mask (D3.1)? Q9 Canonical "great" sprout (D3.2)? Q10 Shape cue kept on mood (D3.3)? Q11 One glyph size per context (33.55 tiles/weekday · 24 rows · 16 headers) — accept collapsing 23/24/20 to 24? Q12 Sleep moon stays violet (D10) despite sitting 30 pt from the medication pill on collapsed cards?
- ★ **Contrast.** Q13 Accept D14 (green-600 text fills, grey-300 captions, no amber text, grey-300 inactive icons, 2 pt selected-tile stroke + tint)? Q14 Which AA-safe amber for the energy tag (candidate to be measured ≥ 4.5:1) — or drop tag colouring for the identity icon?
- **Copy.** Q15 Sentence case for sentences, Title Case for titles (D8)? Q16 "See you at next check-in" — keep (warmth) or drop (return nudge vs Product Posture)? Q17 "Check-In" (pen) vs "Check in" (tab label today) — one spelling app-wide. Q18 "A few words are enough" / "Take your time, speak freely." / "How do you feel today?" / "Make the app work for you" / "Your month at a glance" as the corrected strings? Q19 Range-bar labels: two lines, scaled, or only under the bracketed pair? Q20 Connections caption: generic ("a few days of data") or the real gates (4 / 5 / 3+3)? Q21 "Unlock" + padlock + "log N more days" — acceptable under no-gamification, or reword to "shows after…"?
- **Calendar.** Q22 D6.1–D6.6 confirmed (month grid kept; dots = has-check-ins; compact band kept; month-scoped previous days; `•••` = Edit · Delete; emotions/side effects leave the row)? Q23 Visual for a dose-only node and a transcribing/pending row (both exist, neither drawn)? Q24 Week-strip greys `#717680`/`#414651` snap to grey-300/grey-400? Q25 Medication bar: keep the row tap dialog (recommended) and the onset pulse? Q25b An **expanded previous-day card** is reachable today (`ExpandedDayCards.toggling`, "Always expand cards") but undrawn — confirm it takes the §2.5 anatomy of the selected day's card (fixed mint band `#e6f5ee` + rows + dividers); mockup 059 must show it.
- **Day Details.** Q26 One check-in per page (D18) with time in the subtitle? Q27 Transcript as a disclosure under the summary + `•••` entry (recommended)? Q28 Sleep and side-effect chip rows restored (recommended)? Q29 `•••` = Edit · Transcript · Delete only (no Share/Regenerate)? Q30 Medication rows list all `medicationEvents` (incl. manual) or `.transcript` only (today)? Show `(missed)`/time? Row tappable? Q31 Narrative at 16 pt (`narrative`) rather than the pen's 12 pt? Q32 Summary editing deferred (D19)? Q33 Waveform seeded (D24)? Q34 Emotion chips all solid green (D20)? Q35 Gutter 28 (D16)?
- **Edit.** Q36 Push, not sheet (recommended)? Q37 Medication cardinality per D21? Q38 Date/time = styled field → sheet picker (D23)? Q39 Chip rows wrap (recommended — the pen clips 11 of 15 side effects)? Q40 Collapsible cards real and persisted (`@AppStorage`) — and may "How did you feel?" collapse at all? Q41 Tap-again-to-clear kept (needed to un-set a wrong extraction)? Q42 Save always enabled (pen) or dirty-gated (recommended, §3.3 #6); prompt on back with unsaved edits? Q43 Sleep words `Restless…Deep` + compact hours field (D9/D7)? Q44 Synonym line dropped (logged reversal)? Q45 Tile ring per level (pen) with L3/L4 tints derived, or per signal?
- **Insights.** Q46 053 archived (D12)? Q47 Month selector: fixed three segments with "next" disabled at the current month? Q48 Bubble rule: `d ≈ 60 + 1.3·pct` vs today's sqrt-area; zero-count levels hidden or minimum bubble? Q49 Legend wraps (recommended)? Q50 "Where you averaged" whole-number bracket = one segment? header→bar gap 10 or 15? Q51 No Sleep row on Insights now (as drawn) — 4th row later? Q52 Connections order: pen (med · sleep · energy) or code (med · energy · sleep, test-pinned)? Q53 Rhythm tint = one formula (signal colour @ 0.12) instead of nine literals? Q54 "24 check-ins" = all recordings or mood-resolved ones (bubbles sum to the latter)?
- **Settings.** Q55 Confirm the eight must-keep rows (D7) and who designs them — Claude proposes them in the 062 mockup in the pen language. Q56 Model-row states (not installed / downloading / error / delete) and the LLM row's ~740 MB copy — approve the mockup. Q57 Native toggles, one size (D22)? Q58 Reversal of the 2026-06-24 "Settings stays native `List`" logged? Q59 "Show taken time" / "Show end time" — what exactly they toggle on the bar (title time; a trailing "ends HH:mm"); rows 2–4 hidden when the bar is off (code) or disabled (pen shows all)? Q60 Confirmation preview mirrors `DoseConfirmationCopy` exactly (recommended) — sample time fixed, `Date.now`, or last dose? Q61 "Acknowledgement" row → open-source credits (recommended; MLX/Qwen added)? Q62 "Blocked for" chips hidden when mode ≠ Time window (code) — confirm. Q63 FAB covering the Confirmations toggle at rest → bottom inset ≥ 170 (recommended). Q64 Privacy statement "Nothing is uploaded." + the one honest disclosure line once RevenueCat is in the build (Q-M3).
- **Medication.** Q65 Status thresholds by fill fraction (today) or catalog `onsetMinutes`? Q66 Worn-off = grey-300 + row fades (recommended)? Q67 "Missed" wording kept? Q68 Violet as brand accent + medication (D10)?
- **Chrome / global.** Q69 Medication bar on the four roots only, pinned (D25)? Q70 Inactive tab icons grey-300 (D14)? Q71 Compact (icon-only) bar on all roots incl. Settings (D4)? Q72 Empty states (Calendar first launch under a hard paywall, Insights empty month) — approve the mockups; no pen frame exists.
- **Paywall / 055.** Q73 RevenueCat dashboard paywall restyled by the owner before 1.3 (D11)? Q74 Paywall fine print in `Ink.primary` (the old "Owner decision required" line — now decided?).
- **Process.** Q75 DESIGN.md keeps `Created: 2026-06-18` and is treated as an edit (D26, recommended) — or the owner rules "new file" and the override is recorded in the header comment? Q76 Spec numbering 057–062 accepted (D13)? Q77 Waves (1.2 = Nov 13, 1.3 = Dec 18) vs single release vs chrome-only October (§5)? Q78 `AVAudioSession` interruption pause: wire into the VM later (new ticket) or accept the ticking timer during a call? Q79 `Color.accentColor` sites — asset moves to green-600 (UI-06); confirm nothing else depends on bronze. Q80 Commit the pen exports (`outsource_design/*.svg` + the 2× PNGs + Figma JSON) as `docs/design/pen/` so DESIGN.md §1's evidence row resolves (recommended, UI-01) — or keep them out of the repo and let DESIGN.md quote the 2026-09-27 exports by node id only? Q81 UI-05b: design-system HTML mockup for the Phase B atoms (recommended) vs a written Constitution I waiver for package atoms?
