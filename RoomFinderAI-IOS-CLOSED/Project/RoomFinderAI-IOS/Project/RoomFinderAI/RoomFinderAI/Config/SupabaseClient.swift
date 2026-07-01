import Foundation
import Supabase

// MARK: - Supabase Client Factory
enum SupabaseClientFactory {
    static func makeClient() -> SupabaseClient {
        guard let url = URL(string: Secrets.supabaseURL) else {
            fatalError("Invalid Supabase URL: \(Secrets.supabaseURL)")
        }
        
        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Secrets.supabaseAnonKey,
            options: SupabaseClientOptions(
                db: .init(
                    schema: "public"
                ),
                realtime: .init(
                    connectOnSubscribe: true,
                    timeout: 10,
                    heartbeatInterval: 30,
                    reconnectDelay: 2
                )
            )
        )
        
        print("🔧 Supabase client initialized")
        print("   - URL: \(Secrets.supabaseURL)")
        print("   - Key: \(Secrets.supabaseAnonKey.prefix(20))...")
        
        return client
    }
}

// MARK: - Preview Client
extension SupabaseClient {
    static var preview: SupabaseClient {
        let url = URL(string: "https://preview.supabase.co")!
        return SupabaseClient(supabaseURL: url, supabaseKey: "preview-key")
    }
}