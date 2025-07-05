import UIKit

class FavoritesViewController: UIViewController {
    
    private let tableView = UITableView()
    private let emptyStateView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupEmptyState()
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.backgroundColor
        title = "Favorites"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Clear All",
            style: .plain,
            target: self,
            action: #selector(clearAllTapped)
        )
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = AppColors.backgroundColor
        tableView.separatorStyle = .none
        tableView.register(PropertyTableViewCell.self, forCellReuseIdentifier: "PropertyCell")
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupEmptyState() {
        let imageView = UIImageView(image: UIImage(systemName: "heart"))
        imageView.tintColor = AppColors.textSecondary
        imageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = "No Favorites Yet"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.textAlignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Start exploring properties and add them to your favorites"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = AppColors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        let exploreButton = UIButton(type: .system)
        exploreButton.setTitle("Explore Properties", for: .normal)
        exploreButton.backgroundColor = AppColors.primaryPurple
        exploreButton.setTitleColor(.white, for: .normal)
        exploreButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        exploreButton.layer.cornerRadius = 25
        exploreButton.addTarget(self, action: #selector(exploreTapped), for: .touchUpInside)
        
        emptyStateView.addSubview(imageView)
        emptyStateView.addSubview(titleLabel)
        emptyStateView.addSubview(subtitleLabel)
        emptyStateView.addSubview(exploreButton)
        
        view.addSubview(emptyStateView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        exploreButton.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            imageView.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            imageView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 80),
            imageView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            
            exploreButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            exploreButton.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            exploreButton.widthAnchor.constraint(equalToConstant: 200),
            exploreButton.heightAnchor.constraint(equalToConstant: 50),
            exploreButton.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor)
        ])
    }
    
    @objc private func clearAllTapped() {
        // Implementation for clearing all favorites
    }
    
    @objc private func exploreTapped() {
        tabBarController?.selectedIndex = 1 // Switch to search tab
    }
}

extension FavoritesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0 // No favorites for now - show empty state
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PropertyCell", for: indexPath)
        return cell
    }
}