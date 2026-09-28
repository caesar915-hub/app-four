import SwiftUI
import SquirlDesignSystem

// MARK: - Mock data (hardcoded; no SwiftData/services)

struct MockEntry: Identifiable {
    let id = UUID()
    let time: String
    let mood: MoodLevel
    var energy: EnergyLevel? = nil
    var focus: FocusLevel? = nil
    let note: String
    var takenMed: String? = nil
    var ring: Double? = nil          // carry-over med effect progress 0…1
    var emotions: [String] = []
    var sleep: String? = nil
}

struct MockDay: Identifiable {
    let id = UUID()
    let label: String                // "Thursday 25"
    let mood: MoodLevel?             // representative
    var energy: EnergyLevel? = nil
    var focus: FocusLevel? = nil
    var med: String? = nil
    let entries: [MockEntry]
}

enum MockData {
    static let days: [MockDay] = [
        MockDay(label: "Thursday 25", mood: .okay, energy: .tired, focus: .present, med: "Concerta", entries: [
            MockEntry(time: "18:30", mood: .okay, energy: .tired, note: "Faded in the evening, ordered takeout"),
            MockEntry(time: "12:40", mood: .okay, energy: .steady, focus: .present, note: "Deep work block, then hit a wall", ring: 0.42),
            MockEntry(time: "09:12", mood: .good, energy: .alert, focus: .sharp, note: "Steady after the morning walk",
                      takenMed: "Concerta 36mg", emotions: ["Grateful", "Content"], sleep: "7h sleep"),
        ]),
        MockDay(label: "Wednesday 24", mood: .good, energy: .alert, focus: .sharp, med: "Concerta", entries: [
            MockEntry(time: "17:30", mood: .good, energy: .alert, focus: .sharp, note: "Still sharp into the afternoon", ring: 0.62),
            MockEntry(time: "10:00", mood: .great, energy: .charged, focus: .lockedIn, note: "Best morning in weeks — everything clicked",
                      takenMed: "Concerta 36mg", emotions: ["Excited", "Proud"]),
        ]),
        MockDay(label: "Tuesday 23", mood: .okay, energy: .steady, focus: .present, med: "Ritalin", entries: [
            MockEntry(time: "08:50", mood: .okay, energy: .steady, focus: .present, note: "Ordinary start, a bit foggy at first",
                      takenMed: "Ritalin 10mg", emotions: ["Peaceful"]),
        ]),
        MockDay(label: "Monday 22", mood: .flat, energy: .tired, focus: .distracted, entries: [
            MockEntry(time: "14:00", mood: .flat, energy: .tired, focus: .distracted, note: "Off day — low battery, couldn't get going",
                      emotions: ["Frustrated", "Anxious"]),
        ]),
        MockDay(label: "Friday 19", mood: .great, energy: .charged, focus: .lockedIn, med: "Concerta", entries: [
            MockEntry(time: "10:00", mood: .great, energy: .charged, focus: .lockedIn, note: "On fire today, plans actually happened",
                      takenMed: "Concerta 54mg", emotions: ["Joyful", "Inspired"], sleep: "8h sleep"),
        ]),
    ]
}

// MARK: - Calendar screen (re-composed from package atoms)

struct SandboxCalendar: View {
    @State private var expanded: Set<UUID> = [MockData.days.first!.id]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(MockData.days) { day in
                    DayCardMock(day: day, isOpen: expanded.contains(day.id)) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            if expanded.contains(day.id) { expanded.remove(day.id) } else { expanded.insert(day.id) }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Surface.screen.ignoresSafeArea())
    }
}

