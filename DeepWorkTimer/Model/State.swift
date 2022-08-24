import Foundation

public struct AppState {
    public let preferences: Preferences
    public private(set) var lastConfiguration: IntervalConfiguration = .all.first!
    public private(set) var running: RunningState?
    public private(set) var idleDuration: TimeInterval = 0
    public private(set) var activityDuration: TimeInterval = 0
    public private(set) var untimedWorkDuration: TimeInterval = 0
    public private(set) var timeTillNextStretch: TimeInterval = .greatestFiniteMagnitude
    public private(set) var stretchingRemainingTime: TimeInterval? = nil
    
    public var pendingIntervalCompletionNotification: IntervalConfiguration?
    public var pendingMissingTimerWarning = false

    public var isRunning: Bool { running != nil }

    private var idleStartTime: Date?
    private var activityStartTime: Date?
    private var isIdle: Bool { idleStartTime != nil }
    private var missingTimerWarningTime: Date = .distantPast
    private var lastStopTime: Date
    private var untimedWorkStart: Date?

    private var lastStretchTime: Date
    private var nextStretchTime: Date = .distantFuture
    private var stretchingStartTime: Date? = nil

    public init(memento: AppMemento, preferences: Preferences, now: Date) {
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
    
    public var memento: AppMemento {
        AppMemento(
            startTime: running?.startTime,
            configuration: lastConfiguration,
            lastStretchTime: lastStretchTime
        )
    }
        
    public mutating func start(configuration: IntervalConfiguration, mode: IntervalStartMode, now: Date) {
        lastConfiguration = configuration
        switch mode {
        case .continuation:
            if let running = running {
                if running.remaining >= 0 {
                    self.running!.configuration = configuration
                } else {
                    let extraWorked = -running.remaining
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

    public mutating func stop(now: Date) {
        running = nil
        untimedWorkStart = now
        lastStopTime = now
    }

    public mutating func update(now: Date) {
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
                if running!.remaining < -preferences.cancelOverdueIntervalAfter {
                    stop(now: now)
                } else if running!.completionNotificationTime == nil || (now.timeIntervalSince(running!.completionNotificationTime!) > preferences.finishedTimerReminderInterval && !isIdle) {
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
    
    public mutating func setIdleDuration(_ idleDuration: TimeInterval, now: Date) {
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
    
    public var isStretching: Bool {
        return stretchingStartTime != nil
    }

    public mutating func startStretching(now: Date) {
        stretchingStartTime = now
        updateRemainingStretchingTime(now: now)
    }
    
    public mutating func endStretching(now: Date) {
        lastStretchTime = now
        stretchingStartTime = nil
        updateRemainingStretchingTime(now: now)
    }
    
    public mutating func updateRemainingStretchingTime(now: Date) {
        if let stretchingStartTime = stretchingStartTime {
            stretchingRemainingTime = preferences.stretchingDuration - now.timeIntervalSince(stretchingStartTime)
        } else {
            stretchingRemainingTime = nil
        }
    }
}

public struct RunningState {
    public let startTime: Date
    public var configuration: IntervalConfiguration
    public var completionNotificationTime: Date? = nil
    public var isDone: Bool { derived.remaining < 0 }
    
    public var elapsed: TimeInterval { derived.elapsed }
    public var remaining: TimeInterval { derived.remaining }

    private var derived: RunningDerived

    public init(startTime: Date, configuration: IntervalConfiguration) {
        self.startTime = startTime
        self.configuration = configuration
        derived = RunningDerived(elapsed: 0, configuration: configuration)
    }
    
    public mutating func update(now: Date) {
        let elapsed = now.timeIntervalSince(startTime)
        derived = RunningDerived(elapsed: elapsed, configuration: configuration)
    }
}

public struct RunningDerived {
    var elapsed: TimeInterval
    var remaining: TimeInterval
    
    public init(elapsed: TimeInterval, configuration: IntervalConfiguration) {
        self.elapsed = elapsed
        remaining = configuration.duration - elapsed
    }
}

public enum WorkKind: String, Equatable {
    case deep = "deep"
    case shallow = "shallow"
}

public enum IntervalKindError: Error {
    case invalidIntervalKind
}

public enum IntervalKind: RawRepresentable, Equatable, Codable {
    case work(WorkKind)
    case rest
    
    public init?(rawValue: String) {
        if rawValue == "rest" {
            self = .rest
        } else if rawValue.hasPrefix("work:"), let work = WorkKind(rawValue: String(rawValue.dropFirst(5))) {
            self = .work(work)
        } else {
            return nil
        }
    }
    
    public var isRest: Bool { self == .rest }

    public var rawValue: String {
        switch self {
        case .work(let work):
            return "work:" + work.rawValue
        case .rest:
            return "rest"
        }
    }
    
    public init(from decoder: Decoder) throws {
        if let kind = IntervalKind(rawValue: try decoder.singleValueContainer().decode(String.self)) {
            self = kind
        } else {
            throw IntervalKindError.invalidIntervalKind
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
    
    public var localizedDescription: String {
        switch self {
        case .work(.deep):
            return NSLocalizedString("Deep Work", comment: "")
        case .work(.shallow):
            return NSLocalizedString("Shallow Work", comment: "")
        case .rest:
            return NSLocalizedString("Rest", comment: "")
        }
    }

    public var endLabel: String {
        switch self {
        case .work:
            return NSLocalizedString("BREAK", comment: "")
        case .rest:
            return NSLocalizedString("WORK", comment: "")
        }
    }
}

public enum IntervalStartMode {
    case restart
    case continuation
}

public struct IntervalConfiguration: Equatable, Codable {
    public var kind: IntervalKind
    public var duration: TimeInterval
    
    public static let deep: [IntervalConfiguration] = [
        IntervalConfiguration(kind: .work(.deep), duration: 50 * 60),
        IntervalConfiguration(kind: .work(.deep), duration: 25 * 60),
        IntervalConfiguration(kind: .work(.deep), duration: 15 * 60),
    ] + (debugIncludeTinyIntervals ? [
        IntervalConfiguration(kind: .work(.deep), duration: 15),
    ] : [])
    
    public static let shallow: [IntervalConfiguration] = [
        IntervalConfiguration(kind: .work(.shallow), duration: 50 * 60),
        IntervalConfiguration(kind: .work(.shallow), duration: 25 * 60),
        IntervalConfiguration(kind: .work(.shallow), duration: 15 * 60),
        IntervalConfiguration(kind: .work(.shallow), duration: 10 * 60),
        IntervalConfiguration(kind: .work(.shallow), duration: 5 * 60),
        IntervalConfiguration(kind: .work(.shallow), duration: 2 * 60),
    ] + (debugIncludeTinyIntervals ? [
        IntervalConfiguration(kind: .work(.shallow), duration: 15),
    ] : [])

    public static let rest: [IntervalConfiguration] = [
        IntervalConfiguration(kind: .rest, duration: 5 * 60),
        IntervalConfiguration(kind: .rest, duration: 10 * 60),
        IntervalConfiguration(kind: .rest, duration: 15 * 60),
        IntervalConfiguration(kind: .rest, duration: 20 * 60),
        IntervalConfiguration(kind: .rest, duration: 30 * 60),
    ] + (debugIncludeTinyIntervals ? [
        IntervalConfiguration(kind: .rest, duration: 15),
    ] : [])

    public static let all: [IntervalConfiguration] = deep + shallow + rest
}

//enum TimePresentation {
//    case countdown(TimeInterval)
//    case bell
//    case untimedWork(TimeInterval)
//    case none
//}
