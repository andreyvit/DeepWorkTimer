import Foundation

let isSwiftUIPreview = (ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil)

let debugIncludeTinyIntervals = UserDefaults.standard.bool(forKey: "com.tarantsov.deepwork.debug.includeTinyIntervals")
let debugDisplayIdleTime = UserDefaults.standard.bool(forKey: "com.tarantsov.deepwork.debug.idle.show")
let debugDisplayStretchingTime = UserDefaults.standard.bool(forKey: "com.tarantsov.deepwork.debug.stretching.show")
let debugFastIdleTimer = UserDefaults.standard.bool(forKey: "com.tarantsov.deepwork.debug.idle.fast")
