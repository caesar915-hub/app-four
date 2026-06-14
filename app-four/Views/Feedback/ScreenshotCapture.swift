import SwiftUI

/// Captures the current screen as a UIImage, temporarily hiding the feedback
/// button so it does not appear in the resulting screenshot.
@Observable
@MainActor
final class ScreenshotCapture {
    var isCapturing: Bool = false

    /// Renders the key window's root view controller view into a UIImage.
    /// Returns nil if no valid window scene is found.
    func capture() async -> UIImage? {
        isCapturing = true
        // Allow one render cycle for the button to hide
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        defer { isCapturing = false }

        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootView = window.rootViewController?.view
        else {
            AppLogger.log("ScreenshotCapture: no valid window scene found")
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: rootView.bounds.size)
        let image = renderer.image { context in
            rootView.drawHierarchy(in: rootView.bounds, afterScreenUpdates: true)
        }

        return image
    }
}
