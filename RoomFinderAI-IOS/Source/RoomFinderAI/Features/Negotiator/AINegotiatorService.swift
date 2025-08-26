import Foundation
import Supabase

// MARK: - AI Negotiator Service
class AINegotiatorService: ObservableObject {
    let supabase: SupabaseClient // Made public for property search
    private let config: OpenAIRequestConfig
    private let marketDataCache = MarketDataCache()
    private var realtimeChannel: RealtimeChannelV2?
    private var messageListener: ((NegotiationMessage) -> Void)?
    
    init(supabase: SupabaseClient, config: OpenAIRequestConfig = .default) {
        self.supabase = supabase
        self.config = config
    }
    
    deinit {
        teardownMessageListener()
    }
    
    // MARK: - AI User Management
    func ensureAIUserExists() async throws {
        // Check if AI user exists in profiles
        let query = supabase
            .from("profiles")
            .select("*")
            .eq("email", value: NegotiatorConfig.aiUserEmail)
        
        do {
            let response: [String: Any] = try await query.execute().data
            // If user exists, we're done
            if let profiles = response["data"] as? [[String: Any]], !profiles.isEmpty {
                print("AI user already exists")
                return
            }
        } catch {
            print("Error checking for AI user: \(error)")
        }
        
        // Create AI user profile if missing
        let aiUser: [String: Any] = [
            "email": NegotiatorConfig.aiUserEmail,
            "name": NegotiatorConfig.aiUserName,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            try await supabase
                .from("profiles")
                .insert(aiUser)
                .execute()
            print("AI user created successfully")
        } catch {
            print("Warning: Could not create AI user profile: \(error)")
            // Continue anyway - AI can still send messages
        }
    }
    
    // MARK: - Market Data
    func getMarketData(location: String?, houseType: String?, bedrooms: Int?) async throws -> MarketStats {
        let query = MarketDataQuery(location: location, houseType: houseType, bedrooms: bedrooms)
        
        // Check cache first
        if let cached = marketDataCache.get(for: query.cacheKey) {
            print("Using cached market data")
            return cached
        }
        
        // Try database first
        do {
            let stats = try await fetchMarketDataFromDB(query: query)
            if stats.hasMinimumData {
                marketDataCache.set(stats, for: query.cacheKey)
                return stats
            }
            print("Insufficient database data (\(stats.count) listings), falling back to AI")
        } catch {
            print("Database query failed: \(error), falling back to AI")
        }
        
        // Fallback to AI generation
        let aiStats = try await getAIMarketData(query: query)
        marketDataCache.set(aiStats, for: query.cacheKey)
        return aiStats
    }
    
    private func fetchMarketDataFromDB(query: MarketDataQuery) async throws -> MarketStats {
        var supabaseQuery = supabase
            .from("listings")
            .select("price,title,city,bedrooms,house_type")
            .not("price", operator: "is", value: "null")
            .limit(query.maxResults)
        
        // Apply filters if provided
        if let location = query.location, !location.isEmpty {
            supabaseQuery = supabaseQuery.or("city.ilike.%\(location)%,title.ilike.%\(location)%")
        }
        
        if let houseType = query.houseType, !houseType.isEmpty {
            supabaseQuery = supabaseQuery.eq("house_type", value: houseType)
        }
        
        if let bedrooms = query.bedrooms {
            supabaseQuery = supabaseQuery.eq("bedrooms", value: bedrooms)
        }
        
        let response = try await supabaseQuery.execute()
        let listings = try JSONDecoder().decode([NegotiationListing].self, from: response.data)
        
        let prices = listings.compactMap { $0.price }.map { Double($0) }
        return MarketStats.calculate(from: prices, query: query)
    }
    
    private func getAIMarketData(query: MarketDataQuery) async throws -> MarketStats {
        let prompt = buildMarketDataPrompt(query: query)
        let response = try await callOpenAI(messages: [
            OpenAIMessage(role: "system", content: prompt)
        ])
        
        guard let content = response.choices.first?.message.content else {
            throw NegotiationError.parsingError("No content in OpenAI response")
        }
        
        // Parse JSON response
        guard let data = content.data(using: .utf8),
              let aiResponse = try? JSONDecoder().decode(AIMarketDataResponse.self, from: data) else {
            throw NegotiationError.parsingError("Failed to parse AI market data JSON")
        }
        
        return aiResponse.toMarketStats(query: query)
    }
    
