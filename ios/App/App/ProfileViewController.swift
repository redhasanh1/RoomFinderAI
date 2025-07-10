import UIKit

class ProfileViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let headerView = ProfileHeaderView()
    private let menuTableView = UITableView()
    private var currentUser: User?
    
    private var menuItems: [ProfileMenuItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMenuItems()
        setupUI()
        setupConstraints()
        loadUserProfile()
        animateOnAppear()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupMenuItems()
        loadUserProfile()
        menuTableView.reloadData()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .edit,
            target: self,
            action: #selector(editTapped)
        )
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Configure header
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerView)
        
        // Configure menu table view
        menuTableView.delegate = self
        menuTableView.dataSource = self
        menuTableView.register(ProfileMenuTableViewCell.self, forCellReuseIdentifier: "MenuCell")
        menuTableView.isScrollEnabled = false
        menuTableView.separatorStyle = .none
        menuTableView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(menuTableView)
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
            headerView.heightAnchor.constraint(equalToConstant: 200),
            
            menuTableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            menuTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            menuTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            menuTableView.heightAnchor.constraint(equalToConstant: CGFloat(menuItems.count * 60)),
            menuTableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func animateOnAppear() {
        headerView.transform = CGAffineTransform(translationX: 0, y: -50)
        headerView.alpha = 0
        
        menuTableView.transform = CGAffineTransform(translationX: 0, y: 50)
        menuTableView.alpha = 0
        
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.headerView.transform = .identity
            self.headerView.alpha = 1
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.2, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.menuTableView.transform = .identity
            self.menuTableView.alpha = 1
        }
    }
    
    private func setupMenuItems() {
        if AuthManager.shared.isLoggedIn {
            // User is logged in - show full profile menu
            menuItems = [
                ProfileMenuItem(title: "Edit Profile", icon: "person.circle", action: .editProfile),
                ProfileMenuItem(title: "My Listings", icon: "house.circle", action: .myListings),
                ProfileMenuItem(title: "Saved Searches", icon: "magnifyingglass.circle", action: .savedSearches),
                ProfileMenuItem(title: "Favorites", icon: "heart.circle", action: .favorites),
                ProfileMenuItem(title: "Rental History", icon: "clock.circle", action: .rentalHistory),
                ProfileMenuItem(title: "Payment Methods", icon: "creditcard.circle", action: .paymentMethods),
                ProfileMenuItem(title: "Notifications", icon: "bell.circle", action: .notifications),
                ProfileMenuItem(title: "Privacy & Security", icon: "shield.circle", action: .privacy),
                ProfileMenuItem(title: "Settings", icon: "gear.circle", action: .settings),
                ProfileMenuItem(title: "Test Real Data", icon: "chart.bar.xaxis", action: .testRealData),
                ProfileMenuItem(title: "Invite Friends", icon: "person.2.circle", action: .inviteFriends),
                ProfileMenuItem(title: "Rate App", icon: "star.circle", action: .rateApp),
                ProfileMenuItem(title: "Help & Support", icon: "questionmark.circle", action: .support),
                ProfileMenuItem(title: "About", icon: "info.circle", action: .about),
                ProfileMenuItem(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right", action: .signOut)
            ]
        } else {
            // User is not logged in - show limited menu with sign in option
            menuItems = [
                ProfileMenuItem(title: "Sign In", icon: "rectangle.portrait.and.arrow.left", action: .signIn),
                ProfileMenuItem(title: "Browse Properties", icon: "house.circle", action: .browseProperties),
                ProfileMenuItem(title: "Test Real Data", icon: "chart.bar.xaxis", action: .testRealData),
                ProfileMenuItem(title: "Settings", icon: "gear.circle", action: .settings),
                ProfileMenuItem(title: "Rate App", icon: "star.circle", action: .rateApp),
                ProfileMenuItem(title: "Help & Support", icon: "questionmark.circle", action: .support),
                ProfileMenuItem(title: "About", icon: "info.circle", action: .about)
            ]
        }
    }
    
    @objc private func editTapped() {
        if AuthManager.shared.isLoggedIn {
            let editVC = EditProfileViewController()
            navigationController?.pushViewController(editVC, animated: true)
        } else {
            showSignIn()
        }
    }
}

