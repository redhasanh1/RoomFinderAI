import Foundation

// MARK: - DO NOT COMMIT REAL SECRETS
// Replace with your actual values
enum Secrets {
  // Existing Supabase values (kept current)
  static let supabaseURL: String = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)
    ?? "https://qzxoyzqoknywffwewrxi.supabase.co".trimmingCharacters(in: .whitespacesAndNewlines)
  static let supabaseAnonKey: String = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String)
    ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6eG95enFva255d2Zmd2V3cnhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE5MzY0NzEsImV4cCI6MjAzNzUxMjQ3MX0.d2VDnCKX-8oJG3riFGCWLv8f5Pd8WcvgIWzjJnfKFn4".trimmingCharacters(in: .whitespacesAndNewlines)

  // 🚀 OpenAI (inserted credentials)
  static let openAIKey: String = (Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String)
    ?? "sk-proj-CbQtehx5UM0V9mXWrdZnM-hP3l98a0ZVguNWb51K7G63M0dfChAziWYeIO_AOPE2cEnVGOcwyT3BlbkFJliQDGy85OmZ3UGhQS7RSltE9YKO_5qrdLaLEweqkbxs-dDtMy3FMf6Msuot00O58p9L9XQBucA"
  static let openAIOrgID: String? = (Bundle.main.object(forInfoDictionaryKey: "OPENAI_ORG_ID") as? String)
    ?? "org-EPHQ1A3u0XIUZml6JABMgZzg"
  
  // Optional: model override via Info.plist key OPENAI_MODEL; fallback to default
  static let openAIModel: String = (Bundle.main.object(forInfoDictionaryKey: "OPENAI_MODEL") as? String)
    ?? "gpt-4o-mini"
  
  static func assertValid() {
    precondition(supabaseURL.hasPrefix("https://"), "Supabase URL must start with https://")
    precondition(supabaseURL.contains(".supabase.co"), "Use the Project URL ending with .supabase.co")
    precondition(!supabaseURL.contains("app.supabase.com"), "Do NOT use dashboard URL")
    
    // OpenAI validation (fail loudly if missing)
    precondition(!openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                 "OPENAI key is missing. Update Secrets.openAIKey or provide via Info.plist.")
    precondition(openAIKey.hasPrefix("sk-"), "Invalid OpenAI API key format. Must start with 'sk-'.")
  }
}