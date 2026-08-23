import Foundation

/// Reporting and blocking.
///
/// App Store guideline 1.2 requires both from any app carrying user-generated
/// content, and RoomFinder carries listings, roommate profiles and direct
/// messages. Reviewers check for these on marketplaces, and an app without
/// them is rejected however well it works.
@MainActor
final class ModerationService: ObservableObject {

    static let shared = ModerationService()

    /// The reasons offered when reporting. Kept short and concrete — a long
    /// list makes people give up, and vague options make reports unusable.
    enum Reason: String, CaseIterable, Identifiable {
        case scam = "Scam or fraud"
        case inaccurate = "Inaccurate or misleading"
        case offensive = "Offensive or abusive"
        case discrimination = "Discriminatory"
        case notAvailable = "Not actually available"
        case other = "Something else"

        var id: String { rawValue }
    }

    enum TargetType: String {
        case listing
        case roommateProfile = "roommate_profile"
        case message
        case sublease
        case user
    }

    private init() {}

    @Published private(set) var blockedEmails: Set<String> = []

    func report(targetType: TargetType,
                targetId: String,
                reason: Reason,
                details: String?,
                reporterEmail: String?) async throws {
        var request = URLRequest(url: AppConfig.url("api/report"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "targetType": targetType.rawValue,
            "targetId": targetId,
            "reason": reason.rawValue,
            "details": details ?? "",
            "reporterEmail": reporterEmail ?? ""
        ])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func block(blocked: String, by blocker: String) async throws {
        var request = URLRequest(url: AppConfig.url("api/block"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "blockerEmail": blocker,
            "blockedEmail": blocked
        ])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        blockedEmails.insert(blocked.lowercased())
    }

    /// Block the owner of a roommate profile.
    ///
    /// The browse payload carries no email, so the profile is named and the
    /// server resolves who owns it. Sending every user's address to every
    /// client so the client could block one of them would leak more than it
    /// protects.
    func blockRoommateProfile(id: String, by blocker: String) async throws {
        var request = URLRequest(url: AppConfig.url("api/block"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "blockerEmail": blocker,
            "blockedProfileId": id
        ])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        // The address is never sent back, so the local set cannot be updated
        // here; the caller reloads, and the server has already dropped them.
        await refreshBlockList(for: blocker)
    }

    /// Undo a block.
    ///
    /// Blocking used to be a one-way door: the only way to do it was to file a
    /// report, and there was no way back. Someone who blocked the wrong person,
    /// or made up with a roommate, was stuck with it for good — which is not a
    /// moderation tool, it is a mistake you cannot take back.
    func unblock(blocked: String, by blocker: String) async throws {
        var request = URLRequest(url: AppConfig.url("api/unblock"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "blockerEmail": blocker,
            "blockedEmail": blocked
        ])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        blockedEmails.remove(blocked.lowercased())
    }

    /// Stable order for the list in Profile, so unblocking one person does not
    /// reshuffle the rest under the reader's finger.
    var blockedList: [String] { blockedEmails.sorted() }

    /// Whether this address is blocked, for filtering what gets shown.
    func isBlocked(_ email: String?) -> Bool {
        guard let email = email?.lowercased(), !email.isEmpty else { return false }
        return blockedEmails.contains(email)
    }

    /// Loads the block list so blocked people's rooms can be filtered out
    /// before they are ever shown.
    func refreshBlockList(for email: String) async {
        var components = URLComponents(url: AppConfig.url("api/blocked"), resolvingAgainstBaseURL: false)!
        components.queryItems = [.init(name: "userEmail", value: email)]

        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["blocked"] as? [String] else { return }

        blockedEmails = Set(list.map { $0.lowercased() })
    }
}
