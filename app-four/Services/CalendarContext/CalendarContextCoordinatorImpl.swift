import Foundation

// MARK: - CalendarCaptureSettings

struct CalendarCaptureSettings: Sendable {
    var titlesIncluded: Bool
    var excludedIDs: Set<String>
    var includedOverrideIDs: Set<String>
}

// MARK: - CalendarContextCoordinatorImpl

/// Orchestrates EventKit capture in response to check-in lifecycle events (save / date-change /
/// delete / sweep / recapture-all). All public methods are no-ops while debugMockMode is on or
/// calendar access is not `.fullAccess`; the gate lives in `capture(_:)` and is re-checked
/// after every `await` where state could have changed.
///
/// Sweep coalescing: the single `isSweeping` flag mirrors the `PendingTranscriptionServiceImpl`
/// `isDraining` pattern — a re-entrant call marks `needsAnotherPass` and returns immediately;
/// the running sweep re-runs once after completing its loop.
actor CalendarContextCoordinatorImpl: CalendarContextCoordinator {
    private let service: any CalendarContextService
    private let store: DayContextStore
    private let settingsProvider: @Sendable () -> CalendarCaptureSettings
    private let checkInDaysProvider: @Sendable () async -> Set<Date>
    private let isMockMode: @Sendable () -> Bool

    // MARK: Sweep coalescing state
    private var isSweeping = false
    private var needsAnotherPass = false

    init(
        service: any CalendarContextService,
        store: DayContextStore,
        settingsProvider: @Sendable @escaping () -> CalendarCaptureSettings,
        checkInDaysProvider: @Sendable @escaping () async -> Set<Date>,
        isMockMode: @Sendable @escaping () -> Bool
    ) {
        self.service = service
        self.store = store
        self.settingsProvider = settingsProvider
        self.checkInDaysProvider = checkInDaysProvider
        self.isMockMode = isMockMode
    }

    // MARK: - Protocol

    func checkInSaved(dayKey: Date) async {
        await capture(DayKey.make(for: dayKey))
    }

    func checkInDateChanged(from oldDay: Date, to newDay: Date) async {
        let old = DayKey.make(for: oldDay)

        // Capture context for the day the check-in has moved to (always replace).
        await capture(newDay)

        // Vacated-day cleanup is a local row delete — no calendar read, so it must
        // NOT gate on calendar access (FR-014 is unconditional). Re-derive membership
        // now: another check-in may still occupy oldDay.
        guard !isMockMode() else { return }
        if !(await normalizedCheckInDays()).contains(old) {
            await store.deleteContext(for: old)
        }
    }

    /// FR-014: deleting a day's last check-in MUST delete that day's context —
    /// unconditionally (a local SwiftData delete, no EventKit). Re-derives membership
    /// at execution time instead of trusting a caller-passed snapshot: a fresh
    /// check-in may have been added to the day since the delete that scheduled this.
    func checkInDeleted(dayKey: Date) async {
        guard !isMockMode() else { return }
        let key = DayKey.make(for: dayKey)
        if !(await normalizedCheckInDays()).contains(key) {
            await store.deleteContext(for: key)
        }
    }

    func sweep() async {
        guard !isMockMode(), await service.accessState() == .fullAccess else { return }

        // Coalesce: if already sweeping, request another pass and return immediately.
        guard !isSweeping else {
            needsAnotherPass = true
            return
        }

        isSweeping = true
        defer { isSweeping = false }

        repeat {
            needsAnotherPass = false

            let checkInDays = await normalizedCheckInDays()
            // Re-check gate after async hop — access could have changed.
            guard !isMockMode(), await service.accessState() == .fullAccess else { return }

            // Orphan reconciliation (FR-014, self-healing): drop any context whose day
            // no longer has a check-in. This durably repairs the residual capture-vs-delete
            // race — a resurrected orphan is cleaned on the next foreground sweep — and any
            // delete missed while access was unavailable.
            let orphans = await store.contextDays().subtracting(checkInDays)
            for day in orphans {
                await store.deleteContext(for: day)
            }

            let missing = await store.daysLackingContext(checkInDays: checkInDays)

            // Sequential: EKEventStore is actor-serialized anyway; parallel calls would
            // only contend on the single store and provide no throughput benefit.
            for day in missing {
                await capture(day)
            }
        } while needsAnotherPass
    }

    func recaptureAll() async {
        guard !isMockMode(), await service.accessState() == .fullAccess else { return }
        let days = await normalizedCheckInDays()
        // Re-check gate after async hop.
        guard !isMockMode(), await service.accessState() == .fullAccess else { return }
        for day in days {
            await capture(day)
        }
    }

    /// Check-in day set, normalized to startOfDay so membership tests match stored keys.
    private func normalizedCheckInDays() async -> Set<Date> {
        Set(await checkInDaysProvider().map { DayKey.make(for: $0) })
    }

    // MARK: - Private

    /// Captures calendar events for `dayKey` and upserts into `DayContextStore`.
    /// Always replaces an existing row (latest-wins, FR-006). No-op while
    /// debugMockMode is on or access ≠ fullAccess.
    private func capture(_ dayKey: Date) async {
        guard !isMockMode(), await service.accessState() == .fullAccess else { return }

        let settings = settingsProvider()
        let calendars = await service.availableCalendars()
        let includedIDs = CalendarInclusion.includedCalendarIDs(
            from: calendars,
            excludedIDs: settings.excludedIDs,
            includedOverrideIDs: settings.includedOverrideIDs
        )

        guard let payload = await service.captureDay(
            dayKey,
            includeTitles: settings.titlesIncluded,
            includedCalendarIDs: includedIDs
        ) else { return }

        // Re-validate the day still has a check-in: a delete may have interleaved during
        // the EventKit fetch above (actor reentrancy). Without this, capture would
        // resurrect the context of a day whose check-in was just removed. Any residual
        // window (this check → upsert) is swept by the orphan reconciliation in sweep().
        guard (await normalizedCheckInDays()).contains(DayKey.make(for: dayKey)) else { return }

        await store.upsert(dayKey: dayKey, payload: payload, titlesIncluded: settings.titlesIncluded)
    }
}
