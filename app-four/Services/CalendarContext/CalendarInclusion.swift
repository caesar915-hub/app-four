/// Pure inclusion predicate — called from the coordinator actor; must not inherit
/// the module's default `@MainActor` isolation.
nonisolated enum CalendarInclusion {
    static func defaultExcludedClass(_ descriptor: CalendarDescriptor) -> Bool {
        descriptor.isBirthdayClass || descriptor.isSubscribedClass
    }

    static func isIncluded(
        _ descriptor: CalendarDescriptor,
        excludedIDs: Set<String>,
        includedOverrideIDs: Set<String>
    ) -> Bool {
        !excludedIDs.contains(descriptor.id)
            && (includedOverrideIDs.contains(descriptor.id) || !defaultExcludedClass(descriptor))
    }

    static func includedCalendarIDs(
        from descriptors: [CalendarDescriptor],
        excludedIDs: Set<String>,
        includedOverrideIDs: Set<String>
    ) -> [String] {
        descriptors
            .filter { isIncluded($0, excludedIDs: excludedIDs, includedOverrideIDs: includedOverrideIDs) }
            .map(\.id)
    }
}
