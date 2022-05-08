import Cocoa
import SwiftUI

@main
struct DeepWorkTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    var popover: NSPopover!
    
    var statusBarItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let menu = NSMenu()
        
        let contentView = ContentView()
        let contentController = NSHostingController(rootView: contentView)
        contentController.view.frame.size = CGSize(width: 200, height: 50)
        let customMenuItem = NSMenuItem()
        customMenuItem.view = contentController.view
        menu.addItem(customMenuItem)

        menu.addItem(NSMenuItem.separator())

        let aboutMenuItem = NSMenuItem(title: "About Deep Work Timer", action: #selector(about), keyEquivalent: "")
        aboutMenuItem.target = self
        menu.addItem(aboutMenuItem)
        
        let quitMenuItem = NSMenuItem(title: "Quit Deep Work Timer", action: #selector(quit), keyEquivalent: "")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        statusBarItem.button!.image = NSImage(named: "Timer")!
        statusBarItem.menu = menu
    }
        
    @objc func about(sender: NSMenuItem) {
        NSApp.orderFrontStandardAboutPanel()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quit(sender: NSMenuItem) {
        NSApp.terminate(self)
    }
}
