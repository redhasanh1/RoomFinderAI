import UIKit
import Foundation

// Temporary stub class until properly added to Xcode project
class EnhancedSearchViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Enhanced Search"
        
        let label = UILabel()
        label.text = "Enhanced Search Coming Soon"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

// Full Dashboard Implementation
class DashboardViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let refreshControl = UIRefreshControl()
    
    // Header Section
    private let headerView = UIView()
    private let welcomeLabel = UILabel()
    private let balanceCard = UIView()
    private let balanceLabel = UILabel()
    private let savingsLabel = UILabel()
    
    // Stats Section
    private let statsStackView = UIStackView()
    
    // Quick Actions Section
    private let quickActionsView = UIView()
    private let quickActionsStackView = UIStackView()
    
    // Recent Activity Section
    private let recentActivityView = UIView()
    private let activityTableView = UITableView()
    
    // Chart Section
    private let chartContainerView = UIView()
    
    private var currentUser: User?
    private var userStats: [String: Any] = [:]
    private var recentActivities: [DashboardActivity] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadDashboardData()
        animateOnAppear()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.applyGradient(colors: Theme.Colors.gradientBackground, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1))
        loadDashboardData()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Dashboard"
        
        // Configure scroll view
        scrollView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshDashboard), for: .valueChanged)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        setupHeaderSection()
        setupStatsSection()
        setupQuickActionsSection()
        setupRecentActivitySection()
        setupChartSection()
    }
    
    private func setupHeaderSection() {
        headerView.applyGlassEffect(alpha: 0.9)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerView)
        
        // Welcome label
        welcomeLabel.text = "Welcome back!"
        welcomeLabel.font = Theme.Fonts.displayMedium
        welcomeLabel.textColor = Theme.Colors.textPrimary
        welcomeLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(welcomeLabel)
        
        // Balance card
        balanceCard.applyPremiumCardStyle()
        balanceCard.applyGradient(colors: Theme.Colors.gradientPrimary)
        balanceCard.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(balanceCard)
        
        balanceLabel.text = "$1,250"
        balanceLabel.font = Theme.Fonts.displayLarge
        balanceLabel.textColor = Theme.Colors.textOnPrimary
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        balanceCard.addSubview(balanceLabel)
        
        savingsLabel.text = "Total Savings"
        savingsLabel.font = Theme.Fonts.body
        savingsLabel.textColor = Theme.Colors.textOnPrimary
        savingsLabel.alpha = 0.9
        savingsLabel.translatesAutoresizingMaskIntoConstraints = false
        balanceCard.addSubview(savingsLabel)
    }
    
    private func setupStatsSection() {
        statsStackView.axis = .horizontal
        statsStackView.spacing = Theme.Spacing.md
        statsStackView.distribution = .fillEqually
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statsStackView)
        
        let stats = [
            ("Properties Viewed", "24", "eye", Theme.Colors.gradientSecondary),
            ("Favorites", "8", "heart.fill", Theme.Colors.gradientAccent),
            ("Applications", "3", "doc.text", Theme.Colors.gradientSuccess),
            ("AI Negotiations", "2", "brain.head.profile", Theme.Colors.gradientPrimary)
        ]
        
        for stat in stats {
            let statCard = createStatCard(title: stat.0, value: stat.1, iconName: stat.2, gradient: stat.3)
            statsStackView.addArrangedSubview(statCard)
        }
    }
    
    private func setupQuickActionsSection() {
        quickActionsView.applyGlassEffect(alpha: 0.8)
        quickActionsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(quickActionsView)
        
        let titleLabel = UILabel()
        titleLabel.text = "Quick Actions"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        quickActionsView.addSubview(titleLabel)
        
        quickActionsStackView.axis = .horizontal
        quickActionsStackView.spacing = Theme.Spacing.md
        quickActionsStackView.distribution = .fillEqually
        quickActionsStackView.translatesAutoresizingMaskIntoConstraints = false
        quickActionsView.addSubview(quickActionsStackView)
        
        let actions = [
            ("Search Properties", "magnifyingglass", #selector(searchTapped)),
            ("Start AI Chat", "brain.head.profile", #selector(aiChatTapped)),
            ("View Favorites", "heart.fill", #selector(favoritesTapped)),
            ("Profile", "person.circle", #selector(profileTapped))
        ]
        
        for action in actions {
            let button = createActionButton(title: action.0, iconName: action.1, action: action.2)
            quickActionsStackView.addArrangedSubview(button)
        }
    }
    
    private func setupRecentActivitySection() {
        recentActivityView.applyPremiumCardStyle()
        recentActivityView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(recentActivityView)
        
        let titleLabel = UILabel()
        titleLabel.text = "Recent Activity"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        recentActivityView.addSubview(titleLabel)
        
        activityTableView.delegate = self
        activityTableView.dataSource = self
        activityTableView.register(ActivityTableViewCell.self, forCellReuseIdentifier: "ActivityCell")
        activityTableView.backgroundColor = .clear
        activityTableView.separatorStyle = .none
        activityTableView.isScrollEnabled = false
        activityTableView.translatesAutoresizingMaskIntoConstraints = false
        recentActivityView.addSubview(activityTableView)
    }
    
    private func setupChartSection() {
        chartContainerView.applyGlassEffect(alpha: 0.8)
        chartContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(chartContainerView)
        
        let titleLabel = UILabel()
        titleLabel.text = "Search Trends"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        chartContainerView.addSubview(titleLabel)
        
        // Add a simple chart placeholder for now
        let chartPlaceholder = UIView()
        chartPlaceholder.backgroundColor = Theme.Colors.surfaceSecondary
        chartPlaceholder.layer.cornerRadius = Theme.CornerRadius.medium
        chartPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        chartContainerView.addSubview(chartPlaceholder)
        
        let chartLabel = UILabel()
        chartLabel.text = "📊 Search activity over time"
        chartLabel.font = Theme.Fonts.body
        chartLabel.textColor = Theme.Colors.textSecondary
        chartLabel.textAlignment = .center
        chartLabel.translatesAutoresizingMaskIntoConstraints = false
        chartPlaceholder.addSubview(chartLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: chartContainerView.topAnchor, constant: Theme.Spacing.lg),
            titleLabel.leadingAnchor.constraint(equalTo: chartContainerView.leadingAnchor, constant: Theme.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: chartContainerView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            chartPlaceholder.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            chartPlaceholder.leadingAnchor.constraint(equalTo: chartContainerView.leadingAnchor, constant: Theme.Spacing.lg),
            chartPlaceholder.trailingAnchor.constraint(equalTo: chartContainerView.trailingAnchor, constant: -Theme.Spacing.lg),
            chartPlaceholder.heightAnchor.constraint(equalToConstant: 150),
            chartPlaceholder.bottomAnchor.constraint(equalTo: chartContainerView.bottomAnchor, constant: -Theme.Spacing.lg),
            
            chartLabel.centerXAnchor.constraint(equalTo: chartPlaceholder.centerXAnchor),
            chartLabel.centerYAnchor.constraint(equalTo: chartPlaceholder.centerYAnchor)
        ])
    }
    
    private func createStatCard(title: String, value: String, iconName: String, gradient: [UIColor]) -> UIView {
        let card = UIView()
        card.applyPremiumCardStyle()
        card.applyGradient(colors: gradient)
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = Theme.Colors.textOnPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconView)
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = Theme.Fonts.title1
        valueLabel.textColor = Theme.Colors.textOnPrimary
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(valueLabel)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.Fonts.caption1
        titleLabel.textColor = Theme.Colors.textOnPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 120),
            
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: Theme.Spacing.md),
            iconView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            valueLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: Theme.Spacing.sm),
            valueLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Theme.Spacing.xs),
            valueLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.xs),
            
            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: Theme.Spacing.xxs),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Theme.Spacing.xs),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.xs),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -Theme.Spacing.sm)
        ])
        
        return card
    }
    
    private func createActionButton(title: String, iconName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: iconName), for: .normal)
        button.applyGlassStyle()
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.titleLabel?.font = Theme.Fonts.caption1
        button.imageView?.contentMode = .scaleAspectFit
        button.contentVerticalAlignment = .center
        button.contentHorizontalAlignment = .center
        
        button.titleEdgeInsets = UIEdgeInsets(top: 35, left: -20, bottom: 0, right: 20)
        button.imageEdgeInsets = UIEdgeInsets(top: -15, left: 0, bottom: 15, right: 0)
        
        button.heightAnchor.constraint(equalToConstant: 80).isActive = true
        
        return button
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
            
            // Header
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Spacing.lg),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            headerView.heightAnchor.constraint(equalToConstant: 200),
            
            welcomeLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: Theme.Spacing.lg),
            welcomeLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: Theme.Spacing.lg),
            welcomeLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            balanceCard.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: Theme.Spacing.lg),
            balanceCard.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: Theme.Spacing.lg),
            balanceCard.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -Theme.Spacing.lg),
            balanceCard.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -Theme.Spacing.lg),
            
            savingsLabel.topAnchor.constraint(equalTo: balanceCard.topAnchor, constant: Theme.Spacing.md),
            savingsLabel.leadingAnchor.constraint(equalTo: balanceCard.leadingAnchor, constant: Theme.Spacing.lg),
            
            balanceLabel.topAnchor.constraint(equalTo: savingsLabel.bottomAnchor, constant: Theme.Spacing.xs),
            balanceLabel.leadingAnchor.constraint(equalTo: balanceCard.leadingAnchor, constant: Theme.Spacing.lg),
            
            // Stats
            statsStackView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: Theme.Spacing.xl),
            statsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            statsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            // Quick Actions
            quickActionsView.topAnchor.constraint(equalTo: statsStackView.bottomAnchor, constant: Theme.Spacing.xl),
            quickActionsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            quickActionsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            quickActionsView.heightAnchor.constraint(equalToConstant: 150),
            
            // Recent Activity
            recentActivityView.topAnchor.constraint(equalTo: quickActionsView.bottomAnchor, constant: Theme.Spacing.xl),
            recentActivityView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            recentActivityView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            recentActivityView.heightAnchor.constraint(equalToConstant: 300),
            
            // Chart
            chartContainerView.topAnchor.constraint(equalTo: recentActivityView.bottomAnchor, constant: Theme.Spacing.xl),
            chartContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            chartContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            chartContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Spacing.xl)
        ])
        
        // Quick Actions internal constraints
        guard let firstAction = quickActionsStackView.arrangedSubviews.first else { return }
        
        NSLayoutConstraint.activate([
            quickActionsStackView.topAnchor.constraint(equalTo: quickActionsView.topAnchor, constant: 50),
            quickActionsStackView.leadingAnchor.constraint(equalTo: quickActionsView.leadingAnchor, constant: Theme.Spacing.lg),
            quickActionsStackView.trailingAnchor.constraint(equalTo: quickActionsView.trailingAnchor, constant: -Theme.Spacing.lg),
            quickActionsStackView.bottomAnchor.constraint(equalTo: quickActionsView.bottomAnchor, constant: -Theme.Spacing.lg)
        ])
        
        // Activity table constraints
        NSLayoutConstraint.activate([
            activityTableView.topAnchor.constraint(equalTo: recentActivityView.topAnchor, constant: 50),
            activityTableView.leadingAnchor.constraint(equalTo: recentActivityView.leadingAnchor),
            activityTableView.trailingAnchor.constraint(equalTo: recentActivityView.trailingAnchor),
            activityTableView.bottomAnchor.constraint(equalTo: recentActivityView.bottomAnchor, constant: -Theme.Spacing.lg)
        ])
    }
    
    private func loadDashboardData() {
        // Load user data
        if AuthManager.shared.isLoggedIn {
            APIService.shared.getCurrentUser { [weak self] result in
                switch result {
                case .success(let user):
                    self?.currentUser = user
                    self?.updateUserInterface(user: user)
                case .failure(let error):
                    print("Error loading user: \(error)")
                }
            }
        }
        
        loadRecentActivity()
        loadUserStats()
    }
    
    private func loadRecentActivity() {
        // Sample activity data - replace with real API calls
        recentActivities = [
            DashboardActivity(title: "Viewed Downtown Apartment", time: "2 hours ago", icon: "eye", type: .view),
            DashboardActivity(title: "Saved Property to Favorites", time: "4 hours ago", icon: "heart.fill", type: .favorite),
            DashboardActivity(title: "Started AI Negotiation", time: "1 day ago", icon: "brain.head.profile", type: .negotiation),
            DashboardActivity(title: "Applied to Property", time: "2 days ago", icon: "doc.text", type: .application),
            DashboardActivity(title: "Updated Search Filters", time: "3 days ago", icon: "slider.horizontal.3", type: .search)
        ]
        
        activityTableView.reloadData()
    }
    
    private func loadUserStats() {
        // Load real stats from API
        userStats = [
            "propertiesViewed": 24,
            "favorites": 8,
            "applications": 3,
            "aiNegotiations": 2,
            "totalSavings": 1250
        ]
        
        updateStatsUI()
    }
    
    private func updateUserInterface(user: User) {
        welcomeLabel.text = "Welcome back, \(user.firstName)!"
    }
    
    private func updateStatsUI() {
        if let savings = userStats["totalSavings"] as? Int {
            balanceLabel.text = "$\(savings)"
        }
    }
    
    private func animateOnAppear() {
        let views = [headerView, statsStackView, quickActionsView, recentActivityView, chartContainerView]
        
        for (index, view) in views.enumerated() {
            view.transform = CGAffineTransform(translationX: 0, y: 50)
            view.alpha = 0
            
            UIView.animate(withDuration: Theme.Animation.slow,
                           delay: Double(index) * 0.1,
                           usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 0) {
                view.transform = .identity
                view.alpha = 1
            }
        }
    }
    
    @objc private func refreshDashboard() {
        loadDashboardData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.refreshControl.endRefreshing()
        }
    }
    
    @objc private func searchTapped() {
        tabBarController?.selectedIndex = 1
    }
    
    @objc private func aiChatTapped() {
        let aiVC = AINegotiatorViewController()
        navigationController?.pushViewController(aiVC, animated: true)
    }
    
    @objc private func favoritesTapped() {
        tabBarController?.selectedIndex = 3
    }
    
    @objc private func profileTapped() {
        tabBarController?.selectedIndex = 4
    }
}

class AINegotiatorViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Hero Section
    private let heroView = UIView()
    private let heroTitleLabel = UILabel()
    private let heroSubtitleLabel = UILabel()
    private let startNegotiationButton = UIButton(type: .system)
    
    // Features Section
    private let featuresStackView = UIStackView()
    
    // How It Works Section
    private let howItWorksView = UIView()
    private let stepsStackView = UIStackView()
    
    // Chat Demo Section
    private let chatDemoView = UIView()
    private let chatTableView = UITableView()
    private let chatInputView = UIView()
    private let chatTextField = UITextField()
    private let sendButton = UIButton(type: .system)
    
    // Stats Section
    private let statsView = UIView()
    
    private var chatMessages: [ChatMessage] = []
    private var isNegotiationActive = false
    private var currentPropertyId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadInitialData()
        animateOnAppear()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.applyGradient(colors: Theme.Colors.gradientBackground, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1))
    }
    
    private func setupUI() {
        title = "AI Negotiator"
        view.backgroundColor = .systemBackground
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        setupHeroSection()
        setupFeaturesSection()
        setupHowItWorksSection()
        setupChatDemoSection()
        setupStatsSection()
    }
    
    private func setupHeroSection() {
        heroView.applyGlassEffect(alpha: 0.9)
        heroView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(heroView)
        
        heroTitleLabel.text = "🤖 AI-Powered Rent Negotiation"
        heroTitleLabel.font = Theme.Fonts.displayMedium
        heroTitleLabel.textColor = Theme.Colors.textPrimary
        heroTitleLabel.textAlignment = .center
        heroTitleLabel.numberOfLines = 0
        heroTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(heroTitleLabel)
        
        heroSubtitleLabel.text = "Let our AI negotiate the best price for your dream property. Save up to 15% on rent with smart, data-driven negotiations."
        heroSubtitleLabel.font = Theme.Fonts.body
        heroSubtitleLabel.textColor = Theme.Colors.textSecondary
        heroSubtitleLabel.textAlignment = .center
        heroSubtitleLabel.numberOfLines = 0
        heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(heroSubtitleLabel)
        
        startNegotiationButton.setTitle("Start AI Negotiation", for: .normal)
        startNegotiationButton.applyMagneticStyle()
        startNegotiationButton.addTarget(self, action: #selector(startNegotiationTapped), for: .touchUpInside)
        startNegotiationButton.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(startNegotiationButton)
    }
    
    private func setupFeaturesSection() {
        featuresStackView.axis = .vertical
        featuresStackView.spacing = Theme.Spacing.lg
        featuresStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(featuresStackView)
        
        let features = [
            ("AI-Powered Analysis", "Get data-driven insights on property values and market trends", "chart.bar.xaxis"),
            ("Smart Negotiation", "AI crafts personalized negotiation strategies based on your preferences", "brain.head.profile"),
            ("Real-Time Messaging", "Chat directly with property owners through our secure platform", "message.badge"),
            ("Success Tracking", "Monitor your negotiation progress and savings achieved", "dollarsign.circle")
        ]
        
        for feature in features {
            let featureCard = createFeatureCard(title: feature.0, description: feature.1, iconName: feature.2)
            featuresStackView.addArrangedSubview(featureCard)
        }
    }
    
    private func setupHowItWorksSection() {
        howItWorksView.applyGlassEffect(alpha: 0.8)
        howItWorksView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(howItWorksView)
        
        let titleLabel = UILabel()
        titleLabel.text = "How AI Negotiation Works"
        titleLabel.font = Theme.Fonts.title1
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        howItWorksView.addSubview(titleLabel)
        
        stepsStackView.axis = .vertical
        stepsStackView.spacing = Theme.Spacing.lg
        stepsStackView.translatesAutoresizingMaskIntoConstraints = false
        howItWorksView.addSubview(stepsStackView)
        
        let steps = [
            ("1", "Share Property Details", "Tell us about the property you're interested in"),
            ("2", "AI Analysis", "Our AI analyzes market data and property value"),
            ("3", "Negotiation Strategy", "AI creates a personalized negotiation approach"),
            ("4", "Automated Outreach", "AI communicates with the property owner"),
            ("5", "Success!", "You get the best possible deal")
        ]
        
        for step in steps {
            let stepView = createStepView(number: step.0, title: step.1, description: step.2)
            stepsStackView.addArrangedSubview(stepView)
        }
    }
    
    private func setupChatDemoSection() {
        chatDemoView.applyPremiumCardStyle()
        chatDemoView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(chatDemoView)
        
        let titleLabel = UILabel()
        titleLabel.text = "💬 Try AI Negotiation"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        chatDemoView.addSubview(titleLabel)
        
        // Chat table view
        chatTableView.delegate = self
        chatTableView.dataSource = self
        chatTableView.register(ChatMessageCell.self, forCellReuseIdentifier: "ChatMessageCell")
        chatTableView.backgroundColor = .clear
        chatTableView.separatorStyle = .none
        chatTableView.translatesAutoresizingMaskIntoConstraints = false
        chatDemoView.addSubview(chatTableView)
        
        // Chat input
        setupChatInput()
    }
    
    private func setupChatInput() {
        chatInputView.backgroundColor = Theme.Colors.surfaceSecondary
        chatInputView.layer.cornerRadius = Theme.CornerRadius.medium
        chatInputView.translatesAutoresizingMaskIntoConstraints = false
        chatDemoView.addSubview(chatInputView)
        
        chatTextField.placeholder = "Type your message..."
        chatTextField.borderStyle = .none
        chatTextField.font = Theme.Fonts.body
        chatTextField.delegate = self
        chatTextField.translatesAutoresizingMaskIntoConstraints = false
        chatInputView.addSubview(chatTextField)
        
        sendButton.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        sendButton.tintColor = Theme.Colors.primary
        sendButton.addTarget(self, action: #selector(sendMessageTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        chatInputView.addSubview(sendButton)
    }
    
    private func setupStatsSection() {
        statsView.applyGlassEffect(alpha: 0.8)
        statsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statsView)
        
        let titleLabel = UILabel()
        titleLabel.text = "💰 Success Stories"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        statsView.addSubview(titleLabel)
        
        let statsStackView = UIStackView()
        statsStackView.axis = .horizontal
        statsStackView.spacing = Theme.Spacing.md
        statsStackView.distribution = .fillEqually
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        statsView.addSubview(statsStackView)
        
        let successStats = [
            ("Average Savings", "$485/month", Theme.Colors.gradientSuccess),
            ("Success Rate", "87%", Theme.Colors.gradientPrimary),
            ("Happy Tenants", "2,847", Theme.Colors.gradientAccent)
        ]
        
        for stat in successStats {
            let statCard = createStatCard(title: stat.0, value: stat.1, gradient: stat.2)
            statsStackView.addArrangedSubview(statCard)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: statsView.topAnchor, constant: Theme.Spacing.lg),
            titleLabel.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: Theme.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            statsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            statsStackView.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: Theme.Spacing.lg),
            statsStackView.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -Theme.Spacing.lg),
            statsStackView.bottomAnchor.constraint(equalTo: statsView.bottomAnchor, constant: -Theme.Spacing.lg),
            statsStackView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    private func createFeatureCard(title: String, description: String, iconName: String) -> UIView {
        let card = UIView()
        card.applyPremiumCardStyle()
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = Theme.Colors.primary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconView)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.Fonts.headline
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = Theme.Fonts.body
        descriptionLabel.textColor = Theme.Colors.textSecondary
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: Theme.Spacing.lg),
            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Theme.Spacing.lg),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: Theme.Spacing.lg),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Theme.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.lg),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.sm),
            descriptionLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Theme.Spacing.md),
            descriptionLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.lg),
            descriptionLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Theme.Spacing.lg)
        ])
        
        return card
    }
    
    private func createStepView(number: String, title: String, description: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let numberView = UIView()
        numberView.backgroundColor = Theme.Colors.primary
        numberView.layer.cornerRadius = 25
        numberView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(numberView)
        
        let numberLabel = UILabel()
        numberLabel.text = number
        numberLabel.font = Theme.Fonts.headline
        numberLabel.textColor = Theme.Colors.textOnPrimary
        numberLabel.textAlignment = .center
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberView.addSubview(numberLabel)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.Fonts.headline
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = Theme.Fonts.callout
        descriptionLabel.textColor = Theme.Colors.textSecondary
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            numberView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            numberView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            numberView.widthAnchor.constraint(equalToConstant: 50),
            numberView.heightAnchor.constraint(equalToConstant: 50),
            
            numberLabel.centerXAnchor.constraint(equalTo: numberView.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: numberView.centerYAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: numberView.trailingAnchor, constant: Theme.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xs),
            descriptionLabel.leadingAnchor.constraint(equalTo: numberView.trailingAnchor, constant: Theme.Spacing.lg),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 70)
        ])
        
        return container
    }
    
    private func createStatCard(title: String, value: String, gradient: [UIColor]) -> UIView {
        let card = UIView()
        card.applyGradient(colors: gradient)
        card.layer.cornerRadius = Theme.CornerRadius.medium
        card.applyShadow(Theme.Shadow.medium)
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = Theme.Fonts.title1
        valueLabel.textColor = Theme.Colors.textOnPrimary
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(valueLabel)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.Fonts.caption1
        titleLabel.textColor = Theme.Colors.textOnPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            valueLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: -10),
            
            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: Theme.Spacing.xs),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Theme.Spacing.sm),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.sm)
        ])
        
        return card
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
            
            // Hero Section
            heroView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Spacing.lg),
            heroView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            heroView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            heroView.heightAnchor.constraint(equalToConstant: 220),
            
            heroTitleLabel.topAnchor.constraint(equalTo: heroView.topAnchor, constant: Theme.Spacing.xl),
            heroTitleLabel.leadingAnchor.constraint(equalTo: heroView.leadingAnchor, constant: Theme.Spacing.lg),
            heroTitleLabel.trailingAnchor.constraint(equalTo: heroView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            heroSubtitleLabel.topAnchor.constraint(equalTo: heroTitleLabel.bottomAnchor, constant: Theme.Spacing.md),
            heroSubtitleLabel.leadingAnchor.constraint(equalTo: heroView.leadingAnchor, constant: Theme.Spacing.lg),
            heroSubtitleLabel.trailingAnchor.constraint(equalTo: heroView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            startNegotiationButton.topAnchor.constraint(equalTo: heroSubtitleLabel.bottomAnchor, constant: Theme.Spacing.xl),
            startNegotiationButton.centerXAnchor.constraint(equalTo: heroView.centerXAnchor),
            startNegotiationButton.widthAnchor.constraint(equalToConstant: 240),
            startNegotiationButton.heightAnchor.constraint(equalToConstant: Theme.Spacing.buttonHeight),
            
            // Features Section
            featuresStackView.topAnchor.constraint(equalTo: heroView.bottomAnchor, constant: Theme.Spacing.sectionSpacing),
            featuresStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            featuresStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            // How It Works Section
            howItWorksView.topAnchor.constraint(equalTo: featuresStackView.bottomAnchor, constant: Theme.Spacing.sectionSpacing),
            howItWorksView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            howItWorksView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            howItWorksView.heightAnchor.constraint(greaterThanOrEqualToConstant: 450),
            
            // Chat Demo Section
            chatDemoView.topAnchor.constraint(equalTo: howItWorksView.bottomAnchor, constant: Theme.Spacing.sectionSpacing),
            chatDemoView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            chatDemoView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            chatDemoView.heightAnchor.constraint(equalToConstant: 400),
            
            // Stats Section
            statsView.topAnchor.constraint(equalTo: chatDemoView.bottomAnchor, constant: Theme.Spacing.sectionSpacing),
            statsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            statsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            statsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Spacing.xl),
            statsView.heightAnchor.constraint(equalToConstant: 180)
        ])
        
        // How It Works internal constraints
        guard let titleLabel = howItWorksView.subviews.first(where: { $0 is UILabel }) as? UILabel else { return }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: howItWorksView.topAnchor, constant: Theme.Spacing.xl),
            titleLabel.leadingAnchor.constraint(equalTo: howItWorksView.leadingAnchor, constant: Theme.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: howItWorksView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            stepsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xl),
            stepsStackView.leadingAnchor.constraint(equalTo: howItWorksView.leadingAnchor, constant: Theme.Spacing.lg),
            stepsStackView.trailingAnchor.constraint(equalTo: howItWorksView.trailingAnchor, constant: -Theme.Spacing.lg),
            stepsStackView.bottomAnchor.constraint(equalTo: howItWorksView.bottomAnchor, constant: -Theme.Spacing.xl)
        ])
        
        // Chat Demo internal constraints
        guard let chatTitleLabel = chatDemoView.subviews.first(where: { $0 is UILabel }) as? UILabel else { return }
        
        NSLayoutConstraint.activate([
            chatTitleLabel.topAnchor.constraint(equalTo: chatDemoView.topAnchor, constant: Theme.Spacing.lg),
            chatTitleLabel.leadingAnchor.constraint(equalTo: chatDemoView.leadingAnchor, constant: Theme.Spacing.lg),
            chatTitleLabel.trailingAnchor.constraint(equalTo: chatDemoView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            chatTableView.topAnchor.constraint(equalTo: chatTitleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            chatTableView.leadingAnchor.constraint(equalTo: chatDemoView.leadingAnchor, constant: Theme.Spacing.lg),
            chatTableView.trailingAnchor.constraint(equalTo: chatDemoView.trailingAnchor, constant: -Theme.Spacing.lg),
            chatTableView.bottomAnchor.constraint(equalTo: chatInputView.topAnchor, constant: -Theme.Spacing.md),
            
            chatInputView.leadingAnchor.constraint(equalTo: chatDemoView.leadingAnchor, constant: Theme.Spacing.lg),
            chatInputView.trailingAnchor.constraint(equalTo: chatDemoView.trailingAnchor, constant: -Theme.Spacing.lg),
            chatInputView.bottomAnchor.constraint(equalTo: chatDemoView.bottomAnchor, constant: -Theme.Spacing.lg),
            chatInputView.heightAnchor.constraint(equalToConstant: 50),
            
            chatTextField.leadingAnchor.constraint(equalTo: chatInputView.leadingAnchor, constant: Theme.Spacing.md),
            chatTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -Theme.Spacing.sm),
            chatTextField.centerYAnchor.constraint(equalTo: chatInputView.centerYAnchor),
            
            sendButton.trailingAnchor.constraint(equalTo: chatInputView.trailingAnchor, constant: -Theme.Spacing.md),
            sendButton.centerYAnchor.constraint(equalTo: chatInputView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 30),
            sendButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func loadInitialData() {
        // Load demo chat messages
        chatMessages = [
            ChatMessage(id: "1", conversationId: "demo", senderId: "ai", receiverId: "user", content: "Hello! I'm your AI negotiation assistant. I can help you get the best deal on any property.", messageType: "text", timestamp: "2024-01-01T10:00:00Z", isRead: true, senderName: "AI Assistant", propertyId: nil),
            ChatMessage(id: "2", conversationId: "demo", senderId: "user", receiverId: "ai", content: "I'm interested in a downtown apartment. Can you help me negotiate the price?", messageType: "text", timestamp: "2024-01-01T10:01:00Z", isRead: true, senderName: "You", propertyId: nil),
            ChatMessage(id: "3", conversationId: "demo", senderId: "ai", receiverId: "user", content: "Absolutely! I've analyzed similar properties in that area. Based on market data, I can help you negotiate 10-15% below asking price. What's your target budget?", messageType: "text", timestamp: "2024-01-01T10:02:00Z", isRead: true, senderName: "AI Assistant", propertyId: nil)
        ]
        
        chatTableView.reloadData()
        scrollToBottom()
    }
    
    private func animateOnAppear() {
        let views = [heroView, featuresStackView, howItWorksView, chatDemoView, statsView]
        
        for (index, view) in views.enumerated() {
            view.transform = CGAffineTransform(translationX: 0, y: 50)
            view.alpha = 0
            
            UIView.animate(withDuration: Theme.Animation.slow,
                           delay: Double(index) * 0.15,
                           usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 0) {
                view.transform = .identity
                view.alpha = 1
            }
        }
    }
    
    private func scrollToBottom() {
        guard chatMessages.count > 0 else { return }
        
        let indexPath = IndexPath(row: chatMessages.count - 1, section: 0)
        chatTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    @objc private func startNegotiationTapped() {
        let alert = UIAlertController(
            title: "Start AI Negotiation",
            message: "This will connect you with our AI system for property negotiation. Choose a property to get started!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Choose Property", style: .default) { _ in
            // Navigate to property selection
            self.tabBarController?.selectedIndex = 1
        })
        
        alert.addAction(UIAlertAction(title: "Demo Mode", style: .default) { _ in
            self.startDemoNegotiation()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func sendMessageTapped() {
        guard let message = chatTextField.text, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        sendMessage(message)
        chatTextField.text = ""
    }
    
    private func startDemoNegotiation() {
        isNegotiationActive = true
        currentPropertyId = "demo_property"
        
        let welcomeMessage = ChatMessage(
            id: UUID().uuidString,
            conversationId: "demo",
            senderId: "ai",
            receiverId: "user",
            content: "Great! I'm now in negotiation mode. I'll help you negotiate for the downtown apartment. The listing price is $2,800/month. Based on market analysis, I recommend starting with an offer of $2,400. Shall I proceed?",
            messageType: "text",
            timestamp: Date().ISO8601String,
            isRead: true,
            senderName: "AI Assistant",
            propertyId: currentPropertyId
        )
        
        chatMessages.append(welcomeMessage)
        chatTableView.reloadData()
        scrollToBottom()
    }
    
    private func sendMessage(_ content: String) {
        // User message
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            conversationId: "demo",
            senderId: "user",
            receiverId: "ai",
            content: content,
            messageType: "text",
            timestamp: Date().ISO8601String,
            isRead: true,
            senderName: "You",
            propertyId: currentPropertyId
        )
        
        chatMessages.append(userMessage)
        chatTableView.reloadData()
        scrollToBottom()
        
        // Simulate AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.generateAIResponse(to: content)
        }
    }
    
    private func generateAIResponse(to userMessage: String) {
        let responses = [
            "I understand your concern. Based on market analysis, that's a reasonable approach. Let me craft a professional message to the landlord.",
            "Excellent! I'll incorporate that into our negotiation strategy. Properties in this area typically have 12% room for negotiation.",
            "I've successfully negotiated similar deals. The key is presenting market data and your strong rental history. Shall I proceed?",
            "Perfect! I'm now contacting the property owner with our offer. I'll present it professionally with supporting market data.",
            "Great news! The AI analysis shows this property has been on the market for 45 days, which strengthens our negotiating position."
        ]
        
        let aiMessage = ChatMessage(
            id: UUID().uuidString,
            conversationId: "demo",
            senderId: "ai",
            receiverId: "user",
            content: responses.randomElement() ?? "I'm processing your request and will provide a detailed response shortly.",
            messageType: "text",
            timestamp: Date().ISO8601String,
            isRead: true,
            senderName: "AI Assistant",
            propertyId: currentPropertyId
        )
        
        chatMessages.append(aiMessage)
        chatTableView.reloadData()
        scrollToBottom()
    }
}

class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
        setupTabBarAppearance()
    }
    
    private func setupViewControllers() {
        // Core tabs matching website structure
        let dashboardVC = createNavController(
            viewController: DashboardViewController(),
            title: "Dashboard",
            imageName: "chart.bar.xaxis"
        )
        
        let browseVC = createNavController(
            viewController: EnhancedSearchViewController(),
            title: "Browse",
            imageName: "magnifyingglass"
        )
        
        let aiVC = createNavController(
            viewController: AINegotiatorViewController(),
            title: "AI Negotiate",
            imageName: "brain.head.profile"
        )
        
        let favoritesVC = createNavController(
            viewController: FavoritesViewController(),
            title: "Favorites",
            imageName: "heart.fill"
        )
        
        let profileVC = createNavController(
            viewController: ProfileViewController(),
            title: "More",
            imageName: "ellipsis"
        )
        
        viewControllers = [dashboardVC, browseVC, aiVC, favoritesVC, profileVC]
        
        // Set default selected tab
        selectedIndex = 0
    }
    
    private func createNavController(viewController: UIViewController, title: String, imageName: String) -> UINavigationController {
        let navController = UINavigationController(rootViewController: viewController)
        navController.tabBarItem.title = title
        navController.tabBarItem.image = UIImage(systemName: imageName)
        navController.navigationBar.prefersLargeTitles = true
        viewController.navigationItem.title = title
        return navController
    }
    
    private func setupTabBarAppearance() {
        // Premium glass morphism tab bar design
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        
        // Glass effect background
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        
        // Normal state
        appearance.stackedLayoutAppearance.normal.iconColor = Theme.Colors.textSecondary
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: Theme.Colors.textSecondary,
            .font: Theme.Fonts.caption1
        ]
        
        // Selected state
        appearance.stackedLayoutAppearance.selected.iconColor = Theme.Colors.primary
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: Theme.Colors.primary,
            .font: Theme.Fonts.caption1
        ]
        
        // Apply blur effect to tab bar
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        tabBar.insertSubview(blurView, at: 0)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: tabBar.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: tabBar.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor)
        ])
        
        // Add subtle border
        tabBar.layer.borderWidth = 1
        tabBar.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        
        // Add subtle shadow
        tabBar.layer.shadowColor = UIColor.black.cgColor
        tabBar.layer.shadowOpacity = 0.1
        tabBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        tabBar.layer.shadowRadius = 8
        
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        
        tabBar.tintColor = Theme.Colors.primary
        tabBar.unselectedItemTintColor = Theme.Colors.textSecondary
    }
}

