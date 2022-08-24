import XCTest
@testable import Deep_Work_Timer

class DeepWorkTimerTests: XCTestCase {
    
    var clock: Date = startOfModernEra
    var state: AppState = .init(memento: AppMemento(), preferences: .initial, now: startOfModernEra)

    override func setUpWithError() throws {
        state.update(now: clock)
    }

    override func tearDownWithError() throws {
    }

    func testStretching() throws {
        XCTAssertEqual(state.timeTillNextStretch, .minutes(20))
        XCTAssertNil(state.stretchingRemainingTime)

        advance(.minutes(5))
        XCTAssertEqual(state.timeTillNextStretch, .minutes(15))
        XCTAssertNil(state.stretchingRemainingTime)

        state.startStretching(now: clock)
        XCTAssertEqual(state.timeTillNextStretch, .minutes(15))
        XCTAssertEqual(state.stretchingRemainingTime, .seconds(30))

        advance(.seconds(10))
        XCTAssertEqual(state.timeTillNextStretch, .minutes(20) + .seconds(20))
        XCTAssertEqual(state.stretchingRemainingTime, .seconds(20))

        advance(.seconds(20))
        XCTAssertEqual(state.timeTillNextStretch, .minutes(20))
        XCTAssertEqual(state.stretchingRemainingTime, 0)

        state.endStretching(now: clock)
        XCTAssertEqual(state.timeTillNextStretch, .minutes(20))
        XCTAssertNil(state.stretchingRemainingTime)
    }
    
    func testBar() {
        print(clock)
        clock += .hour
    }
    
    private func advance(_ interval: TimeInterval) {
        clock += interval
        state.update(now: clock)
    }
    
    private func makeState(_ memento: AppMemento = .init()) -> AppState {
        var state = AppState(memento: memento, preferences: .initial, now: clock)
        state.update(now: clock)
        return state
    }

}
