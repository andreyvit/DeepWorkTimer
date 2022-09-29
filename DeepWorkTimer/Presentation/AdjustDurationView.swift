import SwiftUI

struct AdjustDurationView: View {
    let adjuster: (TimeInterval) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                Text("Add:")
                    .frame(width: 30, alignment: .leading)
                Button(action: { adjuster(.minutes(1)) }) {
                    Text("+1m").frame(minWidth: 30)
                }
                Button(action: { adjuster(.minutes(5)) }) {
                    Text("+5m").frame(minWidth: 30)
                }
                Button(action: { adjuster(.minutes(25)) }) {
                    Text("+25m").frame(minWidth: 30)
                }
            }
            HStack(alignment: .center, spacing: 4) {
                Text("Sub:")
                    .frame(width: 30, alignment: .leading)
                Button(action: { adjuster(.minutes(-1)) }) {
                    Text("-1m").frame(minWidth: 30)
                }
                Button(action: { adjuster(.minutes(-5)) }) {
                    Text("-5m").frame(minWidth: 30)
                }
                Button(action: { adjuster(.minutes(-25)) }) {
                    Text("-25m").frame(minWidth: 30)
                }
            }
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.leading, .trailing], 24)
            .padding(.top, 3)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        AdjustDurationView(adjuster: { print("adjust(\($0)") })
    }
}
