import Foundation
import Network

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var connectionType: NWInterface.InterfaceType?
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    // MARK: - HTTP Client
    
    func performRequest<T: Codable>(
        url: URL,
        method: HTTPMethod,
        body: Data? = nil,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = Constants.API.timeoutInterval
        
        var defaultHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        
        if let token = getAuthToken() {
            defaultHeaders["Authorization"] = "Bearer \(token)"
        }
        
        for (key, value) in headers {
            defaultHeaders[key] = value
        }
        
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.httpError(httpResponse.statusCode)
            }
            
            if responseType == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            return try decoder.decode(responseType, from: data)
            
        } catch {
            if error is DecodingError {
                throw NetworkError.decodingError
            } else if error is URLError {
                throw NetworkError.networkError
            } else {
                throw error
            }
        }
    }
    
    // MARK: - File Upload
    
    func uploadFile(
        url: URL,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "file"
    ) async throws -> Data {
        let boundary = UUID().uuidString
        let contentType = "multipart/form-data; boundary=\(boundary)"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0
        
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        return data
    }
    
    // MARK: - Authentication Token Management
    
    private func getAuthToken() -> String? {
        return KeychainManager.shared.getString(for: Constants.KeychainKeys.accessToken)
    }
    
    // MARK: - Request Helpers
    
    func get<T: Codable>(
        url: URL,
        responseType: T.Type,
        headers: [String: String] = [:]
    ) async throws -> T {
        return try await performRequest(
            url: url,
            method: .GET,
            headers: headers,
            responseType: responseType
        )
    }
    
    func post<T: Codable, U: Codable>(
        url: URL,
        body: T,
        responseType: U.Type,
        headers: [String: String] = [:]
    ) async throws -> U {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(body)
        
        return try await performRequest(
            url: url,
            method: .POST,
            body: data,
            headers: headers,
            responseType: responseType
        )
    }
    
    func put<T: Codable, U: Codable>(
        url: URL,
        body: T,
        responseType: U.Type,
        headers: [String: String] = [:]
    ) async throws -> U {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(body)
        
        return try await performRequest(
            url: url,
            method: .PUT,
            body: data,
            headers: headers,
            responseType: responseType
        )
    }
    
    func delete<T: Codable>(
        url: URL,
        responseType: T.Type,
        headers: [String: String] = [:]
    ) async throws -> T {
        return try await performRequest(
            url: url,
            method: .DELETE,
            headers: headers,
            responseType: responseType
        )
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

enum NetworkError: Error {
    case networkError
    case invalidResponse
    case httpError(Int)
    case decodingError
    case encodingError
    case noData
    case unauthorized
    case forbidden
    case notFound
    case serverError
    
    var localizedDescription: String {
        switch self {
        case .networkError:
            return "Network connection error. Please check your internet connection."
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let statusCode):
            return "HTTP error with status code: \(statusCode)"
        case .decodingError:
            return "Failed to decode response data."
        case .encodingError:
            return "Failed to encode request data."
        case .noData:
            return "No data received from server."
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .forbidden:
            return "Access forbidden."
        case .notFound:
            return "Resource not found."
        case .serverError:
            return "Server error. Please try again later."
        }
    }
}

struct EmptyResponse: Codable {
    init() {}
}

// MARK: - Keychain Manager

class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    func setString(_ value: String, for key: String) {
        let data = value.data(using: .utf8)!
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as CFDictionary
        
        SecItemDelete(query)
        SecItemAdd(query, nil)
    }
    
    func getString(for key: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    func deleteString(for key: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ] as CFDictionary
        
        SecItemDelete(query)
    }
    
    func setData(_ data: Data, for key: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as CFDictionary
        
        SecItemDelete(query)
        SecItemAdd(query, nil)
    }
    
    func getData(for key: String) -> Data? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return data
    }
}