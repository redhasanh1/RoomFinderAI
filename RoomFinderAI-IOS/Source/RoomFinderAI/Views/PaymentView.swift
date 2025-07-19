import SwiftUI

struct PaymentView: View {
    @StateObject private var stripeService = StripeService.shared
    @State private var selectedPlan: SubscriptionPlan?
    @State private var isProcessingPayment = false
    @State private var paymentResult: PaymentResult?
    @State private var showingError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    let plans = StripeService.shared.getSubscriptionPlans()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Choose Your Plan")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Unlock powerful features to find your perfect home")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Plans
                    VStack(spacing: 16) {
                        ForEach(plans, id: \.id) { plan in
                            PlanCard(
                                plan: plan,
                                isSelected: selectedPlan?.id == plan.id,
                                onSelect: {
                                    selectedPlan = plan
                                }
                            )
                        }
                    }
                    
                    // Payment Button
                    if let selectedPlan = selectedPlan {
                        Button(action: {
                            processPayment(for: selectedPlan)
                        }) {
                            HStack {
                                if isProcessingPayment {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Text("Subscribe to \(selectedPlan.name) - $\(selectedPlan.price, specifier: "%.2f")/month")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.primaryBlue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessingPayment)
                    }
                    
                    // Features Comparison
                    FeatureComparisonView()
                    
                    // Terms
                    VStack(spacing: 8) {
                        Text("By subscribing, you agree to our Terms of Service and Privacy Policy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Cancel anytime. No hidden fees.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Payment Result", isPresented: Binding<Bool>(
                get: { paymentResult != nil },
                set: { _ in paymentResult = nil }
            )) {
                Button("OK") {
                    if paymentResult?.success == true {
                        dismiss()
                    }
                }
            } message: {
                Text(paymentResult?.message ?? "")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func processPayment(for plan: SubscriptionPlan) {
        isProcessingPayment = true
        
        Task {
            do {
                let result = try await stripeService.simulatePayment(
                    amount: plan.price,
                    planId: plan.id
                )
                
                await MainActor.run {
                    paymentResult = result
                    isProcessingPayment = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isProcessingPayment = false
                }
            }
        }
    }
}

struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(plan.name)
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            if plan.isPopular {
                                Text("POPULAR")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.primaryBlue)
                                    .cornerRadius(8)
                            }
                        }
                        
                        HStack(alignment: .bottom) {
                            Text("$\(plan.price, specifier: "%.2f")")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primaryBlue)
                            
                            Text("/month")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .primaryBlue : .secondary)
                }
                
                // Features
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(plan.features, id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text(feature)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primaryBlue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FeatureComparisonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Feature Comparison")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Feature")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Basic")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 50)
                    
                    Text("Premium")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 50)
                    
                    Text("Pro")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 50)
                }
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                
                // Features
                let features = [
                    ("Basic Search", [true, true, true]),
                    ("AI Negotiator", [false, true, true]),
                    ("Market Analytics", [false, true, true]),
                    ("Mortgage Calculator", [false, false, true]),
                    ("Priority Support", [false, true, true]),
                    ("Investment Analysis", [false, false, true])
                ]
                
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack {
                        Text(feature.0)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ForEach(Array(feature.1.enumerated()), id: \.offset) { _, available in
                            Image(systemName: available ? "checkmark" : "xmark")
                                .foregroundColor(available ? .green : .red)
                                .font(.caption)
                                .frame(width: 50)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(index % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.5))
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct SubscriptionStatusView: View {
    @StateObject private var stripeService = StripeService.shared
    @State private var currentSubscription: UserSubscription?
    @State private var isLoading = true
    @State private var showingCancelConfirmation = false
    
    let userEmail: String
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else if let subscription = currentSubscription {
                // Active subscription
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Current Plan")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text(subscription.planType.capitalized)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primaryBlue)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(subscription.status.capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(subscription.status == "active" ? .green : .orange)
                        }
                    }
                    
                    if let endDate = subscription.currentPeriodEnd {
                        HStack {
                            Text("Next billing date:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(endDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Button("Cancel Subscription") {
                        showingCancelConfirmation = true
                    }
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
            } else {
                // No subscription
                VStack(spacing: 16) {
                    Text("No Active Subscription")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("Subscribe to unlock premium features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("View Plans") {
                        // Navigate to payment view
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.primaryBlue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
        }
        .onAppear {
            loadSubscription()
        }
        .alert("Cancel Subscription", isPresented: $showingCancelConfirmation) {
            Button("Cancel", role: .destructive) {
                cancelSubscription()
            }
            Button("Keep Subscription", role: .cancel) { }
        } message: {
            Text("Are you sure you want to cancel your subscription? You'll lose access to premium features.")
        }
    }
    
    private func loadSubscription() {
        Task {
            do {
                let subscription = try await stripeService.getUserSubscription(userEmail: userEmail)
                await MainActor.run {
                    currentSubscription = subscription
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func cancelSubscription() {
        guard let subscription = currentSubscription,
              let stripeId = subscription.stripeSubscriptionId else { return }
        
        Task {
            do {
                try await stripeService.cancelSubscription(subscriptionId: stripeId)
                await MainActor.run {
                    loadSubscription()
                }
            } catch {
                // Handle error
            }
        }
    }
}

#Preview {
    PaymentView()
}