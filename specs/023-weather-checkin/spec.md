# Feature Specification: Weather at Check-In

**Feature Branch**: `feat/weather-checkin`

**Created**: 2026-06-25

**Status**: Ready for planning — Constitution Principle VI gate RESOLVED via amendment v1.3.0 (scoped first-party weather-lookup exception)

**Input**: User description: "Every mood check-in (voice and text) silently captures the current weather and freezes a snapshot (condition, temperature, icon, capture time) onto that entry. Best-effort: never blocks or fails a check-in. Shows on entry detail; Insights gains a mood-vs-weather correlation. One-shot, reduced-accuracy location only. Mandatory weather attribution wherever weather is shown."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Weather is recorded automatically with each check-in (Priority: P1)

When someone logs how they feel — by voice or by typing — the app, on its own, notes
the current weather (a condition like "clear" or "rain", the temperature, and an icon)
and attaches it to that entry. The person does nothing extra. If the weather can't be
obtained for any reason, the check-in still completes exactly as before, just without
weather.

**Why this priority**: This is the foundation — without automatic, unobtrusive capture
there is no weather data to show or correlate. It must feel invisible and never get in
the way of the core act of checking in.

**Independent Test**: Log a voice check-in and a text check-in with location permission
granted and connectivity available; confirm each entry ends up with a weather snapshot.
Repeat with permission denied and with no connectivity; confirm both check-ins still
complete promptly and simply carry no weather.

**Acceptance Scenarios**:

1. **Given** location permission granted and network available, **When** I complete a
   voice check-in, **Then** the entry is saved immediately and, shortly after, a weather
   snapshot (condition + temperature + icon + capture time) is attached to it.
2. **Given** the same conditions, **When** I complete a text check-in, **Then** the entry
   likewise gains a weather snapshot.
3. **Given** location permission is denied, **When** I complete a check-in, **Then** the
   check-in completes with no added delay and the entry simply has no weather.
4. **Given** the device is offline, **When** I complete a check-in, **Then** the check-in
   completes normally with no weather and no error shown to me.
5. **Given** I delete an entry immediately after creating it, **When** weather retrieval
   later returns, **Then** nothing is written and no error occurs.

---

### User Story 2 - See the weather on a past entry (Priority: P2)

When reviewing a past check-in, the person can see the weather that was recorded at the
time — an icon, the temperature, and the condition — alongside the other context for
that entry.

**Why this priority**: Makes the captured data visible and meaningful; turns an invisible
background capture into something the user can recognise and trust.

**Independent Test**: Open the detail view of an entry that has a weather snapshot and
confirm the weather is displayed legibly with the required provider attribution; open an
entry with no snapshot and confirm the weather area is gracefully absent.

**Acceptance Scenarios**:

