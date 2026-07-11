<!-- Created: 2026-07-03 17:50 (WEST) · Updated: 2026-07-03 17:50 (WEST) -->
# Phase 0 Research — Calendar Day Context (spec 029)

Produced by three parallel research passes (codebase integration points · EventKit API verification against iOS 26.5 SDK headers + developer.apple.com · storage-shape analysis). Every claim below carries a file:line or doc citation in the underlying reports; the decisions are consolidated here.

## D1 — Snapshot storage: day-keyed `@Model` (`DayCalendarContext`)

- **Decision**: new `@Model DayCalendarContext` — one row per journal day; the day's events as a Codable JSON payload column; one-per-day enforced **procedurally** (fetch-or-update through a store), never via `@Attribute(.unique)`.
- **Rationale**: the spec's contract is day-scoped. FR-006 (exactly one context per day, latest capture wins) is the model's identity under B but an N-row consistency invariant under per-`Recording` JSON; FR-014 (delete with the day's *last* check-in) is a one-check hook in `RecordingStore.deleteRecording` under B but a data-loss bug under single-carrier A; FR-013 purge/re-capture and FR-003 coverage scans are cheap whole-table operations under B and journal-wide `Recording` mutations under A. Backdated saves (US1-AS7) are the same upsert path.
- **Alternatives considered**: (A) `calendarContextJSON: String?` on `Recording` (the `sleepEventJSON` pattern) — rejected: that pattern is for *per-check-in* facts; day context is a *per-day* fact (duplicate-or-nil-siblings failure modes on multi-check-in days). (A-hybrid, authoritative-flag) — same failures, more code. (B-normalized, per-event rows) — buys nothing while Phase 1 renders only a summary line and Phase 2 is live-query by design.
- **Constitution IX**: all attributes defaulted/optional, **no unique constraint**. One-per-day is a store invariant (`upsert(dayKey:)` = fetch by `dayKey`+`isMockData` → update or insert). Defensive read rule: >1 row for a day (future CloudKit merge) → newest `capturedAt` wins, older rows deleted — FR-006 semantics extended to the merge case.
- ⚠ **Do not copy the HealthKit plan literally**: `2026-06-13-healthkit-signals-implementation.md` uses `@Attribute(.unique) var dayStart` — written before Constitution IX; follow its day-keyed *shape* only. (Also: the BACKLOG's `superpowers/specs/...healthkit-signals-design.md` link is stale; only the `plans/` file exists.)

## D2 — EventKit access: one long-lived `EKEventStore` inside an actor

- **Decision**: `actor CalendarContextServiceImpl` owns the app's single `EKEventStore` instance and does all fetching; exposed behind a `CalendarContextService` protocol in `Services/Protocols.swift`, composed in `AppDependencies` (the `PendingTranscriptionServiceImpl` precedent).
- **Rationale**: Apple: "hold onto a long-lived instance … most likely as a singleton"; `events(matching:)` is synchronous and documented for off-main execution. `EKEventStore` is **not** `Sendable` and no explicit thread-safety statement exists in current docs → actor confinement is the safe Swift-6-ready design.
- **Authorization** (verified, iOS 17): `EKAuthorizationStatus` = notDetermined · restricted · denied · **fullAccess** · **writeOnly**; request via `requestFullAccessToEvents()` (async, prompts only once — thereafter Settings is the only path, matching FR-010); Info.plist needs **`NSCalendarsFullAccessUsageDescription`**. Revocation: re-read `authorizationStatus(for: .event)` on foreground; note iOS may terminate a running app on the toggle (widely observed, not documented) — both paths handled by re-check-on-active.

## D3 — Day query semantics

- **Decision**: capture queries `predicateForEvents(withStart: dayStart, end: nextDayStart, calendars: included)`; treat results as *events overlapping the window* (multi-day events surface on each covered day — matches the spec's edge-case rule); dedupe occurrences by `eventIdentifier + occurrenceDate`; then apply the spec's attribution rule in code (timed events < 24 h kept only on their **start** day; all-day / ≥ 24 h events kept on every covered day).
- **Verified**: 4-year predicate span limit (irrelevant per-day); results use the default time zone (matches the device-TZ-at-capture rule); recurring occurrences materialize as separate `EKEvent`s (`occurrenceDate`, `isDetached`).
- ⚠ **Device-verify before hardening** (flagged for the implement phase): (1) overlap semantics for multi-day events (community-established, not Apple-stated); (2) recurring occurrences sharing one `eventIdentifier`.

## D4 — Declined-event detection

- **Decision**: an event is "declined" iff `attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined`. No current-user attendee ⇒ not declined. `EKEvent.status` is **not** usable (header: only `.canceled` is reliable).
- ⚠ Server-dependent edge (Exchange/CalDAV may omit the self-attendee) — covered by the default-to-included rule; device-verify with one real declined invite.

## D5 — Birthday/holiday calendar classification

- **Decision**: default-excluded classes = (a) the system **Birthdays** calendar: `calendar.type == .birthday` or `source.sourceType == .birthdays` (first-class, verified); (b) **subscribed calendars**: `type == .subscription` **or** `calendar.isSubscribed` (trap verified in headers: CalDAV-subscribed calendars report `.calDAV` with `isSubscribed == true`). Everything else defaults to included.
- **Rationale**: EventKit has **no first-class "holiday" marker** (grep over all SDK headers: zero hits); holiday feeds are subscribed calendars; title-matching is locale-fragile and untestable. Excluding the whole subscribed class is deterministic, testable, and privacy-conservative; a subscribed team calendar defaults off but is one toggle away in the picker.
- ⚠ **Spec-wording note for the owner**: FR-008 says "calendars the operating system designates as birthday or holiday calendars"; the implementable rule is "the birthday calendar + subscribed calendars". Behaviorally a superset on the holiday side — flagged rather than silently diverging; suggest a one-line spec amendment at implement time.

## D6 — Capture triggers and the self-healing sweep

- **Decision**:
  - **Save-time hook**: fire-and-forget capture after the recording is persisted — voice path (`CheckInViewModel.attemptSave`, after `store.addRecording`) and text path (`RecordingStore.persistCheckInNote`); both funnel into one `captureContext(for: dayKey)` call. Off the critical path per FR-012/SC-002 (everything after the save is already background work).
  - **Date-change hooks**: both `createdAt` writers (`ExtractionReviewViewModel.confirm`, `RecordingDetailViewModel.updateDate`) re-capture the **new** day and clean the **vacated** day (if no check-ins remain there, delete its context — FR-014 logic reused).
  - **Sweep** (`captureMissingDayContexts()`): set-difference of distinct check-in days minus existing `dayKey`s → capture each. Runs at the app's existing hooks (launch `.task`, `scenePhase == .active`, and after access grant) — the `PendingTranscriptionServiceImpl.drainIfModelReady` pattern, including the `isDraining`-style re-entrancy guard and UUID-based (here: dayKey-based) work items so `@Model`s never cross actor hops. This single idempotent rule = initial backfill + failed-capture repair + revoke→re-grant fill-in (FR-003).
- **Batching**: newest-first, yield between batches; 300 local per-day queries is comfortably inside SC-007's 5 minutes.

## D7 — Store + UI observability

- **Decision**: `@MainActor @Observable final class DayContextStore` in `Store/` (peer of `RecordingStore`) owning fetch/upsert/purge/delete-for-day and an observable `[Date: DayContextSnapshot]` cache. `MoodLibraryViewModel.timelineDays` reads it when building `TimelineDay` (new optional context field); day cards refresh via observation — no NotificationCenter needed (though `medicationEventsDidChange` is the fallback precedent).
- The capture actor talks to the store via `await MainActor.run`-style hops passing value types only.

## D8 — Rendering the classified line

- **Decision**: extend `DayCardSummary`/`FoldedDayCardHeader.summaryLine` `Part` tokens with the context line ("N meetings" from events with `attendeeCount > 0`, then named events in day order); the header's composed VoiceOver label gains the context text. Titles-off payloads render "N meetings · M events". Truncation per the approved mockup (variant B, `mockups/context-line-variants.html`).
- Meeting-ness is **derived at render** from stored `attendeeCount` (no stored boolean to drift).

## D9 — Settings & preferences

- **Decision**: a new extracted section file in `Views/Settings/` (pattern: `DayCardSettingsSection`). ⚠ Naming collision: the existing day-card section is already titled "Calendar" — rename it "Day cards" (one-line change, flagged as its own task) so the new "Calendar" section owns the integration.
- **Preference persistence**: `@AppStorage`/UserDefaults — `calendarTitlesIncluded` (Bool, default true; set first in the explainer), `calendarInvitationDismissed` (Bool), `calendarExplainerDeclined` (Bool), plus two JSON-encoded string sets for the picker: `calendarExcludedIDs` (user-toggled-off) and `calendarIncludedOverrideIDs` (user-toggled-on for default-excluded classes) — two sets so newly appearing calendars follow the class defaults (D5) until the user touches them. `EKCalendar.calendarIdentifier` is the key (store-local; acceptable — a lost ID just reverts that calendar to its class default).
- Access state is **never persisted** (always live from `authorizationStatus`) except the two user-declination flags above.

## D10 — Mock mode

- **Decision**: `DayCalendarContext.isMockData` + `#Predicate` filtering at every fetch (the `RecordingStore.loadRecordings` pattern); `MockDataGenerator` seeds fixture contexts for its seeded days; **the capture/sweep pipeline is disabled entirely while `debugMockMode` is on** (spec: real calendar never read in mock mode).

## D11 — Export

- **Decision**: `JournalArchive` gains `dayContexts: [DayContextDTO]`; `ExportServiceImpl.snapshot` fetches the new model (same `isMockData` partition); **bump `currentFormatVersion` 1 → 2**. Purge (FR-013) then automatically empties future exports; FR-011's disclosure copy is a strings task in the export/privacy UI.

## D12 — Day identity

- **Decision**: `dayKey = Calendar.current.startOfDay(for: recording.createdAt)` resolved **at capture time** and stored (spec: device TZ at capture, never recomputed). One shared `DayKey.make(for:)` helper so save-hook, sweep, delete-hook, and rendering agree. Known app-wide behavior: timeline days themselves float with device TZ (existing convention) — a TZ change can re-bucket a day card away from its stored context; accepted, matches the spec's "not recomputed" rule and pre-existing app semantics.

## D13 — Permission flow UI

- **Decision**: entry points per spec FR-001 — permanent Settings Calendar section + one-time dismissible invitation card as the first child of `CalendarLibraryView`'s timeline `LazyVStack` (also shown in the empty-state branch), dismissal persisted via the view's existing `@AppStorage` shared-key pattern. Both lead to an explainer sheet (what's read · on-device promise · benefit · the title-capture choice) → `requestFullAccessToEvents()`. New UI starts as HTML mockups per Constitution I: the context line is already mocked (variant B); the invitation card, explainer sheet, and Settings section need mockups before SwiftUI.

## Resolved NEEDS-CLARIFICATION register

| Unknown (from Technical Context) | Resolution |
|---|---|
| Snapshot storage shape | D1 — day-keyed `@Model`, store-enforced one-per-day |
| Holiday-calendar identification | D5 — birthday class + subscribed class; spec-wording note flagged |
| Where capture hooks live | D6 — save paths + `createdAt` writers + foreground sweep |
| How day cards learn about late-arriving context | D7 — observable `DayContextStore` |
| Preference persistence shape | D9 — AppStorage + two ID sets |
| Export mechanics | D11 — DTO + formatVersion 2 |

## Device-verification checklist (carried into tasks)

1. Multi-day event overlap semantics of the day-window predicate (D3).
2. Recurring occurrences share `eventIdentifier`; dedupe key holds (D3).
3. Declined invite detection on a real invite (D4).
4. App relaunch/termination behavior when the calendar permission toggle flips mid-run (D2).
