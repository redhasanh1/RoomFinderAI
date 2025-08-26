import SwiftUI
import Supabase
import CoreFoundation

struct ListingsScreen: View {
    let supabaseClient: SupabaseClient

    @State private var headStatus: String = "Not checked"
    @State private var rawJSON: String = "[]"
    @State private var errorText: String?
    @State private var debugLogs: String = ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Connectivity: \(headStatus)")
                    .foregroundStyle(headStatus.hasPrefix("ERROR") ? .red : .secondary)

                Divider()

                Text("Debug Logs")
                    .font(.headline)
                
                ScrollView {
                    Text(debugLogs)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 200)
                .background(Color(.systemGray6))

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
                    Button("Full Debug") { Task { await fullDebugSequence() } }
                        .buttonStyle(.borderedProminent)
                    Button("Load Listings") { Task { await loadListings() } }
                        .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Debug & Listings")
            .task { await fullDebugSequence() }
        }
    }

    // STEP 1: Dump raw URL string bytes to reveal hidden characters
    private func dumpURLStringBytes(_ s: String) -> String {
        var log = "▶ RAW URL STRING: [\(s)]  len=\(s.count)\n"
        for (i, u) in s.unicodeScalars.enumerated() {
            log += String(format: "  %03d: U+%04X (%@)\n", i, u.value, String(u))
        }
        if let url = URL(string: s) {
            log += "▶ Parsed URL: scheme=\(url.scheme ?? "nil") host=\(url.host ?? "nil") path=\(url.path)\n"
        } else {
            log += "▶ URL(string:) FAILED to parse\n"
        }
        return log
    }
    
    // STEP 2: Test known-good hosts
    private func testKnownGoodHosts() async -> String {
        var log = "=== Testing Known-Good Hosts ===\n"
        for test in ["https://google.com", "https://supabase.com"] {
            var req = URLRequest(url: URL(string: test)!)
            req.httpMethod = "HEAD"
            do {
                _ = try await URLSession.shared.data(for: req)
                log += "HEAD OK → \(test)\n"
            } catch {
                log += "HEAD FAIL → \(test) error: \(error)\n"
            }
        }
        return log
    }
    
    // STEP 3: DNS resolve the Supabase host directly  
    private func resolveHost(_ host: String) -> String {
        var log = ""
        guard let cfHost = CFHostCreateWithName(nil, host as CFString).takeRetainedValue() as CFHost? else { 
            log += "❌ CFHostCreateWithName failed for \(host)\n"
            return log
        }
        
        var resolved: DarwinBoolean = false
        if let addresses = CFHostGetAddressing(cfHost, &resolved)?.takeUnretainedValue() as NSArray?,
           resolved.boolValue, addresses.count > 0 {
            log += "✅ DNS resolved \(host) to \(addresses.count) addr(s)\n"
        } else {
            log += "❌ DNS could NOT resolve \(host)\n"
        }
        return log
    }
    
    // Full debug sequence
    private func fullDebugSequence() async {
        var log = "=== COMPREHENSIVE SUPABASE DEBUG ===\n\n"
        
        // STEP 1: Dump URL bytes
        log += "STEP 1 - URL Byte Analysis:\n"
        log += dumpURLStringBytes(Secrets.supabaseURL)
        log += "\n"
        
        // STEP 2: Test known-good hosts
        log += "STEP 2 - Known-Good Host Tests:\n"
        log += await testKnownGoodHosts()
        log += "\n"
        
        // STEP 3: DNS resolution
        log += "STEP 3 - DNS Resolution:\n"
        if let host = URL(string: Secrets.supabaseURL)?.host {
            log += resolveHost(host)
        } else {
            log += "❌ URL has no host\n"
        }
        log += "\n"
        
        // STEP 4: HEAD probe to Supabase
        log += "STEP 4 - Supabase HEAD Probe:\n"
        do {
            let url = URL(string: Secrets.supabaseURL)!
            var req = URLRequest(url: url)
            req.httpMethod = "HEAD"
            let (_, response) = try await URLSession.shared.data(for: req)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            log += "✅ HEAD successful - Status: \(statusCode)\n"
            headStatus = "Reachable ✅"
        } catch {
            log += "❌ HEAD failed: \(error)\n"
            headStatus = "ERROR: \(error)"
        }
        
        await MainActor.run {
            debugLogs = log
        }
    }
    
    // STEP 6: Load listings with SELECT
    private func loadListings() async {
        errorText = nil
        
        do {
            let response = try await supabaseClient
                .from("listings")
                .select("*")
                .execute()
            
            let data = response.data
            rawJSON = String(data: data, encoding: .utf8) ?? "<binary JSON>"
            
            var log = debugLogs
            log += "\nSTEP 6 - SELECT Query Results:\n"
            log += "✅ SELECT successful - Data length: \(data.count) bytes\n"
            
            await MainActor.run {
                debugLogs = log
            }
        } catch {
            errorText = "\(error)"
            rawJSON = "[]"
            
            var log = debugLogs
            log += "\nSTEP 6 - SELECT Query Results:\n"
            log += "❌ SELECT failed: \(error)\n"
            
            await MainActor.run {
                debugLogs = log
            }
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