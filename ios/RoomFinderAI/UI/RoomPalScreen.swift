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

    @State private var kind: RoommateProfile.Kind = .seeking
    @State private var city = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                    } else if service.profiles.isEmpty && service.hasLoadedOnce {
                        StatusScreen(
                            symbol: "person.2.slash",
                            title: emptyTitle,
                            message: city.isEmpty
                                ? "Nobody has posted here yet. Check back soon."
                                : "Nobody matches \"\(city)\". Try another city.",
                            actionTitle: city.isEmpty ? "Refresh" : "Clear search",
                            action: { city = ""; reload() }
                        )
                    } else {
                        people
                    }
                }
            }
            .navigationTitle("RoomPal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { MoreMenu() }
            }
            .searchable(text: $city, prompt: "Filter by city")
            .onChange(of: city) { _, _ in scheduleSearch() }
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

    private var people: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                HStack {
                    Text("\(visibleProfiles.count) \(visibleProfiles.count == 1 ? "person" : "people")")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)

                ForEach(visibleProfiles) { profile in
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
        .accessibilityElement(children: .combine)
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
