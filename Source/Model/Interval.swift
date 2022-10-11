import Foundation

public enum WorkKind: String, Equatable, Hashable {
    case leveragedDeep = "leveraged"
    case deep = "deep"
    case shallow = "shallow"
}

public enum IntervalKindError: Error {
    case invalidIntervalKind
}

public enum IntervalPurpose: Hashable {
    case work
    case rest
}

public enum IntervalKind: RawRepresentable, Equatable, Codable, Hashable {
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
    
    public var purpose: IntervalPurpose {
        switch self {
        case .work:
            return .work
        case .rest:
            return .rest
        }
    }

    public var localizedDescription: String {
        switch self {
        case .work(.leveragedDeep):
            return NSLocalizedString("Leveraged Work", comment: "")
        case .work(.deep):
            return NSLocalizedString("Deep Work", comment: "")
        case .work(.shallow):
            return NSLocalizedString("Shallow Work", comment: "")
        case .rest:
            return NSLocalizedString("Rest", comment: "")
        }
    }
}

public struct IntervalConfiguration: Equatable, Codable {
    public var kind: IntervalKind
    public var duration: TimeInterval
    
    public static let leveraged: [IntervalConfiguration] = [
        IntervalConfiguration(kind: .work(.leveragedDeep), duration: 50 * 60),
        IntervalConfiguration(kind: .work(.leveragedDeep), duration: 25 * 60),
        IntervalConfiguration(kind: .work(.leveragedDeep), duration: 15 * 60),
    ] + (debugIncludeTinyIntervals ? [
        IntervalConfiguration(kind: .work(.leveragedDeep), duration: 15),
    ] : [])

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

    public static let all: [IntervalConfiguration] = leveraged + deep + shallow + rest
}
