import SwiftUI

#if DEBUG || TESTFLIGHT

/// A small floating button present on all screens when compiled for Debug
/// or TestFlight builds. Tapping it opens the issue report sheet.
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
                .font(Typography.question)
                .foregroundStyle(.primary)
                .frame(width: 48, height: 48)
                .background(Surface.card)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .accessibilityLabel("Report an issue")
        .sheet(isPresented: $isShowingReport) {
            IssueReportView()
        }
    }
}

#endif
