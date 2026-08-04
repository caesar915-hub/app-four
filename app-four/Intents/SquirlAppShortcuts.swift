import AppIntents

/// 030 / US1+US2 — zero-setup system exposure (FR-017/SC-003): Siri, Spotlight, and
/// the Shortcuts app discover these from install, no user setup. Every phrase carries
/// `.applicationName` (contract); no parameters, so no `updateAppShortcutParameters()`.
/// Two shortcuts, well under the 10-shortcut cap.
struct SquirlAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogDefaultDoseIntent(),
            phrases: [
                "Log my meds in \(.applicationName)",
                "\(.applicationName) dose",
                "Log my dose in \(.applicationName)"
            ],
            shortTitle: "Log My Meds",
            systemImageName: "pills.fill"
        )
        AppShortcut(
            intent: StartCheckInIntent(),
            phrases: [
                "Check in on \(.applicationName)",
                "Start a \(.applicationName) check-in"
            ],
            shortTitle: "Check In",
            systemImageName: "waveform"
        )
    }
}
