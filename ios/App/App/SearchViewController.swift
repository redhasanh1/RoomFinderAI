import UIKit

class SearchViewController: UIViewController {
    
    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView()
    private let filterButton = UIButton(type: .system)
    private let mapButton = UIButton(type: .system)
    private let sortButton = UIButton(type: .system)
    
    // Search and filter properties
    private var properties: [PropertyModel] = []
    private var filteredProperties: [PropertyModel] = []
    private var currentSearchText = ""
    private var activeFilters: [String: Any] = [:]
    
    // Quick filter buttons
    private let quickFiltersScrollView = UIScrollView()
    private let quickFiltersStackView = UIStackView()
    
    // Search suggestions
    private let suggestionsView = UIView()
    private let suggestionsTableView = UITableView()
    private var searchSuggestions: [String] = ["Manhattan", "Brooklyn", "Queens", "Studio", "1 Bedroom", "2 Bedroom", "Under $2000", "Pet Friendly", "Gym", "Pool"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSearchController()
        setupTableView()
        loadProperties()
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.backgroundColor
        title = "Search"
        
        setupNavigationButtons()
        setupQuickFilters()
        setupSuggestionsView()
    }
    
    private func setupNavigationButtons() {
        // Filter button
        filterButton.setImage(UIImage(systemName: "slider.horizontal.3"), for: .normal)
        filterButton.backgroundColor = AppColors.primaryPurple
        filterButton.tintColor = .white
        filterButton.layer.cornerRadius = 20
        filterButton.layer.shadowColor = UIColor.black.cgColor
        filterButton.layer.shadowOpacity = 0.2
        filterButton.layer.shadowOffset = CGSize(width: 0, y: 2)
        filterButton.layer.shadowRadius = 4
        filterButton.addTarget(self, action: #selector(filterTapped), for: .touchUpInside)
        
        // Map button
        mapButton.setImage(UIImage(systemName: "map.fill"), for: .normal)
        mapButton.backgroundColor = AppColors.accentBlue
        mapButton.tintColor = .white
        mapButton.layer.cornerRadius = 20
        mapButton.layer.shadowColor = UIColor.black.cgColor
        mapButton.layer.shadowOpacity = 0.2
        mapButton.layer.shadowOffset = CGSize(width: 0, y: 2)
        mapButton.layer.shadowRadius = 4
        mapButton.addTarget(self, action: #selector(mapTapped), for: .touchUpInside)
        
        // Sort button
        sortButton.setImage(UIImage(systemName: "arrow.up.arrow.down"), for: .normal)
        sortButton.backgroundColor = AppColors.successGreen
        sortButton.tintColor = .white
        sortButton.layer.cornerRadius = 20
        sortButton.layer.shadowColor = UIColor.black.cgColor
        sortButton.layer.shadowOpacity = 0.2
        sortButton.layer.shadowOffset = CGSize(width: 0, y: 2)
        sortButton.layer.shadowRadius = 4
        sortButton.addTarget(self, action: #selector(sortTapped), for: .touchUpInside)
        
        // Setup button constraints
        [filterButton, mapButton, sortButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                $0.widthAnchor.constraint(equalToConstant: 40),
                $0.heightAnchor.constraint(equalToConstant: 40)
            ])
        }
        
        let stackView = UIStackView(arrangedSubviews: [sortButton, mapButton, filterButton])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: stackView)
    }
    
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search locations, price, features..."
        searchController.searchBar.tintColor = AppColors.primaryPurple
        searchController.delegate = self
        
        // Customize search bar appearance
        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.backgroundColor = AppColors.backgroundColor
        
        // Add scope buttons for quick filtering
        searchController.searchBar.scopeButtonTitles = ["All", "Studio", "1BR", "2BR+", "Luxury"]
        searchController.searchBar.selectedScopeButtonIndex = 0
        searchController.searchBar.delegate = self
        
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = AppColors.backgroundColor
        tableView.separatorStyle = .none
        tableView.register(PropertyTableViewCell.self, forCellReuseIdentifier: "PropertyCell")
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        tableView.keyboardDismissMode = .onDrag
        
