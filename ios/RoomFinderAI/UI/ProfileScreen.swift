import SwiftUI

/// The account, natively.
///
/// The last web-backed tab. It held sign-in, verification, your listings and
/// deleting your account, all inside profile.html — which meant the app could
/// not tell whether any of it had worked, and nothing on this tab could be
/// reached by VoiceOver or by the automation used to test the rest.
struct ProfileScreen: View {

    @EnvironmentObject private var state: AppState
    @ObservedObject private var auth = AuthService.shared

    @StateObject private var verification = VerificationService()
    @StateObject private var mine = MyListingsService()

    @State private var showingVerification = false
    @State private var showingDelete = false
    @State private var showingEditName = false

    var body: some View {
        NavigationStack {
            Group {
                if auth.isSignedIn {
                    account
                } else {
                    AuthScreen()
                }
            }
            .navigationTitle(auth.isSignedIn ? "Profile" : "Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { MoreMenu() }
            }
            .navigationDestination(for: Listing.self) { ListingDetailScreen(listing: $0) }
        }
        .task(id: auth.profile?.email) {
            guard auth.isSignedIn else { return }
            await auth.refresh()
            await verification.loadStatus()
            mine.load()
        }
    }

    private var account: some View {
        List {
            Section { identity }

            Section {
                Button {
                    showingVerification = true
                } label: {
                    HStack {
                        Label("Verify your account", systemImage: "checkmark.seal")
                        Spacer()
                        verificationBadge
                    }
                }
                .disabled(verification.stage == .verified || verification.stage == .pending)

                Button {
                    showingEditName = true
                } label: {
                    Label("Edit your name", systemImage: "person.text.rectangle")
                }

                Button {
                    state.showingSaved = true
                } label: {
                    Label("Saved rooms", systemImage: "heart")
                }
            } footer: {
                if case .rejected(let why) = verification.stage {
                    Text(why).foregroundStyle(.red)
                } else if verification.stage == .pending {
                    Text("We're reviewing what you sent. This usually takes a day.")
                }
            }

            listingsSection

            Section {
                Label(planDescription, systemImage: "star")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Plan")
            } footer: {
                // No upgrade button. Guideline 3.1.1 requires anything that
                // unlocks features in the app to go through In-App Purchase,
                // and the Pro plan is sold through Stripe on the website, so
                // the app must not route anyone there. See
                // AppConfig.blocksPurchasing.
                Text("Manage your plan on the RoomFinderAI website.")
            }

            Section {
                Button(role: .destructive) {
                    auth.signOut()
                    Haptics.impact(.light)
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }

                Button(role: .destructive) {
                    showingDelete = true
                } label: {
                    Label("Delete my account", systemImage: "trash")
                }
            } footer: {
                // Guideline 5.1.1(v): an account made in the app has to be
                // deletable in the app, not only on a website.
                Text("Deleting removes your account, your listings and your saved rooms for good.")
            }
        }
        .refreshable {
            await auth.refresh()
            await verification.loadStatus()
            mine.load()
        }
        .sheet(isPresented: $showingVerification) {
            VerificationScreen(service: verification)
        }
        .sheet(isPresented: $showingEditName) {
            EditNameScreen()
        }
        .sheet(isPresented: $showingDelete) {
            DeleteAccountScreen()
        }
    }

    private var identity: some View {
        HStack(spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                Text(auth.profile?.displayName ?? "")
                    .font(.headline)
                Text(auth.profile?.email ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var avatar: some View {
        let initials = auth.profile?.initials ?? "?"

        if let path = auth.profile?.profileImage, let url = URL(string: path) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                initialsCircle(initials)
            }
            .frame(width: 58, height: 58)
            .clipShape(Circle())
        } else {
            initialsCircle(initials)
        }
    }

    private func initialsCircle(_ initials: String) -> some View {
        Text(initials)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Theme.brand)
            .frame(width: 58, height: 58)
            .background(Circle().fill(Theme.brand.opacity(0.14)))
    }

    @ViewBuilder
    private var verificationBadge: some View {
        switch verification.stage {
        case .verified:
            Label("Verified", systemImage: "checkmark.seal.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        case .pending:
            Text("In review").font(.caption).foregroundStyle(.secondary)
        case .rejected:
            Text("Try again").font(.caption).foregroundStyle(.red)
        case .notStarted, .unknown:
            Text("Not verified").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var planDescription: String {
        if auth.profile?.isPro == true { return "Pro" }
        return (auth.profile?.plan ?? "free").capitalized
    }

    @ViewBuilder
    private var listingsSection: some View {
        Section {
            if mine.isLoading && mine.listings.isEmpty {
                HStack { ProgressView(); Text("Loading").foregroundStyle(.secondary) }
            } else if mine.listings.isEmpty {
                Text("You haven't posted a room yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(mine.listings) { listing in
                    NavigationLink(value: listing) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(listing.title).lineLimit(1)
                            Text(listing.priceText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    Task { await mine.delete(at: offsets) }
                }
            }
        } header: {
            Text("Your listings")
        } footer: {
            if !mine.listings.isEmpty {
                Text("Swipe a listing to delete it.")
            }
        }
    }
}
