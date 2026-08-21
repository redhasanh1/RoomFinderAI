import SwiftUI

/// The rooms you saved, natively.
///
/// This was favorites.html in a web view: the site's header, its own scrolling
/// inside the app's, and a heart that could not tell you it had failed. The
/// cards are the same `ListingCard` the feed draws, so a saved room looks like
/// the room you saved.
struct SavedScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = FavoritesService()
    @ObservedObject private var user = CurrentUser.shared

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Saved")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                }
                .navigationDestination(for: Listing.self) { ListingDetailScreen(listing: $0) }
        }
        .task {
            // Only on first appearance. Re-fetching every time the sheet is
            // shown would throw away a list already on screen and flash a
            // spinner over it.
            guard !service.hasLoadedOnce else { return }
            service.load()
        }
        // Signing in on the Profile tab while this is open must fill the list
        // rather than leave the signed-out message up.
        .onChange(of: user.email) { _, _ in service.load() }
    }

    @ViewBuilder
    private var content: some View {
        if !user.isSignedIn {
            message("Sign in to see your saved rooms",
                    "Rooms you save with the heart show up here.",
                    "heart")
        } else if service.isLoading && !service.hasLoadedOnce {
            ProgressView("Loading your saved rooms")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = service.errorMessage, service.listings.isEmpty {
            message("Couldn't load your saved rooms", error, "exclamationmark.triangle")
        } else if service.listings.isEmpty {
            message("Nothing saved yet",
                    "Tap the heart on a room and it will be here.",
                    "heart")
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(service.listings) { listing in
                    NavigationLink(value: listing) {
                        ListingCard(listing: listing)
                    }
                    .buttonStyle(.plain)
                    // The card is one thing to a screen reader, and the
                    // remove action belongs to it rather than to a separate
                    // button that VoiceOver would announce out of context.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(ListingCard(listing: listing).accessibilityLabel)
                    .accessibilityHint("Opens this room")
                    .accessibilityAction(named: "Remove from saved") {
                        Task { await service.remove(listing) }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await service.remove(listing) }
                        } label: {
                            Label("Remove from saved", systemImage: "heart.slash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable { service.load() }
    }

    private func message(_ title: String, _ detail: String, _ symbol: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(detail)
        }
    }
}
