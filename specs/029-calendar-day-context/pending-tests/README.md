<!-- Created: 2026-07-18 16:28 (WEST) · Updated: 2026-07-18 16:28 (WEST) -->
# Parked spec-029 tests (RED, no implementation yet)

These 10 files are the **test-first (RED) tests for spec 029 "Calendar Day Context"**. They were written before the 029 implementation and reference types that **do not exist in the app target** (`CalendarContextService`, `CalendarAccessState`, `CalendarDescriptor`, `CapturedDayEvents`, `DayCalendarContext`, `DayContextStore`, `CapturedEvent`).

## Why they're here

They were sitting untracked in `app-fourTests/`. With Xcode 16 synchronized folders, everything under `app-fourTests/` is auto-compiled — so these files made the **whole test target fail to build** ("Cannot find type … in scope" ×13), which blocked *every* other test (including unrelated features) from running.

Parked here (moved, **not deleted** — fully intact) on **2026-07-18** while implementing spec 038 (iCloud Sync), so the test target compiles again. Nothing was lost.

## How to restore

When spec 029 is implemented (`/speckit-implement` on [../plan.md](../plan.md) / [../tasks.md](../tasks.md)), and the 029 types exist in the app target, move these back:

```sh
mv specs/029-calendar-day-context/pending-tests/*.swift app-fourTests/
mkdir -p app-fourTests/Mocks && mv specs/029-calendar-day-context/pending-tests/Mocks/*.swift app-fourTests/Mocks/
```

Then build the test target — they should go RED→GREEN as 029 lands.

## Files

- `CalendarAccessPresentationTests.swift`
- `CalendarContextCoordinatorReentrancyTests.swift`
- `CalendarContextCoordinatorTests.swift`
- `CalendarInclusionTests.swift`
- `CapturedDayEventsClassificationTests.swift`
- `DayCalendarContextTests.swift`
- `DayContextLineTests.swift`
- `DayContextStoreTests.swift`
- `MoodLibraryContextTests.swift`
- `Mocks/MockCalendarContextService.swift`
