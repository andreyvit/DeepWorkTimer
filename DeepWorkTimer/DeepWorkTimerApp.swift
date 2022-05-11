import Cocoa
import SwiftUI
import Combine
import UserNotifications
import os.log

let idleLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "idle")

private let debugIncludeTinyIntervals = UserDefaults.standard.bool(forKey: "com.tarantsov.deepwork.debug.includeTinyIntervals")
private let debugDisplayIdleTime = UserDefaults.standard.bool(forKey: "com.tarantsov.deepwork.debug.idle.show")
private let debugFastIdleTimer = UserDefaults.standard.bool(forKey: "com.tarantsov.deepwork.debug.idle.fast")

class Preferences {
    let idleThreshold: TimeInterval = (debugFastIdleTimer ? 10 : 60)
    let finishedTimerReminderInterval: TimeInterval = 60
    let idleTimerPausingThreshold: TimeInterval = (debugFastIdleTimer ? 15 : 3 * 60)
    let untimedWorkRelevanceThreshold: TimeInterval = (debugFastIdleTimer ? 5 : 2 * 60)
    let untimedWorkEndThreshold: TimeInterval = (debugFastIdleTimer ? 15 : 3 * 60)
    let missingTimerReminderThreshold: TimeInterval = (debugFastIdleTimer ? 15 : 2 * 60)
    let missingTimerReminderRepeatInterval: TimeInterval = (debugFastIdleTimer ? 20 : 5 * 60)
}

@main
struct DeepWorkTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var state = AppModel.shared

    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
        Settings {
            EmptyView()
        }
    }
}

struct AppState {
    let preferences: Preferences
    private(set) var lastConfiguration: IntervalConfiguration = .all.first!
    private(set) var running: RunningState?
    var isRunning: Bool { running != nil }
    private var idleStartTime: Date?
    private var activityStartTime: Date?
    private(set) var idleDuration: TimeInterval = 0
    private(set) var activityDuration: TimeInterval = 0
    private var isIdle: Bool { idleStartTime != nil }
    private var missingTimerWarningTime: Date = .distantPast
    private var untimedWorkStart: Date?
    private(set) var untimedWorkDuration: TimeInterval = 0

    var pendingIntervalCompletionNotification: IntervalConfiguration?
    var pendingMissingTimerWarning = false

    init(memento: Memento, preferences: Preferences, now: Date) {
        self.preferences = preferences
        lastConfiguration = memento.configuration
        if let startTime = memento.startTime {
            running = RunningState(startTime: startTime, configuration: memento.configuration)
        }
        if running == nil {
            untimedWorkStart = now
        }
    }
    
    var memento: Memento {
        Memento(startTime: running?.startTime, configuration: lastConfiguration)
    }
        
    mutating func start(configuration: IntervalConfiguration, mode: IntervalStartMode, now: Date) {
        lastConfiguration = configuration
        switch mode {
        case .continuation:
            if let running = running {
                if running.derived.remaining >= 0 {
                    self.running!.configuration = configuration
                } else {
                    let extraWorked = -running.derived.remaining
                    self.running = RunningState(startTime: now.addingTimeInterval(-extraWorked), configuration: configuration)
                }
            } else if let untimedWorkStart = untimedWorkStart {
                running = RunningState(startTime: untimedWorkStart, configuration: configuration)
            }
        case .restart:
            running = RunningState(startTime: now, configuration: configuration)
        }
    }

    mutating func stop(now: Date) {
        running = nil
        untimedWorkStart = now
    }

    mutating func update(now: Date) {
        if let idleStartTime = idleStartTime {
            idleDuration = now.timeIntervalSince(idleStartTime)
        }
        if let activityStartTime = activityStartTime {
            activityDuration = now.timeIntervalSince(activityStartTime)
        } else {
            activityDuration = 0
        }
        
        if running != nil {
            running!.update(now: now)
            if running!.isDone {
                if running!.completionNotificationTime == nil || (now.timeIntervalSince(running!.completionNotificationTime!) > preferences.finishedTimerReminderInterval && !isIdle) {
                    running!.completionNotificationTime = now
                    pendingIntervalCompletionNotification = running!.configuration
                }
            }
        }
    }
    
