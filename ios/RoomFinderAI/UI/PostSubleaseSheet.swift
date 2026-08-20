import SwiftUI

/// Post a sublease, natively.
///
/// The Sublease tab could show everyone else's and let you message them, but
/// there was no way to add your own — the empty state literally said "post
/// yours and it'll show up" next to nothing you could tap. The API has taken
/// these since the website shipped.
///
/// Two directions, one form: handing over a place you hold, or looking for one.
/// Which one you picked changes what is asked, because a rent you charge and a
/// budget you can afford are not the same number and asking for both gets you
/// neither.
struct PostSubleaseSheet: View {

    /// Called after a successful post so the list behind the sheet refreshes
    /// rather than leaving you staring at a page your own entry is missing from.
    var onPosted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var user = CurrentUser.shared

    @State private var kind: SubleaseRequest.Kind = .transfer
    @State private var title = ""
    @State private var city = ""
    @State private var state = ""
    @State private var address = ""
    @State private var details = ""

    @State private var rent = ""
    @State private var minBudget = ""
    @State private var maxBudget = ""

    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()

    @State private var propertyType = "Apartment"
    @State private var bedrooms = 1
    @State private var bathrooms = 1
    @State private var furnished = false
    @State private var utilitiesIncluded = false
    @State private var petFriendly = false
    @State private var urgency: Urgency = .soon

    @State private var isPosting = false
    @State private var errorMessage: String?

    private static let propertyTypes = ["Apartment", "House", "Condo", "Studio", "Room", "Townhouse"]

    /// Stored as the 1 to 5 the server keeps, so the "Urgent" flag on a card
    /// means the same thing however the row got there.
    enum Urgency: String, CaseIterable, Identifiable {
        case flexible = "Flexible"
        case soon = "Within a month"
        case urgent = "Urgent"

        var id: String { rawValue }

        var level: Int {
            switch self {
            case .flexible: return 2
            case .soon:     return 3
            case .urgent:   return 5
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Text("I have a place").tag(SubleaseRequest.Kind.transfer)
                        Text("I need a place").tag(SubleaseRequest.Kind.seeking)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, _ in Haptics.select() }
                } footer: {
                    Text(kind == .transfer
                         ? "You're handing over a place you already hold."
                         : "You're looking for someone else's place to take over.")
                }

                Section("The basics") {
                    TextField(kind == .transfer
                              ? "Summer sublet, downtown 1BR"
                              : "Grad student needs a 6 month sublet",
                              text: $title)
                        .textInputAutocapitalization(.sentences)

                    TextField("City", text: $city)
                        .textInputAutocapitalization(.words)
                    TextField("Province or state", text: $state)
                        .textInputAutocapitalization(.words)

                    if kind == .transfer {
                        TextField("Street address (optional)", text: $address)
                            .textInputAutocapitalization(.words)
                    }
                }

                if kind == .transfer {
                    Section("Rent") {
                        HStack {
                            Text("$")
                                .foregroundStyle(.secondary)
                            TextField("1500", text: $rent)
                                .keyboardType(.numberPad)
                            Text("/month")
                                .foregroundStyle(.secondary)
                        }
                        Toggle("Utilities included", isOn: $utilitiesIncluded)
                    }
                } else {
                    Section {
                        HStack {
                            Text("$")
                                .foregroundStyle(.secondary)
                            TextField("Least", text: $minBudget)
                                .keyboardType(.numberPad)
                            Text("to $")
                                .foregroundStyle(.secondary)
                            TextField("Most", text: $maxBudget)
                                .keyboardType(.numberPad)
                        }
                    } header: {
                        Text("Your budget")
                    } footer: {
                        Text("A range gets you more replies than a hard number.")
                    }
                }

