import XCTest
@testable import ClaudeMeterCore

final class FormattingTests: XCTestCase {

    private func win(_ u: Double, resets: Date? = nil) -> UsageWindow {
        UsageWindow(utilization: u, resetsAt: resets)
    }

    // MARK: - percent

    func testPercentRounds() {
        XCTAssertEqual(Formatting.percent(11.0), "11%")
        XCTAssertEqual(Formatting.percent(5.4), "5%")
        XCTAssertEqual(Formatting.percent(5.5), "6%")
        XCTAssertEqual(Formatting.percent(0), "0%")
        XCTAssertEqual(Formatting.percent(100), "100%")
    }

    // MARK: - level / peakLevel

    func testLevelThresholds() {
        XCTAssertEqual(Formatting.level(for: 0), .normal)
        XCTAssertEqual(Formatting.level(for: 59.9), .normal)
        XCTAssertEqual(Formatting.level(for: 60), .warning)
        XCTAssertEqual(Formatting.level(for: 84.9), .warning)
        XCTAssertEqual(Formatting.level(for: 85), .critical)
        XCTAssertEqual(Formatting.level(for: 100), .critical)
    }

    func testPeakLevelUsesHighestWindow() {
        let usage = Usage(session: win(10), week: win(70), weekOpus: nil,
                          weekSonnet: win(5), extra: nil, fetchedAt: Date())
        XCTAssertEqual(Formatting.peakLevel(usage), .warning)   // 70 dominates
    }

    func testPeakLevelAllNilIsNormal() {
        let usage = Usage(session: nil, week: nil, weekOpus: nil, weekSonnet: nil,
                          extra: nil, fetchedAt: Date())
        XCTAssertEqual(Formatting.peakLevel(usage), .normal)
    }

    // MARK: - menuBarTitle

    func testMenuBarTitleBothPresent() {
        XCTAssertEqual(Formatting.menuBarTitle(session: win(11), week: win(5)), "11% · 5%")
    }

    func testMenuBarTitleMissingWindows() {
        XCTAssertEqual(Formatting.menuBarTitle(session: nil, week: win(5)), "– · 5%")
        XCTAssertEqual(Formatting.menuBarTitle(session: win(11), week: nil), "11% · –")
        XCTAssertEqual(Formatting.menuBarTitle(session: nil, week: nil), "– · –")
    }

    // MARK: - gauge

    func testGaugeFillProportion() {
        XCTAssertEqual(Formatting.gauge(0, width: 10), "··········")
        XCTAssertEqual(Formatting.gauge(100, width: 10), "██████████")
        XCTAssertEqual(Formatting.gauge(50, width: 10), "█████·····")
        XCTAssertEqual(Formatting.gauge(11, width: 10), "█·········")  // rounds to 1
    }

    func testGaugeClampsAndGuardsWidth() {
        XCTAssertEqual(Formatting.gauge(150, width: 4), "████")   // clamped to 100%
        XCTAssertEqual(Formatting.gauge(-5, width: 4), "····")    // clamped to 0%
        XCTAssertEqual(Formatting.gauge(50, width: 0), "")        // no width
    }

    // MARK: - resetsIn

    func testResetsInRanges() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(Formatting.resetsIn(now.addingTimeInterval(30 * 60), now: now), "30m")
        XCTAssertEqual(Formatting.resetsIn(now.addingTimeInterval(2 * 3600 + 14 * 60), now: now), "2h 14m")
        XCTAssertEqual(Formatting.resetsIn(now.addingTimeInterval(86400 + 3 * 3600), now: now), "1d 3h")
    }

    func testResetsInPastIsNow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(Formatting.resetsIn(now.addingTimeInterval(-60), now: now), "now")
        XCTAssertEqual(Formatting.resetsIn(now, now: now), "now")
    }

    func testResetsInNilIsNil() {
        XCTAssertNil(Formatting.resetsIn(nil))
    }

    // MARK: - relativeAge

    func testRelativeAge() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(Formatting.relativeAge(now.addingTimeInterval(-12), now: now), "12s ago")
        XCTAssertEqual(Formatting.relativeAge(now.addingTimeInterval(-180), now: now), "3m ago")
        XCTAssertEqual(Formatting.relativeAge(now.addingTimeInterval(-7200), now: now), "2h ago")
        XCTAssertEqual(Formatting.relativeAge(now.addingTimeInterval(5), now: now), "0s ago") // future clamps
    }
}
