import Combine
import Foundation

/// Every landlord the tenant is negotiating with at once.
///
/// A single negotiation was the wrong unit. Someone looking for a room is not
/// pursuing one room, they are pursuing several and taking whichever comes back
/// best — which is exactly the work this is meant to take off them. So rooms
/// are queued, either by tapping "Negotiate this rent" on each, or in one go by
/// asking for everything matching the goals, and then one press starts all of
/// them.
///
/// The negotiating itself is still `LandlordNegotiationService`, one per room.
/// That code already argues to a ceiling and knows when a deal is done; this
/// only decides who to talk to and keeps them all moving.
@MainActor
final class NegotiationCampaign: ObservableObject {

    static let shared = NegotiationCampaign()

    /// Contacting a landlord sends a real message to a real person, so this is
    /// deliberately a small number. Ten is already a lot of strangers to write
    /// to at once.
    static let maxTargets = 10

    /// Rooms chosen but not yet contacted.
    @Published private(set) var queued: [Listing] = []

    /// Rooms being negotiated, newest first.
    @Published private(set) var active: [LandlordNegotiationService] = []

    @Published var goals = NegotiationGoals()
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?

    /// Rooms found by the last "everything matching my goals" search that were
    /// not already queued, so the screen can say how many were added.
    @Published private(set) var lastMatchCount: Int?

    /// A deal that has just been struck and not yet been shown off.
    ///
    /// The whole product is this moment. Leaving the tenant to notice a status
    /// line changed colour somewhere down a list wastes it.
    @Published var celebration: Celebration?

    struct Celebration: Identifiable, Equatable {
        let id = UUID()
        let room: String
        let price: Int?
        let asking: Int?
        let viewing: String?

        var savedPerMonth: Int? {
            guard let price, let asking, asking > price else { return nil }
            return asking - price
        }

        var headline: String {
            guard let price else { return "We secured it" }
            return "We secured it at $\(price)/month"
        }

        var detail: String {
            var parts: [String] = []
            if let saved = savedPerMonth {
                parts.append("$\(saved) a month under asking, about $\(saved * 12) over a year")
            }
            if let viewing { parts.append("viewing booked for \(viewing)") }
            return parts.isEmpty ? room : "\(room). " + parts.joined(separator: ", ") + "."
        }
    }

    /// Deals already announced, so reopening the screen does not re-celebrate
    /// one from an hour ago.
    ///
    /// Kept on disk. Held only in memory it started empty on every launch, so
    /// every deal already struck was announced again — a notification and an
    /// alert about the same agreement every single time the app opened.
    /// Cached in memory, written through to disk. Every read used to hit
    /// UserDefaults and allocate a fresh Set, in a loop over every open
    /// negotiation, on a six second timer.
    private var announcedCache: Set<String>?

    private var announced: Set<String> {
        get {
            if let announcedCache { return announcedCache }
            let stored = Set(UserDefaults.standard.stringArray(forKey: Self.announcedKey) ?? [])
            announcedCache = stored
            return stored
        }
        set {
            announcedCache = newValue
            UserDefaults.standard.set(Array(newValue), forKey: Self.announcedKey)
        }
    }

    private static var announcedKey: String {
        "negotiationsAnnounced.\((CurrentUser.shared.email ?? "anonymous").lowercased())"
    }

    private var forwarding: [AnyCancellable] = []
    private var pollTask: Task<Void, Never>?

    private init() {
        goals = NegotiationGoals.load(for: CurrentUser.shared.email)
        restore()
    }

    // MARK: - Surviving a relaunch

    private struct Saved: Codable {
        var queued: [Listing] = []
        var active: [Listing] = []
    }

    private static func stateKey(for email: String?) -> String {
        "negotiationCampaign.\((email ?? "anonymous").lowercased())"
    }

    private func persist() {
        let saved = Saved(queued: queued, active: active.map(\.listing))
        guard let data = try? JSONEncoder().encode(saved) else { return }
        UserDefaults.standard.set(data, forKey: Self.stateKey(for: CurrentUser.shared.email))
    }

