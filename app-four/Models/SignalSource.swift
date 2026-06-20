import Foundation

/// Provenance of a signal group on a given day. Drives the merge rule in
/// `SignalSyncCoordinator`: HealthKit fills `.none`, re-syncs `.healthKit`, and
/// never overwrites `.manual`.
enum SignalSource: String, Codable, Sendable {
    case none
    case healthKit
    case manual
}
