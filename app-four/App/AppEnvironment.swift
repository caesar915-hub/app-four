import Foundation

enum AppEnvironment {
    /// True only for TestFlight builds. TestFlight installs ship an App Store
    /// *sandbox* receipt; App Store production installs ship a `receipt` file.
    static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    /// Beta-only affordances (feedback button, service inspector): visible in
    /// Debug and TestFlight, never in App Store production. Gated at runtime so a
    /// single Release archive serves both TestFlight and the App Store without a
    /// separate build configuration to misconfigure.
    static var showsBetaTools: Bool {
        #if DEBUG
        true
        #else
        isTestFlight
        #endif
    }
}
