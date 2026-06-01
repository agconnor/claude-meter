import Foundation

/// Nominal lengths of the rate-limit windows, used to turn "time until reset" into
/// a 0…1 fraction for the time-left lane.
public enum WindowLength {
    public static let session: Double = 5 * 3600       // 5-hour rolling session
    public static let week: Double = 7 * 86400         // 7-day weekly window
}

/// Pure geometry for the concentric-donut menu-bar icon. Drawing lives in the app
/// target; this is the testable part. In every lane, the *filled* fraction is what
/// remains, so the lane is eaten counter-clockwise as the metric is consumed.
public enum RingGeometry {
    /// Filled fraction for a usage lane, 0…1.
    /// 0% utilization → 1.0 (full); 100% → 0.0 (empty). A nil window is treated as full.
    public static func filledFraction(utilization: Double?) -> Double {
        guard let utilization else { return 1 }
        return max(0, min(1, 1 - utilization / 100))
    }

    /// Filled fraction for a time-left lane, 0…1.
    /// A full window remaining → 1.0; at/after reset → 0.0. A nil reset is treated as full.
    public static func timeRemainingFraction(resetsAt: Date?, now: Date, windowSeconds: Double) -> Double {
        guard let resetsAt, windowSeconds > 0 else { return 1 }
        return max(0, min(1, resetsAt.timeIntervalSince(now) / windowSeconds))
    }
}
