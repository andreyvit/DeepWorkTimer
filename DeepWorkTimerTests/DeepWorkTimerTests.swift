import XCTest
@testable import Deep_Work_Timer

class DeepWorkTimerTests: XCTestCase {
    
    var clock: Date = startOfModernEra
    var state: AppState = .init(memento: AppMemento(), preferences: .initial, now: startOfModernEra)
    var idleStart: Date?

    override func setUpWithError() throws {
        advance(0)
    }

    override func tearDownWithError() throws {
    }
    
    func testStatusTextDuringInterval() {
        XCTAssertNil(state.running)
        XCTAssertEqual(state.testStatusText, "")

        start(.deep50)
        XCTAssertEqual(state.running?.remaining, .minutes(50))
        XCTAssertEqual(state.testStatusText, "50:00 D")

        advance(.minutes(30))
        XCTAssertEqual(state.running?.remaining, .minutes(20))
        XCTAssertEqual(state.testStatusText, "20:00 D")

        advance(.minutes(19) + .seconds(50))
        XCTAssertEqual(state.testStatusText, "0:10 D")
        XCTAssertNil(state.pendingIntervalCompletionNotification)

        advance(.seconds(10))
        XCTAssertEqual(state.testStatusText, "BREAK")
        advance(.seconds(59))
        XCTAssertEqual(state.testStatusText, "BREAK")
        advance(.seconds(1))
        XCTAssertEqual(state.testStatusText, "1m?")

        advance(.minutes(9))
        XCTAssertEqual(state.running?.remaining, .minutes(-10))
        XCTAssertEqual(state.testStatusText, "10m?")
        
        stop()
        XCTAssertNil(state.running)
        XCTAssertEqual(state.testStatusText, "")

        advance(.minutes(2))
        XCTAssertEqual(state.testStatusText, "2m?")
    }

    func testIntervalCompletionNotification() {
        start(.deep50)
        advance(.minutes(49))
        XCTAssertNil(state.pendingIntervalCompletionNotification)

        advance(.minute)
        XCTAssertEqual(state.popIntervalCompletionNotification(), .deep50)

        advance(1)
        XCTAssertNil(state.popIntervalCompletionNotification())
        advance(state.preferences.finishedTimerReminderInterval - 1)
        XCTAssertEqual(state.popIntervalCompletionNotification(), .deep50) // reminder 1

        advance(1)
        XCTAssertNil(state.popIntervalCompletionNotification())
        advance(state.preferences.finishedTimerReminderInterval - 1)
        XCTAssertEqual(state.popIntervalCompletionNotification(), .deep50) // reminder 2
    }

    func testStretching() throws {
        XCTAssertEqual(state.timeTillNextStretch, .minutes(20))
        XCTAssertNil(state.stretchingRemainingTime)

        advance(.minutes(5))
        XCTAssertEqual(state.timeTillNextStretch, .minutes(15))
        XCTAssertNil(state.stretchingRemainingTime)

        state.startStretching(now: clock)
        XCTAssertEqual(state.timeTillNextStretch, .minutes(15))
        XCTAssertEqual(state.stretchingRemainingTime, .seconds(60))

        advance(.seconds(10))
        XCTAssertEqual(state.timeTillNextStretch, .minutes(20) + .seconds(50))
        XCTAssertEqual(state.stretchingRemainingTime, .seconds(50))

        advance(.seconds(50))
        XCTAssertEqual(state.timeTillNextStretch, .minutes(20))
        XCTAssertEqual(state.stretchingRemainingTime, 0)

        state.endStretching(now: clock)
        XCTAssertEqual(state.timeTillNextStretch, .minutes(20))
        XCTAssertNil(state.stretchingRemainingTime)
    }

    func testLongBreakCancelsInterval() {
        start(.deep50)
        advance(.hours(8))
        XCTAssertNil(state.running)
    }

    func testUntimedBehavior() {
        XCTAssertFalse(state.popMissingTimerWarning())
        XCTAssertEqual(state.testStatusText, "")

        advance(.minutes(1))
        XCTAssertFalse(state.popMissingTimerWarning())
        XCTAssertEqual(state.testStatusText, "")

        advance(.minutes(1))
        XCTAssertTrue(state.popMissingTimerWarning())
        XCTAssertEqual(state.testStatusText, "2m?")

        advance(.minutes(5))
        XCTAssertTrue(state.popMissingTimerWarning())
        XCTAssertEqual(state.testStatusText, "7m?")
        
        start(.deep50)
        stop()
        XCTAssertEqual(state.testStatusText, "")

        advance(.minutes(5))
        XCTAssertEqual(state.testStatusText, "5m?")
}

    func testMutingSilencesStretching() {
        mute(.forever)
        advance(.minutes(10))
        XCTAssertNil(state.stretchingRemainingTime)
    }

    func testMutingSilencesStartNotifications() {
        mute(.forever)
        advance(.minutes(10))
        XCTAssertNil(state.stretchingRemainingTime)
    }

    private func advance(_ interval: TimeInterval) {
        clock += interval
        if let idleStart = idleStart {
            state.setIdleDuration(clock.timeIntervalSince(idleStart), now: clock)
        } else {
            state.setIdleDuration(1, now: clock)
        }
        state.update(now: clock)
    }
    
    private func start(_ configuration: IntervalConfiguration) {
        state.start(configuration: configuration, mode: .restart, now: clock)
        state.update(now: clock)
    }
    private func stop() {
        state.stop(now: clock)
        state.update(now: clock)
    }

    private func idle() {
        precondition(idleStart == nil)
        idleStart = clock
        advance(0)
    }
    
    private func noLongerIdle() {
        precondition(idleStart != nil)
        idleStart = nil
        advance(0)
    }

    private func mute(_ mode: MutingMode?) {
        state.setTotalMutingMode(mode, now: clock)
    }

    private func makeState(_ memento: AppMemento = .init()) -> AppState {
        var state = AppState(memento: memento, preferences: .initial, now: clock)
        state.update(now: clock)
        return state
    }

}

extension IntervalConfiguration {
    static var deep50 = IntervalConfiguration(kind: .work(.deep), duration: .minutes(50))
}
