import SwiftUI
import UIKit

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
    @ObservedObject private var push = PushService.shared
    @Binding var showingGoals: Bool

    var body: some View {
        VStack(spacing: 10) {
            goalsBar

            if !campaign.active.isEmpty { activeBar }
            if !campaign.active.isEmpty && push.authorizationStatus == .denied { notificationsOffBar }

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

    // A closed deal is announced by the negotiator in the chat, as a message
    // from it. It used to be a green card pinned above the chat, which put the
    // one thing the tenant is waiting for outside the conversation they were
    // having about it.

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

    /// Only while a negotiation is actually running. Nagging about
    /// notifications when nothing is happening is how an app gets its
    /// notifications turned off in the first place.
    private var notificationsOffBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.slash.fill").foregroundStyle(.orange)
            Text("Notifications are off, so you won't hear when a landlord agrees.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Turn on") {
                Haptics.impact(.light)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.orange.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
