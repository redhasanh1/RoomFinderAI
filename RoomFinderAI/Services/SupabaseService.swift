import Foundation
import Supabase

// MARK: - AI Service Models (Temporary inclusion for build)
struct AIResponse {
    let id: String
    let listingId: String
    let initialOffer: Double
    let recommendedPrice: Double
    let successProbability: Int
    let marketComparison: String
    let negotiationStrategy: String
    let createdAt: Date
}

class AIService: ObservableObject {
    static let shared = AIService()
    
    private let supabaseService = SupabaseService.shared
    private let apiKey = Constants.openAIAPIKey
    
    private init() {}
    
    func startNegotiation(listing: Listing, initialOffer: Double, userEmail: String) async throws -> AIResponse {
        // Mock implementation for now
        try await Task.sleep(for: .seconds(2))
        
        let difference = abs(Double(listing.price) - initialOffer)
        let percentDifference = difference / Double(listing.price) * 100
        
        let recommendedPrice = initialOffer + (difference * 0.3)
        let successProbability = max(20, min(95, Int(100 - percentDifference)))
        
        return AIResponse(
            id: UUID().uuidString,
            listingId: listing.id,
            initialOffer: initialOffer,
            recommendedPrice: recommendedPrice,
            successProbability: successProbability,
            marketComparison: percentDifference < 10 ? "Good offer" : "Below market",
            negotiationStrategy: "Start with your offer and highlight the property's unique value proposition.",
            createdAt: Date()
        )
    }
}

// MARK: - Mortgage Calculator Service (Temporary inclusion for build)
struct MortgageResult {
    let monthlyPayment: Double
    let totalMonthlyPayment: Double
    let totalInterest: Double
    let totalCost: Double
    let loanToValueRatio: Double
}

struct AffordabilityResult {
    let maxHomePrice: Double
    let maxMonthlyPayment: Double
    let maxLoanAmount: Double
    let debtToIncomeRatio: Double
}

struct RefinancingResult {
    let currentMonthlyPayment: Double
    let newMonthlyPayment: Double
    let monthlySavings: Double
    let totalSavings: Double
    let breakEvenMonths: Double
    let isWorthRefinancing: Bool
}

struct RentVsBuyResult {
    let totalRentCost: Double
    let totalBuyingCost: Double
    let netBuyingCost: Double
    let equityBuilt: Double
    let savings: Double
    let recommendation: String
}

class MortgageCalculatorService: ObservableObject {
    static let shared = MortgageCalculatorService()
    
    private init() {}
    
    func calculateMortgage(homePrice: Double, downPayment: Double, interestRate: Double, loanTerm: Int, propertyTax: Double = 0, homeInsurance: Double = 0, pmi: Double = 0, hoaFees: Double = 0) -> MortgageResult {
        let loanAmount = homePrice - downPayment
        let monthlyRate = interestRate / 100 / 12
        let numberOfPayments = Double(loanTerm * 12)
        
        let monthlyPayment = loanAmount * (monthlyRate * pow(1 + monthlyRate, numberOfPayments)) / (pow(1 + monthlyRate, numberOfPayments) - 1)
        
        let totalMonthlyPayment = monthlyPayment + (propertyTax / 12) + (homeInsurance / 12) + (pmi / 12) + (hoaFees / 12)
        let totalInterest = (monthlyPayment * numberOfPayments) - loanAmount
        let totalCost = homePrice + totalInterest
        let loanToValueRatio = (loanAmount / homePrice) * 100
        
        return MortgageResult(
            monthlyPayment: monthlyPayment,
            totalMonthlyPayment: totalMonthlyPayment,
            totalInterest: totalInterest,
            totalCost: totalCost,
            loanToValueRatio: loanToValueRatio
        )
    }
    
