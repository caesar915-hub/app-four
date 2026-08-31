<!-- Created: 2026-07-27 15:10 (WEST) · Updated: 2026-08-31 01:18 (WEST) -->
# 07 — Medications

Documents branch `main` @ `43eb6515a63a0eca957a79aad257da380c73edd4`. All `path:line` citations are against `main`.

## Purpose

Describe medication support in Squirl: the static medication catalog, the persisted dose record, dose logging flows (manual sheet, quick-log, transcript-extracted, and the dormant hands-free intent), the Dose Guard (dormant), and the floating medication bar with its settings.

**Shipping status.** The feature ships in two tiers on `main`:
1. **Active in 1.0:** the medication bar (display + Log Dose sheet + delete), the picker, the "Medication Bar" settings section, and transcript-extracted `MedicationEvent`s.
2. **Implemented, dormant in 1.0:** `LogDefaultDoseIntent`, `DoseLogService`, Dose Guard, and the "My Medication" / "Confirmations" / "Dose Guard" settings sections exist in code but are **not user-reachable** — the intent has `isDiscoverable = false` and no `AppShortcutsProvider` exists; the settings sections are not instantiated anywhere in the app target. Restore plan (per `docs/BACKLOG.md` §"Last updated"): "1.1 restore = `git revert 94a51181`".

## Scope

- In scope: `MedicationCatalog`, `MedicationEvent`, `DoseGuardMode`, `DoseLogService`/`DoseLogServiceImpl`, `LogDefaultDoseIntent` + `DoseConfirmationCopy`, `MedicationBarViewModel`, `MedicationPickerViewModel`, `MedicationBarView`, `MedicationLogSheet`, `MedicationBarSettingsSection`, `MyMedicationSection`, `DoseGuardSection`, and the `medicationBarOverlay`/`ScreenContainer` placement.
- Out of scope: extraction of medications from transcripts ([Processing & Extraction](04-processing-and-extraction.md)), medication rendering in day cards/insights ([Library & History](05-library-and-history.md), [Insights](06-insights.md)).

## Actors & triggers

- **User** — taps the medication bar row (manage dialog), logs or deletes a dose, toggles bar visibility in Settings. (Dormant: invokes "Log My Meds" via Siri/Shortcuts, configures a default medication and Dose Guard.)
- **System triggers** — `Notification.Name.medicationEventsDidChange` (posted on every log, delete, recording save, and clear-all-data) refreshes the bar and the calendar timeline; `.onAppear` refreshes the bar; summarization creates transcript-sourced events. There is **no timer** — bar progress recomputes only on appear/notification, not continuously.

## Functional requirements

### Static catalog

- **FR-MED-01 — Three-entry static catalog.** `MedicationCatalog.all` is a static, non-persisted catalog ("adds no SwiftData schema") of exactly **3 entries** ("Beta subset: the three meds the first testers take"):

  | Name | doseOptions | onsetMinutes | durationHours |
  |---|---|---|---|
  | Concerta | "18 mg", "27 mg", "36 mg", "54 mg" | 60 | 12 |
  | Ritalin | "5 mg", "10 mg", "20 mg" | 20 | 3 |
  | Elvanse | "20 mg", "30 mg", "40 mg", "50 mg", "60 mg", "70 mg" | 90 | 10 |

  (`MedicationCatalog.swift:14, 20-39`)
- **FR-MED-02 — App Review disclaimer.** Catalog values are "typical values from each product's EU Summary of Product Characteristics (SmPC); the UI must always present them as typical ('≈', 'may differ'), never as guidance (App Review 1.4.1)". The Log Dose sheet shows the literal disclaimer **"Typical values from product labeling — your response may differ."** whenever a catalog entry is resolved (`MedicationCatalog.swift:16-18`; `MedicationLogSheet.swift:120`).
- **FR-MED-03 — Base-name resolution.** `entry(matching:)` takes the **first whitespace token, lowercased** ("base name") and matches it against each entry's lowercased full name — "concerta", "Concerta", "Concerta 36 mg" all resolve to Concerta. Unknown or empty names return nil (`MedicationCatalog.swift:44`).

