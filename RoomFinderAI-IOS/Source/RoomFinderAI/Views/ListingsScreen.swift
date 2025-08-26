import SwiftUI
import Supabase

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
            // Get the URL from the supabase client - need to use a workaround since configuration isn't public
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
        guard headStatus == "Reachable ✅" else { return } // URL/DNS must be correct first

        do {
            // Fetch ALL rows, no filters. If you have a created_at column, you may order it, but not required.
            let response = try await supabase
                .from("listings")
                .select("*")                // no where clause, no pagination
                .execute()

            // Render raw JSON so schema mismatches can't hide data.
            if let data = response.data {
                // response.data is `Data?` in recent supabase-swift; if not, fall back below
                rawJSON = String(data: data, encoding: .utf8) ?? "<binary JSON>"
            } else {
                // Generic fallback using typed decode then re-encode
                let rows: [[String: Any]] = try response.value
                let blob = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted])
                rawJSON = String(data: blob, encoding: .utf8) ?? "[]"
            }
        } catch {
            errorText = "\(error)"
            rawJSON = "[]"
        }
    }

    private func tryDecodingExample() async {
        struct Listing: Decodable, Identifiable {
            let id: String
            let title: String?
            let created_at: String?
            // Add other columns if you want; optional to avoid decode failures
        }
        do {
            let listings: [Listing] = try await supabase
                .from("listings")
                .select("*")
                .order("created_at", ascending: false) // only if column exists
                .execute()
                .value
            // If this works, you can swap UI to a List(listings) {}
            let blob = try JSONEncoder().encode(listings)
            rawJSON = String(data: blob, encoding: .utf8) ?? "[]"
            errorText = nil
        } catch {
            errorText = "Decoding error (not fatal): \(error)"
        }
    }
}