    /// Rebuilds the campaign from disk.
    ///
    /// Without this, quitting the app abandoned every negotiation in progress:
    /// the threads carried on existing server-side, but nothing was left
    /// answering the landlords and the tenant had no list of who had been
    /// contacted. The rebuilt engines pick their threads back up from the
    /// server, so the transcripts come back with them.
    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.stateKey(for: CurrentUser.shared.email)),
              let saved = try? JSONDecoder().decode(Saved.self, from: data)
        else { return }

        queued = saved.queued
        for listing in saved.active {
            let negotiation = LandlordNegotiationService(listing: listing)
            negotiation.goals = goals
            adopt(negotiation)
            active.append(negotiation)
        }

        guard !active.isEmpty else { return }
        Task { [active] in
            for negotiation in active { await negotiation.resume() }
            beginPolling()
        }
    }

    // MARK: - Goals

    func saveGoals() {
        goals.save(for: CurrentUser.shared.email)
    }

    func confirmGoals() {
        goals.confirmedAt = Date()
        saveGoals()
    }

    /// True once there is something to start and the tenant has said the goals
    /// are right.
    var canStart: Bool {
        !queued.isEmpty && goals.isConfirmed && goals.isUsable && !isWorking
    }

    // MARK: - Choosing rooms

    /// Queues one room. Idempotent, so tapping "Negotiate this rent" twice on
    /// the same room does not line it up to be messaged twice.
    @discardableResult
    func queue(_ listing: Listing) -> Bool {
        guard !isTaken(listing.id) else { return false }
        guard queued.count + active.count < Self.maxTargets else {
            errorMessage = "That's \(Self.maxTargets) rooms already, as many landlords as this will message at once."
            return false
        }
        queued.append(listing)
        fillGoals(from: listing)
        persist()
        return true
    }

    /// Fills anything the tenant has not set from the room they just chose.
    ///
    /// A blank form is the tenant doing the negotiator's homework. Almost every
    /// answer is already knowable from the room itself: what it costs, where it
    /// is, what a sensible first ask would be. Only empty fields are touched,
    /// so someone who has set their own budget keeps it.
    private func fillGoals(from listing: Listing) {
        if goals.maxRent == nil, let price = listing.price, price > 0 {
            // The asking price is the ceiling: agreeing at or above it is not a
            // negotiation.
            goals.maxRent = price
        }
        if goals.targetRent == nil, let ceiling = goals.maxRent, ceiling > 0 {
            // Roughly a tenth under. Opening at the asking price concedes the
            // whole thing before the first message.
            goals.targetRent = (ceiling * 0.9).rounded()
        }
        if goals.city.isEmpty, let city = listing.location?.nilIfEmpty {
            goals.city = city
        }
        if goals.leaseMonths == nil { goals.leaseMonths = 12 }
        if goals.moveInDate.isEmpty { goals.moveInDate = "As soon as it's available" }

        // Rooms that advertise a perk are worth asking to keep; ones that do
        // not are worth asking for.
        let blurb = ((listing.cleanDescription ?? "") + " " + listing.title).lowercased()
        if blurb.contains("utilities included") || blurb.contains("utilities incl") {
            goals.utilitiesIncluded = true
        }
        if blurb.contains("furnished") { goals.furnished = true }
        if blurb.contains("parking") { goals.parkingNeeded = true }
        if blurb.contains("pet friendly") || blurb.contains("pets allowed") { goals.petFriendly = true }

        saveGoals()
    }

    func remove(_ listing: Listing) {
        queued.removeAll { $0.id == listing.id }
        persist()
    }

    /// Already queued or already being negotiated.
    func isTaken(_ listingID: String) -> Bool {
        queued.contains { $0.id == listingID } || active.contains { $0.listingID == listingID }
    }

    /// Queues rooms the negotiator chat found, and starts on them.
    ///
    /// This is how the several-at-once path works: the tenant says what they
    /// want in the chat, and every room that fits gets contacted. It used to be
    /// a button on this screen, which meant saying what you wanted and then
    /// separately asking for it to be acted on.
    ///
    /// Silent when the goals have not been confirmed — the chat says so itself,
    /// and messaging landlords off unconfirmed numbers is the one thing this
    /// must never do.
    @discardableResult
    func queueAndStart(_ listings: [Listing]) async -> Int {
        guard goals.isConfirmed, goals.isUsable else { return 0 }

        let me = (CurrentUser.shared.email ?? "").lowercased()
        var added = 0
        for listing in listings {
            guard (listing.userEmail ?? "").lowercased() != me else { continue }
            if queue(listing) { added += 1 }
        }
        guard added > 0 else { return 0 }

        await start()
        return added
    }

    /// Queues every room that fits the goals.
    func queueEverythingMatchingGoals() async {
        guard let budget = goals.maxRent, budget > 0 else {
            errorMessage = "Set the most you'll pay first, so it knows what to look for."
            return
        }

        isWorking = true
        errorMessage = nil
        lastMatchCount = nil
        defer { isWorking = false }

        let reachable = budget * 1.25
        do {
            let found = try await ListingsService.search(query: goals.city, maxPrice: reachable)
            let me = (CurrentUser.shared.email ?? "").lowercased()

            let room = Self.maxTargets - (queued.count + active.count)
            var added = 0
            for listing in found.sorted(by: { ($0.price ?? 0) < ($1.price ?? 0) }) {
                guard added < room else { break }
                // Never negotiate with yourself, and never re-contact a room
                // that is already in hand.
                guard (listing.userEmail ?? "").lowercased() != me else { continue }
                guard !isTaken(listing.id) else { continue }
                queued.append(listing)
                added += 1
            }

            lastMatchCount = added
            persist()
            if added == 0 {
                errorMessage = found.isEmpty
                    ? "No rooms matched those goals. Try a higher budget or a different city."
                    : "Nothing new to add. Those rooms are already lined up."
            }
        } catch {
            errorMessage = "Couldn't search for rooms. Check your connection and try again."
        }
    }

    // MARK: - Running

    /// Contacts every queued landlord, then keeps answering all of them.
    func start() async {
        guard goals.isConfirmed, goals.isUsable else {
            errorMessage = "Confirm your goals first. That's what it argues from."
            return
        }
        guard CurrentUser.shared.email != nil else {
            errorMessage = "Sign in on the Profile tab first. Messaging a landlord needs an account."
            return
        }

        isWorking = true
        errorMessage = nil

        let starting = queued
        queued = []

        for listing in starting {
            let negotiation = LandlordNegotiationService(listing: listing)
            negotiation.goals = goals
            adopt(negotiation)
            active.append(negotiation)
        }

        // Sequentially rather than all at once: each opener is a model call,
        // and ten in parallel is how you get rate-limited into a screen full of
        // failures on the one action that matters most.
        for negotiation in active where negotiation.phase == .idle {
            await negotiation.start()
        }

        isWorking = false
        persist()
        announceAnyNewDeal()
        beginPolling()
    }

    /// Keeps every open negotiation moving without the tenant watching.
    func beginPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            // Cleared on every exit, not just cancellation. Without this the
            // handle stayed non-nil after the loop returned, and the guard
            // above then refused to ever start polling again — so a
            // negotiation opened later sat there never refreshing.
            defer { Task { @MainActor in self?.pollTask = nil } }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                guard let self, !Task.isCancelled else { return }

                let running = await self.active
                if running.isEmpty { return }

                // A negotiation the server is answering is still moving, so
                // it has to keep being read. Filtering to waiting only meant
                // one stuck on "Writing a reply…" was never refreshed again.
                let waiting = running.filter {
                    if case .waitingForLandlord = $0.phase { return true }
                    if case .replying = $0.phase { return true }
                    return false
                }
                if waiting.isEmpty, await self.allSettled { return }
                for negotiation in waiting {
                    if Task.isCancelled { return }
                    await negotiation.refresh()
                }
                // Once per round, not once per landlord. Five open
                // negotiations meant five passes over the same list every six
                // seconds, each one reading and rewriting the announced set on
                // disk, and each one republishing state the whole screen lays
                // out again from.
                await self.announceAnyNewDeal()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Raises a banner and a notification the moment a landlord agrees.
    func announceAnyNewDeal() {
        for negotiation in active {
            guard case .closed(let price, let viewing) = negotiation.phase,
                  !announced.contains(negotiation.listingID) else { continue }

            announced.insert(negotiation.listingID)
            let deal = Celebration(
                room: negotiation.listing.title,
                price: price,
                asking: negotiation.listing.price.map(Int.init),
                viewing: viewing
            )
            celebration = deal
            // The chat is the tenant's negotiator. It is the thing that should
            // be telling them it won, not a card sitting above it.
            NegotiationService.shared.announce(.init(
                room: deal.room,
                price: deal.price,
                asking: deal.asking,
                viewing: deal.viewing
            ))
            LocalNotifier.dealAgreed(headline: deal.headline, detail: deal.detail)
        }
    }

    /// Every room where the landlord has agreed.
    var secured: [LandlordNegotiationService] {
        active.filter { if case .closed = $0.phase { return true } else { return false } }
    }

    /// Nothing left that could change on its own.
    private var allSettled: Bool {
        !active.isEmpty && active.allSatisfy { negotiation in
            if case .closed = negotiation.phase { return true }
            if case .failed = negotiation.phase { return true }
            return false
        }
    }

    /// The best result so far, for the summary line.
    var closedCount: Int {
        active.filter { if case .closed = $0.phase { return true } else { return false } }.count
    }

    // MARK: - Plumbing

    /// SwiftUI does not see through a nested observable, so a child changing
    /// phase would update nothing. Forwarding their announcements makes the
    /// list redraw as each negotiation moves.
    private func adopt(_ negotiation: LandlordNegotiationService) {
        negotiation.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &forwarding)
    }

    // MARK: - Stopping

    /// Calls one negotiation off.
    ///
    /// The AI answers landlords from this app, so dropping a negotiation here
    /// is what actually stops it: nothing keeps replying on a thread that is no
    /// longer in the list. The conversation itself is left alone and stays
    /// readable under Direct Messages, because the landlord is a person who was
    /// mid-conversation and deleting their side of it is not a cancellation, it
    /// is a disappearance.
    @discardableResult
    func stop(listingID: String) -> String? {
        let name = active.first { $0.listingID == listingID }?.listing.title
            ?? queued.first { $0.id == listingID }?.title

        active.removeAll { $0.listingID == listingID }
        queued.removeAll { $0.id == listingID }

        // Dropped subscriptions are rebuilt from what is left, so a stopped
        // negotiation stops driving this object's updates too.
        forwarding = []
        active.forEach { adopt($0) }

        if active.isEmpty { stopPolling() }
        persist()
        return name
    }

    /// Calls every negotiation off at once.
    @discardableResult
    func stopAll() -> Int {
        let count = active.count + queued.count
        guard count > 0 else { return 0 }

        stopPolling()
        forwarding = []
        active = []
        queued = []
        celebration = nil
        persist()
        return count
    }

    /// Clears the negotiations, and deletes the threads behind them.
    ///
    /// The same thing the website's reset does. Clearing only the app's list
    /// would leave the conversations sitting in the inbox with an AI halfway
    /// through arguing in them, which is not what anyone means by reset.
    func resetEverything() async {
        stopPolling()
        forwarding = []
        active = []
        queued = []
        announced = []
        UserDefaults.standard.removeObject(forKey: Self.announcedKey)
        celebration = nil
        errorMessage = nil
        lastMatchCount = nil
        persist()

        guard let me = CurrentUser.shared.email else { return }
        var request = URLRequest(url: AppConfig.url("api/negotiate/reset"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["userEmail": me])
        _ = try? await URLSession.shared.data(for: request)
    }
}
