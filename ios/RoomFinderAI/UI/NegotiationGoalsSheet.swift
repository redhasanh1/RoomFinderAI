import SwiftUI

/// What the tenant wants out of the negotiation.
///
/// Everything is optional. Blank fields are dropped before the request, so the
/// AI only argues for things that were actually asked for — filling this in is
/// an improvement, not a gate.
struct NegotiationGoalsSheet: View {

    @Binding var goals: NegotiationGoals

    /// How many rooms are waiting on these goals, so the button can say what
    /// confirming will actually do.
    var queuedCount: Int = 0

    /// Called once the tenant says the goals are right. Confirming and starting
    /// are one action deliberately: checking the numbers and then hunting for a
    /// separate start button is two decisions where there is only one.
    var onConfirm: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    // Held as text because a number field bound to an optional Double either
    // shows a stray 0 or refuses to be cleared.
    @State private var maxRentText = ""
    @State private var targetRentText = ""
    @State private var leaseText = ""

    /// What the goals were on the way in, so an edit can withdraw the tenant's
    /// confirmation. Changing the budget and having the AI keep arguing to the
    /// old one is the worst failure this screen has.
    @State private var original: NegotiationGoals?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Most you'll pay") {
                        TextField("e.g. 1800", text: $maxRentText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("What you're aiming for") {
                        TextField("e.g. 1500", text: $targetRentText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Rent")
                } footer: {
                    Text("The negotiator will never agree above the lower of your maximum and the asking price.")
                }

                Section("Where") {
                    LabeledContent("City") {
                        TextField("e.g. Toronto", text: $goals.city)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Timing") {
                    LabeledContent("Move-in") {
                        TextField("e.g. 1 September", text: $goals.moveInDate)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Lease length (months)") {
                        TextField("e.g. 12", text: $leaseText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Picker("How hard to push", selection: $goals.assertiveness) {
                        ForEach(NegotiationGoals.Assertiveness.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(goals.assertiveness.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Tone", selection: $goals.tone) {
                        ForEach(NegotiationGoals.Tone.allCases) { tone in
                            Text(tone.label).tag(tone)
                        }
                    }
                } header: {
                    Text("How it negotiates")
                } footer: {
                    Text("Aggressive gets bigger discounts but loses more rooms. Firm is a good default.")
                }

                Section("Must-haves") {
                    Toggle("Parking", isOn: $goals.parkingNeeded)
                    Toggle("Furnished", isOn: $goals.furnished)
                    Toggle("Utilities included", isOn: $goals.utilitiesIncluded)
                }

                Section {
                    Toggle("Ask for a lower deposit", isOn: $goals.askLowerDeposit)
                    Toggle("Ask for the first month free", isOn: $goals.askFirstMonthFree)
                } header: {
                    Text("Worth asking for")
                } footer: {
                    Text("Used when the landlord won't move on rent. A smaller deposit is often easier for them to say yes to.")
                }

                Section {
                    LabeledContent("Work") {
                        TextField("e.g. full-time nurse", text: $goals.employment)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Who's moving in") {
                        TextField("e.g. just me", text: $goals.occupants)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Pets") {
                        TextField("e.g. one cat, or none", text: $goals.pets)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("Non-smoker", isOn: $goals.nonSmoker)
                } header: {
                    Text("Your case")
                } footer: {
                    Text("What makes you worth a discount. A landlord drops the rent for a tenant they believe will stay and pay.")
                }

                Section("Anything else") {
                    TextField("Quiet building, close to campus…", text: $goals.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .safeAreaInset(edge: .bottom) { confirmBar }
            .navigationTitle("Your negotiation goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        // Puts back what was there. Fields bind straight to the
                        // goals as they are typed, so leaving without this would
                        // keep half-finished edits.
                        if let original { goals = original }
                        dismiss()
                    }
                }
            }
            .onAppear(perform: load)
        }
    }

    /// The one action on this screen, kept where a thumb already is.
    private var confirmBar: some View {
        VStack(spacing: 6) {
            Button {
                commit()
                Haptics.impact(.medium)
                onConfirm()
                dismiss()
            } label: {
                Text(confirmTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        isUsable ? AnyShapeStyle(Theme.gradient)
                                 : AnyShapeStyle(Color.secondary.opacity(0.4)),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .disabled(!isUsable)

            Text(isUsable
                 ? "It will never agree above $\(maxRentText)/month."
                 : "Fill in the most you'll pay. That's the limit it argues to.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }

    /// A budget is the one thing the negotiator cannot work without.
    private var isUsable: Bool { !maxRentText.filter(\.isNumber).isEmpty }

    private var confirmTitle: String {
        switch queuedCount {
        case 0:  return "These are right"
        case 1:  return "These are right, start negotiating"
        default: return "These are right, message \(queuedCount) landlords"
        }
    }

    private func load() {
        maxRentText = goals.maxRent.map { String(Int($0)) } ?? ""
        targetRentText = goals.targetRent.map { String(Int($0)) } ?? ""
        leaseText = goals.leaseMonths.map(String.init) ?? ""
        original = goals
    }

    private func commit() {
        goals.maxRent = Double(maxRentText.filter(\.isNumber))
        goals.targetRent = Double(targetRentText.filter(\.isNumber))
        goals.leaseMonths = Int(leaseText.filter(\.isNumber))

        // Anything changed means these are no longer the goals that were
        // confirmed, so they have to be confirmed again before a message goes
        // out on them.
        if var before = original {
            before.confirmedAt = goals.confirmedAt
            if before != goals { goals.confirmedAt = nil }
        }
    }
}


extension View {
    /// Makes a sheet fill the page on iPad.
    ///
    /// Without it a form sheet is a small centred card — fine for a couple of
    /// controls, cramped for a screen of them, and on a tablet it reads as a
    /// dialog that opened by mistake. `presentationSizing` is iOS 18, and the
    /// app still supports 17, where the default is already closer to right.
    @ViewBuilder
    func fullPagePresentation() -> some View {
        if #available(iOS 18.0, *) {
            self.presentationSizing(.page)
        } else {
            self
        }
    }
}
