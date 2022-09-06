import Foundation

public enum MutingMode: Codable, Hashable {
    case duration(TimeInterval)
    case untilTomorrow
    case forever
    
    public static let options: [MutingMode] = (debugIncludeTinyIntervals ? [
        .duration(.second * 10),
        .duration(.minute),
    ] : []) + [
        .duration(.hour * 1),
        .duration(.hour * 2),
        .duration(.hour * 3),
        .duration(.hour * 4),
        .duration(.hour * 12),
        .untilTomorrow,
        .forever,
    ]
    
    public func computeEndTime(after startTime: Date, calendar: Calendar, dayBoundaryHour: Int) -> Date? {
        switch self {
        case .duration(let interval):
            return startTime.addingTimeInterval(interval)
        case .untilTomorrow:
            return calendar.nextDayBoundary(after: startTime, boundaryHour: dayBoundaryHour)
        case .forever:
            return nil
        }
    }
    
    public var localizedDescription: String {
        switch self {
        case .duration(let interval):
            switch interval {
            case .hour:
                return NSLocalizedString("Silence for 1 Hour", comment: "Muting option title")
            case .hour * 2:
                return NSLocalizedString("Silence for 2 Hours", comment: "Muting option title")
            case .hour * 3:
                return NSLocalizedString("Silence for 3 Hours", comment: "Muting option title")
            case .hour * 4:
                return NSLocalizedString("Silence for 4 Hours", comment: "Muting option title")
            case .hour * 12:
                return NSLocalizedString("Silence for 12 Hours", comment: "Muting option title")
            default:
                return NSLocalizedString("Silence for 88:59", comment: "Muting option title").replacingOccurrences(of: "88:59", with: interval.shortString)
            }
        case .untilTomorrow:
            return NSLocalizedString("Silence Until Tomorrow", comment: "Muting option title")
        case .forever:
            return NSLocalizedString("Silence Forever (Until Disabled)", comment: "Muting option title")
        }
    }
}

public struct Muting: Codable, Equatable {
    var mode: MutingMode
    var startTime: Date
    var endTime: Date?

    private enum CodingKeys: String, CodingKey {
        case mode = "mode"
        case startTime = "start"
        case endTime = "end"
    }
    
    public init(mode: MutingMode, startingAt startTime: Date, calendar: Calendar, dayBoundaryHour: Int) {
        self.mode = mode
        self.startTime = startTime
        self.endTime = mode.computeEndTime(after: startTime, calendar: calendar, dayBoundaryHour: dayBoundaryHour)
    }
        
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(MutingMode.self, forKey: .mode)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date?.self, forKey: .endTime)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
    }
}
