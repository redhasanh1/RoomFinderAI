import UIKit

// MARK: - Quick API Test for Debugging
class QuickAPITest {
    
    static func runBasicTests() {
        print("🧪 Running Quick API Tests...")
        print("===============================")
        
        // Test 1: Configuration
        testConfiguration()
        
        // Test 2: Session Manager
        testSessionManager()
        
        // Test 3: API Service
        testAPIService()
        
        // Test 4: Network Request
        testNetworkRequest()
        
        print("===============================")
        print("✅ Quick API Tests Complete")
    }
    
    private static func testConfiguration() {
        print("\n📋 Configuration Test:")
        print("Backend URL: \(APIConfig.baseURL)")
        print("Supabase URL: \(APIConfig.supabaseURL)")
        print("Supabase Key: \(APIConfig.supabaseAnonKey.prefix(20))...")
        
        let hasValidConfig = !APIConfig.baseURL.isEmpty && !APIConfig.supabaseURL.isEmpty
        print("Config Status: \(hasValidConfig ? "✅ Valid" : "❌ Invalid")")
    }
    
    private static func testSessionManager() {
        print("\n🔐 Session Manager Test:")
        let sessionManager = SessionManager.shared
        print("Session Valid: \(sessionManager.isSessionValid() ? "✅" : "❌")")
        print("Has Token: \(sessionManager.getAccessToken() != nil ? "✅" : "❌")")
        print("Current User: \(sessionManager.getCurrentUser()?.email ?? "None")")
    }
    
    private static func testAPIService() {
        print("\n🌐 API Service Test:")
        let apiService = APIService.shared
        print("API Service Available: ✅")
        print("Auth Token: \(apiService.getAuthToken() != nil ? "✅ Present" : "❌ Missing")")
    }
    
    private static func testNetworkRequest() {
        print("\n🔗 Network Test:")
        print("Testing backend connection...")
        
        let urlString = "\(APIConfig.baseURL)/health"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        
        print("Requesting: \(urlString)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Network Error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📊 Response Status: \(httpResponse.statusCode)")
                    
                    if 200...299 ~= httpResponse.statusCode {
                        print("✅ Backend connection successful!")
                        
                        if let data = data,
                           let responseString = String(data: data, encoding: .utf8) {
                            print("📄 Response: \(responseString.prefix(100))...")
                        }
                    } else {
                        print("⚠️ Backend returned status: \(httpResponse.statusCode)")
                    }
                }
            }
        }.resume()
    }
}

// MARK: - Extension for easy testing in ViewControllers
extension UIViewController {
    
    func showQuickAPITest() {
        QuickAPITest.runBasicTests()
        
        // Also test property fetching
        print("\n🏠 Testing Property Fetch...")
        APIService.shared.fetchProperties { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let properties):
                    print("✅ Properties fetched: \(properties.count) items")
                    if let first = properties.first {
                        print("📍 Sample: \(first.title) - $\(first.price)")
                    }
                case .failure(let error):
                    print("❌ Property fetch failed: \(error.localizedDescription)")
                }
            }
        }
    }
}