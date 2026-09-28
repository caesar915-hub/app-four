import SwiftUI

/// Decorative waveform (D24: seeded, not real amplitudes): bars 2.5 pt wide on a 4.6 pt pitch,
/// the count derived from the width, heights quantised to the pen's five levels; played bars
/// violet-500, unplayed violet-100 (the pen's `#eaf4eb` is 1.1:1 against the card). Tap or drag
/// to seek.
struct PlaybackWaveformBars: View {
    let seed: String
    let progress: Double
    let onSeek: (Double) -> Void

    private static let barWidth: CGFloat = 2.5
    private static let pitch: CGFloat = 4.6
    private static let maxHeight: CGFloat = 24.75
    private static let levels: [CGFloat] = [0.23, 0.40, 0.53, 0.74, 1.0]

    var body: some View {
        GeometryReader { geometry in
            let count = max(8, Int(geometry.size.width / Self.pitch))
            HStack(alignment: .center, spacing: Self.pitch - Self.barWidth) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(isPlayed(index: index, of: count) ? Accent.violet : Palette.violet100)
                        .frame(width: Self.barWidth, height: barHeight(for: index))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let fraction = min(1, max(0, value.location.x / geometry.size.width))
                        onSeek(fraction)
                    }
            )
        }
        .frame(height: Self.maxHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback progress, \(Int(min(1, max(0, progress)) * 100)) percent")
        .accessibilityAdjustableAction { direction in
            let step = 0.05
            switch direction {
            case .increment: onSeek(min(1, progress + step))
            case .decrement: onSeek(max(0, progress - step))
            @unknown default: break
            }
        }
    }

    private func isPlayed(index: Int, of count: Int) -> Bool {
        Double(index) < Double(count) * min(1, max(0, progress))
    }

    private func barHeight(for index: Int) -> CGFloat {
        var hasher = Hasher()
        hasher.combine(seed)
        hasher.combine(index)
        let level = abs(hasher.finalize()) % Self.levels.count
        return Self.maxHeight * Self.levels[level]
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        PlaybackWaveformBars(seed: "preview-1", progress: 0.35, onSeek: { _ in })
        PlaybackWaveformBars(seed: "preview-2", progress: 0.72, onSeek: { _ in })
        PlaybackWaveformBars(seed: "preview-3", progress: 0.0, onSeek: { _ in })
    }
    .padding()
}
