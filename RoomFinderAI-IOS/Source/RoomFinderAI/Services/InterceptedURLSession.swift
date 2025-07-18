import Foundation
import Combine

// MARK: - Intercepted URL Session
class InterceptedURLSession: NSObject, ObservableObject {
    static let shared = InterceptedURLSession()
    
    private let urlSession: URLSession
    private let interceptorService = NetworkInterceptorService.shared
    
    override init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.httpMaximumConnectionsPerHost = 6
        
        self.urlSession = URLSession(configuration: configuration)
        super.init()
    }
    
    // MARK: - Data Task Methods
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        // Intercept request
        let interceptedRequest = try await interceptorService.intercept(request: request)
        
        // Perform request
        let (data, response, error) = await performRequest(interceptedRequest)
        
        // Intercept response
        let interceptedResponse = await interceptorService.intercept(
            response: response,
            data: data,
            error: error,
            for: interceptedRequest
        )
        
        // Handle error
        if let error = interceptedResponse.error {
            throw error
        }
        
        // Return data and response
        guard let responseData = interceptedResponse.data,
              let urlResponse = interceptedResponse.response else {
            throw NetworkError.noData
        }
        
        return (responseData, urlResponse)
    }
    
    func data(from url: URL) async throws -> (Data, URLResponse) {
        let request = URLRequest(url: url)
        return try await data(for: request)
    }
    
    // MARK: - Upload Task Methods
    
    func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse) {
        var uploadRequest = request
        uploadRequest.httpBody = bodyData
        
        // Intercept request
        let interceptedRequest = try await interceptorService.intercept(request: uploadRequest)
        
        // Perform upload
        let (data, response, error) = await performUpload(interceptedRequest, bodyData: bodyData)
        
        // Intercept response
        let interceptedResponse = await interceptorService.intercept(
            response: response,
            data: data,
            error: error,
            for: interceptedRequest
        )
        
        // Handle error
        if let error = interceptedResponse.error {
            throw error
        }
        
        // Return data and response
        guard let responseData = interceptedResponse.data,
              let urlResponse = interceptedResponse.response else {
            throw NetworkError.noData
        }
        
        return (responseData, urlResponse)
    }
    
    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse) {
        // Intercept request
        let interceptedRequest = try await interceptorService.intercept(request: request)
        
        // Perform upload
        let (data, response, error) = await performUpload(interceptedRequest, fileURL: fileURL)
        
        // Intercept response
        let interceptedResponse = await interceptorService.intercept(
            response: response,
            data: data,
            error: error,
            for: interceptedRequest
        )
        
        // Handle error
        if let error = interceptedResponse.error {
            throw error
        }
        
        // Return data and response
        guard let responseData = interceptedResponse.data,
              let urlResponse = interceptedResponse.response else {
            throw NetworkError.noData
        }
        
        return (responseData, urlResponse)
    }
    
    // MARK: - Download Task Methods
    
    func download(for request: URLRequest) async throws -> (URL, URLResponse) {
        // Intercept request
        let interceptedRequest = try await interceptorService.intercept(request: request)
        
        // Perform download
        let (url, response, error) = await performDownload(interceptedRequest)
        
        // Intercept response
        let interceptedResponse = await interceptorService.intercept(
            response: response,
            data: nil,
            error: error,
            for: interceptedRequest
        )
        
        // Handle error
        if let error = interceptedResponse.error {
            throw error
        }
        
        // Return URL and response
        guard let downloadURL = url,
              let urlResponse = interceptedResponse.response else {
            throw NetworkError.noData
        }
        
        return (downloadURL, urlResponse)
    }
    
    func download(from url: URL) async throws -> (URL, URLResponse) {
        let request = URLRequest(url: url)
        return try await download(for: request)
    }
    
    // MARK: - Private Methods
    
    private func performRequest(_ request: URLRequest) async -> (Data?, URLResponse?, Error?) {
        do {
            let (data, response) = try await urlSession.data(for: request)
            return (data, response, nil)
        } catch {
            return (nil, nil, error)
        }
    }
    
    private func performUpload(_ request: URLRequest, bodyData: Data) async -> (Data?, URLResponse?, Error?) {
        do {
            let (data, response) = try await urlSession.upload(for: request, from: bodyData)
            return (data, response, nil)
        } catch {
            return (nil, nil, error)
        }
    }
    
    private func performUpload(_ request: URLRequest, fileURL: URL) async -> (Data?, URLResponse?, Error?) {
        do {
            let (data, response) = try await urlSession.upload(for: request, fromFile: fileURL)
            return (data, response, nil)
        } catch {
            return (nil, nil, error)
        }
    }
    
    private func performDownload(_ request: URLRequest) async -> (URL?, URLResponse?, Error?) {
        do {
            let (url, response) = try await urlSession.download(for: request)
            return (url, response, nil)
        } catch {
            return (nil, nil, error)
        }
    }
}

