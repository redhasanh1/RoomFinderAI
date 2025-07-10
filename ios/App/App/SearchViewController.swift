import UIKit

class SearchViewController: UIViewController {
    
    private let searchController = UISearchController(searchResultsController: nil)
    private let filterButton = UIButton(type: .system)
    private let collectionView: UICollectionView
    private let mapToggleButton = UIButton(type: .system)
    
    var selectedCategory: String?
    private var isMapView = false
    private var properties: [Property] = []
    private var currentSearchQuery: String = ""
    private var currentFilters: SearchFilters?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width - 32, height: 140)
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
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
        setupConstraints()
        
        if let category = selectedCategory {
            title = category
            searchPropertiesByCategory(category)
        } else {
            loadProperties()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Configure filter button
        filterButton.setTitle("Filters", for: .normal)
        filterButton.setImage(UIImage(systemName: "slider.horizontal.3"), for: .normal)
        filterButton.addTarget(self, action: #selector(filterTapped), for: .touchUpInside)
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure map toggle
        mapToggleButton.setTitle("Map", for: .normal)
        mapToggleButton.setImage(UIImage(systemName: "map"), for: .normal)
        mapToggleButton.addTarget(self, action: #selector(toggleMapView), for: .touchUpInside)
        mapToggleButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure collection view
        collectionView.backgroundColor = .systemBackground
        collectionView.register(PropertyCollectionViewCell.self, forCellWithReuseIdentifier: "PropertyCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        view.addSubview(filterButton)
        view.addSubview(mapToggleButton)
        view.addSubview(collectionView)
    }
    
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search by location, price, or type"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            filterButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            filterButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            filterButton.heightAnchor.constraint(equalToConstant: 44),
            
            mapToggleButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            mapToggleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            mapToggleButton.heightAnchor.constraint(equalToConstant: 44),
            
            collectionView.topAnchor.constraint(equalTo: filterButton.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func filterTapped() {
        let filterVC = FilterViewController()
        filterVC.delegate = self
        let navController = UINavigationController(rootViewController: filterVC)
        present(navController, animated: true)
    }
    
    @objc private func toggleMapView() {
        let mapVC = MapViewController()
        navigationController?.pushViewController(mapVC, animated: true)
    }
}

// MARK: - UISearchResultsUpdating
extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        
        // Cancel previous search after a delay
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearch), object: nil)
        
        currentSearchQuery = searchText
        
        // Perform search after a short delay to avoid excessive API calls
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
extension SearchViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return properties.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PropertyCell", for: indexPath) as! PropertyCollectionViewCell
        if indexPath.item < properties.count {
            cell.configure(with: properties[indexPath.item])
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let property = properties[indexPath.item]
        let detailVC = PropertyDetailViewController()
        detailVC.property = property
        
        // Custom push transition
        let transition = CATransition()
        transition.duration = 0.3
        transition.type = .push
        transition.subtype = .fromRight
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        navigationController?.view.layer.add(transition, forKey: kCATransition)
        
        navigationController?.pushViewController(detailVC, animated: false)
    }
    
    // MARK: - Data Loading Methods
    private func loadProperties() {
        print("🔍 Loading properties from API...")
        APIService.shared.fetchProperties { [weak self] result in
            switch result {
            case .success(let properties):
                print("✅ Successfully loaded \(properties.count) properties from API")
                self?.properties = properties
                self?.collectionView.reloadData()
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
                self?.collectionView.reloadData()
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
                self?.collectionView.reloadData()
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
        
        properties = sampleProperties + sampleProperties + sampleProperties // 9 total
        collectionView.reloadData()
    }
}

// MARK: - Filter Delegate
extension SearchViewController: FilterViewControllerDelegate {
    func didApplyFilters(_ filters: [String: Any]) {
        // Convert filters to SearchFilters object
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
        
        // Apply filters to current search
        if currentSearchQuery.isEmpty {
            loadProperties()
        } else {
            searchProperties(query: currentSearchQuery)
        }
    }
}