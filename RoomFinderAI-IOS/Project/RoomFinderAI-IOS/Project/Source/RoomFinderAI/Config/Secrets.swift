import Foundation

enum Secrets {
  // Supabase (keep as-is)
  static let supabaseURL = "https://fkktwhjybuflxqzopaex.supabase.co"
  static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs"

  // 🔐 OpenAI (MY ACTUAL PROJECT KEY — do not read from Info.plist)
  private static let _rawKey =
    "sk-proj-CbQtehx5UM0V9mXWrdZnM-hP3l98a0ZVguNWb51K7G63M0dfChAziWYeIO_AOPE2cEnVGOcwyT3BlbkFJliQDGy85OmZ3UGhQS7RSltE9YKO_5qrdLaLEweqkbxs-dDtMy3FMf6Msuot00O58p9L9XQBucA"

  static var openAIKey: String {
    _rawKey
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: """, with: "\"")
      .replacingOccurrences(of: """, with: "\"")
      .replacingOccurrences(of: "'", with: "'")
      .replacingOccurrences(of: " ", with: "")
  }

  // Project keys do NOT need an org header
  static let openAIOrgID: String? = nil
  static let openAIModel = "gpt-4o-mini"

  static func assertValid() {
    precondition(openAIKey.hasPrefix("sk-"), "OpenAI key missing/malformed.")
  }
}