        // Add refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = AppColors.primaryPurple
        refreshControl.addTarget(self, action: #selector(refreshProperties), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: quickFiltersScrollView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadProperties() {
        // Comprehensive sample data for testing
        properties = [
            PropertyModel(id: "1", title: "Modern Studio in Downtown", price: 1800, location: "Manhattan", bedrooms: 1, bathrooms: 1, amenities: ["WiFi", "Gym", "Pool", "Furnished"], rating: 4.8, isVerified: true),
            PropertyModel(id: "2", title: "Cozy 2BR Apartment", price: 1200, location: "Brooklyn", bedrooms: 2, bathrooms: 1, amenities: ["WiFi", "Pet Friendly", "Parking"], rating: 4.5, isVerified: false),
            PropertyModel(id: "3", title: "Luxury Penthouse", price: 3200, location: "Upper East Side", bedrooms: 3, bathrooms: 2, amenities: ["WiFi", "Gym", "Pool", "Concierge", "Furnished"], rating: 4.9, isVerified: true),
            PropertyModel(id: "4", title: "Student Housing Near NYU", price: 900, location: "Greenwich Village", bedrooms: 1, bathrooms: 1, amenities: ["WiFi", "Study Room", "Furnished"], rating: 4.3, isVerified: true),
            PropertyModel(id: "5", title: "Shared Room in Queens", price: 750, location: "Queens", bedrooms: 1, bathrooms: 1, amenities: ["WiFi", "Pet Friendly"], rating: 4.1, isVerified: false),
            PropertyModel(id: "6", title: "Spacious 2BR with Gym Access", price: 2100, location: "Midtown", bedrooms: 2, bathrooms: 2, amenities: ["WiFi", "Gym", "Pet Friendly", "Parking"], rating: 4.6, isVerified: true),
            PropertyModel(id: "7", title: "Affordable Studio with Pool", price: 1400, location: "Lower East Side", bedrooms: 1, bathrooms: 1, amenities: ["WiFi", "Pool", "Furnished"], rating: 4.4, isVerified: false),
            PropertyModel(id: "8", title: "Luxury 3BR with Concierge", price: 4500, location: "Tribeca", bedrooms: 3, bathrooms: 3, amenities: ["WiFi", "Gym", "Pool", "Concierge", "Pet Friendly", "Parking"], rating: 4.9, isVerified: true),
            PropertyModel(id: "9", title: "Pet-Friendly 1BR", price: 1600, location: "Chelsea", bedrooms: 1, bathrooms: 1, amenities: ["WiFi", "Pet Friendly", "Gym"], rating: 4.2, isVerified: true),
            PropertyModel(id: "10", title: "Furnished Studio Near Central Park", price: 2200, location: "Upper West Side", bedrooms: 1, bathrooms: 1, amenities: ["WiFi", "Furnished", "Gym", "Pool"], rating: 4.7, isVerified: true)
        ]
        filteredProperties = properties
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    private func filterProperties(with searchText: String) {
        currentSearchText = searchText
        
        // Start with all properties
        var results = properties
        
        // Apply text search
        if !searchText.isEmpty {
            results = results.filter { property in
                property.title.lowercased().contains(searchText.lowercased()) ||
                property.location.lowercased().contains(searchText.lowercased()) ||
                String(property.price).contains(searchText) ||
                property.amenities.joined().lowercased().contains(searchText.lowercased())
            }
        }
        
        // Apply scope filter
        let scopeIndex = searchController.searchBar.selectedScopeButtonIndex
        switch scopeIndex {
        case 1: // Studio
            results = results.filter { $0.bedrooms == 1 && $0.title.lowercased().contains("studio") }
        case 2: // 1BR
            results = results.filter { $0.bedrooms == 1 && !$0.title.lowercased().contains("studio") }
        case 3: // 2BR+
            results = results.filter { $0.bedrooms >= 2 }
        case 4: // Luxury
            results = results.filter { $0.price > 2000 || $0.title.lowercased().contains("luxury") }
        default: // All
            break
        }
        
        // Apply quick filters
        for (filterName, _) in activeFilters {
            switch filterName {
            case "Under $2000":
                results = results.filter { $0.price < 2000 }
            case "Pet Friendly":
                results = results.filter { $0.amenities.contains("Pet Friendly") }
            case "Gym":
                results = results.filter { $0.amenities.contains("Gym") }
            case "Pool":
                results = results.filter { $0.amenities.contains("Pool") }
            case "Furnished":
                results = results.filter { $0.amenities.contains("Furnished") }
            case "Recently Added":
                // Filter by recently added (mock implementation)
                results = results.suffix(results.count / 2).map { $0 }
            default:
                break
            }
        }
        
        filteredProperties = results
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            
            // Show/hide suggestions
            if searchText.isEmpty {
                self.showSuggestions()
            } else {
                self.hideSuggestions()
            }
        }
    }
    
