import SwiftUI

/// Month chips (a07, spec 036): the New Look chip grammar — selected = solid selection
/// fill + light label, unselected = white + hairline + ink.
struct MonthSelectorScrollView: View {
    @Binding var currentMonth: Date
    let availableMonths: [Date]

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(availableMonths.indices, id: \.self) { index in
                    let month = availableMonths[index]
                    let isSelected = Calendar.current.isDate(month, equalTo: currentMonth, toGranularity: .month)

                    Button(action: { currentMonth = month }) {
                        Text(monthFormatter.string(from: month).uppercased())
                            .tracking(1.3)
                            .newLookChip(selected: isSelected)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
    }
}
