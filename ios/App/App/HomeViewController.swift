import UIKit

class HomeViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Header Components
    private let headerView = UIView()
    private let profileButton = UIButton(type: .system)
    private let notificationButton = UIButton(type: .system)
    
    // Quick Actions Widget
    private let quickActionsWidget = UIView()
    
    // Featured Property Hero Section
    private let heroSection = UIView()
    private let heroScrollView = UIScrollView()
    private let heroStackView = UIStackView()
    private let heroPageControl = UIPageControl()
    
    // Floating Action Button
    private let floatingActionButton = UIButton(type: .system)
    
    
    // Categories Section
    private let categoriesSection = UIView()
    private let categoriesCollectionView: UICollectionView
    
    // Featured Collections
    private let featuredSection = UIView()
    private let featuredCollectionView: UICollectionView
    
    
    // Sample Data
    private let featuredProperties = [
        PropertyModel(id: "1", title: "Luxury Downtown Penthouse", price: 3500, location: "Manhattan, NY", bedrooms: 3, bathrooms: 2, amenities: ["WiFi", "Gym", "Pool", "Concierge"], imageURL: "luxury1", rating: 4.9, isVerified: true),
        PropertyModel(id: "2", title: "Modern Riverside Apartment", price: 2800, location: "Brooklyn, NY", bedrooms: 2, bathrooms: 2, amenities: ["WiFi", "Balcony", "Parking"], imageURL: "modern1", rating: 4.8, isVerified: true),
        PropertyModel(id: "3", title: "Cozy Studio in SoHo", price: 2200, location: "SoHo, NY", bedrooms: 1, bathrooms: 1, amenities: ["WiFi", "Rooftop"], imageURL: "studio1", rating: 4.7, isVerified: false)
    ]
    
    private let categories = [
        CategoryModel(name: "Studios", icon: "🏠", count: 156, color: AppColors.primaryPurple),
        CategoryModel(name: "1 Bedroom", icon: "🛏️", count: 284, color: AppColors.accentBlue),
        CategoryModel(name: "2+ Bedrooms", icon: "🏡", count: 192, color: AppColors.successGreen),
        CategoryModel(name: "Luxury", icon: "✨", count: 47, color: AppColors.warningOrange),
        CategoryModel(name: "Student", icon: "🎓", count: 98, color: AppColors.errorRed),
        CategoryModel(name: "Shared", icon: "👥", count: 134, color: AppColors.primaryPurple)
    ]
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        // Initialize collection views with layouts
        let categoriesLayout = UICollectionViewFlowLayout()
        categoriesLayout.scrollDirection = .horizontal
        categoriesLayout.minimumInteritemSpacing = 12
        categoriesLayout.minimumLineSpacing = 12
        categoriesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: categoriesLayout)
        
        let featuredLayout = UICollectionViewFlowLayout()
        featuredLayout.scrollDirection = .horizontal
        featuredLayout.minimumInteritemSpacing = 16
        featuredLayout.minimumLineSpacing = 16
        featuredCollectionView = UICollectionView(frame: .zero, collectionViewLayout: featuredLayout)
        
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionViews()
        setupConstraints()
        loadData()
        setupRefreshControl()
        setupFloatingActionButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        startHeroAutoScroll()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopHeroAutoScroll()
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.backgroundColor
        
        // Configure scroll view for mobile-optimized scrolling
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast // Faster scrolling for mobile
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Setup mobile-optimized sections
        setupMobileHeader()
        setupQuickActionsWidget()
        setupFeaturedHeroSection()
        setupCategoriesSection()
        setupFeaturedSection()
        
        // Add sections to content view with optimized spacing
        contentView.addSubview(headerView)
        contentView.addSubview(quickActionsWidget)
        contentView.addSubview(heroSection)
        contentView.addSubview(categoriesSection)
        contentView.addSubview(featuredSection)
    }
    
    private func setupMobileHeader() {
        headerView.backgroundColor = .clear
        
        // Compact mobile header
        let titleLabel = UILabel()
        titleLabel.text = "RoomFinder"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary
        
        let locationContainer = UIView()
        locationContainer.backgroundColor = AppColors.separatorColor.withAlphaComponent(0.3)
        locationContainer.layer.cornerRadius = 16
        
        let locationIcon = UIImageView(image: UIImage(systemName: "location.fill"))
        locationIcon.tintColor = AppColors.primaryPurple
        
        let locationLabel = UILabel()
        locationLabel.text = "New York, NY"
        locationLabel.font = .systemFont(ofSize: 14, weight: .medium)
        locationLabel.textColor = AppColors.textSecondary
        
        // Notification badge
        notificationButton.setImage(UIImage(systemName: "bell.badge.fill"), for: .normal)
        notificationButton.tintColor = AppColors.primaryPurple
        notificationButton.backgroundColor = AppColors.cardBackground
        notificationButton.layer.cornerRadius = 20
        notificationButton.layer.shadowColor = UIColor.black.cgColor
        notificationButton.layer.shadowOpacity = 0.1
        notificationButton.layer.shadowOffset = CGSize(width: 0, y: 2)
        notificationButton.layer.shadowRadius = 4
        notificationButton.addTarget(self, action: #selector(notificationsTapped), for: .touchUpInside)
        
        // Profile button
        profileButton.setImage(UIImage(systemName: "person.circle.fill"), for: .normal)
        profileButton.tintColor = AppColors.primaryPurple
        profileButton.backgroundColor = AppColors.cardBackground
        profileButton.layer.cornerRadius = 20
        profileButton.layer.shadowColor = UIColor.black.cgColor
        profileButton.layer.shadowOpacity = 0.1
        profileButton.layer.shadowOffset = CGSize(width: 0, y: 2)
        profileButton.layer.shadowRadius = 4
        profileButton.addTarget(self, action: #selector(profileTapped), for: .touchUpInside)
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(locationContainer)
        locationContainer.addSubview(locationIcon)
        locationContainer.addSubview(locationLabel)
        headerView.addSubview(notificationButton)
        headerView.addSubview(profileButton)
        
        [titleLabel, locationContainer, locationIcon, locationLabel, notificationButton, profileButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            
            locationContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            locationContainer.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            locationContainer.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
            locationContainer.heightAnchor.constraint(equalToConstant: 32),
            
            locationIcon.leadingAnchor.constraint(equalTo: locationContainer.leadingAnchor, constant: 12),
            locationIcon.centerYAnchor.constraint(equalTo: locationContainer.centerYAnchor),
            locationIcon.widthAnchor.constraint(equalToConstant: 16),
            locationIcon.heightAnchor.constraint(equalToConstant: 16),
            
            locationLabel.leadingAnchor.constraint(equalTo: locationIcon.trailingAnchor, constant: 8),
            locationLabel.centerYAnchor.constraint(equalTo: locationContainer.centerYAnchor),
            locationLabel.trailingAnchor.constraint(equalTo: locationContainer.trailingAnchor, constant: -12),
            
            profileButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            profileButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            profileButton.widthAnchor.constraint(equalToConstant: 40),
            profileButton.heightAnchor.constraint(equalToConstant: 40),
            
            notificationButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            notificationButton.trailingAnchor.constraint(equalTo: profileButton.leadingAnchor, constant: -12),
            notificationButton.widthAnchor.constraint(equalToConstant: 40),
            notificationButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupQuickActionsWidget() {
        quickActionsWidget.backgroundColor = .clear
        
        // Quick search button
        let searchButton = createQuickActionButton(
            title: "Search",
            icon: "magnifyingglass",
            color: AppColors.primaryPurple,
            action: #selector(quickSearchTapped)
        )
        
        // Favorites button
        let favoritesButton = createQuickActionButton(
            title: "Favorites",
            icon: "heart.fill",
            color: AppColors.errorRed,
            action: #selector(quickFavoritesTapped)
        )
        
        // AI Chat button
        let chatButton = createQuickActionButton(
            title: "AI Help",
            icon: "message.fill",
            color: AppColors.accentBlue,
            action: #selector(quickChatTapped)
        )
        
        // Map view button
        let mapButton = createQuickActionButton(
            title: "Map View",
            icon: "map.fill",
            color: AppColors.successGreen,
            action: #selector(quickMapTapped)
        )
        
        let stackView = UIStackView(arrangedSubviews: [searchButton, favoritesButton, chatButton, mapButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        
        quickActionsWidget.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: quickActionsWidget.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: quickActionsWidget.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: quickActionsWidget.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: quickActionsWidget.bottomAnchor, constant: -16),
            stackView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    private func createQuickActionButton(title: String, icon: String, color: UIColor, action: Selector) -> UIView {
        let container = UIView()
        container.backgroundColor = AppColors.cardBackground
        container.layer.cornerRadius = 16
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.08
        container.layer.shadowOffset = CGSize(width: 0, y: 2)
        container.layer.shadowRadius = 8
        
        let button = UIButton(type: .system)
        button.addTarget(self, action: action, for: .touchUpInside)
        
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.textAlignment = .center
        
        container.addSubview(button)
        container.addSubview(iconView)
        container.addSubview(titleLabel)
        
        [button, iconView, titleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            iconView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        
        return container
    }
    
    private func setupFeaturedHeroSection() {
        heroSection.backgroundColor = .clear
        
        // Hero scroll view setup
        heroScrollView.isPagingEnabled = true
        heroScrollView.showsHorizontalScrollIndicator = false
        heroScrollView.delegate = self
        
        heroStackView.axis = .horizontal
        heroStackView.spacing = 0
        heroStackView.distribution = .fillEqually
        
        // Page control
        heroPageControl.numberOfPages = featuredProperties.count
        heroPageControl.currentPage = 0
        heroPageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.5)
        heroPageControl.currentPageIndicatorTintColor = .white
        
        heroSection.addSubview(heroScrollView)
        heroScrollView.addSubview(heroStackView)
        heroSection.addSubview(heroPageControl)
        
        // Create hero cards
        for property in featuredProperties {
            let heroCard = createHeroCard(for: property)
            heroStackView.addArrangedSubview(heroCard)
        }
        
        heroScrollView.translatesAutoresizingMaskIntoConstraints = false
        heroStackView.translatesAutoresizingMaskIntoConstraints = false
        heroPageControl.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            heroScrollView.topAnchor.constraint(equalTo: heroSection.topAnchor),
            heroScrollView.leadingAnchor.constraint(equalTo: heroSection.leadingAnchor),
            heroScrollView.trailingAnchor.constraint(equalTo: heroSection.trailingAnchor),
            heroScrollView.heightAnchor.constraint(equalToConstant: 220), // Reduced height for mobile
            
            heroStackView.topAnchor.constraint(equalTo: heroScrollView.topAnchor),
            heroStackView.leadingAnchor.constraint(equalTo: heroScrollView.leadingAnchor),
            heroStackView.trailingAnchor.constraint(equalTo: heroScrollView.trailingAnchor),
            heroStackView.bottomAnchor.constraint(equalTo: heroScrollView.bottomAnchor),
            heroStackView.heightAnchor.constraint(equalTo: heroScrollView.heightAnchor),
            heroStackView.widthAnchor.constraint(equalTo: heroScrollView.widthAnchor, multiplier: CGFloat(featuredProperties.count)),
            
            heroPageControl.topAnchor.constraint(equalTo: heroScrollView.bottomAnchor, constant: 8),
            heroPageControl.centerXAnchor.constraint(equalTo: heroSection.centerXAnchor),
            heroPageControl.bottomAnchor.constraint(equalTo: heroSection.bottomAnchor, constant: -12)
        ])
    }
    
    private func createHeroCard(for property: PropertyModel) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        
        // Background gradient
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = AppColors.primaryGradient
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        card.layer.insertSublayer(gradientLayer, at: 0)
        
        // Content container
        let contentContainer = UIView()
        contentContainer.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        // Property image placeholder
        let imageView = UIImageView()
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.image = UIImage(systemName: "photo.fill")
        imageView.tintColor = UIColor.white.withAlphaComponent(0.6)
        
        // Verified badge
        let verifiedBadge = UIView()
        if property.isVerified {
            verifiedBadge.backgroundColor = AppColors.successGreen
            verifiedBadge.layer.cornerRadius = 12
            
            let checkIcon = UIImageView(image: UIImage(systemName: "checkmark"))
            checkIcon.tintColor = .white
            checkIcon.contentMode = .scaleAspectFit
            
            let verifiedLabel = UILabel()
            verifiedLabel.text = "Verified"
            verifiedLabel.font = .systemFont(ofSize: 12, weight: .semibold)
            verifiedLabel.textColor = .white
            
            verifiedBadge.addSubview(checkIcon)
            verifiedBadge.addSubview(verifiedLabel)
            
            checkIcon.translatesAutoresizingMaskIntoConstraints = false
            verifiedLabel.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                checkIcon.leadingAnchor.constraint(equalTo: verifiedBadge.leadingAnchor, constant: 8),
                checkIcon.centerYAnchor.constraint(equalTo: verifiedBadge.centerYAnchor),
                checkIcon.widthAnchor.constraint(equalToConstant: 14),
                checkIcon.heightAnchor.constraint(equalToConstant: 14),
                
                verifiedLabel.leadingAnchor.constraint(equalTo: checkIcon.trailingAnchor, constant: 4),
                verifiedLabel.centerYAnchor.constraint(equalTo: verifiedBadge.centerYAnchor),
                verifiedLabel.trailingAnchor.constraint(equalTo: verifiedBadge.trailingAnchor, constant: -8),
                
                verifiedBadge.heightAnchor.constraint(equalToConstant: 24)
            ])
        }
        
        // Title and details
        let titleLabel = UILabel()
        titleLabel.text = property.title
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        
        let locationLabel = UILabel()
        locationLabel.text = "📍 \(property.location)"
        locationLabel.font = .systemFont(ofSize: 16, weight: .medium)
        locationLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        
        let priceLabel = UILabel()
        priceLabel.text = "$\(property.price)/month"
        priceLabel.font = .systemFont(ofSize: 20, weight: .bold)
        priceLabel.textColor = .white
        
        let detailsLabel = UILabel()
        detailsLabel.text = "\(property.bedrooms) bed • \(property.bathrooms) bath"
        detailsLabel.font = .systemFont(ofSize: 14, weight: .medium)
        detailsLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        
        // Rating
        let ratingContainer = UIView()
        ratingContainer.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        ratingContainer.layer.cornerRadius = 12
        ratingContainer.layer.backdropFilter()
        
        let starIcon = UIImageView(image: UIImage(systemName: "star.fill"))
        starIcon.tintColor = .systemYellow
        
        let ratingLabel = UILabel()
        ratingLabel.text = String(format: "%.1f", property.rating)
        ratingLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        ratingLabel.textColor = .white
        
        ratingContainer.addSubview(starIcon)
        ratingContainer.addSubview(ratingLabel)
        
        // Add all subviews
        card.addSubview(imageView)
        card.addSubview(contentContainer)
        contentContainer.addSubview(verifiedBadge)
        contentContainer.addSubview(titleLabel)
        contentContainer.addSubview(locationLabel)
        contentContainer.addSubview(priceLabel)
        contentContainer.addSubview(detailsLabel)
        contentContainer.addSubview(ratingContainer)
        
        // Set up constraints
        [imageView, contentContainer, verifiedBadge, titleLabel, locationLabel, priceLabel, detailsLabel, ratingContainer, starIcon, ratingLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: card.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            contentContainer.topAnchor.constraint(equalTo: card.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            verifiedBadge.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 20),
            verifiedBadge.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -20),
            
            ratingContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 20),
            ratingContainer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 20),
            ratingContainer.heightAnchor.constraint(equalToConstant: 24),
            
            starIcon.leadingAnchor.constraint(equalTo: ratingContainer.leadingAnchor, constant: 8),
            starIcon.centerYAnchor.constraint(equalTo: ratingContainer.centerYAnchor),
            starIcon.widthAnchor.constraint(equalToConstant: 12),
            starIcon.heightAnchor.constraint(equalToConstant: 12),
            
            ratingLabel.leadingAnchor.constraint(equalTo: starIcon.trailingAnchor, constant: 4),
            ratingLabel.centerYAnchor.constraint(equalTo: ratingContainer.centerYAnchor),
            ratingLabel.trailingAnchor.constraint(equalTo: ratingContainer.trailingAnchor, constant: -8),
            
            titleLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -20),
            titleLabel.bottomAnchor.constraint(equalTo: locationLabel.topAnchor, constant: -8),
            
            locationLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 20),
            locationLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -20),
            locationLabel.bottomAnchor.constraint(equalTo: priceLabel.topAnchor, constant: -8),
            
            priceLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 20),
            priceLabel.bottomAnchor.constraint(equalTo: detailsLabel.topAnchor, constant: -4),
            
            detailsLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 20),
            detailsLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -20)
        ])
        
        // Add gradient layer resize on layout
        card.layoutIfNeeded()
        DispatchQueue.main.async {
            gradientLayer.frame = card.bounds
        }
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(heroCardTapped(_:)))
        card.addGestureRecognizer(tapGesture)
        card.isUserInteractionEnabled = true
        card.tag = Int(property.id) ?? 0
        
        return card
    }
    
    
    
    private func setupCategoriesSection() {
        categoriesSection.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.text = "Categories"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary
        
        let seeAllButton = UIButton(type: .system)
        seeAllButton.setTitle("See All", for: .normal)
        seeAllButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        seeAllButton.setTitleColor(AppColors.primaryPurple, for: .normal)
        seeAllButton.addTarget(self, action: #selector(seeAllCategoriesTapped), for: .touchUpInside)
        
        categoriesSection.addSubview(titleLabel)
        categoriesSection.addSubview(seeAllButton)
        categoriesSection.addSubview(categoriesCollectionView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        seeAllButton.translatesAutoresizingMaskIntoConstraints = false
        categoriesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: categoriesSection.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: categoriesSection.leadingAnchor, constant: 20),
            
            seeAllButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            seeAllButton.trailingAnchor.constraint(equalTo: categoriesSection.trailingAnchor, constant: -20),
            
            categoriesCollectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            categoriesCollectionView.leadingAnchor.constraint(equalTo: categoriesSection.leadingAnchor),
            categoriesCollectionView.trailingAnchor.constraint(equalTo: categoriesSection.trailingAnchor),
            categoriesCollectionView.bottomAnchor.constraint(equalTo: categoriesSection.bottomAnchor, constant: -16),
            categoriesCollectionView.heightAnchor.constraint(equalToConstant: 90) // Slightly smaller for mobile
        ])
    }
    
    private func setupFeaturedSection() {
        featuredSection.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.text = "Featured Properties"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary
        
        let seeAllButton = UIButton(type: .system)
        seeAllButton.setTitle("See All", for: .normal)
        seeAllButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        seeAllButton.setTitleColor(AppColors.primaryPurple, for: .normal)
        seeAllButton.addTarget(self, action: #selector(seeAllFeaturedTapped), for: .touchUpInside)
        
        featuredSection.addSubview(titleLabel)
        featuredSection.addSubview(seeAllButton)
        featuredSection.addSubview(featuredCollectionView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        seeAllButton.translatesAutoresizingMaskIntoConstraints = false
        featuredCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: featuredSection.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: featuredSection.leadingAnchor, constant: 20),
            
            seeAllButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            seeAllButton.trailingAnchor.constraint(equalTo: featuredSection.trailingAnchor, constant: -20),
            
            featuredCollectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            featuredCollectionView.leadingAnchor.constraint(equalTo: featuredSection.leadingAnchor),
            featuredCollectionView.trailingAnchor.constraint(equalTo: featuredSection.trailingAnchor),
            featuredCollectionView.bottomAnchor.constraint(equalTo: featuredSection.bottomAnchor, constant: -20),
            featuredCollectionView.heightAnchor.constraint(equalToConstant: 280)
        ])
    }
    
    
    private func setupCollectionViews() {
        // Categories collection view
        categoriesCollectionView.backgroundColor = .clear
        categoriesCollectionView.showsHorizontalScrollIndicator = false
        categoriesCollectionView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        categoriesCollectionView.register(CategoryCell.self, forCellWithReuseIdentifier: "CategoryCell")
        categoriesCollectionView.dataSource = self
        categoriesCollectionView.delegate = self
        
        // Featured collection view
        featuredCollectionView.backgroundColor = .clear
        featuredCollectionView.showsHorizontalScrollIndicator = false
        featuredCollectionView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        featuredCollectionView.register(PropertyCard.self, forCellWithReuseIdentifier: "PropertyCard")
        featuredCollectionView.dataSource = self
        featuredCollectionView.delegate = self
        
    }
    
    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
        quickActionsWidget.translatesAutoresizingMaskIntoConstraints = false
        heroSection.translatesAutoresizingMaskIntoConstraints = false
        categoriesSection.translatesAutoresizingMaskIntoConstraints = false
        featuredSection.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
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
            
            quickActionsWidget.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            quickActionsWidget.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            quickActionsWidget.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            heroSection.topAnchor.constraint(equalTo: quickActionsWidget.bottomAnchor, constant: 16),
            heroSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            heroSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            categoriesSection.topAnchor.constraint(equalTo: heroSection.bottomAnchor, constant: 24),
            categoriesSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            categoriesSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            featuredSection.topAnchor.constraint(equalTo: categoriesSection.bottomAnchor, constant: 24),
            featuredSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            featuredSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            featuredSection.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -100) // Extra space for floating button
        ])
    }
    
    private func setupRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        refreshControl.tintColor = AppColors.primaryPurple
        scrollView.refreshControl = refreshControl
    }
    
    private func setupFloatingActionButton() {
        floatingActionButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        floatingActionButton.backgroundColor = AppColors.primaryPurple
        floatingActionButton.tintColor = .white
        floatingActionButton.layer.cornerRadius = 28
        floatingActionButton.layer.shadowColor = UIColor.black.cgColor
        floatingActionButton.layer.shadowOpacity = 0.3
        floatingActionButton.layer.shadowOffset = CGSize(width: 0, y: 4)
        floatingActionButton.layer.shadowRadius = 12
        floatingActionButton.addTarget(self, action: #selector(floatingActionTapped), for: .touchUpInside)
        
        view.addSubview(floatingActionButton)
        floatingActionButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            floatingActionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            floatingActionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            floatingActionButton.widthAnchor.constraint(equalToConstant: 56),
            floatingActionButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func loadData() {
        // Simulate loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.categoriesCollectionView.reloadData()
            self.featuredCollectionView.reloadData()
            self.recentCollectionView.reloadData()
        }
    }
    
    // MARK: - Hero Auto Scroll
    private var heroTimer: Timer?
    
    private func startHeroAutoScroll() {
        heroTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.scrollToNextHeroCard()
        }
    }
    
    private func stopHeroAutoScroll() {
        heroTimer?.invalidate()
        heroTimer = nil
    }
    
    private func scrollToNextHeroCard() {
        let currentPage = heroPageControl.currentPage
        let nextPage = (currentPage + 1) % featuredProperties.count
        
        let xOffset = CGFloat(nextPage) * heroScrollView.frame.width
        heroScrollView.setContentOffset(CGPoint(x: xOffset, y: 0), animated: true)
        heroPageControl.currentPage = nextPage
    }
    
    // MARK: - Actions
    @objc private func profileTapped() {
        tabBarController?.selectedIndex = 4
    }
    
    @objc private func notificationsTapped() {
        // Show notifications
        let alert = UIAlertController(title: "Notifications", message: "You have 3 new messages", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func heroCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let cardView = gesture.view,
              let propertyId = featuredProperties.first(where: { Int($0.id) == cardView.tag }) else { return }
        
        let detailVC = PropertyDetailViewController(property: propertyId)
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    @objc private func seeAllFeaturedTapped() {
        tabBarController?.selectedIndex = 1
    }
    
    @objc private func seeAllCategoriesTapped() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Navigate to search with category filters
        tabBarController?.selectedIndex = 1
    }
    
    @objc private func refreshData() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.scrollView.refreshControl?.endRefreshing()
            self.loadData()
        }
    }
    
    // MARK: - Quick Actions
    @objc private func quickSearchTapped() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Navigate to search with animation
        tabBarController?.selectedIndex = 1
    }
    
    @objc private func quickFavoritesTapped() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        tabBarController?.selectedIndex = 2
    }
    
    @objc private func quickChatTapped() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        tabBarController?.selectedIndex = 3
    }
    
    @objc private func quickMapTapped() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Present map view modally
        let alert = UIAlertController(title: "Map View", message: "Opening map with nearby properties...", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func floatingActionTapped() {
        // Enhanced haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Animate button
        UIView.animate(withDuration: 0.1, animations: {
            self.floatingActionButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.floatingActionButton.transform = .identity
            }
        }
        
        // Show quick actions menu
        let actionSheet = UIAlertController(title: "Quick Actions", message: "What would you like to do?", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "🔍 Advanced Search", style: .default) { _ in
            self.tabBarController?.selectedIndex = 1
        })
        
        actionSheet.addAction(UIAlertAction(title: "📍 Properties Near Me", style: .default) { _ in
            // Implement location-based search
        })
        
        actionSheet.addAction(UIAlertAction(title: "🤖 AI Property Assistant", style: .default) { _ in
            self.tabBarController?.selectedIndex = 3
        })
        
        actionSheet.addAction(UIAlertAction(title: "📋 Saved Searches", style: .default) { _ in
            // Show saved searches
        })
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = floatingActionButton
            popover.sourceRect = floatingActionButton.bounds
        }
        
        present(actionSheet, animated: true)
    }
}

