import UIKit

// MARK: - iOS API Test View Controller
class iOSAPITestViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    private let resultsTextView = UITextView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTests()
        runInitialDiagnostics()
    }
    
    private func setupUI() {
        title = "iOS API Tests"
        view.backgroundColor = .systemBackground
        
        // Add close button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissTapped)
        )
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        resultsTextView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        
        // Results text view
        resultsTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        resultsTextView.backgroundColor = .secondarySystemBackground
        resultsTextView.layer.cornerRadius = 8
        resultsTextView.isEditable = false
        resultsTextView.text = "🚀 iOS API Test Results will appear here...\n\n"
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            resultsTextView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    @objc private func dismissTapped() {
        dismiss(animated: true)
    }
    
    private func setupTests() {
        // Add results view first
        stackView.addArrangedSubview(resultsTextView)
        
        // Configuration Test
        let configCard = createTestCard(title: "📋 Check API Configuration") {
            self.testAPIConfiguration()
        }
        stackView.addArrangedSubview(configCard)
        
        // Backend Connection Test
        let backendCard = createTestCard(title: "🌐 Test Backend Connection") {
            self.testBackendConnection()
        }
        stackView.addArrangedSubview(backendCard)
        
        // Supabase Test
        let supabaseCard = createTestCard(title: "🗃️ Test Supabase Connection") {
            self.testSupabaseConnection()
        }
        stackView.addArrangedSubview(supabaseCard)
        
        // Properties Test
        let propertiesCard = createTestCard(title: "🏠 Test Property Fetching") {
            self.testPropertyFetching()
        }
        stackView.addArrangedSubview(propertiesCard)
        
        // OpenAI Test
        let openAICard = createTestCard(title: "🤖 Test OpenAI Integration") {
            self.testOpenAIIntegration()
        }
        stackView.addArrangedSubview(openAICard)
        
        // Authentication Test
        let authCard = createTestCard(title: "🔐 Test Authentication") {
            self.testAuthentication()
        }
        stackView.addArrangedSubview(authCard)
        
        // Clear Results
        let clearCard = createTestCard(title: "🧹 Clear Results") {
            self.clearResults()
        }
        stackView.addArrangedSubview(clearCard)
    }
    
    private func createTestCard(title: String, action: @escaping () -> Void) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 4
        
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.addTarget(self, action: #selector(testButtonTapped(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Store action in button
        objc_setAssociatedObject(button, "action", action, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        card.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            button.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            button.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        
        return card
    }
    
    @objc private func testButtonTapped(_ sender: UIButton) {
        if let action = objc_getAssociatedObject(sender, "action") as? () -> Void {
            action()
        }
    }
    
    // MARK: - Test Methods
    
    private func runInitialDiagnostics() {
        appendToResults("🚀 Starting iOS API Diagnostics...\n")
        appendToResults("Platform: iOS Native\n")
        appendToResults("App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\n")
        appendToResults("Device: \(UIDevice.current.model) (\(UIDevice.current.systemVersion))\n")
        appendToResults("=====================================\n\n")
    }
    
    private func testAPIConfiguration() {
        appendToResults("📋 Testing API Configuration...\n")
        
        // Test LocalAPIKeys configuration
        let validation = LocalAPIKeys.validateConfiguration()
        
        appendToResults("Required Keys:\n")
        for key in LocalAPIKeys.getRequiredKeys() {
            let status = validation[key] == true ? "✅" : "❌"
            appendToResults("  \(status) \(key)\n")
        }
        
        appendToResults("\nOptional Keys:\n")
        for key in LocalAPIKeys.getOptionalKeys() {
            let status = validation[key] == true ? "✅" : "⚪"
            appendToResults("  \(status) \(key)\n")
        }
        
        // Print full summary for debugging
        #if DEBUG
        LocalAPIKeys.printConfiguration()
        #endif
        
        appendToResults("\n" + LocalAPIKeys.getConfigurationSummary() + "\n")
    }
    
    private func testBackendConnection() {
        appendToResults("🌐 Testing Backend Connection...\n")
        
        let backendURL = LocalAPIKeys.backendURL
        guard !backendURL.isEmpty else {
            appendToResults("❌ Backend URL not configured\n\n")
            return
        }
        
        appendToResults("Backend URL: \(backendURL)\n")
        
        let healthURL = "\(backendURL)/health"
        guard let url = URL(string: healthURL) else {
            appendToResults("❌ Invalid health check URL\n\n")
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue("RoomFinderAI-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        appendToResults("Making request to: \(healthURL)\n")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.appendToResults("❌ Connection failed: \(error.localizedDescription)\n\n")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    self?.appendToResults("Status Code: \(httpResponse.statusCode)\n")
                    
                    if 200...299 ~= httpResponse.statusCode {
                        self?.appendToResults("✅ Backend connection successful!\n")
                        
                        if let data = data,
                           let responseString = String(data: data, encoding: .utf8) {
                            self?.appendToResults("Response: \(responseString)\n")
                        }
                    } else {
                        self?.appendToResults("❌ Backend returned error status\n")
                    }
                } else {
                    self?.appendToResults("❌ Invalid response\n")
                }
                
                self?.appendToResults("\n")
            }
        }.resume()
    }
    
    private func testSupabaseConnection() {
        appendToResults("🗃️ Testing Supabase Connection...\n")
        
        let supabaseURL = LocalAPIKeys.supabaseURL
        let supabaseKey = LocalAPIKeys.supabaseAnonKey
        
        guard !supabaseURL.isEmpty && !supabaseKey.isEmpty else {
            appendToResults("❌ Supabase configuration missing\n\n")
            return
        }
        
        appendToResults("Supabase URL: \(supabaseURL)\n")
        
        // Test Supabase REST API
        let testURL = "\(supabaseURL)/rest/v1/"
        guard let url = URL(string: testURL) else {
            appendToResults("❌ Invalid Supabase URL\n\n")
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.appendToResults("❌ Supabase connection failed: \(error.localizedDescription)\n\n")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    self?.appendToResults("Supabase Status: \(httpResponse.statusCode)\n")
                    
                    if 200...299 ~= httpResponse.statusCode {
                        self?.appendToResults("✅ Supabase connection successful!\n\n")
                    } else {
                        self?.appendToResults("❌ Supabase returned error: \(httpResponse.statusCode)\n\n")
                    }
                }
            }
        }.resume()
    }
    
    private func testPropertyFetching() {
        appendToResults("🏠 Testing Property Fetching...\n")
        
        APIService.shared.fetchProperties { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let properties):
                    self?.appendToResults("✅ Successfully fetched \(properties.count) properties\n")
                    
                    if let firstProperty = properties.first {
                        self?.appendToResults("Sample Property: \(firstProperty.title)\n")
                        self?.appendToResults("Price: $\(firstProperty.price)\n")
                        self?.appendToResults("Location: \(firstProperty.city), \(firstProperty.state)\n")
                    }
                    
                case .failure(let error):
                    self?.appendToResults("❌ Property fetching failed: \(error.localizedDescription)\n")
                }
                
                self?.appendToResults("\n")
            }
        }
    }
    
    private func testOpenAIIntegration() {
        appendToResults("🤖 Testing OpenAI Integration...\n")
        
        guard let openAIKey = LocalAPIKeys.openAIKey else {
            appendToResults("❌ OpenAI API key not configured\n")
            appendToResults("Add your OpenAI key to LocalAPIKeys.swift\n\n")
            return
        }
        
        appendToResults("OpenAI Key: \(String(openAIKey.prefix(8)))...\n")
        
        let testURL = "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: testURL) else {
            appendToResults("❌ Invalid OpenAI URL\n\n")
            return
        }
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "user", "content": "Say 'Hello from iOS app!' in exactly 5 words."]
            ],
            "max_tokens": 20
        ]
        
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            appendToResults("❌ Failed to create request body: \(error)\n\n")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.appendToResults("❌ OpenAI request failed: \(error.localizedDescription)\n\n")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    self?.appendToResults("OpenAI Status: \(httpResponse.statusCode)\n")
                    
                    if 200...299 ~= httpResponse.statusCode,
                       let data = data {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let firstChoice = choices.first,
                               let message = firstChoice["message"] as? [String: Any],
                               let content = message["content"] as? String {
                                self?.appendToResults("✅ OpenAI Response: \(content.trimmingCharacters(in: .whitespacesAndNewlines))\n")
                            } else {
                                self?.appendToResults("✅ OpenAI connection successful (response parsing issue)\n")
                            }
                        } catch {
                            self?.appendToResults("✅ OpenAI connection successful (JSON parsing issue)\n")
                        }
                    } else {
                        self?.appendToResults("❌ OpenAI returned error: \(httpResponse.statusCode)\n")
                        
                        if let data = data,
                           let errorResponse = String(data: data, encoding: .utf8) {
                            self?.appendToResults("Error details: \(errorResponse)\n")
                        }
                    }
                }
                
                self?.appendToResults("\n")
            }
        }.resume()
    }
    
    private func testAuthentication() {
        appendToResults("🔐 Testing Authentication System...\n")
        
        // Test session manager
        let sessionManager = SessionManager.shared
        appendToResults("Session Manager: ✅ Available\n")
        appendToResults("Current Session Valid: \(sessionManager.isSessionValid() ? "✅" : "❌")\n")
        
        if let user = sessionManager.getCurrentUser() {
            appendToResults("Current User: \(user.email)\n")
        } else {
            appendToResults("Current User: None\n")
        }
        
        // Test keychain service
        let keychainService = KeychainService.shared
        let testKey = "test_auth_key"
        let testValue = "test_value_\(Date().timeIntervalSince1970)"
        
        let saveSuccess = keychainService.saveData(
            testValue.data(using: .utf8) ?? Data(),
            forKey: testKey
        )
        
        if saveSuccess {
            if let retrievedData = keychainService.loadData(forKey: testKey),
               let retrievedValue = String(data: retrievedData, encoding: .utf8),
               retrievedValue == testValue {
                appendToResults("Keychain Service: ✅ Working\n")
            } else {
                appendToResults("Keychain Service: ❌ Retrieval failed\n")
            }
            
            // Cleanup
            _ = keychainService.deleteItem(forKey: testKey)
        } else {
            appendToResults("Keychain Service: ❌ Save failed\n")
        }
        
        appendToResults("\n")
    }
    
    private func clearResults() {
        resultsTextView.text = "🧹 Results cleared.\n\n"
    }
    
    private func appendToResults(_ text: String) {
        resultsTextView.text += text
        
        // Auto-scroll to bottom
        let bottom = NSMakeRange(resultsTextView.text.count - 1, 1)
        resultsTextView.scrollRangeToVisible(bottom)
    }
}