                Section(kind == .transfer ? "Available" : "When you need it") {
                    DatePicker(kind == .transfer ? "From" : "Move in",
                               selection: $startDate, displayedComponents: .date)
                    DatePicker(kind == .transfer ? "Until" : "Move out",
                               selection: $endDate, in: startDate..., displayedComponents: .date)
                    Picker("How soon", selection: $urgency) {
                        ForEach(Urgency.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("The place") {
                    Picker("Type", selection: $propertyType) {
                        ForEach(Self.propertyTypes, id: \.self) { Text($0).tag($0) }
                    }
                    Stepper("\(bedrooms) bedroom\(bedrooms == 1 ? "" : "s")", value: $bedrooms, in: 0...8)
                    Stepper("\(bathrooms) bathroom\(bathrooms == 1 ? "" : "s")", value: $bathrooms, in: 1...6)
                    Toggle("Furnished", isOn: $furnished)
                    Toggle("Pets allowed", isOn: $petFriendly)
                }

                Section {
                    TextField(kind == .transfer
                              ? "Anything worth knowing: the building, the commute, why you're leaving."
                              : "Anything worth knowing: who you are, what you're after.",
                              text: $details, axis: .vertical)
                        .lineLimit(4...10)
                } header: {
                    Text("Description")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if !user.isSignedIn {
                    Section {
                        Label("Sign in from the Profile tab first. A sublease has to be attached to an account so people can reach you.",
                              systemImage: "person.crop.circle.badge.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Post a sublease")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isPosting {
                        ProgressView()
                    } else {
                        Button("Post") { Task { await post() } }
                            .fontWeight(.semibold)
                            .disabled(!canPost)
                    }
                }
            }
        }
    }

    /// Checked here rather than after the round trip, so nobody fills in a
    /// whole form to be told the server wanted a city.
    private var canPost: Bool {
        guard user.isSignedIn else { return false }
        guard !title.trimmed.isEmpty, !city.trimmed.isEmpty else { return false }
        return kind == .transfer ? Int(rent.trimmed) ?? 0 > 0
                                 : Int(maxBudget.trimmed) ?? 0 > 0
    }

    private func post() async {
        guard let email = user.email else { return }
        isPosting = true
        errorMessage = nil

        var payload: [String: Any] = [
            "userEmail": email,
            "type": kind.rawValue,
            "title": title.trimmed,
            "description": details.trimmed,
            "city": city.trimmed,
            "state": state.trimmed,
            "propertyType": propertyType,
            "bedrooms": bedrooms,
            "bathrooms": bathrooms,
            "furnished": furnished,
            "petFriendly": petFriendly,
            "urgencyLevel": urgency.level,
            "durationMonths": max(1, months(from: startDate, to: endDate))
        ]

        // The two directions use different date columns and different money
        // columns; sending both sets would put a rent on a request from
        // somebody who has no place to rent out.
        if kind == .transfer {
            payload["address"] = address.trimmed
            payload["rentAmount"] = Int(rent.trimmed) ?? 0
            payload["utilitiesIncluded"] = utilitiesIncluded
            payload["availableFrom"] = Self.day(startDate)
            payload["availableUntil"] = Self.day(endDate)
        } else {
            if let low = Int(minBudget.trimmed), low > 0 { payload["minBudget"] = low }
            payload["maxBudget"] = Int(maxBudget.trimmed) ?? 0
            payload["preferredMoveIn"] = Self.day(startDate)
            payload["preferredMoveOut"] = Self.day(endDate)
        }

        do {
            var request = URLRequest(url: AppConfig.url("api/sublease/request"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                struct Failure: Decodable { let error: String?; let details: String? }
                let decoded = try? JSONDecoder().decode(Failure.self, from: data)
                throw PostSubleaseError(message: decoded?.details ?? decoded?.error
                                        ?? "Couldn't post that. Try again in a moment.")
            }

            Haptics.impact(.medium)
            onPosted()
            dismiss()
        } catch let failure as PostSubleaseError {
            errorMessage = failure.message
        } catch {
            errorMessage = "Couldn't reach the server. Check your connection."
        }
        isPosting = false
    }

    private func months(from: Date, to: Date) -> Int {
        Calendar.current.dateComponents([.month], from: from, to: to).month ?? 1
    }

    /// The date only. The column is a date, and sending a timestamp in the
    /// phone's timezone lands the odd row a day early.
    private static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct PostSubleaseError: Error { let message: String }

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
