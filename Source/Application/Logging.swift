import Foundation
import os.log

let idleLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "idle")
let timerLog = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "timer")
let eventLog = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "events")

