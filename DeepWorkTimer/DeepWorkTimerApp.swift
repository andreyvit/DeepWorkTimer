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
    let missingTimerReminderThreshold: TimeInterval = (debugFastIdleTimer ? 15 : 2 * 60)
    let missingTimerReminderRepeatInterval: TimeInterval = (debugFastIdleTimer ? 20 : 5 * 60)
}

@main
struct DeepWorkTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var state = AppState.shared

    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
        Settings {
            EmptyView()
        }
    }
}

class AppState: ObservableObject {
    static let shared = AppState.load()

    @Published private(set) var lastConfiguration: IntervalConfiguration = .all.first!
    @Published private(set) var running: RunningState?
    private var now: Date = .distantPast
    private var idleStartTime: Date?
    private var activityStartTime: Date?
    private(set) var idleDuration: TimeInterval = 0
    private(set) var activityDuration: TimeInterval = 0
    private var isIdle: Bool { idleStartTime != nil }
    private var missingTimerWarningTime: Date = .distantPast

    let preferences = Preferences()
    
    init() {
        startIdleTimer()
        handleIdleTimer()
    }
    
    init(memento: Memento) {
        lastConfiguration = memento.configuration
        if let startTime = memento.startTime {
            running = RunningState(startTime: startTime, configuration: memento.configuration)
            startUpdateTimer()
        }
        startIdleTimer()
        handleIdleTimer()
    }
    
    var memento: Memento {
        Memento(startTime: running?.startTime, configuration: lastConfiguration)
    }

    func start(configuration: IntervalConfiguration) {
        lastConfiguration = configuration
        if running != nil && !running!.isDone && running!.configuration.kind.isCompatible(with: configuration.kind) {
            running!.configuration = configuration
            update()
            if !running!.isDone {
                return
            }
        }
        running = RunningState(startTime: Date.now, configuration: configuration)
        startUpdateTimer()
        update()
    }
    
    func stop() {
        running = nil
        cancelUpdateTimer()
        update()
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
    private func startUpdateTimer() {
        cancelUpdateTimer()
        updateTimer = Timer(timeInterval: 0.25, target: self, selector: #selector(update), userInfo: nil, repeats: true)
        updateTimer!.tolerance = 0.1
        RunLoop.main.add(updateTimer!, forMode: .common)
    }

    @objc private func update() {
        objectWillChange.send()
        now = Date.now

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
                    signalIntervalCompletion(configuration: running!.configuration)
                }
            }
        }
        save()
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

    private static func load() -> AppState {
        if let string = UserDefaults.standard.string(forKey: "state") {
            do {
                let memento = try JSONDecoder().decode(Memento.self, from: string.data(using: .utf8)!)
                return AppState(memento: memento)
            } catch {
                NSLog("%@", "ERROR: failed to decode memento: \(String(describing: error))")
            }
        }
        return AppState()
    }
    
    private func save() {
        let string = String(data: try! JSONEncoder().encode(memento), encoding: .utf8)!
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
        idleDuration = computeIdleTime()
        let isIdle = (idleDuration > preferences.idleThreshold)
        if idleStartTime == nil && isIdle {
            idleStartTime = Date.now.addingTimeInterval(-idleDuration)
            activityStartTime = nil
        } else if activityStartTime == nil && !isIdle {
            idleStartTime = nil
            activityStartTime = Date.now
        }
        update()

        os_log("idle=%.0lf, activity=%.0lf, isIdle=%{public}@", log: idleLog, type: .debug, idleDuration, activityDuration, isIdle ? "Y" : "N")

        if running != nil && idleDuration > preferences.idleTimerPausingThreshold {
            // TODO: pause
        } else if running == nil && activityDuration > preferences.missingTimerReminderThreshold {
            if now.timeIntervalSince(missingTimerWarningTime) > preferences.missingTimerReminderRepeatInterval {
                missingTimerWarningTime = now
                let content = UNMutableNotificationContent()
                content.title = "Want to start a timer?"
                content.interruptionLevel = .timeSensitive
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
            }
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
    
    func isCompatible(with another: IntervalKind) -> Bool {
        self.isRest == another.isRest
    }

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

struct IntervalConfiguration: Equatable, Codable {
    var kind: IntervalKind
    var duration: TimeInterval
    
    static let deep: [IntervalConfiguration] = [
        IntervalConfiguration(kind: .work(.deep), duration: 15 * 60),
        IntervalConfiguration(kind: .work(.deep), duration: 25 * 60),
        IntervalConfiguration(kind: .work(.deep), duration: 50 * 60),
    ] + (debugIncludeTinyIntervals ? [
        IntervalConfiguration(kind: .work(.deep), duration: 15),
    ] : [])
    
    static let shallow: [IntervalConfiguration] = [
        IntervalConfiguration(kind: .work(.shallow), duration: 5 * 60),
        IntervalConfiguration(kind: .work(.shallow), duration: 15 * 60),
        IntervalConfiguration(kind: .work(.shallow), duration: 25 * 60),
        IntervalConfiguration(kind: .work(.shallow), duration: 50 * 60),
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

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    let state = AppState.shared

    var popover: NSPopover!
    
    var statusBarItem: NSStatusItem!
    
    var startItems: [(NSMenuItem, IntervalConfiguration)] = []

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
            startItems.append((item, configuration))
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
    
        state.objectWillChange.sink { [weak self] _ in self?.updateSoon() }.store(in: &subscriptions)
        update()
    }
        
    @objc func startTimer(_ sender: NSMenuItem) {
        guard let pair = startItems.first(where: { $0.0 == sender }) else {
            fatalError("Unknown start item")
        }
        state.start(configuration: pair.1)
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            DispatchQueue.main.async {
                print("success = \(success), error = \(error?.localizedDescription ?? "<nil>")")
            }
        }
    }
    
    @objc func stopTimer(_ sender: NSMenuItem) {
        state.stop()
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
            suffix += " i\(state.idleDuration, precision: 0) a\(state.activityDuration, precision: 0)"
        }
        if let running = state.running {
            statusBarItem.button!.title = running.derived.remaining.minutesColonSeconds + suffix
        } else {
            statusBarItem.button!.title = suffix.trimmingCharacters(in: .whitespaces)
        }
        
        let isRunning = (state.running != nil)
        for (item, configuration) in startItems {
            item.state = (isRunning && state.running!.configuration == configuration ? .on : .off)
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


