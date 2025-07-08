import UIKit

class RealDataTestViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let testResultsTextView = UITextView()
    private let runTestButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        runInitialTests()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Real Data Test"
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Configure title
        titleLabel.text = "RoomFinderAI Real Data Integration Test"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Configure status
        statusLabel.text = "🔄 Testing connection..."
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusLabel)
        
        // Configure test results
        testResultsTextView.isEditable = false
        testResultsTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        testResultsTextView.backgroundColor = .systemGray6
        testResultsTextView.layer.cornerRadius = 8
        testResultsTextView.text = "Running tests...\n"
        testResultsTextView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(testResultsTextView)
        
        // Configure button
        runTestButton.setTitle("Run Tests Again", for: .normal)
        runTestButton.applyPrimaryStyle()
        runTestButton.addTarget(self, action: #selector(runTestsTapped), for: .touchUpInside)
        runTestButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(runTestButton)
    }
    
    private func setupConstraints() {
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
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            testResultsTextView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            testResultsTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            testResultsTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            testResultsTextView.heightAnchor.constraint(equalToConstant: 400),
            
            runTestButton.topAnchor.constraint(equalTo: testResultsTextView.bottomAnchor, constant: 20),
            runTestButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            runTestButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            runTestButton.heightAnchor.constraint(equalToConstant: 50),
            runTestButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func runInitialTests() {
        Task {
            await runComprehensiveTests()
        }
    }
    
    @objc private func runTestsTapped() {
        testResultsTextView.text = "Running tests...\n"
        statusLabel.text = "🔄 Testing connection..."
        
        Task {
            await runComprehensiveTests()
        }
    }
    
    private func runComprehensiveTests() async {
        var results = ""
        var passedTests = 0
        var totalTests = 0
        
        func addResult(_ message: String) {
            results += "\(message)\n"
            DispatchQueue.main.async {
                self.testResultsTextView.text = results
            }
        }
        
        addResult("=" * 50)
        addResult("🧪 RoomFinderAI Real Data Integration Test")
        addResult("=" * 50)
        addResult("")
        
        // Test 1: Network Connectivity
        totalTests += 1
        addResult("🌐 Test 1: Network Connectivity")
        let hasInternet = NetworkMonitor.shared.isConnectedToInternet()
        if hasInternet {
            addResult("✅ Internet connection available")
            passedTests += 1
        } else {
            addResult("❌ No internet connection")
        }
        addResult("")
        
        // Test 2: Supabase Configuration
        totalTests += 1
        addResult("⚙️ Test 2: Supabase Configuration")
        let isConfigured = await SupabaseService.shared.validateConnection()
        if isConfigured {
            addResult("✅ Supabase service configured successfully")
            passedTests += 1
        } else {
            addResult("❌ Supabase configuration failed")
        }
        addResult("")
        
        // Test 3: API Health Check
        totalTests += 1
        addResult("🏥 Test 3: API Health Check")
        let healthStatus = await DataValidationService.shared.performHealthCheck()
        addResult("   Supabase Status: \(healthStatus.supabaseStatus)")
        addResult("   Data Quality: \(healthStatus.dataQuality)")
        addResult("   Overall Health: \(healthStatus.overallHealth)")
        if healthStatus.overallHealth == .healthy {
            addResult("✅ API health check passed")
            passedTests += 1
        } else {
            addResult("⚠️ API health check warnings detected")
        }
        addResult("")
        
        // Test 4: Real Data Fetch
        totalTests += 1
        addResult("📊 Test 4: Real Data Fetch")
        do {
            var filters = SupabaseSearchFilters()
            filters.limit = 10
            
            let startTime = PerformanceMetrics.shared.startTimer(for: "fetchListings")
            let listings = try await SupabaseService.shared.fetchListings(filters: filters)
            PerformanceMetrics.shared.endTimer(for: "fetchListings", startTime: startTime)
            
            addResult("✅ Successfully fetched \(listings.count) real listings")
            
            if !listings.isEmpty {
                let firstListing = listings[0]
                addResult("   Sample listing: \(firstListing.title)")
                addResult("   Price: $\(firstListing.price)")
                addResult("   City: \(firstListing.city)")
                addResult("   Type: \(firstListing.houseType)")
                passedTests += 1
            } else {
                addResult("⚠️ No listings found in database")
            }
        } catch {
            addResult("❌ Failed to fetch real listings: \(error)")
        }
        addResult("")
        
        // Test 5: Search Functionality
        totalTests += 1
        addResult("🔍 Test 5: Search Functionality")
        do {
            let startTime = PerformanceMetrics.shared.startTimer(for: "searchListings")
            let searchResults = try await SupabaseService.shared.searchListings(query: "apartment")
            PerformanceMetrics.shared.endTimer(for: "searchListings", startTime: startTime)
            
            addResult("✅ Search completed successfully")
            addResult("   Found \(searchResults.count) results for 'apartment'")
            passedTests += 1
        } catch {
            addResult("❌ Search functionality failed: \(error)")
        }
        addResult("")
        
        // Test 6: Data Quality Assessment
        totalTests += 1
        addResult("📈 Test 6: Data Quality Assessment")
        do {
            var filters = SupabaseSearchFilters()
            filters.limit = 20
            let listings = try await SupabaseService.shared.fetchListings(filters: filters)
            
            if !listings.isEmpty {
                let properties = listings.map { $0.toProperty() }
                let quality = DataValidationService.shared.validatePropertyData(properties)
                
                addResult("   Total properties analyzed: \(quality.totalCount)")
                addResult("   Data completeness: \(String(format: "%.1f", quality.dataCompleteness * 100))%")
                addResult("   Price realism: \(String(format: "%.1f", quality.priceRealism * 100))%")
                addResult("   Overall quality: \(String(format: "%.1f", quality.overallQuality * 100))%")
                
                if quality.overallQuality > 0.7 {
                    addResult("✅ Data quality assessment passed")
                    passedTests += 1
                } else {
                    addResult("⚠️ Data quality below threshold")
                }
            } else {
                addResult("❌ No data available for quality assessment")
            }
        } catch {
            addResult("❌ Data quality assessment failed: \(error)")
        }
        addResult("")
        
        // Test 7: API Service Integration
        totalTests += 1
        addResult("🔗 Test 7: API Service Integration")
        
        let semaphore = DispatchSemaphore(value: 0)
        var apiTestPassed = false
        
        APIService.shared.fetchProperties(page: 1, limit: 5) { result in
            switch result {
            case .success(let properties):
                addResult("✅ APIService integration working")
                addResult("   Fetched \(properties.count) properties through APIService")
                if !properties.isEmpty {
                    addResult("   Sample property: \(properties[0].title)")
                }
                apiTestPassed = true
            case .failure(let error):
                addResult("❌ APIService integration failed: \(error)")
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 10)
        
        if apiTestPassed {
            passedTests += 1
        }
        addResult("")
        
        // Performance Summary
        addResult("⚡ Performance Summary:")
        if let fetchTime = PerformanceMetrics.shared.getAverageTime(for: "fetchListings") {
            addResult("   Fetch listings: \(String(format: "%.2f", fetchTime))s")
        }
        if let searchTime = PerformanceMetrics.shared.getAverageTime(for: "searchListings") {
            addResult("   Search listings: \(String(format: "%.2f", searchTime))s")
        }
        addResult("")
        
        // Final Results
        addResult("=" * 50)
        addResult("📊 FINAL RESULTS")
        addResult("=" * 50)
        addResult("Tests Passed: \(passedTests)/\(totalTests)")
        
        let successRate = Double(passedTests) / Double(totalTests)
        let status: String
        let emoji: String
        
        if successRate >= 0.8 {
            status = "EXCELLENT - Real data integration working perfectly!"
            emoji = "🎉"
        } else if successRate >= 0.6 {
            status = "GOOD - Real data mostly working with minor issues"
            emoji = "✅"
        } else if successRate >= 0.4 {
            status = "FAIR - Some real data features working"
            emoji = "⚠️"
        } else {
            status = "POOR - Falling back to sample data"
            emoji = "❌"
        }
        
        addResult("\(emoji) Status: \(status)")
        addResult("Success Rate: \(String(format: "%.1f", successRate * 100))%")
        
        DispatchQueue.main.async {
            self.statusLabel.text = "\(emoji) \(status)"
            if successRate >= 0.6 {
                self.statusLabel.textColor = .systemGreen
            } else if successRate >= 0.4 {
                self.statusLabel.textColor = .systemOrange
            } else {
                self.statusLabel.textColor = .systemRed
            }
        }
    }
}

// MARK: - String Extension for Repeat
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}