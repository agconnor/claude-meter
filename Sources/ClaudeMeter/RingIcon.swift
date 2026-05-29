import AppKit
import ClaudeMeterCore

/// Renders the menu-bar glyph: two concentric donuts. The outer ring is the session
/// (5h) window, the inner ring is the week (7d) window. Each is fully filled at 0%
/// usage and is eaten away counter-clockwise from the top as it approaches 100%.
enum RingIcon {
    private static let dim: CGFloat = 18

    // Outer donut (session) and inner donut (week): [outerRadius, innerRadius].
    private static let sessionRing: (r0: CGFloat, r1: CGFloat) = (8.5, 5.5)
    private static let weekRing: (r0: CGFloat, r1: CGFloat) = (4.0, 1.0)

    static func image(session: Double?, week: Double?) -> NSImage {
        let size = NSSize(width: dim, height: dim)
        let img = NSImage(size: size)
        img.lockFocus()
        let center = CGPoint(x: dim / 2, y: dim / 2)
        NSColor.black.setFill()
        drawRing(center: center, outer: sessionRing.r0, inner: sessionRing.r1,
                 fraction: RingGeometry.filledFraction(utilization: session))
        drawRing(center: center, outer: weekRing.r0, inner: weekRing.r1,
                 fraction: RingGeometry.filledFraction(utilization: week))
        img.unlockFocus()
        img.isTemplate = true   // let the menu bar tint it (and honor contentTintColor)
        return img
    }

    /// Fills the remaining `fraction` of an annulus, starting at the top (12 o'clock)
    /// and sweeping clockwise — so the empty arc grows counter-clockwise.
    private static func drawRing(center: CGPoint, outer: CGFloat, inner: CGFloat, fraction: Double) {
        guard fraction > 0 else { return }   // 100% used → nothing drawn

        if fraction >= 1 {                    // 0% used → solid ring (annulus via even-odd)
            let path = NSBezierPath(ovalIn: rect(center, outer))
            path.append(NSBezierPath(ovalIn: rect(center, inner)))
            path.windingRule = .evenOdd
            path.fill()
            return
        }

        let start: CGFloat = 90                       // top
        let end = start - CGFloat(fraction) * 360     // clockwise sweep
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: outer, startAngle: start, endAngle: end, clockwise: true)
        path.appendArc(withCenter: center, radius: inner, startAngle: end, endAngle: start, clockwise: false)
        path.close()
        path.fill()
    }

    private static func rect(_ center: CGPoint, _ r: CGFloat) -> CGRect {
        CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
    }
}
