import Foundation
import UIKit

// MARK: - Data Models for iOS
struct PropertyModel: Codable {
    let id: String
    let title: String
    let description: String
    let address: String
    let city: String
    let state: String
    let zipCode: String
    let price: Int
    let bedrooms: Int
    let bathrooms: Int
    let propertyType: String
    let images: [String]
    let amenities: [String]
    let isAvailable: Bool
    let createdAt: String
    let updatedAt: String
    let landlordId: String
    let latitude: Double?
    let longitude: Double?
}

struct UserModel: Codable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let phone: String?
    let profileImage: String?
    let userType: String
    let createdAt: String
    let updatedAt: String
}

struct ChatConversationModel: Codable {
    let id: String
    let propertyId: String
    let tenantId: String
    let landlordId: String
    let lastMessage: String
    let lastMessageTime: String
    let isActive: Bool
}

struct ChatMessageModel: Codable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: String
    let messageType: String
    let timestamp: String
    let isRead: Bool
}

struct AIResponseModel: Codable {
    let query: String
    let response: String
    let confidence: Double
    let timestamp: String
}

struct PaymentIntentModel: Codable {
    let id: String
    let amount: Int
    let currency: String
    let status: String
    let description: String
    let createdAt: String
}

struct DashboardStatsModel: Codable {
    let favoriteCount: Int
    let conversationCount: Int
    let recentSearchCount: Int
    let totalSavings: Int
}

// MARK: - Mobile API Bridge
class MobileAPIBridge: NSObject {
    static let shared = MobileAPIBridge()
    
    private override init() {
        super.init()
        setupCapacitorBridge()
    }
    
    private func setupCapacitorBridge() {
        // Initialize Capacitor bridge for calling TypeScript services
        guard let bridge = CapacitorBridge.shared else {
            print("❌ Capacitor bridge not available")
            return
        }
        
        // Setup bridge is ready
        print("✅ MobileAPIBridge initialized successfully")
    }
    
    // MARK: - Authentication Methods
    
