import SwiftUI

/// A small floating button shown on all screens in Debug and TestFlight builds
/// (see `AppEnvironment.showsBetaTools`). Tapping it opens the issue report sheet.
///
/// The button hides itself during screenshot capture so it never appears
/// in user-submitted screenshots.
struct FeedbackButton: View {
    @State private var isShowingReport = false

    var body: some View {
        Button {
            isShowingReport = true
        } label: {
            Image(systemName: "exclamationmark.bubble")
                .font(Typography.title.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .accessibilityLabel("Report an issue")
        .sheet(isPresented: $isShowingReport) {
            IssueReportView()
        }
    }
}
