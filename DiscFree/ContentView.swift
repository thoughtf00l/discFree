import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "internaldrive")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("DiscFree")
                .font(.largeTitle.bold())

            Text("No scan yet")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 480, minHeight: 360)
        .padding()
    }
}

#Preview {
    ContentView()
}
