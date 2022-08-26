import Foundation

public extension TimeInterval {
    static var second: TimeInterval { 1 }
    static var minute: TimeInterval { 60 }
    static var hour: TimeInterval { 60 * 60 }
    static var day: TimeInterval { 24 * 60 * 60 }
    
    static func seconds(_ n: Int) -> TimeInterval { TimeInterval(n) }
    static func seconds(_ n: Double) -> TimeInterval { n }
    static func minutes(_ n: Int) -> TimeInterval { TimeInterval(n) * minute }
    static func minutes(_ n: Double) -> TimeInterval { n * minute }
    static func hours(_ n: Int) -> TimeInterval { TimeInterval(n) * hour }
    static func hours(_ n: Double) -> TimeInterval { n * hour }
    static func days(_ n: Double) -> TimeInterval { n * day }
}
