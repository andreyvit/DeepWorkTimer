import Cocoa
import SwiftUI
import Combine
import UserNotifications
import os.log

@main
struct DeepWorkTimerApp: App {
    @NSApplicationDelegateAdaptor var appDelegate: AppDelegate
    @State var alertPresented: Bool = false

    var body: some Scene {
        Settings {
            EmptyView()
                .alert("Test", isPresented: $alertPresented) {
                    Button("OK", role: .cancel) { }
                }
        }
        
//        MenuBarExtra("Test", systemImage: "A.circle") {
//            Button("Foo") {}
//                .keyboardShortcut("1")
//            Button("Bar") {}
//                .keyboardShortcut("2")
//            Divider()
//            Button("Quit") { NSApplication.shared.terminate(nil) }
//                .keyboardShortcut("Q")
//        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, ObservableObject {
    
    let model = AppModel(preferences: .current, isTesting: false)

    var popover: NSPopover!
    
    var statusBarItem: NSStatusItem!
    
    var startItems: [(NSMenuItem, IntervalConfiguration, IntervalStartMode)] = []

    let stopItem = NSMenuItem(title: "Stop", action: #selector(stopTimer), keyEquivalent: "")
    let interruptionItem = NSMenuItem(title: "Interruption...", action: #selector(reportInterruption), keyEquivalent: "")

    let nextStretchItem = NSMenuItem(title: "Next Stretching in ...", action: nil, keyEquivalent: "")
    let startStretchingItem = NSMenuItem(title: "Stretch Now", action: #selector(startStretching), keyEquivalent: "")

    var globalMutingItems: [(NSMenuItem, MutingMode?)] = []
    let globalMutingUntilItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let globalMutingSubmenuItem = NSMenuItem(title: "Silence All Nagging", action: nil, keyEquivalent: "")
    let globalMutingSubmenu = NSMenu()
    let globalMutingOffItem = NSMenuItem(title: "Off", action: #selector(changeGlobalMutingMode), keyEquivalent: "")

    let optionsSubmenuItem = NSMenuItem(title: "Options", action: nil, keyEquivalent: "")
    let optionsSubmenu = NSMenu()
    let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    let disableStretchingItem = NSMenuItem(title: "Disable Stretching", action: #selector(toggleDisableStretching), keyEquivalent: "")
    let disableUntimedNaggingItem = NSMenuItem(title: "Disable Nagging To Start Timer", action: #selector(toggleDisableNaggingWhenTimerOff), keyEquivalent: "")
    let disableUntimedStatusItemCounterItem = NSMenuItem(title: "Disable “42m?” Counter When Timer Off", action: #selector(toggleDisableStatusItemCounterWhenTimerOff), keyEquivalent: "")

    private lazy var adjustDurationView = AdjustDurationView(adjuster: model.adjust(by:))
    private lazy var adjustDurationHost = NSHostingView(rootView: adjustDurationView)
    private lazy var adjustDurationItem: NSMenuItem = {
        adjustDurationHost.frame.size = adjustDurationHost.intrinsicContentSize

        let item = NSMenuItem()
        item.view = adjustDurationHost
        return item
    }()

    var subscriptions: Set<AnyCancellable> = []
    
    var globalUserActivity: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if isRunningTests {
            return
        }

        let event = NSAppleEventManager.shared().currentAppleEvent
        let isLaunchedAsLogInItem =
            (event?.eventID == kAEOpenApplication) &&
            (event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem)
        _ = isLaunchedAsLogInItem

        globalUserActivity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep], reason: "Deep Work Timer Menubar Updates")

        let defaults: UserDefaults = .standard
        defaults.set(Bundle.main.infoDictionary![kCFBundleVersionKey as String], forKey: "launchStats.last.version")
        defaults.set(defaults.integer(forKey: "launchStats.count") + 1, forKey: "launchStats.count")
        
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        
        menu.addItem(interruptionItem)
        menu.addItem(stopItem)
        menu.addItem(adjustDurationItem)
        menu.addItem(NSMenuItem.separator())

        var lastKind: IntervalKind?
        for configuration in IntervalConfiguration.all {
            if let lastKind = lastKind, configuration.kind != lastKind {
                menu.addItem(NSMenuItem.separator())
            }
            lastKind = configuration.kind

            let item = NSMenuItem(title: "\(configuration.kind.localizedDescription) \(configuration.duration.shortString)", action: #selector(startTimer), keyEquivalent: "")
            menu.addItem(item)
            startItems.append((item, configuration, .restart))

            let continueItem = NSMenuItem(title: "Continue as \(configuration.kind.localizedDescription) \(configuration.duration.shortString)", action: #selector(startTimer), keyEquivalent: "")
            continueItem.isAlternate = true
            continueItem.keyEquivalentModifierMask = .option
            menu.addItem(continueItem)
            startItems.append((continueItem, configuration, .continuation))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(nextStretchItem)
        nextStretchItem.isEnabled = false
        menu.addItem(startStretchingItem)
        
        globalMutingSubmenuItem.submenu = globalMutingSubmenu
        globalMutingSubmenu.addItem(globalMutingUntilItem)
        globalMutingUntilItem.isEnabled = false
        globalMutingSubmenu.addItem(NSMenuItem.separator())
        globalMutingSubmenu.addItem(globalMutingOffItem)
        globalMutingItems.append((globalMutingOffItem, nil))
        for mode in MutingMode.options {
            let item = NSMenuItem(title: mode.localizedDescription, action: #selector(changeGlobalMutingMode), keyEquivalent: "")
            globalMutingSubmenu.addItem(item)
            globalMutingItems.append((item, mode))
        }

        optionsSubmenuItem.submenu = optionsSubmenu
        optionsSubmenu.addItem(launchAtLoginItem)
        optionsSubmenu.addItem(NSMenuItem.separator())
        optionsSubmenu.addItem(disableStretchingItem)
        optionsSubmenu.addItem(disableUntimedNaggingItem)
        optionsSubmenu.addItem(disableUntimedStatusItemCounterItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(globalMutingSubmenuItem)
        menu.addItem(optionsSubmenuItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: "About", action: #selector(about), keyEquivalent: "")
        menu.addItem(withTitle: "Quit Deep Work Buddy", action: #selector(quit), keyEquivalent: "")

        statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        statusBarItem.button!.image = NSImage(named: "Timer")!
        statusBarItem.button!.imagePosition = .imageLeading
        statusBarItem.button!.font = statusBarItem.button!.font!.monospaceDigitsVariant
        statusBarItem.menu = menu
    
        model.objectWillChange.sink { [weak self] _ in self?.updateSoon() }.store(in: &subscriptions)
        update()
        
        if !model.preferences.isWelcomeDone || debugOnLaunchWelcome {
            showWelcome()
        }
        if debugOnLaunchStretching {
            model.startStretching()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        globalUserActivity = nil
    }

    func showWelcome() {
        
    }
        
    @objc func startTimer(_ sender: NSMenuItem) {
        guard let item = startItems.first(where: { $0.0 == sender }) else {
            fatalError("Unknown start item")
        }
        model.start(configuration: item.1, mode: item.2)
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            DispatchQueue.main.async {
                print("success = \(success), error = \(error?.localizedDescription ?? "<nil>")")
            }
        }
    }
    
    @objc func stopTimer(_ sender: NSMenuItem) {
        model.stop()
    }
    
    @objc func startStretching() {
        model.startStretching()
    }
    
    @objc func changeGlobalMutingMode(_ sender: NSMenuItem) {
        guard let item = globalMutingItems.first(where: { $0.0 == sender }) else {
            fatalError("Unknown start item")
        }
        recordUsage(.silencing)
        model.setTotalMutingMode(item.1)
    }

    @objc func toggleLaunchAtLogin() {
        recordUsage(.launchAtLogin)
        do {
            try toggleOpenAtLogin()
        } catch {
            appLog.error("Failed to toggle launch at login: \(String(describing: error))")
            
            let alert = NSAlert(error: error)
            alert.alertStyle = .warning
//            alert.informativeText = "Failed to toggle launch at login: \(error.localizedDescription)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        update()
    }
    
    @objc func toggleDisableStretching() {
        recordUsage(.disableStretching)
        model.toggleDisableStretching()
        update()
    }
    
    @objc func toggleDisableNaggingWhenTimerOff() {
        recordUsage(.disableNaggingWhenTimerOff)
        model.preferences.isUntimedNaggingDisabled = !model.preferences.isUntimedNaggingDisabled
        model.update()
        update()
    }
    
    @objc func toggleDisableStatusItemCounterWhenTimerOff() {
        recordUsage(.disableStatusItemCounterWhenTimerOff)
        model.preferences.isUntimedStatusItemCounterDisabled = !model.preferences.isUntimedNaggingDisabled
        model.update()
        update()
    }

    private var isUpdateScheduled = false
    private func updateSoon() {
        guard !isUpdateScheduled else { return }
        isUpdateScheduled = true
        DispatchQueue.main.async { [self] in
            isUpdateScheduled = false
            update()
        }
    }
    
    private func update() {
        statusBarItem.button!.title = model.state.statusItemText
        
        let isRunning = model.state.isRunning
        for (item, configuration, _) in startItems {
            item.state = (isRunning && model.state.running!.originalConfiguration == configuration ? .on : .off)
//            item.isEnabled = !isRunning
        }
        
        if model.state.stretchMuting?.mode == .forever {
            nextStretchItem.isHidden = true
        } else {
            nextStretchItem.isHidden = false
            if let timeTillNextStretch = model.state.timeTillNextStretch {
                nextStretchItem.title = "Next Stretching In \(timeTillNextStretch.shortString)"
            } else if model.state.totalMuting != nil {
                nextStretchItem.title = "Stretching Paused While Silenced"
            } else {
                nextStretchItem.title = "Stretching Paused"
            }
        }
        
        let totalMutingMode = model.state.totalMuting?.mode
        for (item, mode) in globalMutingItems {
            item.state = (totalMutingMode == mode ? .on : .off)
        }
        globalMutingSubmenuItem.state = (totalMutingMode != nil ? .on : .off)
        if let endTime = model.state.totalMuting?.endTime {
            globalMutingUntilItem.isHidden = false
            globalMutingUntilItem.title = "Silenced Until \(endTime)"
        } else {
            globalMutingUntilItem.isHidden = true
            globalMutingUntilItem.title = "Silenced Until..."
        }

        launchAtLoginItem.state = (launchAtLoginStatus() ? .on : .off)
        disableStretchingItem.state = (model.state.stretchMuting != nil ? .on : .off)
        disableUntimedNaggingItem.state = (model.preferences.isUntimedNaggingDisabled ? .on : .off)
        disableUntimedStatusItemCounterItem.state = (model.preferences.isUntimedStatusItemCounterDisabled ? .on : .off)

        stopItem.isHidden = !isRunning
        adjustDurationItem.isHidden = !isRunning
        adjustDurationHost.frame.size = (adjustDurationItem.isHidden ? .zero : adjustDurationHost.intrinsicContentSize)
    }
    
//    func menuNeedsUpdate(_ menu: NSMenu) {
//        print("menuNeedsUpdate")
//        update()
//    }
//
//    func menuWillOpen(_ menu: NSMenu) {
//        print("menuWillOpen")
//        update()
//    }

    @objc func about(_ sender: NSMenuItem) {
        NSApp.orderFrontStandardAboutPanel()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quit(_ sender: NSMenuItem) {
        NSApp.terminate(self)
    }
    
    @objc func reportInterruption() {
        model.startInterruption(reason: .manual)
    }
}
