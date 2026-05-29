import XCTest
@testable import ClaudeMeterCore

final class UsageParserTests: XCTestCase {

    // MARK: - Credentials

    func testParseCredentialsFull() {
        let raw = #"{"claudeAiOauth":{"accessToken":"acc","refreshToken":"ref","expiresAt":1780106451577,"scopes":["a"],"subscriptionType":"max"}}"#
        let c = UsageParser.parseCredentials(raw)
        XCTAssertEqual(c, Credentials(accessToken: "acc", refreshToken: "ref", expiresAt: 1780106451577))
    }

    func testParseCredentialsMissingOptionalFields() {
        let raw = #"{"claudeAiOauth":{"accessToken":"acc"}}"#
        let c = UsageParser.parseCredentials(raw)
        XCTAssertEqual(c, Credentials(accessToken: "acc", refreshToken: "", expiresAt: 0))
    }

    func testParseCredentialsRejectsMissingAccessToken() {
        XCTAssertNil(UsageParser.parseCredentials(#"{"claudeAiOauth":{"refreshToken":"ref"}}"#))
    }

    func testParseCredentialsRejectsGarbage() {
        XCTAssertNil(UsageParser.parseCredentials("not json"))
        XCTAssertNil(UsageParser.parseCredentials("{}"))
        XCTAssertNil(UsageParser.parseCredentials(#"{"claudeAiOauth":42}"#))
    }

    // MARK: - Credential blob rewrite

    func testUpdatedCredentialBlobPreservesOtherFields() throws {
        let raw = #"{"claudeAiOauth":{"accessToken":"old","refreshToken":"oldR","expiresAt":1,"scopes":["x","y"],"subscriptionType":"max","rateLimitTier":"t"}}"#
        let updated = try XCTUnwrap(
            UsageParser.updatedCredentialBlob(raw, accessToken: "new", refreshToken: "newR", expiresAt: 999))

        // The token fields are updated...
        let c = try XCTUnwrap(UsageParser.parseCredentials(updated))
        XCTAssertEqual(c, Credentials(accessToken: "new", refreshToken: "newR", expiresAt: 999))

        // ...and the unrelated fields survive untouched.
        let data = try XCTUnwrap(updated.data(using: .utf8))
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let oauth = try XCTUnwrap(root["claudeAiOauth"] as? [String: Any])
        XCTAssertEqual(oauth["subscriptionType"] as? String, "max")
        XCTAssertEqual(oauth["rateLimitTier"] as? String, "t")
        XCTAssertEqual(oauth["scopes"] as? [String], ["x", "y"])
    }

    func testUpdatedCredentialBlobRejectsGarbage() {
        XCTAssertNil(UsageParser.updatedCredentialBlob("nope", accessToken: "a", refreshToken: "b", expiresAt: 1))
    }

    // MARK: - Usage payload

    /// The exact shape returned by the live endpoint.
    private let liveSample = """
    {
      "five_hour": {"utilization": 11.0, "resets_at": "2026-05-29T23:00:00.420246+00:00"},
      "seven_day": {"utilization": 5.0, "resets_at": "2026-05-30T13:00:00.420270+00:00"},
      "seven_day_oauth_apps": null,
      "seven_day_opus": null,
      "seven_day_sonnet": {"utilization": 1.0, "resets_at": "2026-05-30T13:00:00.420280+00:00"},
      "extra_usage": {"is_enabled": false, "monthly_limit": null, "used_credits": null,
                      "utilization": null, "currency": null, "disabled_reason": null}
    }
    """

    func testParseUsageLiveSample() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let usage = try XCTUnwrap(UsageParser.parseUsage(Data(liveSample.utf8), now: now))

        XCTAssertEqual(usage.session?.utilization, 11.0)
        XCTAssertEqual(usage.week?.utilization, 5.0)
        XCTAssertNil(usage.weekOpus)                 // null in payload
        XCTAssertEqual(usage.weekSonnet?.utilization, 1.0)
        XCTAssertEqual(usage.fetchedAt, now)

        XCTAssertEqual(usage.extra?.isEnabled, false)
        XCTAssertNil(usage.extra?.utilization)

        // resets_at is parsed into a real Date.
        XCTAssertEqual(usage.session?.resetsAt,
                       UsageParser.parseDate("2026-05-29T23:00:00.420246+00:00"))
    }

    func testParseUsageWithEnabledExtraUsage() throws {
        let json = """
        {"five_hour":{"utilization":90.0,"resets_at":"2026-05-29T23:00:00Z"},
         "extra_usage":{"is_enabled":true,"utilization":42.5,"used_credits":12.0,
                        "monthly_limit":50.0,"currency":"USD"}}
        """
        let usage = try XCTUnwrap(UsageParser.parseUsage(Data(json.utf8)))
        let extra = try XCTUnwrap(usage.extra)
        XCTAssertTrue(extra.isEnabled)
        XCTAssertEqual(extra.utilization, 42.5)
        XCTAssertEqual(extra.usedCredits, 12.0)
        XCTAssertEqual(extra.monthlyLimit, 50.0)
        XCTAssertEqual(extra.currency, "USD")
        XCTAssertNil(usage.week)   // absent window stays nil
    }

    func testParseUsageMissingResetsAt() throws {
        let usage = try XCTUnwrap(UsageParser.parseUsage(Data(#"{"five_hour":{"utilization":3.0}}"#.utf8)))
        XCTAssertEqual(usage.session?.utilization, 3.0)
        XCTAssertNil(usage.session?.resetsAt)
    }

    func testParseUsageRejectsGarbage() {
        XCTAssertNil(UsageParser.parseUsage(Data("not json".utf8)))
        XCTAssertNil(UsageParser.parseUsage(Data("[]".utf8)))
    }

    func testParseUsageEmptyObjectYieldsAllNil() throws {
        let usage = try XCTUnwrap(UsageParser.parseUsage(Data("{}".utf8)))
        XCTAssertNil(usage.session)
        XCTAssertNil(usage.week)
        XCTAssertNil(usage.extra)
    }

    // MARK: - Date parsing

    func testParseDateWithMicrosecondsAndOffset() {
        let d = UsageParser.parseDate("2026-05-29T23:00:00.420246+00:00")
        XCTAssertNotNil(d)
        // 2026-05-29T23:00:00Z is a fixed epoch; fractional micros round to ~.420s.
        XCTAssertEqual(d!.timeIntervalSince1970, 1780095600.420, accuracy: 0.01)
    }

    func testParseDatePlainNoFraction() throws {
        let d = try XCTUnwrap(UsageParser.parseDate("2026-05-29T23:00:00Z"))
        XCTAssertEqual(d.timeIntervalSince1970, 1780095600, accuracy: 0.01)
    }

    func testParseDateRejectsJunk() {
        XCTAssertNil(UsageParser.parseDate("yesterday"))
        XCTAssertNil(UsageParser.parseDate(""))
    }
}
