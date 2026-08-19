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
    @State private var isReporting = false
    @State private var photoIndex = 0
    @State private var isViewingPhotos = false
    /// Filled only when the API sent fewer photos than the listing has.
    @State private var extraPhotos: [URL] = []
    private let gallery = ListingGalleryService()

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
        // The photo used to run up under the navigation bar, which suited the
        // old edge-to-edge crop. Now that it is fitted rather than filled, the
        // top of the room was simply hidden behind the menu. Nothing on this
        // screen should sit under the bar.
        .navigationTitle(listing.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: listing.detailURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    // Guideline 1.2: reporting has to be reachable from the
                    // content itself, not buried in a settings screen.
                    Button(role: .destructive) {
                        Haptics.impact(.light)
                        isReporting = true
                    } label: {
                        Label("Report this listing", systemImage: "flag")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More options")
            }
        }
        .sheet(isPresented: $isReporting) {
            ReportSheet(
                targetType: .listing,
                targetId: listing.id,
                authorEmail: listing.userEmail
            )
        }
    }

    /// The API's photos when it sends them, otherwise whatever the fallback
    /// managed to read.
    private var photos: [URL] {
        let fromAPI = listing.galleryURLs
        return fromAPI.count > 1 ? fromAPI : (extraPhotos.isEmpty ? fromAPI : extraPhotos)
    }

    private var header: some View {
        let photos = self.photos

        return Group {
            if photos.count > 1 {
                // Swipeable, with dots. A room is sold on its photos and only
                // the first was ever reachable here.
                TabView(selection: $photoIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, url in
                        photoStage(url).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            } else {
                photoStage(photos.first)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4 / 3, contentMode: .fit)
        // Capped so a photo cannot push the rest of the screen away on an iPad.
        .frame(maxHeight: 420)
        .clipped()
        .onTapGesture {
            guard !photos.isEmpty else { return }
            Haptics.impact(.light)
            isViewingPhotos = true
        }
        .fullScreenCover(isPresented: $isViewingPhotos) {
            PhotoViewer(urls: photos, index: $photoIndex)
        }
        // Only when the API gave us one photo or none: a server that already
        // sends the full set makes this a no-op.
        .task {
            guard listing.galleryURLs.count <= 1 else { return }
            let found = await gallery.photos(for: listing.id)
            if found.count > 1 { extraPhotos = found }
        }
    }

    /// One photo, fitted rather than filled.
    ///
    /// This used to fill a fixed 260pt band across the full width. On an iPad
    /// that band is around a thousand points wide, so an ordinary photo was
    /// scaled up enormously and cropped to a strip through its middle.
    private func photoStage(_ url: URL?) -> some View {
        ZStack {
            Rectangle().fill(Color(.secondarySystemBackground))

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fit)
                case .empty:
                    ProgressView()
                default:
                    ZStack {
                        Theme.gradient
                        Image(systemName: "house.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
        }
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
            // Back to the native chat.
            //
            // This briefly opened the site's negotiator for the room, to reuse
            // the engine that actually messages landlords. That page pulls
            // Tailwind, Supabase and two sign-in SDKs on top of 156KB of HTML,
            // and inside a web view it sat blank long enough to read as frozen
            // — a worse experience than the chat it replaced. Reusing the
            // engine is still the right idea; embedding that page is not the
            // way to do it.
            Button {
                Haptics.impact(.medium)
                state.pendingNegotiationListing = listing
                state.selectedTab = .messages
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
