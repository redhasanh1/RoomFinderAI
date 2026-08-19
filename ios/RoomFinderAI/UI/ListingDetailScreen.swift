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

    /// Watched so this room's line updates as its negotiation moves, without
    /// the tenant having to go to Messages to find out whether anything is
    /// happening.
    @ObservedObject private var campaign = NegotiationCampaign.shared

    @State private var thread: Conversation?
    @State private var isOpeningThread = false
    @State private var threadProblem: String?

    /// Finds or starts the thread with this room's owner, then opens it.
    ///
    /// Idempotent server-side, so tapping twice does not produce two threads —
    /// which is what the old flow did, because the first tap gave no sign it
    /// had done anything.
    private func openThread() async {
        guard !isOpeningThread else { return }
        guard let me = CurrentUser.shared.email else {
            threadProblem = "Sign in on the Profile tab first to message a host."
            return
        }

        isOpeningThread = true
        threadProblem = nil
        defer { isOpeningThread = false }

        var request = URLRequest(url: AppConfig.url("api/conversations"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "listingId": listing.id,
            "userEmail": me
        ])

        struct Opened: Decodable {
            struct Payload: Decodable { let id: String; let landlordEmail: String? }
            let data: Payload?
            let message: String?
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let decoded = try? JSONDecoder().decode(Opened.self, from: data) else {
            threadProblem = "Couldn't reach the host. Check your connection."
            return
        }

        guard let opened = decoded.data,
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            // The server's own words: "That's your own listing" is more use
            // than a status code.
            threadProblem = decoded.message ?? "Couldn't open that conversation."
            return
        }

        thread = Conversation(
            id: opened.id,
            context: "listing",
            otherParty: opened.landlordEmail,
            subject: listing.title,
            lastMessage: nil,
            lastMessageAt: nil,
            unreadCount: 0
        )
    }

    /// Where this room stands, or nil when nothing has been started for it.
    private var negotiationStatus: (text: String, symbol: String, tint: Color)? {
        if let running = campaign.active.first(where: { $0.listingID == listing.id }) {
            switch running.phase {
            case .idle, .starting:
                return ("Your AI is messaging the landlord now", "paperplane.fill", .secondary)
            case .waitingForLandlord:
                return ("Sent — waiting for the landlord to reply", "clock.fill", .secondary)
            case .replying:
                return ("The landlord replied. Your AI is answering", "pencil", .secondary)
            case .closed(let price, _):
                return (price.map { "The landlord agreed to $\($0) a month" } ?? "The landlord agreed",
                        "checkmark.seal.fill", .green)
            case .failed(let message):
                return (message, "exclamationmark.triangle.fill", .orange)
            }
        }
        if campaign.queued.contains(where: { $0.id == listing.id }) {
            return ("Ready to go — confirm your goals to send the first message",
                    "hand.raised.fill", .secondary)
        }
        return nil
    }

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
                    MoreMenuLabel()
                }
                .accessibilityLabel("More options")
            }
        }
        // Pushed once the thread exists, so the tap goes straight into the
        // conversation rather than to a screen that then has to load one.
        .navigationDestination(item: $thread) { conversation in
            ConversationScreen(conversation: conversation, messaging: MessagingService())
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
            // Opens the negotiation itself, in the app.
            //
            // This has been through two wrong shapes: switching to the
            // assistant chat, which discussed the room but never contacted
            // anyone, and embedding the website's negotiator, which sat blank
            // long enough to look frozen. The thread with the landlord is now
            // native, so the messages are visible and nothing has to load a
            // page to get here.
            // Adds the room to the negotiation queue and hands over to
            // Messages. It used to push straight into a thread with this one
            // landlord, which meant a tenant chasing four rooms ran four
            // separate negotiations with no way to see them together — and
            // confirmed no goals before the first message went out.
            Button {
                Haptics.impact(.medium)
                state.queueForNegotiation(listing)
            } label: {
                Label("Negotiate this rent", systemImage: "bubble.left.and.text.bubble.right.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Says where this room stands without changing what the button
            // says. Tapping again is always fine; it just takes you to the
            // conversation.
            if let status = negotiationStatus {
                HStack(spacing: 6) {
                    Image(systemName: status.symbol)
                    Text(status.text)
                }
                .font(.caption)
                .foregroundStyle(status.tint)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            // Opens the thread here, natively.
            //
            // This used to push a web view of the site's listing page and leave
            // the person to find the contact form inside it — a browser, in an
            // app, to send a message the app can already send. The thread it
            // opens is the same one the negotiator and the inbox use.
            Button {
                Haptics.impact(.light)
                Task { await openThread() }
            } label: {
                HStack(spacing: 8) {
                    if isOpeningThread {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                    }
                    // "Message", not "Contact host": it opens a chat, and an
                    // envelope promised email.
                    Text(isOpeningThread ? "Opening…" : "Message host")
                }
                .font(.headline)
                .foregroundStyle(Theme.brand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.brand.opacity(0.4), lineWidth: 1.5)
                )
            }
            .disabled(isOpeningThread)

            if let threadProblem {
                Text(threadProblem)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
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
