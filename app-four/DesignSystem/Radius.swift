import CoreFoundation

/// Corner-radius constants. Two values only; circular shapes use `.circle`.
enum Radius {
    /// 12pt — cards, sheet content areas, text editor background
    static let card: CGFloat = 12
    /// 10pt — chips, small buttons, segmented-style controls
    static let control: CGFloat = 10
    /// 16pt — tall, generously rounded action buttons (Check-in hub / stop)
    static let button: CGFloat = 16
}
