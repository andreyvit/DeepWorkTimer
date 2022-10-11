import Foundation

let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(abbreviation: "PST")!
    return calendar
}()

let startOfModernEra = testCalendar.date(from: DateComponents(year: 2007, month: 1, day: 9, hour: 9, minute: 41, second: 0))!

extension TimeInterval {
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