    private func showSuggestions() {
        UIView.animate(withDuration: 0.3) {
            self.suggestionsView.isHidden = false
            self.suggestionsView.alpha = 1
        }
    }
    
    private func hideSuggestions() {
        UIView.animate(withDuration: 0.3) {
            self.suggestionsView.alpha = 0
        } completion: { _ in
            self.suggestionsView.isHidden = true
        }
    }
    
    enum SortOption {
        case priceLowToHigh, priceHighToLow, recentlyAdded, rating
    }
    
    private func sortProperties(by option: SortOption) {
        switch option {
        case .priceLowToHigh:
            filteredProperties.sort { $0.price < $1.price }
        case .priceHighToLow:
            filteredProperties.sort { $0.price > $1.price }
        case .recentlyAdded:
            // Mock implementation - reverse order
            filteredProperties.reverse()
        case .rating:
            filteredProperties.sort { $0.rating > $1.rating }
        }
        
        tableView.reloadData()
    }
    
    private func setupQuickFilters() {
        quickFiltersScrollView.showsHorizontalScrollIndicator = false
        quickFiltersScrollView.backgroundColor = AppColors.backgroundColor
        
        quickFiltersStackView.axis = .horizontal
        quickFiltersStackView.spacing = 12
        quickFiltersStackView.distribution = .fill
        
        let filterTitles = ["Under $2000", "Pet Friendly", "Gym", "Pool", "Furnished", "Recently Added"]
        
        for title in filterTitles {
            let filterButton = createQuickFilterButton(title: title)
            quickFiltersStackView.addArrangedSubview(filterButton)
        }
        
        quickFiltersScrollView.addSubview(quickFiltersStackView)
        view.addSubview(quickFiltersScrollView)
        
        [quickFiltersScrollView, quickFiltersStackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            quickFiltersScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            quickFiltersScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            quickFiltersScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            quickFiltersScrollView.heightAnchor.constraint(equalToConstant: 60),
            
            quickFiltersStackView.topAnchor.constraint(equalTo: quickFiltersScrollView.topAnchor, constant: 12),
            quickFiltersStackView.leadingAnchor.constraint(equalTo: quickFiltersScrollView.leadingAnchor, constant: 20),
            quickFiltersStackView.trailingAnchor.constraint(equalTo: quickFiltersScrollView.trailingAnchor, constant: -20),
            quickFiltersStackView.bottomAnchor.constraint(equalTo: quickFiltersScrollView.bottomAnchor, constant: -12),
            quickFiltersStackView.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    private func createQuickFilterButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(AppColors.textPrimary, for: .normal)
        button.setTitleColor(.white, for: .selected)
        button.backgroundColor = AppColors.separatorColor.withAlphaComponent(0.3)
        button.layer.cornerRadius = 18
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        button.addTarget(self, action: #selector(quickFilterTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    private func setupSuggestionsView() {
        suggestionsView.backgroundColor = AppColors.cardBackground
        suggestionsView.layer.cornerRadius = 12
        suggestionsView.layer.shadowColor = UIColor.black.cgColor
        suggestionsView.layer.shadowOpacity = 0.1
        suggestionsView.layer.shadowOffset = CGSize(width: 0, y: 4)
        suggestionsView.layer.shadowRadius = 8
        suggestionsView.isHidden = true
        
        suggestionsTableView.delegate = self
        suggestionsTableView.dataSource = self
        suggestionsTableView.backgroundColor = .clear
        suggestionsTableView.separatorStyle = .none
        suggestionsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "SuggestionCell")
        suggestionsTableView.layer.cornerRadius = 12
        
        suggestionsView.addSubview(suggestionsTableView)
        view.addSubview(suggestionsView)
        
        [suggestionsView, suggestionsTableView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            suggestionsView.topAnchor.constraint(equalTo: quickFiltersScrollView.bottomAnchor, constant: 8),
            suggestionsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            suggestionsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            suggestionsView.heightAnchor.constraint(equalToConstant: 200),
            
            suggestionsTableView.topAnchor.constraint(equalTo: suggestionsView.topAnchor),
            suggestionsTableView.leadingAnchor.constraint(equalTo: suggestionsView.leadingAnchor),
            suggestionsTableView.trailingAnchor.constraint(equalTo: suggestionsView.trailingAnchor),
            suggestionsTableView.bottomAnchor.constraint(equalTo: suggestionsView.bottomAnchor)
        ])
    }
    
