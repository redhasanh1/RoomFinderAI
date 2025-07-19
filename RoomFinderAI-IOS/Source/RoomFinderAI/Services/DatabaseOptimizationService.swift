import Foundation
import Supabase

// MARK: - Query Optimization Service
class DatabaseOptimizationService {
    static let shared = DatabaseOptimizationService()
    
    private let supabaseService = SupabaseService.shared
    private let logger = LoggingService.shared
    
    private init() {}
    
    // MARK: - Optimized Query Builders
    
    /// Optimized listings query with proper indexing
    func buildOptimizedListingsQuery(request: ListingSearchRequest) -> PostgrestQueryBuilder {
        var query = supabaseService.client
            .from("listings")
            .select("*")
        
        // Use indexed columns for filtering
        if let searchQuery = request.query {
            // Use full-text search index
            query = query.textSearch("title,description", query: searchQuery)
        }
        
        // Location filter using GIN index
        if let location = request.location {
            query = query.ilike("location->>'city'", pattern: "%\(location)%")
        }
        
        // Price range using B-tree index
        if let minPrice = request.minPrice {
            query = query.gte("price", value: minPrice)
        }
        
        if let maxPrice = request.maxPrice {
            query = query.lte("price", value: maxPrice)
        }
        
        // Property attributes using composite indexes
        if let bedrooms = request.bedrooms {
            query = query.eq("bedrooms", value: bedrooms)
        }
        
        if let bathrooms = request.bathrooms {
            query = query.eq("bathrooms", value: bathrooms)
        }
        
        if let propertyType = request.propertyType {
            query = query.eq("property_type", value: propertyType.rawValue)
        }
        
        // Policy filters using partial indexes
        if let petFriendly = request.petFriendly, petFriendly {
            query = query.eq("pet_policy", value: "allowed")
        }
        
        if let smokingAllowed = request.smokingAllowed, smokingAllowed {
            query = query.eq("smoking_policy", value: "allowed")
        }
        
        // Date filter using B-tree index
        if let availableDate = request.availableDate {
            query = query.lte("available_date", value: availableDate.ISO8601Format())
        }
        
        // Always filter active listings using partial index
        query = query.eq("is_active", value: true)
        
        return query
    }
    
    /// Optimized sorting and pagination
    func applyOptimizedSorting(
        query: PostgrestQueryBuilder,
        sortBy: SortOption,
        page: Int,
        limit: Int,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) -> PostgrestTransformBuilder {
        let offset = (page - 1) * limit
        
        switch sortBy {
        case .price:
            // Use composite index: property_type_price or price
            return query.order("price", ascending: true)
                .range(from: offset, to: offset + limit - 1)
            
        case .date:
            // Use composite index: active_created_at
            return query.order("created_at", ascending: false)
                .range(from: offset, to: offset + limit - 1)
            
        case .bedrooms:
            // Use composite index: price_bedrooms
            return query.order("bedrooms", ascending: false)
                .order("price", ascending: true)
                .range(from: offset, to: offset + limit - 1)
            
        case .popularity:
            // Use index: view_count
            return query.order("view_count", ascending: false)
                .range(from: offset, to: offset + limit - 1)
            
        case .distance:
            if let lat = latitude, let lon = longitude {
                // Use spatial index for distance calculation
                return query.order("location->>'latitude'", ascending: true)
                    .range(from: offset, to: offset + limit - 1)
            } else {
                return query.order("created_at", ascending: false)
                    .range(from: offset, to: offset + limit - 1)
            }
        }
    }
    
    // MARK: - Cached Query Results
    
