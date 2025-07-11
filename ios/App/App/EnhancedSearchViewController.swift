import UIKit
import MapKit

class EnhancedSearchViewController: UIViewController {
    
    // MARK: - UI Components
    private let searchController = UISearchController(searchResultsController: nil)
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Header Section
    private let headerView = UIView()
    private let searchStatsLabel = UILabel()
    private let sortButton = UIButton(type: .system)
    private let viewToggleSegment = UISegmentedControl(items: ["List", "Map"])
    
    // Quick Filters
    private let quickFiltersScrollView = UIScrollView()
    private let quickFiltersStackView = UIStackView()
    
    // Main Content
    private let collectionView: UICollectionView
    private let mapView = MKMapView()
    private let noResultsView = UIView()
    
    // Filter & Actions
    private let filterButton = UIButton(type: .system)
    
    // Data
    var selectedCategory: String?
    private var isMapView = false
    private var properties: [Property] = []
    private var filteredProperties: [Property] = []
    private var currentSearchQuery: String = ""
    private var currentFilters: SearchFilters?
    private var activeQuickFilters: Set<String> = []
    
    // Location
    private let locationManager = CLLocationManager()
    private var userLocation: CLLocation?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width - 32, height: 160)
        layout.minimumLineSpacing = Theme.Spacing.lg
        layout.sectionInset = UIEdgeInsets(top: Theme.Spacing.lg, left: Theme.Spacing.lg, bottom: Theme.Spacing.lg, right: Theme.Spacing.lg)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSearchController()
        setupQuickFilters()
        setupMapView()
        setupLocationManager()
        setupConstraints()
        
        if let category = selectedCategory {
            title = category
            searchPropertiesByCategory(category)
        } else {
            loadProperties()
        }
        
        animateOnAppear()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.applyGradient(colors: Theme.Colors.gradientBackground, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1))
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Browse Properties"
        
        // Scroll View Setup
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Header Section
        setupHeaderSection()
        setupMainContent()
        setupNoResultsView()
        
        // Add all subviews to content view
        [headerView, quickFiltersScrollView, collectionView, mapView, noResultsView].forEach {
            contentView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        // Initially hide map view
        mapView.isHidden = true
        noResultsView.isHidden = true
    }
    
    private func setupHeaderSection() {
        headerView.applyGlassEffect(alpha: 0.95)
        
        // Search Stats
        searchStatsLabel.text = "Loading properties..."
        searchStatsLabel.font = Theme.Fonts.body
        searchStatsLabel.textColor = Theme.Colors.textSecondary
        searchStatsLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(searchStatsLabel)
        
        // Sort Button
        sortButton.setTitle("Sort by Price", for: .normal)
        sortButton.setImage(UIImage(systemName: "arrow.up.arrow.down"), for: .normal)
        sortButton.applySecondaryButtonStyle()
        sortButton.addTarget(self, action: #selector(sortTapped), for: .touchUpInside)
        sortButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(sortButton)
        
        // View Toggle
        viewToggleSegment.selectedSegmentIndex = 0
        viewToggleSegment.addTarget(self, action: #selector(viewToggleChanged), for: .valueChanged)
        viewToggleSegment.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(viewToggleSegment)
        
        // Filter Button
        filterButton.setTitle("Filters", for: .normal)
        filterButton.setImage(UIImage(systemName: "slider.horizontal.3"), for: .normal)
        filterButton.applyPrimaryButtonStyle()
        filterButton.addTarget(self, action: #selector(filterTapped), for: .touchUpInside)
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(filterButton)
        
        // Header Constraints
        NSLayoutConstraint.activate([
            searchStatsLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: Theme.Spacing.md),
            searchStatsLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: Theme.Spacing.lg),
            
            sortButton.centerYAnchor.constraint(equalTo: searchStatsLabel.centerYAnchor),
            sortButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            viewToggleSegment.topAnchor.constraint(equalTo: searchStatsLabel.bottomAnchor, constant: Theme.Spacing.md),
            viewToggleSegment.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: Theme.Spacing.lg),
            
            filterButton.centerYAnchor.constraint(equalTo: viewToggleSegment.centerYAnchor),
            filterButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -Theme.Spacing.lg),
            filterButton.widthAnchor.constraint(equalToConstant: 100),
            
            headerView.bottomAnchor.constraint(equalTo: viewToggleSegment.bottomAnchor, constant: Theme.Spacing.md)
        ])
    }
    
    private func setupMainContent() {
        collectionView.backgroundColor = .clear
        collectionView.register(EnhancedPropertyCell.self, forCellWithReuseIdentifier: "PropertyCell")
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search by location, price, or type"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }
    
    private func setupQuickFilters() {
        quickFiltersScrollView.showsHorizontalScrollIndicator = false
        
        quickFiltersStackView.axis = .horizontal
        quickFiltersStackView.spacing = Theme.Spacing.sm
        quickFiltersStackView.translatesAutoresizingMaskIntoConstraints = false
        quickFiltersScrollView.addSubview(quickFiltersStackView)
        
        let quickFilters = ["Studio", "1 BR", "2 BR", "3+ BR", "Pet Friendly", "Parking", "Gym", "Pool", "Under $2000", "Luxury"]
        
        for filter in quickFilters {
            let button = createQuickFilterButton(title: filter)
            quickFiltersStackView.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            quickFiltersStackView.topAnchor.constraint(equalTo: quickFiltersScrollView.topAnchor),
            quickFiltersStackView.leadingAnchor.constraint(equalTo: quickFiltersScrollView.leadingAnchor, constant: Theme.Spacing.lg),
            quickFiltersStackView.trailingAnchor.constraint(equalTo: quickFiltersScrollView.trailingAnchor, constant: -Theme.Spacing.lg),
            quickFiltersStackView.bottomAnchor.constraint(equalTo: quickFiltersScrollView.bottomAnchor),
            quickFiltersStackView.heightAnchor.constraint(equalTo: quickFiltersScrollView.heightAnchor)
        ])
    }
    
    private func createQuickFilterButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = Theme.Fonts.caption1
        button.layer.cornerRadius = Theme.CornerRadius.small
        button.layer.borderWidth = 1
        button.layer.borderColor = Theme.Colors.border.cgColor
        button.backgroundColor = Theme.Colors.surface
        button.setTitleColor(Theme.Colors.textPrimary, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.addTarget(self, action: #selector(quickFilterTapped(_:)), for: .touchUpInside)
        return button
    }
    
    @objc private func quickFilterTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        
        if activeQuickFilters.contains(title) {
            activeQuickFilters.remove(title)
            sender.backgroundColor = Theme.Colors.surface
            sender.setTitleColor(Theme.Colors.textPrimary, for: .normal)
            sender.layer.borderColor = Theme.Colors.border.cgColor
        } else {
            activeQuickFilters.insert(title)
            sender.applyGradient(colors: Theme.Colors.gradientPrimary)
            sender.setTitleColor(Theme.Colors.textOnPrimary, for: .normal)
            sender.layer.borderColor = UIColor.clear.cgColor
        }
        
        applyQuickFilters()
    }
    
    private func setupMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func setupNoResultsView() {
        let imageView = UIImageView(image: UIImage(systemName: "house.slash"))
        imageView.tintColor = Theme.Colors.textSecondary
        imageView.translatesAutoresizingMaskIntoConstraints = false
        noResultsView.addSubview(imageView)
        
        let titleLabel = UILabel()
        titleLabel.text = "No Properties Found"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        noResultsView.addSubview(titleLabel)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Try adjusting your search criteria or filters"
        subtitleLabel.font = Theme.Fonts.body
        subtitleLabel.textColor = Theme.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        noResultsView.addSubview(subtitleLabel)
        
        let clearFiltersButton = UIButton(type: .system)
        clearFiltersButton.setTitle("Clear All Filters", for: .normal)
        clearFiltersButton.applySecondaryButtonStyle()
        clearFiltersButton.addTarget(self, action: #selector(clearAllFilters), for: .touchUpInside)
        clearFiltersButton.translatesAutoresizingMaskIntoConstraints = false
        noResultsView.addSubview(clearFiltersButton)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: noResultsView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: noResultsView.centerYAnchor, constant: -80),
            imageView.widthAnchor.constraint(equalToConstant: 80),
            imageView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: Theme.Spacing.lg),
            titleLabel.leadingAnchor.constraint(equalTo: noResultsView.leadingAnchor, constant: Theme.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: noResultsView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.sm),
            subtitleLabel.leadingAnchor.constraint(equalTo: noResultsView.leadingAnchor, constant: Theme.Spacing.lg),
            subtitleLabel.trailingAnchor.constraint(equalTo: noResultsView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            clearFiltersButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: Theme.Spacing.xl),
            clearFiltersButton.centerXAnchor.constraint(equalTo: noResultsView.centerXAnchor),
            clearFiltersButton.widthAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    @objc private func clearAllFilters() {
        currentFilters = nil
        activeQuickFilters.removeAll()
        
        // Reset all quick filter buttons
        for view in quickFiltersStackView.arrangedSubviews {
            if let button = view as? UIButton {
                button.backgroundColor = Theme.Colors.surface
                button.setTitleColor(Theme.Colors.textPrimary, for: .normal)
                button.layer.borderColor = Theme.Colors.border.cgColor
            }
        }
        
        loadProperties()
    }
    
    private func animateOnAppear() {
        let views = [headerView, quickFiltersScrollView, collectionView]
        
        for (index, view) in views.enumerated() {
            view.transform = CGAffineTransform(translationX: 0, y: 30)
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
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Header View
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // Quick Filters
            quickFiltersScrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: Theme.Spacing.sm),
            quickFiltersScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            quickFiltersScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            quickFiltersScrollView.heightAnchor.constraint(equalToConstant: 44),
            
            // Collection View
            collectionView.topAnchor.constraint(equalTo: quickFiltersScrollView.bottomAnchor, constant: Theme.Spacing.sm),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 600),
            
            // Map View
            mapView.topAnchor.constraint(equalTo: quickFiltersScrollView.bottomAnchor, constant: Theme.Spacing.sm),
            mapView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mapView.heightAnchor.constraint(equalToConstant: 600),
            
            // No Results View
            noResultsView.topAnchor.constraint(equalTo: quickFiltersScrollView.bottomAnchor, constant: Theme.Spacing.sm),
            noResultsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            noResultsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            noResultsView.heightAnchor.constraint(equalToConstant: 400),
            
            // Content bottom
            contentView.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: Theme.Spacing.xl)
        ])
    }
    
    @objc private func filterTapped() {
        let filterVC = FilterViewController()
        filterVC.delegate = self
        let navController = UINavigationController(rootViewController: filterVC)
        present(navController, animated: true)
    }
    
    @objc private func viewToggleChanged() {
        isMapView = viewToggleSegment.selectedSegmentIndex == 1
        
        UIView.animate(withDuration: Theme.Animation.standard) {
            self.collectionView.alpha = self.isMapView ? 0 : 1
            self.mapView.alpha = self.isMapView ? 1 : 0
        } completion: { _ in
            self.collectionView.isHidden = self.isMapView
            self.mapView.isHidden = !self.isMapView
            
            if self.isMapView {
                self.updateMapAnnotations()
            }
        }
    }
    
    @objc private func sortTapped() {
        let alert = UIAlertController(title: "Sort Properties", message: "Choose sorting option", preferredStyle: .actionSheet)
        
        let sortOptions = [
            ("Price: Low to High", "price_asc"),
            ("Price: High to Low", "price_desc"),
            ("Newest First", "date_desc"),
            ("Bedrooms", "bedrooms_desc"),
            ("Square Feet", "sqft_desc")
        ]
        
        for (title, sortKey) in sortOptions {
            alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                self.applySorting(sortKey)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sortButton
            popover.sourceRect = sortButton.bounds
        }
        
        present(alert, animated: true)
    }
}

