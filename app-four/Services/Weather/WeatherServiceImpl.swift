import Foundation
import CoreLocation
import WeatherKit

/// Best-effort weather lookup: one-shot **reduced-accuracy** location → Apple WeatherKit.
/// Returns `nil` on every failure, never throws, never starts continuous location updates,
/// and races a timeout so it cannot block a check-in indefinitely.
///
/// Permitted by the Constitution Principle VI scoped weather exception: only coarse
/// location is sent to first-party WeatherKit; no user content leaves the device; the
/// result is stored on-device. Logs record outcome only — never coordinates/condition/temp.
final class WeatherServiceImpl: WeatherService {

    /// Upper bound so a stuck location/network fix can't keep the capture task alive.
    private let timeoutSeconds: UInt64 = 10

    func currentSnapshot() async -> WeatherSnapshot? {
        await withTaskGroup(of: WeatherSnapshot?.self) { group in
            group.addTask { await self.fetch() }
            group.addTask {
                try? await Task.sleep(nanoseconds: self.timeoutSeconds * 1_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func fetch() async -> WeatherSnapshot? {
        guard let location = await OneShotLocation().requestOnce() else {
            AppLogger.log("Weather: skipped — no location/permission")
            return nil
        }
        do {
            let current = try await WeatherKit.WeatherService.shared.weather(for: location).currentWeather
            AppLogger.log("Weather: captured")
            return WeatherSnapshot(
                conditionCode: current.condition.rawValue,
                temperatureC: current.temperature.converted(to: .celsius).value,
                symbolName: current.symbolName,
                capturedAt: current.date
            )
        } catch {
            AppLogger.log("Weather: lookup failed")
            return nil
        }
    }
}

/// One-shot, reduced-accuracy location fix bridged from `CLLocationManager`'s delegate to
/// async via a single-resume continuation. Authorization is requested lazily; denial/
/// restriction/error all resolve to `nil`.
@MainActor
private final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    func requestOnce() async -> CLLocation? {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        // Cancellation-aware: when the caller's timeout task wins and cancels this child,
        // resume the continuation with nil immediately. Without this, a never-answered
        // permission prompt (delegate never fires) would suspend forever and the 10s
        // timeout could never take effect — breaking "never block a check-in".
        return await withTaskCancellationHandler {
            await withCheckedContinuation { cont in
                self.continuation = cont
                switch manager.authorizationStatus {
                case .authorizedWhenInUse, .authorizedAlways:
                    manager.requestLocation()
                case .notDetermined:
                    manager.requestWhenInUseAuthorization() // didChangeAuthorization drives next step
                default:
                    resume(nil) // denied / restricted
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.resume(nil) }
        }
    }

    private func resume(_ value: CLLocation?) {
        continuation?.resume(returning: value)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            break
        default:
            resume(nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        resume(locations.first)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resume(nil)
    }
}
