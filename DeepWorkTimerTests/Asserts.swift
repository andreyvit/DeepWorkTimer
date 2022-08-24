import Foundation
import XCTest

func XCTAssertIn<T: Comparable>(_ value: T, _ range: ClosedRange<T>, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertGreaterThanOrEqual(value, range.lowerBound, message(), file: file, line: line)
    XCTAssertLessThanOrEqual(value, range.upperBound, message(), file: file, line: line)
}
func XCTAssertIn<T: Comparable>(_ value: T, _ range: Range<T>, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertGreaterThanOrEqual(value, range.lowerBound, message(), file: file, line: line)
    XCTAssertLessThan(value, range.upperBound, message(), file: file, line: line)
}
