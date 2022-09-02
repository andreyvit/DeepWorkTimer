import Foundation
import Cocoa
import SwiftUI
import UserNotifications
import os.log

class AppModel: ObservableObject {
    static let shared = AppModel()

    private var now: Date = .distantPast
    private(set) var state: AppState

    let preferences = Preferences.initial
    
    private init() {
        let memento = AppModel.loadMemento() ?? AppMemento()
        state = AppState(memento: memento, preferences: preferences, now: .now)
        startIdleTimer()
        handleIdleTimer()
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
        cancelUpdateTimer()
        cancelIdleTimer()
        save()
    }
    
    private var updateTimer: Timer?
    private func cancelUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    private func reconsiderUpdateTimer() {
        let wantTimer = state.isFrequentUpdatingDesired
        let haveTimer = (updateTimer != nil)
        guard wantTimer != haveTimer else { return }
        cancelUpdateTimer()
        if wantTimer {
            updateTimer = Timer(timeInterval: 0.25, target: self, selector: #selector(update), userInfo: nil, repeats: true)
            updateTimer!.tolerance = 0.1
            RunLoop.main.add(updateTimer!, forMode: .common)
            timerLog.debug("high-frequency timer ON")
        } else {
            timerLog.debug("high-frequency timer OFF")
        }
    }
    
    private func mutate(_ block: () -> Void) {
        objectWillChange.send()
        now = Date.now
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
    }

    @objc private func update() {
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

    private var idleTimer: Timer?
    private func cancelIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }
    private func startIdleTimer() {
        cancelIdleTimer()
        idleTimer = Timer(timeInterval: preferences.idleThreshold / 4, target: self, selector: #selector(handleIdleTimer), userInfo: nil, repeats: true)
        idleTimer!.tolerance = idleTimer!.timeInterval / 5
        RunLoop.main.add(idleTimer!, forMode: .common)
    }
    @objc private func handleIdleTimer() {
        let idleDuration = computeIdleTime()
        let now = Date.now
        mutate {
            state.setIdleDuration(idleDuration, now: now)
        }
    }
    
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
    
    func setTotalMutingMode(_ newMode: MutingMode?) {
        mutate {
            state.setTotalMutingMode(newMode, now: now)
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
        //        window.title = "Manage collections"
        window.center()
        window.isReleasedWhenClosed = false
        self.stretchingWindow = window
        
        let view = StretchingView()
            .frame(
                width: 400,
                //                height: 350,
                alignment: .topLeading
            )
        let hosting = NSHostingView(rootView: view)
        window.contentView = hosting
        hosting.autoresizingMask = [.width, .height]
        
//        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.orderFront(nil)
    }
    
    private func hideStretchingWindow() {
        stretchingWindow?.orderOut(nil)
        stretchingWindow = nil
    }
}
