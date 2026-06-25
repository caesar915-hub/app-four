// The level scales and the design system were hoisted into SPM packages. A single
// `@_exported import` of each re-exports their public API so every file in the app module
// keeps seeing MoodLevel/Theme/Palette/SignalGlyph/… unqualified — no per-file import churn.
@_exported import SquirlSignals
@_exported import SquirlDesignSystem
