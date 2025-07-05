import UIKit

class ProfileViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupProfile()
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.backgroundColor
        title = "Profile"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape.fill"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupProfile() {
        // Profile Header
        let headerView = createProfileHeader()
        
        // Stats Section
        let statsView = createStatsSection()
        
        // Menu Items
        let menuView = createMenuSection()
        
        contentView.addSubview(headerView)
        contentView.addSubview(statsView)
        contentView.addSubview(menuView)
        
        headerView.translatesAutoresizingMaskIntoConstraints = false
        statsView.translatesAutoresizingMaskIntoConstraints = false
        menuView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            statsView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 32),
            statsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            menuView.topAnchor.constraint(equalTo: statsView.bottomAnchor, constant: 32),
            menuView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            menuView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            menuView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }
    
    private func createProfileHeader() -> UIView {
        let headerView = UIView()
        
        // Profile Image
        let profileImageView = UIImageView()
        profileImageView.backgroundColor = AppColors.primaryPurple
        profileImageView.layer.cornerRadius = 50
        profileImageView.clipsToBounds = true
        
        let profileLabel = UILabel()
        profileLabel.text = "JD"
        profileLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        profileLabel.textColor = .white
        profileLabel.textAlignment = .center
        
        profileImageView.addSubview(profileLabel)
        
        // Name and Info
        let nameLabel = UILabel()
        nameLabel.text = "John Doe"
        nameLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        nameLabel.textColor = AppColors.textPrimary
        nameLabel.textAlignment = .center
        
        let emailLabel = UILabel()
        emailLabel.text = "john.doe@email.com"
        emailLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        emailLabel.textColor = AppColors.textSecondary
        emailLabel.textAlignment = .center
        
        let membershipBadge = UIView()
        membershipBadge.backgroundColor = AppColors.primaryPurple.withAlphaComponent(0.1)
        membershipBadge.layer.cornerRadius = 16
        
        let badgeLabel = UILabel()
        badgeLabel.text = "Premium Member"
        badgeLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        badgeLabel.textColor = AppColors.primaryPurple
        badgeLabel.textAlignment = .center
        
        membershipBadge.addSubview(badgeLabel)
        
        headerView.addSubview(profileImageView)
        headerView.addSubview(nameLabel)
        headerView.addSubview(emailLabel)
        headerView.addSubview(membershipBadge)
        
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        membershipBadge.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            profileImageView.topAnchor.constraint(equalTo: headerView.topAnchor),
            profileImageView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 100),
            profileImageView.heightAnchor.constraint(equalToConstant: 100),
            
            profileLabel.centerXAnchor.constraint(equalTo: profileImageView.centerXAnchor),
            profileLabel.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 16),
            nameLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            emailLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            
            membershipBadge.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 12),
            membershipBadge.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            membershipBadge.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            
            badgeLabel.topAnchor.constraint(equalTo: membershipBadge.topAnchor, constant: 8),
            badgeLabel.leadingAnchor.constraint(equalTo: membershipBadge.leadingAnchor, constant: 16),
            badgeLabel.trailingAnchor.constraint(equalTo: membershipBadge.trailingAnchor, constant: -16),
            badgeLabel.bottomAnchor.constraint(equalTo: membershipBadge.bottomAnchor, constant: -8)
        ])
        
        return headerView
    }
    
    private func createStatsSection() -> UIView {
        let statsView = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = "Your Activity"
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary
        
        let statsStackView = UIStackView()
        statsStackView.axis = .horizontal
        statsStackView.distribution = .fillEqually
        statsStackView.spacing = 16
        
        let searchesCard = createStatCard(title: "Searches", value: "47", icon: "magnifyingglass")
        let favoritesCard = createStatCard(title: "Favorites", value: "12", icon: "heart.fill")
        let messagesCard = createStatCard(title: "Messages", value: "156", icon: "message.fill")
        
        statsStackView.addArrangedSubview(searchesCard)
        statsStackView.addArrangedSubview(favoritesCard)
        statsStackView.addArrangedSubview(messagesCard)
        
        statsView.addSubview(titleLabel)
        statsView.addSubview(statsStackView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: statsView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 20),
            
            statsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            statsStackView.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 20),
            statsStackView.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -20),
            statsStackView.bottomAnchor.constraint(equalTo: statsView.bottomAnchor),
            statsStackView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        return statsView
    }
    
    private func createStatCard(title: String, value: String, icon: String) -> UIView {
        let card = UIView()
        card.backgroundColor = AppColors.cardBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.05
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8
        
        let iconImageView = UIImageView(image: UIImage(systemName: icon))
        iconImageView.tintColor = AppColors.primaryPurple
        iconImageView.contentMode = .scaleAspectFit
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        valueLabel.textColor = AppColors.textPrimary
        valueLabel.textAlignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = AppColors.textSecondary
        titleLabel.textAlignment = .center
        
        card.addSubview(iconImageView)
        card.addSubview(valueLabel)
        card.addSubview(titleLabel)
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            iconImageView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            valueLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            
            titleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            titleLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor)
        ])
        
        return card
    }
    
    private func createMenuSection() -> UIView {
        let menuView = UIView()
        
        let menuItems = [
            ("Edit Profile", "person.crop.circle", #selector(editProfileTapped)),
            ("Notifications", "bell.fill", #selector(notificationsTapped)),
            ("Payment Methods", "creditcard.fill", #selector(paymentTapped)),
            ("Help & Support", "questionmark.circle.fill", #selector(helpTapped)),
            ("Privacy Policy", "hand.raised.fill", #selector(privacyTapped)),
            ("Sign Out", "rectangle.portrait.and.arrow.right", #selector(signOutTapped))
        ]
        
        var previousView: UIView = menuView
        
        for (index, item) in menuItems.enumerated() {
            let menuItemView = createMenuItem(title: item.0, icon: item.1, action: item.2, isLast: index == menuItems.count - 1)
            menuView.addSubview(menuItemView)
            
            menuItemView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                menuItemView.leadingAnchor.constraint(equalTo: menuView.leadingAnchor, constant: 20),
                menuItemView.trailingAnchor.constraint(equalTo: menuView.trailingAnchor, constant: -20),
                menuItemView.heightAnchor.constraint(equalToConstant: 56)
            ])
            
            if index == 0 {
                menuItemView.topAnchor.constraint(equalTo: menuView.topAnchor).isActive = true
            } else {
                menuItemView.topAnchor.constraint(equalTo: previousView.bottomAnchor).isActive = true
            }
            
            if index == menuItems.count - 1 {
                menuItemView.bottomAnchor.constraint(equalTo: menuView.bottomAnchor).isActive = true
            }
            
            previousView = menuItemView
        }
        
        return menuView
    }
    
    private func createMenuItem(title: String, icon: String, action: Selector, isLast: Bool) -> UIView {
        let itemView = UIView()
        itemView.backgroundColor = AppColors.cardBackground
        
        if !isLast {
            let separator = UIView()
            separator.backgroundColor = AppColors.separatorColor
            itemView.addSubview(separator)
            separator.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                separator.leadingAnchor.constraint(equalTo: itemView.leadingAnchor, constant: 56),
                separator.trailingAnchor.constraint(equalTo: itemView.trailingAnchor),
                separator.bottomAnchor.constraint(equalTo: itemView.bottomAnchor),
                separator.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        
        let iconImageView = UIImageView(image: UIImage(systemName: icon))
        iconImageView.tintColor = title == "Sign Out" ? AppColors.errorRed : AppColors.primaryPurple
        iconImageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = title == "Sign Out" ? AppColors.errorRed : AppColors.textPrimary
        
        let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevronImageView.tintColor = AppColors.textSecondary
        chevronImageView.contentMode = .scaleAspectFit
        
        itemView.addSubview(iconImageView)
        itemView.addSubview(titleLabel)
        itemView.addSubview(chevronImageView)
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: itemView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: itemView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: itemView.centerYAnchor),
            
            chevronImageView.trailingAnchor.constraint(equalTo: itemView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: itemView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: action)
        itemView.addGestureRecognizer(tapGesture)
        itemView.isUserInteractionEnabled = true
        
        return itemView
    }
    
    @objc private func settingsTapped() {
        // Implementation for settings
    }
    
    @objc private func editProfileTapped() {
        // Implementation for edit profile
    }
    
    @objc private func notificationsTapped() {
        // Implementation for notifications
    }
    
    @objc private func paymentTapped() {
        // Implementation for payment methods
    }
    
    @objc private func helpTapped() {
        // Implementation for help & support
    }
    
    @objc private func privacyTapped() {
        // Implementation for privacy policy
    }
    
    @objc private func signOutTapped() {
        let alert = UIAlertController(title: "Sign Out", message: "Are you sure you want to sign out?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { _ in
            // Implementation for sign out
        })
        present(alert, animated: true)
    }
}