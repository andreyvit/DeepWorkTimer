import Foundation

public struct Muting {
    public var startTime: Date
    public var mode: MutingMode
}

public enum MutingMode: Hashable {
    case permanent
    case timed(TimeInterval)
    case untilTomorrow
}
