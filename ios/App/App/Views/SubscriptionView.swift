import SwiftUI

struct SubscriptionView: View {
    @State private var subscriptionStatus: SubscriptionStatus?
    @State private var availablePlans: [SubscriptionPlan] = []
    @State private var isLoading = true
    @State private var isProcessing = false
    @State private var selectedPlan: SubscriptionPlan?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else {
                    content
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadSubscriptionData()
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading subscription details...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Content
    
    private var content: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current Status
                if let status = subscriptionStatus {
                    currentStatusSection(status)
                }
                
                // Benefits Section
                benefitsSection
                
                // Available Plans
                if !availablePlans.isEmpty {
                    plansSection
                }
                
                // FAQ Section
                faqSection
            }
            .padding()
        }
    }
    
    // MARK: - Current Status Section
    
    private func currentStatusSection(_ status: SubscriptionStatus) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Plan")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: status.isPremium ? "crown.fill" : "person.fill")
                        .font(.title2)
                        .foregroundColor(status.isPremium ? .orange : .blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.type.capitalized)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(status.isActive ? "Active" : "Inactive")
                            .font(.subheadline)
                            .foregroundColor(status.isActive ? .green : .red)
                    }
                    
                    Spacer()
                    
                    if status.isPremium && status.isActive {
                        Button("Manage") {
                            manageSubscription()
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    }
                }
                
                if let expiryDate = status.expiryDate {
                    HStack {
                        Text("Expires on \(formatDate(expiryDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Benefits Section
    
    private var benefitsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Premium Benefits")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                BenefitRow(
                    icon: "brain.head.profile",
                    title: "AI Property Assistant",
                    description: "Get personalized property recommendations",
                    isPremium: true
                )
                
                BenefitRow(
                    icon: "message.fill",
                    title: "Unlimited Messages",
                    description: "Chat with unlimited property owners",
                    isPremium: true
                )
                
                BenefitRow(
                    icon: "heart.fill",
                    title: "Unlimited Favorites",
                    description: "Save as many properties as you want",
                    isPremium: true
                )
                
                BenefitRow(
                    icon: "bell.fill",
                    title: "Advanced Alerts",
                    description: "Get notified of new matching properties",
                    isPremium: true
                )
                
                BenefitRow(
                    icon: "chart.bar.fill",
                    title: "Market Insights",
                    description: "Access detailed market analysis",
                    isPremium: true
                )
                
                BenefitRow(
                    icon: "shield.fill",
                    title: "Priority Support",
                    description: "Get faster customer support",
                    isPremium: true
                )
            }
        }
    }
    
    // MARK: - Plans Section
    
    private var plansSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Choose Your Plan")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(availablePlans) { plan in
                    PlanCard(
                        plan: plan,
                        isSelected: selectedPlan?.id == plan.id,
                        isProcessing: isProcessing
                    ) {
                        if subscriptionStatus?.isPremium != true {
                            selectedPlan = plan
                            subscribeToPlan(plan)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - FAQ Section
    
    private var faqSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Frequently Asked Questions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                FAQItem(
                    question: "Can I cancel anytime?",
                    answer: "Yes, you can cancel your subscription at any time from your account settings."
                )
                
                FAQItem(
                    question: "What happens to my data if I cancel?",
                    answer: "Your data remains safe and accessible. You'll continue to have basic access to the app."
                )
                
                FAQItem(
                    question: "Do you offer refunds?",
                    answer: "We offer a 30-day money-back guarantee for all new subscriptions."
                )
            }
        }
    }
    
    // MARK: - Functions
    
    @MainActor
    private func loadSubscriptionData() async {
        isLoading = true
        
        do {
            async let statusResult = WebBridge.shared.callWebFunction("iosPaymentAPI.getSubscriptionStatus")
            async let plansResult = WebBridge.shared.callWebFunction("iosPaymentAPI.getAvailablePlans")
            
            let (status, plans) = try await (statusResult, plansResult)
            
            // Parse subscription status
            if let statusData = status as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: statusData),
               let subscription = try? JSONDecoder().decode(SubscriptionStatus.self, from: data) {
                self.subscriptionStatus = subscription
            }
            
            // Parse available plans
            if let plansData = plans as? [String: Any],
               let plansArray = plansData["data"] as? [[String: Any]] {
                self.availablePlans = plansArray.compactMap { dict in
                    guard let data = try? JSONSerialization.data(withJSONObject: dict),
                          let plan = try? JSONDecoder().decode(SubscriptionPlan.self, from: data) else {
                        return nil
                    }
                    return plan
                }
            }
            
        } catch {
            print("Error loading subscription data: \(error)")
        }
        
        isLoading = false
    }
    
    private func subscribeToPlan(_ plan: SubscriptionPlan) {
        isProcessing = true
        
        Task {
            do {
                let result = try await WebBridge.shared.callWebFunction(
                    "iosPaymentAPI.createSubscription",
                    with: ["planId": plan.id]
                )
                
                if let success = result as? [String: Any], success["success"] as? Bool == true {
                    await loadSubscriptionData()
                }
                
            } catch {
                print("Error subscribing to plan: \(error)")
            }
            
            isProcessing = false
        }
    }
    
    private func manageSubscription() {
        Task {
            do {
                _ = try await WebBridge.shared.callWebFunction("iosPaymentAPI.manageSubscription")
            } catch {
                print("Error managing subscription: \(error)")
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    let isPremium: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isPremium {
                Text("PRO")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let isProcessing: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(plan.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text("$\(Int(plan.price))")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                    
                    Text("/\(plan.interval)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let originalPrice = plan.originalPrice, originalPrice > plan.price {
                    Text("Save $\(Int(originalPrice - plan.price))")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(feature)
                            .font(.subheadline)
                        Spacer()
                    }
                }
            }
            
            Button(action: onSelect) {
                HStack {
                    if isProcessing && isSelected {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(isProcessing && isSelected ? "Processing..." : "Subscribe")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isProcessing)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(plan.isPopular ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .slide))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    SubscriptionView()
}