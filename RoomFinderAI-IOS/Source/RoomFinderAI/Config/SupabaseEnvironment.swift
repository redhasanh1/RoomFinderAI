import SwiftUI
import Supabase

// MARK: - Environment Key
private struct SupabaseClientKey: EnvironmentKey {
  static let defaultValue: SupabaseClient = {
    // Fallback client with bogus values to prevent accidental real calls in previews
    let url = URL(string: "https://invalid.local")!
    return SupabaseClient(supabaseURL: url, supabaseKey: "invalid")
  }()
}

extension EnvironmentValues {
  var supabase: SupabaseClient {
    get { self[SupabaseClientKey.self] }
    set { self[SupabaseClientKey.self] = newValue }
  }
}

// MARK: - Factory
enum SupabaseFactory {
  static func makeClient() -> SupabaseClient {
    let url = URL(string: Secrets.supabaseURL)!
    return SupabaseClient(
      supabaseURL: url,
      supabaseKey: Secrets.supabaseAnonKey
    )
  }
}