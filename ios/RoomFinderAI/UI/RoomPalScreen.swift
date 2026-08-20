import SwiftUI

/// RoomPal — the people side of the marketplace, rendered natively.
///
/// Two halves that must not be confused: people **looking for a room**, and
/// people **with a room to share**. The website learned this the hard way; the
/// segmented control makes which one you are looking at unmissable.
struct RoomPalScreen: View {

    @EnvironmentObject private var state: AppState
    @ObservedObject private var network = NetworkMonitor.shared
    @ObservedObject private var moderation = ModerationService.shared
    @StateObject private var service = RoommateService()

    /// A switcher pinned above the content, supplied by the tab that hosts
    /// both halves of the people side. Nil when this screen stands alone.
    var header: AnyView?

    @State private var kind: RoommateProfile.Kind = .seeking
    @State private var city = ""
    @State private var filters = Filters()
    @State private var showingFilters = false
    @State private var showingPost = false
    @State private var searchTask: Task<Void, Never>?

    /// Everything the people list can be narrowed or reordered by.
    ///
    /// This was one row of budget chips, which could say "under $1,200" and
    /// nothing else — not when someone is free to move, not whether they had
    /// bothered to write anything about themselves, not what order to read
    /// them in. Scrolling a flat list of strangers is the slowest possible way
    /// to find someone you could actually live with.
    struct Filters: Equatable {
        var minBudget: Int?
        var maxBudget: Int?
        /// Nobody useful is moving after this.
        var moveInBy: Date?
        var withPhoto = false
        var withBio = false
        var sort: Sort = .newest

        enum Sort: String, CaseIterable, Identifiable {
            case newest    = "Newest first"
            case cheapest  = "Lowest budget first"
            case highest   = "Highest budget first"

            var id: String { rawValue }

            var symbol: String {
                switch self {
                case .newest:   return "clock"
                case .cheapest: return "arrow.down.right"
                case .highest:  return "arrow.up.right"
                }
            }
        }

        var isNarrowing: Bool {
            minBudget != nil || maxBudget != nil || moveInBy != nil || withPhoto || withBio
        }

        var isActive: Bool { isNarrowing || sort != .newest }

        var count: Int {
            [minBudget != nil, maxBudget != nil, moveInBy != nil, withPhoto, withBio]
                .filter { $0 }.count
        }

        /// The number to compare against depends on which side someone is on:
        /// a person offering a room has a rent, a person looking has a range
        /// they can stretch to. Comparing a seeker's floor to a ceiling filter
        /// is what makes "under $800" hide everybody who could afford $800.
        private func money(for profile: RoommateProfile) -> Int? {
            if profile.kind == .hasSpot, let rent = profile.roomRent, rent > 0 { return rent }
            if let low = profile.budgetMin, low > 0 { return low }
            if let high = profile.budgetMax, high > 0 { return high }
            return nil
        }

        func matches(_ profile: RoommateProfile) -> Bool {
            if minBudget != nil || maxBudget != nil {
                guard let amount = money(for: profile) else { return false }
                if let low = minBudget, amount < low { return false }
                if let high = maxBudget, amount > high { return false }
            }
            if let moveInBy {
                guard let raw = profile.moveInDate, let date = Self.date(from: raw) else { return false }
                if date > moveInBy { return false }
            }
            if withPhoto, profile.avatarURL == nil { return false }
            if withBio, profile.cleanBio == nil { return false }
            return true
        }

        /// Newest is the order the API already returns.
        func sorted(_ people: [RoommateProfile]) -> [RoommateProfile] {
            switch sort {
            case .newest:
                return people
            case .cheapest:
                return people.sorted { (money(for: $0) ?? .max) < (money(for: $1) ?? .max) }
            case .highest:
                return people.sorted { (money(for: $0) ?? -1) > (money(for: $1) ?? -1) }
            }
        }

        static func date(from raw: String) -> Date? {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withFullDate]
            return iso.date(from: String(raw.prefix(10)))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let header { header }
                searchRow
                picker

