import AppIntents

/// 030 / US1 — zero-setup system exposure (FR-017/SC-003): Siri, Spotlight, and the
/// Shortcuts app discover these from install, no user setup. The check-in shortcut
/// joins in US2 (T028). Every phrase carries `.applicationName` (contract); no
/// parameters, so no `updateAppShortcutParameters()`.
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
    }
}
