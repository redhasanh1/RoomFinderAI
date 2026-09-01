import SwiftUI

struct DebugInfoView: View {
  @State private var status = "Checking..."
  
  var body: some View {
    NavigationView {
      VStack(alignment: .leading, spacing: 20) {
        Group {
          Text("AI Service Status")
            .font(.headline)
          
          VStack(alignment: .leading, spacing: 8) {
            Text("Provider: OpenAI")
            Text("Model: \(Secrets.openAIModel)")
            Text("Status: \(status)")
          }
          .font(.system(.body, design: .monospaced))
          .padding()
          .background(Color(.secondarySystemBackground))
          .cornerRadius(8)
        }
        
        Group {
          Text("Privacy")
            .font(.headline)
          
          VStack(alignment: .leading, spacing: 8) {
            Text("AI chats are processed by OpenAI")
            Text("See the Privacy Policy for details")
          }
          .font(.subheadline)
          .padding()
          .background(Color(.secondarySystemBackground))
          .cornerRadius(8)
        }
        
        Spacer()
      }
      .padding()
      .navigationTitle("Debug Info")
      .navigationBarTitleDisplayMode(.inline)
      .task {
        status = await OpenAIClient.shared.health()
      }
    }
  }
}

#Preview {
  DebugInfoView()
}