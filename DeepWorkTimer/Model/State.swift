import Foundation

public struct AppState {
    public let calendar: Calendar
    public let preferences: Preferences
    public private(set) var lastConfiguration: IntervalConfiguration = .all.first!
    public private(set) var running: RunningState?
    public private(set) var idleDuration: TimeInterval = 0
    public private(set) var activityDuration: TimeInterval = 0
    public private(set) var untimedWorkDuration: TimeInterval = 0
    public private(set) var timeTillNextStretch: TimeInterval?
    public private(set) var stretchingRemainingTime: TimeInterval? = nil
    
    public private(set) var pendingIntervalCompletionNotification: IntervalConfiguration?
    public private(set) var pendingMissingTimerWarning = false

    public private(set) var totalMuting: Muting? = nil
    public private(set) var stretchMuting: Muting? = nil
    private var lastTotalMutingDeactivation: Date = .distantPast
    private var lastStretchMutingDeactivation: Date = .distantPast
    private var lastStretchInactivityReset: Date = .distantPast

    public var isRunning: Bool { running != nil }

    public var isFrequentUpdatingDesired: Bool { isRunning || isStretching || isStretchingSoon }

    private var idleStartTime: Date?
    private var activityStartTime: Date?
    private var isIdle: Bool { idleStartTime != nil }
    private var missingTimerWarningTime: Date = .distantPast
    private var lastStopTime: Date
    private var untimedWorkStart: Date?

    private var lastStretchTime: Date
    private var nextStretchTime: Date = .distantFuture
    private var stretchingState: StretchingState? = nil
    
    public var isTotalMutingActive: Bool { totalMuting != nil }
    public var isStretchingMutingActive: Bool { isTotalMutingActive || stretchMuting != nil }

