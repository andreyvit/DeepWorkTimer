import XCTest
@testable import Deep_Work_Timer

class DeepWorkTimerTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testExample() throws {
        var clock = startOfModernEra
        let state = AppState(memento: AppMemento(), preferences: .initial, now: clock)
        XCTAssertIn(state.timeTillNextStretch, .minutes(15) ... .minutes(25))

        clock += .hour
    }

}

func XCTAssertIn<T: Comparable>(_ value: T, _ range: ClosedRange<T>, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertGreaterThanOrEqual(value, range.lowerBound, message(), file: file, line: line)
    XCTAssertLessThanOrEqual(value, range.upperBound, message(), file: file, line: line)
}
func XCTAssertIn<T: Comparable>(_ value: T, _ range: Range<T>, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertGreaterThanOrEqual(value, range.lowerBound, message(), file: file, line: line)
    XCTAssertLessThan(value, range.upperBound, message(), file: file, line: line)
}
