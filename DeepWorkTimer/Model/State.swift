import Foundation

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
    private var lastStopTime: Date
    private var untimedWorkStart: Date?
    private(set) var untimedWorkDuration: TimeInterval = 0

    private var lastStretchTime: Date
    private var nextStretchTime: Date = .distantFuture
    private(set) var timeTillNextStretch: TimeInterval = .greatestFiniteMagnitude
    private var stretchingStartTime: Date? = nil
    private(set) var stretchingRemainingTime: TimeInterval? = nil

    var pendingIntervalCompletionNotification: IntervalConfiguration?
    var pendingMissingTimerWarning = false

    init(memento: AppMemento, preferences: Preferences, now: Date) {
        self.preferences = preferences
        self.lastStopTime = now
        lastConfiguration = memento.configuration
        lastStretchTime = memento.lastStretchTime
        if let startTime = memento.startTime {
            running = RunningState(startTime: startTime, configuration: memento.configuration)
        }
        if running == nil {
            untimedWorkStart = now
        }
    }
    
    var memento: AppMemento {
        AppMemento(
            startTime: running?.startTime,
            configuration: lastConfiguration,
            lastStretchTime: lastStretchTime
        )
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
        untimedWorkStart = nil
    }

    mutating func stop(now: Date) {
        running = nil
        untimedWorkStart = now
        lastStopTime = now
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
        
        updateRemainingStretchingTime(now: now)
        if let stretchingRemainingTime = stretchingRemainingTime, stretchingRemainingTime < 0 {
            endStretching(now: now)
        }
        
        let lastStretchTime: Date
        if let stretchingStartTime = stretchingStartTime {
            lastStretchTime = stretchingStartTime.addingTimeInterval(preferences.stretchingDuration)
        } else {
            lastStretchTime = self.lastStretchTime
        }
        let latestStretchingBoundary = [lastStretchTime, lastStopTime, untimedWorkStart ?? .distantPast, running?.startTime ?? .distantPast].max()!
        nextStretchTime = latestStretchingBoundary.addingTimeInterval(preferences.stretchingPeriod)
        timeTillNextStretch = nextStretchTime.timeIntervalSince(now)
        if timeTillNextStretch < 0 && !isStretching {
            startStretching(now: now)
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
        } else if running == nil && min(activityDuration, now.timeIntervalSince(lastStopTime)) > preferences.missingTimerReminderThreshold {
            if now.timeIntervalSince(missingTimerWarningTime) > preferences.missingTimerReminderRepeatInterval {
                missingTimerWarningTime = now
                pendingMissingTimerWarning = true
            }
        }
    }
    
    var isStretching: Bool {
        return stretchingStartTime != nil
    }

    mutating func startStretching(now: Date) {
        stretchingStartTime = now
        updateRemainingStretchingTime(now: now)
    }
    
    mutating func endStretching(now: Date) {
        lastStretchTime = now
        stretchingStartTime = nil
        updateRemainingStretchingTime(now: now)
    }
    
    mutating func updateRemainingStretchingTime(now: Date) {
        if let stretchingStartTime = stretchingStartTime {
            stretchingRemainingTime = preferences.stretchingDuration - now.timeIntervalSince(stretchingStartTime)
        } else {
            stretchingRemainingTime = nil
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

    var endLabel: String {
        switch self {
        case .work:
            return NSLocalizedString("BREAK", comment: "")
        case .rest:
            return NSLocalizedString("WORK", comment: "")
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
