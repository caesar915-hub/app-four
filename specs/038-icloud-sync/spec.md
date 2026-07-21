<!-- Created: 2026-07-18 15:05 (WEST) · Updated: 2026-07-18 15:16 (WEST) -->
# Feature Specification: Opt-in iCloud Sync

**Feature Branch**: `038-icloud-sync`

**Created**: 2026-07-18

**Status**: Draft

**Input**: User description: "Opt-in iCloud sync (CloudKit private database) for Squirl's journal data — off by default per Constitution VI; user turns it on in Settings. Syncs the SwiftData store (recordings/transcripts, mood/energy/focus, medication log) across a user's own devices via their private iCloud account, developer-inaccessible. Prerequisite: remove @Attribute(.unique) from Recording.id (CloudKit-incompatible) and keep a plain non-unique UUID as the stable cross-device key. Marketed as end-to-end encrypted only under user's Advanced Data Protection + encrypted fields; otherwise 'private to your iCloud.' Distinct from the existing manual encrypted export (spec 017): sync = automatic multi-device, not point-in-time backup. Target v1.2, post-launch."

---

## Overview

Today a Squirl journal lives on exactly one device. If a user gets a new phone, adds an iPad, or loses their device, their history does not follow them — the only recourse is the manual encrypted export/import from spec 017, which is a deliberate point-in-time file the user must remember to make and move. This feature adds **automatic, opt-in sync of a user's journal across their own Apple devices** through their private iCloud account, so a check-in written on the iPhone is there on the iPad, and a replaced phone comes back with the full history — without any manual step, and without the journal ever becoming reachable by Squirl (there is no Squirl server; data lives only in the user's own iCloud account).

Sync is **off by default and never touches the network until the user turns it on** (Constitution VI, non-negotiable). It is a distinct capability from the spec 017 encrypted export, which stays as the portable, cross-ecosystem, point-in-time backup.

---

## Clarifications

### Session 2026-07-18

- Q: Do raw audio recordings sync, or stay device-local? → A: Transcripts + data only — raw audio stays on the device where it was recorded; it is not synced in this phase.
- Q: On "remove my data from iCloud," what happens to the user's other synced devices? → A: Cloud copy only — sync is disabled first, then only the iCloud copy is deleted; the removal does NOT propagate as entry-deletions, so every other device keeps its full local journal.
- Q: Which data syncs — a defined subset or the whole store? → A: Journal content plus calendar day-context snapshots (spec 029); app settings, diagnostics/logs, and mock/debug data are excluded.
- Q: Mark sensitive fields for CloudKit field-level encryption? → A: Yes — transcripts and medication names are field-level encrypted, giving true end-to-end encryption when the user has Advanced Data Protection enabled.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Turn on sync and find my journal on a second device (Priority: P1)

A user who owns an iPhone and an iPad (both signed into the same Apple Account) opens Settings on the iPhone, turns on "Sync with iCloud," and confirms a short privacy explanation. Their existing check-ins, moods, and medication log upload to their private iCloud account. On the iPad they turn the same setting on, and their journal appears — the same days, the same entries — with no export file, no AirDrop, no manual import.

**Why this priority**: This is the core value and the smallest slice that proves the whole mechanism end-to-end: a real opt-in gate, a real upload, a real download on a second device. Without it there is no feature. It also delivers the single most-requested journaling outcome — "my history is on all my devices."

**Independent Test**: On two devices signed into the same test Apple Account, enable sync on device A (with existing entries) and then on device B (empty). Confirm device B populates with device A's entries, and that before opt-in on either device no journal data is transmitted.

**Acceptance Scenarios**:

1. **Given** a fresh install with sync never enabled, **When** the user browses the app and records check-ins, **Then** no journal data leaves the device (sync is off by default).
2. **Given** the user is signed into iCloud and opens Settings, **When** they turn on "Sync with iCloud," **Then** they see a plain-language explanation of what syncs, that it goes to their own iCloud account, and that Squirl cannot read it — and sync begins only after they confirm.
3. **Given** sync is enabled on device A with existing entries, **When** the user enables sync on device B under the same Apple Account, **Then** device A's entries appear on device B.
4. **Given** entries exist on both device A (synced) and device B (created locally before enabling), **When** device B enables sync, **Then** the two sets merge with no duplicate entries and no lost entries.

---

### User Story 2 - New and edited entries propagate automatically (Priority: P2)

