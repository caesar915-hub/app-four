import SwiftUI

public extension Path {
    /// Builds a path from an SVG `d` string (M/L/H/V/C/S/Q/T/Z, absolute and relative). Arcs are
    /// not supported — none of the pen's glyph art uses them. Used for the Frame 12 glyph art,
    /// which lives in a 64 × 64 space and is scaled by the drawing view.
    init(svg: String) {
        var path = Path()
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControl: CGPoint?
        var lastCommand: Character = "M"
        let scanner = SVGScanner(svg)

        while let command = scanner.nextCommand(defaultAfter: lastCommand) {
            let relative = command.isLowercase
            let base: CGPoint = relative ? current : .zero
            switch command.uppercased() {
            case "M":
                guard let p = scanner.point(base) else { break }
                path.move(to: p); current = p; subpathStart = p; lastControl = nil
                lastCommand = relative ? "l" : "L"
                continue
            case "L":
                guard let p = scanner.point(base) else { break }
                path.addLine(to: p); current = p; lastControl = nil
            case "H":
                guard let x = scanner.number() else { break }
                let p = CGPoint(x: (relative ? current.x : 0) + x, y: current.y)
                path.addLine(to: p); current = p; lastControl = nil
            case "V":
                guard let y = scanner.number() else { break }
                let p = CGPoint(x: current.x, y: (relative ? current.y : 0) + y)
                path.addLine(to: p); current = p; lastControl = nil
            case "C":
                guard let c1 = scanner.point(base), let c2 = scanner.point(base), let p = scanner.point(base) else { break }
                path.addCurve(to: p, control1: c1, control2: c2); current = p; lastControl = c2
            case "S":
                guard let c2 = scanner.point(base), let p = scanner.point(base) else { break }
                let c1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                path.addCurve(to: p, control1: c1, control2: c2); current = p; lastControl = c2
            case "Q":
                guard let c = scanner.point(base), let p = scanner.point(base) else { break }
                path.addQuadCurve(to: p, control: c); current = p; lastControl = c
            case "T":
                guard let p = scanner.point(base) else { break }
                let c = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                path.addQuadCurve(to: p, control: c); current = p; lastControl = c
            case "Z":
                path.closeSubpath(); current = subpathStart; lastControl = nil
            default:
                break
            }
            lastCommand = command
        }
        self = path
    }
}

/// Minimal tokenizer for SVG path data.
private final class SVGScanner {
    private let chars: [Character]
    private var index = 0

    init(_ string: String) { chars = Array(string) }

    private func skipSeparators() {
        while index < chars.count, chars[index] == " " || chars[index] == "," || chars[index] == "\n" || chars[index] == "\t" {
            index += 1
        }
    }

    /// The next command letter, or `defaultAfter` (implicit repeat) when a number follows directly.
    func nextCommand(defaultAfter last: Character) -> Character? {
        skipSeparators()
        guard index < chars.count else { return nil }
        let c = chars[index]
        if c.isLetter {
            index += 1
            return c
        }
        return last.uppercased() == "Z" ? nil : last
    }

    func number() -> CGFloat? {
        skipSeparators()
        var text = ""
        while index < chars.count {
            let c = chars[index]
            if c.isNumber || c == "." || c == "-" || c == "+" || c == "e" || c == "E" {
                if (c == "-" || c == "+") && !text.isEmpty && !(text.last == "e" || text.last == "E") { break }
                if c == "." && text.contains(".") { break }
                text.append(c); index += 1
            } else { break }
        }
        return Double(text).map { CGFloat($0) }
    }

    func point(_ base: CGPoint) -> CGPoint? {
        guard let x = number(), let y = number() else { return nil }
        return CGPoint(x: base.x + x, y: base.y + y)
    }
}