    func calculateAffordability(monthlyIncome: Double, monthlyDebts: Double, downPayment: Double, interestRate: Double, loanTerm: Int) -> AffordabilityResult {
        let debtToIncomeRatio = (monthlyDebts / monthlyIncome) * 100
        let maxMonthlyPayment = (monthlyIncome * 0.28) - monthlyDebts
        
        let monthlyRate = interestRate / 100 / 12
        let numberOfPayments = Double(loanTerm * 12)
        
        let maxLoanAmount = maxMonthlyPayment * (pow(1 + monthlyRate, numberOfPayments) - 1) / (monthlyRate * pow(1 + monthlyRate, numberOfPayments))
        let maxHomePrice = maxLoanAmount + downPayment
        
        return AffordabilityResult(
            maxHomePrice: maxHomePrice,
            maxMonthlyPayment: maxMonthlyPayment,
            maxLoanAmount: maxLoanAmount,
            debtToIncomeRatio: debtToIncomeRatio
        )
    }
    
    func calculateRefinancing(currentLoanBalance: Double, currentInterestRate: Double, currentRemainingTerm: Int, newInterestRate: Double, newLoanTerm: Int, closingCosts: Double) -> RefinancingResult {
        let currentMonthlyRate = currentInterestRate / 100 / 12
        let currentPayments = Double(currentRemainingTerm * 12)
        let currentMonthlyPayment = currentLoanBalance * (currentMonthlyRate * pow(1 + currentMonthlyRate, currentPayments)) / (pow(1 + currentMonthlyRate, currentPayments) - 1)
        
        let newMonthlyRate = newInterestRate / 100 / 12
        let newPayments = Double(newLoanTerm * 12)
        let newMonthlyPayment = currentLoanBalance * (newMonthlyRate * pow(1 + newMonthlyRate, newPayments)) / (pow(1 + newMonthlyRate, newPayments) - 1)
        
        let monthlySavings = currentMonthlyPayment - newMonthlyPayment
        let totalSavings = (monthlySavings * newPayments) - closingCosts
        let breakEvenMonths = closingCosts / monthlySavings
        
        return RefinancingResult(
            currentMonthlyPayment: currentMonthlyPayment,
            newMonthlyPayment: newMonthlyPayment,
            monthlySavings: monthlySavings,
            totalSavings: totalSavings,
            breakEvenMonths: breakEvenMonths,
            isWorthRefinancing: totalSavings > 0
        )
    }
    
    func calculateRentVsBuy(homePrice: Double, downPayment: Double, interestRate: Double, loanTerm: Int, monthlyRent: Double, propertyTax: Double, homeInsurance: Double, maintenance: Double, hoa: Double, timeHorizon: Int) -> RentVsBuyResult {
        let mortgage = calculateMortgage(homePrice: homePrice, downPayment: downPayment, interestRate: interestRate, loanTerm: loanTerm, propertyTax: propertyTax, homeInsurance: homeInsurance, pmi: 0, hoaFees: hoa)
        
        let totalRentCost = monthlyRent * Double(timeHorizon * 12)
        let totalBuyingCost = (mortgage.totalMonthlyPayment * Double(timeHorizon * 12)) + downPayment + (maintenance * Double(timeHorizon))
        
        let appreciationRate = 0.03 // 3% annual appreciation
        let futureHomeValue = homePrice * pow(1 + appreciationRate, Double(timeHorizon))
        let remainingBalance = homePrice - downPayment - (mortgage.monthlyPayment * Double(timeHorizon * 12) - mortgage.totalInterest)
        let equityBuilt = max(0, futureHomeValue - remainingBalance)
        
        let netBuyingCost = totalBuyingCost - equityBuilt
        let savings = totalRentCost - netBuyingCost
        
        return RentVsBuyResult(
            totalRentCost: totalRentCost,
            totalBuyingCost: totalBuyingCost,
            netBuyingCost: netBuyingCost,
            equityBuilt: equityBuilt,
            savings: savings,
            recommendation: savings > 0 ? "Buy" : "Rent"
        )
    }
}

// MARK: - Market Analytics Service (Temporary inclusion for build)
struct MarketOverview {
    let averagePrice: Int
    let medianPrice: Int
    let totalListings: Int
    let averageDaysOnMarket: Int
    let priceHistory: [PricePoint]
    let propertyTypeDistribution: [PropertyType: Int]
    let marketScore: Int
    let trend: PriceTrend
    let inventoryLevel: InventoryLevel
}

