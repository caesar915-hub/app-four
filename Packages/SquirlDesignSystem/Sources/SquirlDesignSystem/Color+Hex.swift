import SwiftUI
import UIKit

public extension Color {
    /// An adaptive colour from a light + dark hex pair. The pen (spec 057) is light-only; every
    /// dark value is derived and recorded in DESIGN.md §11.
    public init(lightHex: String, darkHex: String) {
        self.init(uiColor: UIColor { trait in
            UIColor(Color(hex: trait.userInterfaceStyle == .dark ? darkHex : lightHex))
        })
    }

    /// An adaptive colour with a per-appearance alpha — hairlines and washes such as
    /// `#000000 @ 0.10` in light / `#ffffff @ 0.12` in dark.
    public init(lightHex: String, lightAlpha: Double, darkHex: String, darkAlpha: Double) {
        self.init(uiColor: UIColor { trait in
            let dark = trait.userInterfaceStyle == .dark
            return UIColor(Color(hex: dark ? darkHex : lightHex))
                .withAlphaComponent(dark ? darkAlpha : lightAlpha)
        })
    }

    /// Creates an sRGB colour from a hex string like `"#79B89C"` or `"79B89C"`.
    public init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