1. **Given** an entry with a weather snapshot, **When** I open its detail, **Then** I see
   the condition, temperature (in my locale's units), and an icon, with the weather
   provider's attribution visible.
2. **Given** an entry without a weather snapshot (older entry, or capture failed), **When**
   I open its detail, **Then** no weather is shown and there is no empty placeholder or
   error.

---

### User Story 3 - Discover how mood relates to weather (Priority: P3)

In Insights, the person can see a plain-language read of how their mood tends to vary with
weather — for example, "your mood averages higher on clear days."

**Why this priority**: This is the ultimate payoff (the reason to capture weather at all),
but it depends on P1 having collected enough data first, so it is sequenced last.

**Independent Test**: With a seeded set of weathered entries spanning at least two distinct
conditions, open Insights and confirm a mood-vs-weather summary appears; with too few
weathered entries, confirm the summary is absent (gated, not shown empty).

**Acceptance Scenarios**:

1. **Given** enough weathered entries across at least two weather conditions, **When** I
   open Insights, **Then** I see a mood-vs-weather correlation summary in plain language.
2. **Given** too few weathered entries, **When** I open Insights, **Then** the correlation
   summary is not shown (no empty or misleading state).

---

### Edge Cases

- **Permission not yet decided**: first check-in triggers the location prompt; whatever the
  user chooses, the check-in itself must complete without waiting on the prompt outcome.
- **Permission denied / restricted**: entries carry no weather; the app never nags.
- **No network / provider error / timeout**: best-effort capture quietly yields nothing.
- **Entry deleted before weather returns**: the late result is discarded safely.
- **Locale units**: temperature respects the user's preferred unit (°C/°F).
- **Pre-feature entries**: existing entries simply have no weather and render cleanly.
- **Sparse data**: Insights correlation stays hidden until the data threshold is met.
- **Stale/duplicate prompts**: weather capture must not re-prompt for location on every
  check-in once a decision exists.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST automatically attempt to record the current weather for the
  user's location at the time of every check-in, for both voice and text check-ins.
- **FR-002**: Weather capture MUST be best-effort and MUST NOT block, delay, or cause the
  failure of a check-in. The entry MUST be saved and confirmed independently of whether
  weather is obtained.
- **FR-003**: A weather record MUST contain, at minimum: a weather condition, a temperature,
  a display icon, and the time the weather was captured.
- **FR-004**: The system MUST request location access in a standard, user-respecting way and
  MUST remain fully functional if access is denied — affected entries simply carry no weather.
- **FR-005**: The system MUST use only a single, on-demand, reduced-accuracy location lookup
  per capture. Continuous or background location tracking MUST NOT be used.
- **FR-006 (Privacy, NON-NEGOTIABLE)**: The weather lookup MUST transmit only the coarse
  location needed to obtain weather. NO audio, transcript, mood, emotion, health, or
  medication data may be transmitted off-device. Retrieved weather MUST be stored only
  on-device, alongside the entry.
- **FR-007**: The system MUST display an entry's weather snapshot on that entry's detail view
  when one exists, and MUST omit the weather area cleanly when one does not.
- **FR-008**: Insights MUST present a plain-language mood-vs-weather correlation once a
  minimum data threshold is met, and MUST hide it otherwise.
- **FR-009**: The system MUST display the weather provider's required attribution wherever
  weather data is shown to the user.
- **FR-010**: Temperature MUST be presented in the unit appropriate to the user's locale/
  system settings.
- **FR-011**: Entries without a weather snapshot (created before this feature, or where
  capture failed) MUST render without error anywhere weather could appear.
- **FR-012 (Governance gate)**: Because this feature introduces the app's first default
  network dependency and sends coarse location off-device, it MUST be reconciled with
  Constitution Principle VI (On-Device Privacy) before implementation — either by an explicit
  accepted-exception sign-off or by a constitution amendment. See *Privacy & Constitution Gate*.

### Key Entities *(include if feature involves data)*

- **Weather Snapshot**: A point-in-time record of outdoor conditions captured for a check-in.
  Attributes: condition (categorical), temperature, display icon, captured-at timestamp.
  Relationship: at most one per check-in entry; optional (an entry may have none). Immutable
  once written (it records the moment, not a live value).
- **Check-In Entry** (existing): The mood/journal record. Gains an optional association to a
  single Weather Snapshot. All existing behaviour is unchanged when no snapshot is present.

## Privacy & Constitution Gate *(mandatory for this feature)*

Constitution **Principle VI (On-Device Privacy, NON-NEGOTIABLE)** establishes "no account, no
server, and no cloud by default," with sensitive derived data (audio/mood/health/medication)
never leaving the device. This feature is the first to require an outbound network call, and
it sends the user's coarse location to a third-party (Apple) weather service.

**Reconciliation proposed (requires sign-off):**

- Only **coarse, reduced-accuracy location** is sent — never mood, health, medication,
  transcript, or audio data (FR-006).
- The provider is **first-party Apple** (Apple states WeatherKit location requests are not
  tied to user identity or used for advertising).
- Weather is **stored on-device only**; nothing about the entry is uploaded.
- This is a **read of public weather data**, not synchronisation of user data; it does not
  open an account or a cloud store.

**Decision (FR-012): RESOLVED.** The constitution was amended (v1.2.0 → **v1.3.0**) to add a
scoped exception to Principle VI permitting first-party (Apple WeatherKit), reduced-accuracy,
read-only weather lookups that transmit no user content and store on-device only. Auto-capture
on every check-in is therefore permitted. The exception is narrow by construction: any broader
network use, finer location precision, or transmission of user content remains prohibited and
would require a further amendment.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With location permission granted and connectivity available, at least 95% of
  check-ins acquire a weather snapshot.
- **SC-002**: Check-in completion time is indistinguishable (within normal variance) whether
  or not weather capture succeeds — i.e., capture adds no perceptible delay to confirming a
  check-in.
- **SC-003**: 100% of check-ins still succeed when location is denied or the device is offline.
- **SC-004**: For any entry with a weather snapshot, a user can view its condition,
  temperature, and icon (with attribution) from the entry detail.
- **SC-005**: A mood-vs-weather correlation appears in Insights once the data threshold is met
  and stays hidden below it.
- **SC-006**: No audio, transcript, mood, emotion, health, or medication data is transmitted
  off-device during weather capture (verifiable by network inspection).

## Assumptions

- **Provider**: A first-party on-device-OS weather capability (Apple WeatherKit) is used; its
  service-side terms (attribution, capability registration) are accepted as deployment
  prerequisites.
- **Capture model**: Automatic capture on every check-in (per approved product decision),
  pending the Principle VI sign-off in FR-012.
- **Snapshot fields**: condition + temperature + icon + capture time only (no humidity/wind/UV
  in this version).
- **Correlation threshold**: a small minimum (e.g., ~5 weathered entries spanning ≥2 distinct
  conditions) gates the Insights summary; exact value tunable during planning.
- **Platform**: iOS 26 floor (well above the weather capability's minimum); the weather
  capability must be registered on the app identity before on-device data will return.
- **Storage posture**: the weather snapshot is an optional, defaulted attribute on the existing
  entry record, preserving the CloudKit-compatible schema rule (Principle IX).
