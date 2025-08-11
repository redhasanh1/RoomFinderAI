import Foundation
import Supabase

final class SupabaseClientProvider {
    static let shared = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
    
    private init() {}
}