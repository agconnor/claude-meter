import AppKit
import ClaudeMeterCore

/// Renders the menu-bar glyph: two concentric donuts, each split into two lanes.
///
///   outer donut = session (5h):  outer lane = usage, inner lane = time-left
///   inner donut = week   (7d):  outer lane = usage, inner lane = time-left
///
/// In every lane the filled arc is what *remains*, eaten counter-clockwise from the
/// top. The two donuts are separated by a wide gap so the session/week grouping
/// reads clearly. Usage lanes are drawn in `usageColor` (the menu-bar foreground,
/// or a warning tint); time-left lanes in `timeColor` (blue). Because it is colored
/// it is NOT a template image, so the caller passes the menu bar's appearance and we
/// resolve the dynamic colors against it.
enum RingIcon {
    private static let dim: CGFloat = 20

    // Lane radii (outerR, innerR), outermost first. The big gap between the session
    // time lane (…6.15) and the week usage lane (4.6…) is the inter-donut spacing.
    private static let sessionUsage: (CGFloat, CGFloat) = (9.6, 8.0)
    private static let sessionTime:  (CGFloat, CGFloat) = (7.75, 6.15)
    private static let weekUsage:    (CGFloat, CGFloat) = (4.6, 3.0)
    private static let weekTime:     (CGFloat, CGFloat) = (2.75, 1.15)

    static func image(session: UsageWindow?, week: UsageWindow?, now: Date = Date(),
                      usageColor: NSColor, timeColor: NSColor,
                      appearance: NSAppearance? = nil) -> NSImage {
        let size = NSSize(width: dim, height: dim)
        let img = NSImage(size: size)
        img.lockFocus()
        let c = CGPoint(x: dim / 2, y: dim / 2)

        let draw = {
            usageColor.setFill()
            lane(c, sessionUsage, RingGeometry.filledFraction(utilization: session?.utilization))
            lane(c, weekUsage, RingGeometry.filledFraction(utilization: week?.utilization))

            timeColor.setFill()
            lane(c, sessionTime, RingGeometry.timeRemainingFraction(
                resetsAt: session?.resetsAt, now: now, windowSeconds: WindowLength.session))
            lane(c, weekTime, RingGeometry.timeRemainingFraction(
                resetsAt: week?.resetsAt, now: now, windowSeconds: WindowLength.week))
        }
        // Resolve dynamic colors (labelColor / systemBlue) against the menu bar's appearance.
        if let appearance { appearance.performAsCurrentDrawingAppearance(draw) } else { draw() }

        img.unlockFocus()
        img.isTemplate = false   // colored — not a single-tint template
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
