import Foundation

/// Pure parsing of the JSON shapes we care about. No I/O — takes bytes/strings,
/// returns models. This is the bulk of what the unit tests exercise.
public enum UsageParser {

    /// Parse the keychain credential blob: {"claudeAiOauth":{accessToken,refreshToken,expiresAt}}
    public static func parseCredentials(_ raw: String) -> Credentials? {
        guard let data = raw.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let access = oauth["accessToken"] as? String else { return nil }
        let refresh = oauth["refreshToken"] as? String ?? ""
        let expires = (oauth["expiresAt"] as? Double) ?? 0
        return Credentials(accessToken: access, refreshToken: refresh, expiresAt: expires)
    }

    /// Parse GET /api/oauth/usage.
    public static func parseUsage(_ data: Data, now: Date = Date()) -> Usage? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }

        func window(_ key: String) -> UsageWindow? {
            guard let w = root[key] as? [String: Any], let util = w["utilization"] as? Double else { return nil }
            let resets = (w["resets_at"] as? String).flatMap(parseDate)
            return UsageWindow(utilization: util, resetsAt: resets)
        }

        var extra: ExtraUsage?
        if let e = root["extra_usage"] as? [String: Any] {
            extra = ExtraUsage(
                isEnabled: (e["is_enabled"] as? Bool) ?? false,
                utilization: e["utilization"] as? Double,
                usedCredits: e["used_credits"] as? Double,
                monthlyLimit: e["monthly_limit"] as? Double,
                currency: e["currency"] as? String
            )
        }

        return Usage(
            session: window("five_hour"),
            week: window("seven_day"),
            weekOpus: window("seven_day_opus"),
            weekSonnet: window("seven_day_sonnet"),
            extra: extra,
            fetchedAt: now
        )
    }

    /// Parse timestamps like "2026-05-29T23:00:00.420246+00:00" (microsecond fraction + offset)
    /// as well as the plain no-fraction form.
    public static func parseDate(_ s: String) -> Date? {
        isoFractional.date(from: s) ?? isoPlain.date(from: s)
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
