import SwiftUI
import Supabase

struct ListingsScreen: View {
    let supabaseClient: SupabaseClient

    @State private var headStatus: String = "Not checked"
    @State private var rawJSON: String = "[]"
    @State private var errorText: String?

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Connectivity: \(headStatus)")
                    .foregroundStyle(headStatus.hasPrefix("ERROR") ? .red : .secondary)

                Divider()

                Text("Listings (raw JSON)")
                    .font(.headline)

                ScrollView {
                    Text(rawJSON)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                if let err = errorText {
                    Text("Error: \(err)").foregroundStyle(.red)
                }

                HStack {
                    Button("Reload") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                    Button("Try Decoding Example") { Task { await tryDecodingExample() } }
                }
            }
            .padding()
            .navigationTitle("Listings")
            .task { await load() }
        }
    }

    private func headProbe() async {
        do {
            let supabaseURL = URL(string: "https://qzxoyzqoknywffwewrxi.supabase.co")!
            var req = URLRequest(url: supabaseURL)
            req.httpMethod = "HEAD"
            _ = try await URLSession.shared.data(for: req)
            headStatus = "Reachable ✅"
        } catch {
            headStatus = "ERROR: \(error)"
        }
    }

    private func load() async {
        errorText = nil
        await headProbe()
        guard headStatus == "Reachable ✅" else { return }

        do {
            // Fetch ALL rows, no filters
            let response = try await supabaseClient
                .from("listings")
                .select("*")
                .execute()

            // Render raw JSON so schema mismatches can't hide data
            let data = response.data
            rawJSON = String(data: data, encoding: .utf8) ?? "<binary JSON>"
        } catch {
            errorText = "\(error)"
            rawJSON = "[]"
        }
    }

    private func tryDecodingExample() async {
        struct Listing: Codable, Identifiable {
            let id: String
            let title: String?
            let created_at: String?
        }
        do {
            let listings: [Listing] = try await supabaseClient
                .from("listings")
                .select("*")
                .order("created_at", ascending: false)
                .execute()
                .value
            let blob = try JSONEncoder().encode(listings)
            rawJSON = String(data: blob, encoding: .utf8) ?? "[]"
            errorText = nil
        } catch {
            errorText = "Decoding error (not fatal): \(error)"
        }
    }
}

struct SimpleConnectivityTestView: View {
    @State private var testResult = "Ready to test"
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Supabase Connectivity Test")
                .font(.title)
                .bold()
            
            Text(testResult)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .textSelection(.enabled)
            
            if isLoading {
                ProgressView()
            } else {
                Button("Test Connection") {
                    Task { await testConnection() }
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func testConnection() async {
        await MainActor.run {
            isLoading = true
            testResult = "Testing connection..."
        }
        
        let supabaseClient = SupabaseClient(
            supabaseURL: URL(string: "https://qzxoyzqoknywffwewrxi.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6eG95enFva255d2Zmd2V3cnhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE5MzY0NzEsImV4cCI6MjAzNzUxMjQ3MX0.d2VDnCKX-8oJG3riFGCWLv8f5Pd8WcvgIWzjJnfKFn4"
        )
        
        let supabaseURL = URL(string: "https://qzxoyzqoknywffwewrxi.supabase.co")!
        
        do {
            // Test HEAD request
            var req = URLRequest(url: supabaseURL)
            req.httpMethod = "HEAD"
            let (_, resp) = try await URLSession.shared.data(for: req)
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? -1
            
            if statusCode == 200 || statusCode == 404 {
                // Test SELECT query
                let response: [TestListing] = try await supabaseClient
                    .from("listings")
                    .select("id, title")
                    .limit(5)
                    .execute()
                    .value
                
                await MainActor.run {
                    testResult = """
                    ✅ CONNECTIVITY SUCCESS
                    
                    Supabase URL: \(supabaseURL)
                    HEAD status: \(statusCode)
                    SELECT query: ✅ Success
                    Listings found: \(response.count)
                    
                    🎉 Hostname resolves and database is accessible!
                    """
                }
            } else {
                await MainActor.run {
                    testResult = "❌ Server returned status \(statusCode)"
                }
            }
            
        } catch {
            await MainActor.run {
                testResult = """
                ❌ CONNECTION FAILED
                
                Error: \(error.localizedDescription)
                
                This is likely the "hostname could not be found" error.
                """
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}

private struct TestListing: Codable {
    let id: String
    let title: String?
}

struct ContentView: View {
    var body: some View {
        Text("This ContentView is not used - app shows ListingsScreen directly")
    }
}

#Preview {
    ContentView()
}