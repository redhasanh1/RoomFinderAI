import SwiftUI

/// Subleases, natively.
///
/// This was the last screen in the app rendering the website inside a web view,
/// and it showed: a page built for a mouse, opened in a sheet, with its own
/// header and navigation inside the app's. The data was always available over
/// the same API the site uses.
struct SubleaseScreen: View {

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case offering = "Offering"
        case looking = "Looking"
        var id: String { rawValue }
    }

    @State private var requests: [SubleaseRequest] = []
    @State private var filter: Filter = .all
    @State private var query = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && requests.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, requests.isEmpty {
                    StatusScreen(
                        symbol: "wifi.exclamationmark",
                        title: "Couldn't load subleases",
                        message: errorMessage,
                        actionTitle: "Try Again",
                        action: { Task { await load() } }
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Sublease")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { MoreMenu() }
            }
        }
        .task { if requests.isEmpty { await load() } }
    }

    private var visible: [SubleaseRequest] {
        requests.filter { request in
            let matchesKind: Bool
            switch filter {
            case .all:      matchesKind = true
            case .offering: matchesKind = request.kind == .transfer
            case .looking:  matchesKind = request.kind == .seeking
            }

            guard matchesKind else { return false }
            guard !query.isEmpty else { return true }

            let haystack = [request.displayTitle, request.place, request.description ?? ""]
                .joined(separator: " ").lowercased()
            return haystack.contains(query.lowercased())
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                searchBar
                kindPicker

                if visible.isEmpty {
                    Text(query.isEmpty
                         ? "Nothing here yet. Post yours and it'll show up for everyone else."
                         : "Nothing matches \"\(query)\".")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    ForEach(visible) { request in
                        NavigationLink(value: request) {
                            card(for: request)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .navigationDestination(for: SubleaseRequest.self) { SubleaseDetailScreen(request: $0) }
        .refreshable { await load() }
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.brand)

            TextField("Search by city", text: $query)
                .textFieldStyle(.plain)
                .font(.callout)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    Haptics.impact(.light)
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }

            DictationButton(text: $query, size: 24)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color(.systemBackground)))
        .overlay(Capsule().strokeBorder(Theme.brand.opacity(0.35), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    /// Offering and looking are opposite needs, and mixing them in one list
    /// means half of what you scroll past is useless to you.
    private var kindPicker: some View {
        Picker("Show", selection: $filter) {
            ForEach(Filter.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private func card(for request: SubleaseRequest) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Label(request.kind.label, systemImage: request.kind.symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(request.kind == .transfer ? Color.green : Theme.brand)

                if request.isUrgent {
                    Text("Urgent")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.orange))
                }

                Spacer()

                Text(request.moneyLine)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.brand)
            }

            Text(request.displayTitle)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if !request.place.isEmpty {
                Label(request.place, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let dates = request.datesLine {
                Label(dates, systemImage: "calendar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !request.detailLine.isEmpty {
                Text(request.detailLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var components = URLComponents(url: AppConfig.url("api/sublease/search"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [.init(name: "limit", value: "50")]

        guard let url = components.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(SubleaseSearchResponse.self, from: data) else {
            errorMessage = "Check your connection and try again."
            return
        }

        requests = decoded.requests ?? []
    }
}

/// One sublease, and the way to reach the person behind it.
struct SubleaseDetailScreen: View {

    let request: SubleaseRequest

    @State private var isSending = false
    @State private var outcome: String?
    @State private var didSend = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let description = request.description?.nilIfEmpty {
                    section("About") {
                        Text(description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                facts

                if let amenities = request.amenities, !amenities.isEmpty {
                    section("Amenities") {
                        // Wraps rather than scrolls: a list you have to swipe
                        // sideways hides half of itself.
                        FlowRow(spacing: 8) {
                            ForEach(amenities, id: \.self) { amenity in
                                Text(amenity.capitalized)
                                    .font(.footnote.weight(.medium))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Theme.brand.opacity(0.12)))
                                    .foregroundStyle(Theme.brand)
                            }
                        }
                    }
                }

                interestButton
            }
            .padding(20)
        }
        .navigationTitle(request.kind.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(request.kind.label, systemImage: request.kind.symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(request.kind == .transfer ? Color.green : Theme.brand)

            Text(request.displayTitle)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(request.moneyLine)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.brand)

            if !request.place.isEmpty {
                Label(request.place, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var facts: some View {
        section("Details") {
            VStack(alignment: .leading, spacing: 8) {
                if let dates = request.datesLine { row("Dates", dates, "calendar") }
                if let months = request.durationMonths, months > 0 {
                    row("Length", "\(months) month\(months == 1 ? "" : "s")", "clock")
                }
                if let type = request.propertyType?.nilIfEmpty {
                    row("Property", type.capitalized, "building.2")
                }
                if request.furnished == true { row("Furnished", "Yes", "bed.double") }
                if request.utilitiesIncluded == true { row("Utilities", "Included", "bolt") }
                if request.petFriendly == true { row("Pets", "Allowed", "pawprint") }
            }
        }
    }

    private func row(_ label: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.footnote)
                .foregroundStyle(Theme.brand)
                .frame(width: 20)
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.medium))
        }
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var interestButton: some View {
        VStack(spacing: 8) {
            Button {
                Haptics.impact(.medium)
                Task { await expressInterest() }
            } label: {
                HStack(spacing: 8) {
                    if isSending {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: didSend ? "checkmark" : "bubble.left.and.bubble.right.fill")
                    }
                    Text(didSend ? "They've been told" : "I'm interested")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(didSend ? AnyShapeStyle(Color.green) : AnyShapeStyle(Theme.gradient),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isSending || didSend)

            if let outcome {
                Text(outcome)
                    .font(.footnote)
                    .foregroundStyle(didSend ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func expressInterest() async {
        guard let me = CurrentUser.shared.email else {
            outcome = "Sign in on the Profile tab first to get in touch."
            return
        }

        isSending = true
        outcome = nil
        defer { isSending = false }

        var httpRequest = URLRequest(url: AppConfig.url("api/sublease/express-interest"))
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.timeoutInterval = 30
        httpRequest.httpBody = try? JSONSerialization.data(withJSONObject: [
            "requestId": request.id,
            "userEmail": me
        ])

        guard let (data, response) = try? await URLSession.shared.data(for: httpRequest),
              let http = response as? HTTPURLResponse else {
            outcome = "Couldn't reach them. Check your connection."
            return
        }

        guard (200..<300).contains(http.statusCode) else {
            struct Failure: Decodable { let error: String? }
            let message = (try? JSONDecoder().decode(Failure.self, from: data))?.error
            outcome = message ?? "That didn't go through. Try again."
            return
        }

        didSend = true
        outcome = "They'll see it in their messages, and you can carry on there."
    }
}

/// Chips that wrap onto the next line instead of running off the screen.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