private struct DayCardMock: View {
    let day: MockDay
    let isOpen: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) { header }.buttonStyle(.plain)
            if isOpen {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(day.entries.enumerated()), id: \.element.id) { idx, e in
                        TimelineRowMock(entry: e, isLast: idx == day.entries.count - 1)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(day.mood?.avatarTint ?? Surface.track)
                    if let m = day.mood { SignalGlyph(.mood, level: m.numericValue, size: 24, decorative: true) }
                }.frame(width: 42, height: 42)
                titleText.font(Typography.cardTitle).frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                    .foregroundStyle(Ink.tertiary).rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(.horizontal, 16)
            if !isOpen {
                Rectangle().fill(Stroke.separator).frame(height: 1)
                summaryLine.padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .background(day.mood?.dayCardFill ?? .clear)
        .contentShape(Rectangle())
    }

    private var titleText: Text {
        let weekday = Text(day.label).foregroundColor(.primary)
        guard let m = day.mood else { return weekday }
        return Text(m.displayLabel).foregroundColor(m.wordColor).bold()
            + Text(" · ").foregroundColor(Ink.tertiary) + weekday
    }

    @ViewBuilder private var summaryLine: some View {
        HStack(spacing: 14) {
            if let e = day.energy { seg { SignalGlyph(.energy, level: e.numericValue, size: 15, decorative: true); Text(e.displayLabel) } }
            if let f = day.focus { seg { SignalGlyph(.focus, level: f.numericValue, size: 15, decorative: true); Text(f.displayLabel) } }
            if let med = day.med { seg { SignalGlyph(.medication, size: 15, decorative: true); Text(med).foregroundStyle(Accent.violet) } }
            Spacer(minLength: 0)
        }
        .font(Typography.captionQuiet)
    }

    @ViewBuilder private func seg<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 4) { content() }
    }
}

private struct TimelineRowMock: View {
    let entry: MockEntry
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(entry.mood.avatarTint).frame(width: 42, height: 42)
                    SignalGlyph(.mood, level: entry.mood.numericValue, size: 25, decorative: true)
                    if let r = entry.ring {
                        Circle().trim(from: 0, to: max(0.001, r))
                            .stroke(Accent.violet, style: StrokeStyle(lineWidth: 3.3, lineCap: .round))
                            .rotationEffect(.degrees(-90)).frame(width: 38, height: 38)
                    }
                }
                if !isLast { Rectangle().fill(Stroke.separator).frame(width: 1).frame(maxHeight: .infinity) }
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.mood.displayLabel).font(Typography.cardTitle).foregroundStyle(entry.mood.wordColor)
                    Text(entry.time).font(Typography.mono12).foregroundStyle(Ink.tertiary)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Ink.tertiary)
                }
                if entry.energy != nil || entry.focus != nil {
                    HStack(spacing: 12) {
                        if let e = entry.energy { sg { SignalGlyph(.energy, level: e.numericValue, size: 13, decorative: true); Text(e.displayLabel) } }
                        if let f = entry.focus { sg { SignalGlyph(.focus, level: f.numericValue, size: 13, decorative: true); Text(f.displayLabel) } }
                    }.font(Typography.captionQuiet)
                }
                Text(entry.note).font(Typography.cardSubtitle).foregroundStyle(Ink.primary)
                chips
            }
            .padding(.top, 16)
            .padding(.bottom, isLast ? 0 : 24)
        }
    }

    @ViewBuilder private var chips: some View {
        let items = chipItems
        if !items.isEmpty {
            FlowMock(spacing: 8) {
                ForEach(items, id: \.label) { item in
                    HStack(spacing: 4) {
                        if item.med { SignalGlyph(.medication, size: 16, decorative: true) }
                        Text(item.label)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(item.med ? Accent.violet : Ink.primary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(item.med ? Accent.violet.opacity(0.13) : Color(.secondarySystemFill), in: .capsule)
                }
            }
        }
    }

    private struct Chip { let label: String; let med: Bool }
    private var chipItems: [Chip] {
        var out: [Chip] = []
        if let m = entry.takenMed { out.append(.init(label: "Taken \(m)", med: true)) }
        entry.emotions.forEach { out.append(.init(label: $0, med: false)) }
        if let s = entry.sleep { out.append(.init(label: s, med: false)) }
        return out
    }

    @ViewBuilder private func sg<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 4) { content() }
    }
}

/// Minimal wrapping HStack for chips (avoids depending on the app's FlowLayout).
private struct FlowMock: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: maxW == .infinity ? x : maxW, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}
