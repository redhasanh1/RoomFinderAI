import Foundation
import Supabase

final class SupabaseClientProvider {
    static let shared = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey,
        options: SupabaseClientOptions(
            db: SupabaseClientOptions.DatabaseOptions(),
            auth: SupabaseClientOptions.AuthOptions(
                persistSession: false,
                autoRefreshToken: false,
                detectSessionInUrl: false
            ),
            global: SupabaseClientOptions.GlobalOptions(
                headers: [
                    "X-Client-Info": "RoomFinderAI-iOS"
                ]
            )
        )
    )
    
    private init() {}
}