    @objc private func quickFilterTapped(_ sender: UIButton) {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Toggle button state
        sender.isSelected.toggle()
        
        UIView.animate(withDuration: 0.2) {
            sender.backgroundColor = sender.isSelected ? 
                AppColors.primaryPurple : 
                AppColors.separatorColor.withAlphaComponent(0.3)
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = .identity
            }
        }
        
        // Apply filter
        applyQuickFilter(sender.titleLabel?.text ?? "", isActive: sender.isSelected)
    }
    
    private func applyQuickFilter(_ filterName: String, isActive: Bool) {
        if isActive {
            activeFilters[filterName] = true
        } else {
            activeFilters.removeValue(forKey: filterName)
        }
        
        filterProperties(with: currentSearchText)
    }
    
    @objc private func filterTapped() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        let filterVC = FilterViewController()
        let navController = UINavigationController(rootViewController: filterVC)
        present(navController, animated: true)
    }
    
    @objc private func mapTapped() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        let alert = UIAlertController(title: "Map View", message: "Opening map with search results...", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func sortTapped() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        let actionSheet = UIAlertController(title: "Sort Properties", message: "Choose sorting option", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Price: Low to High", style: .default) { _ in
            self.sortProperties(by: .priceLowToHigh)
        })
        
        actionSheet.addAction(UIAlertAction(title: "Price: High to Low", style: .default) { _ in
            self.sortProperties(by: .priceHighToLow)
        })
        
        actionSheet.addAction(UIAlertAction(title: "Recently Added", style: .default) { _ in
            self.sortProperties(by: .recentlyAdded)
        })
        
        actionSheet.addAction(UIAlertAction(title: "Rating", style: .default) { _ in
            self.sortProperties(by: .rating)
        })
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = sortButton
            popover.sourceRect = sortButton.bounds
        }
        
        present(actionSheet, animated: true)
    }
    
    @objc private func refreshProperties() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.loadProperties()
            self.tableView.refreshControl?.endRefreshing()
        }
    }
    
    func filterByCategory(_ category: String) {
        // Set the appropriate scope button
        switch category.lowercased() {
        case "studios":
            searchController.searchBar.selectedScopeButtonIndex = 1
        case "1 bedroom":
            searchController.searchBar.selectedScopeButtonIndex = 2
        case "2+ bedrooms":
            searchController.searchBar.selectedScopeButtonIndex = 3
        case "luxury":
            searchController.searchBar.selectedScopeButtonIndex = 4
        default:
            searchController.searchBar.selectedScopeButtonIndex = 0
        }
        
        // Apply the filter
        filterProperties(with: searchController.searchBar.text ?? "")
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - UISearchResultsUpdating & UISearchControllerDelegate
extension SearchViewController: UISearchResultsUpdating, UISearchControllerDelegate {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        filterProperties(with: searchText)
    }
    
    func willPresentSearchController(_ searchController: UISearchController) {
        showSuggestions()
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        hideSuggestions()
    }
}

