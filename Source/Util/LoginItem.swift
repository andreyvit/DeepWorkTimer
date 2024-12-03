import Foundation
import ServiceManagement
import Combine

func toggleOpenAtLogin() throws {
    switch SMAppService.mainApp.status {
    case .notRegistered:
        try SMAppService.mainApp.register()
    case .enabled:
        try SMAppService.mainApp.register() // just in case
    case .requiresApproval:
        throw OpenAtLoginError.approvalDenied
    case .notFound:
        throw OpenAtLoginError.notFound
    @unknown default:
        throw OpenAtLoginError.failed
    }
}

func launchAtLoginStatus() -> Bool {
    let status = SMAppService.mainApp.status
    switch status {
    case .notRegistered:
        return false
    case .enabled:
        return true
    case .requiresApproval:
        return false
    case .notFound:
        return false
    default:
        return false
    }
}

enum OpenAtLoginError: Error, LocalizedError {
    case approvalDenied
    case notFound
    case failed
    
    var errorDescription: String? {
        switch self {
        case .approvalDenied: return "Open System Settings to grant the permission."
        case .notFound: return "Registration failed (the login item was unavailable)."
        case .failed: return "Registration failed."
        }
    }

    var failureReason: String? { nil }
    var recoverySuggestion: String? { nil }
    var helpAnchor: String? { nil }
}
