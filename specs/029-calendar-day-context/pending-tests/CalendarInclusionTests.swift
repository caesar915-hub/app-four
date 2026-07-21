import Testing
@testable import app_four

struct CalendarInclusionTests {

    // MARK: - defaultExcludedClass

    @Test func birthdayClassExcludedByDefault() {
        let d = CalendarDescriptor(id: "b1", title: "Birthdays", isBirthdayClass: true, isSubscribedClass: false)
        #expect(CalendarInclusion.defaultExcludedClass(d) == true)
    }

    @Test func subscribedClassExcludedByDefault() {
        let d = CalendarDescriptor(id: "s1", title: "Holidays", isBirthdayClass: false, isSubscribedClass: true)
        #expect(CalendarInclusion.defaultExcludedClass(d) == true)
    }

    @Test func plainCalendarIncludedByDefault() {
        let d = CalendarDescriptor(id: "p1", title: "Work", isBirthdayClass: false, isSubscribedClass: false)
        #expect(CalendarInclusion.defaultExcludedClass(d) == false)
    }

    // MARK: - isIncluded: excludedIDs removes an otherwise-included calendar

    @Test func excludedIDRemovesIncludedCalendar() {
        let d = CalendarDescriptor(id: "p1", title: "Work", isBirthdayClass: false, isSubscribedClass: false)
        #expect(CalendarInclusion.isIncluded(d, excludedIDs: ["p1"], includedOverrideIDs: []) == false)
    }

    // MARK: - isIncluded: includedOverrideIDs re-includes a default-excluded calendar

    @Test func overrideReIncludesBirthdayCalendar() {
        let d = CalendarDescriptor(id: "b1", title: "Birthdays", isBirthdayClass: true, isSubscribedClass: false)
        #expect(CalendarInclusion.isIncluded(d, excludedIDs: [], includedOverrideIDs: ["b1"]) == true)
    }

    @Test func overrideReIncludesSubscribedCalendar() {
        let d = CalendarDescriptor(id: "s1", title: "Holidays", isBirthdayClass: false, isSubscribedClass: true)
        #expect(CalendarInclusion.isIncluded(d, excludedIDs: [], includedOverrideIDs: ["s1"]) == true)
    }

    // MARK: - excludedIDs takes priority over includedOverrideIDs

    @Test func excludedWinsOverOverride() {
        let d = CalendarDescriptor(id: "b1", title: "Birthdays", isBirthdayClass: true, isSubscribedClass: false)
        // id is in both sets — excluded wins per formula
        #expect(CalendarInclusion.isIncluded(d, excludedIDs: ["b1"], includedOverrideIDs: ["b1"]) == false)
    }

    // MARK: - newly-appearing calendar follows class default

    @Test func newlyAppearingPlainCalendarFollowsClassDefault() {
        let d = CalendarDescriptor(id: "new1", title: "Personal", isBirthdayClass: false, isSubscribedClass: false)
        #expect(CalendarInclusion.isIncluded(d, excludedIDs: [], includedOverrideIDs: []) == true)
    }

    @Test func newlyAppearingBirthdayCalendarFollowsClassDefault() {
        let d = CalendarDescriptor(id: "new2", title: "Birthdays", isBirthdayClass: true, isSubscribedClass: false)
        #expect(CalendarInclusion.isIncluded(d, excludedIDs: [], includedOverrideIDs: []) == false)
    }

    // MARK: - includedCalendarIDs

    @Test func includedCalendarIDsReturnsCorrectOrderedIDs() {
        let descriptors: [CalendarDescriptor] = [
            CalendarDescriptor(id: "p1", title: "Work", isBirthdayClass: false, isSubscribedClass: false),
            CalendarDescriptor(id: "b1", title: "Birthdays", isBirthdayClass: true, isSubscribedClass: false),
            CalendarDescriptor(id: "p2", title: "Personal", isBirthdayClass: false, isSubscribedClass: false),
            CalendarDescriptor(id: "s1", title: "Holidays", isBirthdayClass: false, isSubscribedClass: true),
            CalendarDescriptor(id: "b2", title: "Family BD", isBirthdayClass: true, isSubscribedClass: false),
        ]
        // Override b1, exclude p2
        let result = CalendarInclusion.includedCalendarIDs(
            from: descriptors,
            excludedIDs: ["p2"],
            includedOverrideIDs: ["b1"]
        )
        // Expected: p1 (plain, not excluded), b1 (override), p2 excluded, s1 default-excluded, b2 default-excluded
        #expect(result == ["p1", "b1"])
    }

    @Test func includedCalendarIDsPreservesInputOrder() {
        let descriptors: [CalendarDescriptor] = [
            CalendarDescriptor(id: "c", title: "C", isBirthdayClass: false, isSubscribedClass: false),
            CalendarDescriptor(id: "a", title: "A", isBirthdayClass: false, isSubscribedClass: false),
            CalendarDescriptor(id: "b", title: "B", isBirthdayClass: false, isSubscribedClass: false),
        ]
        let result = CalendarInclusion.includedCalendarIDs(from: descriptors, excludedIDs: [], includedOverrideIDs: [])
        #expect(result == ["c", "a", "b"])
    }
}
