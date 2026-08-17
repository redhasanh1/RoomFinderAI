import SwiftUI

/// The Listings tab, rendered natively from the API rather than in a web view.
///
/// Browsing and searching rooms is what people open this app to do, so it is
/// the part worth building properly: a real search field, real filters, real
/// scrolling, images that cache, and results that keep working after the
/// connection drops. It is also the app's answer to App Review guideline 4.2 —
/// the primary task is native, not a framed web page.
///
/// Contacting a landlord and negotiating still hand off to the site, which is
/// where that logic lives and where it stays current.
struct ListingsScreen: View {

    @EnvironmentObject private var state: AppState
    @ObservedObject private var network = NetworkMonitor.shared
    @StateObject private var service = ListingsService()

    @State private var query = ""
    @State private var maxPrice: Double?
    @State private var bedrooms: Int?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if service.isLoading && service.listings.isEmpty {
                    LoadingList()
                } else if let error = service.errorMessage, service.listings.isEmpty {
                    StatusScreen(
                        symbol: "wifi.exclamationmark",
                        title: "Couldn't load rooms",
                        message: error,
                        actionTitle: "Try Again",
                        action: reload
                    )
                } else if service.listings.isEmpty && service.hasLoadedOnce {
                    StatusScreen(
                        symbol: "magnifyingglass",
                        title: "No rooms match",
                        message: "Try a different city, or raise the price filter.",
                        actionTitle: "Clear Filters",
                        action: clearFilters
                    )
                } else {
                    listingsList
                }
            }
            .navigationTitle("Listings")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Search by city or neighbourhood")
            .onChange(of: query) { _, _ in scheduleSearch() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
            .refreshable { await reloadAsync() }
        }
        .task {
            // Retries whenever the last attempt did not leave us with rooms.
            // Loading once and giving up meant a single failed request — a
            // slow response on launch, a moment without signal — left the tab
            // showing an error screen for the rest of the session, and the
            // only way out was knowing to pull down on it.
            if !service.hasLoadedOnce || service.errorMessage != nil || service.listings.isEmpty {
                reload()
            }
        }
        // Coming back online should fill the tab in by itself rather than
        // waiting to be asked.
        .onChange(of: network.isOnline) { wasOnline, isOnline in
            guard !wasOnline, isOnline, service.listings.isEmpty else { return }
            reload()
        }
    }

    private var listingsList: some View {
        List {
            if hasActiveFilters {
                Section {
                    Button(role: .destructive, action: clearFilters) {
                        Label("Clear filters", systemImage: "xmark.circle.fill")
                    }
                }
            }

            Section {
                ForEach(service.listings) { listing in
                    NavigationLink {
                        ListingDetailScreen(listing: listing)
                    } label: {
                        ListingRow(listing: listing)
                    }
                }
            } header: {
                Text("\(service.listings.count) \(service.listings.count == 1 ? "room" : "rooms")")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var filterMenu: some View {
        Menu {
            Menu("Max rent") {
                ForEach([800, 1200, 1600, 2000, 3000], id: \.self) { limit in
                    Button {
                        Haptics.select()
                        maxPrice = Double(limit)
                        reload()
                    } label: {
                        Label("Under $\(limit)", systemImage: maxPrice == Double(limit) ? "checkmark" : "")
                    }
                }
            }
            Menu("Bedrooms") {
                ForEach(1...4, id: \.self) { count in
                    Button {
                        Haptics.select()
                        bedrooms = count
                        reload()
                    } label: {
                        Label("\(count)+ bedrooms", systemImage: bedrooms == count ? "checkmark" : "")
                    }
                }
            }
            if hasActiveFilters {
                Divider()
                Button(role: .destructive, action: clearFilters) {
                    Label("Clear filters", systemImage: "xmark.circle")
                }
            }
        } label: {
            Image(systemName: hasActiveFilters
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filters")
    }

    private var hasActiveFilters: Bool { maxPrice != nil || bedrooms != nil }

    /// Debounced: typing a city name should not fire a request per keystroke.
    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            service.load(query: query, maxPrice: maxPrice, bedrooms: bedrooms)
        }
    }

    private func reload() {
        service.load(query: query, maxPrice: maxPrice, bedrooms: bedrooms)
    }

    private func reloadAsync() async {
        Haptics.impact(.light)
        reload()
        // Let the request actually get going before the spinner retracts,
        // otherwise the pull gesture snaps back as if nothing happened.
        try? await Task.sleep(for: .milliseconds(600))
    }

    private func clearFilters() {
        Haptics.impact(.light)
        maxPrice = nil
        bedrooms = nil
        query = ""
        service.load()
    }
}

private struct ListingRow: View {
    let listing: Listing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ListingThumbnail(url: listing.imageURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(listing.displayLocation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !listing.summaryLine.isEmpty {
                    Text(listing.summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(listing.priceText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.brand)

                    if listing.userVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .accessibilityLabel("Verified host")
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        // One element per row instead of five. VoiceOver otherwise reads the
        // title, the city, the bed count and the price as four separate stops,
        // so getting past a screen of rooms takes dozens of swipes.
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this room")
    }
}

private struct ListingThumbnail: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                placeholder(symbol: "photo")
            default:
                placeholder(symbol: nil)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func placeholder(symbol: String?) -> some View {
        ZStack {
            Rectangle().fill(Color(.secondarySystemBackground))
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(.tertiary)
            } else {
                ProgressView()
            }
        }
    }
}

/// Skeleton rows rather than a bare spinner: the list keeps its shape while
/// loading, so nothing jumps when the real rows arrive.
private struct LoadingList: View {
    var body: some View {
        List(0..<6, id: \.self) { _ in
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: 8) {
                    bar(width: 180)
                    bar(width: 120)
                    bar(width: 90)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.insetGrouped)
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }

    private func bar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.secondarySystemBackground))
            .frame(width: width, height: 12)
    }
}
