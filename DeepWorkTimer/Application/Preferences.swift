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

    public static let initial = Preferences()
}