// MARK: - Dashboard Activity Model
struct DashboardActivity {
    let title: String
    let time: String
    let icon: String
    let type: ActivityType
    
    enum ActivityType {
        case view, favorite, negotiation, application, search
    }
}

// MARK: - Activity Table View Cell
class ActivityTableViewCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let containerView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        containerView.backgroundColor = Theme.Colors.surfaceSecondary
        containerView.layer.cornerRadius = Theme.CornerRadius.medium
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Theme.Colors.primary
        iconView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconView)
        
        titleLabel.font = Theme.Fonts.body
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        timeLabel.font = Theme.Fonts.caption1
        timeLabel.textColor = Theme.Colors.textSecondary
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Spacing.xs),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Spacing.xs),
            containerView.heightAnchor.constraint(equalToConstant: 60),
            
            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Theme.Spacing.md),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Theme.Spacing.sm),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Theme.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -Theme.Spacing.sm),
            
            timeLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Theme.Spacing.md),
            timeLabel.widthAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    func configure(with activity: DashboardActivity) {
        iconView.image = UIImage(systemName: activity.icon)
        titleLabel.text = activity.title
        timeLabel.text = activity.time
    }
}

// MARK: - Dashboard Table View DataSource & Delegate
extension DashboardViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recentActivities.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell", for: indexPath) as! ActivityTableViewCell
        cell.configure(with: recentActivities[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let activity = recentActivities[indexPath.row]
        
        // Navigate based on activity type
        switch activity.type {
        case .view, .search:
            tabBarController?.selectedIndex = 1 // Browse
        case .favorite:
            tabBarController?.selectedIndex = 3 // Favorites
        case .negotiation:
            let aiVC = AINegotiatorViewController()
            navigationController?.pushViewController(aiVC, animated: true)
        case .application:
            // Show application details
            break
        }
    }
}

// MARK: - Date Extension
extension Date {
    var ISO8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

// MARK: - AI Negotiator Table View Extensions
extension AINegotiatorViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chatMessages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatMessageCell", for: indexPath) as! ChatMessageCell
        cell.configure(with: chatMessages[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

// MARK: - AI Negotiator Text Field Delegate
extension AINegotiatorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessageTapped()
        return true
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        sendButton.isEnabled = !(textField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        sendButton.alpha = sendButton.isEnabled ? 1.0 : 0.5
    }
}