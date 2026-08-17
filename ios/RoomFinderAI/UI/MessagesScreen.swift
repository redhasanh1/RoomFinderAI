import SwiftUI

/// The messages hub: the AI negotiator and the real inbox, side by side.
///
/// Both belong here because both are conversations, and keeping them apart in
/// different corners of the app made people miss replies from actual landlords
/// while the negotiator sat in its own tab. Each real thread is labelled with
/// where it came from — Listings, Sublease or RoomPal — so an inbox mixing all
/// three is still legible at a glance.
struct MessagesScreen: View {

    enum Section: String, CaseIterable, Hashable {
        case negotiator = "AI Negotiator"
        case inbox = "Direct Messages"
    }

    @State private var section: Section = .negotiator
    @State private var showingGoals = false
    @StateObject private var messaging = MessagingService()
    @StateObject private var negotiation = NegotiationService()

    var body: some View {
        // One navigation stack for the whole hub. Each section used to bring
        // its own, which stacked a second header under the segmented control.
        NavigationStack {
            VStack(spacing: 0) {
                // A custom switcher rather than .pickerStyle(.segmented):
                // the system control is fixed at around 32pt with a small
                // caption font, which is cramped for the two things this whole
                // tab is divided into.
                SectionSwitcher(section: $section)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                switch section {
                case .negotiator:
                    NegotiatorScreen(service: negotiation, showingGoals: $showingGoals)
                case .inbox:
                    InboxList(messaging: messaging)
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if section == .negotiator {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            Haptics.impact(.light)
                            showingGoals = true
                        } label: {
                            Image(systemName: "target")
                        }
                        .accessibilityLabel("Your goals")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MoreMenu {
                        if section == .negotiator {
                            Button(role: .destructive) {
                                Haptics.impact(.medium)
                                negotiation.reset()
                            } label: {
                                Label("Start over", systemImage: "arrow.counterclockwise")
                            }
                        } else {
                            Button {
                                Haptics.impact(.light)
                                Task { await messaging.loadConversations() }
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingGoals) {
                NegotiationGoalsSheet(goals: $negotiation.goals)
            }
        }
    }
}

/// The two halves of this tab, sized to be tapped without aiming.
private struct SectionSwitcher: View {

    @Binding var section: MessagesScreen.Section
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MessagesScreen.Section.allCases, id: \.self) { option in
                let selected = option == section

                Button {
                    guard !selected else { return }
                    Haptics.select()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        section = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background {
                            if selected {
                                // Matched geometry so the highlight slides
                                // between the two rather than blinking.
                                Capsule()
                                    .fill(Theme.gradient)
                                    .matchedGeometryEffect(id: "switcher", in: highlight)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(5)
        .background(Capsule().fill(Color(.secondarySystemBackground)))
    }
}

private struct InboxList: View {

    @EnvironmentObject private var state: AppState
    @ObservedObject private var user = CurrentUser.shared
    @ObservedObject var messaging: MessagingService

    var body: some View {
        // Ordered so there is no gap that renders nothing. The previous
        // arrangement fell through to an empty List in the moment before the
        // first load finished, which showed a completely blank screen.
        Group {
            if !user.isSignedIn {
                StatusScreen(
                    symbol: "person.crop.circle.badge.questionmark",
                    title: "Sign in to see messages",
                    message: "Your conversations with landlords and roommates appear here once you're signed in. Sign in on the Profile tab.",
                    actionTitle: "Go to Profile",
                    action: { state.selectedTab = .profile }
                )
            } else if !messaging.hasLoadedOnce {
                ProgressView("Loading messages…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = messaging.errorMessage, messaging.conversations.isEmpty {
                // A failed load used to be reported as "no messages yet",
                // which told the user their inbox was empty when it was not.
                StatusScreen(
                    symbol: "wifi.exclamationmark",
                    title: "Couldn't load messages",
                    message: error,
                    actionTitle: "Try Again",
                    action: { Task { await messaging.loadConversations() } }
                )
            } else if messaging.conversations.isEmpty {
                StatusScreen(
                    symbol: "tray",
                    title: "No messages yet",
                    message: "When you contact a landlord or a roommate, the conversation shows up here.",
                    actionTitle: "Refresh",
                    action: { Task { await messaging.loadConversations() } }
                )
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await messaging.loadConversations() }
        // Signing in happens on the Profile tab, in a web view. Without this
        // the inbox kept showing "sign in to see messages" afterwards.
        .onChange(of: user.email) { _, _ in
            Task { await messaging.loadConversations() }
        }
        .refreshable {
            Haptics.impact(.light)
            await messaging.loadConversations()
        }
    }

    private var list: some View {
        List(messaging.conversations) { conversation in
            NavigationLink {
                ConversationScreen(conversation: conversation, messaging: messaging)
            } label: {
                ConversationRow(conversation: conversation)
            }
        }
        .listStyle(.plain)
    }
}

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Theme.gradient)
                Image(systemName: conversation.source.symbol)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(conversation.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    // The source label. Without it an inbox mixing a landlord,
                    // a sublease and a roommate is three identical-looking rows.
                    Text(conversation.source.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.brand)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.brand.opacity(0.12)))

                    Spacer()

                    Text(conversation.timeText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let subject = conversation.subject?.nilIfEmpty {
                    Text(subject)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(conversation.preview)
                    .font(.footnote)
                    .foregroundStyle(conversation.hasUnread ? .primary : .secondary)
                    .lineLimit(2)
            }

            if conversation.hasUnread {
                Circle()
                    .fill(Theme.brand)
                    .frame(width: 9, height: 9)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// One thread, with the same bubble layout as the negotiator so the app reads
/// consistently: your words on the right, theirs on the left.
private struct ConversationScreen: View {

    let conversation: Conversation
    @ObservedObject var messaging: MessagingService

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                transcript
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
            }

            composer
        }
        .navigationTitle(conversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { message in
                        bubble(for: message).id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
        }
    }

    private func bubble(for message: ChatMessage) -> some View {
        let mine = message.isMine(CurrentUser.shared.email)
        return Text(message.content ?? "")
            .foregroundStyle(mine ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if mine {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.gradient)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                }
            }
            .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
            .accessibilityLabel("\(mine ? "You" : conversation.displayName): \(message.content ?? "")")
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .disabled(isSending)

                Button {
                    Task { await send() }
                } label: {
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
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await messaging.messages(in: conversation.id)
        } catch {
            errorMessage = "Couldn't load this conversation."
        }
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        draft = ""
        isSending = true
        defer { isSending = false }
        Haptics.impact(.light)

        do {
            if let sent = try await messaging.send(text, in: conversation.id) {
                messages.append(sent)
            }
            errorMessage = nil
        } catch {
            // Put the text back rather than losing what they typed.
            draft = text
            errorMessage = "Couldn't send. Check your connection."
            Haptics.notify(.error)
        }
    }
}
