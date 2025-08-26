import SwiftUI
import Supabase

enum Secrets {
  static let supabaseURL = "https://fkktwhjybuflxqzopaex.supabase.co"
  static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs"

  static func assertValid() {
    precondition(supabaseURL.hasPrefix("https://"), "Supabase URL must start with https://")
    precondition(supabaseURL.contains(".supabase.co"), "Must use .supabase.co domain")
    precondition(URL(string: supabaseURL)?.host?.hasSuffix(".supabase.co") == true, "Invalid host in Supabase URL")
    precondition(!supabaseAnonKey.isEmpty, "Anon key is empty")
  }
}

enum SupabaseFactory {
    static func makeClient() -> SupabaseClient {
        Secrets.assertValid()
        let url = URL(string: Secrets.supabaseURL)!
        return SupabaseClient(supabaseURL: url, supabaseKey: Secrets.supabaseAnonKey)
    }
}

private struct SupabaseClientKey: EnvironmentKey {
    static let defaultValue: SupabaseClient = {
        let url = URL(string: "https://invalid.local")!
        return SupabaseClient(supabaseURL: url, supabaseKey: "invalid")
    }()
}

extension EnvironmentValues {
    var supabase: SupabaseClient {
        get { self[SupabaseClientKey.self] }
        set { self[SupabaseClientKey.self] = newValue }
    }
}

struct ListingsScreen: View {
    @Environment(\.supabase) private var supabase

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
                }
            }
            .padding()
            .navigationTitle("Listings")
            .task { await load() }
        }
    }

    private func headProbe() async {
        do {
            let supabaseURL = URL(string: Secrets.supabaseURL)!
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
            let response = try await supabase
                .from("listings")
                .select("*")
                .execute()

            let data = response.data
            rawJSON = String(data: data, encoding: .utf8) ?? "<binary JSON>"
        } catch {
            errorText = "\(error)"
            rawJSON = "[]"
        }
    }
}

struct ContentView: View {
    var body: some View {
        ListingsScreen()
    }
}

#Preview {
    ContentView()
        .environment(\.supabase, SupabaseFactory.makeClient())
}