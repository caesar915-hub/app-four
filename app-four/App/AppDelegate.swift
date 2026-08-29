import UIKit

/// Reconnects out-of-process background URLSession transfers to the app.
///
/// `BackgroundLLMDownloadService` transfers ownership of the ~1 GB insights-model
/// download to `nsurlsessiond`, which keeps downloading while the app is suspended
/// or terminated. When all transfers for the session finish, the system relaunches
/// the app in the background and calls
/// `application(_:handleEventsForBackgroundURLSession:completionHandler:)` — the
/// completion handler MUST be retained and invoked (via
/// `BackgroundLLMDownloadService.setBackgroundCompletionHandler`) after the
/// session's delegate callbacks have been replayed, or the app risks a watchdog
/// termination on the background relaunch.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == BackgroundLLMDownloadService.sessionIdentifier else {
            completionHandler()
            return
        }
        BackgroundLLMDownloadService.shared.setBackgroundCompletionHandler(completionHandler)
    }
}
