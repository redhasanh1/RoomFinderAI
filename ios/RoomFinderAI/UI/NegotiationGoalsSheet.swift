import SwiftUI

/// What the tenant wants out of the negotiation.
///
/// Everything is optional. Blank fields are dropped before the request, so the
/// AI only argues for things that were actually asked for — filling this in is
/// an improvement, not a gate.
struct NegotiationGoalsSheet: View {

    @Binding var goals: NegotiationGoals
    @Environment(\.dismiss) private var dismiss

    // Held as text because a number field bound to an optional Double either
    // shows a stray 0 or refuses to be cleared.
    @State private var maxRentText = ""
    @State private var targetRentText = ""
    @State private var leaseText = ""

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

                Section("Must-haves") {
                    Toggle("Pet friendly", isOn: $goals.petFriendly)
                    Toggle("Parking", isOn: $goals.parkingNeeded)
                    Toggle("Furnished", isOn: $goals.furnished)
                    Toggle("Utilities included", isOn: $goals.utilitiesIncluded)
                }

                Section("Anything else") {
                    TextField("Quiet building, close to campus…", text: $goals.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Your Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        commit()
                        Haptics.impact(.light)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        maxRentText = goals.maxRent.map { String(Int($0)) } ?? ""
        targetRentText = goals.targetRent.map { String(Int($0)) } ?? ""
        leaseText = goals.leaseMonths.map(String.init) ?? ""
    }

    private func commit() {
        goals.maxRent = Double(maxRentText.filter(\.isNumber))
        goals.targetRent = Double(targetRentText.filter(\.isNumber))
        goals.leaseMonths = Int(leaseText.filter(\.isNumber))
    }
}
