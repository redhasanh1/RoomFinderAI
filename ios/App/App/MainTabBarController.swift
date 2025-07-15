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

