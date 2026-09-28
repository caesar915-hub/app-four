import SwiftUI

public extension Text {
    /// Pre-057 uppercase card eyebrow — now the pen's row label ink; the uppercase tracking is
    /// gone (the pen has no eyebrows). Its four call sites migrate to `SectionHeading` in Phase C.
    public func cardEyebrow() -> some View {
        self
            .font(Typography.rowLabel)
            .foregroundStyle(Ink.primary)
    }
}
