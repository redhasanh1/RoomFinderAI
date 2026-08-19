import SwiftUI

/// One person on the roommate marketplace.
///
/// Getting in touch hands off to the site, which owns the messaging and the
/// account it needs. Reporting is native, because guideline 1.2 requires it to
/// be reachable from the content itself.
struct RoommateDetailScreen: View {

    let profile: RoommateProfile

    @EnvironmentObject private var state: AppState
    @State private var isReporting = false

    @State private var thread: Conversation?
    @State private var isOpeningThread = false
    @State private var threadProblem: String?

    /// Opens the thread with whoever owns this profile.
    ///
    /// Many seeded profiles have no account behind them, and the server says so
    /// in its own words rather than opening a conversation nobody will read.
    private func openThread() async {
        guard !isOpeningThread else { return }
        guard let me = CurrentUser.shared.email else {
            threadProblem = "Sign in on the Profile tab first to send a message."
            return
        }

        isOpeningThread = true
        threadProblem = nil
        defer { isOpeningThread = false }

        var request = URLRequest(url: AppConfig.url("api/roommate-conversations"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "profileId": profile.id,
            "userEmail": me
        ])

        struct Opened: Decodable {
            struct Payload: Decodable { let id: String; let otherParty: String? }
            let data: Payload?
            let message: String?
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let decoded = try? JSONDecoder().decode(Opened.self, from: data) else {
            threadProblem = "Couldn't reach them. Check your connection."
            return
        }

        guard let opened = decoded.data,
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            threadProblem = decoded.message ?? "Couldn't open that conversation."
            return
        }

        thread = Conversation(
            id: opened.id,
            context: "roommate",
            otherParty: opened.otherParty,
            subject: profile.displayName,
            lastMessage: nil,
            lastMessageAt: nil,
            unreadCount: 0
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let bio = profile.cleanBio {
                    section("About") {
                        Text(bio)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                section("Details") {
                    VStack(spacing: 10) {
                        detailRow("Status", profile.kind.label, symbol: profile.kind.symbol)
                        detailRow(profile.kind == .hasSpot ? "Rent" : "Budget",
                                  profile.budgetText, symbol: "dollarsign.circle")
                        detailRow("Area", profile.locationText, symbol: "mappin.and.ellipse")
                        if let move = profile.moveInDate?.nilIfEmpty {
                            detailRow("Move-in", move, symbol: "calendar")
                        }
                    }
                }

                if let description = profile.roomDescription?.nilIfEmpty {
                    section("Their room") {
                        Text(description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Opens the thread here rather than dropping the person into a
                // web view of the matching page and leaving them to find a
                // contact form in it.
                Button {
                    Haptics.impact(.medium)
                    Task { await openThread() }
                } label: {
                    HStack(spacing: 8) {
                        if isOpeningThread {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "envelope.fill")
                        }
                        Text(isOpeningThread ? "Opening…" : "Get in touch")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isOpeningThread)

                if let threadProblem {
                    Text(threadProblem)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
        .navigationTitle(profile.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $thread) { conversation in
            ConversationScreen(conversation: conversation, messaging: MessagingService())
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        Haptics.impact(.light)
                        isReporting = true
                    } label: {
                        Label("Report this profile", systemImage: "flag")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More options")
            }
        }
        .sheet(isPresented: $isReporting) {
            ReportSheet(
                targetType: .roommateProfile,
                targetId: profile.id,
                // Profiles carry no email, so blocking by address is not
                // offered here; the report still reaches moderation.
                authorEmail: nil
            )
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            AsyncImage(url: profile.avatarURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Theme.gradient
                        Text(profile.initials)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(profile.displayName)
                    .font(.title2.weight(.bold))
                Label(profile.kind.label, systemImage: profile.kind.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.brand)
                Text(profile.budgetText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func detailRow(_ title: String, _ value: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.footnote)
                .foregroundStyle(Theme.brand)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }
}
