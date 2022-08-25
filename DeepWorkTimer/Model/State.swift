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
    
    public private(set) var pendingIntervalCompletionNotification: IntervalConfiguration?
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
                } else if running!.completionNotificationTime == nil || (now.timeIntervalSince(running!.completionNotificationTime!).isGreaterThanOrEqualTo(preferences.finishedTimerReminderInterval, ε: timerEps) && !isIdle) {
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
    
    public mutating func popIntervalCompletionNotification() -> IntervalConfiguration? {
        return pendingIntervalCompletionNotification.pop()
    }

    private var debugTitleSuffix: String {
        var suffix = ""
        if debugDisplayIdleTime {
            suffix += " i\(idleDuration, precision: 0) a\(activityDuration, precision: 0)"
        }
        if debugDisplayStretchingTime {
            suffix += " s\(timeTillNextStretch, precision: 0)"
        }
        return suffix
    }

    public func coreStatusText(using scheme: TitleScheme) -> String {
        if let running = running {
            let remaining = running.remaining
            if remaining.isGreaterThanZero(ε: timerEps) {
                let symbol = scheme.intervalKindSymbols[running.configuration.kind]!
                return remaining.minutesColonSeconds + " " + symbol
            } else if remaining.isGreaterThan(-60, ε: timerEps) {
                return scheme.endPrompt[running.configuration.kind.purpose]!
            } else {
                return (-remaining).shortString + "?"
            }
        } else if untimedWorkDuration.isGreaterThanOrEqualTo(preferences.untimedWorkRelevanceThreshold, ε: timerEps) {
            return untimedWorkDuration.shortString + "?"
        } else {
            return ""
        }
    }

    public var testStatusText: String { coreStatusText(using: .test) }

    public var statusItemText: String {
        (coreStatusText(using: .live) + debugTitleSuffix).trimmingCharacters(in: .whitespaces)
    }
}

public struct RunningState {
    public let startTime: Date
    public var configuration: IntervalConfiguration
    public var completionNotificationTime: Date? = nil
    public var isDone: Bool { derived.remaining.isLessThanOrEqualToZero(ε: timerEps) }
    
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

public enum IntervalStartMode {
    case restart
    case continuation
}

//enum TimePresentation {
//    case countdown(TimeInterval)
//    case bell
//    case untimedWork(TimeInterval)
//    case none
//}

fileprivate extension Optional {
    mutating func pop() -> Self {
        let value = self
        if value != nil {
            self = nil
        }
        return value
    }
}
