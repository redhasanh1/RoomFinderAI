import SwiftUI
import Supabase

struct DebugConnectivityView: View {
    @State private var connectionStatus = "Testing..."
    @State private var networkDetails = ""
    @State private var listingsCount = 0
    @State private var realtimeEvents: [String] = []
    @State private var isRealtimeConnected = false
    
    private let supabaseClient: SupabaseClient
    
    init() {
        self.supabaseClient = SupabaseClient(
            supabaseURL: URL(string: "https://qzxoyzqoknywffwewrxi.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6eG95enFva255d2Zmd2V3cnhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE5MzY0NzEsImV4cCI6MjAzNzUxMjQ3MX0.d2VDnCKX-8oJG3riFGCWLv8f5Pd8WcvgIWzjJnfKFn4"
        )
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Connection Status Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connection Status")
                            .font(.headline)
                        
                        Text(connectionStatus)
                            .foregroundColor(connectionStatus.contains("✅") ? .green : .red)
                            .font(.body)
                        
                        if !networkDetails.isEmpty {
                            Text(networkDetails)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        
                        Text("Listings Found: \(listingsCount)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Realtime Status Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Realtime Status")
                                .font(.headline)
                            
                            Spacer()
                            
                            Circle()
                                .fill(isRealtimeConnected ? .green : .red)
                                .frame(width: 12, height: 12)
                        }
                        
                        if realtimeEvents.isEmpty {
                            Text("No realtime events yet")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Recent Events (\(realtimeEvents.count)):")
                                .font(.subheadline)
                            
                            ForEach(Array(realtimeEvents.suffix(5).enumerated()), id: \.offset) { _, event in
                                Text(event)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.vertical, 2)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Test Buttons
                    VStack(spacing: 12) {
                        Button("Test Connection") {
                            Task { await testConnection() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button("Test Realtime") {
                            Task { await testRealtime() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Debug Connectivity")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await testConnection()
            }
        }
    }
    
    private func testConnection() async {
        await MainActor.run {
            connectionStatus = "Testing connection..."
            networkDetails = ""
            listingsCount = 0
        }
        
        let supabaseURL = supabaseClient.configuration.url
        
        await MainActor.run {
            networkDetails = "Supabase URL: \(supabaseURL)\n"
        }
        
        do {
            // Step 1: HEAD request test
            print("🔍 Testing HEAD request to: \(supabaseURL)")
            var req = URLRequest(url: supabaseURL)
            req.httpMethod = "HEAD"
            let (_, resp) = try await URLSession.shared.data(for: req)
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? -1
            
            await MainActor.run {
                networkDetails += "HEAD status: \(statusCode)\n"
            }
            
            print("📡 HEAD request status: \(statusCode)")
            
            if statusCode == 200 || statusCode == 404 {
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
            print("❌ Network error: \(error)")
            await MainActor.run {
                connectionStatus = "❌ NETWORK ERROR: \(error.localizedDescription)"
                networkDetails += "Error: \(error)\n"
            }
        }
    }
    
    private func testSelectQuery() async {
        print("🔍 Testing SELECT query on listings...")
        
        do {
            // Simple query to test database connectivity
            let response: [ListingTestModel] = try await supabaseClient
                .from("listings")
                .select("id, title")
                .limit(5)
                .execute()
                .value
            
            print("📊 SELECT query successful, found \(response.count) listings")
            
            await MainActor.run {
                listingsCount = response.count
                networkDetails += "✅ SELECT successful (\(response.count) records)\n"
                if response.count > 0 {
                    connectionStatus += "\n✅ SELECT on listings returns \(response.count) rows"
                } else {
                    connectionStatus += "\n⚠️ SELECT works but no listings found"
                }
            }
            
        } catch {
            print("❌ SELECT query error: \(error)")
            await MainActor.run {
                connectionStatus += "\n❌ SELECT query failed: \(error.localizedDescription)"
                networkDetails += "SELECT error: \(error)\n"
            }
        }
    }
    
    private func testRealtime() async {
        print("🔍 Testing realtime connection...")
        
        await MainActor.run {
            realtimeEvents.append("🚀 Starting realtime test...")
        }
        
        let channel = supabaseClient.channel("debug-test")
            .on(.postgresChanges, event: .insert, schema: "public", table: "listings") { payload in
                Task { @MainActor in 
                    self.realtimeEvents.append("✅ INSERT: \(payload)")
                }
            }
            .on(.system, event: .join) { _ in
                Task { @MainActor in
                    self.isRealtimeConnected = true
                    self.realtimeEvents.append("🎉 Realtime connected!")
                }
            }
            .on(.system, event: .error) { payload in
                Task { @MainActor in
                    self.realtimeEvents.append("❌ Realtime error: \(payload)")
                }
            }
        
        do {
            try await channel.subscribe()
            await MainActor.run {
                realtimeEvents.append("📡 Subscription request sent")
            }
            print("📡 Realtime subscription successful")
        } catch {
            print("❌ Realtime error: \(error)")
            await MainActor.run {
                realtimeEvents.append("❌ Subscription failed: \(error.localizedDescription)")
            }
        }
    }
}

// Simple model for testing SELECT queries
private struct ListingTestModel: Codable {
    let id: String
    let title: String?
}

#Preview {
    DebugConnectivityView()
}