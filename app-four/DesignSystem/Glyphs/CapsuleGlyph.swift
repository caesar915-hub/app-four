import SwiftUI

/// Medication — a single horizontal two-tone capsule (does not vary by level; rendered as
/// a chip, never on the 1→5 ramp). One darker half + a seam read instantly as "a dose".
struct CapsuleGlyph: View {
    var color: Color = Palette.medication

    var body: some View {
        GeometryReader { geo in
            let capW = geo.size.width * 0.86
            let capH = geo.size.height * 0.42
            ZStack {
                Capsule().fill(color.opacity(0.22))
                Capsule().fill(color.opacity(0.5))
                    .mask(alignment: .leading) { Color.black.frame(width: capW / 2) }
                Capsule().strokeBorder(color, lineWidth: 2)
                Rectangle().fill(color.opacity(0.8)).frame(width: 1.6, height: capH * 0.66)
            }
            .frame(width: capW, height: capH)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

#Preview { CapsuleGlyph().frame(width: 40, height: 40).padding() }
