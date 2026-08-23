import SwiftUI

/// Everyone this account has blocked, and the way back.
///
/// Guideline 1.2 asks for a way to block abusive users. Blocking with no way
/// to undo it is not that: it turns a tap made in a bad moment into something
/// permanent, and people who know that hesitate to use it at all. The list
/// also makes blocking visible — before this there was no screen anywhere that
/// admitted the block list existed.
struct BlockedPeopleScreen: View {

    @ObservedObject private var moderation = ModerationService.shared
    @ObservedObject private var user = CurrentUser.shared

    @State private var working: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if moderation.blockedList.isEmpty {
                Section {
                    Text("You haven't blocked anyone.")
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Blocking someone hides their rooms, their roommate profile and their messages from you.")
                }
            } else {
                Section {
                    ForEach(moderation.blockedList, id: \.self) { email in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                // The local part, matching how a conversation
                                // names the other person, so the same human is
                                // recognisable in both places.
                                Text(email.split(separator: "@").first.map(String.init) ?? email)
                                    .font(.subheadline.weight(.medium))
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if working.contains(email) {
                                ProgressView().controlSize(.small)
                            } else {
                                Button("Unblock") { unblock(email) }
                                    .font(.subheadline.weight(.semibold))
                                    .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Blocked")
                } footer: {
                    Text("Unblocking lets them contact you again and puts their rooms back in your search.")
                }
            }
        }
        .navigationTitle("Blocked People")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let email = user.email else { return }
            await moderation.refreshBlockList(for: email)
        }
        .refreshable {
            guard let email = user.email else { return }
            await moderation.refreshBlockList(for: email)
        }
    }

    private func unblock(_ email: String) {
        guard let me = user.email, !me.isEmpty else { return }
        working.insert(email)
        errorMessage = nil

        Task {
            do {
                try await ModerationService.shared.unblock(blocked: email, by: me)
                Haptics.notify(.success)
            } catch {
                Haptics.notify(.error)
                errorMessage = "Couldn't unblock \(email). Check your connection and try again."
            }
            working.remove(email)
        }
    }
}
