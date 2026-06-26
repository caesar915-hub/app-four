import CoreText
import Foundation

/// Registers the bundled Paper & Pollen fonts (Fraunces, DM Sans, IBM Plex Mono) so SwiftUI's
/// `.custom(...)` resolves them. The host app's `Info.plist UIAppFonts` does NOT cover fonts
/// shipped inside a Swift package's `Bundle.module`, so a UI-only consumer (e.g. the sandbox)
/// must call `SquirlFonts.register()` once at launch. The main app already declares the fonts in
/// its own bundle, so for it this is a harmless no-op safety net.
public enum SquirlFonts {
    public static func register() {
        let names = ["Fraunces", "FrauncesItalic", "DMSans", "IBMPlexMono-Regular", "IBMPlexMono-Medium"]
        for name in names {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.module.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
