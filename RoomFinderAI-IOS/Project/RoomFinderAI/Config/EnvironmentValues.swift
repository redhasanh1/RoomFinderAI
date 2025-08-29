import SwiftUI
import Supabase

struct SupabaseKey: EnvironmentKey {
  static let defaultValue: SupabaseClient = {
    let url = URL(string: Secrets.supabaseURL)!
    return SupabaseClient(
      supabaseURL: url,
      supabaseKey: Secrets.supabaseAnonKey
    )
  }()
}

extension EnvironmentValues {
  var supabase: SupabaseClient {
    get { self[SupabaseKey.self] }
    set { self[SupabaseKey.self] = newValue }
  }
}