import SwiftUI

/// The pen's Frame 12 glyph art, transcribed from the design exports into a 64 × 64 space
/// (DESIGN.md §7.2). Every glyph view scales this space to its frame. Level encoding is
/// applied by the views: sprout colours (+ a crown-growth cue), bolt and moon rising-fill
/// masks, target arc sweep.
enum GlyphArt {
    static let canvas: CGFloat = 64

    // MARK: Sprout (mood)
    enum Sprout {
        static let stem = Path(svg: "M 31.604 55.009 C 31.804 43.808 29.405 35.506 21.402 28.104 M 31.505 46.806 C 32.804 38.207 37.205 32.305 45.106 26.805")
        static let stemWidth: CGFloat = 1.573
        static let leafA = Path(svg: "M 29.306 34.804 C 16.103 38.205 9.001 28.703 9.001 13.002 C 25.704 12.502 34.105 20.903 29.306 34.804 Z")
        static let leafB = Path(svg: "M 34.605 39.205 C 30.505 25.104 39.105 17.502 55.009 17.502 C 56.308 32.705 47.907 42.905 34.605 39.205 Z")
        static let veinA = Path(svg: "M 29.204 34.905 L 20.202 25.804")
        static let veinB = Path(svg: "M 35.105 38.705 L 44.606 29.104")
        static let veinWidth: CGFloat = 1.206
        /// Where the stem meets the ground — the anchor for the crown-growth cue.
        static let base = CGPoint(x: 31.6, y: 55.0)
    }

    // MARK: Bolt (energy)
    enum Bolt {
        static let outline = Path(svg: "M 24.502 9.000 H 42.004 C 43.139 9.000 43.471 9.532 43.006 10.600 L 35.204 28.001 H 48.906 C 50.306 28.001 50.507 28.568 49.507 29.703 L 23.602 55.807 C 22.469 56.940 22.102 56.739 22.503 55.206 L 27.604 36.004 H 15.601 C 14.468 36.004 14.102 35.470 14.501 34.403 L 22.701 10.299 C 22.968 9.433 23.569 9.000 24.502 9.000 Z")
        static let facet = Path(svg: "M 24.502 9.000 H 42.004 C 43.139 9.000 43.471 9.532 43.006 10.600 L 35.204 28.001 H 25.403 L 22.402 36.004 H 15.601 C 14.468 36.004 14.102 35.470 14.501 34.403 L 22.701 10.299 C 22.968 9.433 23.569 9.000 24.502 9.000 Z")
        /// Height of the rising fill per level, measured from the bottom of the 64 space.
        static let fillHeights: [CGFloat] = [16.8, 26.6, 36.4, 46.2, 56.0]
    }

    // MARK: Target (focus)
    enum Target {
        static let center = CGPoint(x: 28.004, y: 36.006)
        static let ringOuter: CGFloat = 21.753
        static let ringInner: CGFloat = 16.252
        static let discOuter: CGFloat = 11.252
        static let discInner: CGFloat = 7.751
        /// Arc sweep per level, clockwise from 12 o'clock.
        static let sweeps: [Double] = [72, 180, 216, 360, 360]
        static let shaft = Path(svg: "M 29.595 37.595 L 51.098 16.092 L 47.915 12.910 L 26.412 34.413 L 29.595 37.595 Z")
        static let head = Path(svg: "M 45.007 10.501 L 54.108 9.700 C 54.908 9.633 55.275 10.001 55.208 10.800 L 54.508 20.003 C 54.441 21.002 54.008 21.102 53.208 20.302 L 49.807 16.901 H 46.307 L 43.306 13.900 C 42.639 13.235 42.673 12.535 43.406 11.800 L 45.007 10.501 Z")
        static let centerDot = CGRect(x: 25.755, y: 33.755, width: 4.5, height: 4.5)
        static let tipDot = CGRect(x: 47.258, y: 12.252, width: 4.5, height: 4.5)
    }

    // MARK: Moon (sleep)
    enum Moon {
        static let moon = Path(svg: "M 38.800 9.399 C 22.998 5.197 8.998 17.197 8.998 32.797 C 8.998 47.799 20.800 57.197 34.598 55.098 C 43.699 53.700 50.800 47.098 53.901 39.098 C 40.000 44.100 27.699 35.597 27.699 23.098 C 27.699 17.098 31.600 11.799 38.800 9.399 Z")
        static let highlight = Path(svg: "M 8.998 32.800 C 8.998 47.799 20.800 57.200 34.598 55.101 C 42.000 54.000 48.198 49.200 51.802 43.101 C 43.802 50.999 29.901 51.399 20.602 42.999 C 12.602 35.799 12.800 23.300 18.400 14.999 C 12.598 19.200 8.998 25.700 8.998 32.800 Z")
        static let star = Path(svg: "M 46.998 9.498 C 47.699 15.600 49.501 17.399 55.501 18.100 C 49.501 18.800 47.699 20.599 46.998 26.698 C 46.301 20.599 44.499 18.800 38.499 18.100 C 44.499 17.399 46.301 15.600 46.998 9.498 Z")
        static let moonFillHeights: [CGFloat] = [16.8, 26.6, 36.4, 46.2, 56.0]
        static let starFillHeights: [CGFloat] = [40.74, 44.18, 47.62, 51.06, 54.5]
    }
}

/// Per-level sprout colours (Frame 12): leaf A · leaf B + stem · vein.
enum SproutPalette {
    static func colors(for level: Int) -> (leafA: Color, leafB: Color, vein: Color) {
        switch level {
        case 1: (Color(hex: "#d97773"), Color(hex: "#bc4749"), Color(hex: "#eeb4aa"))
        case 2: (Color(hex: "#e8b964"), Color(hex: "#c58b37"), Color(hex: "#f6dca6"))
        case 3: (Color(hex: "#b1c194"), Color(hex: "#82936b"), Color(hex: "#d9e2c6"))
        case 4: (Color(hex: "#75ba4f"), Color(hex: "#2a9134"), Color(hex: "#b7dc88"))
        default: (Color(hex: "#428d52"), Color(hex: "#175723"), Color(hex: "#9ccaa0"))
        }
    }
}

extension GraphicsContext {
    /// Scales the 64 × 64 art space to `size`, centred and aspect-preserving.
    mutating func enterGlyphSpace(_ size: CGSize) {
        let s = min(size.width, size.height) / GlyphArt.canvas
        translateBy(x: (size.width - GlyphArt.canvas * s) / 2, y: (size.height - GlyphArt.canvas * s) / 2)
        scaleBy(x: s, y: s)
    }

    /// A rectangle covering the bottom `height` of the art space — the rising-fill mask.
    func risingMask(height: CGFloat) -> Path {
        Path(CGRect(x: -1, y: GlyphArt.canvas - height, width: GlyphArt.canvas + 2, height: height + 1))
    }
}
