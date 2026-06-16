# Phase 1 Data Model: Medication Bar Consistency

**Feature**: `002-medication-bar-consistency` | **Branch**: `feat/feedback-specs` | **Date**: 2026-06-15
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Summary

**There is no persisted schema change in this feature.** It is a presentation/interaction change to the medication bar (tap target, fixed position, recording-detail presentation, spacing). No SwiftData entity is added, removed, or altered; no attribute is added, removed, retyped, or constrained; no relationship is changed.

## Entities

**None added or modified.**

The medication bar's displayed content derives from existing active-dose records, which this feature reads only and does not change. No view model gains persistence logic (Principle VIII). No new persisted state is introduced; any layout state (e.g. a measured frame used for cross-screen position checks) is in-memory SwiftUI state, not persisted, and never written to the store.

| Concern | This feature |
|---|---|
| Entities added | None |
| Attributes added / changed / retyped | None |
| Relationships added / changed | None |
| Unique constraints (`@Attribute(.unique)`) | None added |
| Required (non-defaulted) attributes | None added |
| Migration required | No — schema unchanged |
| New persisted state | None |

## Principle IX — Pre-Release Data Posture (PASS)

The schema remains exactly as-is and therefore stays CloudKit-compatible: every non-relationship attribute is already optional or defaulted, and no `@Attribute(.unique)` exists or is introduced here. Because nothing in the persisted model changes, the future opt-in CloudKit sync path is preserved unchanged, and the `isMockData` partitioning of mock vs. real data is untouched. No Complexity Tracking justification is required (no unique/required attribute is added).

## Behavioural contract

This is an on-device UI feature with no external API and no network surface, so there is no `contracts/` directory. The behavioural contract is the acceptance scenarios and Functional Requirements in [spec.md](./spec.md) (FR-001…FR-008, SC-001…SC-006), validated by the manual steps and automated tests in [quickstart.md](./quickstart.md).