    func signUp(email: String, password: String, userData: [String: Any], completion: @escaping (Result<UserModel, Error>) -> Void) {
        let params: [String: Any] = [
            "email": email,
            "password": password,
            "userData": userData
        ]
        
        callTypeScriptFunction("signUp", params: params) { result in
            switch result {
            case .success(let data):
                do {
                    let user = try self.decodeResponse(UserModel.self, from: data)
                    completion(.success(user))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        let params: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        callTypeScriptFunction("signIn", params: params) { result in
            switch result {
            case .success(let data):
                do {
                    let user = try self.decodeResponse(UserModel.self, from: data)
                    completion(.success(user))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        callTypeScriptFunction("signOut", params: [:]) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func getCurrentUser(completion: @escaping (Result<UserModel?, Error>) -> Void) {
        callTypeScriptFunction("getCurrentUser", params: [:]) { result in
            switch result {
            case .success(let data):
                if let data = data, !data.isEmpty {
                    do {
                        let user = try self.decodeResponse(UserModel.self, from: data)
                        completion(.success(user))
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    completion(.success(nil))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Property Methods
    
    func fetchProperties(filters: [String: Any] = [:], completion: @escaping (Result<[PropertyModel], Error>) -> Void) {
        let params: [String: Any] = ["filters": filters]
        
        callTypeScriptFunction("fetchProperties", params: params) { result in
            switch result {
            case .success(let data):
                do {
                    let properties = try self.decodeResponse([PropertyModel].self, from: data)
                    completion(.success(properties))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func getPropertyById(_ id: String, completion: @escaping (Result<PropertyModel?, Error>) -> Void) {
        let params: [String: Any] = ["id": id]
        
        callTypeScriptFunction("getPropertyById", params: params) { result in
            switch result {
            case .success(let data):
                if let data = data, !data.isEmpty {
                    do {
                        let property = try self.decodeResponse(PropertyModel.self, from: data)
                        completion(.success(property))
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    completion(.success(nil))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func searchProperties(query: String, filters: [String: Any] = [:], completion: @escaping (Result<[PropertyModel], Error>) -> Void) {
        let params: [String: Any] = [
            "query": query,
            "filters": filters
        ]
        
        callTypeScriptFunction("searchProperties", params: params) { result in
            switch result {
            case .success(let data):
                do {
                    let properties = try self.decodeResponse([PropertyModel].self, from: data)
                    completion(.success(properties))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Chat Methods
    
    func getConversations(userId: String, completion: @escaping (Result<[ChatConversationModel], Error>) -> Void) {
        let params: [String: Any] = ["userId": userId]
        
        callTypeScriptFunction("getConversations", params: params) { result in
            switch result {
            case .success(let data):
                do {
                    let conversations = try self.decodeResponse([ChatConversationModel].self, from: data)
                    completion(.success(conversations))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func getMessages(conversationId: String, completion: @escaping (Result<[ChatMessageModel], Error>) -> Void) {
        let params: [String: Any] = ["conversationId": conversationId]
        
        callTypeScriptFunction("getMessages", params: params) { result in
            switch result {
            case .success(let data):
                do {
                    let messages = try self.decodeResponse([ChatMessageModel].self, from: data)
                    completion(.success(messages))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func sendMessage(conversationId: String, senderId: String, content: String, messageType: String = "text", completion: @escaping (Result<ChatMessageModel, Error>) -> Void) {
        let params: [String: Any] = [
            "conversationId": conversationId,
            "senderId": senderId,
            "content": content,
            "messageType": messageType
        ]
        
        callTypeScriptFunction("sendMessage", params: params) { result in
            switch result {
            case .success(let data):
                do {
                    let message = try self.decodeResponse(ChatMessageModel.self, from: data)
                    completion(.success(message))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - AI Methods
    
    func getAIResponse(query: String, context: [String: Any] = [:], completion: @escaping (Result<String, Error>) -> Void) {
        let params: [String: Any] = [
            "query": query,
            "context": context
        ]
        
        callTypeScriptFunction("getAIResponse", params: params) { result in
            switch result {
            case .success(let data):
                if let response = data?["response"] as? String {
                    completion(.success(response))
                } else {
                    completion(.failure(APIError.invalidResponse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func getNegotiationHelp(propertyId: String, currentOffer: Int, targetRent: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let params: [String: Any] = [
            "propertyId": propertyId,
            "currentOffer": currentOffer,
            "targetRent": targetRent
        ]
        
        callTypeScriptFunction("getNegotiationHelp", params: params) { result in
            switch result {
            case .success(let data):
                if let response = data?["response"] as? String {
                    completion(.success(response))
                } else {
                    completion(.failure(APIError.invalidResponse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Payment Methods
    
    func createPaymentIntent(amount: Int, currency: String, description: String, completion: @escaping (Result<PaymentIntentModel, Error>) -> Void) {
        let params: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "description": description
        ]
        
        callTypeScriptFunction("createPaymentIntent", params: params) { result in
            switch result {
            case .success(let data):
                do {
                    let paymentIntent = try self.decodeResponse(PaymentIntentModel.self, from: data)
                    completion(.success(paymentIntent))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Favorites Methods
    
    func getFavorites(userId: String, completion: @escaping (Result<[PropertyModel], Error>) -> Void) {
        let params: [String: Any] = ["userId": userId]
        
        callTypeScriptFunction("getFavorites", params: params) { result in
            switch result {
            case .success(let data):
                do {
                    let favorites = try self.decodeResponse([PropertyModel].self, from: data)
                    completion(.success(favorites))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func addToFavorites(userId: String, propertyId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let params: [String: Any] = [
            "userId": userId,
            "propertyId": propertyId
        ]
        
        callTypeScriptFunction("addToFavorites", params: params) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func removeFromFavorites(userId: String, propertyId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let params: [String: Any] = [
            "userId": userId,
            "propertyId": propertyId
        ]
        
        callTypeScriptFunction("removeFromFavorites", params: params) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Dashboard Methods
    
    func getDashboardStats(userId: String, completion: @escaping (Result<DashboardStatsModel, Error>) -> Void) {
        let params: [String: Any] = ["userId": userId]
        
        callTypeScriptFunction("getDashboardStats", params: params) { result in
            switch result {
            case .success(let data):
                do {
                    let stats = try self.decodeResponse(DashboardStatsModel.self, from: data)
                    completion(.success(stats))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func uploadImage(_ image: UIImage, type: String, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(APIError.invalidData))
            return
        }
        
        let params: [String: Any] = [
            "imageData": imageData.base64EncodedString(),
            "type": type,
            "userId": userId
        ]
        
        callTypeScriptFunction("uploadImage", params: params) { result in
            switch result {
            case .success(let data):
                if let url = data?["url"] as? String {
                    completion(.success(url))
                } else {
                    completion(.failure(APIError.invalidResponse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func trackUserAction(userId: String, action: String, metadata: [String: Any] = [:]) {
        let params: [String: Any] = [
            "userId": userId,
            "action": action,
            "metadata": metadata
        ]
        
        callTypeScriptFunction("trackUserAction", params: params) { _ in
            // Analytics tracking - fire and forget
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func callTypeScriptFunction(_ functionName: String, params: [String: Any], completion: @escaping (Result<[String: Any]?, Error>) -> Void) {
        guard let bridge = CapacitorBridge.shared else {
            completion(.failure(APIError.bridgeNotAvailable))
            return
        }
        
        let script = """
        try {
            const result = await window.mobileApiService.\(functionName)(\(jsonString(from: params)));
            window.webkit.messageHandlers.capacitorCallback.postMessage({
                success: true,
                data: result
            });
        } catch (error) {
            window.webkit.messageHandlers.capacitorCallback.postMessage({
                success: false,
                error: error.message
            });
        }
        """
        
        bridge.evaluateJavaScript(script) { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let result = result as? [String: Any] {
                if let success = result["success"] as? Bool, success {
                    completion(.success(result["data"] as? [String: Any]))
                } else {
                    let errorMessage = result["error"] as? String ?? "Unknown error"
                    completion(.failure(APIError.custom(errorMessage)))
                }
            } else {
                completion(.failure(APIError.invalidResponse))
            }
        }
    }
    
    private func decodeResponse<T: Codable>(_ type: T.Type, from data: [String: Any]?) throws -> T {
        guard let data = data else {
            throw APIError.invalidData
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        return try JSONDecoder().decode(type, from: jsonData)
    }
    
    private func jsonString(from object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case bridgeNotAvailable
    case invalidData
    case invalidResponse
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .bridgeNotAvailable:
            return "Capacitor bridge is not available"
        case .invalidData:
            return "Invalid data provided"
        case .invalidResponse:
            return "Invalid response from server"
        case .custom(let message):
            return message
        }
    }
}

// MARK: - Extensions for API Models
extension PropertyModel {
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }
    
    var bedroomBathroomText: String {
        let bedText = bedrooms == 1 ? "1 bed" : "\(bedrooms) beds"
        let bathText = bathrooms == 1 ? "1 bath" : "\(bathrooms) baths"
        return "\(bedText) • \(bathText)"
    }
}

extension UserModel {
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
    
    var displayName: String {
        return fullName.isEmpty ? email : fullName
    }
}

extension ChatMessageModel {
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = formatter.date(from: timestamp) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "h:mm a"
            return displayFormatter.string(from: date)
        }
        
        return timestamp
    }
}

extension DashboardStatsModel {
    var formattedSavings: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: totalSavings)) ?? "$\(totalSavings)"
    }
}