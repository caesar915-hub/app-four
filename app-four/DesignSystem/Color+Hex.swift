import SwiftUI
import UIKit

extension Color {
    /// An adaptive colour from a light + dark hex pair — the Paper & Pollen token pattern
    /// (warm paper in light, warm loam in dark).
    init(lightHex: String, darkHex: String) {
        self.init(uiColor: UIColor { trait in
            UIColor(Color(hex: trait.userInterfaceStyle == .dark ? darkHex : lightHex))
        })
    }

    /// Creates an sRGB colour from a hex string like `"#79B89C"` or `"79B89C"`.
    /// Used for the custom mood palette, which is not part of the iOS system colours.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
