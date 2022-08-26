import Foundation

public extension Calendar {
    func nextMidnight(after time: Date) -> Date {
        nextDate(after: time, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime, repeatedTimePolicy: .last, direction: .forward)!
    }

    func nextDayBoundary(after time: Date, boundaryHour: Int) -> Date {
        let midnight = nextMidnight(after: time)
        let midnightHour = self.component(.hour, from: midnight)
        if midnightHour >= boundaryHour {
            // If they specified 0 and we've got it, return right away.
            // Or maybe they specified 0 as hour, but due to weird datetime transition 0am (12pm) does not exist, so we only have 1am to offer.
            // Or maybe they specified 1am, and there's a super-weird gap in time-space fabric eating up 0 and 1, and only 2am exists.
            return midnight
        }
        
        // They want something like 2am, so look for it. Might need to offer the next time that exists.
        return nextDate(after: midnight, matching: DateComponents(hour: boundaryHour, minute: 0, second: 0), matchingPolicy: .nextTime, repeatedTimePolicy: .last, direction: .forward)!
    }
}
