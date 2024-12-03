import Foundation

public enum OpStatus {
    case neverTried
    case running
    case succeeded
    case failed
}

public struct OpState {
    public private(set) var isRunning = false
    public private(set) var attemptTime: Date?
    public private(set) var error: Error? = nil
    public private(set) var successTime: Date?
    
    public var status: OpStatus {
        if isRunning {
            return .running
        } else if error != nil {
            return .failed
        } else if successTime != nil {
            return .succeeded
        } else {
            return .neverTried
        }
    }
    public var succeeded: Bool { status == .succeeded }
    public var failed: Bool { status == .failed }

    public mutating func start(now: Date) {
        isRunning = true
        attemptTime = now
    }

    public mutating func complete(error: Error?, now: Date) {
        isRunning = false
        attemptTime = now
        self.error = error
        if error == nil {
            successTime = now
        }
    }
}
