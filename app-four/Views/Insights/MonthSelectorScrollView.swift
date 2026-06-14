import SwiftUI

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
            HStack(spacing: Spacing.xxl) {
                ForEach(availableMonths.indices, id: \.self) { index in
                    let month = availableMonths[index]
                    let isSelected = Calendar.current.isDate(month, equalTo: currentMonth, toGranularity: .month)

                    Button(action: { currentMonth = month }) {
                        Text(monthFormatter.string(from: month).uppercased())
                            .font(Typography.body.weight(isSelected ? .bold : .semibold))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                            .padding(.vertical, Spacing.s)
                            .padding(.horizontal, Spacing.xs)
                            .overlay(alignment: .bottom) {
                                if isSelected {
                                    Rectangle()
                                        .fill(Color.primary)
                                        .frame(height: 2)
                                        .clipShape(.rect(cornerRadius: 1))
                                }
                            }
                            .animation(Motion.snappy, value: currentMonth)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.xl)
        }
    }
}
