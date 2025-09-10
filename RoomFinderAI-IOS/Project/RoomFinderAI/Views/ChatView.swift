import SwiftUI

struct ChatView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Chat")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Chat functionality coming soon")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .padding(.top)
        .navigationBarHidden(true)
    }
}

#Preview {
    NavigationView {
        ChatView()
    }
}