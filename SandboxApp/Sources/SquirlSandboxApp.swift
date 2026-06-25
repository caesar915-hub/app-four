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

    var body: some View {
        NavigationStack {
            DesignGallery()
                .navigationTitle("Squirl Sandbox")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(dark ? "☀︎ Light" : "☾ Dark") { dark.toggle() }
                    }
                }
        }
        .preferredColorScheme(dark ? .dark : .light)
    }
}
