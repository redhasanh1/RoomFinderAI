import UIKit

// MARK: - API Test View Controller
class APITestViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTests()
    }
    
    private func setupUI() {
        title = "API Tests"
        view.backgroundColor = .systemBackground
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        
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
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupTests() {
        // Diagnostics Section
        let diagnosticsCard = createCard(title: "System Diagnostics") {
            self.runDiagnostics()
        }
        stackView.addArrangedSubview(diagnosticsCard)
        
        // Environment Test
        let envCard = createCard(title: "Test Environment") {
            self.testEnvironment()
        }
        stackView.addArrangedSubview(envCard)
        
        // API Keys Test
        let keysCard = createCard(title: "Test API Keys") {
            self.testAPIKeys()
        }
        stackView.addArrangedSubview(keysCard)
        
        // Supabase Test
        let supabaseCard = createCard(title: "Test Supabase Connection") {
            self.testSupabase()
        }
        stackView.addArrangedSubview(supabaseCard)
        
        // Backend API Test
        let backendCard = createCard(title: "Test Backend API") {
            self.testBackendAPI()
        }
        stackView.addArrangedSubview(backendCard)
        
        // OpenAI Test (if available)
        let openAICard = createCard(title: "Test OpenAI API") {
            self.testOpenAI()
        }
        stackView.addArrangedSubview(openAICard)
        
        // Fetch Properties Test
        let propertiesCard = createCard(title: "Fetch Properties") {
            self.testFetchProperties()
        }
        stackView.addArrangedSubview(propertiesCard)
    }
    
    private func createCard(title: String, action: @escaping () -> Void) -> UIView {
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
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
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
    
    @objc private func buttonTapped(_ sender: UIButton) {
        if let action = objc_getAssociatedObject(sender, "action") as? () -> Void {
            action()
        }
    }
    
    // MARK: - Test Methods
    
    private func runDiagnostics() {
        let diagnostics = AppInitializationService.shared.runDiagnostics()
        showResult(title: "System Diagnostics", content: formatDiagnostics(diagnostics))
    }
    
    private func testEnvironment() {
        let env = EnvironmentManager.shared
        let result = """
        Environment: \(env.currentEnvironment)
        Platform: \(env.currentPlatform)
        Running on Device: \(env.isRunningOnDevice)
        Base URL: \(env.apiEndpoints.baseURL)
        Supabase URL: \(env.apiEndpoints.supabaseURL)
        OpenAI URL: \(env.apiEndpoints.openAIBaseURL)
        Default Timeout: \(env.apiEndpoints.defaultTimeout)s
        """
        showResult(title: "Environment Test", content: result)
    }
    
    private func testAPIKeys() {
        let keyManager = APIKeyManager.shared
        let keys = keyManager.validateKeys()
        
        var result = "API Key Status:\n"
        for (service, hasKey) in keys {
            result += "\(service): \(hasKey ? "✅" : "❌")\n"
        }
        
        showResult(title: "API Keys Test", content: result)
    }
    
    private func testSupabase() {
        showLoading(title: "Testing Supabase...")
        
        Task {
            let isValid = await SupabaseService.shared.validateConnection()
            
            DispatchQueue.main.async {
                self.hideLoading()
                let result = isValid ? "✅ Supabase connection successful" : "❌ Supabase connection failed"
                self.showResult(title: "Supabase Test", content: result)
            }
        }
    }
    
    private func testBackendAPI() {
        showLoading(title: "Testing Backend API...")
        
        MobileAPIService.shared.performRequest<[String: Any]>(
            endpoint: "/health",
            method: .GET,
            authenticated: false
        ) { [weak self] result in
            self?.hideLoading()
            
            switch result {
            case .success(let response):
                let resultText = "✅ Backend API connection successful\n\nResponse: \(response)"
                self?.showResult(title: "Backend API Test", content: resultText)
            case .failure(let error):
                let resultText = "❌ Backend API connection failed\n\nError: \(error.localizedDescription)"
                self?.showResult(title: "Backend API Test", content: resultText)
            }
        }
    }
    
    private func testOpenAI() {
        guard APIKeyManager.shared.getOpenAIKey() != nil else {
            showResult(title: "OpenAI Test", content: "❌ OpenAI API key not available")
            return
        }
        
        showLoading(title: "Testing OpenAI...")
        
        let messages = [
            ["role": "user", "content": "Say hello in exactly 5 words."]
        ]
        
        MobileAPIService.shared.sendOpenAIRequest(messages: messages) { [weak self] result in
            self?.hideLoading()
            
            switch result {
            case .success(let response):
                let content = response.choices.first?.message.content ?? "No response"
                let resultText = "✅ OpenAI API connection successful\n\nResponse: \(content)"
                self?.showResult(title: "OpenAI Test", content: resultText)
            case .failure(let error):
                let resultText = "❌ OpenAI API connection failed\n\nError: \(error.localizedDescription)"
                self?.showResult(title: "OpenAI Test", content: resultText)
            }
        }
    }
    
    private func testFetchProperties() {
        showLoading(title: "Fetching Properties...")
        
        APIService.shared.fetchProperties { [weak self] result in
            self?.hideLoading()
            
            switch result {
            case .success(let properties):
                let resultText = "✅ Properties fetch successful\n\nFound \(properties.count) properties"
                self?.showResult(title: "Properties Test", content: resultText)
            case .failure(let error):
                let resultText = "❌ Properties fetch failed\n\nError: \(error.localizedDescription)"
                self?.showResult(title: "Properties Test", content: resultText)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDiagnostics(_ diagnostics: [String: Any]) -> String {
        var result = ""
        for (key, value) in diagnostics.sorted(by: { $0.key < $1.key }) {
            if let dict = value as? [String: Any] {
                result += "\(key):\n"
                for (subKey, subValue) in dict.sorted(by: { $0.key < $1.key }) {
                    result += "  \(subKey): \(subValue)\n"
                }
            } else {
                result += "\(key): \(value)\n"
            }
        }
        return result
    }
    
    private func showResult(title: String, content: String) {
        let alert = UIAlertController(title: title, message: content, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private var loadingAlert: UIAlertController?
    
    private func showLoading(title: String) {
        hideLoading()
        
        loadingAlert = UIAlertController(title: title, message: "Please wait...", preferredStyle: .alert)
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        loadingAlert?.setValue(spinner, forKey: "accessoryView")
        
        present(loadingAlert!, animated: true)
    }
    
    private func hideLoading() {
        loadingAlert?.dismiss(animated: true)
        loadingAlert = nil
    }
}