    mutating func setIdleDuration(_ idleDuration: TimeInterval, now: Date) {
        self.idleDuration = idleDuration
        let isIdle = (idleDuration > preferences.idleThreshold)
        // TODO: better hysteresis
        if idleStartTime == nil && isIdle {
            idleStartTime = now.addingTimeInterval(-idleDuration)
            activityStartTime = nil
        } else if activityStartTime == nil && !isIdle {
            idleStartTime = nil
            activityStartTime = now
        }
        
        if untimedWorkStart == nil, let activityStartTime = activityStartTime {
            untimedWorkStart = activityStartTime
        } else if untimedWorkStart != nil, let idleStartTime = idleStartTime, now.timeIntervalSince(idleStartTime) > preferences.untimedWorkEndThreshold {
            untimedWorkStart = nil
        }
        if let untimedWorkStart = untimedWorkStart {
            untimedWorkDuration = now.timeIntervalSince(untimedWorkStart)
        } else {
            untimedWorkDuration = 0
        }

        if running != nil && idleDuration > preferences.idleTimerPausingThreshold {
            // TODO: pause
        } else if running == nil && activityDuration > preferences.missingTimerReminderThreshold {
            if now.timeIntervalSince(missingTimerWarningTime) > preferences.missingTimerReminderRepeatInterval {
                missingTimerWarningTime = now
                pendingMissingTimerWarning = true
            }
        }
    }
}

class AppModel: ObservableObject {
    static let shared = AppModel()

    private var now: Date = .distantPast
    private(set) var state: AppState

    let preferences = Preferences()
    
