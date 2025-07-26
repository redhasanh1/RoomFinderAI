import Foundation

// Simple payment status for the simplified app
enum PaymentStatus {
    case pending
    case processing
    case succeeded
    case failed
    case cancelled
}

// Simple payment result
struct PaymentResult {
    let id: String
    let status: PaymentStatus
    let amount: Double
    let currency: String
    let message: String?
}

// Mock payment method
struct PaymentMethod {
    let id: String
    let type: String
    let last4: String?
    let brand: String?
}

// Simplified Stripe service stub for development
class StripeService: ObservableObject {
    static let shared = StripeService()
    
    @Published var isLoading = false
    @Published var paymentMethods: [PaymentMethod] = []
    
    private init() {
        // Initialize with mock payment methods
        loadMockPaymentMethods()
    }
    
    // Load mock payment methods for development
    private func loadMockPaymentMethods() {
        paymentMethods = [
            PaymentMethod(id: "pm_1", type: "card", last4: "4242", brand: "visa"),
            PaymentMethod(id: "pm_2", type: "card", last4: "5555", brand: "mastercard")
        ]
    }
    
    // Mock payment processing
    func processPayment(amount: Double, currency: String = "USD") async -> PaymentResult {
        isLoading = true
        
        // Simulate payment processing delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        isLoading = false
        
        // For demo purposes, randomly succeed or fail
        let success = Bool.random()
        
        if success {
            return PaymentResult(
                id: "pi_\(UUID().uuidString.prefix(8))",
                status: .succeeded,
                amount: amount,
                currency: currency,
                message: "Payment processed successfully"
            )
        } else {
            return PaymentResult(
                id: "pi_\(UUID().uuidString.prefix(8))",
                status: .failed,
                amount: amount,
                currency: currency,
                message: "Payment failed - Demo mode"
            )
        }
    }
    
    // Mock subscription creation
    func createSubscription(priceId: String) async -> PaymentResult {
        isLoading = true
        
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        isLoading = false
        
        return PaymentResult(
            id: "sub_\(UUID().uuidString.prefix(8))",
            status: .succeeded,
            amount: 9.99,
            currency: "USD",
            message: "Subscription created successfully"
        )
    }
    
    // Mock payment method addition
    func addPaymentMethod() async -> PaymentMethod? {
        isLoading = true
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let newPaymentMethod = PaymentMethod(
            id: "pm_\(UUID().uuidString.prefix(8))",
            type: "card",
            last4: "1234",
            brand: "visa"
        )
        
        paymentMethods.append(newPaymentMethod)
        isLoading = false
        
        return newPaymentMethod
    }
    
    // Mock payment method removal
    func removePaymentMethod(id: String) async -> Bool {
        isLoading = true
        
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        paymentMethods.removeAll { $0.id == id }
        isLoading = false
        
        return true
    }
    
    // Simple validation for demo
    func validateCard(number: String, expiryMonth: Int, expiryYear: Int, cvc: String) -> Bool {
        // Basic validation for demo purposes
        return number.count >= 13 && number.count <= 19 &&
               expiryMonth >= 1 && expiryMonth <= 12 &&
               expiryYear >= 2024 &&
               cvc.count >= 3 && cvc.count <= 4
    }
}

// Extension to handle PostgrestFilterBuilder error (if referenced anywhere)
// This is a temporary stub to resolve compilation issues
struct PostgrestFilterBuilder {
    var maybeSingle: String = ""
}