// MARK: - Table View Data Source & Delegate
extension ProfileViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MenuCell", for: indexPath) as! ProfileMenuTableViewCell
        cell.configure(with: menuItems[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let menuItem = menuItems[indexPath.row]
        handleMenuAction(menuItem.action)
    }
    
    private func handleMenuAction(_ action: ProfileMenuAction) {
        switch action {
        case .editProfile:
            let editVC = EditProfileViewController()
            navigationController?.pushViewController(editVC, animated: true)
        case .myListings:
            showFeatureComingSoon("My Listings")
        case .savedSearches:
            showFeatureComingSoon("Saved Searches")
        case .favorites:
            tabBarController?.selectedIndex = 2 // Navigate to favorites tab
        case .rentalHistory:
            showFeatureComingSoon("Rental History")
        case .paymentMethods:
            showFeatureComingSoon("Payment Methods")
        case .notifications:
            showFeatureComingSoon("Notifications")
        case .privacy:
            showFeatureComingSoon("Privacy & Security")
        case .settings:
            showFeatureComingSoon("Settings")
        case .testRealData:
            showRealDataTest()
        case .inviteFriends:
            shareApp()
        case .rateApp:
            rateApp()
        case .support:
            showSupport()
        case .about:
            showAbout()
        case .browseProperties:
            tabBarController?.selectedIndex = 0 // Navigate to home tab
        case .signIn:
            showSignIn()
        case .signOut:
            showSignOutAlert()
        }
    }
    
    private func loadUserProfile() {
        if AuthManager.shared.isLoggedIn {
            APIService.shared.getCurrentUser { [weak self] result in
                switch result {
                case .success(let user):
                    self?.currentUser = user
                    self?.headerView.configure(with: user)
                case .failure(let error):
                    print("Error loading user profile: \(error)")
                    // Load default profile
                    self?.headerView.configureDefault()
                }
            }
        } else {
            // User not logged in - show guest profile
            currentUser = nil
            headerView.configureDefault()
        }
    }
    
    private func showSignIn() {
        let authVC = AuthViewController()
        let navController = UINavigationController(rootViewController: authVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    private func showSignOutAlert() {
        let alert = UIAlertController(title: "Sign Out", message: "Are you sure you want to sign out?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { _ in
            AuthManager.shared.logout()
        })
        
        present(alert, animated: true)
    }
    
    private func showFeatureComingSoon(_ featureName: String) {
        let alert = UIAlertController(title: "Coming Soon", message: "\(featureName) feature is coming soon in a future update!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func shareApp() {
        let shareText = "Check out RoomFinderAI - the best app for finding your perfect home! Download it now."
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }
        
        present(activityVC, animated: true)
    }
    
    private func rateApp() {
        let alert = UIAlertController(title: "Rate RoomFinderAI", message: "We'd love to hear your feedback! Please rate us on the App Store.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Rate Now", style: .default) { _ in
            // In a real app, this would open the App Store
            if let url = URL(string: "https://apps.apple.com") {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Later", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showSupport() {
        let alert = UIAlertController(title: "Help & Support", message: "How can we help you?", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "FAQ", style: .default) { _ in
            self.showFeatureComingSoon("FAQ")
        })
        alert.addAction(UIAlertAction(title: "Contact Support", style: .default) { _ in
            self.contactSupport()
        })
        alert.addAction(UIAlertAction(title: "Report Issue", style: .default) { _ in
            self.showFeatureComingSoon("Report Issue")
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }
    
    private func contactSupport() {
        let alert = UIAlertController(title: "Contact Support", message: "Send us an email and we'll get back to you soon!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Send Email", style: .default) { _ in
            if let url = URL(string: "mailto:support@roomfinderai.com") {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showAbout() {
        let alert = UIAlertController(title: "About RoomFinderAI", message: "RoomFinderAI v1.0\n\nYour trusted partner in finding the perfect home. We use AI to match you with properties that fit your lifestyle and budget.\n\n© 2024 RoomFinderAI. All rights reserved.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showRealDataTest() {
        let testVC = RealDataTestViewController()
        navigationController?.pushViewController(testVC, animated: true)
    }
}

// MARK: - Profile Header View
class ProfileHeaderView: UIView {
    private let profileImageView = UIImageView()
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let statsStackView = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        // Profile image
        profileImageView.image = UIImage(systemName: "person.circle.fill")
        profileImageView.tintColor = .systemGray2
        profileImageView.contentMode = .scaleAspectFit
        profileImageView.layer.cornerRadius = 50
        profileImageView.clipsToBounds = true
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(profileImageView)
        
        // Name
        nameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)
        
        // Email
        emailLabel.font = .systemFont(ofSize: 16)
        emailLabel.textColor = .secondaryLabel
        emailLabel.textAlignment = .center
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emailLabel)
        
        // Stats stack view
        statsStackView.axis = .horizontal
        statsStackView.distribution = .fillEqually
        statsStackView.spacing = 20
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statsStackView)
        
        let favoritesView = createStatView(title: "Favorites", count: "12")
        let viewsView = createStatView(title: "Views", count: "45")
        let listingsView = createStatView(title: "Listings", count: "3")
        
        statsStackView.addArrangedSubview(favoritesView)
        statsStackView.addArrangedSubview(viewsView)
        statsStackView.addArrangedSubview(listingsView)
        
        NSLayoutConstraint.activate([
            profileImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            profileImageView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            profileImageView.widthAnchor.constraint(equalToConstant: 100),
            profileImageView.heightAnchor.constraint(equalToConstant: 100),
            
            nameLabel.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            emailLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            emailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            statsStackView.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 20),
            statsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            statsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            statsStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    private func createStatView(title: String, count: String) -> UIView {
        let container = UIView()
        
        let countLabel = UILabel()
        countLabel.text = count
        countLabel.font = .systemFont(ofSize: 20, weight: .bold)
        countLabel.textAlignment = .center
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(countLabel)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: container.topAnchor),
            countLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            countLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    func configure(with user: User) {
        nameLabel.text = "\(user.firstName) \(user.lastName)"
        emailLabel.text = user.email
        
        // Load profile image if available
        if let profileImageUrl = user.profileImage {
            profileImageView.loadImage(from: profileImageUrl, placeholder: UIImage(systemName: "person.circle.fill"))
        } else {
            profileImageView.image = UIImage(systemName: "person.circle.fill")
            profileImageView.tintColor = Theme.Colors.primary
        }
    }
    
    func configureDefault() {
        nameLabel.text = "Guest User"
        emailLabel.text = "guest@roomfinder.ai"
        profileImageView.image = UIImage(systemName: "person.circle.fill")
        profileImageView.tintColor = Theme.Colors.primary
    }
}

// MARK: - Profile Menu Models
struct ProfileMenuItem {
    let title: String
    let icon: String
    let action: ProfileMenuAction
}

enum ProfileMenuAction {
    case editProfile
    case myListings
    case savedSearches
    case favorites
    case rentalHistory
    case paymentMethods
    case notifications
    case privacy
    case settings
    case testRealData
    case inviteFriends
    case rateApp
    case support
    case about
    case browseProperties
    case signIn
    case signOut
}

// MARK: - Profile Menu Table View Cell
class ProfileMenuTableViewCell: UITableViewCell {
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let chevronImageView = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .systemBackground
        
        // Icon
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconImageView)
        
        // Title
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Chevron
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = .systemGray3
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -16),
            
            chevronImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            chevronImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    func configure(with item: ProfileMenuItem) {
        iconImageView.image = UIImage(systemName: item.icon)
        titleLabel.text = item.title
        
        if item.action == .signOut {
            titleLabel.textColor = .systemRed
            iconImageView.tintColor = .systemRed
        } else {
            titleLabel.textColor = .label
            iconImageView.tintColor = .systemBlue
        }
    }
}

// MARK: - Edit Profile View Controller
class EditProfileViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Edit Profile"
    }
}