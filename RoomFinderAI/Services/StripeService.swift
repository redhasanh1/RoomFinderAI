import Foundation
import Supabase

class StripeService: ObservableObject {
    static let shared = StripeService()
    
    private let supabaseService = SupabaseService.shared
    private let publishableKey = Constants.stripePublishableKey
    private let secretKey = Constants.stripeSecretKey
    
    private init() {}
    
    // MARK: - Subscription Plans
    
    func getSubscriptionPlans() -> [SubscriptionPlan] {
        return [
            SubscriptionPlan(
                id: "basic",
                name: "Basic",
                price: 9.99,
                features: [
                    "Access to all listings",
                    "Basic search filters",
                    "Email support",
                    "Up to 5 saved searches"
                ],
                stripePriceId: "price_basic_monthly"
            ),
            SubscriptionPlan(
                id: "premium",
                name: "Premium",
                price: 19.99,
                features: [
                    "Everything in Basic",
                    "AI Negotiator",
                    "Market Analytics",
                    "Priority support",
                    "Unlimited saved searches",
                    "Price alerts"
                ],
                stripePriceId: "price_premium_monthly"
            ),
            SubscriptionPlan(
                id: "pro",
                name: "Pro",
                price: 39.99,
                features: [
                    "Everything in Premium",
                    "Mortgage Calculator",
                    "Investment Analysis",
                    "Sublease Management",
                    "Advanced Market Reports",
                    "Phone support",
                    "Early access to new features"
                ],
                stripePriceId: "price_pro_monthly"
            )
        ]
    }
    
    // MARK: - Payment Processing
    
    func createPaymentIntent(amount: Double, currency: String = "usd") async throws -> PaymentIntent {
        let url = URL(string: "https://api.stripe.com/v1/payment_intents")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let amountCents = Int(amount * 100)
        let body = "amount=\(amountCents)&currency=\(currency)&automatic_payment_methods[enabled]=true"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StripeError.paymentFailed
        }
        
        let result = try JSONDecoder().decode(StripePaymentIntentResponse.self, from: data)
        
        return PaymentIntent(
            id: result.id,
            clientSecret: result.client_secret,
            amount: Double(result.amount) / 100,
            currency: result.currency,
            status: result.status
        )
    }
    
    func createSubscription(customerId: String, priceId: String) async throws -> Subscription {
        let url = URL(string: "https://api.stripe.com/v1/subscriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "customer=\(customerId)&items[0][price]=\(priceId)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StripeError.subscriptionFailed
        }
        
        let result = try JSONDecoder().decode(StripeSubscriptionResponse.self, from: data)
        
        return Subscription(
            id: result.id,
            customerId: result.customer,
            priceId: priceId,
            status: result.status,
            currentPeriodStart: Date(timeIntervalSince1970: TimeInterval(result.current_period_start)),
            currentPeriodEnd: Date(timeIntervalSince1970: TimeInterval(result.current_period_end))
        )
    }
    
    func createCustomer(email: String, name: String) async throws -> Customer {
        let url = URL(string: "https://api.stripe.com/v1/customers")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "email=\(email)&name=\(name)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StripeError.customerCreationFailed
        }
        
        let result = try JSONDecoder().decode(StripeCustomerResponse.self, from: data)
        
        return Customer(
            id: result.id,
            email: result.email,
            name: result.name
        )
    }
    
    // MARK: - Subscription Management
    
    func getUserSubscription(userEmail: String) async throws -> UserSubscription? {
        let subscription: UserSubscription? = try await supabaseService.client
            .from("subscriptions")
            .select("*")
            .eq("user_email", value: userEmail)
            .eq("status", value: "active")
            .maybeSingle()
            .execute()
            .value
        
        return subscription
    }
    
    func updateUserSubscription(userEmail: String, subscription: Subscription) async throws {
        let record: [String: Any] = [
            "user_email": userEmail,
            "plan_type": subscription.priceId,
            "status": subscription.status,
            "stripe_subscription_id": subscription.id,
            "current_period_start": subscription.currentPeriodStart.ISO8601Format(),
            "current_period_end": subscription.currentPeriodEnd.ISO8601Format()
        ]
        
        try await supabaseService.client
            .from("subscriptions")
            .upsert(record)
            .execute()
    }
    
    func cancelSubscription(subscriptionId: String) async throws {
        let url = URL(string: "https://api.stripe.com/v1/subscriptions/\(subscriptionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StripeError.cancellationFailed
        }
    }
    
    // MARK: - Feature Access Control
    
    func hasAccess(to feature: PremiumFeature, userEmail: String) async -> Bool {
        do {
            guard let subscription = try await getUserSubscription(userEmail: userEmail) else {
                return feature.isAvailableInFree
            }
            
            let plan = getSubscriptionPlans().first { $0.stripePriceId == subscription.planType }
            
            switch subscription.planType {
            case "price_basic_monthly":
                return feature.isAvailableInBasic
            case "price_premium_monthly":
                return feature.isAvailableInPremium
            case "price_pro_monthly":
                return feature.isAvailableInPro
            default:
                return feature.isAvailableInFree
            }
        } catch {
            return feature.isAvailableInFree
        }
    }
    
    func getFeatureAccessLevel(userEmail: String) async -> SubscriptionLevel {
        do {
            guard let subscription = try await getUserSubscription(userEmail: userEmail) else {
                return .free
            }
            
            switch subscription.planType {
            case "price_basic_monthly":
                return .basic
            case "price_premium_monthly":
                return .premium
            case "price_pro_monthly":
                return .pro
            default:
                return .free
            }
        } catch {
            return .free
        }
    }
    
    // MARK: - Mock Payment Processing (for demo)
    
    func simulatePayment(amount: Double, planId: String) async throws -> PaymentResult {
        // Simulate payment processing delay
        try await Task.sleep(for: .seconds(2))
        
        // Simulate 90% success rate
        if Double.random(in: 0...1) > 0.9 {
            throw StripeError.paymentFailed
        }
        
        return PaymentResult(
            success: true,
            paymentId: "payment_\(UUID().uuidString.prefix(8))",
            subscriptionId: "sub_\(UUID().uuidString.prefix(8))",
            message: "Payment successful! Your subscription is now active."
        )
    }
}

