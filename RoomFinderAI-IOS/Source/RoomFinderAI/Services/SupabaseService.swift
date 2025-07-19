import Foundation
import Supabase

// AIService and AIResponse are defined in AIService.swift

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private let _client: SupabaseClient
    
    var client: SupabaseClient {
        return _client
    }
    
    private init() {
        guard let url = URL(string: Constants.supabaseURL) else {
            print("⚠️ Invalid Supabase URL: \(Constants.supabaseURL)")
            fatalError("Invalid Supabase URL configuration")
        }
        
        _client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Constants.supabaseAnonKey
        )
        
        print("✅ Supabase client initialized successfully")
        print("🔗 Connected to: \(Constants.supabaseURL)")
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String, name: String? = nil) async throws -> User {
        do {
            let response = try await _client.auth.signUp(
                email: email,
                password: password
            )
            
            let authUser = response.user
            
            if let name = name {
                try await updateUserProfile(userId: authUser.id.uuidString, name: name)
            }
            
            return try await getUserProfile(userId: authUser.id.uuidString)
        } catch {
            let context = ErrorContext(
                additionalInfo: ["email": email, "hasName": name != nil]
            )
            
            let mappedError = mapSupabaseError(error, operation: "signUp")
            ErrorHandler.shared.handle(mappedError, context: context)
            throw mappedError
        }
    }
    
    func signIn(email: String, password: String) async throws -> User {
        do {
            let response = try await _client.auth.signIn(
                email: email,
                password: password
            )
            
            let authUser = response.user
            
            return try await getUserProfile(userId: authUser.id.uuidString)
        } catch {
            let context = ErrorContext(
                additionalInfo: ["email": email]
            )
            
            let mappedError = mapSupabaseError(error, operation: "signIn")
            ErrorHandler.shared.handle(mappedError, context: context)
            throw mappedError
        }
    }
    
    func signOut() async throws {
        try await _client.auth.signOut()
    }
    
    func resetPassword(email: String) async throws {
        try await _client.auth.resetPasswordForEmail(email)
    }
    
    func getCurrentUser() async throws -> User? {
        guard let authUser = _client.auth.currentUser else {
            return nil
        }
        
        return try await getUserProfile(userId: authUser.id.uuidString)
    }
    
    // MARK: - User Profile Management
    
    private func getUserProfile(userId: String) async throws -> User {
        let response: User = try await _client
            .from("users")
            .select("*")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        return response
    }
    
    private func updateUserProfile(userId: String, name: String) async throws {
        try await _client
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
        return try await executeWithRetry {
            let listings: [Listing] = try await _client
                .from("listings")
                .select("*")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            return listings
        }
    }
    
    func fetchListings(request: ListingSearchRequest) async throws -> ListingResponse {
        return try await executeWithRetry {
            do {
                var query = _client
                    .from("listings")
                    .select("*")
                
                // Apply filters
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
                
                // Apply sorting and pagination
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
                
                // Get total count
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
            } catch {
                let context = ErrorContext(
                    additionalInfo: [
                        "page": request.page,
                        "limit": request.limit,
                        "hasFilters": !request.query.isNilOrEmpty
                    ]
                )
                
                let mappedError = mapSupabaseError(error, operation: "fetchListings")
                ErrorHandler.shared.handle(mappedError, context: context)
                throw mappedError
            }
        }
    }
    
    func fetchListingById(_ id: String) async throws -> Listing {
        return try await executeWithRetry {
            let listing: Listing = try await client
                .from("listings")
                .select("*")
                .eq("id", value: id)
                .single()
                .execute()
                .value
            
            return listing
        }
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
            try await _client
                .from("user_favorites")
                .insert([
                    "listing_id": listingId,
                    "user_email": userEmail,
                    "created_at": Date().ISO8601Format()
                ])
                .execute()
        } else {
            try await _client
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
        try await _client
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

    // MARK: - Error Mapping
    
    private func mapSupabaseError(_ error: Error, operation: String) -> AppError {
        let errorDescription = error.localizedDescription.lowercased()
        
        // Network errors
        if errorDescription.contains("network") || errorDescription.contains("connection") {
            return .networkError(.noInternetConnection)
        }
        
        if errorDescription.contains("timeout") {
            return .networkError(.timeoutError)
        }
        
        if errorDescription.contains("rate limit") {
            return .supabaseError(.rateLimitExceeded)
        }
        
        // Auth errors
        if operation.contains("signUp") || operation.contains("signIn") {
            if errorDescription.contains("invalid") || errorDescription.contains("wrong") {
                return .authError(.invalidCredentials)
            }
            
            if errorDescription.contains("user not found") {
                return .authError(.userNotFound)
            }
            
            if errorDescription.contains("email already") {
                return .authError(.emailAlreadyExists)
            }
            
            if errorDescription.contains("password") && errorDescription.contains("weak") {
                return .authError(.weakPassword)
            }
            
            return .authError(.signInFailed(errorDescription))
        }
        
        // Database errors
        if errorDescription.contains("permission") || errorDescription.contains("denied") {
            return .supabaseError(.permissionDenied)
        }
        
        if errorDescription.contains("insert") {
            return .supabaseError(.insertError(errorDescription))
        }
        
        if errorDescription.contains("update") {
            return .supabaseError(.updateError(errorDescription))
        }
        
        if errorDescription.contains("delete") {
            return .supabaseError(.deleteError(errorDescription))
        }
        
        if errorDescription.contains("query") || errorDescription.contains("select") {
            return .supabaseError(.queryError(errorDescription))
        }
        
        // Default to database error
        return .supabaseError(.databaseError(errorDescription))
    }
    
    // MARK: - Retry Logic
    
    private func executeWithRetry<T>(_ operation: () async throws -> T, maxRetries: Int = 3) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if error is retryable
                if !isRetryableError(error) {
                    throw error
                }
                
                // Wait before retry with exponential backoff
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt)) // 2s, 4s, 8s
                    try await Task.sleep(for: .seconds(delay))
                }
            }
        }
        
        throw lastError ?? AppError.unknownError("Max retries exceeded")
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        let description = error.localizedDescription.lowercased()
        
        return description.contains("timeout") ||
               description.contains("network") ||
               description.contains("connection") ||
               description.contains("rate limit") ||
               description.contains("server error") ||
               description.contains("503") ||
               description.contains("502") ||
               description.contains("500")
    }