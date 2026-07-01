import Foundation

enum Secrets {
  // Supabase (unchanged)
  static let supabaseURL = "https://fkktwhjybuflxqzopaex.supabase.co"
  static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs"

  // 🔐 NEW OpenAI PROJECT key (paste EXACTLY; no spaces/newlines)
  private static let _rawKey =
    "sk-proj-zFRDbomQxBfV4CCY6Zinr5pf0EW4q-hMlWaihWMhOqtSEdHhHhJ_QmWZXDTYBFGXew-K2J3yAsWT3BlbkFJiB-CxD6QNVoq90ds6e-n826FS8-PUSAZ3OQqy110UdLXDsfhB-DXp6i84lKMxr7OB2FaEei1AA"

  static var openAIKey: String {
    _rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // ❗ Project keys MUST NOT send an org header. Keep this nil.
  static let openAIOrgID: String? = nil

  // Use the model I received with the key
  static let openAIModel = "gpt-3.5-turbo"

  static func assertValid() {
    precondition(openAIKey.hasPrefix("sk-"), "OpenAI key missing/malformed")
  }
}