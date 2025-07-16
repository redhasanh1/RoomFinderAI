import SwiftUI

struct NegotiationView: View {
    let property: Property
    @State private var negotiationHistory: [NegotiationOffer] = []
    @State private var currentOffer: Double = 0
    @State private var negotiationMessage = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var showingOfferSheet = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Property Header
            propertyHeader
            
            // Negotiation Status
            negotiationStatusSection
            
            // Negotiation History
            negotiationHistorySection
            
            // Action Buttons
            actionButtonsSection
        }
        .navigationTitle("Negotiation")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadNegotiationHistory()
        }
        .sheet(isPresented: $showingOfferSheet) {
            MakeOfferSheet(
                property: property,
                currentOffer: $currentOffer,
                message: $negotiationMessage
            ) {
                await sendOffer()
            }
        }
    }
    
    // MARK: - Property Header
    
    private var propertyHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: property.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "house")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(property.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Text(property.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(property.formattedPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            
            Divider()
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Negotiation Status
    
    private var negotiationStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Negotiation Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Last Offer")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let lastOffer = negotiationHistory.last(where: { $0.isFromUser }) {
                        Text("$\(Int(lastOffer.amount))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    } else {
                        Text("No offer yet")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Status")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let lastOffer = negotiationHistory.last {
                        StatusBadge(status: lastOffer.status)
                    } else {
                        Text("Not started")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Negotiation History
    
    private var negotiationHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Negotiation History")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if negotiationHistory.isEmpty {
                emptyHistoryView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(negotiationHistory) { offer in
                            NegotiationOfferCard(offer: offer)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "handshake")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No negotiations yet")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Start negotiating by making your first offer")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Make Counter Offer
                Button(action: {
                    currentOffer = property.price * 0.9
                    showingOfferSheet = true
                }) {
                    HStack {
                        Image(systemName: "dollarsign.circle")
                        Text("Make Offer")
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSending)
                
                // Accept Last Offer (if applicable)
                if let lastOwnerOffer = negotiationHistory.last(where: { !$0.isFromUser && $0.status == .pending }) {
                    Button(action: {
                        acceptOffer(lastOwnerOffer)
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Accept")
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isSending)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Functions
    
    @MainActor
    private func loadNegotiationHistory() async {
        isLoading = true
        
        do {
            let result = try await WebBridge.shared.callWebFunction(
                "iosNegotiationAPI.getNegotiationHistory",
                with: ["propertyId": property.id]
            )
            
            if let historyResult = result as? [String: Any],
               let historyArray = historyResult["data"] as? [[String: Any]] {
                self.negotiationHistory = parseOffers(from: historyArray)
            }
            
        } catch {
            print("Error loading negotiation history: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    private func sendOffer() async {
        guard currentOffer > 0 else { return }
        
        isSending = true
        
        do {
            let result = try await WebBridge.shared.callWebFunction(
                "iosNegotiationAPI.makeOffer",
                with: [
                    "propertyId": property.id,
                    "amount": currentOffer,
                    "message": negotiationMessage
                ]
            )
            
            if let success = result as? [String: Any], success["success"] as? Bool == true {
                await loadNegotiationHistory()
                showingOfferSheet = false
                negotiationMessage = ""
            }
            
        } catch {
            print("Error sending offer: \(error)")
        }
        
        isSending = false
    }
    
    private func acceptOffer(_ offer: NegotiationOffer) {
        isSending = true
        
        Task {
            do {
                let result = try await WebBridge.shared.callWebFunction(
                    "iosNegotiationAPI.acceptOffer",
                    with: ["offerId": offer.id]
                )
                
                if let success = result as? [String: Any], success["success"] as? Bool == true {
                    await loadNegotiationHistory()
                }
                
            } catch {
                print("Error accepting offer: \(error)")
            }
            
            isSending = false
        }
    }
    
    private func parseOffers(from array: [[String: Any]]) -> [NegotiationOffer] {
        return array.compactMap { dict in
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let offer = try? JSONDecoder().decode(NegotiationOffer.self, from: data) else {
                return nil
            }
            return offer
        }.sorted { $0.createdAt < $1.createdAt }
    }
}

// MARK: - Supporting Views

struct StatusBadge: View {
    let status: OfferStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(status.textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.backgroundColor)
            .clipShape(Capsule())
    }
}

struct NegotiationOfferCard: View {
    let offer: NegotiationOffer
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(offer.isFromUser ? Color.blue : Color.green)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: offer.isFromUser ? "person.fill" : "house.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(offer.isFromUser ? "Your Offer" : "Owner's Offer")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    StatusBadge(status: offer.status)
                }
                
                // Amount
                Text("$\(Int(offer.amount))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(offer.isFromUser ? .blue : .green)
                
                // Message
                if !offer.message.isEmpty {
                    Text(offer.message)
                        .font(.body)
                        .lineSpacing(4)
                }
                
                // Timestamp
                Text(formatTime(offer.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func formatTime(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        guard let date = formatter.date(from: dateString) else {
            return ""
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .short
        timeFormatter.timeStyle = .short
        return timeFormatter.string(from: date)
    }
}

struct MakeOfferSheet: View {
    let property: Property
    @Binding var currentOffer: Double
    @Binding var message: String
    let onSend: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isSending = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Property Info
                VStack(spacing: 12) {
                    Text("Make an offer for")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(property.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("Listed at \(property.formattedPrice)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                // Offer Amount
                VStack(spacing: 16) {
                    Text("Your Offer")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("Enter amount", value: $currentOffer, format: .currency(code: "USD"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                    
                    // Quick preset buttons
                    HStack(spacing: 12) {
                        ForEach([0.85, 0.9, 0.95], id: \.self) { multiplier in
                            Button("\(Int(multiplier * 100))%") {
                                currentOffer = property.price * multiplier
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                        }
                    }
                }
                
                // Message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message (Optional)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("Add a personal message...", text: $message, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                Spacer()
                
                // Send Button
                Button(action: {
                    Task {
                        isSending = true
                        await onSend()
                        isSending = false
                        dismiss()
                    }
                }) {
                    HStack {
                        if isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(isSending ? "Sending..." : "Send Offer")
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(currentOffer > 0 ? Color.blue : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(currentOffer <= 0 || isSending)
            }
            .padding()
            .navigationTitle("Make Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension OfferStatus {
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        case .countered: return "Countered"
        }
    }
    
    var textColor: Color {
        switch self {
        case .pending: return .white
        case .accepted: return .white
        case .rejected: return .white
        case .countered: return .white
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .pending: return .orange
        case .accepted: return .green
        case .rejected: return .red
        case .countered: return .blue
        }
    }
}

#Preview {
    NegotiationView(property: Property(
        id: "1",
        title: "Beautiful 2BR Apartment",
        description: "A stunning apartment",
        price: 2500,
        location: "Downtown",
        category: "apartment",
        bedrooms: 2,
        bathrooms: 2,
        imageUrl: nil,
        featured: false,
        createdAt: nil,
        userEmail: "owner@example.com"
    ))
}