// MARK: - UISearchResultsUpdating
extension EnhancedSearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearch), object: nil)
        currentSearchQuery = searchText
        perform(#selector(performSearch), with: nil, afterDelay: 0.5)
    }
    
    @objc private func performSearch() {
        if currentSearchQuery.isEmpty {
            loadProperties()
        } else {
            searchProperties(query: currentSearchQuery)
        }
    }
}

// MARK: - Collection View Data Source & Delegate
extension EnhancedSearchViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredProperties.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PropertyCell", for: indexPath) as! EnhancedPropertyCell
        if indexPath.item < filteredProperties.count {
            cell.configure(with: filteredProperties[indexPath.item])
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let property = filteredProperties[indexPath.item]
        let detailVC = PropertyDetailViewController()
        detailVC.property = property
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Data Loading Methods
extension EnhancedSearchViewController {
    private func loadProperties() {
        print("🔍 Loading properties from API...")
        APIService.shared.fetchProperties { [weak self] result in
            switch result {
            case .success(let properties):
                print("✅ Successfully loaded \(properties.count) properties from API")
                self?.properties = properties
                self?.updateUI()
            case .failure(let error):
                print("❌ Error loading properties: \(error)")
                print("🔄 Falling back to sample data")
                self?.loadSampleData()
            }
        }
    }
    
    private func searchProperties(query: String) {
        print("🔍 Searching properties with query: '\(query)'")
        APIService.shared.searchProperties(query: query, filters: currentFilters) { [weak self] result in
            switch result {
            case .success(let properties):
                print("✅ Successfully found \(properties.count) properties matching search")
                self?.properties = properties
                self?.updateUI()
            case .failure(let error):
                print("❌ Error searching properties: \(error)")
                print("🔄 Falling back to sample data")
                self?.loadSampleData()
            }
        }
    }
    
    private func searchPropertiesByCategory(_ category: String) {
        print("🏠 Searching properties by category: '\(category)'")
        let filters = SearchFilters(
            minPrice: nil,
            maxPrice: nil,
            bedrooms: nil,
            bathrooms: nil,
            propertyType: category,
            city: nil,
            amenities: nil,
            sortBy: nil,
            sortOrder: nil
        )
        
        APIService.shared.searchProperties(query: "", filters: filters) { [weak self] result in
            switch result {
            case .success(let properties):
                print("✅ Successfully found \(properties.count) properties in category '\(category)'")
                self?.properties = properties
                self?.updateUI()
            case .failure(let error):
                print("❌ Error searching by category: \(error)")
                print("🔄 Falling back to sample data")
                self?.loadSampleData()
            }
        }
    }
    
    private func loadSampleData() {
        let sampleProperties = [
            Property(
                id: "1",
                title: "Modern Downtown Apartment",
                description: "Beautiful 2BR/2BA apartment in downtown with city views",
                address: "123 Main Street",
                city: "New York",
                state: "NY",
                zipCode: "10001",
                price: 2500.0,
                bedrooms: 2,
                bathrooms: 2,
                sqft: 1200,
                propertyType: "Apartment",
                images: ["https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400&h=250&fit=crop"],
                amenities: ["Parking", "Gym", "Pool"],
                latitude: 40.7128,
                longitude: -74.0060,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z",
                isFavorite: false
            ),
            Property(
                id: "2",
                title: "Luxury Studio Loft",
                description: "Spacious studio with exposed brick and modern amenities",
                address: "456 Brooklyn Ave",
                city: "Brooklyn",
                state: "NY",
                zipCode: "11201",
                price: 1800.0,
                bedrooms: 1,
                bathrooms: 1,
                sqft: 800,
                propertyType: "Studio",
                images: ["https://images.unsplash.com/photo-1560449752-c40dfffbdab9?w=400&h=250&fit=crop"],
                amenities: ["Laundry", "Parking", "Rooftop"],
                latitude: 40.6892,
                longitude: -73.9442,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z",
                isFavorite: true
            ),
            Property(
                id: "3",
                title: "Cozy Family House",
                description: "3BR house with backyard in quiet neighborhood",
                address: "789 Oak Street",
                city: "Austin",
                state: "TX",
                zipCode: "73301",
                price: 3200.0,
                bedrooms: 3,
                bathrooms: 2,
                sqft: 1800,
                propertyType: "House",
                images: ["https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=400&h=250&fit=crop"],
                amenities: ["Garden", "Parking", "Pet Friendly"],
                latitude: 30.2672,
                longitude: -97.7431,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z",
                isFavorite: false
            )
        ]
        
        properties = sampleProperties + sampleProperties + sampleProperties
        updateUI()
    }
    
    private func updateUI() {
        filteredProperties = applyCurrentFilters(to: properties)
        
        DispatchQueue.main.async {
            self.searchStatsLabel.text = "\(self.filteredProperties.count) properties found"
            self.collectionView.reloadData()
            
            self.noResultsView.isHidden = !self.filteredProperties.isEmpty
            self.collectionView.isHidden = self.filteredProperties.isEmpty || self.isMapView
            
            if self.isMapView {
                self.updateMapAnnotations()
            }
        }
    }
    
    private func applyCurrentFilters(to properties: [Property]) -> [Property] {
        var filtered = properties
        
        if !currentSearchQuery.isEmpty {
            filtered = filtered.filter { property in
                property.title.localizedCaseInsensitiveContains(currentSearchQuery) ||
                property.city.localizedCaseInsensitiveContains(currentSearchQuery) ||
                property.address.localizedCaseInsensitiveContains(currentSearchQuery) ||
                property.propertyType.localizedCaseInsensitiveContains(currentSearchQuery)
            }
        }
        
        for filter in activeQuickFilters {
            filtered = applyQuickFilter(filter, to: filtered)
        }
        
        if let filters = currentFilters {
            filtered = applyAdvancedFilters(filters, to: filtered)
        }
        
        return filtered
    }
    
    private func applyQuickFilter(_ filter: String, to properties: [Property]) -> [Property] {
        switch filter {
        case "Studio":
            return properties.filter { $0.bedrooms == 0 || $0.propertyType.lowercased().contains("studio") }
        case "1 BR":
            return properties.filter { $0.bedrooms == 1 }
        case "2 BR":
            return properties.filter { $0.bedrooms == 2 }
        case "3+ BR":
            return properties.filter { $0.bedrooms >= 3 }
        case "Pet Friendly":
            return properties.filter { $0.amenities.contains { $0.lowercased().contains("pet") } }
        case "Parking":
            return properties.filter { $0.amenities.contains { $0.lowercased().contains("parking") } }
        case "Gym":
            return properties.filter { $0.amenities.contains { $0.lowercased().contains("gym") } }
        case "Pool":
            return properties.filter { $0.amenities.contains { $0.lowercased().contains("pool") } }
        case "Under $2000":
            return properties.filter { $0.price < 2000 }
        case "Luxury":
            return properties.filter { $0.price > 3000 }
        default:
            return properties
        }
    }
    
    private func applyAdvancedFilters(_ filters: SearchFilters, to properties: [Property]) -> [Property] {
        var filtered = properties
        
        if let minPrice = filters.minPrice {
            filtered = filtered.filter { $0.price >= minPrice }
        }
        
        if let maxPrice = filters.maxPrice {
            filtered = filtered.filter { $0.price <= maxPrice }
        }
        
        if let bedrooms = filters.bedrooms {
            filtered = filtered.filter { $0.bedrooms >= bedrooms }
        }
        
        if let bathrooms = filters.bathrooms {
            filtered = filtered.filter { $0.bathrooms >= bathrooms }
        }
        
        if let propertyType = filters.propertyType, !propertyType.isEmpty {
            filtered = filtered.filter { $0.propertyType.lowercased().contains(propertyType.lowercased()) }
        }
        
        if let city = filters.city, !city.isEmpty {
            filtered = filtered.filter { $0.city.localizedCaseInsensitiveContains(city) }
        }
        
        return filtered
    }
    
    private func applySorting(_ sortKey: String) {
        switch sortKey {
        case "price_asc":
            filteredProperties.sort { $0.price < $1.price }
            sortButton.setTitle("Price: Low to High", for: .normal)
        case "price_desc":
            filteredProperties.sort { $0.price > $1.price }
            sortButton.setTitle("Price: High to Low", for: .normal)
        case "date_desc":
            filteredProperties.sort { $0.createdAt > $1.createdAt }
            sortButton.setTitle("Newest First", for: .normal)
        case "bedrooms_desc":
            filteredProperties.sort { $0.bedrooms > $1.bedrooms }
            sortButton.setTitle("By Bedrooms", for: .normal)
        case "sqft_desc":
            filteredProperties.sort { $0.sqft > $1.sqft }
            sortButton.setTitle("By Square Feet", for: .normal)
        default:
            break
        }
        
        collectionView.reloadData()
    }
    
    private func applyQuickFilters() {
        updateUI()
    }
    
    private func updateMapAnnotations() {
        mapView.removeAnnotations(mapView.annotations)
        
        for property in filteredProperties {
            let annotation = PropertyAnnotation(property: property)
            mapView.addAnnotation(annotation)
        }
        
        if !filteredProperties.isEmpty {
            let coordinates = filteredProperties.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let region = regionFor(coordinates: coordinates)
            mapView.setRegion(region, animated: true)
        }
    }
    
    private func regionFor(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060), latitudinalMeters: 10000, longitudinalMeters: 10000)
        }
        
        let minLat = coordinates.map { $0.latitude }.min()!
        let maxLat = coordinates.map { $0.latitude }.max()!
        let minLon = coordinates.map { $0.longitude }.min()!
        let maxLon = coordinates.map { $0.longitude }.max()!
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Filter Delegate
extension EnhancedSearchViewController: FilterViewControllerDelegate {
    func didApplyFilters(_ filters: [String: Any]) {
        let searchFilters = SearchFilters(
            minPrice: filters["minPrice"] as? Double,
            maxPrice: filters["maxPrice"] as? Double,
            bedrooms: filters["bedrooms"] as? Int,
            bathrooms: filters["bathrooms"] as? Int,
            propertyType: filters["propertyType"] as? String,
            city: filters["city"] as? String,
            amenities: filters["amenities"] as? [String],
            sortBy: filters["sortBy"] as? String,
            sortOrder: filters["sortOrder"] as? String
        )
        
        currentFilters = searchFilters
        
        if currentSearchQuery.isEmpty {
            loadProperties()
        } else {
            searchProperties(query: currentSearchQuery)
        }
    }
}