With sync on across two devices, a user records a check-in on the iPhone during the day; that evening it is already on the iPad. An edit to a transcript, a changed mood, or a logged dose made on one device shows up on the other. Deleting an entry on one device deletes it on the other — it does not silently come back.

**Why this priority**: Multi-device value is only real if it is continuous, not a one-time import. This is what separates "sync" from "restore." It is P2 because US1 already delivers a demonstrable MVP (initial population); ongoing propagation is the next layer.

**Independent Test**: With both devices synced, create/edit/delete entries on each in turn and confirm each change reaches the other device within a reasonable time under normal connectivity, with deletes propagating as deletes.

**Acceptance Scenarios**:

1. **Given** both devices synced, **When** a check-in is recorded on device A, **Then** it appears on device B within one minute under normal connectivity.
2. **Given** an entry present on both devices, **When** its mood/energy/focus or transcript is edited on device A, **Then** device B reflects the edit.
3. **Given** an entry present on both devices, **When** it is deleted on device A, **Then** it is removed on device B and does not reappear.
4. **Given** the same entry is edited on both devices while one is offline, **When** both reconnect, **Then** the entries converge to a single consistent version with no corruption or duplication.

---

### User Story 3 - Stay in control: off by default, honest status, turn off and remove (Priority: P2)

A privacy-sensitive user wants sync on their terms. Settings shows whether sync is on, which account it uses, and when it last synced. They can turn sync off at any time; when off, nothing further is transmitted and their on-device journal is untouched. They can also choose to remove their journal data from iCloud entirely. The messaging never overstates protection: it claims end-to-end encryption only when the user's account actually qualifies for it, and otherwise states plainly that the data is private to their iCloud account and unreadable by Squirl.

**Why this priority**: Constitution VI makes opt-in/off-by-default and truthful privacy posture non-negotiable, and the audience is overwhelm- and privacy-sensitive. The consent gate itself is already part of US1; this story covers the richer control surface (status, disable, remove, accurate messaging) that makes the feature trustworthy.

**Independent Test**: Enable then disable sync; confirm transmission stops and local data remains. Trigger "remove from iCloud" and confirm the cloud copy is deleted while the local journal stays. Verify the privacy copy shown matches the account's actual protection state.

**Acceptance Scenarios**:

1. **Given** sync has never been enabled, **When** the user first opens Settings, **Then** the sync control is off.
2. **Given** sync is on, **When** the user opens Settings, **Then** they see it is on, the account it uses, and the last successful sync time.
3. **Given** sync is on, **When** the user turns it off, **Then** no further journal data is transmitted and every entry remains available on the device.
4. **Given** sync has been used across two devices, **When** the user chooses "remove my data from iCloud," **Then** the journal copy in iCloud is deleted within a bounded time, the initiating device's local journal is unaffected, and the other device keeps its full local journal (the removal does not delete entries on it).
5. **Given** the user's account does not qualify for end-to-end encryption, **When** they read the sync explanation, **Then** it does not claim end-to-end encryption and instead states the data is private to their iCloud account and not readable by Squirl.

---

### User Story 4 - Recover my journal on a new or replaced device (Priority: P3)

A user upgrades to a new iPhone (or replaces a lost one), installs Squirl, signs into their Apple Account, and turns on sync. Their journal — days, transcripts, moods, medication log — comes back without them ever having made or located an export file.

**Why this priority**: This is the backup/recovery dimension and a strong retention hook, but it is mostly the same mechanism as US1 viewed from the "I lost my data" angle; it rides on US1/US2 and so is P3.

**Independent Test**: Enable sync on device A, wipe/replace with a clean install signed into the same account, enable sync, and confirm the journal is restored.

**Acceptance Scenarios**:

1. **Given** a user with sync enabled on device A, **When** they set up a clean install on a new device under the same Apple Account and enable sync, **Then** their synced journal is restored.
2. **Given** raw audio is device-local and not synced (see Assumptions), **When** the journal is restored on the new device, **Then** transcripts and structured data are present and any entry whose audio is unavailable is shown in a clear "audio not on this device" state rather than as an error.

---

### Edge Cases

