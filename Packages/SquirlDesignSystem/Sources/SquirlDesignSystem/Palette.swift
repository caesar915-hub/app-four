import SwiftUI

/// Primitive colour namespace: the three pen ramps live in `Palette+Ramps`, the chart ramps in
/// `Palette+Signals`. Views reach for `Surface` / `Ink` / `Accent` / `Stroke`, never `Palette`.
public enum Palette {}
