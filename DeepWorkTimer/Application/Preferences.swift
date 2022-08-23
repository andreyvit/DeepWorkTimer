import Foundation

class Preferences {
    let idleThreshold: TimeInterval = (debugFastIdleTimer ? 10 : 60)
    let finishedTimerReminderInterval: TimeInterval = 60
    let idleTimerPausingThreshold: TimeInterval = (debugFastIdleTimer ? 15 : 3 * 60)
    let untimedWorkRelevanceThreshold: TimeInterval = (debugFastIdleTimer ? 5 : 2 * 60)
    let untimedWorkEndThreshold: TimeInterval = (debugFastIdleTimer ? 15 : 3 * 60)
    let missingTimerReminderThreshold: TimeInterval = (debugFastIdleTimer ? 15 : 2 * 60)
    let missingTimerReminderRepeatInterval: TimeInterval = (debugFastIdleTimer ? 20 : 5 * 60)
    
    let stretchingDuration: TimeInterval = (debugFastIdleTimer ? 5 : 30)
    let stretchingPeriod: TimeInterval = (debugFastIdleTimer ? 15 : 20 * 60)

    let timeToRestMessages = [
        "Ready for a break?",
        "Want to freshen up?",
        "Ready to switch off work for a few minutes?",
        "Wanna stand up and have a break?",
    ]

    let backToWorkMessages = [
        "Want to get back to work?",
        "Ready to finish break?",
        "What do you choose to do next?",
    ]
}
