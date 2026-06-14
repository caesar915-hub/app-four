import SwiftUI

struct TopicChip: View {
    let category: TopicCategory

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: category.icon)
            Text(category.displayName)
        }
        .font(.caption)
        .fontWeight(.medium)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s) // was 6
        .background(category.color.opacity(0.15))
        .foregroundStyle(category.color)
        .clipShape(.rect(cornerRadius: 16))
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s) // was 6
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .clipShape(.rect(cornerRadius: 16))
        }
        .accessibilityLabel("Filter by \(title)")
    }
}

#Preview {
    HStack(spacing: Spacing.s) {
        TopicChip(category: .medications)
        TopicChip(category: .symptoms)
        FilterChip(title: "All", isSelected: true) {}
        FilterChip(title: "General", isSelected: false) {}
    }
    .padding()
}
