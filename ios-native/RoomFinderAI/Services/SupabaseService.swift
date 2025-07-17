import Foundation
import Supabase

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Constants.supabaseURL)!,
            supabaseKey: Constants.supabaseAnonKey
        )
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String, name: String? = nil) async throws -> User {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        
        guard let user = response.user else {
            throw AuthError.signUpFailed
        }
        
        if let name = name {
            try await updateUserProfile(userId: user.id.uuidString, name: name)
        }
        
        return try await getUserProfile(userId: user.id.uuidString)
    }
    
    func signIn(email: String, password: String) async throws -> User {
        let response = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        guard let user = response.user else {
            throw AuthError.signInFailed
        }
        
        return try await getUserProfile(userId: user.id.uuidString)
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }
    
    func getCurrentUser() async throws -> User? {
        guard let user = try await client.auth.user else {
            return nil
        }
        
        return try await getUserProfile(userId: user.id.uuidString)
    }
    
    // MARK: - User Profile Management
    
    private func getUserProfile(userId: String) async throws -> User {
        let response: User = try await client.database
            .from("profiles")
            .select("*")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        return response
    }
    
    private func updateUserProfile(userId: String, name: String) async throws {
        try await client.database
            .from("profiles")
            .update([
                "name": name,
                "updated_at": Date().ISO8601Format()
            ])
            .eq("id", value: userId)
            .execute()
    }
    
    // MARK: - Listings
    
    func fetchListings(request: ListingSearchRequest) async throws -> ListingResponse {
        var query = client.database
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
        switch sortBy {
        case .price:
            query = query.order("price", ascending: true)
        case .date:
            query = query.order("created_at", ascending: false)
        case .bedrooms:
            query = query.order("bedrooms", ascending: false)
        case .popularity:
            query = query.order("view_count", ascending: false)
        case .distance:
            if let lat = request.latitude, let lon = request.longitude {
                query = query.order("location->>'latitude'", ascending: true)
            } else {
                query = query.order("created_at", ascending: false)
            }
        }
        
        let offset = (request.page - 1) * request.limit
        query = query.range(from: offset, to: offset + request.limit - 1)
        
        let listings: [Listing] = try await query.execute().value
        
        let countQuery = client.database
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
        let listing: Listing = try await client.database
            .from("listings")
            .select("*")
            .eq("id", value: id)
            .single()
            .execute()
            .value
        
        return listing
    }
    
    func toggleFavorite(listingId: String, userId: String) async throws {
        let exists = try await client.database
            .from("favorites")
            .select("id")
            .eq("listing_id", value: listingId)
            .eq("user_id", value: userId)
            .execute()
            .value as [String]
        
        if exists.isEmpty {
            try await client.database
                .from("favorites")
                .insert([
                    "listing_id": listingId,
                    "user_id": userId,
                    "created_at": Date().ISO8601Format()
                ])
                .execute()
        } else {
            try await client.database
                .from("favorites")
                .delete()
                .eq("listing_id", value: listingId)
                .eq("user_id", value: userId)
                .execute()
        }
    }
    
    // MARK: - Chat
    
    func fetchChats(userId: String) async throws -> [Chat] {
        let chats: [Chat] = try await client.database
            .from("conversations")
            .select("*, participants(*), last_message(*)")
            .contains("participants", value: [userId])
            .order("updated_at", ascending: false)
            .execute()
            .value
        
        return chats
    }
    
    func fetchMessages(chatId: String, page: Int = 1, limit: Int = 50) async throws -> MessageResponse {
        let offset = (page - 1) * limit
        
        let messages: [Message] = try await client.database
            .from("messages")
            .select("*")
            .eq("chat_id", value: chatId)
            .order("timestamp", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        let countResponse = try await client.database
            .from("messages")
            .select("count", head: true)
            .eq("chat_id", value: chatId)
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
        let message: Message = try await client.database
            .from("messages")
            .insert([
                "chat_id": request.chatId,
                "content": request.content,
                "message_type": request.messageType.rawValue,
                "sender_id": getCurrentUserId(),
                "timestamp": Date().ISO8601Format(),
                "reply_to": request.replyTo as Any,
                "attachments": request.attachments as Any
            ])
            .select("*")
            .single()
            .execute()
            .value
        
        try await updateChatLastMessage(chatId: request.chatId, messageId: message.id)
        
        return message
    }
    
    func createChat(request: CreateChatRequest) async throws -> Chat {
        let chat: Chat = try await client.database
            .from("conversations")
            .insert([
                "title": request.title as Any,
                "participants": request.participantIds,
                "listing_id": request.listingId as Any,
                "is_group_chat": request.isGroupChat,
                "created_at": Date().ISO8601Format(),
                "updated_at": Date().ISO8601Format()
            ])
            .select("*")
            .single()
            .execute()
            .value
        
        return chat
    }
    
    private func updateChatLastMessage(chatId: String, messageId: String) async throws {
        try await client.database
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
        let chats: [AIChat] = try await client.database
            .from("ai_chats")
            .select("*")
            .eq("user_id", value: userId)
            .order("updated_at", ascending: false)
            .execute()
            .value
        
        return chats
    }
    
    func sendAIMessage(chatId: String, message: String) async throws -> AIMessage {
        let aiMessage: AIMessage = try await client.database
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
        
        await channel.on(.insert) { message in
            if let messageData = message.payload["new"] as? [String: Any],
               let decodedMessage = try? JSONDecoder().decode(Message.self, from: JSONSerialization.data(withJSONObject: messageData)) {
                onMessage(decodedMessage)
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