import SwiftUI

/// The sublease filters.
///
/// Offering versus Looking was the only question this screen could ask, which
/// is not a filter so much as a table of contents. Everything that decides
/// whether a sublease is worth opening — what it costs, how big it is, whether
/// it's furnished, whether it's free before you need it — lives here.
struct SubleaseFilterSheet: View {

    @Binding var filters: SubleaseScreen.Filters
    /// Everything loaded, so the button can say what you are about to get.
    let requests: [SubleaseRequest]

    @Environment(\.dismiss) private var dismiss

    @State private var draft = SubleaseScreen.Filters()
    @State private var limitsDate = false
    @State private var availableBy = Date()

    private static let stops = [500, 700, 900, 1100, 1300, 1500, 1800, 2200, 2600, 3000, 4000]
    private static let types = ["Apartment", "House", "Condo", "Studio", "Room", "Townhouse"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Least", selection: $draft.minPrice) {
                        Text("No minimum").tag(Int?.none)
                        ForEach(Self.stops, id: \.self) { Text("$\($0)").tag(Int?($0)) }
                    }
                    Picker("Most", selection: $draft.maxPrice) {
                        Text("No maximum").tag(Int?.none)
                        ForEach(Self.stops, id: \.self) { Text("$\($0)").tag(Int?($0)) }
                    }
                } header: {
                    Text("Monthly price")
                } footer: {
                    Text("Matched against the rent when someone is handing a place over, and against their budget when they're looking for one.")
                }

                Section("The place") {
                    Picker("Bedrooms", selection: $draft.bedrooms) {
                        Text("Any").tag(Int?.none)
                        ForEach(1...4, id: \.self) { Text("\($0)+").tag(Int?($0)) }
                    }
                    .pickerStyle(.segmented)

                    Picker("Type", selection: $draft.propertyType) {
                        Text("Any").tag(String?.none)
                        ForEach(Self.types, id: \.self) { Text($0).tag(String?($0)) }
                    }
                }

                Section {
                    Toggle("Free on or before", isOn: $limitsDate.animation())
                    if limitsDate {
                        DatePicker("Date", selection: $availableBy, displayedComponents: .date)
                    }
                } header: {
                    Text("Timing")
                } footer: {
                    if limitsDate {
                        Text("Hides anything that hasn't said when it starts.")
                    }
                }

                Section("Only show") {
                    Toggle(isOn: $draft.furnished) {
                        Label("Furnished", systemImage: "sofa")
                    }
                    Toggle(isOn: $draft.utilitiesIncluded) {
                        Label("Utilities included", systemImage: "bolt")
                    }
                    Toggle(isOn: $draft.petFriendly) {
                        Label("Pets allowed", systemImage: "pawprint")
                    }
                    Toggle(isOn: $draft.urgentOnly) {
                        Label("Urgent only", systemImage: "exclamationmark.circle")
                    }
                }

                Section("Order") {
                    Picker("Sort", selection: $draft.sort) {
                        ForEach(SubleaseScreen.Filters.Sort.allCases) { option in
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
                        draft = SubleaseScreen.Filters()
                        limitsDate = false
                    }
                    .disabled(!draft.isActive && !limitsDate)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { applyBar }
        }
        .onAppear {
            draft = filters
            limitsDate = filters.availableBy != nil
            availableBy = filters.availableBy ?? Date()
        }
    }

    private var normalised: SubleaseScreen.Filters {
        var value = draft
        value.availableBy = limitsDate ? availableBy : nil
        if let low = value.minPrice, let high = value.maxPrice, low > high {
            value.minPrice = high
            value.maxPrice = low
        }
        return value
    }

    private var matchCount: Int {
        let applied = normalised
        return requests.filter { applied.matches($0) }.count
    }

    private var applyBar: some View {
        Button {
            Haptics.impact(.medium)
            filters = normalised
            dismiss()
        } label: {
            Text(matchCount == 0
                 ? "Nothing matches"
                 : matchCount == 1 ? "Show 1 sublease" : "Show \(matchCount) subleases")
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
