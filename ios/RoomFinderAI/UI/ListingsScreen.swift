import SwiftUI

/// The Listings tab, rendered natively from the API rather than in a web view.
///
/// Browsing rooms is what people open this app to do, so it is built the way
/// rentals apps are built: large photo cards you can judge a room from at a
/// glance, and category chips across the top to narrow the pile down. A dense
/// one-line-per-room list makes every room look the same, which is the one
/// thing a rentals browser must not do.
struct ListingsScreen: View {

    @EnvironmentObject private var state: AppState
    @ObservedObject private var network = NetworkMonitor.shared
    @ObservedObject private var moderation = ModerationService.shared
    @StateObject private var service = ListingsService()

    @State private var query = ""
    @State private var maxPrice: Double?
    @State private var bedrooms: Int?
    @State private var category: Category = .all
    @State private var searchTask: Task<Void, Never>?

    /// Property types, plus an "All". Derived from `propertyType`, which is
    /// what the website's own filters use.
    enum Category: String, CaseIterable, Identifiable {
        case all = "All"
        case apartment = "Apartment"
        case house = "House"
        case condo = "Condo"
        case studio = "Studio"
        case room = "Room"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .all:       return "square.grid.2x2"
            case .apartment: return "building.2"
            case .house:     return "house"
            case .condo:     return "building"
            case .studio:    return "square.split.bottomrightquarter"
            case .room:      return "bed.double"
            }
        }

        func matches(_ listing: Listing) -> Bool {
            guard self != .all else { return true }
            guard let type = listing.propertyType?.lowercased() else { return false }
            return type.contains(rawValue.lowercased())
        }
    }

    var body: some View {
        NavigationStack {
            // The category chips stay put through loading and failure. Having
            // the filters vanish while the page thinks, then reappear, makes
            // the screen feel like it is rebuilding itself.
            VStack(spacing: 0) {
                categoryStrip
                    .padding(.bottom, 10)

                if service.isLoading && service.listings.isEmpty {
                    LoadingCards()
                } else if let error = service.errorMessage, service.listings.isEmpty {
                    StatusScreen(
                        symbol: "wifi.exclamationmark",
                        title: "Couldn't load rooms",
                        message: error,
                        actionTitle: "Try Again",
                        action: reload
                    )
                } else {
                    content
                }
            }
            .navigationTitle("Listings")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Search by city or neighbourhood")
            .onChange(of: query) { _, _ in scheduleSearch() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
                ToolbarItem(placement: .topBarTrailing) { MoreMenu() }
            }
            .refreshable { await reloadAsync() }
        }
        .task {
            // Retries whenever the last attempt did not leave us with rooms.
            // Loading once and giving up meant a single failed request left the
            // tab showing an error for the rest of the session.
            if !service.hasLoadedOnce || service.errorMessage != nil || service.listings.isEmpty {
                reload()
            }
        }
        .onChange(of: network.isOnline) { wasOnline, isOnline in
            guard !wasOnline, isOnline, service.listings.isEmpty else { return }
            reload()
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if visibleListings.isEmpty {
                    EmptyResults(hasFilters: hasActiveFilters || category != .all,
                                 clear: clearFilters)
                        .padding(.top, 40)
                } else {
                    HStack {
                        Text(resultsSummary)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if hasActiveFilters || category != .all {
                            Button("Clear", action: clearFilters)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(.horizontal, 16)

                    ForEach(visibleListings) { listing in
                        NavigationLink {
                            ListingDetailScreen(listing: listing)
                        } label: {
                            ListingCard(listing: listing)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.top, 4)
            // Clears the floating post button so the last room is reachable.
            .padding(.bottom, 96)
        }
    }

    /// Horizontal chips. Filtered on the client because the rooms are already
    /// in memory — a round trip to change category would feel broken.
    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Category.allCases) { option in
                    let selected = option == category
                    Button {
                        Haptics.select()
                        category = option
                    } label: {
                        Label(option.rawValue, systemImage: option.symbol)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule().fill(selected
                                               ? AnyShapeStyle(Theme.gradient)
                                               : AnyShapeStyle(Color(.secondarySystemBackground)))
                            )
                            .foregroundStyle(selected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
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
            if hasActiveFilters || category != .all {
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

    private var resultsSummary: String {
        let count = visibleListings.count
        let noun = count == 1 ? "room" : "rooms"
        return category == .all ? "\(count) \(noun)" : "\(count) \(noun) · \(category.rawValue)"
    }

    /// Blocking has to actually hide something to mean anything, so blocked
    /// people's rooms are filtered out here rather than only being flagged.
    private var visibleListings: [Listing] {
        let blocked = moderation.blockedEmails
        return service.listings.filter { listing in
            guard category.matches(listing) else { return false }
            guard let author = listing.userEmail?.lowercased() else { return true }
            return !blocked.contains(author)
        }
    }

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
        // Let the request get going before the spinner retracts, or the pull
        // gesture snaps back as if nothing happened.
        try? await Task.sleep(for: .milliseconds(600))
    }

    private func clearFilters() {
        Haptics.impact(.light)
        maxPrice = nil
        bedrooms = nil
        category = .all
        query = ""
        service.load()
    }
}

/// A room, big enough to judge. The photo does the work — everything else is
/// laid over or under it in one glance-able block.
private struct ListingCard: View {
    let listing: Listing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                CardImage(url: listing.imageURL)

                if listing.userVerified == true {
                    Label("Verified", systemImage: "checkmark.seal.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.black.opacity(0.55)))
                        .padding(10)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(listing.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Label(listing.displayLocation, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(listing.priceText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.brand)

                    if !listing.summaryLine.isEmpty {
                        Text(listing.summaryLine)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        // One element per card. VoiceOver otherwise reads the badge, title,
        // city, price and summary as five separate stops per room.
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this room")
    }
}

private struct CardImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                placeholder(showIcon: true)
            default:
                placeholder(showIcon: false)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func placeholder(showIcon: Bool) -> some View {
        ZStack {
            Theme.gradient.opacity(0.18)
            if showIcon {
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }
}

private struct EmptyResults: View {
    let hasFilters: Bool
    let clear: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 42))
                .foregroundStyle(Theme.gradient)
            Text("No rooms match")
                .font(.title3.weight(.semibold))
            Text(hasFilters
                 ? "Try a different category, city, or raise the price filter."
                 : "Nothing is listed here yet. Pull down to refresh.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if hasFilters {
                Button("Clear filters", action: clear)
                    .font(.headline)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

/// Card-shaped skeletons, so the layout does not jump when rooms arrive.
private struct LoadingCards: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 200)
                        VStack(alignment: .leading, spacing: 8) {
                            bar(width: 220)
                            bar(width: 150)
                            bar(width: 110)
                        }
                        .padding(14)
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }

    private func bar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.secondarySystemBackground))
            .frame(width: width, height: 13)
    }
}
