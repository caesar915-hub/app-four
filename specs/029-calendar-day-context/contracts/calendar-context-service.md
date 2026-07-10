<!-- Created: 2026-07-03 17:50 (WEST) · Updated: 2026-07-03 17:50 (WEST) -->
# Contracts — Calendar Context (spec 029)

Protocol seams the feature exposes; the mock/test surface mirrors these exactly (7-actor-mock pattern). Declarations land in `app-four/Services/Protocols.swift` beside `TranscriptionService`.

## 1. `CalendarContextService` (actor seam over EventKit)

```swift
/// The app's only EventKit touchpoint. One long-lived EKEventStore, actor-confined
/// (EKEventStore is not Sendable; Apple documents off-main fetching + singleton lifetime).
protocol CalendarContextService: Sendable {
    /// Live authorization state — never cached across calls.
    func accessState() async -> CalendarAccessState
    /// Triggers the system prompt (first time only). Returns the resulting state.
    func requestFullAccess() async -> CalendarAccessState
    /// All event calendars on the device, with classification facts for the picker.
    func availableCalendars() async -> [CalendarDescriptor]
    /// Captures one journal day: full-day window in the device's current time zone,
    /// included calendars only, declined events filtered, attribution rule applied
    /// (timed <24h → start day only). Returns nil when access is unavailable.
    func captureDay(_ dayKey: Date, includeTitles: Bool, includedCalendarIDs: [String]) async -> CapturedDayEvents?
}

enum CalendarAccessState: Sendable, Equatable {
    case notDetermined, fullAccess, writeOnly, denied, restricted
}

struct CalendarDescriptor: Sendable, Identifiable, Equatable {
    let id: String            // EKCalendar.calendarIdentifier
    let title: String
    let isBirthdayClass: Bool // type == .birthday || source == .birthdays
    let isSubscribedClass: Bool // type == .subscription || isSubscribed
}
```

**Contract notes**
- `captureDay` returns value types only (`CapturedDayEvents` per data-model.md); no `EKEvent`/`@Model` crosses the actor boundary.
- Attendee identities never leave the service: it maps `attendees` → `attendeeCount` + declined-filter internally (FR-002).
- `captureDay` performs **no writes**; persistence belongs to `DayContextStore`.

## 2. `DayContextStore` (`@MainActor @Observable`, Store layer)

```swift
/// Owns DayCalendarContext persistence + the observable per-day cache day cards read.
@MainActor @Observable final class DayContextStore {
    private(set) var contextsByDay: [Date: CapturedDayEvents]   // current partition only

    func context(for dayKey: Date) -> CapturedDayEvents?
    /// One-per-day invariant lives HERE (fetch-or-update; newest-capturedAt dedupe guard).
    func upsert(dayKey: Date, payload: CapturedDayEvents, titlesIncluded: Bool)
    func deleteContext(for dayKey: Date)          // FR-014 + vacated-day cleanup
    func purgeAll()                               // FR-013 "remove captured calendar context"
    /// Distinct check-in days (current partition) that have no context row — sweep input.
    func daysLackingContext(checkInDays: Set<Date>) -> Set<Date>
    func reload()                                  // partition switch (debugMockMode)
}
```

## 3. `CalendarContextCoordinator` (capture orchestration)

```swift
/// Fire-and-forget triggers; all are no-ops while debugMockMode is on or access ≠ fullAccess.
protocol CalendarContextCoordinator: Sendable {
    func checkInSaved(dayKey: Date) async               // save-time hook (voice + text paths)
    func checkInDateChanged(from oldDay: Date, to newDay: Date) async // createdAt writers
    func checkInDeleted(dayKey: Date, dayStillHasCheckIns: Bool) async // FR-014
    func sweep() async                                   // FR-003 idempotent coverage; re-entrancy-coalesced
    func recaptureAll() async                            // FR-013 explicit user action
}
```

**Ordering contract**: `sweep()` never overwrites an existing row; `checkInSaved`/`recaptureAll` always replace (latest-capture-wins, FR-006).

## 4. UI surface contracts

| Surface | Contract |
|---|---|
| Invitation card (Calendar tab) | Rendered once while `!calendarInvitationDismissed && accessState == .notDetermined && !calendarExplainerDeclined`; first child of the timeline `LazyVStack` and of the empty state. Dismiss = permanent. |
| Explainer sheet | Reached from invitation or Settings; shows what-is-read / on-device promise / benefit + the `calendarTitlesIncluded` toggle **before** any system prompt (FR-001). Decline sets `calendarExplainerDeclined`, shows no prompt. |
| Settings "Calendar" section | Access-state row (live), per-calendar picker (inclusion resolution per data-model.md), titles toggle, `re-capture history` + `remove captured calendar context` actions (FR-013), path to system settings when denied/revoked (FR-010). Existing day-card section retitled "Day cards" to free the name. |
| Day-card context line | From `TimelineDay.context`: "N meetings" (attendeeCount > 0) + named events in day order, truncating per approved mockup (variant B); titles-off → "N meetings · M events"; absent context → nothing (FR-005). Composed VoiceOver label includes the line. |

## 5. Info.plist

| Key | Value (verbatim) |
|---|---|
| `NSCalendarsFullAccessUsageDescription` | "Squirl shows what was on your calendar alongside your check-ins. Events are read on this device only and never leave it." |
