import SwiftUI

@main
struct RoomFinderAIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Text("RoomFinder AI")
                .font(.largeTitle)
                .padding()
            
            Text("Welcome to RoomFinder AI")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}