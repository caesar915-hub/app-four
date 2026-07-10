<!-- Created: 2026-07-03 17:50 (WEST) · Updated: 2026-07-03 17:50 (WEST) -->
# Quickstart Validation — Calendar Day Context (spec 029)

How to prove the feature works end-to-end. Owner runs device QA (workflow rule: no simulator); the agent runs build + tests.

## Prerequisites

- Branch `feat/029-calendar-day-context` off `main`; Xcode 16+, scheme `app-four`.
- A physical iPhone with ≥2 calendar accounts (one with a subscribed holidays calendar and the Birthdays calendar visible), some past events across several days, one multi-day event, one recurring event, one declined invitation.
- An existing journal with check-ins on several past days (or seed via mock mode first, then switch to real data).

## Build & tests (agent, every change)

```bash
# Full serial suite — parallel is known-flaky (12 false failures)
xcodebuild -project app-four.xcodeproj -scheme app-four -destination 'generic/platform=iOS' build
xcodebuild test -project app-four.xcodeproj -scheme app-four -parallel-testing-enabled NO -destination <owner device>
```

New Swift Testing suites expected GREEN (written RED-first per Constitution X): `DayCalendarContextTests` (model/payload round-trip), `DayContextStoreTests` (upsert invariant, newest-wins dedupe, purge, daysLackingContext, mock partition), `CalendarContextCoordinatorTests` (save/date-change/delete/sweep/recapture against a `MockCalendarContextService`), `CalendarInclusionTests` (class defaults + override sets), `CapturedDayEventsClassificationTests` (attribution rule, declined filter, titles-off), `ExportServiceTests` extension (formatVersion 2 + DayContextDTO round-trip).

## Device QA script (owner)

| # | Scenario | Expect |
|---|---|---|
| 1 | Fresh install → Calendar tab | One dismissible invitation card; dismiss → never returns; Settings › Calendar still offers the flow |
| 2 | Settings › Calendar → explainer | What-is-read + on-device promise + titles toggle shown **before** the iOS prompt |
| 3 | Grant full access | Backfill fills past check-in days within minutes (SC-007); day cards show classified lines ("3 meetings · Dentist") |
| 4 | Save a new check-in on a day with events | Context line appears; save flow feels unchanged (SC-002) |
| 5 | Day with 0 events / all calendars excluded | No context line, no placeholder (FR-005) |
| 6 | Exclude a calendar → new check-in | Excluded calendar's events absent from the new capture; old days unchanged (FR-009) |
| 7 | Titles off → new check-in | Line reads "N meetings · M events" (FR-007) |
| 8 | Re-capture history | Old days now honor current settings (FR-013) |
| 9 | Remove captured calendar context | All lines vanish; export no longer contains context |
| 10 | Backdate a check-in to a past day | That past day gains/refreshes context (US1-AS7) |
| 11 | Second check-in same day (after adding an event) | Line updates — latest capture wins (FR-006) |
| 12 | Delete the day's last check-in | Context gone with it; multi-check-in day keeps context (FR-014) |
| 13 | Revoke access in iOS Settings → relaunch | Old lines still render (FR-004/SC-005); no errors, no re-prompt; Settings shows state + path to system settings |
| 14 | Re-grant access | Gap days self-heal via sweep (FR-003) |
| 15 | Declined invitation on an included calendar | Never appears in capture (FR-008) |
| 16 | Multi-day event · recurring event | Multi-day appears on each covered day; recurrence appears per occurrence day — **also verifies research D3's two device-verify items** |
| 17 | Mock mode ON | Fixture context lines visible; real calendar never queried (verify via no permission prompt on a fresh mock-mode install) |
| 18 | Encrypted export → decrypt | `dayContexts` present, formatVersion 2; matches on-screen days |
| 19 | VoiceOver on a day card | Composed label includes the context line |
| 20 | Toggle calendar permission mid-run in iOS Settings | App relaunch or foreground re-check both land in a correct state (research D2 caveat) |

## Definition of done (gates before PR)

Build green · full serial suite green · HTML mockups existed before each new SwiftUI surface (invitation, explainer, Settings section; context line already mocked) · `/code-review` on the diff · owner device QA above · trackers updated. Merge only after owner QA (repo rule: never on code review alone).
