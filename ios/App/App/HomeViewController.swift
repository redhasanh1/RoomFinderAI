import UIKit

class HomeViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Header Components
    private let headerView = UIView()
    private let profileButton = UIButton(type: .system)
    private let notificationButton = UIButton(type: .system)
    
    // Featured Property Hero Section
    private let heroSection = UIView()
    private let heroScrollView = UIScrollView()
    private let heroStackView = UIStackView()
    private let heroPageControl = UIPageControl()
    
    // Quick Stats Section
    private let statsSection = UIView()
    
    // Categories Section
    private let categoriesSection = UIView()
    private let categoriesCollectionView: UICollectionView
    
    // Featured Collections
    private let featuredSection = UIView()
    private let featuredCollectionView: UICollectionView
    
    // Recent Properties
    private let recentSection = UIView()
    private let recentCollectionView: UICollectionView
    
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
        
        let recentLayout = UICollectionViewFlowLayout()
        recentLayout.scrollDirection = .horizontal
        recentLayout.minimumInteritemSpacing = 12
        recentLayout.minimumLineSpacing = 12
        recentCollectionView = UICollectionView(frame: .zero, collectionViewLayout: recentLayout)
        
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
        
        // Configure scroll view
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Setup header
        setupHeader()
        
        // Setup hero section
        setupHeroSection()
        
        // Setup stats
        setupStatsSection()
        
        // Setup categories
        setupCategoriesSection()
        
        // Setup featured section
        setupFeaturedSection()
        
        // Setup recent section
        setupRecentSection()
        
        // Add all sections to content view
        contentView.addSubview(headerView)
        contentView.addSubview(heroSection)
        contentView.addSubview(statsSection)
        contentView.addSubview(categoriesSection)
        contentView.addSubview(featuredSection)
        contentView.addSubview(recentSection)
    }
    
    private func setupHeader() {
        headerView.backgroundColor = .clear
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Discover"
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Find your perfect room"
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = AppColors.textSecondary
        
        // Profile button
        profileButton.setImage(UIImage(systemName: "person.circle.fill"), for: .normal)
        profileButton.tintColor = AppColors.primaryPurple
        profileButton.addTarget(self, action: #selector(profileTapped), for: .touchUpInside)
        
        // Notification button
        notificationButton.setImage(UIImage(systemName: "bell.fill"), for: .normal)
        notificationButton.tintColor = AppColors.primaryPurple
        notificationButton.addTarget(self, action: #selector(notificationsTapped), for: .touchUpInside)
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        headerView.addSubview(profileButton)
        headerView.addSubview(notificationButton)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        notificationButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            
            profileButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            profileButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            profileButton.widthAnchor.constraint(equalToConstant: 32),
            profileButton.heightAnchor.constraint(equalToConstant: 32),
            
            notificationButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            notificationButton.trailingAnchor.constraint(equalTo: profileButton.leadingAnchor, constant: -12),
            notificationButton.widthAnchor.constraint(equalToConstant: 32),
            notificationButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupHeroSection() {
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
            heroScrollView.heightAnchor.constraint(equalToConstant: 300),
            
            heroStackView.topAnchor.constraint(equalTo: heroScrollView.topAnchor),
            heroStackView.leadingAnchor.constraint(equalTo: heroScrollView.leadingAnchor),
            heroStackView.trailingAnchor.constraint(equalTo: heroScrollView.trailingAnchor),
            heroStackView.bottomAnchor.constraint(equalTo: heroScrollView.bottomAnchor),
            heroStackView.heightAnchor.constraint(equalTo: heroScrollView.heightAnchor),
            heroStackView.widthAnchor.constraint(equalTo: heroScrollView.widthAnchor, multiplier: CGFloat(featuredProperties.count)),
            
            heroPageControl.topAnchor.constraint(equalTo: heroScrollView.bottomAnchor, constant: 16),
            heroPageControl.centerXAnchor.constraint(equalTo: heroSection.centerXAnchor),
            heroPageControl.bottomAnchor.constraint(equalTo: heroSection.bottomAnchor, constant: -20)
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
    
    private func setupStatsSection() {
        statsSection.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.text = "Your Activity"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary
        
        let statsStackView = UIStackView()
        statsStackView.axis = .horizontal
        statsStackView.distribution = .fillEqually
        statsStackView.spacing = 16
        
        // Create stat cards
        let searchesCard = createStatCard(title: "Searches", value: "47", icon: "magnifyingglass", gradient: AppColors.primaryGradient)
        let favoritesCard = createStatCard(title: "Favorites", value: "12", icon: "heart.fill", gradient: AppColors.accentGradient)
        let messagesCard = createStatCard(title: "Messages", value: "156", icon: "message.fill", gradient: [AppColors.successGreen.cgColor, AppColors.successGreen.withAlphaComponent(0.7).cgColor])
        
        statsStackView.addArrangedSubview(searchesCard)
        statsStackView.addArrangedSubview(favoritesCard)
        statsStackView.addArrangedSubview(messagesCard)
        
        statsSection.addSubview(titleLabel)
        statsSection.addSubview(statsStackView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: statsSection.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: statsSection.leadingAnchor, constant: 20),
            
            statsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            statsStackView.leadingAnchor.constraint(equalTo: statsSection.leadingAnchor, constant: 20),
            statsStackView.trailingAnchor.constraint(equalTo: statsSection.trailingAnchor, constant: -20),
            statsStackView.bottomAnchor.constraint(equalTo: statsSection.bottomAnchor, constant: -20),
            statsStackView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    private func createStatCard(title: String, value: String, icon: String, gradient: [CGColor]) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.1
        card.layer.shadowOffset = CGSize(width: 0, y: 4)
        card.layer.shadowRadius = 12
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = gradient
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 16
        card.layer.insertSublayer(gradientLayer, at: 0)
        
        let iconImageView = UIImageView(image: UIImage(systemName: icon))
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 20, weight: .bold)
        valueLabel.textColor = .white
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        
        card.addSubview(iconImageView)
        card.addSubview(valueLabel)
        card.addSubview(titleLabel)
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            iconImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            valueLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            valueLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: -4),
            
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: iconImageView.leadingAnchor, constant: -8)
        ])
        
        DispatchQueue.main.async {
            gradientLayer.frame = card.bounds
        }
        
        return card
    }
    
    private func setupCategoriesSection() {
        categoriesSection.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.text = "Browse by Category"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary
        
        categoriesSection.addSubview(titleLabel)
        categoriesSection.addSubview(categoriesCollectionView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        categoriesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: categoriesSection.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: categoriesSection.leadingAnchor, constant: 20),
            
            categoriesCollectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            categoriesCollectionView.leadingAnchor.constraint(equalTo: categoriesSection.leadingAnchor),
            categoriesCollectionView.trailingAnchor.constraint(equalTo: categoriesSection.trailingAnchor),
            categoriesCollectionView.bottomAnchor.constraint(equalTo: categoriesSection.bottomAnchor, constant: -20),
            categoriesCollectionView.heightAnchor.constraint(equalToConstant: 100)
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
    
    private func setupRecentSection() {
        recentSection.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.text = "Recently Viewed"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary
        
        recentSection.addSubview(titleLabel)
        recentSection.addSubview(recentCollectionView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        recentCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: recentSection.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: recentSection.leadingAnchor, constant: 20),
            
            recentCollectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            recentCollectionView.leadingAnchor.constraint(equalTo: recentSection.leadingAnchor),
            recentCollectionView.trailingAnchor.constraint(equalTo: recentSection.trailingAnchor),
            recentCollectionView.bottomAnchor.constraint(equalTo: recentSection.bottomAnchor, constant: -20),
            recentCollectionView.heightAnchor.constraint(equalToConstant: 200)
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
        
        // Recent collection view
        recentCollectionView.backgroundColor = .clear
        recentCollectionView.showsHorizontalScrollIndicator = false
        recentCollectionView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        recentCollectionView.register(CompactPropertyCard.self, forCellWithReuseIdentifier: "CompactPropertyCard")
        recentCollectionView.dataSource = self
        recentCollectionView.delegate = self
    }
    
    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
        heroSection.translatesAutoresizingMaskIntoConstraints = false
        statsSection.translatesAutoresizingMaskIntoConstraints = false
        categoriesSection.translatesAutoresizingMaskIntoConstraints = false
        featuredSection.translatesAutoresizingMaskIntoConstraints = false
        recentSection.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            heroSection.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            heroSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            heroSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            statsSection.topAnchor.constraint(equalTo: heroSection.bottomAnchor),
            statsSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statsSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            categoriesSection.topAnchor.constraint(equalTo: statsSection.bottomAnchor),
            categoriesSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            categoriesSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            featuredSection.topAnchor.constraint(equalTo: categoriesSection.bottomAnchor),
            featuredSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            featuredSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            recentSection.topAnchor.constraint(equalTo: featuredSection.bottomAnchor),
            recentSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            recentSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            recentSection.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    private func setupRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        scrollView.refreshControl = refreshControl
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
    
    @objc private func refreshData() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.scrollView.refreshControl?.endRefreshing()
            self.loadData()
        }
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
        case recentCollectionView:
            return min(featuredProperties.count, 5)
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
            
        case recentCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CompactPropertyCard", for: indexPath) as! CompactPropertyCard
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
        case recentCollectionView:
            return CGSize(width: 160, height: 200)
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
            
        case featuredCollectionView, recentCollectionView:
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