// MARK: - Convenience Extensions

extension InterceptedURLSession {
    // MARK: - JSON Methods
    
    func json<T: Codable>(for request: URLRequest, type: T.Type) async throws -> T {
        let (data, _) = try await data(for: request)
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }
    
    func json<T: Codable>(from url: URL, type: T.Type) async throws -> T {
        let request = URLRequest(url: url)
        return try await json(for: request, type: type)
    }
    
    func postJSON<T: Codable, U: Codable>(
        to url: URL,
        body: T,
        responseType: U.Type
    ) async throws -> U {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        } catch {
            throw NetworkError.encodingError(error.localizedDescription)
        }
        
        return try await json(for: request, type: responseType)
    }
    
    func putJSON<T: Codable, U: Codable>(
        to url: URL,
        body: T,
        responseType: U.Type
    ) async throws -> U {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        } catch {
            throw NetworkError.encodingError(error.localizedDescription)
        }
        
        return try await json(for: request, type: responseType)
    }
    
    func delete(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (data, _) = try await data(for: request)
        return data
    }
    
    // MARK: - Form Data Methods
    
    func postForm(to url: URL, fields: [String: String]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let formData = fields.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }.joined(separator: "&")
        
        request.httpBody = formData.data(using: .utf8)
        
        let (data, _) = try await data(for: request)
        return data
    }
    
    // MARK: - Multipart Form Data Methods
    
    func postMultipartForm(
        to url: URL,
        fields: [String: String] = [:],
        files: [String: (data: Data, filename: String, mimeType: String)] = [:]
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add form fields
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add files
        for (key, file) in files {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return try await upload(for: request, from: body).0
    }
}

// MARK: - Request Builder

class RequestBuilder {
    private var request: URLRequest
    
    init(url: URL) {
        self.request = URLRequest(url: url)
    }
    
    func method(_ method: String) -> RequestBuilder {
        request.httpMethod = method
        return self
    }
    
    func header(_ name: String, value: String) -> RequestBuilder {
        request.setValue(value, forHTTPHeaderField: name)
        return self
    }
    
    func headers(_ headers: [String: String]) -> RequestBuilder {
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return self
    }
    
    func body(_ data: Data) -> RequestBuilder {
        request.httpBody = data
        return self
    }
    
    func jsonBody<T: Codable>(_ object: T) throws -> RequestBuilder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(object)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return self
    }
    
    func timeout(_ interval: TimeInterval) -> RequestBuilder {
        request.timeoutInterval = interval
        return self
    }
    
    func cachePolicy(_ policy: NSURLRequest.CachePolicy) -> RequestBuilder {
        request.cachePolicy = policy
        return self
    }
    
    func build() -> URLRequest {
        return request
    }
}

// MARK: - URL Extension

extension URL {
    func request() -> RequestBuilder {
        return RequestBuilder(url: self)
    }
}

// MARK: - Network Error Extensions

extension NetworkError {
    static let noData = NetworkError.requestFailed("No data received")
    static let encodingError = { (message: String) in NetworkError.requestFailed("Encoding error: \(message)") }
    static let decodingError = { (message: String) in NetworkError.requestFailed("Decoding error: \(message)") }
}

// MARK: - Usage Examples

/*
 // Basic usage:
 let session = InterceptedURLSession.shared
 let (data, response) = try await session.data(from: url)
 
 // JSON usage:
 let user = try await session.json(from: url, type: User.self)
 
 // POST JSON:
 let newUser = try await session.postJSON(to: url, body: createUserRequest, responseType: User.self)
 
 // Request builder:
 let request = URL(string: "https://api.example.com/users")!
     .request()
     .method("POST")
     .header("Authorization", value: "Bearer token")
     .jsonBody(user)
     .timeout(60)
     .build()
 
 let result = try await session.json(for: request, type: ApiResponse.self)
 */