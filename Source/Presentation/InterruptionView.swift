import Cocoa
import SwiftUI

class InterruptionController: NSObject, NSWindowDelegate {
    let appModel: AppModel
    var preferences: Preferences { appModel.preferences }
    
    init(appModel: AppModel) {
        self.appModel = appModel
        super.init()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var window: NSWindow?
    public var isVisible: Bool { window != nil }

    func setVisible(_ visible: Bool) {
        if visible {
            show()
        } else {
            hide()
        }
    }
    
    func show() {
        guard window == nil else { return }
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.window = window
        window.delegate = self
        window.level = .statusBar
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.title = NSLocalizedString("Interruption", comment: "Interruption window title")
        window.center()
        
        let view = InterruptionView()
            .environmentObject(appModel)
            .frame(
                width: 500,
                //                height: 350,
                alignment: .topLeading
            )
        let hosting = NSHostingView(rootView: view)
        window.contentView = hosting
        hosting.autoresizingMask = [.width, .height]
        
        window.center()
        window.makeKey()
        window.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
    
    func windowWillClose(_ notification: Notification) {
        appModel.endInterruption(action: .continueExcludingInterruption)
        window = nil
    }
}

struct InterruptionView: View {
    @EnvironmentObject var model: AppModel
    @State private var cause: String = ""
//    @State private var continueInterval: Bool = false
//    @State private var stopInterval: Bool = false
//    @State private var selected = 1

    var isRunningIntervalWorthContinuing: Bool { model.state.isRunningIntervalWorthContinuing }
    var isRecommendedToContinue: Bool {  model.state.isRecommendedToContinue }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Interrupted for:")
                Text(model.state.interruptionDuration.minutesColonSeconds)
            }
            .font(.body)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Why did you get interrupted?")
                ComboBox("call / notification / that annoying bob again", text: $cause, items: ["wife", "call", "toilet"])
            }
            //            VStack(alignment: .leading, spacing: 4) {
            //                Text("Why did you get interrupted?")
            //                TextField("call / notification / that annoying bob again", text: $cause)
            //            }
            
            //            Picker(selection: $selected, label: Text("Current interval:")) {
            //                Text("Stop").tag(1)
            //                Text("Continue (include interruption)").tag(2)
            //                Text("Continue (exclude interruption)").tag(3)
            //            }
            //                .pickerStyle(.radioGroup)
            
            HStack(alignment: .top) {
                //                if isRunningIntervalWorthContinuing {
                //                    Toggle(isOn: $continueInterval) {
                //                        Text("Continue interval")
                //                    }
                //                }
                Button(action: cancel) {
                    Text("Continue")
                        .frame(minWidth: 100)
                }
                .keyboardShortcut(.cancelAction)
                Button(action: subtract) {
                    Text("Subtract & Continue")
                }
                .keyboardShortcut(KeyboardShortcut("b"))
                Spacer()
                Button(action: stop) {
                    if isRunningIntervalWorthContinuing {
                        Text("Stop Interval")
                            .frame(minWidth: 100)
                    } else {
                        Text("Record")
                            .frame(minWidth: 100)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding()
        //            .onChange(of: isRecommendedToContinue) { newValue in
        //                continueInterval = false
        //                stopInterval = false
        //            }
    }

    func cancel() {
        model.endInterruption(action: .continueIncludingInterruption)
        record()
    }
    func subtract() {
        model.endInterruption(action: .continueExcludingInterruption)
        record()
    }
    func stop() {
        model.endInterruption(action: .stop)
        record()
    }
    
    private func record() {
        let cause = self.cause
        guard !cause.isEmpty else { return }
        Task.detached(priority: .background) {
            do {
                try await model.store.recordInterruption(reason: cause)
            } catch {
                eventLog.error("database op failed: \(String(reflecting: error))")
            }
        }
    }
}

struct InterruptionView_Previews: PreviewProvider {
    static var previews: some View {
        let view = InterruptionView()
            .environmentObject(AppModel.testing())
        Group {
            view
                .frame(width: 500)
        }
    }
}
