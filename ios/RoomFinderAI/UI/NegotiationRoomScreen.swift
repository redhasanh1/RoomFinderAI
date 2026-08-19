import SwiftUI

/// One negotiation with one landlord, from first contact to a booked viewing.
///
/// The negotiator tab briefs an assistant. This is the thing that actually
/// happens afterwards: a thread with the person who owns the room, every message
/// the AI sent on the tenant's behalf, and their replies. Previously only the
/// website could do this, so the app could discuss a room but never pursue one.
struct NegotiationRoomScreen: View {

    let listing: Listing
    @StateObject private var negotiation: LandlordNegotiationService
    @State private var isRefreshing = false

    init(listing: Listing) {
        self.listing = listing
        _negotiation = StateObject(wrappedValue: LandlordNegotiationService(listing: listing))
    }

    var body: some View {
        VStack(spacing: 0) {
            statusBar

            if negotiation.messages.isEmpty {
                primer
            } else {
                transcript
            }

            footer
        }
        .navigationTitle("Negotiating")
        .navigationBarTitleDisplayMode(.inline)
        // Catches up whenever the screen comes back, so a landlord reply that
        // arrived while the app was elsewhere is answered on return.
        .task { if negotiation.canStart == false { await negotiation.refresh() } }
    }

    // MARK: - Status

    private var statusBar: some View {
        Group {
            switch negotiation.phase {
            case .idle:
                label("Ready to contact the landlord", "envelope", .secondary)
            case .starting:
                working("Getting in touch…")
            case .waitingForLandlord:
                label("Waiting for the landlord to reply", "clock", .secondary)
            case .replying:
                working("Writing a reply…")
            case .closed(let price, let viewing):
                closedBanner(price: price, viewing: viewing)
            case .failed(let message):
                label(message, "exclamationmark.triangle.fill", .orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    private func label(_ text: String, _ symbol: String, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(text).font(.footnote).foregroundStyle(tint)
        }
    }

    private func working(_ text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text).font(.footnote).foregroundStyle(.secondary)
        }
    }

    /// The whole point of the feature, so it is stated plainly and with the
    /// numbers rather than left to be inferred from the transcript.
    private func closedBanner(price: Int?, viewing: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text("Deal agreed").font(.subheadline.weight(.bold))
            }
            if let price {
                let asking = Int(listing.price ?? 0)
                let saved = max(0, asking - price)
                Text(saved > 0
                     ? "$\(price)/month — $\(saved)/month under asking, about $\(saved * 12) a year."
                     : "$\(price)/month.")
                    .font(.footnote)
            }
            if let viewing {
                Text("Viewing booked for \(viewing).").font(.footnote).foregroundStyle(.secondary)
            }
            Text("Turn up, look the place over, and only sign if you're happy.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Content

    private var primer: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.gradient)
            Text("Let the AI do the asking")
                .font(.title3.weight(.semibold))
            Text("It messages the landlord for you, argues the rent down, and books a viewing. You'll see every message it sends.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if let price = listing.price, price > 0 {
                Text("It will never agree above $\(Int(price))/month.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(negotiation.messages) { message in
                        bubble(for: message).id(message.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: negotiation.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(negotiation.messages.last?.id, anchor: .bottom)
                }
            }
        }
    }

    private func bubble(for message: ChatMessage) -> some View {
        let ours = isOurs(message)
        return VStack(alignment: ours ? .trailing : .leading, spacing: 3) {
            // Says who is speaking. Without it a transcript of two voices with
            // no landlord present is genuinely hard to follow.
            Text(ours ? "Your AI negotiator" : "Landlord")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(message.content ?? "")
                .foregroundStyle(ours ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if ours {
                        RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.gradient)
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: ours ? .trailing : .leading)
    }

    private func isOurs(_ message: ChatMessage) -> Bool {
        let sender = (message.senderEmail ?? "").lowercased()
        if sender.contains("ai-negotiator") { return true }
        return sender == (CurrentUser.shared.email ?? "").lowercased()
    }

    // MARK: - Actions

    private var footer: some View {
        VStack(spacing: 10) {
            Divider()

            switch negotiation.phase {
            case .idle:
                primaryButton("Start negotiating") { await negotiation.start() }
            case .starting, .replying:
                // No action while it is mid-turn: two overlapping calls would
                // send the landlord two messages about the same thing.
                primaryButton("Working…", enabled: false) { }
            case .waitingForLandlord:
                VStack(spacing: 6) {
                    primaryButton(isRefreshing ? "Checking…" : "Check for a reply", enabled: !isRefreshing) {
                        isRefreshing = true
                        await negotiation.refresh()
                        isRefreshing = false
                    }
                    Text("It answers on its own whenever you open this screen.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            case .closed:
                Text("Nothing left to do here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
            case .failed:
                primaryButton("Try again") {
                    if negotiation.conversationID == nil {
                        await negotiation.start()
                    } else {
                        await negotiation.refresh()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func primaryButton(_ title: String, enabled: Bool = true,
                               action: @escaping () async -> Void) -> some View {
        Button {
            Haptics.impact(.medium)
            Task { await action() }
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    enabled ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.secondary.opacity(0.4)),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
        .disabled(!enabled)
    }
}
