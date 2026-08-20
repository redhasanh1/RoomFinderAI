import SwiftUI

/// The browse filters, as a full sheet.
///
/// This used to be a menu holding two things: a max rent and a bedroom count.
/// Everything else people actually sort rooms by — a floor as well as a
/// ceiling on rent, bathrooms, whether the host is verified, whether there are
/// any photos at all, and what order the list comes back in — had nowhere to
/// live. A sheet shows all of it at once, and the button at the bottom says how
/// many rooms you are about to get, so nobody applies a filter to find out it
/// left them with nothing.
struct FilterSheet: View {

    @Binding var filters: ListingsScreen.Filters
    @Binding var category: ListingsScreen.Category
    /// Everything loaded, unfiltered, purely so the button can count.
    let rooms: [Listing]

    @Environment(\.dismiss) private var dismiss

    /// Edited in place, applied on the way out. Changing the real filters as
    /// each control moves would rebuild the list underneath the sheet and
    /// fire a reload per tap.
    @State private var draft = ListingsScreen.Filters()
    @State private var draftCategory: ListingsScreen.Category = .all

    /// Round numbers people actually think in, not a slider that lands on
    /// $1,347.
    private static let priceStops = [500, 700, 900, 1100, 1300, 1500, 1800, 2200, 2600, 3000, 4000]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Least", selection: $draft.minPrice) {
                        Text("No minimum").tag(Double?.none)
                        ForEach(Self.priceStops, id: \.self) { stop in
                            Text("$\(stop)").tag(Double?(Double(stop)))
                        }
                    }
                    Picker("Most", selection: $draft.maxPrice) {
                        Text("No maximum").tag(Double?.none)
                        ForEach(Self.priceStops, id: \.self) { stop in
                            Text("$\(stop)").tag(Double?(Double(stop)))
                        }
                    }
                } header: {
                    Text("Monthly rent")
                } footer: {
                    if let low = draft.minPrice, let high = draft.maxPrice, low > high {
                        Text("That range is backwards. We'll flip it for you.")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Size") {
                    Picker("Bedrooms", selection: $draft.bedrooms) {
                        Text("Any").tag(Int?.none)
                        ForEach(1...5, id: \.self) { count in
                            Text("\(count)+").tag(Int?(count))
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Bathrooms", selection: $draft.bathrooms) {
                        Text("Any").tag(Int?.none)
                        ForEach(1...3, id: \.self) { count in
                            Text("\(count)+").tag(Int?(count))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Property type") {
                    Picker("Type", selection: $draftCategory) {
                        ForEach(ListingsScreen.Category.allCases) { option in
                            Label(option.rawValue, systemImage: option.symbol)
                                .tag(option)
                        }
                    }
                }

                Section {
                    Toggle(isOn: $draft.verifiedOnly) {
                        Label("Verified hosts only", systemImage: "checkmark.seal")
                    }
                    Toggle(isOn: $draft.withPhotos) {
                        Label("Has photos", systemImage: "photo")
                    }
                } header: {
                    Text("Only show")
                } footer: {
                    Text("Verified means we've checked the host's ID.")
                }

                Section("Order") {
                    Picker("Sort", selection: $draft.sort) {
                        ForEach(ListingsScreen.Filters.Sort.allCases) { option in
                            Label(option.rawValue, systemImage: option.symbol)
                                .tag(option)
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
                        draft = ListingsScreen.Filters()
                        draftCategory = .all
                    }
                    .disabled(!draft.isActive && draftCategory == .all)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { applyBar }
        }
        .onAppear {
            draft = filters
            draftCategory = category
        }
    }

    /// Rooms this draft would leave on screen. Counted from what is loaded, so
    /// the number on the button is the number you get.
    private var matchCount: Int {
        let applied = normalised
        return rooms.filter { draftCategory.matches($0) && applied.matches($0) }.count
    }

    /// A range entered backwards is a slip, not a request for nothing.
    private var normalised: ListingsScreen.Filters {
        var value = draft
        if let low = value.minPrice, let high = value.maxPrice, low > high {
            value.minPrice = high
            value.maxPrice = low
        }
        return value
    }

    private var applyBar: some View {
        Button {
            Haptics.impact(.medium)
            filters = normalised
            category = draftCategory
            dismiss()
        } label: {
            Text(matchCount == 0
                 ? "No rooms match"
                 : matchCount == 1 ? "Show 1 room" : "Show \(matchCount) rooms")
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
        // Applying a filter that matches nothing is a legitimate thing to do:
        // it tells you the answer. It just should not look inviting.
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.bar)
    }
}