### Dose record

- **FR-MED-04 — `MedicationEvent` model.** SwiftData `@Model` with: `id`, `name`, `dose: String?` (free-form, e.g. "36 mg"), `takenAt` ("Resolved absolute time. Set once at save time so there is no re-parsing on every read"), `taken: Bool = true` (false = missed/negated dose from transcript), `quantity: Double?` (nil = 1.0 full dose; 0.5 = half pill), `durationHours: Double = 10.0` (per-medication effect window, "stored so the bar doesn't hard-code it"), `change: MedEventChange?` (`regular`/`started`/`stopped`), `timeLabel: String?` (raw transcript phrase for provenance), `source` (`manual` | `transcript`, default `.manual`), `createdAt`, `isMockData`, and an optional `recording` link (nil for standalone manual logs) (`MedicationEvent.swift:9-36`).
- **FR-MED-05 — Effect window.** `effectProgress(at:) = min(1, max(0, elapsed / (durationHours * 3600)))`, clamped [0,1]; if `durationHours * 3600 <= 0` returns 1. `isActive(at:) = taken && effectProgress < 1` (`MedicationEvent.swift:68-77`).
- **FR-MED-06 — Transcript fuzzy-time mapping.** `resolvedTakenAt(time:timeLabel:recordingDate:)`: (1) explicit "HH:mm" parsed onto the recording's calendar day — if the parsed time is *after* the recording date, it's assumed to be the **previous day**; (2) fuzzy `timeLabel` via first-match keyword→hour mapping: contains "morning"/"am"/"breakfast" → **8**; "afternoon"/"lunch"/"noon" → **13**; "evening"/"dinner"/"pm" → **19**; "night"/"bedtime"/"sleep" → **22** (minute = 0); (3) fallback: the recording's creation date (`MedicationEvent.swift:83-120`).
- **FR-MED-07 — Transcript-event creation.** `Recording.setMedicationEvents` replaces only `source == .transcript` events; manual events are never touched and suppress extraction of the same lowercased name (manual beats extractor). Duration precedence: per-med `durationHours` (Edit sheet) → call-site default → **10.0 h**. `hasMedication` recomputed from inputs. Manual check-in meds insert as `source: .manual` events linked to the recording (`Recording.swift:299-342`; `RecordingStore.swift:141-152`).

### Dose logging flows