    private func buildMarketDataPrompt(query: MarketDataQuery) -> String {
        var prompt = """
        Generate realistic rental market statistics in JSON format for:
        """
        
        if let location = query.location {
            prompt += "\nLocation: \(location)"
        }
        if let houseType = query.houseType {
            prompt += "\nProperty Type: \(houseType)"
        }
        if let bedrooms = query.bedrooms {
            prompt += "\nBedrooms: \(bedrooms)"
        }
        
        prompt += """
        
        Return ONLY valid JSON with this exact structure:
        {
          "average": 1500.0,
          "median": 1450.0,
          "min": 1000.0,
          "max": 2500.0,
          "count": 25,
          "analysis": "Brief market analysis",
          "negotiationTips": ["tip1", "tip2", "tip3"]
        }
        
        Base estimates on realistic market data. Include 3-5 practical negotiation tips.
        """
        
        return prompt
    }
    
    // MARK: - Negotiation Messages
    func generateNegotiationMessage(listing: NegotiationListing, userBudget: Double?, marketData: MarketStats) async throws -> String {
        let prompt = buildNegotiationPrompt(listing: listing, userBudget: userBudget, marketData: marketData)
        
        let response = try await callOpenAI(messages: [
            OpenAIMessage(role: "system", content: prompt)
        ])
        
        guard let message = response.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw NegotiationError.parsingError("No message content from OpenAI")
        }
        
