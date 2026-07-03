<!-- Created: 2026-07-03 13:58 (WEST) · Updated: 2026-07-03 13:58 (WEST) -->
# Calendar Integration — "The Day, Remembered" (design)

**Status:** Design approved in brainstorm (2026-07-02/03). Post-v1.0 flagship (v1.1+). Not milestone-dated.
**Source of decisions:** brainstorm session against the Master PRD (`project-team/by-me/MASTER-PRD-manual-check.md`); owner picked direction, values, write scope, roadmap slot, and approach.

## Why

ADHD users live against a calendar they struggle to feel (time blindness) and remember (weak episodic memory). Squirl already captures the *inner* day (mood/energy/focus/sleep/meds); the device calendar holds the *outer* day (meetings, appointments, social load). Joining them — entirely on-device — makes check-ins interpretable months later, explains signal patterns, and maps stimulant coverage onto real demands.

**Privacy fit:** EventKit is fully on-device. iOS itself syncs Google/Exchange/iCloud calendars into the local event store; Squirl reading it never touches a network. Constitution Principle VI (on-device privacy, non-negotiable) holds untouched. Same integration category as the HealthKit prototype.

## Decisions (owner-approved)

| Question | Decision |
|---|---|
| Direction | **Both**: read events for context + write Squirl artifacts back |
| Core values | All four: pattern correlation (Insights) · memory prosthesis (day context) · med-timing vs schedule · capture context & prompting |
| Write scope | **Check-in markers only** — into a dedicated Squirl-created `EKCalendar`, never the user's default (no clutter, no shared-calendar leak, one-delete removable) |
| Roadmap | **v1.x flagship, post-launch** — spec deep now, build after v1.0 ships; zero risk to the 6 Jul submission |
| Approach | **A — Context-first**: day context → correlations → med overlay → markers. Least regret; foundation first; each phase independently shippable |
| Snapshot vs live-query | **Snapshot at check-in** for day context (survives calendar churn — job change removes the work calendar from EventKit, the journal keeps "the day as lived"). **Live-query** for correlations (nothing extra stored). |

## The arc — 4 phases, each independently shippable

### Phase 1 — Foundation + day context (memory prosthesis)
- `CalendarContextService` actor wrapping `EKEventStore`; protocol-fronted (like `TranscriptionService`), composed in `AppDependencies`.
- iOS 17+ full-access flow (`requestFullAccessToEvents`); pre-permission explainer screen before the iOS prompt; `NSCalendarsFullAccessUsageDescription` string.
- Settings "Calendar" group: permission state, **included-calendars picker** (declined events and holiday/birthday calendars excluded by default), title-capture toggle.
- On check-in save, snapshot that day's events (title, start/end, all-day flag) from included calendars — denormalized JSON on `Recording`, following the existing `sleepEventJSON`/`emotionsJSON` pattern (exact home per-day vs per-recording decided in the implementation plan).
- Day cards (calendar tab) render the day's context line ("3 meetings · dentist · Mum's birthday"); detail view shows the list.

### Phase 2 — Insights correlations ("why was I wrecked on Thursday?")
- Calendar-derived day features: meeting count/density, back-to-back blocks, earliest start, busy hours, evening events.
- Correlated with mood/energy/focus in the existing Insights `connections` section; computed live at render from EventKit history + check-in history (works day-one — both histories already exist on-device).
- **ADHD-safe rules (hard requirements):** observations, never judgments ("energy tends lower after 5-meeting days", never "you do worse when busy"); minimum sample size + effect-size floor before anything is shown; findings stable, not daily-churning; framed as patterns to be curious about, not verdicts. No shame surface.

### Phase 3 — Today overlay (med bar meets the day)
- Map `MedicationEvent` coverage windows onto today's events: "Elvanse coverage ends ~15:30 — before Presentation, 16:00."
- Purely descriptive; never a nag, no red, no alarms (per product posture §4.5). Surfaces on the day timeline and/or med bar.
- Optional gentle capture prompting: a quiet "free 10 min before your next thing" affordance — no notifications v1, no streak/guilt mechanics ever.

### Phase 4 — Check-in markers (write-out, opt-in)
- Off by default. Squirl creates its own `EKCalendar`; one small event per check-in.
- Deleting the calendar (in any calendar app) removes every marker; toggle off stops writing.

## Error & edge handling
- Permission denied/limited → feature degrades silently; calm empty states, no re-prompting nags.
- Calendar account removed → Phase-1 snapshots preserve past day context; correlations recompute over what remains.
- Exclude declined events; handle all-day and multi-day events explicitly.
- Snapshots ride the encrypted export — document that calendar titles are included (title-capture toggle is the opt-out).

## Testing
- Actor-based `MockCalendarContextService` (extends the existing 7-mock pattern), Swift Testing.
- Correlation math unit-tested against synthetic fixtures (known effect sizes, below-floor samples must render nothing).
- Snapshot round-trip + calendar-removed scenarios; permission-state matrix.

## Non-goals
- No cloud calendar APIs (Google/Outlook direct) — EventKit only; the OS is the sync layer.
- No writing meds/doses or "recovery blocks" to the calendar (considered, dropped — revisit only on real demand).
- No notifications/reminders in v1 of this feature.
- No natural-language event parsing from check-in speech ("meeting with Sam went badly" → event linking) — future idea, out of scope.

## Open questions (for the implementation plan)
1. Snapshot home: per-`Recording` JSON (simple, duplicates on multi-check-in days) vs a day-keyed model (deduped; pairs with the HealthKit plan's `DailySignals` day-keyed precedent).
2. Whether Phase-2 features feed the existing `connections` cards or a new dedicated section.
3. Premium gating: PRD ties HealthKit to the subscription tier — decide if calendar integration lands the same side of the paywall.
