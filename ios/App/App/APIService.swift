import Foundation
import Capacitor

// MARK: - API Configuration
struct APIConfig {
    static let baseURL = "https://roomfinderai-production.up.railway.app"
    static let apiVersion = "v1"
    
    // Endpoints
    struct Endpoints {
        static let properties = "/api/properties"
        static let search = "/api/search"
        static let favorites = "/api/favorites"
        static let user = "/api/user"
        static let auth = "/api/auth"
        static let chat = "/api/chat"
    }
}

// MARK: - Data Models
struct Property: Codable {
    let id: String
    let title: String
    let description: String
    let address: String
    let city: String
    let state: String
    let zipCode: String
    let price: Double
    let bedrooms: Int
    let bathrooms: Int
    let sqft: Int
    let propertyType: String
    let images: [String]
    let amenities: [String]
    let latitude: Double?
    let longitude: Double?
    let createdAt: String
    let updatedAt: String
    var isFavorite: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, address, city, state, price, bedrooms, bathrooms, sqft, amenities, latitude, longitude, isFavorite
        case zipCode = "zip_code"
        case propertyType = "property_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case images
    }
}

struct SearchFilters: Codable {
    let minPrice: Double?
    let maxPrice: Double?
    let bedrooms: Int?
    let bathrooms: Int?
    let propertyType: String?
    let city: String?
    let amenities: [String]?
    let sortBy: String?
    let sortOrder: String?
}

struct User: Codable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let phone: String?
    let profileImage: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, email, phone, createdAt
        case firstName = "first_name"
        case lastName = "last_name"
        case profileImage = "profile_image"
    }
}

struct AuthResponse: Codable {
    let success: Bool
    let token: String?
    let user: User?
    let message: String?
}

struct ChatMessage: Codable {
    let id: String
    let conversationId: String
    let senderId: String
    let receiverId: String
    let content: String
    let messageType: String
    let timestamp: String
    let isRead: Bool
    let senderName: String?
    let propertyId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, content, timestamp, propertyId
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case messageType = "message_type"
        case isRead = "is_read"
        case senderName = "sender_name"
    }
}

struct ChatConversation: Codable {
    let id: String
    let participantIds: [String]
    let propertyId: String?
    let propertyTitle: String?
    let lastMessage: String?
    let lastMessageTime: String?
    let unreadCount: Int
    let otherParticipant: User?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, createdAt
        case participantIds = "participant_ids"
        case propertyId = "property_id"
        case propertyTitle = "property_title"
        case lastMessage = "last_message"
        case lastMessageTime = "last_message_time"
        case unreadCount = "unread_count"
        case otherParticipant = "other_participant"
    }
}

// MARK: - API Service
class APIService {
    static let shared = APIService()
    
    private init() {}
    
    // MARK: - Properties
    func fetchProperties(page: Int = 1, limit: Int = 20, completion: @escaping (Result<[Property], Error>) -> Void) {
        // Use real Supabase data
        Task {
            do {
                var filters = SupabaseSearchFilters()
                filters.offset = (page - 1) * limit
                filters.limit = limit
                
                let supabaseListings = try await SupabaseService.shared.fetchListings(filters: filters)
                let properties = supabaseListings.map { $0.toProperty() }
                
                DispatchQueue.main.async {
                    completion(.success(properties))
                }
            } catch {
                print("Failed to fetch real properties, using fallback: \(error)")
                // Fallback to sample data if Supabase fails
                DispatchQueue.main.async {
                    completion(.success(self.getSampleProperties()))
                }
            }
        }
    }
    
    func searchProperties(query: String, filters: SearchFilters? = nil, completion: @escaping (Result<[Property], Error>) -> Void) {
        Task {
            do {
                // Convert to Supabase search
                var supabaseFilters = SupabaseSearchFilters()
                
                if let filters = filters {
                    supabaseFilters.city = filters.city
                    supabaseFilters.maxPrice = filters.maxPrice != nil ? Int(filters.maxPrice!) : nil
                    supabaseFilters.minPrice = filters.minPrice != nil ? Int(filters.minPrice!) : nil
                    supabaseFilters.houseType = filters.propertyType
                    supabaseFilters.bedrooms = filters.bedrooms
                    supabaseFilters.limit = 50
                }
                
                let supabaseListings: [SupabaseListing]
                
                if query.isEmpty {
                    // Fetch with filters only
                    supabaseListings = try await SupabaseService.shared.fetchListings(filters: supabaseFilters)
                } else {
                    // Search by query
                    supabaseListings = try await SupabaseService.shared.searchListings(query: query)
                }
                
                let properties = supabaseListings.map { $0.toProperty() }
                
                DispatchQueue.main.async {
                    completion(.success(properties))
                }
            } catch {
                print("Failed to search real properties, using fallback: \(error)")
                // Fallback to filtered sample data
                DispatchQueue.main.async {
                    let filteredProperties = self.filterSampleProperties(query: query, filters: filters)
                    completion(.success(filteredProperties))
                }
            }
        }
    }
    
