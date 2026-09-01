import Foundation
import SwiftUI

/// What leaves the phone when an AI feature is used, said plainly before it
/// happens.
///
/// The negotiator and the listing autofill both send what someone typed or
/// photographed to companies outside RoomFinder. That is not obvious from the
/// buttons that start them, and App Review asked directly what personal data
/// goes to third-party AI. Someone should be told before it is sent, not
/// discover it in a policy afterwards.
///
/// Asked once and remembered. Declining leaves the feature unused rather than
/// sending anything, so it is a real choice: everything else in the app —
/// browsing, messaging landlords, posting a room by hand — keeps working.
@MainActor
final class AIDisclosure: ObservableObject {

    static let shared = AIDisclosure()

    private static let key = "aiDisclosureAcceptedVersion"
    /// Bumped when what is shared, or who it goes to, changes — which asks
    /// everyone again rather than relying on consent given for something else.
    private static let currentVersion = 1

    @Published private(set) var hasAgreed: Bool

    private init() {
        hasAgreed = UserDefaults.standard.integer(forKey: Self.key) >= Self.currentVersion
    }

    func agree() {
        UserDefaults.standard.set(Self.currentVersion, forKey: Self.key)
        hasAgreed = true
    }

    /// Test hook, and the reset used by -uiTestingResetState.
    func forget() {
        UserDefaults.standard.removeObject(forKey: Self.key)
        hasAgreed = false
    }
}

/// The disclosure itself.
///
/// Deliberately specific. "We use AI to improve your experience" tells nobody
/// anything; what a person needs to know is which of their words and pictures
/// go where, and what happens to them afterwards.
struct AIDisclosureSheet: View {

    /// Runs only when the person agrees, so the caller can carry straight on
    /// with whatever they were trying to do.
    var onAgree: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var disclosure = AIDisclosure.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    section(
                        title: "What gets sent",
                        rows: [
                            ("text.bubble", "What you type to the negotiator"),
                            ("house", "Details of the room being discussed — its title, price, location, bedrooms and type"),
                            ("dollarsign.circle", "The budget or price you tell it to aim for"),
                            ("envelope", "Your email address, so the conversation stays attached to your account"),
                            ("photo", "Photos you add to a listing, when you ask the app to fill the details in for you")
                        ]
                    )

                    section(
                        title: "Who it goes to",
                        rows: [
                            ("cpu", "OpenAI — writes the negotiator's messages, and checks that a photo you upload really shows a room"),
                            ("cloud", "Cloudflare — reads a room photo to fill in the listing")
                        ]
                    )

                    section(
                        title: "What they do with it",
                        rows: [
                            ("checkmark.shield", "Used only to provide these features"),
                            ("xmark.shield", "Not used for advertising or tracking"),
                            ("brain", "Not used to train their models")
                        ]
                    )

                    Text("You can use the rest of RoomFinderAI without this. Browsing rooms, messaging landlords yourself and posting a room by hand all work whether you agree or not.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Link("Read our privacy policy",
                         destination: AppConfig.url("privacy-policy.html"))
                        .font(.footnote.weight(.semibold))
                }
                .padding(20)
            }
            .navigationTitle("Before you use AI")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        Haptics.notify(.success)
                        disclosure.agree()
                        dismiss()
                        onAgree()
                    } label: {
                        Text("Agree and continue")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.gradient))
                    }

                    Button("Not now") { dismiss() }
                        .font(.subheadline)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .background(.regularMaterial)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(Theme.brand)
            Text("This feature uses AI services run by other companies. Here is exactly what they receive.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func section(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(rows, id: \.1) { symbol, text in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: symbol)
                        .font(.footnote)
                        .foregroundStyle(Theme.brand)
                        .frame(width: 20)
                    Text(text)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

extension View {
    /// Shows the disclosure before an AI feature runs, and runs it only once
    /// the person has agreed.
    func aiDisclosure(isPresented: Binding<Bool>, onAgree: @escaping () -> Void) -> some View {
        sheet(isPresented: isPresented) {
            AIDisclosureSheet(onAgree: onAgree)
        }
    }
}