                Group {
                    if service.isLoading && service.profiles.isEmpty {
                        LoadingPeople()
                    } else if let error = service.errorMessage, service.profiles.isEmpty {
                        StatusScreen(
                            symbol: "wifi.exclamationmark",
                            title: "Couldn't load people",
                            message: error,
                            actionTitle: "Try Again",
                            action: reload
                        )
                    } else if shownProfiles.isEmpty && service.hasLoadedOnce {
                        StatusScreen(
                            symbol: "person.2.slash",
                            title: emptyTitle,
                            message: (city.isEmpty && !filters.isNarrowing)
                                ? "Nobody has posted here yet. Check back soon."
                                : "Nobody matches those filters. Try a wider budget or another city.",
                            actionTitle: (city.isEmpty && !filters.isNarrowing) ? "Refresh" : "Clear filters",
                            action: { city = ""; filters = Filters(); reload() }
                        )
                    } else {
                        people
                    }
                }
            }
            .navigationTitle("RoomPal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.impact(.light)
                        showingPost = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.brand)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Theme.brand.opacity(0.12)))
                    }
                    .accessibilityLabel("Post your profile")
                }
                ToolbarItem(placement: .topBarTrailing) { MoreMenu() }
            }
            .fullScreenCover(isPresented: $showingPost) {
                PostRoommateSheet(onPosted: { reload() })
            }
            .onChange(of: city) { _, _ in scheduleSearch() }
            .sheet(isPresented: $showingFilters) {
                RoommateFilterSheet(filters: $filters, people: visibleProfiles)
            }
            .refreshable { await reloadAsync() }
        }
        .task {
            if !service.hasLoadedOnce || service.errorMessage != nil || service.profiles.isEmpty {
                reload()
            }
        }
        .onChange(of: network.isOnline) { wasOnline, isOnline in
            guard !wasOnline, isOnline, service.profiles.isEmpty else { return }
            reload()
        }
    }

    private var picker: some View {
        Picker("Show", selection: $kind) {
            Text("Looking for a room").tag(RoommateProfile.Kind.seeking)
            Text("Has a room").tag(RoommateProfile.Kind.hasSpot)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onChange(of: kind) { _, _ in
            Haptics.select()
            reload()
        }
    }

    /// Search and filters on one line, the same shape as the rooms tab. A
    /// system search bar sat above the section switcher while everything else
    /// sat below it, so the page had a control in a different place depending
    /// on which half you were reading.
    private var searchRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.brand)

                TextField("Search by city", text: $city)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)

                if !city.isEmpty {
                    Button {
                        Haptics.impact(.light)
                        city = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }

                DictationButton(text: $city, size: 24)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color(.systemBackground)))
            .overlay(Capsule().strokeBorder(Theme.brand.opacity(0.35), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)

            Button {
                Haptics.impact(.light)
                showingFilters = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .semibold))
                    if filters.count > 0 {
                        Text("\(filters.count)").font(.footnote.weight(.bold))
                    }
                }
                .padding(.horizontal, filters.isNarrowing ? 14 : 13)
                .padding(.vertical, 12)
                .foregroundStyle(filters.isNarrowing ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.brand))
                .background(
                    Capsule().fill(filters.isNarrowing
                                   ? AnyShapeStyle(Theme.gradient)
                                   : AnyShapeStyle(Color(.systemBackground)))
                )
                .overlay(
                    Capsule().strokeBorder(
                        filters.isNarrowing ? Color.clear : Theme.brand.opacity(0.35),
                        lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filters")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var people: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                HStack {
                    Text("\(shownProfiles.count) \(shownProfiles.count == 1 ? "person" : "people")")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)

                ForEach(shownProfiles) { profile in
                    NavigationLink {
                        RoommateDetailScreen(profile: profile)
                    } label: {
                        RoommateCard(profile: profile)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 96)
        }
    }

    private var emptyTitle: String {
        kind == .seeking ? "No one looking right now" : "No rooms offered yet"
    }

    /// Blocked people are removed here so blocking means something.
    private var visibleProfiles: [RoommateProfile] {
        guard !moderation.blockedEmails.isEmpty else { return service.profiles }
        // Profiles carry no email, so blocking is enforced by id where the
        // block list holds one; the marketplace still hides them everywhere an
        // address IS known (listings, messages).
        return service.profiles.filter { !moderation.blockedEmails.contains($0.id.lowercased()) }
    }

    /// What is actually shown: block list, then the budget band.
    private var shownProfiles: [RoommateProfile] {
        filters.sorted(visibleProfiles.filter { filters.matches($0) })
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            service.load(kind: kind, city: city)
        }
    }

    private func reload() { service.load(kind: kind, city: city) }

    private func reloadAsync() async {
        Haptics.impact(.light)
        reload()
        try? await Task.sleep(for: .milliseconds(600))
    }
}

private struct RoommateCard: View {
    let profile: RoommateProfile

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Avatar(profile: profile)

            VStack(alignment: .leading, spacing: 5) {
                Text(profile.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Label(profile.locationText, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let bio = profile.cleanBio {
                    Text(bio)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Text(profile.budgetText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.brand)
                    .padding(.top, 1)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        // Spelled out rather than combined: .combine walks the subtree and
        // forces it to lay out, which on a card in a lazy list never settles.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(profile.displayName), \(profile.locationText), \(profile.budgetText)")
        .accessibilityHint("Opens this profile")
    }
}

private struct Avatar: View {
    let profile: RoommateProfile

    var body: some View {
        AsyncImage(url: profile.avatarURL) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                // Initials rather than a grey silhouette: a page of identical
                // placeholder heads makes everyone look like nobody.
                ZStack {
                    Theme.gradient
                    Text(profile.initials)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }
}

private struct LoadingPeople: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(alignment: .top, spacing: 14) {
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 8) {
                            bar(width: 140)
                            bar(width: 190)
                            bar(width: 100)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }

    private func bar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.secondarySystemBackground))
            .frame(width: width, height: 12)
    }
}
