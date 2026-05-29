import Foundation

/// One rate-limit window (the 5-hour session or a 7-day weekly bucket).
public struct UsageWindow: Equatable {
    public let utilization: Double      // percent, 0…100
    public let resetsAt: Date?
    public init(utilization: Double, resetsAt: Date?) {
        self.utilization = utilization
        self.resetsAt = resetsAt
    }
}

/// Pay-as-you-go ("extra usage") credit state.
public struct ExtraUsage: Equatable {
    public let isEnabled: Bool
    public let utilization: Double?
    public let usedCredits: Double?
    public let monthlyLimit: Double?
    public let currency: String?
    public init(isEnabled: Bool, utilization: Double?, usedCredits: Double?,
                monthlyLimit: Double?, currency: String?) {
        self.isEnabled = isEnabled
        self.utilization = utilization
        self.usedCredits = usedCredits
        self.monthlyLimit = monthlyLimit
        self.currency = currency
    }
}

/// A full snapshot of GET /api/oauth/usage (the data behind Claude Code's /usage).
public struct Usage: Equatable {
    public let session: UsageWindow?     // five_hour
    public let week: UsageWindow?        // seven_day
    public let weekOpus: UsageWindow?    // seven_day_opus
    public let weekSonnet: UsageWindow?  // seven_day_sonnet
    public let extra: ExtraUsage?
    public let fetchedAt: Date
    public init(session: UsageWindow?, week: UsageWindow?, weekOpus: UsageWindow?,
                weekSonnet: UsageWindow?, extra: ExtraUsage?, fetchedAt: Date) {
        self.session = session
        self.week = week
        self.weekOpus = weekOpus
        self.weekSonnet = weekSonnet
        self.extra = extra
        self.fetchedAt = fetchedAt
    }
}

/// OAuth credential blob stored by Claude Code in the login keychain.
public struct Credentials: Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Double   // Unix epoch, milliseconds
    public init(accessToken: String, refreshToken: String, expiresAt: Double) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}

public enum UsageError: Error, Equatable, CustomStringConvertible {
    case noCredentials
    case http(Int)
    case network(String)
    case decode

    public var description: String {
        switch self {
        case .noCredentials: return "Not signed in to Claude Code"
        case .http(let c) where c == 401 || c == 403: return "Auth expired — open Claude Code"
        case .http(let c): return "Server error (\(c))"
        case .network(let m): return m
        case .decode: return "Unexpected response"
        }
    }
}