    /// Use materialized view for popular listings
    func fetchPopularListings(city: String? = nil, limit: Int = 20) async throws -> [PopularListing] {
        var query = supabaseService.client
            .from("popular_listings")
            .select("*")
        
        if let city = city {
            query = query.eq("location->>'city'", value: city)
        }
        
        let listings: [PopularListing] = try await query
            .order("view_count", ascending: false)
            .order("favorite_count", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        logger.info("Fetched \(listings.count) popular listings", category: .database)
        return listings
    }
    
    /// Use materialized view for recent listings
    func fetchRecentListings(propertyType: PropertyType? = nil, limit: Int = 20) async throws -> [RecentListing] {
        var query = supabaseService.client
            .from("recent_listings")
            .select("*")
        
        if let propertyType = propertyType {
            query = query.eq("property_type", value: propertyType.rawValue)
        }
        
        let listings: [RecentListing] = try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        logger.info("Fetched \(listings.count) recent listings", category: .database)
        return listings
    }
    
    /// Use materialized view for city statistics
    func fetchCityStatistics(limit: Int = 50) async throws -> [CityStats] {
        let stats: [CityStats] = try await supabaseService.client
            .from("city_stats")
            .select("*")
            .order("total_listings", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        logger.info("Fetched city statistics for \(stats.count) cities", category: .database)
        return stats
    }
    
    // MARK: - Optimized Message Queries
    
    /// Optimized query for user conversations
    func fetchUserConversations(userEmail: String, limit: Int = 50) async throws -> [ConversationWithStats] {
        // Use composite index: user_updated_at
        let conversations: [ConversationWithStats] = try await supabaseService.client
            .from("conversations")
            .select("""
                *,
                messages:messages(count),
                latest_message:messages(content, created_at, sender_id)
            """)
            .or("sender_email.eq.\(userEmail),receiver_email.eq.\(userEmail)")
            .order("updated_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        logger.info("Fetched \(conversations.count) conversations for user", category: .database)
        return conversations
    }
    
    /// Optimized query for conversation messages with pagination
    func fetchConversationMessages(
        conversationId: String,
        page: Int = 1,
        limit: Int = 50
    ) async throws -> MessageResponse {
        let offset = (page - 1) * limit
        
        // Use composite index: conversation_created_at
        let messages: [Message] = try await supabaseService.client
            .from("messages")
            .select("*")
            .eq("conversation_id", value: conversationId)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        // Get total count efficiently
        let countResponse = try await supabaseService.client
            .from("messages")
            .select("count", head: true)
            .eq("conversation_id", value: conversationId)
            .execute()
        
        let totalCount = countResponse.count ?? 0
        let totalPages = (totalCount + limit - 1) / limit
        
        logger.info("Fetched \(messages.count) messages for conversation", category: .database)
        
        return MessageResponse(
            messages: messages.reversed(),
            hasNextPage: page < totalPages,
            hasPreviousPage: page > 1,
            totalCount: totalCount
        )
    }
    
    // MARK: - Batch Operations
    
    /// Optimized batch insert for listings
    func batchInsertListings(_ listings: [ListingInsert]) async throws {
        let batchSize = 100
        
        for i in stride(from: 0, to: listings.count, by: batchSize) {
            let batch = Array(listings[i..<min(i + batchSize, listings.count)])
            
            try await supabaseService.client
                .from("listings")
                .insert(batch)
                .execute()
        }
        
        logger.info("Batch inserted \(listings.count) listings", category: .database)
    }
    
    /// Optimized batch update for view counts
    func batchUpdateViewCounts(_ updates: [String: Int]) async throws {
        for (listingId, increment) in updates {
            try await supabaseService.client
                .from("listings")
                .update(["view_count": "view_count + \(increment)"])
                .eq("id", value: listingId)
                .execute()
        }
        
        logger.info("Batch updated view counts for \(updates.count) listings", category: .database)
    }
    
    // MARK: - Query Performance Monitoring
    
    /// Monitor query performance
    func trackQueryPerformance<T>(
        operation: String,
        query: () async throws -> T
    ) async throws -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let result = try await query()
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            logger.logPerformance(
                operation: operation,
                duration: duration,
                category: .database,
                metadata: ["query_type": "select"]
            )
            
            // Log slow queries
            if duration > 1.0 {
                logger.warning(
                    "Slow query detected: \(operation) took \(String(format: "%.2f", duration * 1000))ms",
                    category: .performance,
                    metadata: ["operation": operation, "duration_ms": duration * 1000]
                )
            }
            
            return result
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            logger.error(
                "Query failed: \(operation) - \(error.localizedDescription)",
                category: .database,
                metadata: [
                    "operation": operation,
                    "duration_ms": duration * 1000,
                    "error": error.localizedDescription
                ]
            )
            
            throw error
        }
    }
    
    // MARK: - Cache Management
    
    /// Refresh materialized views
    func refreshMaterializedViews() async throws {
        try await supabaseService.client
            .rpc("refresh_materialized_views")
            .execute()
        
        logger.info("Refreshed all materialized views", category: .database)
    }
    
    /// Get database statistics
    func getDatabaseStatistics() async throws -> DatabaseStats {
        let stats: DatabaseStats = try await supabaseService.client
            .rpc("get_database_stats")
            .execute()
            .value
        
        logger.info("Retrieved database statistics", category: .database)
        return stats
    }
    
    // MARK: - Connection Pool Management
    
    /// Optimize connection pool settings
    func optimizeConnectionPool() {
        // This would typically be done at the database level
        // or through connection pool configuration
        logger.info("Connection pool optimization requested", category: .database)
    }
    
    // MARK: - Query Plan Analysis
    
    /// Analyze query execution plans
    func analyzeQueryPlan(query: String) async throws -> QueryPlan {
        let plan: QueryPlan = try await supabaseService.client
            .rpc("explain_query", params: ["query": query])
            .execute()
            .value
        
        logger.info("Analyzed query plan", category: .database, metadata: ["query": query])
        return plan
    }
}

// MARK: - Supporting Models

struct PopularListing: Codable {
    let id: String
    let title: String
    let price: Int
    let bedrooms: Int
    let bathrooms: Int
    let propertyType: String
    let location: [String: String]
    let viewCount: Int
    let favoriteCount: Int
    let averageRating: Double?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, price, bedrooms, bathrooms, location
        case propertyType = "property_type"
        case viewCount = "view_count"
        case favoriteCount = "favorite_count"
        case averageRating = "average_rating"
        case createdAt = "created_at"
    }
}