    func getProperty(id: String, completion: @escaping (Result<Property, Error>) -> Void) {
        let urlString = "\(APIConfig.baseURL)\(APIConfig.Endpoints.properties)/\(id)"
        performRequest(urlString: urlString, completion: completion)
    }
    
    // MARK: - Favorites
    func getFavorites(completion: @escaping (Result<[Property], Error>) -> Void) {
        let urlString = "\(APIConfig.baseURL)\(APIConfig.Endpoints.favorites)"
        performRequest(urlString: urlString, completion: completion)
    }
    
    func toggleFavorite(propertyId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let urlString = "\(APIConfig.baseURL)\(APIConfig.Endpoints.favorites)/\(propertyId)"
        performRequest(urlString: urlString, method: "POST") { (result: Result<[String: Bool], Error>) in
            switch result {
            case .success(let response):
                completion(.success(response["isFavorite"] ?? false))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Authentication
    func login(email: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        let urlString = "\(APIConfig.baseURL)\(APIConfig.Endpoints.auth)/login"
        let body = ["email": email, "password": password]
        performRequest(urlString: urlString, method: "POST", body: body, completion: completion)
    }
    
    func register(email: String, password: String, firstName: String, lastName: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        let urlString = "\(APIConfig.baseURL)\(APIConfig.Endpoints.auth)/register"
        let body = ["email": email, "password": password, "first_name": firstName, "last_name": lastName]
        performRequest(urlString: urlString, method: "POST", body: body, completion: completion)
    }
    
    func getCurrentUser(completion: @escaping (Result<User, Error>) -> Void) {
        let urlString = "\(APIConfig.baseURL)\(APIConfig.Endpoints.user)/profile"
        performRequest(urlString: urlString, completion: completion)
    }
    
    // MARK: - Chat/Messaging
    func getConversations(completion: @escaping (Result<[ChatConversation], Error>) -> Void) {
        let urlString = "\(APIConfig.baseURL)\(APIConfig.Endpoints.chat)/conversations"
        performRequest(urlString: urlString, completion: completion)
    }
    
    func getMessages(conversationId: String, completion: @escaping (Result<[ChatMessage], Error>) -> Void) {
        let urlString = "\(APIConfig.baseURL)\(APIConfig.Endpoints.chat)/conversations/\(conversationId)/messages"
        performRequest(urlString: urlString, completion: completion)
    }
    
    func sendMessage(conversationId: String, content: String, completion: @escaping (Result<ChatMessage, Error>) -> Void) {
        let urlString = "\(APIConfig.baseURL)\(APIConfig.Endpoints.chat)/conversations/\(conversationId)/messages"
        let body = ["content": content, "message_type": "text"]
        performRequest(urlString: urlString, method: "POST", body: body, completion: completion)
    }
    
    func startConversation(propertyId: String, initialMessage: String, completion: @escaping (Result<ChatConversation, Error>) -> Void) {
        let urlString = "\(APIConfig.baseURL)\(APIConfig.Endpoints.chat)/conversations"
        let body = ["property_id": propertyId, "initial_message": initialMessage]
        performRequest(urlString: urlString, method: "POST", body: body, completion: completion)
    }
    
    func markMessagesAsRead(conversationId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let urlString = "\(APIConfig.baseURL)\(APIConfig.Endpoints.chat)/conversations/\(conversationId)/read"
        performRequest(urlString: urlString, method: "POST") { (result: Result<[String: String], Error>) in
            switch result {
            case .success(_):
                completion(.success(true))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Generic Request Method
    private func performRequest<T: Codable>(
        urlString: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication token if available
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add request body for POST/PUT requests
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(APIError.noData))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(T.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Sample Data Fallback
    private func getSampleProperties() -> [Property] {
        return [
            Property(
                id: "1",
                title: "Modern Downtown Apartment",
                description: "Beautiful 2BR/2BA apartment in downtown with city views",
                address: "123 Main Street",
                city: "New York",
                state: "NY",
                zipCode: "10001",
                price: 2500.0,
                bedrooms: 2,
                bathrooms: 2,
                sqft: 1200,
                propertyType: "Apartment",
                images: ["https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400&h=250&fit=crop"],
                amenities: ["Parking", "Gym", "Pool"],
                latitude: 40.7128,
                longitude: -74.0060,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z",
                isFavorite: false
            ),
            Property(
                id: "2",
                title: "Luxury Studio Loft",
                description: "Spacious studio with exposed brick and modern amenities",
                address: "456 Brooklyn Ave",
                city: "Brooklyn",
                state: "NY",
                zipCode: "11201",
                price: 1800.0,
                bedrooms: 1,
                bathrooms: 1,
                sqft: 800,
                propertyType: "Studio",
                images: ["https://images.unsplash.com/photo-1560449752-c40dfffbdab9?w=400&h=250&fit=crop"],
                amenities: ["Laundry", "Parking", "Rooftop"],
                latitude: 40.6892,
                longitude: -73.9442,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z",
                isFavorite: true
            ),
            Property(
                id: "3",
                title: "Cozy Family House",
                description: "3BR house with backyard in quiet neighborhood",
                address: "789 Oak Street",
                city: "Austin",
                state: "TX",
                zipCode: "73301",
                price: 3200.0,
                bedrooms: 3,
                bathrooms: 2,
                sqft: 1800,
                propertyType: "House",
                images: ["https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=400&h=250&fit=crop"],
                amenities: ["Garden", "Parking", "Pet Friendly"],
                latitude: 30.2672,
                longitude: -97.7431,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z",
                isFavorite: false
            )
        ]
    }
    
    private func filterSampleProperties(query: String, filters: SearchFilters?) -> [Property] {
        var properties = getSampleProperties()
        
        // Filter by query
        if !query.isEmpty {
            let lowercaseQuery = query.lowercased()
            properties = properties.filter {
                $0.title.lowercased().contains(lowercaseQuery) ||
                $0.city.lowercased().contains(lowercaseQuery) ||
                $0.description.lowercased().contains(lowercaseQuery)
            }
        }
        
        // Apply filters
        if let filters = filters {
            if let city = filters.city, !city.isEmpty {
                properties = properties.filter { $0.city.lowercased().contains(city.lowercased()) }
            }
            
            if let minPrice = filters.minPrice {
                properties = properties.filter { $0.price >= minPrice }
            }
            
            if let maxPrice = filters.maxPrice {
                properties = properties.filter { $0.price <= maxPrice }
            }
            
            if let bedrooms = filters.bedrooms {
                properties = properties.filter { $0.bedrooms == bedrooms }
            }
            
            if let propertyType = filters.propertyType, !propertyType.isEmpty {
                properties = properties.filter { $0.propertyType.lowercased() == propertyType.lowercased() }
            }
        }
        
        return properties
    }
    
    // MARK: - Token Management
    func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: "auth_token")
    }
    
    func setAuthToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "auth_token")
    }
    
    func clearAuthToken() {
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }
    
    func getCurrentUserId() -> String? {
        return UserDefaults.standard.string(forKey: "current_user_id")
    }
    
    func setCurrentUserId(_ userId: String) {
        UserDefaults.standard.set(userId, forKey: "current_user_id")
    }
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case unauthorized
    case serverError(Int)
    case custom(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .unauthorized:
            return "Unauthorized access"
        case .serverError(let code):
            return "Server error: \(code)"
        case .custom(let message):
            return message
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

// MARK: - Image Service
class ImageService {
    static let shared = ImageService()
    private let imageCache = NSCache<NSString, UIImage>()
    
    private init() {}
    
    func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        // Check cache first
        if let cachedImage = imageCache.object(forKey: urlString as NSString) {
            completion(cachedImage)
            return
        }
        
        // Load from URL
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // Cache the image
            self?.imageCache.setObject(image, forKey: urlString as NSString)
            
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }
}

// MARK: - UIImageView Extension
extension UIImageView {
    func loadImage(from urlString: String, placeholder: UIImage? = nil) {
        image = placeholder
        
        ImageService.shared.loadImage(from: urlString) { [weak self] image in
            self?.image = image ?? placeholder
        }
    }
}