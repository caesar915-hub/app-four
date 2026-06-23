import CoreFoundation

/// Corner-radius constants. Two values only; circular shapes use `.circle`.
enum Radius {
    /// 16pt — cards, sheet content areas, text editor background (Paper & Pollen)
    static let card: CGFloat = 16
    /// 10pt — chips, small buttons, segmented-style controls
    static let control: CGFloat = 10
    /// 16pt — tall, generously rounded action buttons (Check-in hub / stop)
    static let button: CGFloat = 16
    /// 15pt — signal / feeling / side-effect chips in the expanded check-in row
    static let chip: CGFloat = 15
}
