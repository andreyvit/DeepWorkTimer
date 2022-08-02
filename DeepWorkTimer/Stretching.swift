import SwiftUI

struct StretchingView: View {
    @ObservedObject var model = AppModel.shared
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Stand up, stretch, look away")
                .font(.headline)
                .padding(.bottom, 2)
            Text("→ Stand up, move a little bit, look into the distance.")
                .font(.body)
            HStack {
                Text((model.state.stretchingRemainingTime ?? 0).minutesColonSeconds)
                    .font(.body)
                Spacer()
                Button(action: model.endStretching) {
                    Text("Back to Work")
                }
            }
        }
            .padding()
    }
}

struct StretchingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StretchingView()
                .preferredColorScheme(.light)
            StretchingView()
                .preferredColorScheme(.light)
                .frame(width: 300)
            StretchingView()
                .preferredColorScheme(.light)
                .frame(width: 400)
            StretchingView()
                .preferredColorScheme(.dark)
        }
    }
}
