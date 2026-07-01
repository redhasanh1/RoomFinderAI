import SwiftUI

struct DebugInfoView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var openAIStatus = "Checking..."
  
  var body: some View {
    NavigationView {
      List {
        Section("OpenAI Configuration") {
          Text("Key type: \(Secrets.openAIKey.hasPrefix("sk-proj-") ? "project" : "classic")")
          Text("Model: \(Secrets.openAIModel)")
          Text("Org ID: \(Secrets.openAIOrgID ?? "nil")")
        }
        
        Section("Health Check") {
          Text(openAIStatus)
            .foregroundColor(openAIStatus.contains("OK") ? .green : .red)
        }
        
        Section("Supabase") {
          Text("URL: \(Secrets.supabaseURL)")
          Text("Key: \(Secrets.supabaseAnonKey.prefix(20))...")
        }
      }
      .navigationTitle("Debug Info")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
      .task {
        openAIStatus = await OpenAIClient.shared.health()
      }
    }
  }
}