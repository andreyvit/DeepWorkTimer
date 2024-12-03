import SwiftUI
import Cocoa

class StretchingController {
    let appModel: AppModel
    var preferences: Preferences { appModel.preferences }
    
    init(appModel: AppModel) {
        self.appModel = appModel
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
    
    private func show() {
        guard window == nil else { return }
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.window = window
        window.level = .statusBar
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.title = NSLocalizedString("Still want to be healthy?", comment: "Stretching window title")
        window.center()

        let stretchingIdeas = preferences.randomStretchingIdeas()
        
        let view = StretchingView(stretchingIdeas: stretchingIdeas)
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
    }

    private func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

struct StretchingView: View {
    @EnvironmentObject var model: AppModel
    let stretchingIdeas: [String]
    
    var stretchingIdeasText: String {
        "Ideas:\n" + stretchingIdeas.enumerated().map { (el) in "\(el.0+1). \(el.1)" } .joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stand up. Look far into the distance. Blink. Stretch.").bold()
                .font(.title2)
                .fixedSize(horizontal: false, vertical: true)

//            Text("1. Stand up.").bold()
//
//            Text("2. Look far into the distance. Blink.").bold()
//
//            Text("3. Stretch.").bold()
            
            Text("Ideas:")
            
            ForEach(stretchingIdeas.indices, id: \.self) { index in
                Text("\(index+1). \(stretchingIdeas[index])")
                    .fixedSize(horizontal: false, vertical: true)
            }

//            Text("Moving 2-3 times an hour is crucial for your health.")
//                .padding(.top, 4)

            HStack {
                Text((model.state.stretchingRemainingTime ?? 0).minutesColonSeconds)
                    .font(.body)
                Spacer()
                Button(action: model.extendStretching) {
                    Text("Add 1 Minute")
                }
                Button(action: model.endStretching) {
                    Text("Back to Work")
                }
                    .keyboardShortcut(.cancelAction)
            }
                .padding(.top, 4)
        }
            .padding()
    }
}

struct StretchingView_Previews: PreviewProvider {
    static var previews: some View {
        let stretchingIdeas = Preferences.initial.randomStretchingIdeas()
        StretchingView(stretchingIdeas: stretchingIdeas)
            .environmentObject(AppModel.testing())
            .frame(width: 500)
    }
}
