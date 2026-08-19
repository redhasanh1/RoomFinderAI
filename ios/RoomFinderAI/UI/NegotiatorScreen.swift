import SwiftUI

/// The negotiator, built natively.
///
/// It works **for the tenant**. They say what they are looking for, it answers,
/// finds rooms, and does the arguing with landlords on their behalf. The
/// tenant's own words sit on the right in the brand colour, the AI's on the
/// left — the arrangement the website settled on, so someone moving between
/// the two is never unsure who said what.
/// Content only — no navigation stack or title of its own. The Messages hub
/// that hosts it supplies both, because two stacked headers (a segmented
/// control above a second navigation bar) read as a layout fault.
struct NegotiatorScreen: View {

    @ObservedObject var service: NegotiationService
    @Binding var showingGoals: Bool

    @State private var draft = ""
    @StateObject private var dictation = SpeechDictation()
    @FocusState private var inputFocused: Bool

    /// Starts or stops listening. What is heard goes into the same box as
    /// typing, so it can be corrected before it is sent.
    private func toggleDictation() async {
        if dictation.isListening {
            dictation.stop()
        } else {
            inputFocused = false
            await dictation.start()
        }
    }

    /// Openers, so the first message is a tap rather than a blank page.
    private let suggestions = [
        "Find me a 1 bedroom under $1500",
        "What's a fair rent in Toronto?",
        "Help me negotiate my rent down"
    ]

    var body: some View {
        VStack(spacing: 0) {
            transcript

            if let error = service.errorMessage ?? dictation.errorMessage {
                errorBar(error)
            }

            composer
        }
        .onChange(of: dictation.transcript) { _, spoken in
            guard !spoken.isEmpty else { return }
            draft = spoken
        }
        // Never leave the microphone running because someone swiped away.
        .onDisappear { dictation.stop() }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if !service.hasStarted { primer }

                    ForEach(service.messages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                    }

                    if service.isThinking {
                        TypingIndicator().id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            // Follows the newest line without the user chasing it.
            .onChange(of: service.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(service.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: service.isThinking) { _, thinking in
                guard thinking else { return }
                withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
            }
        }
    }

    private var primer: some View {
        VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.gradient)

            Text("Your rental advocate")
                .font(.title3.weight(.semibold))

            Text("Tell it what you're after. It finds rooms, works out what's a fair price, and negotiates with landlords for you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        Haptics.impact(.light)
                        Task { await service.send(suggestion) }
                    } label: {
                        Text(suggestion)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
        }
        .padding(.vertical, 24)
    }

    private func errorBar(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message).font(.footnote)
            Spacer()
            Button("Dismiss") {
                service.errorMessage = nil
                dictation.errorMessage = nil
            }
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.1))
        .foregroundStyle(.red)
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                // Talking beats typing a paragraph about what you want on a
                // phone keyboard, and it is the first thing anyone does here.
                Button {
                    Haptics.impact(.light)
                    Task { await toggleDictation() }
                } label: {
                    Image(systemName: dictation.isListening ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(dictation.isListening
                                         ? AnyShapeStyle(.red)
                                         : AnyShapeStyle(Theme.brand))
                        .symbolEffect(.pulse, isActive: dictation.isListening)
                }
                .disabled(service.isThinking)
                .accessibilityLabel(dictation.isListening ? "Stop dictation" : "Talk instead of typing")

                TextField(dictation.isListening ? "Listening…" : "Tell me what you're looking for…",
                          text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .focused($inputFocused)
                    .disabled(service.isThinking)

                Button(action: sendDraft) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? AnyShapeStyle(Theme.gradient)
                                                 : AnyShapeStyle(Color.secondary.opacity(0.4)))
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !service.isThinking
    }

    private func sendDraft() {
        guard canSend else { return }
        let text = draft
        draft = ""
        Haptics.impact(.light)
        Task { await service.send(text) }
    }
}

private struct MessageRow: View {
    let message: NegotiationMessage

    private var isTenant: Bool { message.author == .you }

    var body: some View {
        if let deal = message.deal {
            dealCard(deal)
        } else {
            standard
        }
    }

    /// The outcome the whole conversation was for, so it does not look like one
    /// more reply.
    private func dealCard(_ deal: NegotiationMessage.Deal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").font(.title3)
                Text(deal.price.map { "We secured it at $\($0)/month" } ?? "We secured it")
                    .font(.headline)
            }

            Text(deal.room)
                .font(.subheadline.weight(.semibold))
                .opacity(0.95)

            if let saved = deal.savedPerMonth {
                Text("$\(saved) a month under asking, about $\(saved * 12) over a year.")
                    .font(.footnote)
                    .opacity(0.9)
            }
            if let viewing = deal.viewing {
                Text("Viewing booked for \(viewing).")
                    .font(.footnote)
                    .opacity(0.9)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(colors: [Color.green, Color.green.opacity(0.78)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private var standard: some View {
        VStack(alignment: isTenant ? .trailing : .leading, spacing: 6) {
            VStack(alignment: isTenant ? .trailing : .leading, spacing: 3) {
                Text(message.author.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)

                Text(message.text)
                    .foregroundStyle(isTenant ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        if isTenant {
                            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.gradient)
                        } else {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        }
                    }
            }
            .frame(maxWidth: .infinity, alignment: isTenant ? .trailing : .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(message.author.label): \(message.text)")

            // Rooms the AI found for this turn, tappable straight through to
            // the same native detail screen the Listings tab uses.
            if !message.listings.isEmpty {
                ForEach(message.listings) { listing in
                    NavigationLink {
                        ListingDetailScreen(listing: listing)
                    } label: {
                        ChatListingCard(listing: listing)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Compact enough to sit inside a conversation, big enough to be worth tapping.
private struct ChatListingCard: View {
    let listing: Listing

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: listing.imageURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Theme.gradient.opacity(0.18)
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                Text(listing.displayLocation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(listing.priceText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.brand)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this room")
    }
}

/// Three dots while the model composes. A determinate bar would be a lie —
/// nothing here knows how long the model will take.
private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .scaleEffect(animating ? 1.2 : 0.7)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { animating = true }
        .accessibilityLabel("The negotiator is typing")
    }
}
