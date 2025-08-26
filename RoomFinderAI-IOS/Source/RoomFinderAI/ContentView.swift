import SwiftUI
import Supabase

struct ContentView: View {
    @EnvironmentObject private var authViewModel: SimpleAuthViewModel
    @EnvironmentObject private var listingsViewModel: SimpleListingsViewModel
    @State private var selectedTab = 0
    @State private var showingLogin = false
    
    var body: some View {
        Group {
            // Check authentication status
            if authViewModel.isAuthenticated {
                // Main app interface for authenticated users
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                        .tag(0)
                    
                    ListingsView()
                        .tabItem {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                        }
                        .tag(1)
                    
                    ProfileView()
                        .tabItem {
                            Image(systemName: "person.fill")
                            Text("Profile")
                        }
                        .tag(2)
                    
                    SimpleConnectivityTestView()
                        .tabItem {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("Debug")
                        }
                        .tag(3)
                }
                .accentColor(.blue)
            } else {
                // Guest mode - show main app with login prompt
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                        .tag(0)
                    
                    ListingsView()
                        .tabItem {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                        }
                        .tag(1)
                    
                    // Profile tab shows login when not authenticated
                    LoginView()
                        .tabItem {
                            Image(systemName: "person.fill")
                            Text("Profile")
                        }
                        .tag(2)
                    
                    SimpleConnectivityTestView()
                        .tabItem {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("Debug")
                        }
                        .tag(3)
                }
                .accentColor(.blue)
            }
        }
        .preferredColorScheme(nil)
        .onAppear {
            authViewModel.checkAuthStatus()
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

#Preview {
    let supabaseClient = SupabaseClient(
        supabaseURL: URL(string: "https://qzxoyzqoknywffwewrxi.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6eG95enFva255d2Zmd2V3cnhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE5MzY0NzEsImV4cCI6MjAzNzUxMjQ3MX0.d2VDnCKX-8oJG3riFGCWLv8f5Pd8WcvgIWzjJnfKFn4"
    )
    
    return ContentView()
        .environmentObject(SimpleAuthViewModel())
        .environmentObject(SimpleListingsViewModel(supabaseClient: supabaseClient))
}