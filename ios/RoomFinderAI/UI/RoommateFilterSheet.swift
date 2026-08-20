import SwiftUI

/// The roommate filters.
///
/// The old control was a single row of budget chips. Everything else that
/// decides whether a stranger is worth messaging — when they can move, whether
/// there is a face and a few words attached, what order to read them in — had
/// nowhere to go.
struct RoommateFilterSheet: View {

    @Binding var filters: RoomPalScreen.Filters
    /// Everyone loaded, so the button can say what you are about to get.
    let people: [RoommateProfile]

    @Environment(\.dismiss) private var dismiss

    @State private var draft = RoomPalScreen.Filters()
    /// A date picker needs a date whether or not the filter is on, so the
    /// toggle carries the "is this set at all" and the picker only the value.
    @State private var limitsMoveIn = false
    @State private var moveInBy = Date()

    private static let stops = [400, 600, 800, 1000, 1200, 1500, 1800, 2200, 2600, 3000]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Least", selection: $draft.minBudget) {
                        Text("No minimum").tag(Int?.none)
                        ForEach(Self.stops, id: \.self) { Text("$\($0)").tag(Int?($0)) }
                    }
                    Picker("Most", selection: $draft.maxBudget) {
                        Text("No maximum").tag(Int?.none)
                        ForEach(Self.stops, id: \.self) { Text("$\($0)").tag(Int?($0)) }
                    }
                } header: {
                    Text("Budget")
                } footer: {
                    Text("Matched against the rent when someone has a room, and against what they can pay when they're looking.")
                }

                Section {
                    Toggle("Only people who can move by", isOn: $limitsMoveIn.animation())
                    if limitsMoveIn {
                        DatePicker("Date", selection: $moveInBy, displayedComponents: .date)
                    }
                } header: {
                    Text("Timing")
                } footer: {
                    if limitsMoveIn {
                        Text("Hides anyone who hasn't said when they can move.")
                    }
                }

                Section {
                    Toggle(isOn: $draft.withPhoto) {
                        Label("Has a photo", systemImage: "person.crop.circle")
                    }
                    Toggle(isOn: $draft.withBio) {
                        Label("Wrote something about themselves", systemImage: "text.alignleft")
                    }
                } header: {
                    Text("Only show")
                } footer: {
                    Text("A blank profile is usually somebody who signed up and left.")
                }

                Section("Order") {
                    Picker("Sort", selection: $draft.sort) {
                        ForEach(RoomPalScreen.Filters.Sort.allCases) { option in
                            Label(option.rawValue, systemImage: option.symbol).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        Haptics.impact(.light)
                        draft = RoomPalScreen.Filters()
                        limitsMoveIn = false
                    }
                    .disabled(!draft.isActive && !limitsMoveIn)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { applyBar }
        }
        .onAppear {
            draft = filters
            limitsMoveIn = filters.moveInBy != nil
            moveInBy = filters.moveInBy ?? Date()
        }
    }

    private var normalised: RoomPalScreen.Filters {
        var value = draft
        value.moveInBy = limitsMoveIn ? moveInBy : nil
        if let low = value.minBudget, let high = value.maxBudget, low > high {
            value.minBudget = high
            value.maxBudget = low
        }
        return value
    }

    private var matchCount: Int {
        let applied = normalised
        return people.filter { applied.matches($0) }.count
    }

    private var applyBar: some View {
        Button {
            Haptics.impact(.medium)
            filters = normalised
            dismiss()
        } label: {
            Text(matchCount == 0
                 ? "Nobody matches"
                 : matchCount == 1 ? "Show 1 person" : "Show \(matchCount) people")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    Capsule().fill(matchCount == 0
                                   ? AnyShapeStyle(Color(.tertiarySystemFill))
                                   : AnyShapeStyle(Theme.gradient))
                )
                .foregroundStyle(matchCount == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.bar)
    }
}
