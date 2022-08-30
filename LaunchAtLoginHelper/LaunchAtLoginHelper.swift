import SwiftUI
import os

private let mainBundleID = Bundle.main.bundleIdentifier!.replacingOccurrences(of: ".LaunchAtLoginHelper$", with: "", options: .regularExpression)

private let log = Logger(subsystem: mainBundleID, category: "launchatlogin")

@main
struct LaunchAtLoginHelper: App {
    @NSApplicationDelegateAdaptor(LaunchAtLoginAppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {}
    }
}

final class LaunchAtLoginAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainBundleURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        if NSRunningApplication.runningApplications(withBundleIdentifier: mainBundleID).isEmpty {
            log.debug("launching main app: \(mainBundleID, privacy: .public) at \(mainBundleURL.path, privacy: .public)")
            NSWorkspace.shared.openApplication(at: mainBundleURL, configuration: .init()) { runningApp, error in
                DispatchQueue.main.async {
                    if let error = error {
                        log.error("failed to launch main app \(mainBundleID, privacy: .public): \(String(reflecting: error), privacy: .public)")
                    } else {
                        log.info("main app launched: \(mainBundleID, privacy: .public)")
                    }
                    NSApp.terminate(nil)
                }
            }
        } else {
            log.info("main app already running: \(mainBundleID, privacy: .public)")
            NSApp.terminate(nil)
        }
    }
}
