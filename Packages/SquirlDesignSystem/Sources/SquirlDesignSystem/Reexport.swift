// The level enums live in the SquirlSignals leaf package. Re-export them so every file in
// SquirlDesignSystem sees MoodLevel/EnergyLevel/FocusLevel/SleepLevel unqualified, and so
// consumers of SquirlDesignSystem get them transitively too.
@_exported import SquirlSignals
