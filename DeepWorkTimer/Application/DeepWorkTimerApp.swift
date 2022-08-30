import Cocoa
import SwiftUI
import Combine
import UserNotifications
import os.log

let launchAtLoginHelper = LoginItem(bundleID: "com.tarantsov.DeepWorkTimer.LaunchAtLoginHelper")

@main
struct DeepWorkTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var state = AppModel.shared
    @State var alertPresented: Bool = false

    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
        Settings {
            EmptyView()
                .alert("Test", isPresented: $alertPresented) {
                    Button("OK", role: .cancel) { }
                }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    let model = AppModel.shared

    var popover: NSPopover!
    
    var statusBarItem: NSStatusItem!
    
    var startItems: [(NSMenuItem, IntervalConfiguration, IntervalStartMode)] = []

    let stopItem = NSMenuItem(title: "Stop", action: #selector(stopTimer), keyEquivalent: "")

    let nextStretchItem = NSMenuItem(title: "Next Stretching in ...", action: nil, keyEquivalent: "")
    let startStretchingItem = NSMenuItem(title: "Stretch Now", action: #selector(startStretching), keyEquivalent: "")

    var globalMutingItems: [(NSMenuItem, MutingMode?)] = []
    let globalMutingUntilItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let globalMutingSubmenuItem = NSMenuItem(title: "Silence All Nagging", action: nil, keyEquivalent: "")
    let globalMutingSubmenu = NSMenu()
    let globalMutingOffItem = NSMenuItem(title: "Off", action: #selector(changeGlobalMutingMode), keyEquivalent: "")

    let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    var subscriptions: Set<AnyCancellable> = []
    
    var globalUserActivity: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if isRunningTests {
            return
        }
        
        globalUserActivity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep], reason: "Deep Work Timer Menubar Updates")

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        
        menu.addItem(stopItem)
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

        menu.addItem(NSMenuItem.separator())
        globalMutingSubmenuItem.submenu = globalMutingSubmenu
        menu.addItem(globalMutingSubmenuItem)
        menu.addItem(launchAtLoginItem)
        menu.addItem(NSMenuItem.separator())
        
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

//        let contentView = ContentView()
//        let contentController = NSHostingController(rootView: contentView)
//        contentController.view.frame.size = CGSize(width: 200, height: 50)
//        let customMenuItem = NSMenuItem()
//        customMenuItem.view = contentController.view
//        menu.addItem(customMenuItem)
//        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: "About", action: #selector(about), keyEquivalent: "")
        menu.addItem(withTitle: "Quit Deep Work Timer", action: #selector(quit), keyEquivalent: "")

        statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        statusBarItem.button!.image = NSImage(named: "Timer")!
        statusBarItem.button!.imagePosition = .imageLeading
        statusBarItem.button!.font = statusBarItem.button!.font!.monospaceDigitsVariant
        statusBarItem.menu = menu
    
        model.objectWillChange.sink { [weak self] _ in self?.updateSoon() }.store(in: &subscriptions)
        update()
        
        if debugOnLaunchStretching {
            model.startStretching()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        globalUserActivity = nil
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
        model.setTotalMutingMode(item.1)
    }

    @objc func toggleLaunchAtLogin() {
        launchAtLoginHelper.isEnabled = !launchAtLoginHelper.isEnabled
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
            item.state = (isRunning && model.state.running!.configuration == configuration ? .on : .off)
//            item.isEnabled = !isRunning
        }
        
        if let timeTillNextStretch = model.state.timeTillNextStretch {
            nextStretchItem.title = "Next Stretching In \(timeTillNextStretch.shortString)"
        } else {
            nextStretchItem.title = "Stretching Paused"
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

        launchAtLoginItem.state = (launchAtLoginHelper.isEnabled ? .on : .off)

        stopItem.isHidden = !isRunning
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
}

private struct MutingSubmenu {
    
}

private extension NSMenuItem {
    
}


