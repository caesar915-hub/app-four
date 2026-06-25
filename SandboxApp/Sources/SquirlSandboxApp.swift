import SwiftUI
import SquirlDesignSystem

@main
struct SquirlSandboxApp: App {
    init() { SquirlFonts.register() }

    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @State private var dark = false
    @State private var tab = "calendar"

    var body: some View {
        TabView(selection: $tab) {
            navWrap(SandboxCalendar(), title: "Calendar")
                .tabItem { Label("Calendar", systemImage: "calendar") }.tag("calendar")
            navWrap(DesignGallery(), title: "Gallery")
                .tabItem { Label("Gallery", systemImage: "square.grid.2x2") }.tag("gallery")
        }
        .preferredColorScheme(dark ? .dark : .light)
        .tint(Theme.meadowGreen)
    }

    private func navWrap<C: View>(_ content: C, title: String) -> some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(dark ? "☀︎ Light" : "☾ Dark") { dark.toggle() }
                    }
                }
        }
    }
}
