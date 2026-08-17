import SwiftUI

/// A room, shown natively.
///
/// Everything that is just information about the listing is rendered here.
/// The two actions that need an account and the site's own logic — contacting
/// the landlord and starting a negotiation — hand off to the web, so there is
/// one implementation of each rather than two that drift.
struct ListingDetailScreen: View {

    let listing: Listing

    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 20) {
                    titleBlock
                    if let description = listing.cleanDescription {
                        section("About this place") {
                            Text(description)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let address = listing.address?.nilIfEmpty {
                        section("Address") {
                            Text(address)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    actions
                }
                .padding(20)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle(listing.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: listing.detailURL) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share this room")
            }
        }
    }

    private var header: some View {
        AsyncImage(url: listing.imageURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                ZStack {
                    Theme.gradient
                    Image(systemName: "house.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(listing.title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(listing.displayLocation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Text(listing.priceText)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.brand)

                if listing.userVerified == true {
                    Label("Verified", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            if !listing.summaryLine.isEmpty {
                Text(listing.summaryLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.impact(.medium)
                // The negotiator needs the site's session and its own state, so
                // it opens on the tab that owns it rather than being rebuilt.
                state.route(to: .negotiator, url: AppConfig.url("ai-negotiator.html?listing=\(listing.id)"))
                dismiss()
            } label: {
                Label("Negotiate this rent", systemImage: "bubble.left.and.text.bubble.right.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Pushed rather than routed to a tab: messaging needs the site's
            // session and chat widget, and pushing keeps the user inside the
            // listing they were reading with a back button to return.
            NavigationLink {
                WebPageScreen(url: listing.detailURL, title: "Contact Host")
            } label: {
                Label("Contact host", systemImage: "envelope.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.brand.opacity(0.4), lineWidth: 1.5)
                    )
            }
            .simultaneousGesture(TapGesture().onEnded { Haptics.impact(.light) })
        }
        .padding(.top, 4)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}
