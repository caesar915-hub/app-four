import AppIntents

/// 037 — the three Live Activity control intents (contract §3). Each is thin: resolve
/// the app-registered `RecordingControlSurface`, call one method, return.
///
/// `LiveActivityIntent`: `perform()` runs in the app process — the system launches it
/// in the background without foregrounding or unlocking (research D7/D8) — so it reaches
/// the live recorder + SwiftData context. They live in the shared package so the widget
/// extension can build `Button(intent:)` for the Lock Screen / expanded Dynamic Island.
///
/// `authenticationPolicy` is pinned to the platform default `.alwaysAllowed` as a
/// documented contract: it MUST NOT become `.requiresAuthentication`, which would force
/// an unlock and break FR-005 (control while locked).

public struct StopRecordingIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Stop & save check-in"
    /// Backs a Live Activity button only — keep it out of the Shortcuts library.
    public static let isDiscoverable = false
    public static let authenticationPolicy = IntentAuthenticationPolicy.alwaysAllowed

    @AppDependency private var control: any RecordingControlSurface

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        // Fully awaited before returning (research D9): the save must commit before
        // `perform()` returns, or the background finalize is truncated → lost capture.
        await control.stopAndSave()
        return .result()
    }
}

public struct PauseRecordingIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Pause check-in"
    /// Backs a Live Activity button only — keep it out of the Shortcuts library.
    public static let isDiscoverable = false
    public static let authenticationPolicy = IntentAuthenticationPolicy.alwaysAllowed

    @AppDependency private var control: any RecordingControlSurface

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        await control.pause()
        return .result()
    }
}

public struct ResumeRecordingIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Resume check-in"
    /// Backs a Live Activity button only — keep it out of the Shortcuts library.
    public static let isDiscoverable = false
    public static let authenticationPolicy = IntentAuthenticationPolicy.alwaysAllowed

    @AppDependency private var control: any RecordingControlSurface

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        try await control.resume()
        return .result()
    }
}
