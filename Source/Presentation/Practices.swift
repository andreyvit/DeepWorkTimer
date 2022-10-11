//
//  Practices.swift
//  Deep Work Timer
//
//  Created by Andrey Tarantsov on 2022-10-10.
//

import SwiftUI

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
                        ForEach(0 ..< obnoxiousnessValues.count) { i in
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
            .padding()
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

struct PracticesView_Previews: PreviewProvider {
    static var previews: some View {
        PracticesView()
            .frame(width: 400, alignment: .topLeading)
   }
}
