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

    @EnvironmentObject private var state: AppState
    @State private var section: Section = .negotiator
    @State private var showingGoals = false
    @State private var confirmingReset = false
    @State private var askingAboutNotifications = false
    @ObservedObject private var push = PushService.shared
    @StateObject private var messaging = MessagingService()
    @ObservedObject private var chat = NegotiationService.shared
    @ObservedObject private var campaign = NegotiationCampaign.shared

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
                    NegotiatorCampaignScreen(campaign: campaign, chat: chat, showingGoals: $showingGoals)
                case .inbox:
                    InboxList(messaging: messaging)
                }
            }
            // A room just arrived from "Negotiate this rent". Show the
            // negotiator half, and the first time round open the goals form —
            // nothing is sent to a landlord until those are confirmed, so
            // landing on a screen with a disabled button and no explanation
            // would read as broken.
            .onChange(of: state.justQueuedNegotiation) { _, queued in
                guard queued else { return }
                section = .negotiator
                // Always, not only the first time. The form arrives filled in
                // from the room just chosen, and confirming it is what starts
                // the messaging — so this is the whole flow in one glance
                // rather than a queue the tenant has to go and find a button
                // for. Cancelling leaves the room lined up to start later.
                showingGoals = true
                state.justQueuedNegotiation = false
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    MoreMenu {
                        if section == .negotiator {
                            Button {
                                Haptics.impact(.light)
                                chat.reset()
                            } label: {
                                Label("Clear chat", systemImage: "eraser")
                            }
                            Button(role: .destructive) {
                                Haptics.impact(.medium)
                                confirmingReset = true
                            } label: {
                                Label("Reset negotiations", systemImage: "arrow.counterclockwise")
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
            // A full page, not the small card a form sheet defaults to on
            // iPad: this is a screenful of fields and it was being shown in a
            // window smaller than the keyboard.
            // Asked in our own words first, so a "no" here costs nothing and
            // the one system prompt iOS allows is only spent on someone who
            // has already said yes.
            .alert("Tell you when a landlord agrees?", isPresented: $askingAboutNotifications) {
                Button("Yes, notify me") { push.requestAuthorization() }
                Button("Not now", role: .cancel) { }
            } message: {
                Text("Your AI keeps negotiating after you close the app, and landlords can take hours to reply. We'll ping you the moment one agrees.")
            }
            .task { push.refreshStatus() }
            // Reset deletes the conversations themselves, so it asks first.
            // The website's does the same, and it is not recoverable.
            .confirmationDialog("Reset negotiations?",
                                isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Delete all negotiations", role: .destructive) {
                    Task { await campaign.resetEverything() }
                }
                Button("Keep them", role: .cancel) { }
            } message: {
                Text("This deletes every negotiation and the messages in them. It can't be undone.")
            }
            .sheet(isPresented: $showingGoals) {
                NegotiationGoalsSheet(
                    goals: $campaign.goals,
                    queuedCount: campaign.queued.count,
                    onConfirm: {
                        campaign.confirmGoals()
                        // Confirming is the go-ahead. Anything already lined up
                        // starts now, and the negotiations appear above.
                        if !campaign.queued.isEmpty {
                            Task { await campaign.start() }
                        }
                        // The only moment worth asking about notifications:
                        // something is now running in the background that the
                        // tenant cannot see the end of. Asked at launch it is a
                        // prompt about nothing, and iOS only allows one.
                        if push.authorizationStatus == .notDetermined {
                            askingAboutNotifications = true
                        }
                    }
                )
                .presentationDetents([.large])
                .fullPagePresentation()
            }
        }
    }
}

/// The two halves of this tab, sized to be tapped without aiming.
private struct SectionSwitcher: View {

    @Binding var section: MessagesScreen.Section
    @Namespace private var highlight

    /// The same count the tab bar carries.
    ///
    /// The badge on the tab told someone a message was waiting and then this
    /// screen opened on the negotiator, with nothing to say the message was
    /// behind the other half of the switcher. People went looking and did not
    /// find it.
    @ObservedObject private var unread = UnreadCounter.shared

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
                    HStack(spacing: 6) {
                        Text(option.rawValue)
                        if option == .inbox, unread.count > 0 {
                            Text(unread.count > 99 ? "99+" : "\(unread.count)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.red))
                                // Announced as part of the button rather than
                                // as a loose number beside it.
                                .accessibilityLabel("\(unread.count) unread")
                        }
                    }
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
    @ObservedObject private var moderation = ModerationService.shared
    @ObservedObject var messaging: MessagingService

    /// Blocking someone did nothing to the inbox: their rooms disappeared from
    /// search while their messages kept arriving, which is the half that
    /// actually matters when the person is harassing you.
    private var visibleConversations: [Conversation] {
        messaging.conversations.filter { !moderation.isBlocked($0.otherParty) }
    }

    @State private var blockTarget: String?
    @State private var confirmingBlock = false
    @State private var reportTarget: Conversation?

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
            } else if let error = messaging.errorMessage, visibleConversations.isEmpty {
                // A failed load used to be reported as "no messages yet",
                // which told the user their inbox was empty when it was not.
                StatusScreen(
                    symbol: "wifi.exclamationmark",
                    title: "Couldn't load messages",
                    message: error,
                    actionTitle: "Try Again",
                    action: { Task { await messaging.loadConversations() } }
                )
            } else if visibleConversations.isEmpty {
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
        List(visibleConversations) { conversation in
            NavigationLink {
                // Opening a thread marks it read on the server, so the badge
                // should stop claiming otherwise without waiting for the next
                // poll to come round.
                ConversationScreen(conversation: conversation, messaging: messaging)
                    .onAppear { UnreadCounter.shared.refreshSoon() }
            } label: {
                ConversationRow(conversation: conversation)
            }
            // Reachable without opening the thread. Someone being harassed
            // should not have to read the next message to get at the controls
            // that stop it.
            .swipeActions(edge: .trailing) {
                if let other = conversation.otherParty?.nilIfEmpty {
                    Button(role: .destructive) {
                        blockTarget = other
                        confirmingBlock = true
                    } label: {
                        Label("Block", systemImage: "hand.raised.fill")
                    }
                }
                Button {
                    reportTarget = conversation
                } label: {
                    Label("Report", systemImage: "flag")
                }
                .tint(.orange)
            }
        }
        .listStyle(.plain)
        .blockAction(.person(email: blockTarget), isPresented: $confirmingBlock)
        .sheet(item: $reportTarget) { conversation in
            ReportSheet(
                targetType: .message,
                targetId: conversation.id,
                authorEmail: conversation.otherParty
            )
        }
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
        // Spelled out rather than combined: .combine walks the subtree and
        // forces it to lay out, which on a row in a lazy list never settles.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(conversation.displayName), \(conversation.source.label), \(conversation.preview)")
    }
}

