import SwiftUI

struct WelcomeView: View {
    @State var stage: Int = 0
    var body: some View {
        VStack {
            if stage == 0 {
                WelcomeStep(advance: { stage = 1 })
            } else if stage == 1 {
                StartJourneyStep(advance: { stage = 2 })
            } else if stage == 2 {
                Text(
"""
**Episode 1: New Focus**




This app can be a tool, a coach and a virtual accountability buddy. You decide how deep you want to go.

Over the coming weeks we'll work on:

1. Maintaining focus without distractions.
2. Setting your goals.
3. Being accountable to yourself daily.

Deep Work Buddy will be your coach and virtual accountability buddy.



Deep Work Buddy helps you do your best work by g you through adoption of multiple habits

We'll teach you a number of habits
""")
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                PracticesView()
            }
        }
            .padding()
    }
}

struct PracticesView: View {
    @State var isStretchingOn: Bool = true
    @State var restAlertObnoxiousness: Int = 2
    @State var pickerSel: Int = 0
    
    let obnoxiousnessValues = ["Mild", "Obnoxious", "Very Obnoxious"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PracticeView("Prompt when time to rest", isOn: $isStretchingOn) {
                VStack {
                    Picker("Alert persistence:", selection: $restAlertObnoxiousness) {
                        ForEach(0 ..< 3) { i in
                            Text(obnoxiousnessValues[i])
                                .frame(maxWidth: .infinity)
                                .layoutPriority(-1)
                        }
                    }
                }
            }
            PracticeView("Stretching", isOn: $isStretchingOn) {
                VStack {
                    Picker("Suggest a break every", selection: $pickerSel) {
                        ForEach(20 ..< 25) { i in
                            Text("\(i) minutes")
                        }
                    }
                }
            }
        }
    }
}

struct PracticeView<Content: View>: View {
    var isOn: Binding<Bool>
    @State var pickerSel: Int = 0
    
    let title: LocalizedStringKey
    let settings: Content
    
    init(_ title: LocalizedStringKey, isOn: Binding<Bool>, @ViewBuilder settings: () -> Content) {
        self.title = title
        self.isOn = isOn
        self.settings = settings()
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: isOn) {
                Text(title)
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
                .toggleStyle(SwitchToggleStyle())
            if isOn.wrappedValue {
                settings
//                .animation(Animation.default, value: isOn)
            }
        }
    }
}

extension Shape {
    public func outlinedFill(_ color: Color, fillOpacity: Double) -> some View {
        self.fill(color.opacity(fillOpacity))
            .overlay(self.stroke(color))
    }
}

struct HabitsDiagram: View {
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .trailing) {
                Text("Focus Habits")
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).outlinedFill(Color.mint, fillOpacity: 0.33))
                Text("Goal-Setting Habits")
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).outlinedFill(Color.purple, fillOpacity: 0.33))
                    .offset(x: -8, y: 0)
                Text("Accountability Habits")
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).outlinedFill(Color.cyan, fillOpacity: 0.33))
                    .offset(x: 16, y: 0)
            }
            Image(systemName: "arrow.right")
            //                        .imageScale(.large)
                .resizable()
                .frame(width: 44, height: 44)
                .font(.system(size: 10, weight: .ultraLight, design: .default))
                .padding(.horizontal, 30)
            Text("You doing your best work")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.vertical, 24)
                .background(RoundedRectangle(cornerRadius: 8).outlinedFill(Color.green, fillOpacity: 0.33))
        }
    }
}

struct WelcomeStep: View {
    let advance: () -> Void

    var body: some View {
        VStack {
            Text("How Deep Work Buddy is going to help you")
                .font(.headline)
            HabitsDiagram()
                .fixedSize()
                .padding(.vertical)
            Text("This app helps you adopt multiple productivity habits that combine into a system that makes you unstopptable.")
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
//            Spacer()
            Button(action: advance) {
                Text("Start my journey")
            }
                .padding(.top)
        }
    }
}

struct StartJourneyStep: View {
    let advance: () -> Void

    var body: some View {
        VStack {
            Text("Your Journey")
                .font(.headline)
                .padding(.bottom)
            Text("Your journey is split into episodes. Each episode takes a number of steps to complete.")
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            JourneyView(advance: advance)
//            Text("You decide when to take the next step")
//                .padding(.vertical)
//                .multilineTextAlignment(.leading)
//                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: advance) {
                Text("I'm ready to work on my focus")
            }
                .padding(.top)
        }
    }
}

struct JourneyView: View {
    let advance: () -> Void

    var body: some View {
        List {
            Label("Welcome", systemImage: "checkmark.circle.fill")
            HStack {
                Label("Episode 1: New Focus", systemImage: "arrow.right")
                Spacer()
                Text("0 of 3 Steps").foregroundColor(.secondary)
            }
            HStack {
                Label("Episode 2: ", systemImage: "lock")
                    .foregroundColor(.secondary)
                Spacer()
                Text("? Steps").foregroundColor(.secondary)
            }
            ForEach(2 ..< 11) { i in
                HStack {
                    Label("Episode \(i): Under development", systemImage: "lock")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("? Steps").foregroundColor(.secondary)
                }
            }
        }
    }
}

//\n\nIt will:\n- guide you,\n- give occasional advise,\n- eventually be your virtual accountability buddy.

struct PracticesView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .frame(width: 500, alignment: .topLeading)
   }
}
