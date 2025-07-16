import SwiftUI

struct FilterView: View {
    @Binding var filters: SearchFilters
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempFilters: SearchFilters
    
    init(filters: Binding<SearchFilters>, onApply: @escaping () -> Void) {
        self._filters = filters
        self.onApply = onApply
        self._tempFilters = State(initialValue: filters.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Property Type
                Section("Property Type") {
                    Picker("Category", selection: $tempFilters.category) {
                        Text("Any").tag(nil as String?)
                        Text("Apartment").tag("apartment" as String?)
                        Text("House").tag("house" as String?)
                        Text("Condo").tag("condo" as String?)
                        Text("Studio").tag("studio" as String?)
                    }
                    .pickerStyle(.menu)
                }
                
                // Price Range
                Section("Price Range") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Min Price")
                            Spacer()
                            TextField("No minimum", value: $tempFilters.minPrice, format: .currency(code: "USD"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }
                        
                        HStack {
                            Text("Max Price")
                            Spacer()
                            TextField("No maximum", value: $tempFilters.maxPrice, format: .currency(code: "USD"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }
                        
                        if let min = tempFilters.minPrice, let max = tempFilters.maxPrice {
                            Text("$\(Int(min)) - $\(Int(max))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Bedrooms
                Section("Bedrooms") {
                    Picker("Bedrooms", selection: $tempFilters.bedrooms) {
                        Text("Any").tag(nil as Int?)
                        ForEach(0...5, id: \.self) { count in
                            if count == 0 {
                                Text("Studio").tag(count as Int?)
                            } else {
                                Text("\(count)+ bedroom\(count > 1 ? "s" : "")").tag(count as Int?)
                            }
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }
                
                // Bathrooms
                Section("Bathrooms") {
                    Picker("Bathrooms", selection: $tempFilters.bathrooms) {
                        Text("Any").tag(nil as Int?)
                        ForEach(1...4, id: \.self) { count in
                            Text("\(count)+ bathroom\(count > 1 ? "s" : "")").tag(count as Int?)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }
                
                // Location
                Section("Location") {
                    TextField("Enter location...", text: Binding(
                        get: { tempFilters.location ?? "" },
                        set: { tempFilters.location = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                
                // Reset Section
                Section {
                    Button("Reset All Filters") {
                        tempFilters = SearchFilters()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        filters = tempFilters
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    FilterView(filters: .constant(SearchFilters())) { }
}