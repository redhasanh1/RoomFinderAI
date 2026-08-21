import SwiftUI

/// A legal question, answered.
struct LegalQuestionScreen: View {

    @State private var question = ""
    @State private var answer: String?
    @State private var isAsking = false
    @State private var errorMessage: String?
    @FocusState private var typing: Bool

    private let starters = [
        "My landlord kept my deposit. What can I do?",
        "Can my rent be raised mid-lease?",
        "The heat has been broken for two weeks."
    ]

    var body: some View {
        Form {
            Section {
                TextField("Describe what happened", text: $question, axis: .vertical)
                    .lineLimit(3...8)
                    .focused($typing)
            } header: {
                Text("Your situation")
            } footer: {
                Text("The more specific you are, the more useful the answer. Include dates and what was said.")
            }

            if answer == nil && !isAsking {
                Section("Or start from one of these") {
                    ForEach(starters, id: \.self) { starter in
                        Button {
                            Haptics.impact(.light)
                            question = starter
                            typing = false
                            Task { await ask() }
                        } label: {
                            Text(starter)
                                .font(.subheadline)
                                .foregroundStyle(Theme.brand)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            if isAsking {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Reading it over…").foregroundStyle(.secondary)
                    }
                }
            }

            if let answer {
                Section("Answer") {
                    Text(answer)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Ask a question")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isAsking {
                    ProgressView()
                } else {
                    Button("Ask") { typing = false; Task { await ask() } }
                        .fontWeight(.semibold)
                        .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func ask() async {
        let asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !asked.isEmpty else { return }
        isAsking = true
        errorMessage = nil
        answer = nil

        do {
            answer = try await LegalAPI.chat(
                "A tenant asks: \(asked). Answer in plain language, in under 200 words. "
                + "Say what their rights usually are, what to do next, and when to get a lawyer. "
                + "Do not invent a specific law or section number."
            )
        } catch {
            errorMessage = (error as? LegalAPI.Failure)?.message
                ?? "Couldn't get an answer. Check your connection and try again."
        }
        isAsking = false
    }
}

/// Paste a lease, get the parts worth arguing about.
struct LeaseReviewScreen: View {

    @State private var lease = ""
    @State private var findings: String?
    @State private var isReviewing = false
    @State private var errorMessage: String?
    @FocusState private var typing: Bool

    var body: some View {
        Form {
            Section {
                TextField("Paste the lease text here", text: $lease, axis: .vertical)
                    .lineLimit(6...20)
                    .font(.footnote)
                    .focused($typing)
            } header: {
                Text("The lease")
            } footer: {
                Text("Paste as much as you have. Nothing is stored: it is sent, read and the answer comes back.")
            }

            if isReviewing {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Reading the lease…").foregroundStyle(.secondary)
                    }
                }
            }

            if let findings {
                Section("What stood out") {
                    Text(findings)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Review my lease")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isReviewing {
                    ProgressView()
                } else {
                    Button("Review") { typing = false; Task { await review() } }
                        .fontWeight(.semibold)
                        .disabled(lease.trimmingCharacters(in: .whitespacesAndNewlines).count < 40)
                }
            }
        }
    }

    private func review() async {
        isReviewing = true
        errorMessage = nil
        findings = nil
        do {
            findings = try await LegalAPI.reviewLease(lease)
        } catch {
            errorMessage = (error as? LegalAPI.Failure)?.message
                ?? "Couldn't review that. Check your connection and try again."
        }
        isReviewing = false
    }
}

/// The letters people actually need to send.
struct LegalDocumentScreen: View {

    enum Kind: String, CaseIterable, Identifiable {
        case noticeToVacate = "Notice to vacate"
        case repairRequest  = "Repair request"
        case depositDemand  = "Deposit demand"
        case rentDispute    = "Dispute a rent increase"
        case entryComplaint = "Entry without notice"

        var id: String { rawValue }
    }

    @State private var kind: Kind = .repairRequest
    @State private var place = ""
    @State private var detail = ""
    @State private var letter: String?
    @State private var isWriting = false
    @State private var errorMessage: String?
    @State private var copied = false

    var body: some View {
        Form {
            Section("What do you need") {
                Picker("Letter", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                }
            }

            Section {
                TextField("City or province", text: $place)
                    .textInputAutocapitalization(.words)
                TextField("What happened, in your words", text: $detail, axis: .vertical)
                    .lineLimit(3...8)
            } header: {
                Text("Details")
            } footer: {
                Text("Where you live changes the notice periods, so it is worth filling in.")
            }

            if isWriting {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Writing it…").foregroundStyle(.secondary)
                    }
                }
            }

            if let letter {
                Section {
                    Text(letter)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)

                    Button {
                        UIPasteboard.general.string = letter
                        Haptics.impact(.medium)
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy the letter",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }

                    ShareLink(item: letter) {
                        Label("Send it", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Your letter")
                } footer: {
                    Text("Read it before you send it, and change anything that is not true of your situation.")
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Write a letter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isWriting {
                    ProgressView()
                } else {
                    Button("Write") { Task { await write() } }
                        .fontWeight(.semibold)
                        .disabled(detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func write() async {
        isWriting = true
        errorMessage = nil
        letter = nil
        copied = false

        let where_ = place.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            letter = try await LegalAPI.chat(
                "Write a \(kind.rawValue.lowercased()) letter from a tenant to their landlord"
                + (where_.isEmpty ? "" : " in \(where_)")
                + ". The tenant's situation: \(detail.trimmingCharacters(in: .whitespacesAndNewlines)). "
                + "Return only the letter, ready to send. Firm and polite, no legal threats, "
                + "no invented law or section numbers. Leave [square brackets] where a date, "
                + "name or address is needed."
            )
        } catch {
            errorMessage = (error as? LegalAPI.Failure)?.message
                ?? "Couldn't write that. Check your connection and try again."
        }
        isWriting = false
    }
}

/// The two calls the legal pages make, in one place.
///
/// Main-actor isolated because it reads the signed-in address, which lives on
/// an observable object the UI owns. The awaits inside still suspend, so
/// nothing blocks while the network is working.
@MainActor
enum LegalAPI {
    struct Failure: Error { let message: String }

    static func chat(_ prompt: String) async throws -> String {
        var body: [String: Any] = ["message": prompt, "conversationHistory": []]
        if let email = CurrentUser.shared.email { body["userEmail"] = email }

        struct Reply: Decodable { let response: String? }
        let data = try await post("api/chat", body)
        guard let text = (try? JSONDecoder().decode(Reply.self, from: data))?.response,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure(message: "The answer came back empty. Try asking it another way.")
        }
        return text
    }

    static func reviewLease(_ text: String) async throws -> String {
        struct Reply: Decodable { let review: String?; let response: String?; let analysis: String? }
        let data = try await post("api/negotiate/lease-review", ["leaseText": text])
        let decoded = try? JSONDecoder().decode(Reply.self, from: data)
        guard let found = decoded?.review ?? decoded?.analysis ?? decoded?.response,
              !found.isEmpty else {
            throw Failure(message: "Nothing came back for that. Try pasting more of the lease.")
        }
        return found
    }

    private static func post(_ path: String, _ body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: AppConfig.url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw Failure(message: "No answer from the server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            // The server explains its own limits better than a status code can.
            struct Refusal: Decodable { let message: String?; let error: String? }
            let stated = (try? JSONDecoder().decode(Refusal.self, from: data))?.message
            throw Failure(message: stated ?? "That didn't work (error \(http.statusCode)).")
        }
        return data
    }
}
