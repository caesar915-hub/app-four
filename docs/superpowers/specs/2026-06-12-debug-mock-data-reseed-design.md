---
name: debug-mock-data-reseed
description: Add Seed / Wipe & Reseed buttons to the existing hidden debug sheet (TestServicesView) for on-demand mock data control without reinstalling
metadata:
  type: project
---

# Debug Mock Data Reseed

## Problem

The `#if DEBUG` seeding gate in `AppModelContainer` only fires when the store is empty. Once any real or mock recording exists, the seed is skipped silently. The only way to get fresh mock data is to delete the app and reinstall.

## Solution

Add a "Mock Data" section to the existing hidden debug sheet (`TestServicesView`, reachable via 5-tap on the version label in Settings). Two buttons:

- **Seed Mock Data** — calls `MockDataGenerator.generate(context:)`. Disabled when `recordings.count > 0`.
- **Wipe & Reseed** — deletes all `Recording` and `MedicationEvent` objects, then calls `MockDataGenerator.generate(context:)`. Destructive role.

## Files Changed

- `app-two/Views/TestServicesView.swift` — add one new `Section("Mock Data")` between "Metadata & List" and "Exports & Actions"

## Data Flow

Both buttons use the existing `@Environment(\.modelContext)` and `@Query` recordings already present in `TestServicesView`. No new types, no new files.

## Out of Scope

- Launch arguments
- Visible settings row
- Any change to the empty-store gate in `AppModelContainer`
