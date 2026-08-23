import SwiftUI

/// Blocking someone, on its own.
///
/// It used to exist only as a toggle inside the report form, so the only way
/// to stop hearing from somebody was to first accuse them of something. Plenty
/// of people want out of a conversation without filing a complaint, and making
/// them file one either produces a false report or, more often, nothing at all.
///
/// Attached with `.blockAction(_:isPresented:)` so the confirmation and the
/// call read the same way everywhere they appear.
struct BlockActionModifier: ViewModifier {

    /// Who is being blocked. A roommate profile carries no email — the browse
    /// payload deliberately omits one — so it is named by its id and the owner
    /// is resolved on the server.
    enum Target {
        case person(email: String?)
        case roommateProfile(id: String, name: String)

        var name: String? {
            switch self {
            case .person(let email):
                guard let email = email?.nilIfEmpty else { return nil }
                return email.split(separator: "@").first.map(String.init) ?? email
            case .roommateProfile(_, let name):
                return name
            }
        }

        var isBlockable: Bool {
            switch self {
            case .person(let email):          return email?.nilIfEmpty != nil
            case .roommateProfile(let id, _): return !id.isEmpty
            }
        }
    }

    let target: Target
    @Binding var isPresented: Bool
    /// Called after a successful block, for screens that need to pop back or
    /// drop the row they were showing.
    var onBlocked: (() -> Void)?

    @State private var failed = false

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                target.name.map { "Block \($0)?" } ?? "Block this person?",
                isPresented: $isPresented,
                titleVisibility: .visible
            ) {
                Button("Block", role: .destructive) { block() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("They won't be able to message you, and you won't see their rooms or roommate profile. You can undo this in Profile, under Blocked People.")
            }
            .alert("Couldn't block", isPresented: $failed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Check your connection and try again.")
            }
    }

    private func block() {
        guard target.isBlockable,
              let me = CurrentUser.shared.email, !me.isEmpty else { return }

        Task {
            do {
                switch target {
                case .person(let email):
                    guard let email = email?.nilIfEmpty else { return }
                    try await ModerationService.shared.block(blocked: email, by: me)
                case .roommateProfile(let id, _):
                    try await ModerationService.shared.blockRoommateProfile(id: id, by: me)
                }
                Haptics.notify(.success)
                onBlocked?()
            } catch {
                Haptics.notify(.error)
                failed = true
            }
        }
    }
}

extension View {
    /// Confirm-then-block, wherever a person is named.
    func blockAction(_ target: BlockActionModifier.Target,
                     isPresented: Binding<Bool>,
                     onBlocked: (() -> Void)? = nil) -> some View {
        modifier(BlockActionModifier(target: target, isPresented: isPresented, onBlocked: onBlocked))
    }
}
