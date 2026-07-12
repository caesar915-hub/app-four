import SwiftUI

struct PlaybackWaveformBars: View {
    let seed: String
    let progress: Double
    var barCount: Int = 32
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 3 // intrinsic waveform bar gap
            let totalSpacing = CGFloat(barCount - 1) * spacing
            let barWidth = max(2, (geometry.size.width - totalSpacing) / CGFloat(barCount))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(isPlayed(index: index) ? Theme.accent.opacity(0.6) : NewLook.tintNeutral)
                        .frame(width: barWidth, height: barHeight(for: index))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let fraction = min(1, max(0, value.location.x / geometry.size.width))
                        onSeek(fraction)
                    }
            )
        }
        .frame(height: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback progress, \(Int(min(1, max(0, progress)) * 100)) percent")
    }

    private func isPlayed(index: Int) -> Bool {
        let threshold = Double(barCount) * min(1, max(0, progress))
        return Double(index) < threshold
    }

    private func barHeight(for index: Int) -> CGFloat {
        var hasher = Hasher()
        hasher.combine(seed)
        hasher.combine(index)
        let hash = abs(hasher.finalize())
        let normalized = Double(hash % 1000) / 1000.0
        return CGFloat(4 + normalized * 20)
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        PlaybackWaveformBars(seed: "preview-1", progress: 0.35, onSeek: { _ in })
            .frame(width: 200)

        PlaybackWaveformBars(seed: "preview-2", progress: 0.72, onSeek: { _ in })
            .frame(width: 200)

        PlaybackWaveformBars(seed: "preview-3", progress: 0.0, onSeek: { _ in })
            .frame(width: 200)
    }
    .padding()
}
