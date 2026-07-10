<!-- Created: 2026-07-03 17:50 (WEST) · Updated: 2026-07-03 17:50 (WEST) -->
# Data Model — Calendar Day Context (spec 029)

## New `@Model`: `DayCalendarContext`

One row per journal day that has captured calendar context. Lives in `app-four/Models/DayCalendarContext.swift`; registered in **both** `Schema` arrays of `AppModelContainer` (production + preview).

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `UUID` | `UUID()` | No `@Attribute(.unique)` — Constitution IX |
| `dayKey` | `Date` | `.distantPast` | `Calendar.current.startOfDay` of the journal day, resolved **at capture time** (spec: device TZ at capture, never recomputed) |
| `eventsJSON` | `String?` | `nil` | Codable payload below, encoded once per capture (whole-set replace per FR-006) |
| `capturedAt` | `Date` | `.distantPast` | Set on every (re-)capture; drives the newest-wins dedupe guard |
| `titlesIncluded` | `Bool` | `true` | Whether titles were captured for this snapshot (FR-007; per-snapshot so settings changes stay non-retroactive per FR-009) |
| `isMockData` | `Bool` | `false` | Partition flag; every fetch filters `isMockData == mockMode` (RecordingStore pattern) |

**Invariants (store-enforced, not schema-enforced):**
- Exactly one row per (`dayKey`, `isMockData`) — `upsert` fetches-then-updates; never a unique constraint (Constitution IX / CloudKit path).
- Defensive read: if a fetch returns >1 row for a day, newest `capturedAt` wins and older rows are deleted (FR-006 semantics; future-proofs CloudKit merges).
- No relationship to `Recording` (deliberate): lifecycle coupling is behavioral (FR-014 — delete when the day's last check-in is deleted), implemented in `RecordingStore.deleteRecording`, not by cascade.

## Payload: `CapturedDayEvents` (Codable, versioned)

Encoded into `eventsJSON`. Mirrors FR-002's five facts exactly; nothing else is representable.

```swift
struct CapturedDayEvents: Codable {          // schemaVersion for forward migration
    var schemaVersion: Int = 1
    var events: [CapturedEvent]
}

struct CapturedEvent: Codable {
    var title: String?          // nil when titles-off at capture (FR-007)
    var start: Date
    var end: Date
    var isAllDay: Bool
    var attendeeCount: Int      // count ONLY — identities are never captured (FR-002)
    var availability: String    // "busy" | "free" | "tentative" | "unavailable" | "notSupported"
}
```

- **"Meeting" is derived at render** (`attendeeCount > 0`), never stored — no boolean to drift if the classification rule evolves.
- Declined events are filtered **at capture** (FR-008); they never enter the payload.
- Multi-day/≥24 h events appear in each covered day's payload; timed <24 h events only on their start day (spec edge case; attribution applied at capture, D3).

## Preferences (UserDefaults / `@AppStorage`)

| Key | Type | Default | Purpose |
|---|---|---|---|
| `calendarTitlesIncluded` | Bool | `true` | FR-007 toggle; first offered in the explainer (FR-001) |
| `calendarInvitationDismissed` | Bool | `false` | One-time Calendar-tab invitation card (FR-001) |
| `calendarExplainerDeclined` | Bool | `false` | "Declined the explainer" access state (Key Entities); Settings remains the way back in |
| `calendarExcludedIDs` | JSON `[String]` | `[]` | `EKCalendar.calendarIdentifier`s the user toggled **off** |
| `calendarIncludedOverrideIDs` | JSON `[String]` | `[]` | Identifiers the user toggled **on** despite a default-excluded class |

**Inclusion resolution** for a calendar `c`:
`included(c) = !excludedIDs.contains(c.id) && (includedOverrides.contains(c.id) || !defaultExcludedClass(c))`
where `defaultExcludedClass(c)` = birthday class (`type == .birthday || source == .birthdays`) or subscribed class (`type == .subscription || isSubscribed`) — research D5. Newly appearing calendars therefore follow class defaults until touched (spec FR-008 default rule generalized).

**Access state is never persisted** — always derived live from `EKEventStore.authorizationStatus(for: .event)` plus the two declination flags above (Key Entities: not requested · invitation dismissed/explainer declined · granted · denied/revoked · partial).

## State transitions

```
capture(dayKey):   (no row) ──insert──▶ row(capturedAt=now)
                   row      ──replace whole payload, capturedAt=now──▶ row'      (FR-006 latest-wins)
date change:       old day: if no check-ins remain ─▶ delete row (FR-014 logic)
                   new day: capture(dayKey')                                        (US1-AS7)
delete check-in:   if day's last ─▶ delete row (FR-014); else no-op
purge (FR-013):    delete all rows (current partition)
re-capture (FR-013): for each distinct check-in day ─▶ capture(dayKey) under current settings
sweep (FR-003):    for each check-in day with no row ─▶ capture(dayKey)            (never overwrites)
Clear All Data:    explicit fetch-and-delete of all rows (no cascade; SettingsViewModel.clearAllData)
```

## Export extension (FR-011)

- `JournalArchive` gains `dayContexts: [DayContextDTO]` (dayKey, capturedAt, titlesIncluded, events payload).
- `ExportServiceImpl.snapshot` adds a second fetch (same partition filter).
- `currentFormatVersion` **1 → 2**.
- Purge automatically empties future exports (DTOs derive from live rows).

## `TimelineDay` extension (rendering)

`MoodLibraryViewModel.TimelineDay` gains `var context: CapturedDayEvents?`, populated from the observable `DayContextStore` cache when grouping recordings by day; `FoldedDayCardHeader` renders the classified line from it and folds it into the composed VoiceOver label.
