import Foundation

enum PromptPace: Int, CaseIterable {
    case relaxed = 10
    case brisk = 6

    var displayLabel: String {
        switch self {
        case .relaxed: "Relaxed · 10 s"
        case .brisk: "Brisk · 6 s"
        }
    }

    var interval: TimeInterval { TimeInterval(rawValue) }
}