/// One thread, with the same bubble layout as the negotiator so the app reads
/// consistently: your words on the right, theirs on the left.
struct ConversationScreen: View {

    let conversation: Conversation
    @ObservedObject var messaging: MessagingService

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var isReporting = false
    @State private var confirmingBlock = false
    @Environment(\.dismiss) private var dismiss

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
        // Guideline 1.2 wants reporting and blocking where the content is, and
        // for a messaging app that is inside the thread. This screen had
        // neither: the only report buttons in the app were on a listing and on
        // a roommate profile, so abuse arriving as a message had nowhere to go.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                MoreMenu {
                    Button {
                        Haptics.impact(.light)
                        isReporting = true
                    } label: {
                        Label("Report this conversation", systemImage: "flag")
                    }

                    if conversation.otherParty?.nilIfEmpty != nil {
                        Button(role: .destructive) {
                            Haptics.impact(.medium)
                            confirmingBlock = true
                        } label: {
                            Label("Block this person", systemImage: "hand.raised")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isReporting) {
            ReportSheet(
                targetType: .message,
                targetId: conversation.id,
                authorEmail: conversation.otherParty
            )
        }
        // Leaving the thread afterwards, because staying in a conversation with
        // somebody you just blocked reads as though the block did not take.
        .blockAction(.person(email: conversation.otherParty),
                     isPresented: $confirmingBlock,
                     onBlocked: {
                         Task { await messaging.loadConversations() }
                         dismiss()
                     })
        .task {
            await load()

            // Then keep watching while the thread is open.
            //
            // It loaded once and stopped, so a reply that arrived while you
            // were reading never appeared — you had to back out to the list and
            // come back in to see it. The notification told you it existed and
            // the screen showing that conversation did not.
            //
            // The task is cancelled when the screen goes away, which ends the
            // loop; no timer to invalidate.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                if Task.isCancelled { break }
                await load(quietly: true)
            }
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        if startsNewDay(message, at: index), let sent = message.sentAt {
                            Text(dayLabel(sent))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 6)
                        }
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
        let sent = message.sentAt

        return VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
            Text(message.content ?? "")
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

            // When it was sent, under the bubble.
            //
            // A thread was a column of text in which a reply from three days
            // ago looked exactly like one from a minute ago — and how long a
            // landlord has been quiet is the thing a tenant is reading for.
            if let sent {
                Text(sent, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        // One label for the whole thing, with the time spoken as part of it
        // rather than as a stray number after the message.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [mine ? "You" : conversation.displayName,
             message.content ?? "",
             sent.map { $0.formatted(date: .omitted, time: .shortened) } ?? ""]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        )
    }

    /// "Today", "Yesterday", or a date — shown once above the first message of
    /// each day so a long thread can be read at a glance.
    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// Whether this message begins a new day in the transcript.
    private func startsNewDay(_ message: ChatMessage, at index: Int) -> Bool {
        guard let sent = message.sentAt else { return false }
        guard index > 0, let previous = messages[index - 1].sentAt else { return true }
        return !Calendar.current.isDate(sent, inSameDayAs: previous)
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                DictationButton(text: $draft, isDisabled: isSending)

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

    /// Fetches the thread.
    ///
    /// `quietly` is for the poll: it must not put the spinner back over a
    /// conversation you are reading, and a failed refresh must not replace the
    /// messages on screen with an error — the ones already there are still
    /// perfectly good.
    private func load(quietly: Bool = false) async {
        if !quietly { isLoading = true }
        defer { if !quietly { isLoading = false } }

        do {
            let fetched = try await messaging.messages(in: conversation.id)
            // Only touch the array when something actually changed, so the list
            // does not rebuild itself every four seconds while being read.
            if fetched.count != messages.count || fetched.last?.id != messages.last?.id {
                messages = fetched
                if quietly { UnreadCounter.shared.refreshSoon() }
            }
            errorMessage = nil
        } catch {
            guard !quietly else { return }
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
