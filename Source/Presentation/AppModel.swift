import Foundation
import Cocoa
import SwiftUI
import UserNotifications
import os.log

class AppModel: ObservableObject {
    private var now: Date = .distantPast
    private(set) var state: AppState
    
    private lazy var stretching = StretchingController(appModel: self)
    private lazy var interruption = InterruptionController(appModel: self)

    let preferences: Preferences
    
    static func testing() -> AppModel { .init(preferences: .initial) }
    
    init(preferences: Preferences) {
        self.preferences = preferences
        let memento = AppModel.loadMemento() ?? AppMemento()
        state = AppState(memento: memento, preferences: preferences, now: .now)
        mutate {}
    }
    
    func start(configuration: IntervalConfiguration, mode: IntervalStartMode) {
        mutate {
            state.start(configuration: configuration, mode: mode, now: .now)
        }
    }
    
    func stop() {
        mutate {
            state.stop(now: Date.now)
        }
    }
    
    func adjust(by delta: TimeInterval) {
        mutate {
            state.adjustDuration(by: delta, now: .now)
        }
    }

    deinit {
        setUpdateTimerFrequency(nil)
        save()
    }

    
    // MARK: - Update Timer
    
    private enum TimerFrequency: Equatable, CustomStringConvertible {
        case frequent
        case idle
        
        public var description: String {
            switch self {
            case .frequent: return "FREQUENT"
            case .idle: return "IDLE"
            }
        }
    }
    
    private var updateTimer: Timer?
    private var updateTimerFrequency: TimerFrequency?

    private var idleTimerInterval: TimeInterval { preferences.idleThreshold / 4 }

    private func reconsiderUpdateTimer() {
        setUpdateTimerFrequency(state.isFrequentUpdatingDesired ? .frequent : .idle)
    }
    private func setUpdateTimerFrequency(_ newFrequency: TimerFrequency?) {
        guard newFrequency != updateTimerFrequency else { return }
        updateTimerFrequency = newFrequency
        updateTimer?.invalidate()
        if let desiredFrequency = newFrequency {
            let interval, tolerance: TimeInterval
            switch desiredFrequency {
            case .frequent:
                (interval, tolerance) = (0.25, 0.1)
            case .idle:
                interval = idleTimerInterval
                tolerance = interval / 4
            }
            
            updateTimer = Timer(timeInterval: interval, target: self, selector: #selector(update), userInfo: nil, repeats: true)
            updateTimer!.tolerance = tolerance
            RunLoop.main.add(updateTimer!, forMode: .common)
            timerLog.debug("timer now in \(desiredFrequency.description, privacy: .public) mode (interval \(interval)s ± \(tolerance)s)")
        } else {
            updateTimer = nil
            timerLog.debug("timer now OFF")
        }
    }

    
    // MARK: - Updates

    private var lastIdleUpdate: Date = .distantPast
    private var idleUpdateInterval: TimeInterval { idleTimerInterval - 2 /* ensure updates when timer fires at idleTimerInterval */ }

    private func mutate(_ block: () -> Void) {
        objectWillChange.send()
        now = Date.now
        if now.timeIntervalSince(lastIdleUpdate) >= idleUpdateInterval {
            let idleDuration = computeIdleTime()
            state.setIdleDuration(idleDuration, now: now)
        }
        block()
        state.update(now: now)
        save()
        reconsiderUpdateTimer()
        if let configuration = state.popIntervalCompletionNotification() {
            signalIntervalCompletion(configuration: configuration)
        }
        if state.popMissingTimerWarning() {
            let content = UNMutableNotificationContent()
            content.title = "Want to start a timer?"
            content.interruptionLevel = .timeSensitive
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
        stretching.setVisible(state.isStretching)
        interruption.setVisible(state.isInterrupted)
        if state.popAppActivation(now: now) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc public func update() {
        mutate {}
    }

    private func signalIntervalCompletion(configuration: IntervalConfiguration) {
        let content = UNMutableNotificationContent()

        if configuration.kind.isRest {
            content.title = "Finished: \(configuration.duration.mediumString) of \(configuration.kind.localizedDescription)"
            content.subtitle = preferences.backToWorkMessages.randomElement()!
        } else {
            content.title = "Done: \(configuration.duration.mediumString) of \(configuration.kind.localizedDescription)"
            content.subtitle = preferences.timeToRestMessages.randomElement()!
        }

        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        if configuration.kind == .rest {
            NSSound(named: .purr)!.play()
        } else {
            NSSound(named: .hero)!.play()
        }
    }

    private static func loadMemento() -> AppMemento? {
        if isRunningTests {
            return nil
        }
        if let string = UserDefaults.standard.string(forKey: "state") {
            do {
                return try JSONDecoder().decode(AppMemento.self, from: string.data(using: .utf8)!)
            } catch {
                NSLog("%@", "ERROR: failed to decode memento: \(String(describing: error))")
            }
        }
        return nil
    }
    
    private func save() {
        if isRunningTests {
            return
        }
        let string = String(data: try! JSONEncoder().encode(state.memento), encoding: .utf8)!
        UserDefaults.standard.set(string, forKey: "state")
    }

    
    // MARK: - Stretching
    
    func startStretching() {
        guard !state.isStretching else { return }
        mutate {
            state.startStretching(now: now)
        }
    }
    func endStretching() {
        guard state.isStretching else { return }
        mutate {
            state.endStretching(now: now)
        }
    }
    func extendStretching() {
        guard state.isStretching else { return }
        mutate {
            state.extendStretching(now: now)
        }
    }

    
    // MARK: - Interruptions

    func startInterruption(reason: InterruptionStartReason) {
        mutate {
            state.startInterruption(reason: reason, now: now)
        }
    }
    func endInterruption(action: InterruptionEndAction) {
        mutate {
            state.endInterruption(action: action, now: now)
        }
    }

    
    // MARK: - Options
    
    func setTotalMutingMode(_ newMode: MutingMode?) {
        mutate {
            state.setTotalMutingMode(newMode, now: now)
        }
    }

    func toggleDisableStretching() {
        mutate {
            if state.stretchMuting != nil {
                state.setStretchingMutingMode(nil, now: now)
            } else {
                state.setStretchingMutingMode(.forever, now: now)
            }
        }
    }

}
