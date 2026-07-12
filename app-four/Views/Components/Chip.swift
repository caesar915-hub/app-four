import SwiftUI

/// A unified chip component that replaces both `TopicChip` and `FilterChip`.
///
/// Use `.topic(_:)` for read-only category badges.
/// Use `.filter(_:isSelected:)` for tappable filter controls.
struct Chip: View {
    enum Style {
        case topic(TopicCategory)
        case filter(title: String, isSelected: Bool)
    }

    let style: Style
    var action: (() -> Void)?

    // MARK: - Convenience initialisers

    static func topic(_ category: TopicCategory) -> Chip {
        Chip(style: .topic(category))
    }

    static func filter(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> Chip {
        Chip(style: .filter(title: title, isSelected: isSelected), action: action)
    }

    // MARK: - Body

    var body: some View {
        switch style {
        case .topic(let category):
            topicChip(category: category)
        case .filter(let title, let isSelected):
            filterChip(title: title, isSelected: isSelected)
        }
    }

    // MARK: - Variants

    private func topicChip(category: TopicCategory) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: category.icon)
            Text(category.displayName)
        }
        .font(Typography.caption)
        .fontWeight(.medium)
        .foregroundStyle(category.color)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs + 2)
        .background(category.color.opacity(0.15), in: .rect(cornerRadius: Radius.control))
        .accessibilityLabel(category.displayName)
    }

    private func filterChip(title: String, isSelected: Bool) -> some View {
        Button(action: { action?() }) {
            Text(title)
                .font(Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? NewLook.selection : NewLook.inkSecondary)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.xs + 2)
                .background(
                    isSelected ? NewLook.selection.opacity(0.15) : NewLook.card,
                    in: .rect(cornerRadius: Radius.control)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by \(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: Spacing.l) {
        Text("Topic chips").font(Typography.subheadline)
        HStack(spacing: Spacing.s) {
            Chip.topic(.medications)
            Chip.topic(.symptoms)
            Chip.topic(.appointments)
        }

        Text("Filter chips").font(Typography.subheadline)
        HStack(spacing: Spacing.s) {
            Chip.filter("All", isSelected: true) {}
            Chip.filter("Medications", isSelected: false) {}
            Chip.filter("Symptoms", isSelected: false) {}
        }
    }
    .padding(Spacing.l)
}
