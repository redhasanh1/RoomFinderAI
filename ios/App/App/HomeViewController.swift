import UIKit

class HomeViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerView = UIView()
    private let appTitleLabel = UILabel()
    private let greetingLabel = UILabel()
    private let searchBar = UISearchBar()
    private let featuredCollectionView: UICollectionView
    private let categoriesCollectionView: UICollectionView
    private let recentListingsTableView = UITableView()
    
    private let sections = ["Featured Properties", "Browse by Category", "Recent Listings"]
    private let categories = ["Apartments", "Houses", "Condos", "Student Housing", "Subleases", "Rooms"]
    private var featuredProperties: [Property] = []
    private var recentProperties: [Property] = []
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        let featuredLayout = UICollectionViewFlowLayout()
        featuredLayout.scrollDirection = .horizontal
        featuredLayout.itemSize = CGSize(width: 300, height: 200)
        featuredLayout.minimumInteritemSpacing = 16
        featuredLayout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        featuredCollectionView = UICollectionView(frame: .zero, collectionViewLayout: featuredLayout)
        
        let categoriesLayout = UICollectionViewFlowLayout()
        categoriesLayout.scrollDirection = .horizontal
        categoriesLayout.itemSize = CGSize(width: 100, height: 120)
        categoriesLayout.minimumInteritemSpacing = 12
        categoriesLayout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        categoriesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: categoriesLayout)
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadData()
        animateOnAppear()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure header
        headerView.backgroundColor = Theme.Colors.primary
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure app title
        appTitleLabel.text = "RoomFinderAI"
        appTitleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        appTitleLabel.textColor = .white
        appTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(appTitleLabel)
        
        // Configure greeting
        greetingLabel.text = "Find Your Perfect Home"
        greetingLabel.font = .systemFont(ofSize: 16, weight: .medium)
        greetingLabel.textColor = .white.withAlphaComponent(0.9)
        greetingLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(greetingLabel)
        
        // Configure search bar
        searchBar.placeholder = "Search properties..."
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.backgroundImage = UIImage()
        
        // Add map button to search bar
        let mapButton = UIButton(type: .system)
        mapButton.setImage(UIImage(systemName: "map"), for: .normal)
        mapButton.tintColor = .white
        mapButton.addTarget(self, action: #selector(mapButtonTapped), for: .touchUpInside)
        searchBar.searchTextField.rightView = mapButton
        searchBar.searchTextField.rightViewMode = .always
        
        // Configure collection views
        featuredCollectionView.backgroundColor = .clear
        featuredCollectionView.showsHorizontalScrollIndicator = false
        featuredCollectionView.register(FeaturedPropertyCell.self, forCellWithReuseIdentifier: "FeaturedCell")
        featuredCollectionView.delegate = self
        featuredCollectionView.dataSource = self
        featuredCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        categoriesCollectionView.backgroundColor = .clear
        categoriesCollectionView.showsHorizontalScrollIndicator = false
        categoriesCollectionView.register(CategoryCell.self, forCellWithReuseIdentifier: "CategoryCell")
        categoriesCollectionView.delegate = self
        categoriesCollectionView.dataSource = self
        categoriesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure table view
        recentListingsTableView.register(PropertyTableViewCell.self, forCellReuseIdentifier: "PropertyCell")
        recentListingsTableView.delegate = self
        recentListingsTableView.dataSource = self
        recentListingsTableView.translatesAutoresizingMaskIntoConstraints = false
        recentListingsTableView.isScrollEnabled = false
        recentListingsTableView.separatorStyle = .none
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(headerView)
        headerView.addSubview(searchBar)
        contentView.addSubview(featuredCollectionView)
        contentView.addSubview(categoriesCollectionView)
        contentView.addSubview(recentListingsTableView)
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
            
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 180),
            
            appTitleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            appTitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            appTitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            greetingLabel.topAnchor.constraint(equalTo: appTitleLabel.bottomAnchor, constant: 4),
            greetingLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            greetingLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            searchBar.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            searchBar.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            searchBar.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            
            featuredCollectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 30),
            featuredCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            featuredCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            featuredCollectionView.heightAnchor.constraint(equalToConstant: 220),
            
            categoriesCollectionView.topAnchor.constraint(equalTo: featuredCollectionView.bottomAnchor, constant: 40),
            categoriesCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            categoriesCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            categoriesCollectionView.heightAnchor.constraint(equalToConstant: 140),
            
            recentListingsTableView.topAnchor.constraint(equalTo: categoriesCollectionView.bottomAnchor, constant: 40),
            recentListingsTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            recentListingsTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            recentListingsTableView.heightAnchor.constraint(equalToConstant: 840), // 6 items * 140 height
            recentListingsTableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func animateOnAppear() {
        // Fade in animation
        view.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1
        }
        
        // Slide up animation for content
        let views = [featuredCollectionView, categoriesCollectionView, recentListingsTableView]
        for (index, view) in views.enumerated() {
            view.transform = CGAffineTransform(translationX: 0, y: 50)
            view.alpha = 0
            
            UIView.animate(withDuration: 0.5, delay: Double(index) * 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
                view.transform = .identity
                view.alpha = 1
            }
        }
    }
}