- **Not signed into iCloud / iCloud Drive off**: the user tries to enable sync without an available iCloud account → sync does not enable and a clear message explains what is required, with no silent failure.
- **iCloud storage full**: sync cannot complete → the app surfaces the stalled state honestly (not a fake "synced") and resumes when space is available.
- **Account signed out or changed** on a device: sync pauses; the local journal is never deleted as a side effect; re-signing resumes.
- **Turn sync off, then on again** on the same device: entries re-link by their stable identity and are not duplicated.
- **Delete-then-resync**: a deletion is never resurrected by a stale copy from another device.
- **Large existing journal on first enable**: initial upload may take time and battery/network → the app shows progress and does not block use of the app.
- **Offline edits on two devices to the same entry**: converge to one consistent version without corruption.
- **Advanced Data Protection state changes**: the privacy messaging reflects the current protection level truthfully.
- **Audio-not-synced entries on a second device**: presented as a defined state ("audio stays on the device it was recorded on"), never as a broken/failed entry.
- **Remove-from-iCloud vs. multi-device**: removing the iCloud copy disables sync and purges only the cloud store — it is NOT a fan-out delete; the user's other devices keep their local journals intact.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Sync MUST be OFF by default on every fresh install; no journal data may be transmitted off the device until the user explicitly enables sync (Constitution VI).
- **FR-002**: The app MUST provide a single user-facing control in Settings to turn iCloud sync on and off.
- **FR-003**: Before the first upload, the app MUST present a plain-language explanation of what data syncs, that it goes to the user's own iCloud account, and that Squirl cannot read it, and MUST begin syncing only after the user confirms.
- **FR-004**: When enabled, the app MUST sync the user's journal — check-in entries and their transcripts, mood/energy/focus signals, sleep/side-effect data, the medication log, and calendar day-context snapshots (spec 029) — across the user's Apple devices signed into the same Apple Account. It MUST NOT sync app settings, diagnostics/logs, mock/debug data, the downloaded transcription model, or raw audio.
- **FR-005**: Sync MUST propagate creations, edits, and deletions in both directions; a deletion MUST NOT be resurrected by another device's stale copy.
- **FR-006**: When the same entry is modified on multiple devices, the system MUST converge on a single consistent version without data corruption or duplicate entries.
- **FR-007**: Entries MUST be de-duplicated across devices by a stable per-entry identity that survives upload/download and re-enabling sync (no `@Attribute(.unique)`, per Constitution IX).
- **FR-008**: The journal data MUST reside only in the user's private iCloud account and MUST NOT be accessible to Squirl/the developer or transmitted to any developer-controlled server.
- **FR-009**: Settings MUST truthfully display sync status: on/off, the account in use, and the time of the last successful sync.
- **FR-010**: The user MUST be able to turn sync off at any time; when off, no further journal data is transmitted and the on-device journal remains fully intact.
- **FR-011**: The user MUST be able to remove their journal data from iCloud; doing so MUST first disable sync on the initiating device, then delete ONLY the cloud copy within a bounded time. The removal MUST NOT propagate as entry-deletions to the user's other devices — every device retains its full local journal — and MUST NOT affect the initiating device's local journal.
- **FR-012**: Privacy messaging MUST claim end-to-end encryption ONLY when the user's account qualifies for it (Advanced Data Protection enabled and applicable fields protected); otherwise it MUST state the data is private to the user's iCloud account and not readable by Squirl — and MUST NOT overstate protection.
- **FR-013**: When iCloud is unavailable (not signed in, storage full, network down), the app MUST surface the real state to the user and MUST NOT report a successful or complete sync that did not occur.
- **FR-014**: The local journal store MUST remain excluded from iCloud *device backup* (`isExcludedFromBackupKey`, Constitution VI) even while syncing to the private iCloud database — these are distinct mechanisms and both invariants hold simultaneously.
- **FR-015**: Enabling and using sync MUST NOT change the App Store privacy posture from "Data Not Collected" — because the developer cannot access the synced data — and any future change to that posture MUST be re-verified against Apple's current definition of data collection before shipping.
- **FR-016**: Sensitive content — at minimum transcripts and medication names — MUST be marked for field-level encryption so that, when the user has Advanced Data Protection enabled, that content is end-to-end encrypted with keys held only on the user's own devices. This MUST NOT degrade on-device search or filtering, which operate against the local store rather than the cloud copy.

### Key Entities *(include if feature involves data)*

