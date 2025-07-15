import Foundation
import UIKit

// MARK: - API Bridge for Configuration (Simplified iOS Native version)
@objc(CapacitorBridge)
public class CapacitorBridge: NSObject {
    
    static let shared = CapacitorBridge()
    
    // MARK: - Local Configuration Storage
    private struct LocalConfig {
        // Store API keys locally (these would normally come from your backend)
        static let apiKeys: [String: String] = [
            "SUPABASE_URL": "https://zmxyysauqtfkvntgtjsm.supabase.co",
            "SUPABASE_ANON_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM",
            "BACKEND_URL": "https://roomfinder-ai-negotiator-production.up.railway.app",
            // Add your API keys here (you'll need to get these from your backend)
            "OPENAI_API_KEY": "", // Will be fetched from backend or stored locally
            "GOOGLE_API_KEY": "", // For maps and geocoding
            "STRIPE_PUBLISHABLE_KEY": "" // For payments
        ]
    }
    
    // MARK: - Simple API Methods
    
    @objc func getConfig() -> [String: String] {
        return LocalConfig.apiKeys
    }
    
    @objc func getApiKey(keyName: String) -> String? {
        return LocalConfig.apiKeys[keyName]
    }
    
    @objc func setApiKey(keyName: String, keyValue: String) -> Bool {
        // Store in secure keychain
        guard let keychainService = getKeychainServiceIfAvailable() else {
            // Fallback to UserDefaults if KeychainService is not available
            UserDefaults.standard.set(keyValue, forKey: "api_key_\(keyName)")
            return true
        }
        
        return keychainService.saveData(
            keyValue.data(using: .utf8) ?? Data(),
            forKey: "api_key_\(keyName)"
        )
    }
    
    @objc func getStoredApiKey(keyName: String) -> String? {
        if let keychainService = getKeychainServiceIfAvailable(),
           let data = keychainService.loadData(forKey: "api_key_\(keyName)"),
           let keyValue = String(data: data, encoding: .utf8) {
            return keyValue
        }
        
        // Fallback to UserDefaults
        return UserDefaults.standard.string(forKey: "api_key_\(keyName)")
    }
    
    @objc func testConnection(completion: @escaping (Bool, String) -> Void) {
        // Test connection to backend
        let testUrl = "\(LocalConfig.apiKeys["BACKEND_URL"] ?? "")/health"
        
        performNativeRequest(
            url: testUrl,
            method: "GET",
            headers: [:],
            data: nil
        ) { result in
            switch result {
            case .success:
                completion(true, "Backend connection successful")
            case .failure(let error):
                completion(false, "Backend connection failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Native Request Handler
    
    func performNativeRequest(
        url: String,
        method: String,
        headers: [String: String],
        data: [String: Any]?,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let requestUrl = URL(string: url) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 400, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: requestUrl, timeoutInterval: 30)
        request.httpMethod = method
        
        // Add default headers for mobile
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue("RoomFinderAI-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add authentication if available
        if let sessionManager = getSessionManagerIfAvailable(),
           let token = sessionManager.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body data
        if let data = data {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: data)
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        // Perform request
        URLSession.shared.dataTask(with: request) { responseData, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let responseData = responseData else {
                completion(.failure(NSError(domain: "No data received", code: 204, userInfo: nil)))
                return
            }
            
            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                guard 200...299 ~= httpResponse.statusCode else {
                    let errorMsg = "HTTP \(httpResponse.statusCode)"
                    completion(.failure(NSError(domain: errorMsg, code: httpResponse.statusCode, userInfo: nil)))
                    return
                }
            }
            
            // Parse JSON response
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                    completion(.success(jsonResponse))
                } else {
                    // If not JSON object, wrap the response
                    let stringResponse = String(data: responseData, encoding: .utf8) ?? "Unknown response"
                    completion(.success(["data": stringResponse]))
                }
            } catch {
                // If JSON parsing fails, return raw string
                let stringResponse = String(data: responseData, encoding: .utf8) ?? "Unknown response"
                completion(.success(["data": stringResponse]))
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    
    @objc func initializeApiKeys() -> [String: Bool] {
        // Initialize all required API keys
        var results: [String: Bool] = [:]
        
        for (keyName, keyValue) in LocalConfig.apiKeys {
            if !keyValue.isEmpty {
                results[keyName] = setApiKey(keyName: keyName, keyValue: keyValue)
            } else {
                results[keyName] = false
            }
        }
        
        return results
    }
    
    @objc func getEnvironmentInfo() -> [String: Any] {
        return [
            "platform": "ios",
            "isNative": true,
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "1.0",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] ?? "1",
            "deviceModel": UIDevice.current.model,
            "systemVersion": UIDevice.current.systemVersion
        ]
    }
    
    // Helper to safely access KeychainService if available
    private func getKeychainServiceIfAvailable() -> KeychainService? {
        return NSClassFromString("KeychainService") != nil ? KeychainService.shared : nil
    }
    
    // Helper to safely access SessionManager if available
    private func getSessionManagerIfAvailable() -> SessionManager? {
        return NSClassFromString("SessionManager") != nil ? SessionManager.shared : nil
    }
}