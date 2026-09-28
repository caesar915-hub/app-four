import SwiftUI

/// Standard screen wrapper that every tab root uses.
///
/// Provides:
/// - `NavigationStack` with a bound or internal `NavigationPath`
/// - the pen's chrome-less root: no system navigation bar, no system tab bar (the floating
///   chrome is overlaid by `RootTabView`), and a bottom inset that keeps content clear of it
/// - the medication bar via `.medicationBarOverlay()` — single shared placement
/// - programmatic scroll-to-top: increment `scrollResetToken` from outside to jump back
/// - optional `ScrollView` wrapper — pass `scrollable: false` for screens that manage
///   their own scroll (List) or use Spacer-based layouts (CheckInView).
struct ScreenContainer<Content: View>: View {
    let title: String
    var showsMedicationBar: Bool = true
    var scrollable: Bool = true
    /// Whether to reserve the floating chrome's height at the bottom (false while a screen hides it).
    var reservesFloatingChrome: Bool = true
    /// Increment to programmatically scroll the container back to the top.
    var scrollResetToken: Int = 0
    var path: Binding<NavigationPath>?

    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var internalPath = NavigationPath()
    @State private var scrollPosition = ScrollPosition(edge: .top)

    private var resolvedPath: Binding<NavigationPath> {
        path ?? $internalPath
    }

    var body: some View {
        NavigationStack(path: resolvedPath) {
            primaryContent
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
                .background(Surface.screen.ignoresSafeArea())
                .toolbarBackground(Surface.screen, for: .navigationBar)
        }
        .tint(Accent.primaryFill)
    }

    // MARK: - Private

    @ViewBuilder
    private var primaryContent: some View {
        if scrollable {
            ScrollView {
                content()
            }
            .scrollContentBackground(.hidden)
            .scrollPosition($scrollPosition)
            .onChange(of: scrollResetToken) {
                withAnimation(reduceMotion ? nil : Motion.expand) {
                    scrollPosition.scrollTo(edge: .top)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { chromeInset }
            .medicationBarOverlay(shown: showsMedicationBar)
        } else {
            content()
                .safeAreaInset(edge: .bottom, spacing: 0) { chromeInset }
                .medicationBarOverlay(shown: showsMedicationBar)
        }
    }

    @ViewBuilder private var chromeInset: some View {
        if reservesFloatingChrome {
            Color.clear.frame(height: Metrics.floatingChromeInset)
        }
    }
}

// MARK: - Preview

#Preview("Scrollable (default)") {
    ScreenContainer(title: "") {
        LazyVStack {
            ForEach(0..<20) { i in
                Text("Row \(i)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.l)
            }
        }
    }
    .withPreviewEnvironment()
}

#Preview("Non-scrollable") {
    ScreenContainer(title: "", scrollable: false) {
        VStack {
            Spacer()
            Text("Centered content")
            Spacer()
        }
    }
    .withPreviewEnvironment()
}
