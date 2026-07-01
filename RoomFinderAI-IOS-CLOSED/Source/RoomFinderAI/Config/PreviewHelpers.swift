import SwiftUI
import Supabase

// MARK: - Preview Helpers
extension SupabaseClient {
    static var preview: SupabaseClient {
        // Create a preview client with fake credentials
        let url = URL(string: "https://preview.supabase.co")!
        return SupabaseClient(supabaseURL: url, supabaseKey: "preview-key")
    }
}

extension SimpleListingsViewModel {
    static var preview: SimpleListingsViewModel {
        SimpleListingsViewModel(supabaseClient: .preview)
    }
}