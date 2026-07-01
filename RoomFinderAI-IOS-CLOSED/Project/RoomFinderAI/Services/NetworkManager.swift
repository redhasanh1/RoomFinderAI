import Foundation

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private init() {}
    
    func performRequest<T: Codable>(
        url: URL,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        // Add default headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add custom headers
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(responseType, from: data)
            return decodedResponse
        } catch {
            print("Decoding error: \(error)")
            throw NetworkError.decodingError(error)
        }
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

enum NetworkError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int, String)
    case decodingError(Error)
    case encodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return "HTTP Error \(code): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        }
    }
}