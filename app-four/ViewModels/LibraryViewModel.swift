import Foundation
import Observation

@Observable
@MainActor
final class LibraryViewModel {

    struct WeekGroup: Identifiable {
        let id: Date
        let label: String
        let recordings: [Recording]
    }

    @ObservationIgnored private let store: RecordingStore
    @ObservationIgnored private let calendar = Calendar.current
    @ObservationIgnored private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    var searchText: String = ""
    var selectedTopicFilter: TopicCategory?

    var recordings: [Recording] {
        store.recordings
    }

    var filteredRecordings: [Recording] {
        var result = recordings

        if let filter = selectedTopicFilter {
            result = result.filter { $0.topicCategories.contains(filter) }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var weekGroups: [WeekGroup] {
        let grouped = Dictionary(grouping: filteredRecordings) { recording -> Date in
            calendar.dateInterval(of: .weekOfYear, for: recording.createdAt)?.start ?? recording.createdAt
        }
        return grouped.keys
            .sorted(by: >)
            .map { weekStart in
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
                let label = weekLabel(start: weekStart, end: weekEnd)
                let recordings = grouped[weekStart]!.sorted { $0.createdAt > $1.createdAt }
                return WeekGroup(id: weekStart, label: label, recordings: recordings)
            }
    }

    init(store: RecordingStore) {
        self.store = store
    }

    func deleteRecording(_ recording: Recording) {
        store.deleteRecording(recording)
    }

    func deleteAtOffsets(_ offsets: IndexSet) {
        let recordingsToDelete = offsets.map { filteredRecordings[$0] }
        for recording in recordingsToDelete {
            store.deleteRecording(recording)
        }
    }

    func deleteSelected(ids: Set<UUID>) {
        let toDelete = recordings.filter { ids.contains($0.id) }
        for recording in toDelete {
            store.deleteRecording(recording)
        }
    }

    // MARK: - Private

    private func weekLabel(start: Date, end: Date) -> String {
        let today = Date()
        if calendar.isDate(today, equalTo: start, toGranularity: .weekOfYear) {
            return "This Week"
        }
        if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: today),
           calendar.isDate(lastWeek, equalTo: start, toGranularity: .weekOfYear) {
            return "Last Week"
        }
        let startStr = dayFormatter.string(from: start)
        let endStr = dayFormatter.string(from: end)
        return "\(startStr) – \(endStr)"
    }
}
