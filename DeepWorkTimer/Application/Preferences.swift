import Foundation

public class Preferences {
    public let idleThreshold: TimeInterval = (debugFastIdleTimer ? 10 : 60)
    public let finishedTimerReminderInterval: TimeInterval = 60
    public let idleTimerPausingThreshold: TimeInterval = (debugFastIdleTimer ? 15 : 3 * 60)
    public let cancelOverdueIntervalAfter: TimeInterval = (debugFastIdleTimer ? 60 : 2 * 60 * 60)

    public let untimedWorkRelevanceThreshold: TimeInterval = (debugFastIdleTimer ? 5 : 2 * 60)
    public let untimedWorkEndThreshold: TimeInterval = (debugFastIdleTimer ? 15 : 3 * 60)
    public let missingTimerReminderThreshold: TimeInterval = (debugFastIdleTimer ? 15 : 2 * 60)
    public let missingTimerReminderRepeatInterval: TimeInterval = (debugFastIdleTimer ? 20 : 5 * 60)
    
    public let stretchingDuration: TimeInterval = (debugFastIdleTimer ? 5 : 60)
    public let stretchingPeriod: TimeInterval = (debugFastIdleTimer ? 15 : 20 * 60)
    public let stretchingAppActivationDelay: TimeInterval = 5
    public let stretchingResetsAfterInactivityPeriod: TimeInterval = (debugFastIdleTimer ? 5 : 3 * 60)
    public let minStretchingDelayAroundEndOfInterval: TimeInterval = (debugFastIdleTimer ? 5 : 30)
    public let maxStretchingDelayAtEndOfInterval: TimeInterval = (debugFastIdleTimer ? 15 : 8 * 60)

    public let dayBoundaryHour = 4  // 4 am

    public let timeToRestMessages = [
        "Ready for a break?",
        "Want to freshen up?",
        "Ready to switch off work for a few minutes?",
        "Wanna stand up and have a break?",
    ]

    public let backToWorkMessages = [
        "Want to get back to work?",
        "Ready to finish break?",
        "What do you choose to do next?",
    ]

    public let shoulderStretchingIdeas = [
        "Shrug: raise and drop your shoulders a few times.",
        "Touch your ears to your shoulders, slowly.",
        "Roll your shoulders forwards and backwards in circular motion.",
        "Squeeze your shoulder blades.",
    ]

    public let torsoStretchingIdeas = [
        "Clasp your hands behind your back, push your chest outwards, raise your chin, hold for a few seconds.",
        "Clasp your hands in front of you, lower your head in line with your arms, hold a bit.",
        "Rest your arm on the back of a chair, keep your feet on the ground facing forward, twist upper body in the direction of the arm, hold for a few seconds.",
    ]

    public let armStretchingIdeas = [
        "Raise your arm above your head and extend it fully, reach to the opposite side.",
        "Raise your elbow above your head, bending the arm fully. Use the other hand to pull the elbow towards your head, hold for a few seconds.",
        "Clasp your hands together above the head, with your palms facing outward. Push your arms up, hold for a few seconds."
    ]

    public let legStretchingIdeas = [
        "Extend your legs all the way, enjoy for a few seconds.",
        "Hug your knee and pull it towards your chest, hold a bit.",
    ]

    public let mindfulnessIdeas = [
        "Pay attention to how good it feels to move.",
        "Recall an enjoyable moment from your recent days.",
        "Think of something you're feeling grateful for today.",
        "You can keep thinking about work, don't let your mind wander.",
    ]

    public func randomStretchingIdeas() -> [String] {
        var ideas: [String] = []
        ideas.append(shoulderStretchingIdeas.randomElement()!)
        ideas.append(torsoStretchingIdeas.randomElement()!)
        ideas.append(armStretchingIdeas.randomElement()!)
        ideas.append(legStretchingIdeas.randomElement()!)
        ideas.append(mindfulnessIdeas.randomElement()!)
        return ideas
    }

    public let defaults: UserDefaultsProtocol
    
    public init(defaults: UserDefaultsProtocol) {
        self.defaults = defaults
    }

    public static let current = Preferences(defaults: UserDefaults.standard)
    public static let initial = Preferences(defaults: MockDefaults())

    public var isUntimedNaggingDisabled: Bool {
        get { defaults.bool(forKey: "isUntimedNaggingDisabled") }
        set { defaults.set(newValue, forKey: "isUntimedNaggingDisabled") }
    }
    public var isUntimedStatusItemCounterDisabled: Bool {
        get { defaults.bool(forKey: "isUntimedStatusItemCounterDisabled") }
        set { defaults.set(newValue, forKey: "isUntimedStatusItemCounterDisabled") }
    }
}

public extension UserDefaults {
    private static let testingSuiteName = "com.tarantsov.DeepWorkTimer.testing"
    static var testing = UserDefaults(suiteName: testingSuiteName)!
    static func resetTestingDefaults() {
        testing.removePersistentDomain(forName: testingSuiteName)
    }
}

public protocol UserDefaultsProtocol {
    func object(forKey defaultName: String) -> Any?
    func string(forKey defaultName: String) -> String?
    func url(forKey defaultName: String) -> URL?
    func array(forKey defaultName: String) -> [Any]?
    func dictionary(forKey defaultName: String) -> [String : Any]?
    func data(forKey defaultName: String) -> Data?
    func stringArray(forKey defaultName: String) -> [String]?
    func bool(forKey defaultName: String) -> Bool
    func integer(forKey defaultName: String) -> Int
    func double(forKey defaultName: String) -> Double

    func set(_ value: Any?, forKey defaultName: String)
    func set(_ value: Int, forKey defaultName: String)
    func set(_ value: Double, forKey defaultName: String)
    func set(_ value: Bool, forKey defaultName: String)
    func set(_ value: URL?, forKey defaultName: String)
}

extension UserDefaults: UserDefaultsProtocol {}

public class MockDefaults: UserDefaultsProtocol {
    public var values: [String: Any]
    
    public init(_ values: [String: Any] = [:]) {
        self.values = values
    }

    public func object(forKey key: String) -> Any?         { values[key] }
    public func string(forKey key: String) -> String?      { values[key] as? String }
    public func url(forKey key: String) -> URL?            { values[key] as? URL }
    public func bool(forKey key: String) -> Bool           { (values[key] as? Bool) ?? false }
    public func integer(forKey key: String) -> Int         { (values[key] as? Int) ?? 0 }
    public func double(forKey key: String) -> Double       { (values[key] as? Double) ?? 0 }
    public func array(forKey key: String) -> [Any]?        { values[key] as? [Any] }
    public func data(forKey key: String) -> Data?          { values[key] as? Data }
    public func dictionary(forKey key: String) -> [String : Any]?  { values[key] as? [String: Any] }
    public func stringArray(forKey key: String) -> [String]?       { values[key] as? [String] }

    public func removeObject(forKey key: String)           { values[key] = nil }
    public func set(_ value: Any?, forKey key: String)     { values[key] = value }
    public func set(_ value: Int, forKey key: String)      { set(value as Any?, forKey: key) }
    public func set(_ value: Double, forKey key: String)   { set(value as Any?, forKey: key) }
    public func set(_ value: Bool, forKey key: String)     { set(value as Any?, forKey: key) }
    public func set(_ value: URL?, forKey key: String)     { set(value as Any?, forKey: key) }
}