    public init(memento: AppMemento, preferences: Preferences, now: Date, calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        self.preferences = preferences
        self.lastStopTime = now
        lastConfiguration = memento.configuration
        lastStretchTime = memento.lastStretchTime
        totalMuting = memento.totalMuting
        stretchMuting = memento.stretchMuting
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
            lastStretchTime: lastStretchTime,
            totalMuting: totalMuting,
            stretchMuting: stretchMuting
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
        if let endTime = totalMuting?.endTime, endTime <= now {
            setTotalMutingMode(nil, now: now)
        }
        if let endTime = stretchMuting?.endTime, endTime <= now {
            stretchMuting = nil
            lastStretchMutingDeactivation = now
        }

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
                } else if !isTotalMutingActive && (
                        running!.completionNotificationTime == nil ||
                        (now.timeIntervalSince(running!.completionNotificationTime!).isGreaterThanOrEqualTo(preferences.finishedTimerReminderInterval, ε: timerEps) && !isIdle)
                ) {
                    running!.completionNotificationTime = now
                    pendingIntervalCompletionNotification = running!.configuration
                }
            }
        }
        
        updateRemainingStretchingTime(now: now)
        if let stretchingRemainingTime = stretchingRemainingTime, stretchingRemainingTime.isLessThanOrEqualToZero(ε: timerEps) {
            endStretching(now: now)
        }

        if running == nil {
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
        } else {
            untimedWorkStart = nil
            untimedWorkDuration = 0
        }

        if running != nil && idleDuration > preferences.idleTimerPausingThreshold {
            // TODO: pause
        } else if running == nil && !preferences.isUntimedNaggingDisabled && min(activityDuration, now.timeIntervalSince(lastStopTime)).isGreaterThanOrEqualTo(preferences.missingTimerReminderThreshold, ε: timerEps) && !isTotalMutingActive {
            if now.timeIntervalSince(missingTimerWarningTime).isGreaterThanOrEqualTo(preferences.missingTimerReminderRepeatInterval, ε: timerEps) {
                missingTimerWarningTime = now
                pendingMissingTimerWarning = true
            }
        }

        if idleDuration.isGreaterThanOrEqualTo(preferences.stretchingResetsAfterInactivityPeriod, ε: timerEps) {
            lastStretchInactivityReset = now
        }

        let lastStretchTime: Date
        if let stretchingState = stretchingState {
            lastStretchTime = stretchingState.endTime
        } else {
            lastStretchTime = self.lastStretchTime
        }
        let latestStretchingBoundary = [
            lastStretchTime,
            lastStopTime,
            untimedWorkStart ?? .distantPast,
            running?.startTime ?? .distantPast,
            lastStretchMutingDeactivation,
            lastStretchInactivityReset,
        ].max()!
        if isStretchingMutingActive {
            nextStretchTime = .distantFuture
            timeTillNextStretch = nil
        } else {
            nextStretchTime = latestStretchingBoundary.addingTimeInterval(preferences.stretchingPeriod)
            
            if let running = running, running.endTime.timeIntervalSince(nextStretchTime).isBetween(-preferences.minStretchingDelayAroundEndOfInterval, preferences.maxStretchingDelayAtEndOfInterval, ε: timerEps) {
                nextStretchTime = nextStretchTime.addingTimeInterval(preferences.maxStretchingDelayAtEndOfInterval)
            }
            
            let timeTillNextStretch = nextStretchTime.timeIntervalSince(now)
            self.timeTillNextStretch = timeTillNextStretch
            if timeTillNextStretch.isLessThanOrEqualToZero(ε: timerEps) && !isStretching {
                startStretching(now: now)
            }
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
    }
    
    public var isStretching: Bool { stretchingState != nil }

    public var isStretchingSoon: Bool {
        if let timeTillNextStretch = timeTillNextStretch {
            return timeTillNextStretch < 60
        } else {
            return false
        }
    }

    public mutating func startStretching(now: Date) {
        stretchingState = StretchingState(startTime: now, duration: preferences.stretchingDuration)
        updateRemainingStretchingTime(now: now)
    }
    
    public mutating func endStretching(now: Date) {
        lastStretchTime = now
        stretchingState = nil
        updateRemainingStretchingTime(now: now)
    }
    
    public mutating func extendStretching(now: Date) {
        if stretchingState != nil {
            stretchingState!.duration += 60
        }
        updateRemainingStretchingTime(now: now)
    }

    public mutating func updateRemainingStretchingTime(now: Date) {
        if let stretchingState = stretchingState {
            stretchingRemainingTime = stretchingState.endTime.timeIntervalSince(now)
        } else {
            stretchingRemainingTime = nil
        }
    }
    
    public mutating func popIntervalCompletionNotification() -> IntervalConfiguration? {
        return pendingIntervalCompletionNotification.pop()
    }
    
    public mutating func popMissingTimerWarning() -> Bool {
        return pendingMissingTimerWarning.pop()
    }
    
    public mutating func popAppActivation(now: Date) -> Bool {
        if let stretchingState = stretchingState, !stretchingState.appActivated, stretchingState.durationSoFar(now: now).isGreaterThanOrEqualTo(preferences.stretchingAppActivationDelay, ε: timerEps) {
            self.stretchingState!.appActivated = true
            return true
        }
        return false
    }

    public mutating func setStretchingMutingMode(_ newMode: MutingMode?, now: Date) {
        if let newMode = newMode {
            stretchMuting = Muting(mode: newMode, startingAt: now, calendar: calendar, dayBoundaryHour: preferences.dayBoundaryHour)
        } else {
            stretchMuting = nil
            lastStretchMutingDeactivation = now
        }
    }

    public mutating func setTotalMutingMode(_ newMode: MutingMode?, now: Date) {
        if let newMode = newMode {
            totalMuting = Muting(mode: newMode, startingAt: now, calendar: calendar, dayBoundaryHour: preferences.dayBoundaryHour)
        } else {
            totalMuting = nil
            lastTotalMutingDeactivation = now
            lastStretchMutingDeactivation = now
        }
    }

    private var debugTitleSuffix: String {
        var suffix = ""
        if debugDisplayIdleTime {
            suffix += " i\(idleDuration, precision: 0) a\(activityDuration, precision: 0)"
        }
        if debugDisplayStretchingTime, let timeTillNextStretch = timeTillNextStretch {
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
        } else if !preferences.isUntimedStatusItemCounterDisabled && untimedWorkDuration.isGreaterThanOrEqualTo(preferences.untimedWorkRelevanceThreshold, ε: timerEps) {
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
    public var endTime: Date { startTime.addingTimeInterval(configuration.duration) }

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

public struct StretchingState {
    public var startTime: Date
    public var duration: TimeInterval
    public var endTime: Date { startTime.addingTimeInterval(duration) }
    public var appActivated: Bool = false
    
    public func durationSoFar(now: Date) -> TimeInterval {
        return now.timeIntervalSince(startTime)
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

fileprivate extension Bool {
    mutating func pop() -> Self {
        let value = self
        if value {
            self = false
        }
        return value
    }
}