// MARK: - Map View Delegate
extension EnhancedSearchViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let propertyAnnotation = annotation as? PropertyAnnotation else { return nil }
        
        let identifier = "PropertyPin"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
            annotationView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        } else {
            annotationView?.annotation = annotation
        }
        
        annotationView?.markerTintColor = Theme.Colors.primary
        annotationView?.glyphText = "$\(Int(propertyAnnotation.property.price))"
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        guard let propertyAnnotation = view.annotation as? PropertyAnnotation else { return }
        
        let detailVC = PropertyDetailViewController()
        detailVC.property = propertyAnnotation.property
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Location Manager Delegate
extension EnhancedSearchViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}

// MARK: - Property Annotation
class PropertyAnnotation: NSObject, MKAnnotation {
    let property: Property
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(property: Property) {
        self.property = property
        self.coordinate = CLLocationCoordinate2D(latitude: property.latitude, longitude: property.longitude)
        self.title = property.title
        self.subtitle = "$\(Int(property.price))/month"
        super.init()
    }
}

// MARK: - Enhanced Property Cell
class EnhancedPropertyCell: UICollectionViewCell {
    private let containerView = UIView()
    private let imageView = UIImageView()
    private let favoriteButton = UIButton(type: .system)
    private let priceLabel = UILabel()
    private let titleLabel = UILabel()
    private let locationLabel = UILabel()
    private let detailsStackView = UIStackView()
    private let bedroomLabel = UILabel()
    private let bathroomLabel = UILabel()
    private let sqftLabel = UILabel()
    private let amenitiesLabel = UILabel()
    