        return message
    }
    
    private func buildNegotiationPrompt(listing: NegotiationListing, userBudget: Double?, marketData: MarketStats) -> String {
        var prompt = """
        Write a professional negotiation message for this rental listing:
        
        Property: \(listing.displayTitle)
        Listed Price: \(listing.displayPrice)
        Location: \(listing.displayLocation)
        """
        
        if let budget = userBudget {
            prompt += "\nBudget: $\(Int(budget))"
        }
        
        if let bedrooms = listing.bedrooms {
            prompt += "\nBedrooms: \(bedrooms)"
        }
        
        prompt += "\n\nMarket Data:"
        if let avg = marketData.average {
            prompt += "\n- Average rent: $\(Int(avg))"
        }
        if let median = marketData.median {
            prompt += "\n- Median rent: $\(Int(median))"
        }
        prompt += "\n- Sample size: \(marketData.count) listings"
        
        if let analysis = marketData.analysis {
            prompt += "\n- Market analysis: \(analysis)"
        }
        
        prompt += """
        
        Write a persuasive but respectful negotiation message (2-3 sentences max).
        Use market data to justify a fair offer. Be professional and polite.
        DO NOT include subject lines, signatures, or formatting - just the message content.
        """
        
        return prompt
    }
    
    // MARK: - Reply Analysis
    func analyzeReply(replyContent: String, context: NegotiationContext) async throws -> AnalysisResult {
        // First try regex-based quick analysis for common patterns
        if let quickResult = quickAnalyzeReply(replyContent: replyContent) {
            return quickResult
        }
        
        // Fallback to AI analysis
        return try await aiAnalyzeReply(replyContent: replyContent, context: context)
    }
    
    private func quickAnalyzeReply(replyContent: String) -> AnalysisResult? {
        let content = replyContent.lowercased()
        
        // Check for acceptance patterns
        let acceptancePatterns = ["sure", "yes", "ok", "deal", "accept", "agreed", "fine"]
        if acceptancePatterns.contains(where: { content.contains($0) }) {
            // Try to extract agreed price
            let priceRegex = try? NSRegularExpression(pattern: "\\$([0-9,]+)", options: [])
            let range = NSRange(content.startIndex..., in: content)
            
            if let match = priceRegex?.firstMatch(in: content, range: range),
               let priceRange = Range(match.range(at: 1), in: content) {
                let priceString = String(content[priceRange]).replacingOccurrences(of: ",", with: "")
                if let agreedPrice = Double(priceString) {
                    return AnalysisResult(
                        sentiment: "positive",
                        priceOffered: agreedPrice,
                        acceptsOffer: true,
                        makesCounterOffer: false,
                        shouldRespond: true,
                        isFinalized: true,
                        agreedPrice: agreedPrice,
                        responseStrategy: "acceptance",
                        suggestedResponse: "Perfect! I'll proceed with the rental at $\(Int(agreedPrice)). Thank you!",
                        negotiationPhase: "finalized"
                    )
                }
            }
            
            return AnalysisResult(
                sentiment: "positive",
                priceOffered: nil,
                acceptsOffer: true,
                makesCounterOffer: false,
                shouldRespond: true,
                isFinalized: true,
                agreedPrice: nil,
                responseStrategy: "acceptance",
                suggestedResponse: "Thank you for accepting! I look forward to moving forward.",
                negotiationPhase: "finalized"
            )
        }
        
        // Check for rejection patterns
        let rejectionPatterns = ["no", "not interested", "too low", "can't do", "sorry"]
        if rejectionPatterns.contains(where: { content.contains($0) }) {
            return AnalysisResult(
                sentiment: "negative",
                priceOffered: nil,
                acceptsOffer: false,
                makesCounterOffer: false,
                shouldRespond: true,
                isFinalized: false,
                agreedPrice: nil,
                responseStrategy: "counter",
                suggestedResponse: "I understand. Would you consider meeting somewhere in the middle?",
                negotiationPhase: "negotiating"
            )
        }
        
        return nil // No quick pattern matched, use AI analysis
    }
    
    private func aiAnalyzeReply(replyContent: String, context: NegotiationContext) async throws -> AnalysisResult {
        let prompt = buildAnalysisPrompt(replyContent: replyContent, context: context)
        
        let response = try await callOpenAI(messages: [
            OpenAIMessage(role: "system", content: prompt)
        ])
        
        guard let content = response.choices.first?.message.content,
              let data = content.data(using: .utf8),
              let result = try? JSONDecoder().decode(AnalysisResult.self, from: data) else {
            throw NegotiationError.parsingError("Failed to parse analysis result")
        }
        
        return result
    }
    
    private func buildAnalysisPrompt(replyContent: String, context: NegotiationContext) -> String {
        return """
        Analyze this landlord reply and return ONLY valid JSON:
        
        Reply: "\(replyContent)"
        
        Property: \(context.listing.displayTitle)
        Listed Price: \(context.listing.displayPrice)
        Current Negotiation State: \(context.currentState.displayName)
        
        Return this exact JSON structure:
        {
          "sentiment": "positive/neutral/negative",
          "price_offered": 1400.0,
          "accepts_offer": false,
          "makes_counter_offer": true,
          "should_respond": true,
          "is_finalized": false,
          "agreed_price": null,
          "response_strategy": "counter/acceptance/clarification",
          "suggested_response": "Professional response message",
          "negotiation_phase": "negotiating/counter_offer/finalized"
        }
        
        Extract any prices mentioned. Determine if landlord accepts, counters, or rejects.
        """
    }
    
    // MARK: - Response Generation
    func generateCounterResponse(analysis: AnalysisResult, context: NegotiationContext) async throws -> String {
        let prompt = """
        Generate a counter-negotiation response based on this analysis:
        
        Landlord's sentiment: \(analysis.sentiment ?? "neutral")
        Their price: \(analysis.priceOffered.map { "$\(Int($0))" } ?? "not specified")
        Strategy: \(analysis.responseStrategy ?? "counter")
        
        Property: \(context.listing.displayTitle)
        Listed Price: \(context.listing.displayPrice)
        
        Write a professional counter-offer (2-3 sentences). Be persistent but respectful.
        """
        
        let response = try await callOpenAI(messages: [
            OpenAIMessage(role: "system", content: prompt)
        ])
        
        return response.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? 
               "Thank you for your response. I'd like to continue discussing the rental terms."
    }
    
    func generateMarketBasedResponse(context: NegotiationContext) async throws -> String {
        guard let marketStats = context.marketStats else {
            throw NegotiationError.invalidInput("No market data available")
        }
        
        let prompt = """
        Generate a market-data-based negotiation response:
        
        Property: \(context.listing.displayTitle)
        Listed Price: \(context.listing.displayPrice)
        Market Average: \(marketStats.averagePrice)
        Market Median: \(marketStats.medianPrice)
        Sample Size: \(marketStats.count) listings
        
        Write a data-driven negotiation message (2-3 sentences) using the market statistics.
        """
        
        let response = try await callOpenAI(messages: [
            OpenAIMessage(role: "system", content: prompt)
        ])
        
        return response.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? 
               "Based on current market data, I'd like to discuss a fair rental price."
    }
    
    func generateContextualResponse(messageHistory: [NegotiationMessage], context: NegotiationContext) async throws -> String {
        let recentMessages = Array(messageHistory.suffix(5)) // Last 5 messages for context
        let conversationContext = recentMessages.map { msg in
            "\(msg.displaySender): \(msg.content)"
        }.joined(separator: "\n")
        
        let prompt = """
        Generate a contextual response based on this conversation:
        
        \(conversationContext)
        
        Property: \(context.listing.displayTitle)
        Current State: \(context.currentState.displayName)
        
        Write an appropriate follow-up message (2-3 sentences) that advances the negotiation.
        """
        
        let response = try await callOpenAI(messages: [
            OpenAIMessage(role: "system", content: prompt)
        ])
        
        return response.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? 
               "I'd like to continue our discussion about the rental terms."
    }
    
    // MARK: - Message Sending
    func sendNegotiationMessage(conversationId: UUID, message: String, userEmail: String) async throws {
        let messageData: [String: Any] = [
            "conversation_id": conversationId.uuidString,
            "sender_email": NegotiatorConfig.aiUserEmail,
            "content": message,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        try await supabase
            .from("messages")
            .insert(messageData)
            .execute()
    }
    
    // MARK: - Realtime Listener
    func setupMessageListener(conversationId: UUID, onMessage: @escaping (NegotiationMessage) -> Void) async throws {
        messageListener = onMessage
        
        realtimeChannel = await supabase.realtimeV2.channel("messages_\(conversationId)")
        
        await realtimeChannel?.onPostgresChanges(
            AnyAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(conversationId)"
        ) { [weak self] change in
            Task {
                await self?.handleMessageChange(change, conversationId: conversationId)
            }
        }
        
        await realtimeChannel?.subscribe()
    }
    
    private func handleMessageChange(_ change: AnyAction, conversationId: UUID) async {
        guard case .INSERT = change.action else { return }
        
        do {
            // Fetch the new message
            let response = try await supabase
                .from("messages")
                .select("*")
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
            
            let messages = try JSONDecoder().decode([NegotiationMessage].self, from: response.data)
            
            if let newMessage = messages.first, !newMessage.isFromAI {
                messageListener?(newMessage)
            }
        } catch {
            print("Error handling message change: \(error)")
        }
    }
    
    func teardownMessageListener() {
        Task {
            await realtimeChannel?.unsubscribe()
            realtimeChannel = nil
            messageListener = nil
        }
    }
    
    // MARK: - OpenAI API
    private func callOpenAI(messages: [OpenAIMessage]) async throws -> OpenAIResponse {
        guard !config.apiKey.isEmpty else {
            throw NegotiationError.missingAPIKey
        }
        
        let request = OpenAIRequest(
            model: config.model,
            messages: messages,
            maxTokens: config.maxTokens,
            temperature: config.temperature
        )
        
        var urlRequest = URLRequest(url: URL(string: "\(NegotiatorConfig.openAIBaseURL)/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let orgId = config.organizationID {
            urlRequest.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = config.timeout
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NegotiationError.openAIError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        do {
            return try JSONDecoder().decode(OpenAIResponse.self, from: data)
        } catch {
            throw NegotiationError.parsingError("Failed to decode OpenAI response: \(error)")
        }
    }
    
    // MARK: - Retry Logic
    private func withRetry<T>(maxAttempts: Int = NegotiatorConfig.maxRetries, operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    let delay = min(
                        NegotiatorConfig.baseRetryDelay * pow(2.0, Double(attempt - 1)),
                        NegotiatorConfig.maxRetryDelay
                    )
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NegotiationError.networkError("Max retries exceeded")
    }
}