struct PricePoint {
    let date: Date
    let price: Double
}


enum PriceTrend {
    case increasing
    case stable
    case decreasing
}

enum InventoryLevel {
    case low
    case moderate
    case high
}

enum TimeFrame {
    case threeMonths
    case sixMonths
    case oneYear
    case twoYears
}

class MarketAnalyticsService: ObservableObject {
    static let shared = MarketAnalyticsService()
    
    private init() {}
    
    func getMarketOverview(for city: String) async throws -> MarketOverview {
        // Mock implementation
        try await Task.sleep(for: .seconds(1))
        
        let priceHistory = generateMockPriceHistory()
        let propertyTypeDistribution: [PropertyType: Int] = [
            .apartment: 45,
            .house: 25,
            .condo: 20,
            .townhouse: 10
        ]
        
        return MarketOverview(
            averagePrice: 2500,
            medianPrice: 2200,
            totalListings: 100,
            averageDaysOnMarket: 25,
            priceHistory: priceHistory,
            propertyTypeDistribution: propertyTypeDistribution,
            marketScore: 78,
            trend: .increasing,
            inventoryLevel: .moderate
        )
    }
    
    private func generateMockPriceHistory() -> [PricePoint] {
        let calendar = Calendar.current
        let now = Date()
        var points: [PricePoint] = []
        
        for i in 0..<12 {
            let date = calendar.date(byAdding: .month, value: -i, to: now)!
            let price = 2000 + Double(i * 50) + Double.random(in: -100...100)
            points.append(PricePoint(date: date, price: price))
        }
        
        return points.reversed()
    }
}

// MARK: - Stripe Service (Temporary inclusion for build)
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

struct PaymentResult {
    let success: Bool
    let paymentId: String
    let subscriptionId: String
    let message: String
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

class StripeService: ObservableObject {
    static let shared = StripeService()
    
    private init() {}
    
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
    
    func simulatePayment(amount: Double, planId: String) async throws -> PaymentResult {
        // Simulate payment processing delay
        try await Task.sleep(for: .seconds(2))
        
        // Simulate 90% success rate
        if Double.random(in: 0...1) > 0.9 {
            throw NSError(domain: "PaymentError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Payment failed"])
        }
        
        return PaymentResult(
            success: true,
            paymentId: "payment_\(UUID().uuidString.prefix(8))",
            subscriptionId: "sub_\(UUID().uuidString.prefix(8))",
            message: "Payment successful! Your subscription is now active."
        )
    }
    
    func getUserSubscription(userEmail: String) async throws -> UserSubscription? {
        // Mock implementation
        return nil
    }
    
