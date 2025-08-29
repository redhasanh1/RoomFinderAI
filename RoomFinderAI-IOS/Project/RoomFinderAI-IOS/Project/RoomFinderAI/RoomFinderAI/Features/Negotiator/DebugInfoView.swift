import SwiftUI

struct DebugInfoView: View {
  @State private var status = "Checking..."
  
  var body: some View {
    NavigationView {
      VStack(alignment: .leading, spacing: 20) {
        Group {
          Text("OpenAI Configuration")
            .font(.headline)
          
          VStack(alignment: .leading, spacing: 8) {
            Text("Key type: \(Secrets.openAIKey.hasPrefix("sk-proj-") ? "project" : "classic")")
            Text("Model: \(Secrets.openAIModel)")
            Text("Organization: \(Secrets.openAIOrgID ?? "nil")")
            Text("Status: \(status)")
          }
          .font(.system(.body, design: .monospaced))
          .padding()
          .background(Color(.secondarySystemBackground))
          .cornerRadius(8)
        }
        
        Group {
          Text("Supabase Configuration")
            .font(.headline)
          
          VStack(alignment: .leading, spacing: 8) {
            Text("URL: \(Secrets.supabaseURL)")
            Text("Key: \(String(Secrets.supabaseAnonKey.prefix(20)))...")
          }
          .font(.system(.body, design: .monospaced))
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