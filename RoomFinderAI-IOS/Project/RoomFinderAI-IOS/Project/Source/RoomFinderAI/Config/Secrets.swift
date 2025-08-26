// MARK: - DO NOT COMMIT REAL SECRETS
// Replace with your actual values
enum Secrets {
  static let supabaseURL = "https://qzxoyzqoknywffwewrxi.supabase.co".trimmingCharacters(in: .whitespacesAndNewlines)
  static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6eG95enFva255d2Zmd2V3cnhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE5MzY0NzEsImV4cCI6MjAzNzUxMjQ3MX0.d2VDnCKX-8oJG3riFGCWLv8f5Pd8WcvgIWzjJnfKFn4".trimmingCharacters(in: .whitespacesAndNewlines)
  
  static func assertValid() {
    precondition(supabaseURL.hasPrefix("https://"), "Supabase URL must start with https://")
    precondition(supabaseURL.contains(".supabase.co"), "Use the Project URL ending with .supabase.co")
    precondition(!supabaseURL.contains("app.supabase.com"), "Do NOT use dashboard URL")
  }
}