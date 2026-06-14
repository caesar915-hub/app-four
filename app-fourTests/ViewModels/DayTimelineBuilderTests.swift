import Foundation
import Testing
import SwiftData
@testable import app_four

@MainActor
struct DayTimelineBuilderTests {
    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Recording.self, MedicationEvent.self, AppSettings.self,
            configurations: config
        )
        context = container.mainContext
    }

    private func time(_ hour: Int, _ minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 9
        comps.hour = hour; comps.minute = minute
        return Calendar.current.date(from: comps)!
    }

    private func makeRecording(at date: Date, mood: String?) -> Recording {
        let r = Recording(audioFileName: "r.m4a", duration: 0, title: "Note", mood: mood)
        r.createdAt = date
        context.insert(r)
        return r
    }

    private func makeDose(at date: Date, durationHours: Double = 10) -> MedicationEvent {
        let e = MedicationEvent(name: "Concerta", dose: "27mg", takenAt: date,
                                taken: true, durationHours: durationHours, source: .manual)
        context.insert(e)
        return e
    }

    @Test func liveCheckInMergesRecordingAndDoseIntoOneNode() {
        let t = time(10, 45)
        let r = makeRecording(at: t, mood: "good")
        let dose = makeDose(at: t)

        let nodes = DayTimelineBuilder.build(recordings: [r], doses: [dose])

        #expect(nodes.count == 1)
        #expect(nodes[0].recording?.id == r.id)
        #expect(nodes[0].intakeDoses.map(\.id) == [dose.id])
        #expect(nodes[0].rings.count == 1)
        #expect(nodes[0].rings[0].progress < 0.01)
    }

    @Test func backDatedDoseIsASeparateNodeAndOverlaysTheRecording() {
        let dose = makeDose(at: time(10, 45))
        let r = makeRecording(at: time(14, 0), mood: "good")

        let nodes = DayTimelineBuilder.build(recordings: [r], doses: [dose])

        #expect(nodes.count == 2)
        let recordingNode = nodes[0]
        let doseNode = nodes[1]
        #expect(recordingNode.recording?.id == r.id)
        #expect(recordingNode.intakeDoses.isEmpty)
        #expect(recordingNode.rings.count == 1)
        #expect(abs(recordingNode.rings[0].progress - 0.325) < 0.01)
        #expect(doseNode.recording == nil)
        #expect(doseNode.intakeDoses.map(\.id) == [dose.id])
        #expect(doseNode.rings[0].progress < 0.01)
    }

    @Test func ringsAreOrderedOldestOutermost() {
        let d1 = makeDose(at: time(10, 45))
        let d2 = makeDose(at: time(16, 0))
        let r = makeRecording(at: time(18, 0), mood: "great")

        let nodes = DayTimelineBuilder.build(recordings: [r], doses: [d1, d2])
        let node = nodes.first { $0.recording?.id == r.id }!

        #expect(node.rings.count == 2)
        #expect(node.rings[0].doseID == d1.id)
        #expect(node.rings[1].doseID == d2.id)
        #expect(node.rings[0].progress > node.rings[1].progress)
    }

    @Test func moodOnlyNodeStillShowsActiveDoseRings() {
        let dose = makeDose(at: time(10, 45))
        let r = makeRecording(at: time(14, 0), mood: "okay")

        let nodes = DayTimelineBuilder.build(recordings: [r], doses: [dose])
        let moodNode = nodes.first { $0.recording?.id == r.id }!

        #expect(moodNode.intakeDoses.isEmpty)
        #expect(moodNode.rings.count == 1)
        #expect(abs(moodNode.rings[0].progress - 0.325) < 0.01)
    }

    @Test func expiredDoseDropsOffLaterNodes() {
        let dose = makeDose(at: time(6, 0), durationHours: 4)
        let r = makeRecording(at: time(14, 0), mood: "flat")

        let nodes = DayTimelineBuilder.build(recordings: [r], doses: [dose])
        let moodNode = nodes.first { $0.recording?.id == r.id }!

        #expect(moodNode.rings.isEmpty)
    }

    @Test func ringsCapAtThreeMostRecentActiveDoses() {
        let doses = [time(9, 0), time(10, 0), time(11, 0), time(12, 0)].map { makeDose(at: $0) }
        let r = makeRecording(at: time(13, 0), mood: "good")

        let nodes = DayTimelineBuilder.build(recordings: [r], doses: doses)
        let node = nodes.first { $0.recording?.id == r.id }!

        #expect(node.rings.count == 3)
        #expect(node.rings[0].doseID == doses[1].id)
        #expect(node.rings[2].doseID == doses[3].id)
    }

    @Test func manualDoseOnlyProducesAHollowNode() {
        let dose = makeDose(at: time(8, 0))

        let nodes = DayTimelineBuilder.build(recordings: [], doses: [dose])

        #expect(nodes.count == 1)
        #expect(nodes[0].recording == nil)
        #expect(nodes[0].intakeDoses.map(\.id) == [dose.id])
    }

    @Test func nodesAreSortedNewestFirst() {
        let r1 = makeRecording(at: time(9, 0), mood: "good")
        let r2 = makeRecording(at: time(18, 0), mood: "low")

        let nodes = DayTimelineBuilder.build(recordings: [r1, r2], doses: [])

        #expect(nodes.map(\.recording?.id) == [r2.id, r1.id])
    }
}
