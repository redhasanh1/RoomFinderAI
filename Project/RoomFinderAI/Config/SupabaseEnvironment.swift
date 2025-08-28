import Foundation
import Supabase
import SwiftUI

struct SupabaseKey: EnvironmentKey {
  static let defaultValue = SupabaseClient(
    supabaseURL: URL(string: Secrets.supabaseURL)!,
    supabaseKey: Secrets.supabaseAnonKey
  )
}
extension EnvironmentValues { var supabase: SupabaseClient { get { self[SupabaseKey.self] } set { self[SupabaseKey.self] = newValue } } }