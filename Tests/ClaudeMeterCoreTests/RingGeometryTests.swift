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
}
