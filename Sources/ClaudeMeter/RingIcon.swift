import AppKit
import ClaudeMeterCore

/// Renders the menu-bar glyph: two concentric donuts, each split into two lanes.
///
///   outer donut = session (5h):  outer lane = usage, inner lane = time-left
///   inner donut = week   (7d):  outer lane = usage, inner lane = time-left
///
/// In every lane the filled arc is what *remains*, eaten counter-clockwise from the
/// top — so a lane is full at 0% used / a fresh window and empty at 100% / at reset.
enum RingIcon {
    private static let dim: CGFloat = 20

    // Lane radii (outerR, innerR), outermost first.
    private static let sessionUsage: (CGFloat, CGFloat) = (9.5, 7.6)
    private static let sessionTime:  (CGFloat, CGFloat) = (7.4, 5.5)
    private static let weekUsage:    (CGFloat, CGFloat) = (4.9, 3.0)
    private static let weekTime:     (CGFloat, CGFloat) = (2.8, 0.9)

    static func image(session: UsageWindow?, week: UsageWindow?, now: Date = Date()) -> NSImage {
        let size = NSSize(width: dim, height: dim)
        let img = NSImage(size: size)
        img.lockFocus()
        let c = CGPoint(x: dim / 2, y: dim / 2)
        NSColor.black.setFill()

        lane(c, sessionUsage, RingGeometry.filledFraction(utilization: session?.utilization))
        lane(c, sessionTime, RingGeometry.timeRemainingFraction(
            resetsAt: session?.resetsAt, now: now, windowSeconds: WindowLength.session))
        lane(c, weekUsage, RingGeometry.filledFraction(utilization: week?.utilization))
        lane(c, weekTime, RingGeometry.timeRemainingFraction(
            resetsAt: week?.resetsAt, now: now, windowSeconds: WindowLength.week))

        img.unlockFocus()
        img.isTemplate = true   // let the menu bar tint it (and honor contentTintColor)
        return img
    }

    /// Fills the remaining `fraction` of one annulus lane, starting at the top
    /// (12 o'clock) and sweeping clockwise — so the empty arc grows counter-clockwise.
    private static func lane(_ center: CGPoint, _ radii: (CGFloat, CGFloat), _ fraction: Double) {
        let (outer, inner) = radii
        guard fraction > 0 else { return }            // fully consumed → nothing drawn

        if fraction >= 1 {                            // full lane → solid annulus (even-odd)
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
