import SwiftUI

/// Help, natively.
///
/// This was support.html in a web view: a four-card desktop grid, a FAQ list
/// whose questions had no answers behind them (each one only pasted itself
/// into the AI chat box), and a contact form. The two things it actually does
/// are `/api/chat` and `/api/contact`; the rest was layout iOS already has.
struct SupportScreen: View {

    @Environment(\.dismiss) private var dismiss

    /// The site's "Popular Questions". They were never answers, so they are
    /// what they always were underneath: openers for the assistant.
    private static let common = [
        "How do I create an account?",
        "How do I search for properties?",
        "Is RoomFinderAI free to use?",
        "I can't log in to my account",
        "How do I contact landlords?",
        "What is the AI Negotiator?"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SupportChatScreen()
                    } label: {
                        row("Ask the assistant",
                            "Answers straight away, any hour",
                            "bubble.left.and.text.bubble.right.fill")
                    }

                    NavigationLink {
                        ContactSupportScreen()
                    } label: {
                        row("Message the team",
                            "A person replies within 24 hours",
                            "envelope.fill")
                    }
                }

                Section {
                    ForEach(Self.common, id: \.self) { question in
                        NavigationLink {
                            SupportChatScreen(opener: question)
                        } label: {
                            Text(question)
                        }
                    }
                } header: {
                    Text("Common questions")
                } footer: {
                    Text("Each one opens the assistant with the question already asked.")
                }
            }
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: String, _ detail: String, _ symbol: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Theme.brand)
        }
    }
}

/// The assistant, as a conversation rather than a page.
private struct SupportChatScreen: View {

    /// Set when the question was picked from the list, so it is asked on
    /// arrival instead of making someone type it out again.
    var opener: String?

    @State private var draft = ""
    @State private var turns: [Turn] = []
    @State private var isSending = false
    @State private var errorMessage: String?

    private struct Turn: Identifiable {
        let id = UUID()
        let mine: Bool
        let text: String
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(turns) { turn in
                        Text(turn.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(turn.mine ? Theme.brand.opacity(0.15) : Color(.secondarySystemBackground))
                            )
                            .frame(maxWidth: .infinity, alignment: turn.mine ? .trailing : .leading)
                            .textSelection(.enabled)
                    }

                    if isSending {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
            }
            // Rather than a ScrollViewReader, which forces every message in a
            // lazy stack to be built to find the one to scroll to. That was a
            // measured cause of the negotiator pinning the CPU.
            .defaultScrollAnchor(.bottom)

            Divider()

            HStack(spacing: 10) {
                TextField("Ask anything about RoomFinderAI", text: $draft)
                    .textFieldStyle(.plain)
                    // Fixed height on purpose. A vertical TextField that grows
                    // with its content re-measures on every keystroke, which
                    // is the other half of that same CPU problem.
                    .frame(height: 22)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(.secondarySystemBackground)))
                    .submitLabel(.send)
                    .onSubmit(send)

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                .accessibilityLabel("Send")
            }
            .padding(12)
        }
        .navigationTitle("Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let opener, turns.isEmpty else { return }
            ask(opener)
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        ask(text)
    }

    private func ask(_ text: String) {
        turns.append(Turn(mine: true, text: text))
        errorMessage = nil
        isSending = true

        Task {
            do {
                let answer = try await LegalAPI.chat(text)
                turns.append(Turn(mine: false, text: answer))
            } catch {
                errorMessage = (error as? LegalAPI.Failure)?.message
                    ?? "Couldn't reach support. Check your connection and try again."
            }
            isSending = false
        }
    }
}

/// The contact form, which posts the same four fields the website's does.
private struct ContactSupportScreen: View {

    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = CurrentUser.shared.email ?? ""
    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var sent = false

    private var canSend: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && email.contains("@")
            && message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
            && !isSending
    }

    var body: some View {
        Form {
            if sent {
                Section {
                    Label("Message sent. We'll reply within 24 hours.",
                          systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Section("Your details") {
                TextField("First name", text: $firstName)
                    .textContentType(.givenName)
                TextField("Last name", text: $lastName)
                    .textContentType(.familyName)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("How can we help?") {
                TextField("Tell us what's going on", text: $message, axis: .vertical)
                    .lineLimit(4...10)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    submit()
                } label: {
                    if isSending {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Send message")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canSend)
            }
        }
        .navigationTitle("Message the team")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        isSending = true
        errorMessage = nil

        Task {
            do {
                try await SupportAPI.contact(
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces),
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                sent = true
                message = ""
                Haptics.impact(.light)
            } catch {
                errorMessage = (error as? LegalAPI.Failure)?.message
                    ?? "Couldn't send that. Check your connection and try again."
            }
            isSending = false
        }
    }
}

/// The one call the contact form makes.
@MainActor
enum SupportAPI {
    static func contact(firstName: String, lastName: String, email: String, message: String) async throws {
        var request = URLRequest(url: AppConfig.url("api/contact"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "message": message
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LegalAPI.Failure(message: "No answer from the server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            struct Refusal: Decodable { let message: String?; let error: String? }
            let decoded = try? JSONDecoder().decode(Refusal.self, from: data)
            throw LegalAPI.Failure(
                message: decoded?.error ?? decoded?.message ?? "That didn't send (error \(http.statusCode))."
            )
        }
    }
}
