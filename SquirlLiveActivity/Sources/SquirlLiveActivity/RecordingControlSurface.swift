import Foundation

/// 037 — the minimal, app-type-free control surface the Live Activity intents call.
///
/// It lives in the shared package on purpose: `StopRecordingIntent` /
/// `PauseRecordingIntent` / `ResumeRecordingIntent` reference it, and the package is
/// linked by BOTH the app and the widget extension — so the widget can build its
/// `Button(intent:)` from the intent *types* while the intents' `perform()` runs in
/// the app process, where the concrete conformer is registered with
/// `AppDependencyManager` (research D10/D11).
///
/// Deliberately narrow: only the three background-invocable control actions, none of
/// the app's lifecycle types (`RecordingState`, capture ids), so the package stays
/// free of app coupling (research D2).
@MainActor
public protocol RecordingControlSurface: Sendable {
    /// FR-004 — suspend capture without ending it; the recorder keeps the file open.
    func pause() async
    /// FR-004 — continue the same capture.
    func resume() async throws
    /// FR-003 — idempotent finalize through the same save pipeline as an in-app stop.
    func stopAndSave() async
}
