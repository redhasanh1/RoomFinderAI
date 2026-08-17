import SwiftUI

/// Home, rendered natively.
///
/// The website's homepage is a marketing page: a full-screen animated hero,
/// feature grids, 3D models. That is the right thing for a stranger arriving
/// from a search engine and the wrong thing for someone who has already
/// installed the app. This is the version for someone who is already here —
/// what's new, and one tap to each thing they came to do.
struct HomeScreen: View {

    @EnvironmentObject private var state: AppState
    @ObservedObject private var network = NetworkMonitor.shared
    @StateObject private var service = ListingsService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    hero
                    quickActions
                    recentRooms
                }
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            // A roomfinderai.com/roommate-matching.html link lands on Home and
            // pushes RoomPal from here, since it has no tab of its own.
            .navigationDestination(isPresented: $state.showRoomPal) { RoomPalScreen() }
            .navigationTitle("RoomFinderAI")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { MoreMenu() }
            }
            .refreshable {
                Haptics.impact(.light)
                service.load()
                try? await Task.sleep(for: .milliseconds(600))
            }
        }
        .task {
            if !service.hasLoadedOnce || service.listings.isEmpty { service.load() }
        }
        .onChange(of: network.isOnline) { wasOnline, isOnline in
            guard !wasOnline, isOnline, service.listings.isEmpty else { return }
            service.load()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Find your perfect deal")
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("Search rooms, then let the AI negotiate the rent for you.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.impact(.medium)
                state.selectedTab = .messages
            } label: {
                Label("Start negotiating", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.brandDeep)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(.white))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Get started")
                .font(.headline)
                .padding(.horizontal, 16)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ActionTile(title: "Browse rooms", symbol: "building.2.fill") {
                    state.selectedTab = .listings
                }
                // RoomPal lost its tab slot to the Post button, so Home is
                // its way in — one tap, and the same native screen.
                NavigationLink { RoomPalScreen() } label: {
                    ActionTileLabel(title: "Find a roommate", symbol: "person.2.fill")
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.select() })
                ActionTile(title: "Sublease", symbol: "calendar.badge.clock") {
                    state.open(AppConfig.url("sublease.html"))
                }
                ActionTile(title: "Saved rooms", symbol: "heart.fill") {
                    state.open(AppConfig.url("favorites.html"))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var recentRooms: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Newest rooms")
                    .font(.headline)
                Spacer()
                Button("See all") {
                    Haptics.select()
                    state.selectedTab = .listings
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)

            if service.listings.isEmpty {
                // Quiet on purpose: Home should never show an error banner for
                // a strip that is a convenience, not the point of the screen.
                Text(service.isLoading ? "Loading rooms…" : "No rooms to show yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(service.listings.prefix(8)) { listing in
                            NavigationLink {
                                ListingDetailScreen(listing: listing)
                            } label: {
                                HomeRoomCard(listing: listing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

private struct ActionTile: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            ActionTileLabel(title: title, symbol: symbol)
        }
        .buttonStyle(.plain)
    }
}

/// The tile's appearance, separated so a NavigationLink can wear it too.
private struct ActionTileLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.brand)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct HomeRoomCard: View {
    let listing: Listing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: listing.imageURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Theme.gradient.opacity(0.18)
                }
            }
            .frame(width: 240, height: 140)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
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
            .frame(width: 240, alignment: .leading)
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
