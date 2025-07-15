import UIKit
import Foundation

// Real Enhanced Search Implementation
class EnhancedSearchViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let searchBar = UISearchBar()
    private let filtersStackView = UIStackView()
    private let resultsTableView = UITableView()
    private let mapToggleButton = UIButton(type: .system)
    private let sortButton = UIButton(type: .system)
    
    private var properties: [Property] = []
    private var filteredProperties: [Property] = []
    private var isMapView = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadProperties()
    }
    
    private func setupUI() {
        view.backgroundColor = Theme.Colors.background
        title = "Search Properties"
        
        // Search bar
        searchBar.delegate = self
        searchBar.placeholder = "Search properties..."
        searchBar.searchBarStyle = .minimal
        
        // Filters stack view
        filtersStackView.axis = .horizontal
        filtersStackView.spacing = Theme.Spacing.sm
        filtersStackView.distribution = .fillEqually
        
        // Add filter buttons
        let priceFilterButton = createFilterButton(title: "Price", action: #selector(showPriceFilter))
        let typeFilterButton = createFilterButton(title: "Type", action: #selector(showTypeFilter))
        let bedsFilterButton = createFilterButton(title: "Beds", action: #selector(showBedsFilter))
        let locationFilterButton = createFilterButton(title: "Location", action: #selector(showLocationFilter))
        
        filtersStackView.addArrangedSubview(priceFilterButton)
        filtersStackView.addArrangedSubview(typeFilterButton)
        filtersStackView.addArrangedSubview(bedsFilterButton)
        filtersStackView.addArrangedSubview(locationFilterButton)
        
        // Map toggle button
        mapToggleButton.setTitle("Map View", for: .normal)
        mapToggleButton.applySecondaryButtonStyle()
        mapToggleButton.addTarget(self, action: #selector(toggleMapView), for: .touchUpInside)
        
        // Sort button
        sortButton.setTitle("Sort", for: .normal)
        sortButton.applySecondaryButtonStyle()
        sortButton.addTarget(self, action: #selector(showSortOptions), for: .touchUpInside)
        
        // Results table view
        resultsTableView.delegate = self
        resultsTableView.dataSource = self
        resultsTableView.register(PropertyTableViewCell.self, forCellReuseIdentifier: "PropertyCell")
        resultsTableView.backgroundColor = .clear
        resultsTableView.separatorStyle = .none
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        filtersStackView.translatesAutoresizingMaskIntoConstraints = false
        mapToggleButton.translatesAutoresizingMaskIntoConstraints = false
        sortButton.translatesAutoresizingMaskIntoConstraints = false
        resultsTableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(searchBar)
        contentView.addSubview(filtersStackView)
        contentView.addSubview(mapToggleButton)
        contentView.addSubview(sortButton)
        contentView.addSubview(resultsTableView)
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
            
            searchBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Spacing.md),
            searchBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.md),
            searchBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.md),
            
            filtersStackView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: Theme.Spacing.md),
            filtersStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.md),
            filtersStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.md),
            filtersStackView.heightAnchor.constraint(equalToConstant: 44),
            
            mapToggleButton.topAnchor.constraint(equalTo: filtersStackView.bottomAnchor, constant: Theme.Spacing.md),
            mapToggleButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.md),
            mapToggleButton.widthAnchor.constraint(equalToConstant: 100),
            
            sortButton.topAnchor.constraint(equalTo: filtersStackView.bottomAnchor, constant: Theme.Spacing.md),
            sortButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.md),
            sortButton.widthAnchor.constraint(equalToConstant: 80),
            
            resultsTableView.topAnchor.constraint(equalTo: mapToggleButton.bottomAnchor, constant: Theme.Spacing.md),
            resultsTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            resultsTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            resultsTableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            resultsTableView.heightAnchor.constraint(equalToConstant: 600)
        ])
    }
    
    private func createFilterButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.applySecondaryButtonStyle()
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    private func loadProperties() {
        // Load properties from API
        APIService.shared.fetchProperties { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let properties):
                    self?.properties = properties
                    self?.filteredProperties = properties
                    self?.resultsTableView.reloadData()
                case .failure(let error):
                    print("Error loading properties: \(error)")
                    // Show error message
                }
            }
        }
    }
    
    @objc private func showPriceFilter() {
        let alert = UIAlertController(title: "Price Range", message: "Select price range", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Under $1,000", style: .default) { _ in
            self.filterByPrice(max: 1000)
        })
        alert.addAction(UIAlertAction(title: "$1,000 - $2,000", style: .default) { _ in
            self.filterByPrice(min: 1000, max: 2000)
        })
        alert.addAction(UIAlertAction(title: "$2,000 - $3,000", style: .default) { _ in
            self.filterByPrice(min: 2000, max: 3000)
        })
        alert.addAction(UIAlertAction(title: "Over $3,000", style: .default) { _ in
            self.filterByPrice(min: 3000)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func showTypeFilter() {
        let alert = UIAlertController(title: "Property Type", message: "Select property type", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Apartment", style: .default) { _ in
            self.filterByType("apartment")
        })
        alert.addAction(UIAlertAction(title: "House", style: .default) { _ in
            self.filterByType("house")
        })
        alert.addAction(UIAlertAction(title: "Condo", style: .default) { _ in
            self.filterByType("condo")
        })
        alert.addAction(UIAlertAction(title: "Townhouse", style: .default) { _ in
            self.filterByType("townhouse")
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func showBedsFilter() {
        let alert = UIAlertController(title: "Bedrooms", message: "Select number of bedrooms", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Studio", style: .default) { _ in
            self.filterByBeds(0)
        })
        alert.addAction(UIAlertAction(title: "1 Bedroom", style: .default) { _ in
            self.filterByBeds(1)
        })
        alert.addAction(UIAlertAction(title: "2 Bedrooms", style: .default) { _ in
            self.filterByBeds(2)
        })
        alert.addAction(UIAlertAction(title: "3+ Bedrooms", style: .default) { _ in
            self.filterByBeds(3)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func showLocationFilter() {
        let alert = UIAlertController(title: "Location", message: "Select location", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Downtown", style: .default) { _ in
            self.filterByLocation("downtown")
        })
        alert.addAction(UIAlertAction(title: "Midtown", style: .default) { _ in
            self.filterByLocation("midtown")
        })
        alert.addAction(UIAlertAction(title: "Uptown", style: .default) { _ in
            self.filterByLocation("uptown")
        })
        alert.addAction(UIAlertAction(title: "Suburbs", style: .default) { _ in
            self.filterByLocation("suburbs")
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func toggleMapView() {
        isMapView.toggle()
        mapToggleButton.setTitle(isMapView ? "List View" : "Map View", for: .normal)
        
        if isMapView {
            let mapVC = MapViewController()
            mapVC.properties = filteredProperties
            navigationController?.pushViewController(mapVC, animated: true)
        }
    }
    
    @objc private func showSortOptions() {
        let alert = UIAlertController(title: "Sort By", message: "Select sorting option", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Price: Low to High", style: .default) { _ in
            self.sortProperties(by: .priceAsc)
        })
        alert.addAction(UIAlertAction(title: "Price: High to Low", style: .default) { _ in
            self.sortProperties(by: .priceDesc)
        })
        alert.addAction(UIAlertAction(title: "Newest First", style: .default) { _ in
            self.sortProperties(by: .newest)
        })
        alert.addAction(UIAlertAction(title: "Relevance", style: .default) { _ in
            self.sortProperties(by: .relevance)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func filterByPrice(min: Int? = nil, max: Int? = nil) {
        filteredProperties = properties.filter { property in
            let price = Int(property.price)
            if let min = min, let max = max {
                return price >= min && price <= max
            } else if let min = min {
                return price >= min
            } else if let max = max {
                return price <= max
            }
            return true
        }
        resultsTableView.reloadData()
    }
    
    private func filterByType(_ type: String) {
        filteredProperties = properties.filter { property in
            property.propertyType.lowercased() == type.lowercased()
        }
        resultsTableView.reloadData()
    }
    
    private func filterByBeds(_ beds: Int) {
        filteredProperties = properties.filter { property in
            if beds == 0 {
                return property.bedrooms == 0
            } else if beds == 3 {
                return property.bedrooms >= 3
            } else {
                return property.bedrooms == beds
            }
        }
        resultsTableView.reloadData()
    }
    
    private func filterByLocation(_ location: String) {
        filteredProperties = properties.filter { property in
            property.city.lowercased().contains(location.lowercased()) ||
            property.address.lowercased().contains(location.lowercased())
        }
        resultsTableView.reloadData()
    }
    
    private enum SortOption {
        case priceAsc, priceDesc, newest, relevance
    }
    
    private func sortProperties(by option: SortOption) {
        switch option {
        case .priceAsc:
            filteredProperties.sort { $0.price < $1.price }
        case .priceDesc:
            filteredProperties.sort { $0.price > $1.price }
        case .newest:
            filteredProperties.sort { $0.createdAt > $1.createdAt }
        case .relevance:
            // Sort by relevance (implement based on search criteria)
            break
        }
        resultsTableView.reloadData()
    }
}

// MARK: - UISearchBarDelegate
extension EnhancedSearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredProperties = properties
        } else {
            filteredProperties = properties.filter { property in
                property.title.lowercased().contains(searchText.lowercased()) ||
                property.address.lowercased().contains(searchText.lowercased()) ||
                property.city.lowercased().contains(searchText.lowercased())
            }
        }
        resultsTableView.reloadData()
    }
}

// MARK: - UITableViewDataSource & Delegate
extension EnhancedSearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredProperties.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PropertyCell", for: indexPath) as! PropertyTableViewCell
        cell.configure(with: filteredProperties[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let property = filteredProperties[indexPath.row]
        let detailVC = PropertyDetailViewController()
        detailVC.property = property
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Dashboard Activity Model
struct DashboardActivity {
    let title: String
    let time: String
    let icon: String
    let type: ActivityType
    
    enum ActivityType {
        case view
        case favorite
        case negotiation
        case application
        case search
    }
}

// MARK: - Activity Table View Cell
class ActivityTableViewCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        let containerView = UIView()
        containerView.applyGlassEffect(alpha: 0.5)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Theme.Colors.primary
        iconView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconView)
        
        titleLabel.font = Theme.Fonts.body
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        timeLabel.font = Theme.Fonts.caption1
        timeLabel.textColor = Theme.Colors.textSecondary
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Spacing.xs),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.md),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.md),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Spacing.xs),
            
            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Theme.Spacing.md),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Theme.Spacing.md),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Theme.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Theme.Spacing.md),
            
            timeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            timeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xxs),
            timeLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            timeLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Theme.Spacing.md)
        ])
    }
    
    func configure(with activity: DashboardActivity) {
        iconView.image = UIImage(systemName: activity.icon)
        titleLabel.text = activity.title
        timeLabel.text = activity.time
        
        switch activity.type {
        case .view:
            iconView.tintColor = Theme.Colors.primary
        case .favorite:
            iconView.tintColor = Theme.Colors.accent
        case .negotiation:
            iconView.tintColor = Theme.Colors.success
        case .application:
            iconView.tintColor = Theme.Colors.warning
        case .search:
            iconView.tintColor = Theme.Colors.secondary
        }
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

// MARK: - UITableViewDataSource & Delegate
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
        return 60
    }
}

