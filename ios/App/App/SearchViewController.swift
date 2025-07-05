import UIKit

class SearchViewController: UIViewController {
    
    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView()
    private let filterButton = UIButton(type: .system)
    
    private var properties: [PropertyModel] = []
    private var filteredProperties: [PropertyModel] = []
    
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
        
        // Setup filter button
        filterButton.setTitle("Filters", for: .normal)
        filterButton.setImage(UIImage(systemName: "slider.horizontal.3"), for: .normal)
        filterButton.backgroundColor = AppColors.primaryPurple
        filterButton.setTitleColor(.white, for: .normal)
        filterButton.tintColor = .white
        filterButton.layer.cornerRadius = 22
        filterButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        filterButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        filterButton.addTarget(self, action: #selector(filterTapped), for: .touchUpInside)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: filterButton)
    }
    
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search locations, price range..."
        searchController.searchBar.tintColor = AppColors.primaryPurple
        
        // Customize search bar appearance
        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.backgroundColor = AppColors.backgroundColor
        
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
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 100, right: 0)
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadProperties() {
        // Sample data
        properties = [
            PropertyModel(id: "1", title: "Modern Studio in Downtown", price: 850, location: "Downtown", bedrooms: 1, bathrooms: 1, amenities: ["WiFi", "Gym", "Pool"]),
            PropertyModel(id: "2", title: "Cozy 2BR Apartment", price: 1200, location: "Midtown", bedrooms: 2, bathrooms: 1, amenities: ["WiFi", "Parking"]),
            PropertyModel(id: "3", title: "Luxury Penthouse", price: 2500, location: "Upper East", bedrooms: 3, bathrooms: 2, amenities: ["WiFi", "Gym", "Pool", "Concierge"]),
            PropertyModel(id: "4", title: "Student Housing", price: 600, location: "University District", bedrooms: 1, bathrooms: 1, amenities: ["WiFi", "Study Room"]),
            PropertyModel(id: "5", title: "Shared Room", price: 450, location: "Brooklyn", bedrooms: 1, bathrooms: 1, amenities: ["WiFi"]),
        ]
        filteredProperties = properties
        tableView.reloadData()
    }
    
    private func filterProperties(with searchText: String) {
        if searchText.isEmpty {
            filteredProperties = properties
        } else {
            filteredProperties = properties.filter { property in
                property.title.lowercased().contains(searchText.lowercased()) ||
                property.location.lowercased().contains(searchText.lowercased()) ||
                String(property.price).contains(searchText)
            }
        }
        tableView.reloadData()
    }
    
    @objc private func filterTapped() {
        let filterVC = FilterViewController()
        let navController = UINavigationController(rootViewController: filterVC)
        present(navController, animated: true)
    }
}

// MARK: - UISearchResultsUpdating
extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        filterProperties(with: searchText)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension SearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredProperties.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PropertyCell", for: indexPath) as! PropertyTableViewCell
        cell.configure(with: filteredProperties[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let property = filteredProperties[indexPath.row]
        let detailVC = PropertyDetailViewController(property: property)
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 280
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