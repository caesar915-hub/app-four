import SwiftUI

/// The pen's card grammar (DESIGN.md §8.6): white surface, a 0.5 pt hairline, a tinted shadow,
/// one of three radii — plus the mood-tinted collapsed day card and the expanded day card.
public enum CardStyle {
    /// r 24 — insights, settings groups, edit sections, the AI card.
    case large
    /// r 18 — connection cards, the listening prompt card, small settings groups.
    case medium
    /// r 12 — the medication bar, medication rows, the signal summary.
    case small
    /// r 12, tinted fill + stroke for the mood — collapsed previous-day cards.
    case day(MoodLevel?)
    /// r 24 with a mint header band drawn by the caller — the expanded day card.
    case expandedDay

    var radius: CGFloat {
        switch self {
        case .large, .expandedDay: Radius.cardL
        case .medium: Radius.cardM
        case .small, .day: Radius.cardS
        }
    }

    var fill: Color {
        if case .day(let level) = self, let level { return level.dayCardFill }
        return Surface.card
    }

    var stroke: Color {
        if case .day(let level) = self, let level { return level.dayCardStroke.opacity(0.5) }
        return Stroke.card
    }

    var shadow: ShadowSpec {
        switch self {
        case .large, .medium, .small, .day: Elevation.card
        case .expandedDay: Elevation.raised
        }
    }

    var defaultPadding: CGFloat {
        switch self {
        case .large, .medium: Spacing.cardInset
        case .small, .day: Spacing.rowInset
        case .expandedDay: 0
        }
    }
}

public extension View {
    /// Wraps the content in a pen card. Pass `padding: 0` for cards that draw their own bands.
    func card(_ style: CardStyle, padding: CGFloat? = nil) -> some View {
        self
            .padding(padding ?? style.defaultPadding)
            .background(style.fill, in: .rect(cornerRadius: style.radius))
            .overlay {
                RoundedRectangle(cornerRadius: style.radius)
                    .strokeBorder(style.stroke, lineWidth: Stroke.cardWidth)
            }
            .elevation(style.shadow)
    }

    /// Raised variant of a card's shadow (day-details and edit cards, the prompt card).
    func raisedCard(_ style: CardStyle, padding: CGFloat? = nil) -> some View {
        self
            .padding(padding ?? style.defaultPadding)
            .background(style.fill, in: .rect(cornerRadius: style.radius))
            .overlay {
                RoundedRectangle(cornerRadius: style.radius)
                    .strokeBorder(style.stroke, lineWidth: Stroke.cardWidth)
            }
            .elevation(Elevation.raised)
    }
}

#Preview("Cards") {
    ScrollView {
        VStack(spacing: Spacing.cardGap) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Large card").font(Typography.cardTitle).foregroundStyle(Ink.primary)
                Text("Radius 24, hairline, tinted shadow").font(Typography.cardSubtitle).foregroundStyle(Ink.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(.large)

            Text("Medium card").font(Typography.cardTitle).foregroundStyle(Ink.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(.medium)

            Text("Small card").font(Typography.rowLabel).foregroundStyle(Ink.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(.small)

            ForEach(MoodLevel.allCases, id: \.self) { level in
                Text(level.displayLabel).font(Typography.cardTitle).foregroundStyle(level.wordColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(.day(level))
            }
        }
        .padding(Spacing.gutter)
    }
    .background(Surface.screen)
}
