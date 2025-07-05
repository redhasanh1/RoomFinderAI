import UIKit

class HomeViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let headerView = UIView()
    private let statsContainerView = UIView()
    private let featuredPropertiesView = UIView()
    private let quickActionsView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLayout()
        loadData()
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.backgroundColor
        title = "RoomFinderAI"
        
        // Configure scroll view
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.refreshControl = UIRefreshControl()
        scrollView.refreshControl?.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        setupHeaderView()
        setupStatsView()
        setupQuickActionsView()
        setupFeaturedPropertiesView()
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = .clear
        
        // Welcome label
        let welcomeLabel = UILabel()
        welcomeLabel.text = "Welcome back!"
        welcomeLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        welcomeLabel.textColor = AppColors.textSecondary
        
        // User name label
        let nameLabel = UILabel()
        nameLabel.text = "Find Your Perfect Room"
        nameLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        nameLabel.textColor = AppColors.textPrimary
        nameLabel.numberOfLines = 0
        
        // Search bar
        let searchContainer = UIView()
        searchContainer.backgroundColor = AppColors.cardBackground
        searchContainer.layer.cornerRadius = 16
        searchContainer.layer.shadowColor = UIColor.black.cgColor
        searchContainer.layer.shadowOpacity = 0.1
        searchContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        searchContainer.layer.shadowRadius = 8
        
        let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIcon.tintColor = AppColors.textSecondary
        searchIcon.contentMode = .scaleAspectFit
        
        let searchLabel = UILabel()
        searchLabel.text = "Search for rooms, locations..."
        searchLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        searchLabel.textColor = AppColors.textSecondary
        
        searchContainer.addSubview(searchIcon)
        searchContainer.addSubview(searchLabel)
        
        headerView.addSubview(welcomeLabel)
        headerView.addSubview(nameLabel)
        headerView.addSubview(searchContainer)
        
        // Layout
        welcomeLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            welcomeLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            welcomeLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            
            nameLabel.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            searchContainer.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 24),
            searchContainer.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            searchContainer.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            searchContainer.heightAnchor.constraint(equalToConstant: 56),
            searchContainer.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            
            searchIcon.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 16),
            searchIcon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 20),
            searchIcon.heightAnchor.constraint(equalToConstant: 20),
            
            searchLabel.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 12),
            searchLabel.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchLabel.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -16)
        ])
        
        // Add tap gesture to search
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(searchTapped))
        searchContainer.addGestureRecognizer(tapGesture)
    }
    
    private func setupStatsView() {
        statsContainerView.backgroundColor = .clear
        
        let statsStackView = UIStackView()
        statsStackView.axis = .horizontal
        statsStackView.distribution = .fillEqually
        statsStackView.spacing = 16
        
        // Create stat cards
        let availableRoomsCard = createStatCard(title: "Available Rooms", value: "1,247", icon: "house.fill", gradient: AppColors.primaryGradient)
        let avgPriceCard = createStatCard(title: "Avg. Price", value: "$850", icon: "dollarsign.circle.fill", gradient: AppColors.accentGradient)
        let savedCard = createStatCard(title: "Money Saved", value: "$2,340", icon: "checkmark.circle.fill", gradient: [AppColors.successGreen.cgColor, AppColors.successGreen.withAlphaComponent(0.7).cgColor])
        
        statsStackView.addArrangedSubview(availableRoomsCard)
        statsStackView.addArrangedSubview(avgPriceCard)
        statsStackView.addArrangedSubview(savedCard)
        
        statsContainerView.addSubview(statsStackView)
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            statsStackView.topAnchor.constraint(equalTo: statsContainerView.topAnchor, constant: 20),
            statsStackView.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor, constant: 20),
            statsStackView.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor, constant: -20),
            statsStackView.bottomAnchor.constraint(equalTo: statsContainerView.bottomAnchor, constant: -20),
            statsStackView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    private func createStatCard(title: String, value: String, icon: String, gradient: [CGColor]) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.1
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 12
        
        // Add gradient background
        DispatchQueue.main.async {
            card.addGradient(colors: gradient)
        }
        
        let iconImageView = UIImageView(image: UIImage(systemName: icon))
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        valueLabel.textColor = .white
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        
        card.addSubview(iconImageView)
        card.addSubview(valueLabel)
        card.addSubview(titleLabel)
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            iconImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            valueLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            valueLabel.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -2),
            
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: iconImageView.leadingAnchor, constant: -8)
        ])
        
        return card
    }
    
    private func setupQuickActionsView() {
        quickActionsView.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.text = "Quick Actions"
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary
        
        let actionsStackView = UIStackView()
        actionsStackView.axis = .horizontal
        actionsStackView.distribution = .fillEqually
        actionsStackView.spacing = 16
        
        // Create action buttons
        let searchAction = createActionButton(title: "Find Rooms", icon: "magnifyingglass", color: AppColors.primaryPurple)
        let negotiateAction = createActionButton(title: "AI Negotiate", icon: "message.badge.filled.fill", color: AppColors.accentBlue)
        let favoritesAction = createActionButton(title: "My Favorites", icon: "heart.fill", color: AppColors.errorRed)
        let mapAction = createActionButton(title: "Map View", icon: "map.fill", color: AppColors.successGreen)
        
        actionsStackView.addArrangedSubview(searchAction)
        actionsStackView.addArrangedSubview(negotiateAction)
        actionsStackView.addArrangedSubview(favoritesAction)
        actionsStackView.addArrangedSubview(mapAction)
        
        quickActionsView.addSubview(titleLabel)
        quickActionsView.addSubview(actionsStackView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        actionsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: quickActionsView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: quickActionsView.leadingAnchor, constant: 20),
            
            actionsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            actionsStackView.leadingAnchor.constraint(equalTo: quickActionsView.leadingAnchor, constant: 20),
            actionsStackView.trailingAnchor.constraint(equalTo: quickActionsView.trailingAnchor, constant: -20),
            actionsStackView.bottomAnchor.constraint(equalTo: quickActionsView.bottomAnchor, constant: -20),
            actionsStackView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    private func createActionButton(title: String, icon: String, color: UIColor) -> UIView {
        let button = UIView()
        button.backgroundColor = AppColors.cardBackground
        button.layer.cornerRadius = 16
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.1
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 8
        
        let iconImageView = UIImageView(image: UIImage(systemName: icon))
        iconImageView.tintColor = color
        iconImageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        
        button.addSubview(iconImageView)
        button.addSubview(titleLabel)
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            iconImageView.topAnchor.constraint(equalTo: button.topAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: button.bottomAnchor, constant: -8)
        ])
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(actionButtonTapped(_:)))
        button.addGestureRecognizer(tapGesture)
        button.isUserInteractionEnabled = true
        
        return button
    }
    
    private func setupFeaturedPropertiesView() {
        featuredPropertiesView.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.text = "Featured Properties"
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary
        
        let seeAllButton = UIButton(type: .system)
        seeAllButton.setTitle("See All", for: .normal)
        seeAllButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        seeAllButton.setTitleColor(AppColors.primaryPurple, for: .normal)
        seeAllButton.addTarget(self, action: #selector(seeAllTapped), for: .touchUpInside)
        
        // Create property cards scroll view
        let propertiesScrollView = UIScrollView()
        propertiesScrollView.showsHorizontalScrollIndicator = false
        propertiesScrollView.isPagingEnabled = false
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 16
        stackView.distribution = .fill
        
        // Create sample property cards
        for i in 1...5 {
            let propertyCard = createPropertyCard(
                title: "Modern Studio Apartment \(i)",
                price: "$\(800 + i * 50)",
                location: "Downtown Area",
                image: "photo"
            )
            stackView.addArrangedSubview(propertyCard)
        }
        
        propertiesScrollView.addSubview(stackView)
        featuredPropertiesView.addSubview(titleLabel)
        featuredPropertiesView.addSubview(seeAllButton)
        featuredPropertiesView.addSubview(propertiesScrollView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        seeAllButton.translatesAutoresizingMaskIntoConstraints = false
        propertiesScrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: featuredPropertiesView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: featuredPropertiesView.leadingAnchor, constant: 20),
            
            seeAllButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            seeAllButton.trailingAnchor.constraint(equalTo: featuredPropertiesView.trailingAnchor, constant: -20),
            
            propertiesScrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            propertiesScrollView.leadingAnchor.constraint(equalTo: featuredPropertiesView.leadingAnchor),
            propertiesScrollView.trailingAnchor.constraint(equalTo: featuredPropertiesView.trailingAnchor),
            propertiesScrollView.bottomAnchor.constraint(equalTo: featuredPropertiesView.bottomAnchor, constant: -20),
            propertiesScrollView.heightAnchor.constraint(equalToConstant: 280),
            
            stackView.topAnchor.constraint(equalTo: propertiesScrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: propertiesScrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: propertiesScrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: propertiesScrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: propertiesScrollView.heightAnchor)
        ])
    }
    
    private func createPropertyCard(title: String, price: String, location: String, image: String) -> UIView {
        let card = UIView()
        card.backgroundColor = AppColors.cardBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.1
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 12
        card.widthAnchor.constraint(equalToConstant: 220).isActive = true
        
        let imageView = UIImageView()
        imageView.backgroundColor = AppColors.separatorColor
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.image = UIImage(systemName: image)
        imageView.tintColor = AppColors.textSecondary
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.numberOfLines = 2
        
        let priceLabel = UILabel()
        priceLabel.text = price
        priceLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        priceLabel.textColor = AppColors.primaryPurple
        
        let locationLabel = UILabel()
        locationLabel.text = location
        locationLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        locationLabel.textColor = AppColors.textSecondary
        
        card.addSubview(imageView)
        card.addSubview(titleLabel)
        card.addSubview(priceLabel)
        card.addSubview(locationLabel)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        locationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            imageView.heightAnchor.constraint(equalToConstant: 140),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            
            priceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            priceLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            
            locationLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 4),
            locationLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            locationLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            locationLabel.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -12)
        ])
        
        return card
    }
    
    private func setupLayout() {
        contentView.addSubview(headerView)
        contentView.addSubview(statsContainerView)
        contentView.addSubview(quickActionsView)
        contentView.addSubview(featuredPropertiesView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.translatesAutoresizingMaskIntoConstraints = false
        quickActionsView.translatesAutoresizingMaskIntoConstraints = false
        featuredPropertiesView.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            statsContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            statsContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statsContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            quickActionsView.topAnchor.constraint(equalTo: statsContainerView.bottomAnchor),
            quickActionsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            quickActionsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            featuredPropertiesView.topAnchor.constraint(equalTo: quickActionsView.bottomAnchor),
            featuredPropertiesView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            featuredPropertiesView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            featuredPropertiesView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    private func loadData() {
        // Simulate loading data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.scrollView.refreshControl?.endRefreshing()
        }
    }
    
    @objc private func refreshData() {
        loadData()
    }
    
    @objc private func searchTapped() {
        tabBarController?.selectedIndex = 1 // Switch to search tab
    }
    
    @objc private func actionButtonTapped(_ gesture: UITapGestureRecognizer) {
        guard let button = gesture.view else { return }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Add animation
        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                button.transform = CGAffineTransform.identity
            }
        }
        
        // Handle action based on button (you can identify by tag or other means)
        // For now, just switch to appropriate tab
        if button.subviews.contains(where: { ($0 as? UIImageView)?.image == UIImage(systemName: "magnifyingglass") }) {
            tabBarController?.selectedIndex = 1
        } else if button.subviews.contains(where: { ($0 as? UIImageView)?.image == UIImage(systemName: "message.badge.filled.fill") }) {
            tabBarController?.selectedIndex = 3
        } else if button.subviews.contains(where: { ($0 as? UIImageView)?.image == UIImage(systemName: "heart.fill") }) {
            tabBarController?.selectedIndex = 2
        }
    }
    
    @objc private func seeAllTapped() {
        tabBarController?.selectedIndex = 1 // Switch to search tab
    }
}