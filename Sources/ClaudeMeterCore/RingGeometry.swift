import Foundation

/// Pure geometry for the concentric-donut menu-bar icon. Drawing lives in the app
/// target; this is the testable part.
public enum RingGeometry {
    /// The *filled* (remaining) fraction of a ring, 0…1.
    /// 0% utilization → 1.0 (ring fully filled); 100% → 0.0 (ring empty).
    /// A nil/absent window is treated as fully filled.
    public static func filledFraction(utilization: Double?) -> Double {
        guard let utilization else { return 1 }
        return max(0, min(1, 1 - utilization / 100))
    }
}
