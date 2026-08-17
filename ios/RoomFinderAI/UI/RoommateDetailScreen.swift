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

                NavigationLink {
                    WebPageScreen(url: AppConfig.url("roommate-matching.html"), title: "Get in touch")
                } label: {
                    Label("Get in touch", systemImage: "envelope.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .simultaneousGesture(TapGesture().onEnded { Haptics.impact(.medium) })
            }
            .padding(20)
        }
        .navigationTitle(profile.displayName)
        .navigationBarTitleDisplayMode(.inline)
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
