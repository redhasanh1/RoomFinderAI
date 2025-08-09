import Foundation
import Supabase

class AIService: ObservableObject {
    static let shared = AIService()
    
    private let openAIAPIKey = Constants.openAIAPIKey
    private let supabaseService = SupabaseService.shared
    
    private init() {}
    
    // MARK: - AI Negotiation
    
    func startNegotiation(listing: Listing, initialOffer: Double, userEmail: String) async throws -> AIResponse {
        // Create negotiation record
        let negotiation = AIRequest(
            listingId: listing.id,
            userEmail: userEmail,
            initialPrice: Int(listing.price),
            currentOffer: Int(initialOffer),
            negotiationHistory: []
        )
        
        // Save to database
        try await saveNegotiation(negotiation)
        
        // Generate AI response
        let context = NegotiationContext(
            listing: listing,
            initialOffer: initialOffer,
            marketData: await getMarketData(for: listing)
        )
        
        return try await generateAIResponse(context: context, message: "I'd like to negotiate the price to $\(Int(initialOffer))")
    }
    
    func continueNegotiation(negotiationId: String, userMessage: String) async throws -> AIResponse {
        // Fetch existing negotiation
        let negotiation = try await fetchNegotiation(negotiationId: negotiationId)
        
        // Get listing details
        let listing = try await supabaseService.fetchListingById(negotiation.listingId)
        
        // Generate context
        let context = NegotiationContext(
            listing: listing,
            initialOffer: Double(negotiation.currentOffer),
            marketData: await getMarketData(for: listing),
            negotiationHistory: negotiation.negotiationHistory
        )
        
        return try await generateAIResponse(context: context, message: userMessage)
    }
    
    // MARK: - AI Response Generation
    
