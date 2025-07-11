import UIKit

class DashboardViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let headerView = UIView()
    private let welcomeLabel = UILabel()
    private let statsContainerView = UIView()
    private let activityContainerView = UIView()
    private let quickActionsView = UIView()
    private let refreshControl = UIRefreshControl()
    
    private var currentUser: User?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadDashboardData()
        animateOnAppear()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Apply background gradient
        view.applyGradient(colors: Theme.Colors.gradientBackground, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1))
        refreshDashboard()
    }
    
    private func setupUI() {
        title = "Dashboard"
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshDashboard), for: .valueChanged)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Configure header
        setupHeaderView()
        
        // Configure stats section
        setupStatsSection()
        
        // Configure activity section
        setupActivitySection()
        
        // Configure quick actions
        setupQuickActionsSection()
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
            
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Spacing.lg),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            statsContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: Theme.Spacing.xl),
            statsContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            statsContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            activityContainerView.topAnchor.constraint(equalTo: statsContainerView.bottomAnchor, constant: Theme.Spacing.xl),
            activityContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            activityContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            quickActionsView.topAnchor.constraint(equalTo: activityContainerView.bottomAnchor, constant: Theme.Spacing.xl),
            quickActionsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            quickActionsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            quickActionsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Spacing.xl)
        ])
    }
    
    private func setupHeaderView() {
        headerView.applyGlassEffect(alpha: 0.9)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerView)
        
        welcomeLabel.text = "Welcome back!"
        welcomeLabel.font = Theme.Fonts.displayMedium
        welcomeLabel.textColor = Theme.Colors.textPrimary
        welcomeLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(welcomeLabel)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Here's your property search overview"
        subtitleLabel.font = Theme.Fonts.body
        subtitleLabel.textColor = Theme.Colors.textSecondary
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            headerView.heightAnchor.constraint(equalToConstant: 120),
            
            welcomeLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: Theme.Spacing.lg),
            welcomeLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: Theme.Spacing.lg),
            welcomeLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            subtitleLabel.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: Theme.Spacing.sm),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: Theme.Spacing.lg),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -Theme.Spacing.lg)
        ])
    }
    
    private func setupStatsSection() {
        statsContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statsContainerView)
        
        let titleLabel = UILabel()
        titleLabel.text = "Your Activity"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.addSubview(titleLabel)
        
        let statsStackView = UIStackView()
        statsStackView.axis = .horizontal
        statsStackView.spacing = Theme.Spacing.md
        statsStackView.distribution = .fillEqually
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.addSubview(statsStackView)
        
        let stats = [
            ("Properties Viewed", "24", "eye", Theme.Colors.gradientPrimary),
            ("Favorites", "8", "heart.fill", Theme.Colors.gradientSecondary),
            ("Applications", "3", "doc.text", Theme.Colors.gradientAccent),
            ("Savings", "$420", "dollarsign.circle", Theme.Colors.gradientSuccess)
        ]
        
        for stat in stats {
            let statCard = createStatCard(title: stat.0, value: stat.1, iconName: stat.2, gradient: stat.3)
            statsStackView.addArrangedSubview(statCard)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: statsContainerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor),
            
            statsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            statsStackView.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor),
            statsStackView.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor),
            statsStackView.heightAnchor.constraint(equalToConstant: 120),
            statsStackView.bottomAnchor.constraint(equalTo: statsContainerView.bottomAnchor)
        ])
    }
    
    private func createStatCard(title: String, value: String, iconName: String, gradient: [UIColor]) -> UIView {
        let card = UIView()
        card.applyPremiumCardStyle()
        card.applyGradient(colors: gradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1))
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = Theme.Colors.textOnPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconView)
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = Theme.Fonts.title2
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
    
    private func setupActivitySection() {
        activityContainerView.applyGlassEffect(alpha: 0.8)
        activityContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(activityContainerView)
        
        let titleLabel = UILabel()
        titleLabel.text = "Recent Activity"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        activityContainerView.addSubview(titleLabel)
        
        let activitiesStackView = UIStackView()
        activitiesStackView.axis = .vertical
        activitiesStackView.spacing = Theme.Spacing.md
        activitiesStackView.translatesAutoresizingMaskIntoConstraints = false
        activityContainerView.addSubview(activitiesStackView)
        
        let activities = [
            ("Viewed Downtown Apartment", "2 hours ago", "eye"),
            ("Saved Modern Loft", "5 hours ago", "heart.fill"),
            ("Started AI Negotiation", "1 day ago", "brain.head.profile"),
            ("Applied to Property", "2 days ago", "doc.text"),
            ("Updated Search Filters", "3 days ago", "slider.horizontal.3")
        ]
        
        for activity in activities {
            let activityView = createActivityRow(title: activity.0, time: activity.1, iconName: activity.2)
            activitiesStackView.addArrangedSubview(activityView)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: activityContainerView.topAnchor, constant: Theme.Spacing.lg),
            titleLabel.leadingAnchor.constraint(equalTo: activityContainerView.leadingAnchor, constant: Theme.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: activityContainerView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            activitiesStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            activitiesStackView.leadingAnchor.constraint(equalTo: activityContainerView.leadingAnchor, constant: Theme.Spacing.lg),
            activitiesStackView.trailingAnchor.constraint(equalTo: activityContainerView.trailingAnchor, constant: -Theme.Spacing.lg),
            activitiesStackView.bottomAnchor.constraint(equalTo: activityContainerView.bottomAnchor, constant: -Theme.Spacing.lg)
        ])
    }
    
    private func createActivityRow(title: String, time: String, iconName: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = Theme.Colors.primary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.Fonts.body
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let timeLabel = UILabel()
        timeLabel.text = time
        timeLabel.font = Theme.Fonts.caption1
        timeLabel.textColor = Theme.Colors.textSecondary
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 50),
            
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Theme.Spacing.md),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: Theme.Spacing.sm),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            timeLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Theme.Spacing.md),
            timeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xxs),
            timeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        return container
    }
    
    private func setupQuickActionsSection() {
        quickActionsView.applyPremiumCardStyle()
        quickActionsView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(quickActionsView)
        
        let titleLabel = UILabel()
        titleLabel.text = "Quick Actions"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        quickActionsView.addSubview(titleLabel)
        
        let actionsStackView = UIStackView()
        actionsStackView.axis = .horizontal
        actionsStackView.spacing = Theme.Spacing.md
        actionsStackView.distribution = .fillEqually
        actionsStackView.translatesAutoresizingMaskIntoConstraints = false
        quickActionsView.addSubview(actionsStackView)
        
        let searchButton = createActionButton(title: "Search", iconName: "magnifyingglass", action: #selector(searchTapped))
        let negotiateButton = createActionButton(title: "AI Negotiate", iconName: "brain.head.profile", action: #selector(negotiateTapped))
        let favoritesButton = createActionButton(title: "Favorites", iconName: "heart.fill", action: #selector(favoritesTapped))
        let profileButton = createActionButton(title: "Profile", iconName: "person.circle", action: #selector(profileTapped))
        
        actionsStackView.addArrangedSubview(searchButton)
        actionsStackView.addArrangedSubview(negotiateButton)
        actionsStackView.addArrangedSubview(favoritesButton)
        actionsStackView.addArrangedSubview(profileButton)
        
        NSLayoutConstraint.activate([
            quickActionsView.heightAnchor.constraint(equalToConstant: 160),
            
            titleLabel.topAnchor.constraint(equalTo: quickActionsView.topAnchor, constant: Theme.Spacing.lg),
            titleLabel.leadingAnchor.constraint(equalTo: quickActionsView.leadingAnchor, constant: Theme.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: quickActionsView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            actionsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            actionsStackView.leadingAnchor.constraint(equalTo: quickActionsView.leadingAnchor, constant: Theme.Spacing.lg),
            actionsStackView.trailingAnchor.constraint(equalTo: quickActionsView.trailingAnchor, constant: -Theme.Spacing.lg),
            actionsStackView.bottomAnchor.constraint(equalTo: quickActionsView.bottomAnchor, constant: -Theme.Spacing.lg)
        ])
    }
    
    private func createActionButton(title: String, iconName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: iconName), for: .normal)
        button.applyGlassStyle()
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure button layout
        button.titleLabel?.font = Theme.Fonts.buttonSmall
        button.imageView?.contentMode = .scaleAspectFit
        button.contentVerticalAlignment = .center
        button.contentHorizontalAlignment = .center
        
        // Position icon above text
        button.titleEdgeInsets = UIEdgeInsets(top: 35, left: -20, bottom: 0, right: 20)
        button.imageEdgeInsets = UIEdgeInsets(top: -15, left: 0, bottom: 15, right: 0)
        
        return button
    }
    
    private func loadDashboardData() {
        // Load user data
        if AuthManager.shared.isLoggedIn {
            APIService.shared.getCurrentUser { [weak self] result in
                switch result {
                case .success(let user):
                    self?.currentUser = user
                    self?.updateWelcomeMessage(user: user)
                case .failure(let error):
                    print("Error loading user: \(error)")
                }
            }
        }
    }
    
    private func updateWelcomeMessage(user: User) {
        welcomeLabel.text = "Welcome back, \(user.firstName)!"
    }
    
    private func animateOnAppear() {
        let views = [headerView, statsContainerView, activityContainerView, quickActionsView]
        
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
        // Simulate refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.refreshControl.endRefreshing()
            self.loadDashboardData()
        }
    }
    
    @objc private func searchTapped() {
        tabBarController?.selectedIndex = 1 // Search tab
    }
    
    @objc private func negotiateTapped() {
        let negotiatorVC = AINegotiatorViewController()
        navigationController?.pushViewController(negotiatorVC, animated: true)
    }
    
    @objc private func favoritesTapped() {
        tabBarController?.selectedIndex = 2 // Favorites tab
    }
    
    @objc private func profileTapped() {
        tabBarController?.selectedIndex = 4 // Profile tab
    }
}