    private init() {
        let memento = AppModel.loadMemento() ?? Memento(startTime: nil, configuration: .deep.first!)
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
        let wantTimer = state.isRunning
        let haveTimer = (updateTimer != nil)
        guard wantTimer != haveTimer else { return }
        cancelUpdateTimer()
        if wantTimer {
            updateTimer = Timer(timeInterval: 0.25, target: self, selector: #selector(update), userInfo: nil, repeats: true)
            updateTimer!.tolerance = 0.1
            RunLoop.main.add(updateTimer!, forMode: .common)
        }
    }
    
    private func mutate(_ block: () -> Void) {
        objectWillChange.send()
        now = Date.now
        block()
        state.update(now: now)
        save()
        reconsiderUpdateTimer()
        if let configuration = state.pendingIntervalCompletionNotification {
            state.pendingIntervalCompletionNotification = nil
            signalIntervalCompletion(configuration: configuration)
        }
        if state.pendingMissingTimerWarning {
            state.pendingMissingTimerWarning = false
            let content = UNMutableNotificationContent()
            content.title = "Want to start a timer?"
            content.interruptionLevel = .timeSensitive
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

    @objc private func update() {
        mutate {}
    }

    private func signalIntervalCompletion(configuration: IntervalConfiguration) {
        let content = UNMutableNotificationContent()
        content.title = "End \(configuration.kind.localizedDescription)?"
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        if configuration.kind == .rest {
            NSSound(named: .purr)!.play()
        } else {
            NSSound(named: .hero)!.play()
        }
    }

    private static func loadMemento() -> Memento? {
        if let string = UserDefaults.standard.string(forKey: "state") {
            do {
                return try JSONDecoder().decode(Memento.self, from: string.data(using: .utf8)!)
            } catch {
                NSLog("%@", "ERROR: failed to decode memento: \(String(describing: error))")
            }
        }
        return nil
    }
    
    private func save() {
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
}

struct RunningState {
    let startTime: Date
    var configuration: IntervalConfiguration
    var completionNotificationTime: Date? = nil
    var derived: RunningDerived
    var isDone: Bool { derived.remaining < 0 }
    
    init(startTime: Date, configuration: IntervalConfiguration) {
        self.startTime = startTime
        self.configuration = configuration
        derived = RunningDerived(elapsed: 0, configuration: configuration)
    }
    
    mutating func update(now: Date) {
        let elapsed = now.timeIntervalSince(startTime)
        derived = RunningDerived(elapsed: elapsed, configuration: configuration)
    }
}

struct Memento: Codable {
    var startTime: Date?
    var configuration: IntervalConfiguration

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case configuration = "configuration"
    }
}

struct RunningDerived {
    var elapsed: TimeInterval
    var remaining: TimeInterval
    
    init(elapsed: TimeInterval, configuration: IntervalConfiguration) {
        self.elapsed = elapsed
        remaining = configuration.duration - elapsed
    }
}

enum WorkKind: String, Equatable {
    case deep = "deep"
    case shallow = "shallow"
}

enum IntervalKindError: Error {
    case invalidIntervalKind
}

enum IntervalKind: RawRepresentable, Equatable, Codable {
    case work(WorkKind)
    case rest
    
    init?(rawValue: String) {
        if rawValue == "rest" {
            self = .rest
        } else if rawValue.hasPrefix("work:"), let work = WorkKind(rawValue: String(rawValue.dropFirst(5))) {
            self = .work(work)
        } else {
            return nil
        }
    }
    
    var isRest: Bool { self == .rest }

    var rawValue: String {
        switch self {
        case .work(let work):
            return "work:" + work.rawValue
        case .rest:
            return "rest"
        }
    }
    
    init(from decoder: Decoder) throws {
        if let kind = IntervalKind(rawValue: try decoder.singleValueContainer().decode(String.self)) {
            self = kind
        } else {
            throw IntervalKindError.invalidIntervalKind
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
    
    var localizedDescription: String {
        switch self {
        case .work(.deep):
            return NSLocalizedString("Deep Work", comment: "")
        case .work(.shallow):
            return NSLocalizedString("Shallow Work", comment: "")
        case .rest:
            return NSLocalizedString("Rest", comment: "")
        }
    }
}

enum IntervalStartMode {
    case restart
    case continuation
}

struct IntervalConfiguration: Equatable, Codable {
    var kind: IntervalKind
    var duration: TimeInterval
    
    static let deep: [IntervalConfiguration] = [
        IntervalConfiguration(kind: .work(.deep), duration: 50 * 60),
        IntervalConfiguration(kind: .work(.deep), duration: 25 * 60),
        IntervalConfiguration(kind: .work(.deep), duration: 15 * 60),
    ] + (debugIncludeTinyIntervals ? [
        IntervalConfiguration(kind: .work(.deep), duration: 15),
    ] : [])
    
    static let shallow: [IntervalConfiguration] = [
        IntervalConfiguration(kind: .work(.shallow), duration: 50 * 60),
        IntervalConfiguration(kind: .work(.shallow), duration: 25 * 60),
        IntervalConfiguration(kind: .work(.shallow), duration: 15 * 60),
        IntervalConfiguration(kind: .work(.shallow), duration: 10 * 60),
        IntervalConfiguration(kind: .work(.shallow), duration: 5 * 60),
        IntervalConfiguration(kind: .work(.shallow), duration: 2 * 60),
    ] + (debugIncludeTinyIntervals ? [
        IntervalConfiguration(kind: .work(.shallow), duration: 15),
    ] : [])

    static let rest: [IntervalConfiguration] = [
        IntervalConfiguration(kind: .rest, duration: 5 * 60),
        IntervalConfiguration(kind: .rest, duration: 10 * 60),
        IntervalConfiguration(kind: .rest, duration: 15 * 60),
        IntervalConfiguration(kind: .rest, duration: 20 * 60),
        IntervalConfiguration(kind: .rest, duration: 30 * 60),
    ] + (debugIncludeTinyIntervals ? [
        IntervalConfiguration(kind: .rest, duration: 15),
    ] : [])

    static let all: [IntervalConfiguration] = deep + shallow + rest
}

//enum TimePresentation {
//    case countdown(TimeInterval)
//    case bell
//    case untimedWork(TimeInterval)
//    case none
//}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    let model = AppModel.shared

    var popover: NSPopover!
    
    var statusBarItem: NSStatusItem!
    
    var startItems: [(NSMenuItem, IntervalConfiguration, IntervalStartMode)] = []

    let stopItem = NSMenuItem(title: "Stop", action: #selector(stopTimer), keyEquivalent: "")
    
    var subscriptions: Set<AnyCancellable> = []
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        
        menu.addItem(stopItem)
        menu.addItem(NSMenuItem.separator())

        var lastKind: IntervalKind?
        for configuration in IntervalConfiguration.all {
            if let lastKind = lastKind, configuration.kind != lastKind {
                menu.addItem(NSMenuItem.separator())
            }
            lastKind = configuration.kind

            let item = NSMenuItem(title: "\(configuration.kind.localizedDescription) \(configuration.duration.shortString)", action: #selector(startTimer), keyEquivalent: "")
            menu.addItem(item)
            startItems.append((item, configuration, .restart))

            let continueItem = NSMenuItem(title: "Continue as \(configuration.kind.localizedDescription) \(configuration.duration.shortString)", action: #selector(startTimer), keyEquivalent: "")
            continueItem.isAlternate = true
            continueItem.keyEquivalentModifierMask = .option
            menu.addItem(continueItem)
            startItems.append((continueItem, configuration, .continuation))
        }

        menu.addItem(NSMenuItem.separator())
        
//        let contentView = ContentView()
//        let contentController = NSHostingController(rootView: contentView)
//        contentController.view.frame.size = CGSize(width: 200, height: 50)
//        let customMenuItem = NSMenuItem()
//        customMenuItem.view = contentController.view
//        menu.addItem(customMenuItem)
//        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: "About Deep Work Timer", action: #selector(about), keyEquivalent: "")
        menu.addItem(withTitle: "Quit Deep Work Timer", action: #selector(quit), keyEquivalent: "")

        statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        statusBarItem.button!.image = NSImage(named: "Timer")!
        statusBarItem.button!.imagePosition = .imageLeading
        statusBarItem.button!.font = statusBarItem.button!.font!.monospaceDigitsVariant
        statusBarItem.menu = menu
    
        model.objectWillChange.sink { [weak self] _ in self?.updateSoon() }.store(in: &subscriptions)
        update()
    }
        
    @objc func startTimer(_ sender: NSMenuItem) {
        guard let item = startItems.first(where: { $0.0 == sender }) else {
            fatalError("Unknown start item")
        }
        model.start(configuration: item.1, mode: item.2)
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            DispatchQueue.main.async {
                print("success = \(success), error = \(error?.localizedDescription ?? "<nil>")")
            }
        }
    }
    
    @objc func stopTimer(_ sender: NSMenuItem) {
        model.stop()
    }
    
    private var isUpdateScheduled = false
    private func updateSoon() {
        guard !isUpdateScheduled else { return }
        isUpdateScheduled = true
        DispatchQueue.main.async { [self] in
            isUpdateScheduled = false
            update()
        }
    }
    
    private func update() {
        var suffix = ""
        if debugDisplayIdleTime {
            suffix += " i\(model.state.idleDuration, precision: 0) a\(model.state.activityDuration, precision: 0)"
        }
        if let running = model.state.running {
            let remaining = running.derived.remaining
            if remaining > 0 {
                statusBarItem.button!.title = running.derived.remaining.minutesColonSeconds + suffix
            } else if remaining > -60 {
                statusBarItem.button!.title = "END" + suffix
            } else {
                statusBarItem.button!.title = (-remaining).shortString + "?" + suffix
            }
        } else if model.state.untimedWorkDuration > model.state.preferences.untimedWorkRelevanceThreshold {
            statusBarItem.button!.title = model.state.untimedWorkDuration.shortString + "?" + suffix
        } else {
            statusBarItem.button!.title = suffix.trimmingCharacters(in: .whitespaces)
        }
        
        let isRunning = model.state.isRunning
        for (item, configuration, _) in startItems {
            item.state = (isRunning && model.state.running!.configuration == configuration ? .on : .off)
//            item.isEnabled = !isRunning
        }
        
        stopItem.isHidden = !isRunning
    }
    
//    func menuNeedsUpdate(_ menu: NSMenu) {
//        print("menuNeedsUpdate")
//        update()
//    }
//
//    func menuWillOpen(_ menu: NSMenu) {
//        print("menuWillOpen")
//        update()
//    }

    @objc func about(_ sender: NSMenuItem) {
        NSApp.orderFrontStandardAboutPanel()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quit(_ sender: NSMenuItem) {
        NSApp.terminate(self)
    }
}

private extension NSMenuItem {
    
}


