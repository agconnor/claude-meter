import Foundation

/// Pure presentation helpers shared by the UI and exercised directly by tests.
public enum Formatting {

    public enum Level: Equatable { case normal, warning, critical }

    /// Color band for a utilization percentage.
    public static func level(for utilization: Double) -> Level {
        switch utilization {
        case ..<60: return .normal
        case ..<85: return .warning
        default: return .critical
        }
    }

    /// "11%" — rounds to the nearest whole percent, clamped to 0…100+.
    public static func percent(_ utilization: Double) -> String {
        "\(Int(utilization.rounded()))%"
    }

    /// Compact menu-bar title, e.g. "11% · 5%" (session · week). Missing windows render "–".
    public static func menuBarTitle(session: UsageWindow?, week: UsageWindow?) -> String {
        let s = session.map { percent($0.utilization) } ?? "–"
        let w = week.map { percent($0.utilization) } ?? "–"
        return "\(s) · \(w)"
    }

    /// Highest utilization across the windows, used to pick the menu-bar tint.
    public static func peakLevel(_ usage: Usage) -> Level {
        let utils = [usage.session, usage.week, usage.weekOpus, usage.weekSonnet]
            .compactMap { $0?.utilization }
        return level(for: utils.max() ?? 0)
    }

    /// A unicode block gauge, e.g. "███▏······" for the given width.
    public static func gauge(_ utilization: Double, width: Int = 10) -> String {
        guard width > 0 else { return "" }
        let clamped = max(0, min(100, utilization))
        let filled = Int((clamped / 100 * Double(width)).rounded())
        return String(repeating: "█", count: filled) + String(repeating: "·", count: width - filled)
    }

    /// Human "resets in" string relative to `now`: "now", "14m", "2h 14m", "1d 3h".
    public static func resetsIn(_ resetsAt: Date?, now: Date = Date()) -> String? {
        guard let resetsAt else { return nil }
        let secs = Int(resetsAt.timeIntervalSince(now))
        if secs <= 0 { return "now" }
        let d = secs / 86400
        let h = (secs % 86400) / 3600
        let m = (secs % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    /// "12s ago", "3m ago", "1h ago".
    public static func relativeAge(_ date: Date, now: Date = Date()) -> String {
        let secs = max(0, Int(now.timeIntervalSince(date)))
        if secs < 60 { return "\(secs)s ago" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        return "\(secs / 3600)h ago"
    }
}
