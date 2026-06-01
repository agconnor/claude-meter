import XCTest
@testable import ClaudeMeterCore

final class RingGeometryTests: XCTestCase {
    func testFullWhenUnused() {
        XCTAssertEqual(RingGeometry.filledFraction(utilization: 0), 1.0)
    }

    func testEmptyWhenMaxed() {
        XCTAssertEqual(RingGeometry.filledFraction(utilization: 100), 0.0)
    }

    func testHalf() {
        XCTAssertEqual(RingGeometry.filledFraction(utilization: 50), 0.5, accuracy: 1e-9)
    }

    func testClampsBeyondRange() {
        XCTAssertEqual(RingGeometry.filledFraction(utilization: 130), 0.0)  // over 100%
        XCTAssertEqual(RingGeometry.filledFraction(utilization: -10), 1.0)  // negative
    }

    func testNilIsFull() {
        XCTAssertEqual(RingGeometry.filledFraction(utilization: nil), 1.0)
    }

    // MARK: - timeRemainingFraction

    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testTimeFullWindowRemaining() {
        let resets = now.addingTimeInterval(WindowLength.session)
        XCTAssertEqual(RingGeometry.timeRemainingFraction(
            resetsAt: resets, now: now, windowSeconds: WindowLength.session), 1.0, accuracy: 1e-9)
    }

    func testTimeHalfRemaining() {
        let resets = now.addingTimeInterval(WindowLength.week / 2)
        XCTAssertEqual(RingGeometry.timeRemainingFraction(
            resetsAt: resets, now: now, windowSeconds: WindowLength.week), 0.5, accuracy: 1e-9)
    }

    func testTimePastResetIsEmpty() {
        let resets = now.addingTimeInterval(-60)
        XCTAssertEqual(RingGeometry.timeRemainingFraction(
            resetsAt: resets, now: now, windowSeconds: WindowLength.session), 0.0)
    }

    func testTimeClampsAboveWindow() {
        let resets = now.addingTimeInterval(WindowLength.session * 2)   // shouldn't happen, but clamp
        XCTAssertEqual(RingGeometry.timeRemainingFraction(
            resetsAt: resets, now: now, windowSeconds: WindowLength.session), 1.0)
    }

    func testTimeNilResetIsFull() {
        XCTAssertEqual(RingGeometry.timeRemainingFraction(
            resetsAt: nil, now: now, windowSeconds: WindowLength.session), 1.0)
    }
}
