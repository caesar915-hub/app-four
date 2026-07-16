import CoreFoundation

/// Corner-radius constants. Two values only; circular shapes use `.circle`.
public enum Radius {
    /// 16pt — cards, sheet content areas, text editor background (Paper & Pollen)
    public static let card: CGFloat = 16
    /// 10pt — chips, small buttons, segmented-style controls
    public static let control: CGFloat = 10
    /// 16pt — tall, generously rounded action buttons (Check-in hub / stop)
    public static let button: CGFloat = 16
    /// 15pt — signal / emotion / side-effect chips in the expanded check-in row
    public static let chip: CGFloat = 15
    /// 20pt — New Look card radius (spec 032). Paper & Pollen keeps `card` at 16.
    public static let newLookCard: CGFloat = 20
}
