import Foundation
import Cocoa
import CoreGraphics

internal extension TimeInterval {
    
    var minutesColonSeconds: String {
        if self < 0 {
            return "-" + (-self).minutesColonSeconds
        }
        let totalSeconds = Int(exactly: self.rounded())!
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var minutesColonSecondsDotMilliseconds: String {
        if self < 0 {
            return "-" + (-self).minutesColonSecondsDotMilliseconds
        }
        let totalMilliseconds = Int(exactly: (self * 1000).rounded(.towardZero))!
        let milliseconds = totalMilliseconds % 1000

        let totalSeconds = totalMilliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return String(format: "%d:%02d.%03d", minutes, seconds, milliseconds)
    }
    
    var shortString: String {
        if self < 0 {
            return "-" + (-self).shortString
        }
        let totalSeconds = Int(exactly: self.rounded())!
        let minutes = totalSeconds / 60
        if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(totalSeconds)s"
        }
    }

}

extension NSFont {
    var monospaceDigitsVariant: NSFont {
        let origDesc = CTFontCopyFontDescriptor(self)
        let monoDesc = CTFontDescriptorCreateCopyWithFeature(origDesc, kNumberSpacingType as CFNumber, kMonospacedNumbersSelector as CFNumber)
        return CTFontCreateWithFontDescriptor(monoDesc, self.pointSize, nil) as NSFont
    }
}

extension NSSound.Name {
    static let basso     = NSSound.Name("Basso")
    static let blow      = NSSound.Name("Blow")
    static let bottle    = NSSound.Name("Bottle")
    static let frog      = NSSound.Name("Frog")
    static let funk      = NSSound.Name("Funk")
    static let glass     = NSSound.Name("Glass")
    static let hero      = NSSound.Name("Hero")
    static let morse     = NSSound.Name("Morse")
    static let ping      = NSSound.Name("Ping")
    static let pop       = NSSound.Name("Pop")
    static let purr      = NSSound.Name("Purr")
    static let sosumi    = NSSound.Name("Sosumi")
    static let submarine = NSSound.Name("Submarine")
    static let tink      = NSSound.Name("Tink")
}

func computeIdleTime() -> TimeInterval {
    CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!) as TimeInterval
}

extension String.StringInterpolation {
    mutating func appendInterpolation(_ value: Double, precision: Int, places: Int? = nil, digits: Int? = nil, plus: Bool = false) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = precision
        formatter.maximumFractionDigits = precision
        formatter.usesGroupingSeparator = false
        formatter.minimumIntegerDigits = digits ?? 1
        
        let w1: Int = (plus ? 1 : 0)
        let w2: Int = (places ?? 1)
        let w3: Int = (precision > 0 ? 1 + precision : 0)
        formatter.formatWidth = w1 + w2 + w3

        if plus {
            formatter.positivePrefix = formatter.plusSign!
        }
        appendLiteral(formatter.string(from: value as NSNumber)!)
    }
    mutating func appendInterpolation(_ value: Int, places: Int) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.formatWidth = places
        appendLiteral(formatter.string(from: value as NSNumber)!)
    }
    mutating func appendInterpolation(_ value: Int, digits: Int) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumIntegerDigits = digits
        appendLiteral(formatter.string(from: value as NSNumber)!)
    }
}
