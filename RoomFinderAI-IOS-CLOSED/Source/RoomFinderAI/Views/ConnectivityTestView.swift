import SwiftUI
import Supabase

struct ConnectivityTestView: View {
    @Environment(\.supabase) private var supabase
    @State private var connectionStatus = "Testing..."
    @State private var networkDetails = ""
    @State private var listingsCount = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Supabase Connectivity Test")
                .font(.title)
                .bold()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Connection Status:")
                    .font(.headline)
                Text(connectionStatus)
                    .foregroundColor(connectionStatus.contains("✅") ? .green : .red)
                
                Text("Network Details:")
                    .font(.headline)
                Text(networkDetails)
                    .font(.system(.caption, design: .monospaced))
                
                Text("Listings Count: \(listingsCount)")
                    .font(.headline)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            Button("Test Again") {
                Task { await testConnection() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .task {
            await testConnection()
        }
    }
    
    private func testConnection() async {
        await MainActor.run {
            connectionStatus = "Testing connection..."
            networkDetails = ""
        }
        
        let supabaseURL = supabase.configuration.url
        
        await MainActor.run {
            networkDetails = "Supabase URL in use: \(supabaseURL)\n"
        }
        
        do {
            // Step 1: HEAD request test
            var req = URLRequest(url: supabaseURL)
            req.httpMethod = "HEAD"
            let (_, resp) = try await URLSession.shared.data(for: req)
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? -1
            
            await MainActor.run {
                networkDetails += "HEAD request status: \(statusCode)\n"
            }
            
            if statusCode == 200 {
                await MainActor.run {
                    connectionStatus = "✅ Hostname resolves and server reachable"
                }
                
                // Step 2: Test SELECT query
                await testSelectQuery()
            } else {
                await MainActor.run {
                    connectionStatus = "❌ Server reachable but returned status \(statusCode)"
                }
            }
            
        } catch {
            await MainActor.run {
                connectionStatus = "❌ NETWORK ERROR: \(error.localizedDescription)"
                networkDetails += "Error details: \(error)\n"
            }
        }
    }
    
    private func testSelectQuery() async {
        do {
            let response: [ListingResponse] = try await supabase
                .from("listings")
                .select()
                .limit(5)
                .execute()
                .value
            
            await MainActor.run {
                listingsCount = response.count
                networkDetails += "✅ SELECT query successful, found \(response.count) listings\n"
                if response.count > 0 {
                    connectionStatus += "\n✅ SELECT on listings returns \(response.count) rows"
                } else {
                    connectionStatus += "\n⚠️ SELECT works but no listings found"
                }
            }
            
        } catch {
            await MainActor.run {
                connectionStatus += "\n❌ SELECT query failed: \(error.localizedDescription)"
                networkDetails += "SELECT error: \(error)\n"
            }
        }
    }
}

// Simple response type for testing
private struct ListingResponse: Codable {
    let id: String
    let title: String?
}

#Preview {
    ConnectivityTestView()
        .environment(\.supabase, SupabaseFactory.makeClient())
}