    private var property: Property?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.backgroundColor = .clear
        
        containerView.applyPremiumCardStyle()
        containerView.backgroundColor = Theme.Colors.surface
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Theme.CornerRadius.medium
        imageView.backgroundColor = Theme.Colors.surfaceSecondary
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        
        favoriteButton.setImage(UIImage(systemName: "heart"), for: .normal)
        favoriteButton.setImage(UIImage(systemName: "heart.fill"), for: .selected)
        favoriteButton.tintColor = Theme.Colors.error
        favoriteButton.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        favoriteButton.layer.cornerRadius = 20
        favoriteButton.addTarget(self, action: #selector(favoriteToggled), for: .touchUpInside)
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(favoriteButton)
        
        priceLabel.font = Theme.Fonts.title2
        priceLabel.textColor = Theme.Colors.primary
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(priceLabel)
        
        titleLabel.font = Theme.Fonts.headline
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        locationLabel.font = Theme.Fonts.callout
        locationLabel.textColor = Theme.Colors.textSecondary
        locationLabel.numberOfLines = 1
        locationLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(locationLabel)
        
        detailsStackView.axis = .horizontal
        detailsStackView.distribution = .fillEqually
        detailsStackView.spacing = Theme.Spacing.sm
        detailsStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(detailsStackView)
        
        [bedroomLabel, bathroomLabel, sqftLabel].forEach { label in
            label.font = Theme.Fonts.caption1
            label.textColor = Theme.Colors.textSecondary
            label.textAlignment = .center
            detailsStackView.addArrangedSubview(label)
        }
        
        amenitiesLabel.font = Theme.Fonts.caption2
        amenitiesLabel.textColor = Theme.Colors.textSecondary
        amenitiesLabel.numberOfLines = 1
        amenitiesLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(amenitiesLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Theme.Spacing.sm),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Theme.Spacing.sm),
            imageView.widthAnchor.constraint(equalToConstant: 120),
            imageView.heightAnchor.constraint(equalToConstant: 90),
            
