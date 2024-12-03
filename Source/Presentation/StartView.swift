import SwiftUI

struct StartView: View {
    @State var tab: String = "start"
    @State var bogus1: String = ""
    @State var bogus2: Int?

    var body: some View {
        VStack {
            TabView(selection: $tab) {
                StartDayView()
                .tabItem {
                    Label("Routines", systemImage: "square.and.arrow.up")
                }
                .tag("start")
                VStack {
                    StartWorkView()
        //            UnusedStartShallowWorkView()
                    StartRestView()
                }
                .tabItem {
                    Label("Work", systemImage: "square.and.arrow.up")
                }
                .tag("work")
                WelcomeView()
                .tabItem {
                    Label("Journey", systemImage: "square.and.arrow.up")
                }
                .tag("journey")
                VStack {
                    Text("TODO")
                }
                .tabItem {
                    Label("History", systemImage: "square.and.arrow.up")
                }
                .tag("history")
            }
//            StartDayView().padding(.bottom)
        }.scenePadding()
    }
}

struct StartView_Previews: PreviewProvider {
    static var previews: some View {
        StartView()
//            .frame(height: 500)
    }
}

struct StartDayView: View {
    @State var bogus: Bool = false
    @State var cm: String = ""
    @State var dummy: Int? = nil

    var body: some View {
        VStack {
            Text("Start your day")
                .font(.headline)
            //                    Button(action: {}) {
            //                        Text("Start Deep Work")
            //                                        }
            VStack(alignment: .leading) {
                if #available(macOS 13.0, *) {
                    Form {
                        Picker("Notify Me About:", selection: $dummy) {
                            Text("Direct Messages").tag(1)
                            Text("Mentions").tag(2)
                            Text("Anything").tag(3)
                        }
                        Toggle("Play notification sounds", isOn: $bogus)
                        Toggle("Send read receipts", isOn: $bogus)
                        
                        Picker("Profile Image Size:", selection: $dummy) {
                            Text("Large").tag(1)
                            Text("Medium").tag(2)
                            Text("Small").tag(3)
                        }
                        .pickerStyle(.inline)
                    }
                    .formStyle(.columns)
                }
                Toggle(isOn: $bogus) {
                    Text("Review Life Map")
                }
                Toggle(isOn: $bogus) {
                    HStack {
                        Text("Today's CM:")
                        TextField("CM", text: $cm, prompt: Text("do something"))
                    }
                    Text("Second-level label")
                    Text("Tertiary label")
                    Text("Qqq label")
                    Text("5 label")
                    Text("6 label")
                    Text("7 label")
                    Text("8 label")
                }
                HStack {
                    Text("Clear inboxes:")
                    Toggle(isOn: $bogus) {
                        Text("email")
                    }
                    Toggle(isOn: $bogus) {
                        Text("Asana")
                    }
                }
                TextField("CM", text: $cm, prompt: Text("do something"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Menu("Start My Day") {
                Button("Skip Today", action: {})
            } primaryAction: {
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.top)
        }
    }
}

struct StartWorkView: View {
    @State var bogus1: String = ""
    @State var bogus2: Int?

    var body: some View {
        VStack {
            //                    Text("Work")
            //                        .font(.headline)
            //                    Button(action: {}) {
            //                        Text("Start Deep Work")
            //                                        }
            VStack(alignment: .leading, spacing: 4) {
                Text("Starting working on:")
                TextField("major feature", text: $bogus1)
            }
            Picker("Energy:", selection: $bogus2) {
                Text("A")
                    .keyboardShortcut(KeyboardShortcut("a"))
                Text("B")
                Text("C")
                Text("F")
            }
            .pickerStyle(.segmented)
            VStack {
                Menu("Start Deep Work for 50m") {
                    Button("Deep Work for 50m", action: {})
                    Button("Deep Work for 25m", action: {})
                    Divider()
                    Button("Shallow Work for 50m", action: {})
                    Button("Shallow Work for 25m", action: {})
                    Button("Shallow Work for 15m", action: {})
                    Button("Shallow Work for 5m", action: {})
                } primaryAction: {
                }
                .keyboardShortcut(KeyboardShortcut("d"))
                Menu("Start Shallow Work for 25m") {
                    Button("Deep Work for 50m", action: {})
                    Button("Deep Work for 25m", action: {})
                    Divider()
                    Button("Shallow Work for 50m", action: {})
                    Button("Shallow Work for 25m", action: {})
                    Button("Shallow Work for 15m", action: {})
                    Button("Shallow Work for 5m", action: {})
                } primaryAction: {
                }
                .keyboardShortcut(KeyboardShortcut("s"))
            }
            .padding(.top)
        }
    }
}

struct UnusedStartShallowWorkView: View {
    @State var bogus1: String = ""

    var body: some View {
        VStack {
            Text("Start Shallow Work")
                .font(.headline)
            //                    Button(action: {}) {
            //                        Text("Start Deep Work")
            //                    }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("What are you going to do?")
                TextField("talk to haider", text: $bogus1)
            }
            Menu("Shallow Work for 50m") {
                Button("Shallow Work for 50m", action: {})
                Button("Shallow Work for 25m", action: {})
                Button("Shallow Work for 15m", action: {})
                Button("Shallow Work for 5m", action: {})
            } primaryAction: {
            }
            .padding(.top)
        }
    }
}

struct StartRestView: View {
    var body: some View {
        VStack {
            Text("Start Rest")
                .font(.headline)
            
            //                    Grid {
            //                        GridRow {
            //                            Text("Today:")
            //                            Text("15m")
            //                        }
            //                    }
            Text("Today: 15m (1 interval)")
            //                    Button(action: {}) {
            //                        Text("Start Deep Work")
            //                    }
            Spacer()
            Menu("Rest for 10m") {
                Button("Order Now", action: {})
                Button("Adjust Order", action: {})
                Button("Cancel", action: {})
            } primaryAction: {
            }
            .padding(.top)
        }
    }
}
