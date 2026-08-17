import SwiftUI

/// The report form.
///
/// Presented from anything a person can post. Deliberately two taps from the
/// content itself — a reporting flow buried three menus deep satisfies the
/// letter of guideline 1.2 and none of its purpose.
struct ReportSheet: View {

    let targetType: ModerationService.TargetType
    let targetId: String
    /// Nil when the content has no identifiable author, which is why blocking
    /// is offered conditionally rather than always.
    let authorEmail: String?

    @Environment(\.dismiss) private var dismiss

    @State private var reason: ModerationService.Reason = .scam
    @State private var details = ""
    @State private var alsoBlock = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            Group {
                if didSubmit {
                    confirmation
                } else {
                    form
                }
            }
            .navigationTitle(didSubmit ? "Report Sent" : "Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(didSubmit ? "Done" : "Cancel") { dismiss() }
                }
                if !didSubmit {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Submit") { submit() }
                            .disabled(isSubmitting)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var form: some View {
        Form {
            Section("What's wrong?") {
                Picker("Reason", selection: $reason) {
                    ForEach(ModerationService.Reason.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("Anything else? (optional)") {
                TextField("Add details", text: $details, axis: .vertical)
                    .lineLimit(3...6)
            }

            if authorEmail != nil {
                Section {
                    Toggle("Also block this person", isOn: $alsoBlock)
                } footer: {
                    Text("You won't see their rooms or messages again.")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Text("Reports are reviewed within 24 hours. If you're in danger, contact your local emergency services.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var confirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            Text("Thanks for telling us")
                .font(.title3.weight(.semibold))
            Text(alsoBlock
                 ? "Our team reviews reports within 24 hours. You won't see this person again."
                 : "Our team reviews reports within 24 hours.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func submit() {
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let reporter = CurrentUser.shared.email
                try await ModerationService.shared.report(
                    targetType: targetType,
                    targetId: targetId,
                    reason: reason,
                    details: details.isEmpty ? nil : details,
                    reporterEmail: reporter
                )

                // Blocking needs to know who is doing the blocking, so it is
                // only attempted when we actually have a signed-in address.
                if alsoBlock, let authorEmail, let reporter, !reporter.isEmpty {
                    try? await ModerationService.shared.block(blocked: authorEmail, by: reporter)
                }

                Haptics.notify(.success)
                didSubmit = true
            } catch {
                Haptics.notify(.error)
                errorMessage = "Couldn't send your report. Please check your connection and try again."
            }
            isSubmitting = false
        }
    }
}
