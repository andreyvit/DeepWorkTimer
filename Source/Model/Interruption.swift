import Foundation

public enum InterruptionEndAction {
    case stop
    case continueIncludingInterruption
    case continueExcludingInterruption
}

public enum InterruptionStartReason: String, Codable {
    case sleep = "sleep"
    case idleness = "idleness"
    case manual = "manual"
    
    func overrides(_ another: InterruptionStartReason) -> Bool {
        switch self {
        case .sleep:
            return false
        case .idleness:
            return another == .sleep
        case .manual:
            return another == .sleep || another == .idleness
        }
    }
}

public struct Interruption: Codable {
    var startTime: Date
    var reason: InterruptionStartReason
    var derived: InterruptionDerived = .init()
    
    init(startTime: Date, reason: InterruptionStartReason) {
        self.startTime = startTime
        self.reason = reason
    }
    
    init(memento: InterruptionMemento) {
        startTime = memento.startTime
        reason = memento.reason
    }
    
    var memento: InterruptionMemento {
        InterruptionMemento(startTime: startTime, reason: reason)
    }

    mutating func update(now: Date) {
        derived = InterruptionDerived(self, now: now)
    }
}

struct InterruptionMemento: Codable {
    var startTime: Date
    var reason: InterruptionStartReason
}

public struct InterruptionDerived: Codable {
    var duration: TimeInterval
    
    init() {
        duration = 0
    }
    
    init(_ interruption: Interruption, now: Date) {
        duration = now.timeIntervalSince(interruption.startTime)
    }
}
