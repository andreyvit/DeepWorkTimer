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
        XCTAssertNil(state.stretchingRemainingTime)
    }
    
    func testIdlenessResetsStretching() throws {
        advance(.minutes(5))
        XCTAssertEqual(state.timeTillNextStretch, .minutes(15))
        
        idle()
        advance(.minutes(5))
        XCTAssertEqual(state.timeTillNextStretch, .minutes(20))
        advance(.minutes(20))
        XCTAssertEqual(state.timeTillNextStretch, .minutes(20))
        
        noLongerIdle()
        XCTAssertEqual(state.timeTillNextStretch, .minutes(20))
        advance(.minutes(5))
        XCTAssertEqual(state.timeTillNextStretch, .minutes(15))
    }
    
    func testIdlenessDoesNotInterferWithStretchingInProgress() throws {
        state.startStretching(now: clock)
        state.extendStretching(now: clock)
        state.extendStretching(now: clock)
        state.extendStretching(now: clock)
        state.extendStretching(now: clock)
        state.extendStretching(now: clock)
        XCTAssertEqual(state.stretchingRemainingTime, .minutes(6))

        idle()
        advance(.minutes(5))
        XCTAssertEqual(state.stretchingRemainingTime, .minutes(1))
        XCTAssertEqual(state.timeTillNextStretch, .minutes(21))
    }
    
    func testStretchingDelayedAtEndOfInterval() throws {
        start(.deep50)
        
        // finish stretching by 25m, so that next interval would be at 45m
        advance(.minutes(24))
        state.startStretching(now: clock)
        advance(.minutes(1))
        XCTAssertFalse(state.isStretching)

        // 45m mark is too close to 50m, so we give an extra 8m extension
        XCTAssertEqual(state.timeTillNextStretch, .minutes(28))

        advance(.minutes(24))
        XCTAssertEqual(state.timeTillNextStretch, .minutes(4))
        advance(.minute)
        XCTAssertEqual(state.timeTillNextStretch, .minutes(3))
        // interval ended, but we keep working...
        advance(.minutes(2))
        XCTAssertEqual(state.timeTillNextStretch, .minutes(1))
        // ...until we blow past the 8-minute extension, which triggers stretching immediately
        advance(.minute)
        XCTAssertEqual(state.timeTillNextStretch, 0)
        XCTAssertTrue(state.isStretching)
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