// MARK: - UISearchBarDelegate
extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        filterProperties(with: searchBar.text ?? "")
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        showSuggestions()
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if searchBar.text?.isEmpty ?? true {
            hideSuggestions()
        }
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension SearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == suggestionsTableView {
            return searchSuggestions.count
        }
        return filteredProperties.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == suggestionsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
            cell.textLabel?.text = searchSuggestions[indexPath.row]
            cell.textLabel?.font = .systemFont(ofSize: 16, weight: .medium)
            cell.textLabel?.textColor = AppColors.textPrimary
            cell.backgroundColor = .clear
            cell.imageView?.image = UIImage(systemName: "magnifyingglass")
            cell.imageView?.tintColor = AppColors.primaryPurple
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "PropertyCell", for: indexPath) as! PropertyTableViewCell
        cell.configure(with: filteredProperties[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if tableView == suggestionsTableView {
            let suggestion = searchSuggestions[indexPath.row]
            searchController.searchBar.text = suggestion
            filterProperties(with: suggestion)
            hideSuggestions()
            
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            return
        }
        
        let property = filteredProperties[indexPath.row]
        let detailVC = PropertyDetailViewController(property: property)
        navigationController?.pushViewController(detailVC, animated: true)
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if tableView == suggestionsTableView {
            return 44
        }
        return 280
    }
    
    // Add swipe actions for property cells
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if tableView == suggestionsTableView {
            return nil
        }
        
        let favoriteAction = UIContextualAction(style: .normal, title: "Favorite") { [weak self] (_, _, completion) in
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Handle favorite action
            completion(true)
        }
        favoriteAction.backgroundColor = AppColors.errorRed
        favoriteAction.image = UIImage(systemName: "heart.fill")
        
        let shareAction = UIContextualAction(style: .normal, title: "Share") { [weak self] (_, _, completion) in
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Handle share action
            let property = self?.filteredProperties[indexPath.row]
            let shareText = "Check out this property: \(property?.title ?? "")"
            let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
            self?.present(activityVC, animated: true)
            
            completion(true)
        }
        shareAction.backgroundColor = AppColors.accentBlue
        shareAction.image = UIImage(systemName: "square.and.arrow.up")
        
        return UISwipeActionsConfiguration(actions: [favoriteAction, shareAction])
    }
}

// MARK: - PropertyModel
struct PropertyModel {
    let id: String
    let title: String
    let price: Int
    let location: String
    let bedrooms: Int
    let bathrooms: Int
    let amenities: [String]
    var imageURL: String = "photo"
    var rating: Double = 4.5
    var isVerified: Bool = false
    
    init(id: String, title: String, price: Int, location: String, bedrooms: Int, bathrooms: Int, amenities: [String], imageURL: String = "photo", rating: Double = 4.5, isVerified: Bool = false) {
        self.id = id
        self.title = title
        self.price = price
        self.location = location
        self.bedrooms = bedrooms
        self.bathrooms = bathrooms
        self.amenities = amenities
        self.imageURL = imageURL
        self.rating = rating
        self.isVerified = isVerified
    }
    
    func filterByCategory(_ category: String) {
        // Method for filtering by category
    }
}

// MARK: - PropertyTableViewCell
class PropertyTableViewCell: UITableViewCell {
    
    private let cardView = UIView()
    private let propertyImageView = UIImageView()
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let locationLabel = UILabel()
    private let detailsLabel = UILabel()
    private let amenitiesStackView = UIStackView()
    private let favoriteButton = UIButton(type: .system)
    
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
        