// MARK: - ScrollView Delegate
extension HomeViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == heroScrollView {
            let pageIndex = round(scrollView.contentOffset.x / scrollView.frame.width)
            heroPageControl.currentPage = Int(pageIndex)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if scrollView == heroScrollView {
            stopHeroAutoScroll()
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView == heroScrollView && !decelerate {
            startHeroAutoScroll()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView == heroScrollView {
            startHeroAutoScroll()
        }
    }
}

// MARK: - Collection View DataSource & Delegate
extension HomeViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch collectionView {
        case categoriesCollectionView:
            return categories.count
        case featuredCollectionView:
            return featuredProperties.count
        default:
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch collectionView {
        case categoriesCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
            cell.configure(with: categories[indexPath.item])
            return cell
            
        case featuredCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PropertyCard", for: indexPath) as! PropertyCard
            cell.configure(with: featuredProperties[indexPath.item])
            return cell
            
        default:
            return UICollectionViewCell()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        switch collectionView {
        case categoriesCollectionView:
            return CGSize(width: 80, height: 100)
        case featuredCollectionView:
            return CGSize(width: 220, height: 280)
        default:
            return CGSize.zero
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch collectionView {
        case categoriesCollectionView:
            let category = categories[indexPath.item]
            // Navigate to search with category filter
            if let tabBar = tabBarController as? MainTabBarController,
               let searchVC = tabBar.viewControllers?[1] as? UINavigationController,
               let searchController = searchVC.topViewController as? SearchViewController {
                searchController.filterByCategory(category.name)
                tabBar.selectedIndex = 1
            }
            
        case featuredCollectionView:
            let property = featuredProperties[indexPath.item]
            let detailVC = PropertyDetailViewController(property: property)
            navigationController?.pushViewController(detailVC, animated: true)
            
        default:
            break
        }
    }
}

// MARK: - Extensions
extension CALayer {
    func backdropFilter() {
        // iOS doesn't support backdrop filters like CSS, but we can simulate with blur
        // This would require additional implementation with visual effect views
    }
}

// MARK: - Models
struct CategoryModel {
    let name: String
    let icon: String
    let count: Int
    let color: UIColor
}