            favoriteButton.topAnchor.constraint(equalTo: imageView.topAnchor, constant: Theme.Spacing.xs),
            favoriteButton.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -Theme.Spacing.xs),
            favoriteButton.widthAnchor.constraint(equalToConstant: 40),
            favoriteButton.heightAnchor.constraint(equalToConstant: 40),
            
            priceLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Theme.Spacing.sm),
            priceLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: Theme.Spacing.md),
            priceLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Theme.Spacing.sm),
            
            titleLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: Theme.Spacing.xs),
            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: Theme.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Theme.Spacing.sm),
            
            locationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xs),
            locationLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: Theme.Spacing.md),
            locationLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Theme.Spacing.sm),
            
            detailsStackView.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: Theme.Spacing.sm),
            detailsStackView.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: Theme.Spacing.md),
            detailsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Theme.Spacing.sm),
            
            amenitiesLabel.topAnchor.constraint(equalTo: detailsStackView.bottomAnchor, constant: Theme.Spacing.xs),
            amenitiesLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: Theme.Spacing.md),
            amenitiesLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Theme.Spacing.sm),
            amenitiesLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -Theme.Spacing.sm)
        ])
    }
    
    func configure(with property: Property) {
        self.property = property
        
        priceLabel.text = "$\(Int(property.price))/mo"
        titleLabel.text = property.title
        locationLabel.text = "\(property.city), \(property.state)"
        
        bedroomLabel.text = "\(property.bedrooms) BR"
        bathroomLabel.text = "\(property.bathrooms) BA"
        sqftLabel.text = "\(Int(property.sqft)) sqft"
        
        amenitiesLabel.text = property.amenities.prefix(3).joined(separator: " • ")
        favoriteButton.isSelected = property.isFavorite
        
        if let imageURL = property.images.first, let url = URL(string: imageURL) {
            loadImage(from: url)
        } else {
            imageView.image = UIImage(systemName: "house.fill")
            imageView.tintColor = Theme.Colors.textSecondary
        }
        
        transform = CGAffineTransform(scaleX: 0.95, scaleY: 0.95)
        UIView.animate(withDuration: Theme.Animation.fast) {
            self.transform = .identity
        }
    }
    
    private func loadImage(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.imageView.image = image
                }
            }
        }
    }
    
    @objc private func favoriteToggled() {
        guard var property = property else { return }
        
        property.isFavorite.toggle()
        favoriteButton.isSelected = property.isFavorite
        self.property = property
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        UIView.animate(withDuration: Theme.Animation.fast, 
                       delay: 0,
                       usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.8,
                       options: []) {
            self.favoriteButton.transform = CGAffineTransform(scaleX: 1.2, scaleY: 1.2)
        } completion: { _ in
            UIView.animate(withDuration: Theme.Animation.fast) {
                self.favoriteButton.transform = .identity
            }
        }
    }
}