        // Card view
        cardView.backgroundColor = AppColors.cardBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.1
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 12
        
        // Property image
        propertyImageView.backgroundColor = AppColors.separatorColor
        propertyImageView.contentMode = .scaleAspectFill
        propertyImageView.clipsToBounds = true
        propertyImageView.layer.cornerRadius = 12
        propertyImageView.image = UIImage(systemName: "photo")
        propertyImageView.tintColor = AppColors.textSecondary
        
        // Title
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.numberOfLines = 2
        
        // Price
        priceLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        priceLabel.textColor = AppColors.primaryPurple
        
        // Location
        locationLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        locationLabel.textColor = AppColors.textSecondary
        
        // Details
        detailsLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        detailsLabel.textColor = AppColors.textSecondary
        
        // Amenities
        amenitiesStackView.axis = .horizontal
        amenitiesStackView.spacing = 8
        amenitiesStackView.distribution = .fill
        
        // Favorite button
        favoriteButton.setImage(UIImage(systemName: "heart"), for: .normal)
        favoriteButton.setImage(UIImage(systemName: "heart.fill"), for: .selected)
        favoriteButton.tintColor = AppColors.errorRed
        favoriteButton.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        favoriteButton.layer.cornerRadius = 20
        favoriteButton.layer.shadowColor = UIColor.black.cgColor
        favoriteButton.layer.shadowOpacity = 0.2
        favoriteButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        favoriteButton.layer.shadowRadius = 4
        
        contentView.addSubview(cardView)
        cardView.addSubview(propertyImageView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(priceLabel)
        cardView.addSubview(locationLabel)
        cardView.addSubview(detailsLabel)
        cardView.addSubview(amenitiesStackView)
        cardView.addSubview(favoriteButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        propertyImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        locationLabel.translatesAutoresizingMaskIntoConstraints = false
        detailsLabel.translatesAutoresizingMaskIntoConstraints = false
        amenitiesStackView.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            propertyImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            propertyImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            propertyImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            propertyImageView.heightAnchor.constraint(equalToConstant: 160),
            
            favoriteButton.topAnchor.constraint(equalTo: propertyImageView.topAnchor, constant: 12),
            favoriteButton.trailingAnchor.constraint(equalTo: propertyImageView.trailingAnchor, constant: -12),
            favoriteButton.widthAnchor.constraint(equalToConstant: 40),
            favoriteButton.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.topAnchor.constraint(equalTo: propertyImageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: priceLabel.leadingAnchor, constant: -8),
            
            priceLabel.topAnchor.constraint(equalTo: propertyImageView.bottomAnchor, constant: 12),
            priceLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            priceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            locationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            locationLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            
            detailsLabel.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 4),
            detailsLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            
            amenitiesStackView.topAnchor.constraint(equalTo: detailsLabel.bottomAnchor, constant: 8),
            amenitiesStackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            amenitiesStackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            amenitiesStackView.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with property: PropertyModel) {
        titleLabel.text = property.title
        priceLabel.text = "$\(property.price)/mo"
        locationLabel.text = "📍 \(property.location)"
        detailsLabel.text = "\(property.bedrooms) bed • \(property.bathrooms) bath"
        
        // Clear previous amenities
        amenitiesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add amenity badges
        for amenity in property.amenities.prefix(3) {
            let badge = createAmenityBadge(text: amenity)
            amenitiesStackView.addArrangedSubview(badge)
        }
        
        if property.amenities.count > 3 {
            let moreBadge = createAmenityBadge(text: "+\(property.amenities.count - 3) more")
            amenitiesStackView.addArrangedSubview(moreBadge)
        }
    }
    
    private func createAmenityBadge(text: String) -> UIView {
        let badge = UIView()
        badge.backgroundColor = AppColors.primaryPurple.withAlphaComponent(0.1)
        badge.layer.cornerRadius = 12
        
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = AppColors.primaryPurple
        label.textAlignment = .center
        
        badge.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: badge.topAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -6),
            badge.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return badge
    }
}