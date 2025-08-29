import SwiftUI
import Supabase

struct SampleSupabaseView: View {
    @Environment(\.supabase) private var supabase
    
    var body: some View {
        Text("Sample View")
            .task {
                // Example: read from table "todos"
                do {
                    let rows = try await supabase.database
                        .from("todos")
                        .select()
                    print(rows)
                } catch {
                    print("Supabase error:", error)
                }
            }
    }
}