// The four level scales (MoodLevel/EnergyLevel/FocusLevel/SleepLevel) were hoisted into the
// `SquirlSignals` package. A single `@_exported import` re-exports them so every file in the
// app module keeps seeing them unqualified — no per-file import churn.
@_exported import SquirlSignals
