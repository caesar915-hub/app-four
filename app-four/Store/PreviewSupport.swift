/// Preview-time convenience accessors so `#Preview` blocks never reference
/// `AppDependencies` directly. The values are the same shared instances —
/// no extra allocation happens.
extension RecordingStore {
    static let preview: RecordingStore = AppDependencies.store
}

extension AppServices {
    static let preview: AppServices = AppDependencies.services
}