// MARK: - Collection View Data Source
extension HomeViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == featuredCollectionView {
            return featuredProperties.count
        } else if collectionView == categoriesCollectionView {
            return categories.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == featuredCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FeaturedCell", for: indexPath) as! FeaturedPropertyCell
            if indexPath.item < featuredProperties.count {
                cell.configure(with: featuredProperties[indexPath.item])
            }
            return cell
        } else if collectionView == categoriesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
            cell.configure(with: categories[indexPath.item])
            return cell
        }
        return UICollectionViewCell()
    }
}

// MARK: - Collection View Delegate
extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == categoriesCollectionView {
            let searchVC = SearchViewController()
            searchVC.selectedCategory = categories[indexPath.item]
            navigationController?.pushViewController(searchVC, animated: true)
        }
    }
}

// MARK: - Table View Data Source & Delegate
extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recentProperties.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PropertyCell", for: indexPath) as! PropertyTableViewCell
        if indexPath.row < recentProperties.count {
            cell.configure(with: recentProperties[indexPath.row])
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 140
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let property = recentProperties[indexPath.row]
        let detailVC = PropertyDetailViewController()
        detailVC.property = property
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    private func loadData() {
        print("🚀 HomeViewController: Starting data load...")
        
        // Always load sample data first to show something immediately
        loadSampleData()
        
        // Then try to load real data from API in background
        APIService.shared.fetchProperties(page: 1, limit: 5) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let properties):
                    print("✅ Successfully loaded \(properties.count) real properties from API")
                    if !properties.isEmpty {
                        self?.featuredProperties = properties
                        self?.recentProperties = properties
                        self?.featuredCollectionView.reloadData()
                        self?.recentListingsTableView.reloadData()
                    }
                case .failure(let error):
                    print("❌ Error loading real properties: \(error.localizedDescription)")
                    print("📊 Using sample data as fallback")
                    // Sample data is already loaded, so we're good
                }
            }
        }
    }
    
    private func loadRecentProperties() {
        // Load recent properties from real API
        APIService.shared.fetchProperties(page: 1, limit: 10) { [weak self] result in
            switch result {
            case .success(let properties):
                print("✅ Successfully loaded \(properties.count) recent properties from API")
                self?.recentProperties = properties
                self?.recentListingsTableView.reloadData()
            case .failure(let error):
                print("❌ Error loading recent properties: \(error)")
                // Use sample data as fallback
                self?.loadSampleData()
            }
        }
    }
    
    private func loadSampleData() {
        print("📦 Loading sample data for immediate display...")
        
        // Diverse sample properties with real images
        let properties = [
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
            ),
            Property(
                id: "4",
                title: "Penthouse Suite",
                description: "Luxury penthouse with panoramic city views",
                address: "101 Sky Tower",
                city: "Miami",
                state: "FL",
                zipCode: "33101",
                price: 5500.0,
                bedrooms: 3,
                bathrooms: 3,
                sqft: 2200,
                propertyType: "Condo",
                images: ["https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=400&h=250&fit=crop"],
                amenities: ["Pool", "Gym", "Concierge", "Balcony"],
                latitude: 25.7617,
                longitude: -80.1918,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z",
                isFavorite: false
            ),
            Property(
                id: "5",
                title: "Student Housing",
                description: "Affordable shared accommodation near campus",
                address: "202 University Ave",
                city: "Boston",
                state: "MA",
                zipCode: "02115",
                price: 1200.0,
                bedrooms: 1,
                bathrooms: 1,
                sqft: 600,
                propertyType: "Student Housing",
                images: ["https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=400&h=250&fit=crop"],
                amenities: ["Study Room", "Laundry", "WiFi"],
                latitude: 42.3601,
                longitude: -71.0589,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z",
                isFavorite: true
            ),
            Property(
                id: "6",
                title: "Suburban Townhouse",
                description: "Spacious 4BR townhouse with garage and garden",
                address: "303 Maple Drive",
                city: "Seattle",
                state: "WA",
                zipCode: "98101",
                price: 4000.0,
                bedrooms: 4,
                bathrooms: 3,
                sqft: 2400,
                propertyType: "Townhouse",
                images: ["https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400&h=250&fit=crop"],
                amenities: ["Garage", "Garden", "Fireplace"],
                latitude: 47.6062,
                longitude: -122.3321,
                createdAt: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z",
                isFavorite: false
            )
        ]
        
        featuredProperties = Array(properties.shuffled().prefix(5))
        recentProperties = properties.shuffled()
        
        featuredCollectionView.reloadData()
        recentListingsTableView.reloadData()
    }
    
    @objc private func mapButtonTapped() {
        let mapVC = MapViewController()
        navigationController?.pushViewController(mapVC, animated: true)
    }
}