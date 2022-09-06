import Foundation

struct Feature {
    let identifier: String
    let defaults: UserDefaults = .standard
    
    init(_ identifier: String) {
        self.identifier = identifier
    }

    fileprivate func recordUse() {
        defaults.set(Date.now, forKey: lastUseKey)
        defaults.set(totalCount + 1, forKey: totalCountKey)
    }

    var totalCount: Int { defaults.integer(forKey: totalCountKey) }
    
    private var totalCountKey: String { "feature.\(identifier).total.count" }
    private var lastUseKey: String { "feature.\(identifier).last.time" }
}

extension Feature {
    static let launchAtLogin = Feature("launchAtLoginToggle")
    static let disableStretching = Feature("disableStretchingToggle")
    static let disableNaggingWhenTimerOff = Feature("disableNaggingWhenTimerOff")
    static let disableStatusItemCounterWhenTimerOff = Feature("disableStatusItemCounterWhenTimerOff")
    static let silencing = Feature("silencing")
}

func recordUsage(_ feature: Feature) {
    feature.recordUse()
}
