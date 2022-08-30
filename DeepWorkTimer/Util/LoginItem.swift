import Foundation
import ServiceManagement
import Combine

class LoginItem: ObservableObject {
    let bundleID: String
    
    private let publisherImpl: CurrentValueSubject<Bool, Never>
    let publisher: AnyPublisher<Bool, Never>
    
    init(bundleID: String) {
        self.bundleID = bundleID
        isEnabled = (Self.self as SilenceDeprecationWarningOnSMCopyAllJobDictionaries.Type).checkJobEnabled(bundleID: bundleID)
        publisherImpl = CurrentValueSubject<Bool, Never>(isEnabled)
        publisher = publisherImpl.eraseToAnyPublisher()
    }

    var isEnabled: Bool {
        willSet {
            guard isEnabled != newValue else { return }
            objectWillChange.send()
        }
        didSet {
            guard isEnabled != oldValue else { return }
            SMLoginItemSetEnabled(bundleID as CFString, isEnabled)
        }
    }
}

private protocol SilenceDeprecationWarningOnSMCopyAllJobDictionaries {
    static func checkJobEnabled(bundleID: String) -> Bool
}
extension LoginItem: SilenceDeprecationWarningOnSMCopyAllJobDictionaries {
    // SMCopyAllJobDictionaries is deprecated, but the docs say:
    // "For the specific use of testing the state of a login item that may have been
    // enabled with SMLoginItemSetEnabled() in order to show that state to the
    // user, this function remains the recommended API. A replacement API for this
    // specific use will be provided before this function is removed."
    @available(*, deprecated)
    fileprivate static func checkJobEnabled(bundleID: String) -> Bool {
        let jobs: [[String: AnyObject]] = SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?.takeRetainedValue() as? [[String: AnyObject]] ?? []
        guard let job = jobs.first(where: { ($0["Label"] as? String) == bundleID }) else {
            return false
        }
        return job["OnDemand"] as? Bool ?? false
    }
}