// MARK: - Models

struct SubscriptionPlan {
    let id: String
    let name: String
    let price: Double
    let features: [String]
    let stripePriceId: String
    
    var isPopular: Bool {
        return id == "premium"
    }
}

struct PaymentIntent {
    let id: String
    let clientSecret: String
    let amount: Double
    let currency: String
    let status: String
}

struct Subscription {
    let id: String
    let customerId: String
    let priceId: String
    let status: String
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
}

struct Customer {
    let id: String
    let email: String
    let name: String?
}

struct UserSubscription: Codable {
    let id: String
    let userEmail: String
    let planType: String
    let status: String
    let stripeSubscriptionId: String?
    let currentPeriodStart: Date?
    let currentPeriodEnd: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case userEmail = "user_email"
        case planType = "plan_type"
        case stripeSubscriptionId = "stripe_subscription_id"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
    }
}

struct PaymentResult {
    let success: Bool
    let paymentId: String
    let subscriptionId: String
    let message: String
}

enum PremiumFeature {
    case aiNegotiator
    case marketAnalytics
    case mortgageCalculator
    case subleaseMmanagement
    case advancedFilters
    case priceAlerts
    case prioritySupport
    case investmentAnalysis
    case advancedReports
    
    var isAvailableInFree: Bool {
        return false
    }
    
    var isAvailableInBasic: Bool {
        switch self {
        case .advancedFilters: return true
        default: return false
        }
    }
    
    var isAvailableInPremium: Bool {
        switch self {
        case .aiNegotiator, .marketAnalytics, .advancedFilters, .priceAlerts: return true
        default: return isAvailableInBasic
        }
    }
    
    var isAvailableInPro: Bool {
        return true // All features available in Pro
    }
}

enum SubscriptionLevel {
    case free
    case basic
    case premium
    case pro
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .basic: return "Basic"
        case .premium: return "Premium"
        case .pro: return "Pro"
        }
    }
}

// MARK: - Stripe Response Models

struct StripePaymentIntentResponse: Codable {
    let id: String
    let client_secret: String
    let amount: Int
    let currency: String
    let status: String
}

struct StripeSubscriptionResponse: Codable {
    let id: String
    let customer: String
    let status: String
    let current_period_start: Int
    let current_period_end: Int
}

struct StripeCustomerResponse: Codable {
    let id: String
    let email: String
    let name: String?
}

// MARK: - Errors

enum StripeError: Error {
    case paymentFailed
    case subscriptionFailed
    case customerCreationFailed
    case cancellationFailed
    case invalidAPIKey
    case networkError
    
    var localizedDescription: String {
        switch self {
        case .paymentFailed:
            return "Payment failed. Please try again."
        case .subscriptionFailed:
            return "Failed to create subscription."
        case .customerCreationFailed:
            return "Failed to create customer account."
        case .cancellationFailed:
            return "Failed to cancel subscription."
        case .invalidAPIKey:
            return "Invalid API key."
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}