- **FR-MED-08 — Log Dose sheet (active).** Presented only from the medication bar's "Log new dose". Modal sheet titled **"Log Dose"** with a circular × button (AX "Cancel") and a **"Save"** button disabled while the trimmed name is empty (trimmed of **whitespace only**, not newlines). State defaults: empty name/dose, `takenAt = now`, `durationHours = 10`. Sections: **"Medication"** (scrolling chips of pickable names + free-text field, autocorrection disabled); **"Dose"** (catalog → menu picker with placeholder "—" plus the entry's doseOptions and a read-only **"Onset"** row **"≈ N min"**; non-catalog → free text "Dose (optional)"); **"Effect Duration"** ("Hours" numeric field, decimal pad, width 60, bound directly — **no clamping**, 0/negative allowed); **"Taken At"** (`DatePicker(in: ...Date(), .hourAndMinute)` — **future times cannot be picked**; only same-day times are practically enterable). No dose-content validation; empty dose stored as nil (`MedicationLogSheet.swift:8-153`).
- **FR-MED-09 — Catalog auto-fill.** On every name change, if the name resolves to a catalog entry: `durationHours = entry.durationHours`, and if the current dose isn't in `doseOptions` it resets to the **first** dose option. Non-catalog names keep whatever dose/duration the user had (`MedicationLogSheet.swift:31, 192`).
- **FR-MED-10 — Quick-log & manage dialog from the bar.** Tapping a bar row opens a `confirmationDialog` titled `"<name>[ <dose>]"` (visible) with **"Log new dose"** (opens the Log Dose sheet), **"Delete this dose"** (destructive — **immediate, no separate confirmation alert**), and **"Cancel"** (`MedicationBarView.swift:20-39`).
- **FR-MED-11 — Manual log semantics.** `logManualDose(name:dose:takenAt:durationHours:)` inserts `MedicationEvent(taken: true, source: .manual)` with caller-supplied duration (default 10.0), stamps `isMockData` from the `debugMockMode` key, saves with `try?` (**save errors are swallowed** — no failure surface), and posts the change notification. `deleteEvent(id:)` fetches by id, deletes, `try?` save, posts; unknown id → silent no-op (`MedicationBarViewModel.swift:111-130`).
- **FR-MED-12 — Picker merge.** `pickableNames` = catalog names in catalog order, then previously-logged names whose **base name** isn't already represented ("Concerta 36 mg" in history folds into catalog "Concerta"), deduped within history. History fetch: `takenAt` descending, **`fetchLimit = 100`**, **no taken/mock filtering**; failure → catalog-only chips. Chip selection compares base names, not exact strings (`MedicationPickerViewModel.swift:5-63`; `MedicationLogSheet.swift:167-170`).
- **FR-MED-13 — Dormant hands-free intent — Implemented, dormant in 1.0.** `LogDefaultDoseIntent` (title **"Log My Meds"**; description "Logs your default medication dose. Set the medication once in Squirl's settings.") has `isDiscoverable = false` (hidden from Shortcuts/Spotlight; no `AppShortcutsProvider` — "1.0 ships hands-free logging hidden … pending its S1–S10 device QA"). `supportedModes = [.background, .foreground(.dynamic)]`; `authenticationPolicy = .alwaysAllowed` (locked Siri works; "worst case is journal pollution"). On `.notConfigured` it attempts `continueInForeground(dialog, alwaysConfirm: true)` then routes to Settings' My Medication focus; a declined/impossible transition "leaves the calm dialog standing — never an error surface" (`LogDefaultDoseIntent.swift:10-44`; notes §0).
- **FR-MED-14 — Dormant expedited log flow — Implemented, dormant in 1.0.** `DoseLogServiceImpl.logDefaultDose(now:)` in exact order: (1) fetch-or-create the single `AppSettings`; (2) **configuration check** — requires `defaultMedicationName` AND `defaultMedicationDose` AND the name still resolving via the catalog (a dangling default degrades to `.notConfigured`); (3) **guard evaluation** — skipped entirely when mode is `.off` (never reads history); otherwise fetch `mostRecentDose()` — a fetch **error returns `.failed` (fails closed)**: an error degraded to nil would read as "no prior dose" and bypass an armed guard; blocked → `.guarded(activeSince:)`; (4) **write** — `MedicationEvent` with duration from the **catalog entry**, not user input; (5) **save-failure rollback** — on persist throw, the inserted event is explicitly deleted ("a reported failure into a silent success = a double log once the user retries") → `.failed`; (6) success posts `medicationEventsDidChange` → `.logged(name:dose:at:)`. `mostRecentDose()`: `taken == true && isMockData == false`, `takenAt` desc, limit 1, any medication, **no time cutoff** (`DoseLogServiceImpl.swift:18-82`).
- **FR-MED-15 — Dormant confirmation copy — Implemented, dormant in 1.0.** `DoseConfirmationCopy.text(for:named:)` exact strings (time = system short time style, locale-aware): logged, named on: `"<Name> <dose> logged · <time>"` (e.g. "Elvanse 30 mg logged · 9:41 AM"); logged, named off: `"Dose logged · <time>"`; guarded: `"Your <time> dose is still active."` (names the earlier dose's **time**, never the drug); notConfigured: `"Set your medication first."`; failed: `"Couldn't save that dose — nothing was logged. Try again in the app."` The `named` flag governs every surface uniformly (banner, spoken, lock screen) (`DoseConfirmationCopy.swift:10-20`).

### Dose Guard (implemented, dormant in 1.0)

- **FR-MED-16 — Guard modes & blocking semantics.** `DoseGuardMode` cases `off`, `total`, `window` — guards **expedited (hands-free) logs only** (sticker/voice/Shortcuts); "the in-app Log Dose sheet never consults it". `blocksLog(previousDose:windowHours:now:)`: no previous dose → never blocks; `.off` → never blocks; `.total` → blocks while the previous dose `isActive(at: now)` — reusing `effectProgress < 1`, so it honors a **per-event edited duration**, not the catalog default; `.window` → blocks while `now - previousDose.takenAt < windowHours * 3600` — purely time-since-dose. **Boundary is closed:** at exactly window-end/effect-end the guard opens (strict `<`). Forward-safe decode: any unrecognized persisted raw value maps to `.off` (`DoseGuardMode.swift:3-21`).
- **FR-MED-17 — Dormant Dose Guard settings section — Implemented, dormant in 1.0.** Section header **"Dose Guard"** with three always-visible selectable rows (`shield` icon, checkmark on selection): **"Off"** / "Every trigger logs"; **"Total"** / "Blocked while a dose is still active"; **"Time window"** / "Blocked for a set time after a dose". When `.window` is selected, an inline **"Blocked for"** segmented picker offers **[1, 2, 3, 4] hours** ("1 h".."4 h"), bound to `doseGuardWindowHours` (default **2**). Dynamic footer always ends with **" The in-app Log Dose sheet is never blocked."**: off → "Every trigger logs. Guards expedited logs only — sticker, Siri, or Shortcuts."; total → "A second log is blocked while your last dose is still active."; window → "A second log is blocked for <N> h after your last dose." Not instantiated anywhere in the app target on main (`DoseGuardSection.swift:14-99`; `AppSettings.swift:21`; notes §0).

### Medication bar

- **FR-MED-18 — Fetch & shaping.** `refresh(now:)`: cutoff = `now - 24 h`; predicate `taken == true && takenAt > cutoff && isMockData == debugMockMode` (mock and real data mutually exclusive); sorted `takenAt` descending, **`fetchLimit = 50`**; fetch failure → `activeDoses = []` (silent empty). Active filter `takenAt + durationHours*3600 > now`, then **`.prefix(3)`** most-recent, then **reversed → oldest first** ("1st dose at top") — **maximum 3 rows displayed** (`MedicationBarViewModel.swift:59-77`).
- **FR-MED-19 — Daily ordinals.** Events are grouped by **base name** (first whitespace token, lowercased — "Concerta", "Concerta 36mg", "Concerta 27 mg" count together), filtered to `takenAt >= startOfDay(now)`, sorted ascending; `doseNumber` = index+1, `totalDosesToday` = group size. The grouping pool is the 24 h/fetchLimit-50 fetch, not a dedicated today-query (`MedicationBarViewModel.swift:82-95`).
- **FR-MED-20 — Row content & state words.** Each row: 24 pt medication glyph + title **"HH:mm · Name Dose"** (24-hour, time-first; when "Show Medication Name" is off, **only the time** shows — "row order already conveys sequence"; dose omitted when nil) + uppercase state word by fill fraction only: **`< 0.2` → "kicking in"; `< 0.8` → "active"; `< 1.0` → "wearing off"; `>= 1.0` → "worn off"** (unreachable — worn-off doses are filtered out). "Never red/alarming (locked decision)" (`MedicationBarView.swift:79-104`).
- **FR-MED-21 — Progress track & Reduce Motion.** `DoseTrack` height **19 pt**; neutral groove with gradient fill `Palette.medication → medicationFillEnd`; fill width `max(19, width × progress)` (minimum one capsule-height even at 0%). **Pulse** only during onset (`progress < 0.2`) and never under Reduce Motion: `.easeInOut(duration: 1.3).repeatForever(autoreverses: true)`, fill opacity dipping to **0.55**; the pulse stops via `onChange` when Reduce Motion toggles or onset ends. Progress changes animate `.easeInOut(duration: 0.5)` unless Reduce Motion. An in-track text label was deliberately dropped (failed WCAG AA contrast, max ~2.6:1 vs required 4.5:1, and overflowed at large Dynamic Type) (`MedicationBarView.swift:126-173`).
- **FR-MED-22 — Placement & visibility.** The bar renders inside `medicationBarOverlay(shown:)` pinned via `safeAreaInset(edge: .top)` below the nav bar; `ScreenContainer` applies it to every tab screen (`showsMedicationBar: Bool = true` default), and `RecordingDetailView` applies it directly. The whole bar renders only when visible **and** `activeDoses` is non-empty — **empty state = bar fully absent**, no placeholder, no loading or error states. Refresh on `.onAppear` plus the shared notification (`MedicationBarOverlay.swift:14-27`; `ScreenContainer.swift:79,82`; `RecordingDetailView.swift:41`; `MedicationBarView.swift:12, 44`).
- **FR-MED-23 — Visibility settings (active).** Settings section **"Medication Bar"** (mounted at `SettingsView.swift:181`): toggle **"Show Medication Bar"** (`@AppStorage("medicationBarVisible")`, default `true`, icon `pills.circle`; hint "Shows a medication progress bar at the top of each screen."); toggle **"Show Medication Name"** (`@AppStorage("medicationBarShowName")`, default `true`, icon `pill`; hint "Displays the medication name and dose in the bar.") — visible only when the first toggle is on (`MedicationBarSettingsSection.swift:9-…`).
- **FR-MED-24 — Bar accessibility.** Row label: `"[ordinal dose, ]<name dose>, taken at <HH:mm>, <percent>% elapsed, ends <HH:mm>. Tap to manage."` — the ordinal prefix ("1st"/"2nd"/"3rd"/"Nth") appears only when `totalDosesToday > 1` (`MedicationBarView.swift:106-121`).

### Dormant settings — My Medication & Confirmations

- **FR-MED-25 — "My Medication" section — Implemented, dormant in 1.0.** Header "My Medication"; footer: **"Logged by the Log My Meds action — sticker, Siri, or Shortcuts. Only this medication and dose are recorded; changing it never alters past logs."** Collapsible picker row with three value states: name+dose → `"<name> · <dose>"` in purple; name only → plain secondary; nothing → **"Set"** in accent. Expanded: chips of all catalog entries; a second "Dose" chip group appears once a catalog entry is selected. **Any medication change clears the dose** (`medicationDidChange()` nils `defaultMedicationDose` — "picking a medication never auto-commits a dose: the dose takes its own tap"). **"Clear Medication"** (destructive) removes the default; hint "Removes the default. Hands-free logging asks you to set a medication again; past logs keep what they recorded." Not instantiated on main (`MyMedicationSection.swift:21-96`; `SettingsViewModel.swift:97-99`; notes §0).
- **FR-MED-26 — "Confirmations" section — Implemented, dormant in 1.0.** Header "Confirmations"; footer: **"Off — discreet everywhere; the medication name stays inside the app. On — confirmations name the medication and dose (banner, spoken, and on the lock screen)."** Toggle **"Name medication in confirmations"** (default `false`). Preview banner: purple `pills.fill` icon + sample line + fixed sample time **"· 17:42"**; off → **"Dose logged"**; on → `"<name> <dose> logged"` using the current selection or neutral defaults "Elvanse" / "30 mg". Not instantiated on main (`MyMedicationSection.swift:64-76, 147-177`; notes §0).

## User flows

### Happy path — log a dose

1. User takes medication; the bar (if doses are active) shows the row with state "kicking in".
2. User taps the row → manage dialog → "Log new dose" → Log Dose sheet.
3. User picks "Concerta" from the chips → duration auto-fills 12 h, dose resets to "18 mg", onset row shows "≈ 60 min", disclaimer shows; user picks "36 mg", adjusts time, taps Save.
4. Event persists (`source: .manual`), notification posts, bar re-fetches, the new dose appears oldest-first with a fresh progress track and pulse.

### Alternate flows

- **Voice check-in mentions a dose:** extraction creates `source: .transcript` events (skipping names already logged manually), `takenAt` resolved via FR-MED-06 fuzzy-time mapping; these appear in the bar, timeline, and detail summary card.
- **Delete a dose:** row → "Delete this dose" → immediate deletion (no second confirmation); bar and timeline refresh via notification.
- **Bar hidden / no names shown:** Settings → Medication Bar toggles; bar reserves zero space when hidden or empty.
- **(Dormant) Hands-free:** "Log My Meds" → configured → guard `.off` → event logged with catalog duration → confirmation "Elvanse 30 mg logged · 9:41 AM" (or discreet "Dose logged · 9:41 AM"); guard armed and a dose active → "Your 8:12 AM dose is still active.", nothing written; not configured → "Set your medication first." + route to settings; history unreadable with an armed guard → `.failed`, nothing written (fail-closed).

## UI states

- **Bar empty / hidden / fetch failure:** bar fully absent — no placeholder, no loading, no error state (fetch failure silently yields an empty bar).
- **Log Dose sheet:** no loading/error/permission states; Save disabled on empty trimmed name; drag indicator visible.
- **Dormant intent outcomes:** calm dialogs only — "never an error surface"; `.failed` copy tells the user nothing was logged and to try again in the app.
- **Mock mode (`debugMockMode`):** the bar shows mock or real events exclusively; the guard ignores mock events entirely.

## Validation rules & constants

| Rule / constant | Value | Source |
|---|---|---|
| Catalog | 3 entries; Concerta 18/27/36/54 mg, onset 60 min, 12 h; Ritalin 5/10/20 mg, onset 20 min, 3 h; Elvanse 20/30/40/50/60/70 mg, onset 90 min, 10 h | `MedicationCatalog.swift:20-39` |
| Default effect duration | 10.0 h (model default, sheet default, bar log default) | `MedicationEvent.swift:19`; `MedicationLogSheet.swift:11`; `MedicationBarViewModel.swift:111` |
| Bar fetch | 24 h cutoff; fetchLimit 50; max 3 active rows, oldest first | `MedicationBarViewModel.swift:60, 66, 76` |
| Picker history | fetchLimit 100; no taken/mock filtering | `MedicationPickerViewModel.swift:63` |
| State words | <0.2 kicking in; <0.8 active; <1.0 wearing off; ≥1.0 worn off | `MedicationBarView.swift:81-84` |
| Dose track | 19 pt height (= min fill width); pulse min opacity 0.55, cycle 1.3 s; progress animation 0.5 s | `MedicationBarView.swift:138, 156, 161, 169` |
| Dose Guard window | 1–4 h options, default 2 h; boundary strict `<` | `DoseGuardSection.swift:49`; `AppSettings.swift:21`; `DoseGuardMode.swift:21` |
| Guard settings defaults | mode `"off"`; `defaultMedicationName/Dose` nil; `nameMedicationInConfirmations` false | `AppSettings.swift:18-22` |
| Fuzzy time map | morning/am/breakfast→8; afternoon/lunch/noon→13; evening/dinner/pm→19; night/bedtime/sleep→22 | `MedicationEvent.swift:117-120` |
| Save name trim | whitespace only (newline-only names technically savable) | `MedicationLogSheet.swift:36-63` |
| Sheet duration field | width 60, no clamping | `MedicationLogSheet.swift:137` |

## Edge cases

- **Save failures swallowed** in the manual flow (`logManualDose`/`deleteEvent` use `try?`) — no user-facing error anywhere on that path.
- **Dangling default medication** (name no longer in catalog) → `.notConfigured`, treated as not-set.
- **Unrecognized persisted `doseGuardModeRaw`** → `.off` (forward-safe decode).
- **Zero/negative `durationHours`** → `effectProgress` = 1 → dose never shows as active; guard `.total` never blocks on it.
- **Guard boundary:** exactly at window/effect end → guard opens (strict `<`).
- **Ordinal miscount risk:** the ordinal grouping pool is the last-24 h fetch (limit 50) — >50 events in 24 h could miscount.
- **Free-text (non-catalog) meds:** no dose options, no onset row, no disclaimer; duration keeps whatever was previously in the field (10 h on first open).
- **`clearAllData`** deletes all `MedicationEvent`s (standalone explicitly; recording-linked via cascade) and posts the change notification.
- **Guard is arms-length:** `.off` never even reads dose history; an unreadable history with an armed guard fails closed (`.failed`, nothing written) rather than bypassing.

## Acceptance criteria

1. The Log Dose sheet cannot be saved with an empty name, cannot set a future time, auto-fills duration/dose from the catalog on name change, and shows the exact SmPC disclaimer for catalog meds.
2. The bar shows at most 3 active doses, oldest first, each with the correct 20%/80%/100% state word, daily ordinal (base-name grouped), and "HH:mm · Name Dose" title (time-only when names are hidden); it disappears entirely when empty, hidden, or on fetch failure.
3. Deleting a dose from the manage dialog takes effect immediately without a second confirmation and refreshes every surface via `medicationEventsDidChange`.
4. A transcript mention "took my Concerta this morning" creates a transcript-sourced event at 08:00; a manual event of the same name suppresses the transcript one.
5. (Dormant, code-level) With guard `.window` = 2 h, a second expedited log 1:59 after the first is `.guarded` with nothing written; at exactly 2:00 it logs; with an armed guard and an unreadable history the outcome is `.failed` with nothing written; a save failure rolls back the insert before reporting `.failed`.
6. Reduce Motion on (or onset finished) produces no pulse on the dose track; progress changes render without animation.

## Source references

- `app-four/Models/MedicationCatalog.swift:4-44` · `MedicationEvent.swift:9-120` · `DoseGuardMode.swift:3-21` · `AppSettings.swift:18-22` · `Recording.swift:299-342`
- `app-four/Services/DoseLog/DoseLogService.swift:5-26` · `DoseLogServiceImpl.swift:18-82`
- `app-four/Intents/LogDefaultDoseIntent.swift:10-44` · `DoseConfirmationCopy.swift:10-20` · `AppIntentRouter.swift:54-57`
- `app-four/ViewModels/MedicationBarViewModel.swift:9-130` · `MedicationPickerViewModel.swift:5-63` · `SettingsViewModel.swift:97-118, 214-230`
- `app-four/Views/Components/MedicationBarView.swift:8-173` · `MedicationLogSheet.swift:8-192`
- `app-four/Views/Settings/MedicationBarSettingsSection.swift` · `MyMedicationSection.swift:21-177` · `DoseGuardSection.swift:14-99` · `app-four/Views/SettingsView.swift:78-85, 181`
- `app-four/DesignSystem/MedicationBarOverlay.swift:14-27` · `ScreenContainer.swift:79,82` · `app-four/Views/RecordingDetailView.swift:41` · `app-four/App/SquirlApp.swift:40, 53` · `app-four/Store/RecordingStore.swift:69, 113, 141-152`
- `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Palette.swift:12-17` · `docs/BACKLOG.md` §"Last updated"
- Sibling FSD: [Processing & Extraction](04-processing-and-extraction.md) · [Library & History](05-library-and-history.md) · [Insights](06-insights.md)