    func cancelSubscription(subscriptionId: String) async throws {
        // Mock implementation
    }
}

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private let client: SupabaseClient
    
    private init() {
        guard let url = URL(string: Constants.supabaseURL) else {
            print("⚠️ Invalid Supabase URL: \(Constants.supabaseURL)")
            fatalError("Invalid Supabase URL configuration")
        }
        
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Constants.supabaseAnonKey
        )
        
        print("✅ Supabase client initialized successfully")
        print("🔗 Connected to: \(Constants.supabaseURL)")
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String, name: String? = nil) async throws -> User {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        
        let authUser = response.user
        
        if let name = name {
            try await updateUserProfile(userId: authUser.id.uuidString, name: name)
        }
        
        return try await getUserProfile(userId: authUser.id.uuidString)
    }
    
    func signIn(email: String, password: String) async throws -> User {
        let response = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        let authUser = response.user
        
        return try await getUserProfile(userId: authUser.id.uuidString)
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }
    
    func getCurrentUser() async throws -> User? {
        guard let authUser = client.auth.currentUser else {
            return nil
        }
        
        return try await getUserProfile(userId: authUser.id.uuidString)
    }
    
    // MARK: - User Profile Management
    
    private func getUserProfile(userId: String) async throws -> User {
        let response: User = try await client
            .from("users")
            .select("*")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        return response
    }
    
    private func updateUserProfile(userId: String, name: String) async throws {
        try await client
            .from("users")
            .update([
                "first_name": name,
                "updated_at": Date().ISO8601Format()
            ])
            .eq("id", value: userId)
            .execute()
    }
    
    // MARK: - Listings
    
    func fetchAllListings() async throws -> [Listing] {
        let listings: [Listing] = try await client
            .from("listings")
            .select("*")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return listings
    }
    
    func fetchListings(request: ListingSearchRequest) async throws -> ListingResponse {
        var query = client
            .from("listings")
            .select("*")
        
        if let searchQuery = request.query {
            query = query.textSearch("title,description", query: searchQuery)
        }
        
        if let location = request.location {
            query = query.ilike("location->>'city'", pattern: "%\(location)%")
        }
        
        if let minPrice = request.minPrice {
            query = query.gte("price", value: minPrice)
        }
        
        if let maxPrice = request.maxPrice {
            query = query.lte("price", value: maxPrice)
        }
        
        if let bedrooms = request.bedrooms {
            query = query.eq("bedrooms", value: bedrooms)
        }
        
        if let bathrooms = request.bathrooms {
            query = query.eq("bathrooms", value: bathrooms)
        }
        
        if let propertyType = request.propertyType {
            query = query.eq("property_type", value: propertyType.rawValue)
        }
        
        if let petFriendly = request.petFriendly, petFriendly {
            query = query.eq("pet_policy", value: "allowed")
        }
        
        if let smokingAllowed = request.smokingAllowed, smokingAllowed {
            query = query.eq("smoking_policy", value: "allowed")
        }
        
        if let availableDate = request.availableDate {
            query = query.lte("available_date", value: availableDate.ISO8601Format())
        }
        
        let sortBy = request.sortBy ?? .date
        let offset = (request.page - 1) * request.limit
        
        let finalQuery: PostgrestTransformBuilder
        switch sortBy {
        case .price:
            finalQuery = query.order("price", ascending: true).range(from: offset, to: offset + request.limit - 1)
        case .date:
            finalQuery = query.order("created_at", ascending: false).range(from: offset, to: offset + request.limit - 1)
        case .bedrooms:
            finalQuery = query.order("bedrooms", ascending: false).range(from: offset, to: offset + request.limit - 1)
        case .popularity:
            finalQuery = query.order("view_count", ascending: false).range(from: offset, to: offset + request.limit - 1)
        case .distance:
            if let lat = request.latitude, let lon = request.longitude {
                finalQuery = query.order("location->>'latitude'", ascending: true).range(from: offset, to: offset + request.limit - 1)
            } else {
                finalQuery = query.order("created_at", ascending: false).range(from: offset, to: offset + request.limit - 1)
            }
        }
        
        let listings: [Listing] = try await finalQuery.execute().value
        
        let countQuery = client
            .from("listings")
            .select("count", head: true)
        
        let countResponse = try await countQuery.execute()
        let totalCount = countResponse.count ?? 0
        
        let totalPages = (totalCount + request.limit - 1) / request.limit
        
        return ListingResponse(
            listings: listings,
            totalCount: totalCount,
            page: request.page,
            totalPages: totalPages,
            hasNextPage: request.page < totalPages,
            hasPreviousPage: request.page > 1
        )
    }
    
    func fetchListingById(_ id: String) async throws -> Listing {
        let listing: Listing = try await client
            .from("listings")
            .select("*")
            .eq("id", value: id)
            .single()
            .execute()
            .value
        
        return listing
    }
    
    func toggleFavorite(listingId: String, userEmail: String) async throws {
        let exists = try await client
            .from("user_favorites")
            .select("id")
            .eq("listing_id", value: listingId)
            .eq("user_email", value: userEmail)
            .execute()
            .value as [String]
        
        if exists.isEmpty {
            try await client
                .from("user_favorites")
                .insert([
                    "listing_id": listingId,
                    "user_email": userEmail,
                    "created_at": Date().ISO8601Format()
                ])
                .execute()
        } else {
            try await client
                .from("user_favorites")
                .delete()
                .eq("listing_id", value: listingId)
                .eq("user_email", value: userEmail)
                .execute()
        }
    }
    
    // MARK: - Chat
    
    func fetchChats(userEmail: String) async throws -> [Chat] {
        let chats: [Chat] = try await client
            .from("conversations")
            .select("*")
            .or("sender_email.eq.\(userEmail),receiver_email.eq.\(userEmail)")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return chats
    }
    
    func fetchMessages(conversationId: String, page: Int = 1, limit: Int = 50) async throws -> MessageResponse {
        let offset = (page - 1) * limit
        
        let messages: [Message] = try await client
            .from("messages")
            .select("*")
            .eq("conversation_id", value: conversationId)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        let countResponse = try await client
            .from("messages")
            .select("count", head: true)
            .eq("conversation_id", value: conversationId)
            .execute()
        
        let totalCount = countResponse.count ?? 0
        let totalPages = (totalCount + limit - 1) / limit
        
        return MessageResponse(
            messages: messages.reversed(),
            hasNextPage: page < totalPages,
            hasPreviousPage: page > 1,
            totalCount: totalCount
        )
    }
    
    func sendMessage(request: SendMessageRequest) async throws -> Message {
        let message: Message = try await client
            .from("messages")
            .insert(request)
            .select("*")
            .single()
            .execute()
            .value
        
        try await updateChatLastMessage(chatId: request.chatId, messageId: message.id)
        
        return message
    }
    
    func createChat(request: CreateChatRequest) async throws -> Chat {
        let chat: Chat = try await client
            .from("conversations")
            .insert(request)
            .select("*")
            .single()
            .execute()
            .value
        
        return chat
    }
    
    private func updateChatLastMessage(chatId: String, messageId: String) async throws {
        try await client
            .from("conversations")
            .update([
                "last_message": messageId,
                "updated_at": Date().ISO8601Format()
            ])
            .eq("id", value: chatId)
            .execute()
    }
    
    // MARK: - AI Chat
    
    func fetchAIChats(userId: String) async throws -> [AIChat] {
        let chats: [AIChat] = try await client
            .from("ai_chats")
            .select("*")
            .eq("user_id", value: userId)
            .order("updated_at", ascending: false)
            .execute()
            .value
        
        return chats
    }
    
    func sendAIMessage(chatId: String, message: String) async throws -> AIMessage {
        let aiMessage: AIMessage = try await client
            .from("ai_messages")
            .insert([
                "chat_id": chatId,
                "role": "user",
                "content": message,
                "timestamp": Date().ISO8601Format()
            ])
            .select("*")
            .single()
            .execute()
            .value
        
        return aiMessage
    }
    
    // MARK: - Real-time Subscriptions
    
    func subscribeToMessages(chatId: String, onMessage: @escaping (Message) -> Void) async throws {
        let channel = await client.channel("messages")
        
        await channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "chat_id=eq.\(chatId)"
        ) { payload in
            do {
                let messageData = payload.record
                let jsonData = try JSONSerialization.data(withJSONObject: messageData)
                let decodedMessage = try JSONDecoder().decode(Message.self, from: jsonData)
                onMessage(decodedMessage)
            } catch {
                print("Error decoding message: \(error)")
            }
        }
        
        await channel.subscribe()
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentUserId() -> String {
        return "current_user_id"
    }
}

enum AuthError: Error {
    case signUpFailed
    case signInFailed
    case userNotFound
    case invalidCredentials
    case networkError
    
    var localizedDescription: String {
        switch self {
        case .signUpFailed:
            return "Failed to create account. Please try again."
        case .signInFailed:
            return "Failed to sign in. Please check your credentials."
        case .userNotFound:
            return "User not found. Please check your email."
        case .invalidCredentials:
            return "Invalid email or password."
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}