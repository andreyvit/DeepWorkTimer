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
    private var lastInterruptionEnd: Date = .distantPast

    public var isRunning: Bool { running != nil }
    
    public var isFrequentUpdatingDesired: Bool { isRunning || isStretching || isStretchingSoon || isInterrupted }
    
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
        if let runningMemento = memento.running {
            running = RunningState(startTime: runningMemento.startTime, configuration: memento.configuration, excluded: runningMemento.excluded)
        }
        if running == nil {
            untimedWorkStart = now
        }
        interruption = memento.interruption.map(Interruption.init(memento:))
    }
    
    public var memento: AppMemento {
        AppMemento(
            running: running?.memento,
            configuration: lastConfiguration,
            lastStretchTime: lastStretchTime,
            totalMuting: totalMuting,
            stretchMuting: stretchMuting,
            interruption: interruption?.memento
        )
    }
    
    public mutating func start(configuration: IntervalConfiguration, mode: IntervalStartMode, now: Date) {
        lastConfiguration = configuration
        switch mode {
        case .continuation:
            if let running = running {
                if running.remaining >= 0 {
                    self.running!.originalConfiguration = configuration
                } else {
                    let extraWorked = -running.remaining
                    self.running = RunningState(startTime: now.addingTimeInterval(-extraWorked), configuration: configuration, excluded: 0)
                }
            } else if let untimedWorkStart = untimedWorkStart {
                running = RunningState(startTime: untimedWorkStart, configuration: configuration, excluded: 0)
            }
        case .restart:
            running = RunningState(startTime: now, configuration: configuration, excluded: 0)
        }
        untimedWorkStart = nil
    }
    
    public mutating func stop(now: Date) {
        running = nil
        untimedWorkStart = now
        lastStopTime = now
    }
    
    public mutating func adjustDuration(by delta: TimeInterval, now: Date) {
        running?.adjustDuration(by: delta, now: now)
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
                    pendingIntervalCompletionNotification = running!.currentConfiguration
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
        
        if running != nil && idleDuration > preferences.idleInterruptionThreshold {
            if !isInterrupted, let idleStartTime = idleStartTime {
                startInterruption(reason: .idleness, at: idleStartTime)
            }
        } else if running == nil && !preferences.isUntimedNaggingDisabled && min(activityDuration, now.timeIntervalSince(lastStopTime)).isGreaterThanOrEqualTo(preferences.missingTimerReminderThreshold, ε: timerEps) && !isTotalMutingActive {
            if now.timeIntervalSince(missingTimerWarningTime).isGreaterThanOrEqualTo(preferences.missingTimerReminderRepeatInterval, ε: timerEps) {
                missingTimerWarningTime = now
                pendingMissingTimerWarning = true
            }
        }
        
        if idleDuration.isGreaterThanOrEqualTo(preferences.stretchingResetsAfterInactivityPeriod, ε: timerEps) {
            lastStretchInactivityReset = now
        }
        
        interruption?.update(now: now)
        
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
            lastInterruptionEnd,
        ].max()!
        if isStretchingMutingActive || isInterrupted {
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
    
    
    // MARK: - Stretching
    
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
    
    // MARK: - Notifications
    
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
    
    
    // MARK: - Muting
    
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
    
    
    // MARK: - Status
    
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
                let symbol = scheme.intervalKindSymbols[running.originalConfiguration.kind]!
                return remaining.minutesColonSeconds + " " + symbol
            } else if remaining.isGreaterThan(-60, ε: timerEps) {
                return scheme.endPrompt[running.originalConfiguration.kind.purpose]!
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
    
    // MARK: - Interruptions
    
    public private(set) var interruption: Interruption?
    
    public var isInterrupted: Bool { interruption != nil }
    public var isRunningIntervalWorthContinuing: Bool { isRunning }
    public var isRecommendedToContinue: Bool { isRunning }
    public var interruptionDuration: TimeInterval { interruption?.derived.duration ?? 0 }
    
    mutating func startInterruption(reason: InterruptionStartReason, at startTime: Date) {
        if let interruption = interruption {
            if reason.overrides(interruption.reason) {
                self.interruption!.reason = reason
            }
            return
        }
        interruption = Interruption(startTime: startTime, reason: reason)
    }
    
    mutating func endInterruption(action: InterruptionEndAction, now: Date) {
        guard let interruption = interruption else {
            return
        }

        var elapsed = now.timeIntervalSince(interruption.startTime)
        if elapsed < 0 {
            eventLog.error("negative interruption duration")
            elapsed = 0
        }
        
        self.interruption = nil
        self.lastInterruptionEnd = now

        switch action {
        case .continueIncludingInterruption:
            break
        case .continueExcludingInterruption:
            running?.exclude(from: interruption.startTime, now: now)
        case .stop:
            running?.exclude(from: interruption.startTime, now: now)
            stop(now: now)
        }
    }
}


// MARK: -
public struct RunningState {
    public let startTime: Date
    public var originalConfiguration: IntervalConfiguration
    public var duration: TimeInterval
    public var completionNotificationTime: Date? = nil
    public var excluded: TimeInterval = 0
    public var isDone: Bool { derived.remaining.isLessThanOrEqualToZero(ε: timerEps) }

    public var elapsed: TimeInterval { derived.elapsed }
    public var remaining: TimeInterval { derived.remaining }
    public var endTime: Date { startTime.addingTimeInterval(duration) }
    
    public var currentConfiguration: IntervalConfiguration {
        IntervalConfiguration(kind: originalConfiguration.kind, duration: duration)
    }

    private var derived: RunningDerived

    public init(startTime: Date, configuration: IntervalConfiguration, excluded: TimeInterval) {
        self.startTime = startTime
        self.originalConfiguration = configuration
        self.duration = configuration.duration
        self.excluded = excluded
        derived = RunningDerived(elapsed: 0, duration: duration)
    }

    public var memento: RunningMemento {
        RunningMemento(startTime: startTime, excluded: excluded)
    }
    
    public mutating func exclude(from exclusionStart: Date, now: Date) {
        let boundary = max(startTime, exclusionStart)
        let duration = now.timeIntervalSince(boundary)
        excluded += duration
        update(now: now)
    }

    public mutating func adjustDuration(by delta: TimeInterval, now: Date) {
        update(now: now)
        if delta.isGreaterThanZero(ε: timerEps) {
            duration += derived.extraWorked + delta
        } else {
            duration += delta
        }
    }
    
    public mutating func continueWithConfiguration(_ newConfiguration: IntervalConfiguration, now: Date) {
        originalConfiguration = newConfiguration

        update(now: now)
        if !derived.hasEnded && newConfiguration.duration.isGreaterThanOrEqualTo(duration, ε: timerEps) {
            duration = newConfiguration.duration
        } else {
            duration += derived.extraWorked + newConfiguration.duration
        }
    }

    public mutating func update(now: Date) {
        let elapsed = now.timeIntervalSince(startTime) - excluded
        derived = RunningDerived(elapsed: elapsed, duration: duration)
    }
}

public struct RunningDerived {
    var elapsed: TimeInterval
    var remaining: TimeInterval
    var extraWorked: TimeInterval {
        if hasEnded {
            return -remaining
        } else {
            return 0
        }
    }
    
    public init(elapsed: TimeInterval, duration: TimeInterval) {
        self.elapsed = elapsed
        remaining = duration - elapsed
    }

    public var hasEnded: Bool {
        remaining.isLessThanZero(ε: timerEps)
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
