import Foundation

// Time interval small enough to be considered equivalent to zero.
// The primary purpose is to accomodate accumulated floating point errors
// when doing comparisons. However, the chosen value is based on
// a "duration we definitely don't care about" criteria.
let timerEps: TimeInterval = 0.0001

public extension TimeInterval {
    func isZero(ε: Self) -> Bool {
        return abs(self) <= ε
    }
    
    func isNonZero(ε: Self) -> Bool {
        return abs(self) > ε
    }

    func isGreaterThanZero(ε: Self) -> Bool {
        return self > ε
    }

    func isGreaterThanOrEqualToZero(ε: Self) -> Bool {
        return self >= -ε
    }

    func isLessThanZero(ε: Self) -> Bool {
        return self < -ε
    }

    func isLessThanOrEqualToZero(ε: Self) -> Bool {
        return self <= ε
    }

    func isEqualTo(_ peer: Self, ε: Self) -> Bool {
        return abs(self - peer) <= ε
    }
    
    func isNotEqualTo(_ peer: Self, ε: Self) -> Bool {
        return abs(self - peer) > ε
    }
    
    func isLessThan(_ peer: Self, ε: Self) -> Bool {
        return self < peer - ε
    }
    
    func isGreaterThan(_ peer: Self, ε: Self) -> Bool {
        return self > peer + ε
    }
    
    func isLessThanOrEqualTo(_ peer: Self, ε: Self) -> Bool {
        return self <= peer + ε
    }
    
    func isGreaterThanOrEqualTo(_ peer: Self, ε: Self) -> Bool {
        return self >= peer - ε
    }
    
    func isBetween(_ a: Self, _ b: Self, ε: Self) -> Bool {
        return (isGreaterThanOrEqualTo(a, ε: ε) && isLessThanOrEqualTo(b, ε: ε)) || (isGreaterThanOrEqualTo(b, ε: ε) && isLessThanOrEqualTo(a, ε: ε))
    }
    
    func isStrictlyBetween(_ a: Self, _ b: Self, ε: Self) -> Bool {
        return (isGreaterThan(a, ε: ε) && isLessThan(b, ε: ε)) || (isGreaterThan(b, ε: ε) && isLessThan(a, ε: ε))
    }
    
    func rounded(ε: Self) -> Self {
        return (self / ε).rounded() * ε
    }
}
