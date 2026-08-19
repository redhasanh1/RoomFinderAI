import SwiftUI

/// The negotiator half of Messages: your goals, the negotiations running, and
/// the chat that starts more of them.
///
/// The chat is the main surface. Telling it what you want is how several rooms
/// get contacted at once — it searches, then messages every landlord that fits
/// rather than listing rooms and waiting to be told to act. Tapping "Negotiate
/// this rent" on a specific room lines that one up here instead.
///
/// Everything above the chat is deliberately one line tall until it has
/// something to say. This screen is for negotiating, not for reading status.
struct NegotiatorCampaignScreen: View {

    @ObservedObject var campaign: NegotiationCampaign
    @ObservedObject var chat: NegotiationService
    @Binding var showingGoals: Bool

    var body: some View {
        VStack(spacing: 10) {
            // The win goes first and takes real space. Everything else on this
            // screen is admin.
            if !campaign.secured.isEmpty { securedBanner }

            goalsBar

            if !campaign.active.isEmpty { activeBar }

            if let message = campaign.errorMessage { notice(message) }

            NegotiatorScreen(service: chat, showingGoals: $showingGoals)
        }
        .padding(.horizontal, 16)
        .task {
            campaign.beginPolling()
            // Catches a deal that closed while this screen was not on show.
            campaign.announceAnyNewDeal()
        }
        // Pops the moment a landlord agrees, wherever in Messages the tenant
        // happens to be looking.
        .alert(item: $campaign.celebration) { deal in
            Alert(
                title: Text(deal.headline),
                message: Text(deal.detail),
                dismissButton: .default(Text("Nice"))
            )
        }
    }

    // MARK: - The win

    private var securedBanner: some View {
        NavigationLink {
            NegotiationsListScreen(campaign: campaign)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                    Text(campaign.secured.count == 1
                         ? "We secured it"
                         : "We secured \(campaign.secured.count) rooms")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold))
                }

                ForEach(campaign.secured, id: \.listingID) { negotiation in
                    if case .closed(let price, let viewing) = negotiation.phase {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(negotiation.listing.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(securedLine(price: price, viewing: viewing,
                                             asking: negotiation.listing.price.map(Int.init)))
                                .font(.footnote)
                                .opacity(0.9)
                        }
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color.green, Color.green.opacity(0.75)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func securedLine(price: Int?, viewing: String?, asking: Int?) -> String {
        var parts: [String] = []
        if let price { parts.append("$\(price) a month") }
        if let price, let asking, asking > price {
            parts.append("$\(asking - price) under asking")
        }
        if let viewing { parts.append("viewing \(viewing)") }
        return parts.isEmpty ? "Agreed" : parts.joined(separator: ", ")
    }

    // MARK: - Goals

    /// Compact, because the goals are filled in from the room the tenant
    /// tapped. All that is left is to say they look right.
    private var goalsBar: some View {
        HStack(spacing: 10) {
            Image(systemName: campaign.goals.isConfirmed ? "checkmark.seal.fill" : "target")
                .foregroundStyle(campaign.goals.isConfirmed ? AnyShapeStyle(.green) : AnyShapeStyle(Theme.gradient))

            VStack(alignment: .leading, spacing: 1) {
                Text(campaign.goals.isConfirmed ? "Goals confirmed" : "Check your goals")
                    .font(.caption.weight(.semibold))
                Text(campaign.goals.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button("Edit") {
                Haptics.impact(.light)
                showingGoals = true
            }
            .font(.caption.weight(.semibold))

            if !campaign.goals.isConfirmed {
                Button {
                    Haptics.impact(.medium)
                    // Never a dead button. With nothing to argue from there is
                    // nothing to confirm, so this opens the form instead of
                    // sitting greyed out with no explanation.
                    if campaign.goals.isUsable {
                        campaign.confirmGoals()
                    } else {
                        showingGoals = true
                    }
                } label: {
                    Text("These are right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.gradient,
                                    in: Capsule())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // Rooms waiting to be contacted are not shown here. The count already
    // appears on the goals popup's button ("message 3 landlords"), which is
    // where the decision is made — repeating it as a bar on this screen was
    // status for its own sake.

    // MARK: - Running

    private var activeBar: some View {
        NavigationLink {
            NegotiationsListScreen(campaign: campaign)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .foregroundStyle(Theme.gradient)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Negotiating with \(campaign.active.count) landlord\(campaign.active.count == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(summaryLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var summaryLine: String {
        let agreed = campaign.closedCount
        if agreed > 0 { return "\(agreed) agreed — tap to see the offers" }
        return "Tap to read every message"
    }

    private func notice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundStyle(.orange)
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.orange.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Every landlord being negotiated with, and how each one is going.
struct NegotiationsListScreen: View {

    @ObservedObject var campaign: NegotiationCampaign

    var body: some View {
        List {
            ForEach(campaign.active, id: \.listingID) { negotiation in
                NavigationLink {
                    NegotiationRoomScreen(negotiation: negotiation)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(negotiation.listing.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        status(for: negotiation.phase)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Negotiations")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if campaign.active.isEmpty {
                ContentUnavailableView(
                    "No negotiations yet",
                    systemImage: "bubble.left.and.text.bubble.right",
                    description: Text("Tell the negotiator what you're looking for and it'll message every landlord that fits.")
                )
            }
        }
    }

    @ViewBuilder
    private func status(for phase: LandlordNegotiationService.Phase) -> some View {
        switch phase {
        case .idle:
            Text("Ready").font(.caption).foregroundStyle(.secondary)
        case .starting:
            Text("Getting in touch…").font(.caption).foregroundStyle(.secondary)
        case .waitingForLandlord:
            Text("Waiting for the landlord").font(.caption).foregroundStyle(.secondary)
        case .replying:
            Text("Writing a reply…").font(.caption).foregroundStyle(.secondary)
        case .closed(let price, _):
            Label(price.map { "Agreed at $\($0)/mo" } ?? "Deal agreed",
                  systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(2)
        }
    }
}
