import SwiftUI

struct SummaryCard: View {
    let state: RecordingDetailViewModel.SummaryState
    let onGenerate: () -> Void
    let onRegenerate: () -> Void

    var body: some View {
        switch state {
        case .idle:
            Button {
                Haptics.success()
                onGenerate()
            } label: {
                HStack(spacing: Spacing.s) {
                    Image(systemName: "sparkles")
                    Text("Generate Summary")
                }
            }
            .buttonStyle(.primary)
            .accessibilityLabel("Generate summary")

        case .loading:
            VStack(spacing: Spacing.m) {
                ProgressView()
                Text("Analyzing note…")
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .card()

        case .ready:
            HStack {
                Spacer()
                Button("Regenerate Summary", action: onRegenerate)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.accent)
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .card()

        case .error(let message):
            VStack(spacing: Spacing.m) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Text(message)
                    .font(Typography.body)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)

                Button("Retry", action: onGenerate)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .card()
        }
    }
}

#Preview {
    VStack(spacing: Spacing.l) {
        SummaryCard(state: .idle, onGenerate: {}, onRegenerate: {})
        SummaryCard(state: .loading, onGenerate: {}, onRegenerate: {})
        SummaryCard(state: .ready("**Medications**\n• Item"), onGenerate: {}, onRegenerate: {})
        SummaryCard(state: .error("Something went wrong"), onGenerate: {}, onRegenerate: {})
    }
    .padding(Spacing.l)
}