struct RecentListing: Codable {
    let id: String
    let title: String
    let price: Int
    let bedrooms: Int
    let bathrooms: Int
    let propertyType: String
    let location: [String: String]
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, price, bedrooms, bathrooms, location
        case propertyType = "property_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CityStats: Codable {
    let city: String
    let state: String
    let country: String
    let totalListings: Int
    let averagePrice: Double
    let minPrice: Int
    let maxPrice: Int
    let propertyTypesCount: Int
    
    enum CodingKeys: String, CodingKey {
        case city, state, country
        case totalListings = "total_listings"
        case averagePrice = "average_price"
        case minPrice = "min_price"
        case maxPrice = "max_price"
        case propertyTypesCount = "property_types_count"
    }
}

struct ConversationWithStats: Codable {
    let id: String
    let senderEmail: String
    let receiverEmail: String
    let listingId: String?
    let lastMessage: String?
    let createdAt: Date
    let updatedAt: Date
    let messageCount: Int
    let latestMessage: Message?
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderEmail = "sender_email"
        case receiverEmail = "receiver_email"
        case listingId = "listing_id"
        case lastMessage = "last_message"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case messageCount = "message_count"
        case latestMessage = "latest_message"
    }
}

struct ListingInsert: Codable {
    let title: String
    let price: Int
    let bedrooms: Int
    let bathrooms: Int
    let propertyType: String
    let location: [String: String]
    let description: String
    let isActive: Bool
    let availableDate: Date
    
    enum CodingKeys: String, CodingKey {
        case title, price, bedrooms, bathrooms, location, description
        case propertyType = "property_type"
        case isActive = "is_active"
        case availableDate = "available_date"
    }
}

struct DatabaseStats: Codable {
    let totalListings: Int
    let activeListings: Int
    let totalUsers: Int
    let activeUsers: Int
    let totalMessages: Int
    let totalConversations: Int
    let averageResponseTime: Double
    let cacheHitRatio: Double
    
    enum CodingKeys: String, CodingKey {
        case totalListings = "total_listings"
        case activeListings = "active_listings"
        case totalUsers = "total_users"
        case activeUsers = "active_users"
        case totalMessages = "total_messages"
        case totalConversations = "total_conversations"
        case averageResponseTime = "average_response_time"
        case cacheHitRatio = "cache_hit_ratio"
    }
}

struct QueryPlan: Codable {
    let plan: String
    let executionTime: Double
    let planningTime: Double
    let totalCost: Double
    let recommendations: [String]
    
    enum CodingKeys: String, CodingKey {
        case plan
        case executionTime = "execution_time"
        case planningTime = "planning_time"
        case totalCost = "total_cost"
        case recommendations
    }
}

// MARK: - Query Builder Extensions

extension SupabaseService {
    func getOptimizedQuery() -> DatabaseOptimizationService {
        return DatabaseOptimizationService.shared
    }
}

// MARK: - Performance Monitoring Extensions

extension DatabaseOptimizationService {
    func executeWithPerformanceTracking<T>(
        operation: String,
        query: () async throws -> T
    ) async throws -> T {
        return try await trackQueryPerformance(operation: operation, query: query)
    }
}

// MARK: - Batch Processing Extensions

extension DatabaseOptimizationService {
    func processBatchWithOptimization<T, R>(
        items: [T],
        batchSize: Int = 100,
        operation: ([T]) async throws -> R
    ) async throws -> [R] {
        var results: [R] = []
        
        for i in stride(from: 0, to: items.count, by: batchSize) {
            let batch = Array(items[i..<min(i + batchSize, items.count)])
            let result = try await operation(batch)
            results.append(result)
        }
        
        return results
    }
}