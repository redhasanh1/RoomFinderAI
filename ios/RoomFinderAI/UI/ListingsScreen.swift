import SwiftUI

/// The Listings tab, rendered natively from the API rather than in a web view.
///
/// Browsing rooms is what people open this app to do, so it is built the way
/// rentals apps are built: large photo cards you can judge a room from at a
/// glance, and category chips across the top to narrow the pile down. A dense
/// one-line-per-room list makes every room look the same, which is the one
/// thing a rentals browser must not do.
struct ListingsScreen: View {

    /// Home shows a hero above the rooms; the screen is otherwise identical,
    /// which is why there is one implementation rather than two that drift.
    var showsHero = false
    var title = "Listings"

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
                if showsHero { hero }

                // At the top, where people look for it. It was moved to the
                // bottom to be in reach of a thumb, but a search bar you have
                // to hunt for is worse than one you have to stretch to.
                searchBar

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
            // Value-based, and declared once for the whole stack. Driving this
            // from a bound item set inside the section rows opened nothing at
            // all when a room was tapped in "All rooms".
            .navigationDestination(for: Listing.self) { ListingDetailScreen(listing: $0) }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: query) { _, _ in scheduleSearch() }
            .toolbar {
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
            LazyVStack(alignment: .leading, spacing: 26) {
                if visibleListings.isEmpty {
                    EmptyResults(hasFilters: hasActiveFilters || category != .all,
                                 clear: clearFilters)
                        .padding(.top, 40)
                } else {
                    // Sections, not one undifferentiated column. A single run
                    // of identical cards gives no reason to look past the
                    // third one; grouping gives the page a shape and surfaces
                    // rooms that would otherwise be buried.
                    ForEach(sections) { section in
                        ListingSection(section: section)
                    }

                    HStack {
                        Text(resultsSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if hasActiveFilters || category != .all {
                            Button("Clear filters", action: clearFilters)
                                .font(.footnote.weight(.semibold))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
            .padding(.top, 4)
            // Clears the floating post button so the last room is reachable.
            .padding(.bottom, 96)
        }
    }

    /// How the rooms are grouped.
    ///
    /// Built from what is actually on screen rather than a fixed list, so a
    /// section never appears empty: a city with nothing under $1,200 simply
    /// does not get a Budget row.
    private var sections: [Section] {
        let rooms = visibleListings
        guard !rooms.isEmpty else { return [] }

        var result: [Section] = []

        // Newest first is what the API already returns.
        result.append(Section(id: "featured",
                              title: "Featured",
                              subtitle: "Newest rooms on RoomFinderAI",
                              style: .carousel,
                              listings: Array(rooms.prefix(8))))

        let affordable = rooms.filter { ($0.price ?? .greatestFiniteMagnitude) <= 1200 }
        if affordable.count >= 2 {
            result.append(Section(id: "budget",
                                  title: "Under $1,200",
                                  subtitle: "Easier on the rent",
                                  style: .carousel,
                                  listings: Array(affordable.prefix(8))))
        }

        let verified = rooms.filter { $0.userVerified == true }
        if verified.count >= 2 {
            result.append(Section(id: "verified",
                                  title: "Verified hosts",
                                  subtitle: "Identity checked by us",
                                  style: .carousel,
                                  listings: Array(verified.prefix(8))))
        }

        let shared = rooms.filter { ($0.bedrooms ?? 0) >= 2 }
        if shared.count >= 2 {
            result.append(Section(id: "shared",
                                  title: "Good for sharing",
                                  subtitle: "Two bedrooms or more",
                                  style: .carousel,
                                  listings: Array(shared.prefix(8))))
        }

        // Everything, so nothing is only reachable through a themed row.
        result.append(Section(id: "all",
                              title: category == .all ? "All rooms" : "All \(category.rawValue.lowercased())s",
                              subtitle: nil,
                              style: .list,
                              listings: rooms))

        return result
    }

    struct Section: Identifiable {
        enum Style { case carousel, list }
        let id: String
        let title: String
        let subtitle: String?
        let style: Style
        let listings: [Listing]
    }

    /// A compact banner, not a full-screen splash: on a browse screen the
    /// rooms are the point, and a hero that fills the viewport just means
    /// scrolling past it every single visit.
    private var hero: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Let the AI negotiate")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("We argue the rent down for you")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onTapGesture {
            Haptics.impact(.medium)
            state.selectedTab = .messages
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
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

    /// The search field and the filters, pinned above the tab bar.
    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.brand)

                TextField("Search by city or neighbourhood", text: $query)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .accessibilityIdentifier("listingSearchField")

                if !query.isEmpty {
                    Button {
                        Haptics.impact(.light)
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }

                // Say a city instead of typing it.
                DictationButton(text: $query, size: 24)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            // A filled capsule on a tinted bar reads as a bar, not a field.
            // This is the control people use most on this screen, so it gets a
            // solid surface, a brand-tinted edge and a little lift.
            .background(
                Capsule().fill(Color(.systemBackground))
            )
            .overlay(
                Capsule().strokeBorder(Theme.brand.opacity(0.35), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)

            filterMenu
                .padding(.horizontal, hasActiveFilters ? 14 : 13)
                .padding(.vertical, 12)
                .foregroundStyle(hasActiveFilters ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.brand))
                .background(
                    Capsule().fill(hasActiveFilters
                                   ? AnyShapeStyle(Theme.gradient)
                                   : AnyShapeStyle(Color(.systemBackground)))
                )
                .overlay(
                    Capsule().strokeBorder(
                        hasActiveFilters ? Color.clear : Theme.brand.opacity(0.35),
                        lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
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
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                // Says which filters are on rather than only that some are, so
                // a list that looks short has a visible reason.
                if let summary = activeFilterSummary {
                    Text(summary)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }
            }
        }
        .accessibilityLabel(activeFilterSummary.map { "Filters, \($0)" } ?? "Filters")
    }

    private var hasActiveFilters: Bool { maxPrice != nil || bedrooms != nil }

    /// The filters currently on, in the fewest words that still say which.
    private var activeFilterSummary: String? {
        var parts: [String] = []
        if let maxPrice { parts.append("under $\(Int(maxPrice))") }
        if let bedrooms { parts.append("\(bedrooms)+ bed") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

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
struct ListingCard: View {
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
        .frame(height: 168)
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

/// One titled group of rooms: a horizontal shelf for themed rows, a vertical
/// run of full-width cards for the complete set.
private struct ListingSection: View {

    let section: ListingsScreen.Section

    /// Rooms sit side by side once there is room for them. A single column of
    /// full-width cards on an iPad gives one room per screenful, each stretched
    /// far wider than its photo wants to be.
    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 460), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.title3.weight(.bold))
                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)

            switch section.style {
            case .carousel:
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(section.listings) { listing in
                            NavigationLink(value: listing) {
                                ShelfCard(listing: listing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

            case .list:
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(section.listings) { listing in
                        NavigationLink(value: listing) {
                            ListingCard(listing: listing)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

/// The card used inside a horizontal shelf — narrower than the full-width one,
/// but still photo-led so a room can be judged at a glance.
private struct ShelfCard: View {
    let listing: Listing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: listing.imageURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Theme.gradient.opacity(0.18)
                    }
                }
                .frame(width: 260, height: 160)
                .clipped()

                if listing.userVerified == true {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(.black.opacity(0.5)))
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(listing.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(listing.displayLocation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(listing.priceText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.brand)
            }
            .frame(width: 260, alignment: .leading)
            .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this room")
    }
}
