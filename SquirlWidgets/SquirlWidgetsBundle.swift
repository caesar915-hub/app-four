import WidgetKit
import SwiftUI

/// 037 — the extension hosts only the check-in recording Live Activity. No Home Screen
/// or Control Center widgets ship here (the generated samples were removed); the target
/// exists solely as WidgetKit's required render host for the Live Activity.
@main
struct SquirlWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SquirlWidgetsLiveActivity()
    }
}