// MARK: - Main Tab Bar Controller
class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
        setupAppearance()
    }
    
    private func setupViewControllers() {
        let dashboardVC = UINavigationController(rootViewController: DashboardViewController())
        dashboardVC.tabBarItem = UITabBarItem(title: "Dashboard", image: UIImage(systemName: "house.fill"), tag: 0)
        
        let searchVC = UINavigationController(rootViewController: EnhancedSearchViewController())
        searchVC.tabBarItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 1)
        
        let chatVC = UINavigationController(rootViewController: ChatViewController())
        chatVC.tabBarItem = UITabBarItem(title: "Chat", image: UIImage(systemName: "message.fill"), tag: 2)
        
        let favoritesVC = UINavigationController(rootViewController: FavoritesViewController())
        favoritesVC.tabBarItem = UITabBarItem(title: "Favorites", image: UIImage(systemName: "heart.fill"), tag: 3)
        
        let profileVC = UINavigationController(rootViewController: ProfileViewController())
        profileVC.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person.fill"), tag: 4)
        
        viewControllers = [dashboardVC, searchVC, chatVC, favoritesVC, profileVC]
    }
    
    private func setupAppearance() {
        tabBar.tintColor = Theme.Colors.primary
        tabBar.backgroundColor = Theme.Colors.surface
        tabBar.isTranslucent = true
        
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = Theme.Colors.surface
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }
}

