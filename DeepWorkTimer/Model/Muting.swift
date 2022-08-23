import Foundation

struct Muting {
    var startTime: Date
    var mode: MutingMode
}

enum MutingMode: Hashable {
    case permanent
    case timed(TimeInterval)
    case untilTomorrow
}
