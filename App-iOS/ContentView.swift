import SwiftUI
import Shared

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.springSurface.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("라운드온")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Color.springTextPrimary)
                Text("Round-On")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.springTextSecondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
