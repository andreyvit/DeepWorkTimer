import Foundation
import Cocoa
import SwiftUI
import UserNotifications
import os.log

class AppModel: ObservableObject {
    private var now: Date = .distantPast
    private(set) var state: AppState

    let preferences: Preferences
    
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
        updateStretchingState()
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
    
    private var stretchingWindow: NSWindow?

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
    
    private func updateStretchingState() {
        let isVisible = (stretchingWindow != nil)
        if !isVisible && state.isStretching {
            showStretchingWindow()
        } else if isVisible && !state.isStretching {
            hideStretchingWindow()
        }
    }

    private func showStretchingWindow() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.level = .statusBar
        window.titlebarAppearsTransparent = true
        window.title = NSLocalizedString("Still want to be healthy?", comment: "Stretching window title")
        window.center()
        window.isReleasedWhenClosed = false
        self.stretchingWindow = window

        let stretchingIdeas = preferences.randomStretchingIdeas()
        
        let view = StretchingView(stretchingIdeas: stretchingIdeas)
            .environmentObject(self)
            .frame(
                width: 500,
                //                height: 350,
                alignment: .topLeading
            )
        let hosting = NSHostingView(rootView: view)
        window.contentView = hosting
        hosting.autoresizingMask = [.width, .height]
        
        window.center()
        window.makeKey()
        window.orderFront(nil)
    }
    
    private func hideStretchingWindow() {
        stretchingWindow?.orderOut(nil)
        stretchingWindow = nil
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