    private func generateAIResponse(context: NegotiationContext, message: String) async throws -> AIResponse {
        guard !openAIAPIKey.isEmpty && openAIAPIKey != "YOUR_OPENAI_API_KEY" else {
            // Return mock response for demo
            return generateMockNegotiationResponse(context: context, message: message)
        }
        
        let systemPrompt = createNegotiationSystemPrompt(context: context)
        
        let requestBody: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": message]
            ],
            "max_tokens": 500,
            "temperature": 0.7
        ]
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.apiError
        }
        
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = result.choices.first?.message.content else {
            throw AIError.noResponse
        }
        
        return parseAIResponse(content: content, context: context)
    }
    
    private func generateMockNegotiationResponse(context: NegotiationContext, message: String) -> AIResponse {
        let currentPrice = context.listing.price
        let userOffer = context.initialOffer
        
        let responses = [
            "I understand you're interested in negotiating the price. The current asking price is $\(currentPrice). Your offer of $\(Int(userOffer)) is about \(Int(((Double(currentPrice) - userOffer) / Double(currentPrice)) * 100))% below asking price.",
            
            "Thank you for your interest! Based on current market conditions in \(context.listing.city), properties like this typically rent for $\(currentPrice - 100) to $\(currentPrice + 100). Would you consider $\(currentPrice - 50)?",
            
            "I appreciate your offer. This property has premium features like \(context.listing.utilities). The best I can do is $\(currentPrice - 100). What do you think?",
            
            "Let me check with the landlord about your offer of $\(Int(userOffer)). Given the property's location and amenities, I think we might be able to meet in the middle at $\(Int((Double(currentPrice) + userOffer) / 2)). Does that work for you?"
        ]
        
        return AIResponse(
            message: responses.randomElement() ?? responses[0],
            suggestedPrice: Int((Double(currentPrice) + userOffer) / 2),
            confidence: 0.8,
            reasoning: "Based on market analysis and property features",
            nextSteps: ["Consider the counter-offer", "Schedule a viewing", "Request property documents"]
        )
    }
    
    private func createNegotiationSystemPrompt(context: NegotiationContext) -> String {
        return """
        You are an AI real estate negotiator representing property owners. Your role is to:
        
        1. Negotiate rental prices professionally and fairly
        2. Highlight property value and market conditions
        3. Find mutually beneficial agreements
        4. Maintain a helpful and professional tone
        
        Property Details:
        - Address: \(context.listing.street), \(context.listing.city)
        - Type: \(context.listing.houseType)
        - Bedrooms: \(context.listing.bedrooms)
        - Asking Price: $\(context.listing.price)
        - Utilities: \(context.listing.utilities)
        
        Market Context:
        - Average rent in area: $\(context.marketData.averageRent)
        - Price trend: \(context.marketData.trend)
        - Demand level: \(context.marketData.demandLevel)
        
        Guidelines:
        - Don't accept offers below 80% of asking price
        - Emphasize property value and location benefits
        - Be willing to negotiate within reason
        - Always provide a counter-offer if rejecting
        - Keep responses concise and professional
        """
    }
    
    private func parseAIResponse(content: String, context: NegotiationContext) -> AIResponse {
        // Simple parsing - in production, you'd use more sophisticated NLP
        let lines = content.components(separatedBy: "\n")
        let message = lines.first ?? content
        
        // Extract suggested price if mentioned
        let priceRegex = try! NSRegularExpression(pattern: "\\$([0-9,]+)", options: [])
        let range = NSRange(location: 0, length: content.count)
        let matches = priceRegex.matches(in: content, options: [], range: range)
        
        var suggestedPrice: Int?
        if let match = matches.last {
            let priceString = (content as NSString).substring(with: match.range(at: 1))
            suggestedPrice = Int(priceString.replacingOccurrences(of: ",", with: ""))
        }
        
        return AIResponse(
            message: message,
            suggestedPrice: suggestedPrice,
            confidence: 0.85,
            reasoning: "AI analysis of market conditions and property value",
            nextSteps: ["Review the offer", "Consider counter-proposal", "Schedule property viewing"]
        )
    }
    
    // MARK: - Market Data
    
    private func getMarketData(for listing: Listing) async -> MarketData {
        // In production, this would fetch real market data
        return MarketData(
            averageRent: listing.price + Int.random(in: -200...200),
            trend: ["increasing", "stable", "decreasing"].randomElement() ?? "stable",
            demandLevel: ["high", "medium", "low"].randomElement() ?? "medium",
            comparableProperties: []
        )
    }
    
    // MARK: - Database Operations
    
    private func saveNegotiation(_ negotiation: AIRequest) async throws {
        let record: [String: Any] = [
            "listing_id": negotiation.listingId,
            "user_email": negotiation.userEmail,
            "initial_price": negotiation.initialPrice,
            "final_price": negotiation.currentOffer,
            "negotiation_status": "active",
            "ai_responses": try JSONSerialization.data(withJSONObject: negotiation.negotiationHistory.map { $0.toDictionary() })
        ]
        
        try await supabaseService.client
            .from("ai_negotiations")
            .insert(record)
            .execute()
    }
    
    private func fetchNegotiation(negotiationId: String) async throws -> AIRequest {
        let result: [String: Any] = try await supabaseService.client
            .from("ai_negotiations")
            .select("*")
            .eq("id", value: negotiationId)
            .single()
            .execute()
            .value
        
        // Parse and return AIRequest
        return AIRequest(
            listingId: result["listing_id"] as? String ?? "",
            userEmail: result["user_email"] as? String ?? "",
            initialPrice: result["initial_price"] as? Int ?? 0,
            currentOffer: result["final_price"] as? Int ?? 0,
            negotiationHistory: []
        )
    }
    
    // MARK: - Property Analysis
    
    func analyzeProperty(listing: Listing) async throws -> PropertyAnalysis {
        let marketData = await getMarketData(for: listing)
        
        return PropertyAnalysis(
            estimatedValue: listing.price,
            marketComparison: marketData.averageRent > listing.price ? "Below Market" : "Above Market",
            priceRecommendation: "Consider pricing at $\(marketData.averageRent)",
            strengths: ["Good location", "Modern amenities", "Competitive pricing"],
            weaknesses: ["Limited parking", "Older building"],
            negotiationRange: (Int(Double(listing.price) * 0.9), Int(Double(listing.price) * 1.1))
        )
    }
}

// MARK: - Models

struct AIRequest {
    let listingId: String
    let userEmail: String
    let initialPrice: Int
    let currentOffer: Int
    let negotiationHistory: [AIResponse]
}

struct AIResponse {
    let message: String
    let suggestedPrice: Int?
    let confidence: Double
    let reasoning: String
    let nextSteps: [String]
    
    func toDictionary() -> [String: Any] {
        return [
            "message": message,
            "suggested_price": suggestedPrice as Any,
            "confidence": confidence,
            "reasoning": reasoning,
            "next_steps": nextSteps
        ]
    }
}

struct NegotiationContext {
    let listing: Listing
    let initialOffer: Double
    let marketData: MarketData
    let negotiationHistory: [AIResponse] = []
}

struct MarketData {
    let averageRent: Int
    let trend: String
    let demandLevel: String
    let comparableProperties: [Listing]
}

struct PropertyAnalysis {
    let estimatedValue: Int
    let marketComparison: String
    let priceRecommendation: String
    let strengths: [String]
    let weaknesses: [String]
    let negotiationRange: (min: Int, max: Int)
}

// MARK: - OpenAI Response Models

struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

// MARK: - Errors

enum AIError: Error {
    case invalidURL
    case apiError
    case noResponse
    case invalidResponse
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .apiError:
            return "AI API request failed"
        case .noResponse:
            return "No response from AI service"
        case .invalidResponse:
            return "Invalid response format"
        }
    }
}