- **Sync state**: whether sync is enabled, the associated Apple Account/iCloud availability, last successful sync time, and current status (idle / syncing / stalled / unavailable). User-controlled; drives all Settings display.
- **Synced journal data set**: the set of journal records that sync — check-in entries, transcripts, mood/energy/focus and related signals, medication log entries, and calendar day-context snapshots (spec 029). Each carries a stable, non-unique identity used for cross-device de-duplication. Sensitive fields (transcripts, medication names) are field-level encrypted (FR-016). **Excludes** raw audio blobs in this phase (see Assumptions).
- **Device-local data**: data that does NOT sync — raw audio recordings, the downloaded transcription model, diagnostics/logs, and any mock/debug data. Remains on the device on which it was created.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With sync enabled on two devices under the same account, an entry created on one device is visible on the other within **one minute** under normal connectivity.
- **SC-002**: On a fresh install, **zero** bytes of journal data are transmitted off the device before the user explicitly enables sync (verifiable by observing no sync traffic pre-opt-in).
- **SC-003**: A user replacing their device recovers **100%** of their synced entries (transcripts + structured data + medication log) by signing in and enabling sync, with no manual export/import step.
- **SC-004**: After turning sync off, **no** further journal data is transmitted; after "remove from iCloud," the cloud copy is gone within a bounded time while **100%** of the local journal remains.
- **SC-005**: Across all sync scenarios, **no** journal entry is ever duplicated or lost as a result of syncing, including offline-edit convergence and re-enabling sync.
- **SC-006**: In every state, the sync status and privacy messaging shown to the user matches reality (no false "synced," no overstated encryption claim) — verified against each defined state.
- **SC-007**: Enabling sync leaves the App Store privacy label defensibly at "Data Not Collected," confirmed against Apple's current data-collection definition.

## Assumptions

- **Raw audio is NOT synced in this phase** (confirmed in Clarifications 2026-07-18). Sync covers transcripts, structured signals (mood/energy/focus, sleep, side effects), the medication log, and calendar day-context snapshots. Raw audio recordings stay on the device where they were recorded. Rationale: audio blobs are large relative to typical iCloud quotas and bandwidth, while the transcript is the durable, searchable value; full audio portability is a defensible later phase. An entry whose audio is absent on a given device is shown as a defined "audio stays on its original device" state, not an error.
- **Sync targets the user's own Apple devices** signed into the same Apple Account; cross-account sharing, collaboration, and non-Apple platforms are out of scope.
- **Conflict resolution is last-writer-wins at field granularity** (the platform default), which is acceptable for a single person syncing their own journal across their own devices; no custom merge UI is offered.
- **On first enable**, existing local entries upload to iCloud; on a second device, cloud entries download and merge with any pre-existing local entries, de-duplicated by stable identity.
- **The versioned schema + migration mechanism** introduced by the App Store readiness work (`SquirlSchemaV1` / migration plan on `fix/app-store-readiness`) is in place before this feature ships, so removing `@Attribute(.unique)` from `Recording.id` is a forward schema migration on real user data, **not** a wipe. This feature MUST NOT rely on the pre-release wipe-on-conflict path once the app has shipped.
- **End-to-end encryption depends on the user**, specifically their Advanced Data Protection setting and the fields marked for encryption; the app therefore treats E2E as a conditional claim, not a guarantee.
- **Distinct from spec 017**: the manual encrypted export/import remains the portable, cross-ecosystem, point-in-time backup; this feature is automatic continuous multi-device sync. Neither replaces the other.

## Dependencies

- **Constitution VI** (opt-in, off by default; store excluded from iCloud backup; sensitive health data) and **Constitution IX** (CloudKit-compatible schema: no `@Attribute(.unique)`, attributes optional/defaulted) directly govern this feature.
- **Schema prerequisite**: remove `@Attribute(.unique)` from `Recording.id` and audit every synced `@Model` — including `DayCalendarContext` (spec 029), now in the synced set — for `.unique` and for required non-defaulted attributes; introduce a stable non-unique `UUID` cross-device key. This is a hard precondition and interacts with the migration mechanism above.
- **Depends on** the App Store readiness work (versioned schema + crash-safe container) being merged to `main`, so the schema change is a migration rather than a data wipe.
- **Relationship to spec 017** (Settings — recovery, privacy & clarity): coexists; both live in the Settings "Your data" area.

## Out of Scope

- Syncing raw audio recordings (deferred; see Assumptions).
- Sharing or collaborating on a journal across different people/accounts.
- Sync to non-Apple platforms or a web client.
- Selective/partial sync (choosing which entries or date ranges sync).
- Syncing the downloaded transcription model, diagnostics, logs, or mock/debug data.
- A custom conflict-resolution UI beyond automatic convergence.
