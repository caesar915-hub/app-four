import SwiftUI

/// Standard screen wrapper that every tab uses.
///
/// Provides:
/// - `NavigationStack` with a bound or internal `NavigationPath`
/// - `.navigationTitle` + `.navigationBarTitleDisplayMode(.inline)`
/// - Medication bar via `.medicationBarOverlay()` — single shared placement, floating Liquid Glass capsule.
/// - Edge fade mask on scrollable content (top is 0 — bar is translucent glass so content shows under it; bottom aligns with tab bar).
/// - Programmatic scroll-to-top: increment `scrollResetToken` from outside to jump back.
/// - Optional `ScrollView` wrapper — pass `scrollable: false` for screens that manage
///   their own scroll (List) or use Spacer-based layouts (CheckInView).
///
/// Usage:
/// ```swift
/// // Scrollable (default — Calendar, Insights):
/// ScreenContainer(title: "", path: $path, scrollResetToken: resetToken) {
///     VStack { ... }
/// }
///
/// // Non-scrollable (CheckInView, SettingsView with List):
/// ScreenContainer(title: "", scrollable: false) {
///     VStack { Spacer(); micButton; Spacer() }
/// }
/// ```
struct ScreenContainer<Content: View>: View {
    let title: String
    var showsMedicationBar: Bool = true
    var scrollable: Bool = true
    /// Increment to programmatically scroll the container back to the top.
    var scrollResetToken: Int = 0
    var path: Binding<NavigationPath>?

    @ViewBuilder let content: () -> Content

    @State private var internalPath = NavigationPath()
    @State private var scrollPosition = ScrollPosition(edge: .top)

    private var resolvedPath: Binding<NavigationPath> {
        path ?? $internalPath
    }

    // No top fade — the bar is now a translucent .bar material; content should frost under it, not fade to clear.
    private let barFadeHeight: CGFloat = 0
    // Matches the approximate tab bar height so content dissolves into the bar below.
    private let tabBarFadeHeight: CGFloat = 36

    var body: some View {
        NavigationStack(path: resolvedPath) {
            primaryContent
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .background(NewLook.screen.ignoresSafeArea())
                .toolbarBackground(NewLook.screen, for: .navigationBar)
        }
        .tint(Theme.meadowGreen)
        // Tab-bar appearance is a preference that flows UP from tab content — it must live here
        // (every tab's root), not on the TabView, where it silently no-ops.
        .toolbarBackground(NewLook.screen, for: .tabBar)
        .toolbarBackgroundVisibility(.visible, for: .tabBar)
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
                withAnimation(.easeOut(duration: 0.25)) {
                    scrollPosition.scrollTo(edge: .top)
                }
            }
            .edgeFadeMask(top: barFadeHeight, bottom: tabBarFadeHeight)
            .medicationBarOverlay(shown: showsMedicationBar)
        } else {
            content()
                .medicationBarOverlay(shown: showsMedicationBar)
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
