import Foundation

public class Preferences {
    public let idleThreshold: TimeInterval = (debugFastIdleTimer ? 10 : 60)
    public let finishedTimerReminderInterval: TimeInterval = 60
    public let idleTimerPausingThreshold: TimeInterval = (debugFastIdleTimer ? 15 : 3 * 60)
    public let untimedWorkRelevanceThreshold: TimeInterval = (debugFastIdleTimer ? 5 : 2 * 60)
    public let untimedWorkEndThreshold: TimeInterval = (debugFastIdleTimer ? 15 : 3 * 60)
    public let missingTimerReminderThreshold: TimeInterval = (debugFastIdleTimer ? 15 : 2 * 60)
    public let missingTimerReminderRepeatInterval: TimeInterval = (debugFastIdleTimer ? 20 : 5 * 60)
    
    public let stretchingDuration: TimeInterval = (debugFastIdleTimer ? 5 : 30)
    public let stretchingPeriod: TimeInterval = (debugFastIdleTimer ? 15 : 20 * 60)

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
    
    public static let initial = Preferences()
}
