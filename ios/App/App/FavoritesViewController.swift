import UIKit

class FavoritesViewController: UIViewController {
    
    private let tableView = UITableView()
    private let emptyStateView = EmptyStateView()
    private var favoriteProperties: [Property] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Update empty state message based on current login status
        updateEmptyStateMessage()
        
        loadFavorites()
        animateTableView()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Configure table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PropertyTableViewCell.self, forCellReuseIdentifier: "PropertyCell")
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshFavorites), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        view.addSubview(tableView)
        
        // Configure empty state based on login status
        let title = SessionManager.shared.isSessionValid() ? "No Favorites Yet" : "Login to View Favorites"
        let message = SessionManager.shared.isSessionValid() ? "Properties you favorite will appear here" : "Sign in to sync your favorites across devices"
        let imageName = SessionManager.shared.isSessionValid() ? "heart.slash" : "person.circle"
        
        emptyStateView.configure(
            title: title,
            message: message,
            imageName: imageName
        )
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    private func loadFavorites() {
        // Check if user is logged in
        guard SessionManager.shared.isSessionValid() else {
            favoriteProperties = []
            tableView.reloadData()
            updateEmptyState()
            return
        }
        
        // Use secure API service for authenticated requests
        SecureAPIService.shared.getFavorites { [weak self] result in
            switch result {
            case .success(let properties):
                self?.favoriteProperties = properties
                self?.tableView.reloadData()
                self?.updateEmptyState()
            case .failure(let error):
                print("Error loading favorites: \(error)")
                // Fallback to old API service
                self?.loadFavoritesFromOldAPI()
            }
        }
    }
    
    private func loadFavoritesFromOldAPI() {
        APIService.shared.getFavorites { [weak self] result in
            switch result {
            case .success(let properties):
                self?.favoriteProperties = properties
                self?.tableView.reloadData()
                self?.updateEmptyState()
            case .failure(let error):
                print("Error loading favorites from old API: \(error)")
                // Load sample data for testing
                self?.loadSampleFavorites()
            }
        }
    }
    
    private func loadSampleFavorites() {
        let sampleProperty = Property(
            id: "fav1",
            title: "Favorite Downtown Loft",
            description: "Your saved luxury loft",
            address: "456 Favorite St",
            city: "New York",
            state: "NY",
            zipCode: "10001",
            price: 3000.0,
            bedrooms: 2,
            bathrooms: 2,
            sqft: 1400,
            propertyType: "Loft",
            images: ["https://via.placeholder.com/300x200/8651ED/FFFFFF?text=Favorite+Property"],
            amenities: ["Parking", "Gym", "Pool", "Rooftop"],
            latitude: 40.7128,
            longitude: -74.0060,
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            isFavorite: true
        )
        
        favoriteProperties = [sampleProperty, sampleProperty]
        tableView.reloadData()
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !favoriteProperties.isEmpty
        tableView.isHidden = favoriteProperties.isEmpty
    }
    
    private func updateEmptyStateMessage() {
        let title = SessionManager.shared.isSessionValid() ? "No Favorites Yet" : "Login to View Favorites"
        let message = SessionManager.shared.isSessionValid() ? "Properties you favorite will appear here" : "Sign in to sync your favorites across devices"
        let imageName = SessionManager.shared.isSessionValid() ? "heart.slash" : "person.circle"
        
        emptyStateView.configure(
            title: title,
            message: message,
            imageName: imageName
        )
    }
    
    private func showLoginAlert() {
        let alert = UIAlertController(title: "Login Required", message: "Please log in to manage your favorites", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Login", style: .default) { _ in
            // Navigate to login screen
            let authVC = AuthViewController()
            let navController = UINavigationController(rootViewController: authVC)
            self.present(navController, animated: true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showToast(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        
        // Auto-dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
    
    @objc private func refreshFavorites() {
        loadFavorites()
        
        // End refresh control animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.tableView.refreshControl?.endRefreshing()
        }
    }
    
    private func animateTableView() {
        guard !favoriteProperties.isEmpty else { return }
        
        tableView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.tableView.alpha = 1
        }
        
        // Animate cells
        let cells = tableView.visibleCells
        for (index, cell) in cells.enumerated() {
            cell.transform = CGAffineTransform(translationX: 0, y: 50)
            cell.alpha = 0
            
            UIView.animate(withDuration: 0.4, delay: Double(index) * 0.05, options: .curveEaseOut) {
                cell.transform = .identity
                cell.alpha = 1
            }
        }
    }
}

// MARK: - Table View Data Source & Delegate
extension FavoritesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return favoriteProperties.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PropertyCell", for: indexPath) as! PropertyTableViewCell
        if indexPath.row < favoriteProperties.count {
            cell.configure(with: favoriteProperties[indexPath.row])
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let property = favoriteProperties[indexPath.row]
        let detailVC = PropertyDetailViewController()
        detailVC.property = property
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let property = favoriteProperties[indexPath.row]
            
            // Check if user is logged in
            guard SessionManager.shared.isSessionValid() else {
                showLoginAlert()
                return
            }
            
            // Remove from favorites via secure API
            SecureAPIService.shared.removeFromFavorites(listingId: property.id) { [weak self] result in
                switch result {
                case .success(_):
                    // Remove from local array
                    self?.favoriteProperties.remove(at: indexPath.row)
                    self?.tableView.deleteRows(at: [indexPath], with: .fade)
                    self?.updateEmptyState()
                    
                    // Show success feedback
                    self?.showToast(message: "Removed from favorites")
                    
                case .failure(let error):
                    print("Error removing favorite: \(error)")
                    // Try with old API as fallback
                    self?.removeFromFavoritesOldAPI(property: property, indexPath: indexPath)
                }
            }
        }
    }
    
    private func removeFromFavoritesOldAPI(property: Property, indexPath: IndexPath) {
        APIService.shared.toggleFavorite(propertyId: property.id) { [weak self] result in
            switch result {
            case .success(_):
                // Remove from local array
                self?.favoriteProperties.remove(at: indexPath.row)
                self?.tableView.deleteRows(at: [indexPath], with: .fade)
                self?.updateEmptyState()
                
                // Show success feedback
                self?.showToast(message: "Removed from favorites")
                
            case .failure(let error):
                print("Error removing favorite: \(error)")
                // Show error alert
                let alert = UIAlertController(title: "Error", message: "Failed to remove favorite. Please try again.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
}

// MARK: - Empty State View
class EmptyStateView: UIView {
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Image view
        imageView.tintColor = .systemGray2
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        // Title label
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        // Message label
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 80),
            imageView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(title: String, message: String, imageName: String) {
        titleLabel.text = title
        messageLabel.text = message
        imageView.image = UIImage(systemName: imageName)
    }
}