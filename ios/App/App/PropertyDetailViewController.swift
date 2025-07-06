import UIKit

class PropertyDetailViewController: UIViewController {
    
    private let property: PropertyModel
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Hero image gallery
    private let imageGalleryContainer = UIView()
    private let imageScrollView = UIScrollView()
    private let imageStackView = UIStackView()
    private let imagePageControl = UIPageControl()
    private var currentImageIndex = 0
    
    // Floating action buttons
    private let favoriteButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    
    // Property images
    private let propertyImages = ["luxury1", "modern1", "studio1", "photo", "photo.fill"]
    
    init(property: PropertyModel) {
        self.property = property
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupContent()
        setupNavigationBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Make navigation bar transparent initially
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.tintColor = .white
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore navigation bar
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        navigationController?.navigationBar.shadowImage = nil
        navigationController?.navigationBar.tintColor = AppColors.primaryPurple
    }
    
    private func setupNavigationBar() {
        // Custom back button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.backgroundColor
        
        // Setup scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
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
    
    private func setupContent() {
        // Image Gallery
        let imageGallery = createImageGallery()
        
        // Property Info
        let propertyInfo = createPropertyInfo()
        
        // Description
        let descriptionSection = createDescriptionSection()
        
        // Amenities
        let amenitiesSection = createAmenitiesSection()
        
        // Contact Section
        let contactSection = createContactSection()
        
        contentView.addSubview(imageGallery)
        contentView.addSubview(propertyInfo)
        contentView.addSubview(descriptionSection)
        contentView.addSubview(amenitiesSection)
        contentView.addSubview(contactSection)
        
        imageGallery.translatesAutoresizingMaskIntoConstraints = false
        propertyInfo.translatesAutoresizingMaskIntoConstraints = false
        descriptionSection.translatesAutoresizingMaskIntoConstraints = false
        amenitiesSection.translatesAutoresizingMaskIntoConstraints = false
        contactSection.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageGallery.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageGallery.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageGallery.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            propertyInfo.topAnchor.constraint(equalTo: imageGallery.bottomAnchor, constant: 20),
            propertyInfo.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            propertyInfo.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            descriptionSection.topAnchor.constraint(equalTo: propertyInfo.bottomAnchor, constant: 20),
            descriptionSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            descriptionSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            amenitiesSection.topAnchor.constraint(equalTo: descriptionSection.bottomAnchor, constant: 20),
            amenitiesSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            amenitiesSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            contactSection.topAnchor.constraint(equalTo: amenitiesSection.bottomAnchor, constant: 20),
            contactSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contactSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contactSection.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -100)
        ])
    }
    
    private func createImageGallery() -> UIView {
        // Configure image scroll view
        imageScrollView.isPagingEnabled = true
        imageScrollView.showsHorizontalScrollIndicator = false
        imageScrollView.delegate = self
        
        // Configure stack view
        imageStackView.axis = .horizontal
        imageStackView.spacing = 0
        imageStackView.distribution = .fillEqually
        
        // Add images to stack view
        for imageName in propertyImages {
            let imageView = UIImageView()
            imageView.backgroundColor = AppColors.separatorColor
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            
            // Try to load image, fallback to system image
            if let image = UIImage(named: imageName) {
                imageView.image = image
            } else {
                imageView.image = UIImage(systemName: imageName)
                imageView.tintColor = AppColors.textSecondary
            }
            
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
            
            imageStackView.addArrangedSubview(imageView)
        }
        
        // Configure page control
        imagePageControl.numberOfPages = propertyImages.count
        imagePageControl.currentPage = 0
        imagePageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.5)
        imagePageControl.currentPageIndicatorTintColor = .white
        imagePageControl.hidesForSinglePage = true
        
        // Setup floating buttons
        setupFloatingButtons()
        
        // Add subviews
        imageGalleryContainer.addSubview(imageScrollView)
        imageScrollView.addSubview(imageStackView)
        imageGalleryContainer.addSubview(imagePageControl)
        imageGalleryContainer.addSubview(favoriteButton)
        imageGalleryContainer.addSubview(shareButton)
        
        // Setup constraints
        imageScrollView.translatesAutoresizingMaskIntoConstraints = false
        imageStackView.translatesAutoresizingMaskIntoConstraints = false
        imagePageControl.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageScrollView.topAnchor.constraint(equalTo: imageGalleryContainer.topAnchor),
            imageScrollView.leadingAnchor.constraint(equalTo: imageGalleryContainer.leadingAnchor),
            imageScrollView.trailingAnchor.constraint(equalTo: imageGalleryContainer.trailingAnchor),
            imageScrollView.bottomAnchor.constraint(equalTo: imageGalleryContainer.bottomAnchor),
            imageScrollView.heightAnchor.constraint(equalToConstant: 350),
            
            imageStackView.topAnchor.constraint(equalTo: imageScrollView.topAnchor),
            imageStackView.leadingAnchor.constraint(equalTo: imageScrollView.leadingAnchor),
            imageStackView.trailingAnchor.constraint(equalTo: imageScrollView.trailingAnchor),
            imageStackView.bottomAnchor.constraint(equalTo: imageScrollView.bottomAnchor),
            imageStackView.heightAnchor.constraint(equalTo: imageScrollView.heightAnchor),
            
            imagePageControl.bottomAnchor.constraint(equalTo: imageGalleryContainer.bottomAnchor, constant: -20),
            imagePageControl.centerXAnchor.constraint(equalTo: imageGalleryContainer.centerXAnchor)
        ])
        
        return imageGalleryContainer
    }
    
    private func setupFloatingButtons() {
        // Favorite button
        favoriteButton.setImage(UIImage(systemName: "heart.fill"), for: .normal)
        favoriteButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        favoriteButton.tintColor = AppColors.errorRed
        favoriteButton.layer.cornerRadius = 22
        favoriteButton.addTarget(self, action: #selector(favoriteTapped), for: .touchUpInside)
        
        // Share button  
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        shareButton.tintColor = .white
        shareButton.layer.cornerRadius = 22
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            favoriteButton.topAnchor.constraint(equalTo: imageGalleryContainer.safeAreaLayoutGuide.topAnchor, constant: 16),
            favoriteButton.trailingAnchor.constraint(equalTo: imageGalleryContainer.trailingAnchor, constant: -20),
            favoriteButton.widthAnchor.constraint(equalToConstant: 44),
            favoriteButton.heightAnchor.constraint(equalToConstant: 44),
            
            shareButton.topAnchor.constraint(equalTo: favoriteButton.bottomAnchor, constant: 12),
            shareButton.trailingAnchor.constraint(equalTo: imageGalleryContainer.trailingAnchor, constant: -20),
            shareButton.widthAnchor.constraint(equalToConstant: 44),
            shareButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func createPropertyInfo() -> UIView {
        let infoView = UIView()
        infoView.backgroundColor = AppColors.cardBackground
        infoView.layer.cornerRadius = 20
        infoView.layer.shadowColor = UIColor.black.cgColor
        infoView.layer.shadowOpacity = 0.08
        infoView.layer.shadowOffset = CGSize(width: 0, y: 4)
        infoView.layer.shadowRadius = 12
        
        // Top row with title and price
        let topContainer = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = property.title
        titleLabel.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.numberOfLines = 0
        
        let priceContainer = UIView()
        priceContainer.backgroundColor = AppColors.primaryPurple.withAlphaComponent(0.1)
        priceContainer.layer.cornerRadius = 16
        
        let priceLabel = UILabel()
        priceLabel.text = "$\(property.price)"
        priceLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        priceLabel.textColor = AppColors.primaryPurple
        
        let periodLabel = UILabel()
        periodLabel.text = "/month"
        periodLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        periodLabel.textColor = AppColors.textSecondary
        
        // Rating and verification
        let ratingContainer = UIView()
        
        let starIcon = UIImageView(image: UIImage(systemName: "star.fill"))
        starIcon.tintColor = .systemYellow
        starIcon.contentMode = .scaleAspectFit
        
        let ratingLabel = UILabel()
        ratingLabel.text = String(format: "%.1f", property.rating)
        ratingLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        ratingLabel.textColor = AppColors.textPrimary
        
        let verifiedBadge = UIView()
        if property.isVerified {
            verifiedBadge.backgroundColor = AppColors.successGreen
            verifiedBadge.layer.cornerRadius = 12
            
            let checkIcon = UIImageView(image: UIImage(systemName: "checkmark.seal.fill"))
            checkIcon.tintColor = .white
            checkIcon.contentMode = .scaleAspectFit
            
            let verifiedLabel = UILabel()
            verifiedLabel.text = "Verified"
            verifiedLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            verifiedLabel.textColor = .white
            
            verifiedBadge.addSubview(checkIcon)
            verifiedBadge.addSubview(verifiedLabel)
            
            checkIcon.translatesAutoresizingMaskIntoConstraints = false
            verifiedLabel.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                checkIcon.leadingAnchor.constraint(equalTo: verifiedBadge.leadingAnchor, constant: 8),
                checkIcon.centerYAnchor.constraint(equalTo: verifiedBadge.centerYAnchor),
                checkIcon.widthAnchor.constraint(equalToConstant: 16),
                checkIcon.heightAnchor.constraint(equalToConstant: 16),
                
                verifiedLabel.leadingAnchor.constraint(equalTo: checkIcon.trailingAnchor, constant: 4),
                verifiedLabel.centerYAnchor.constraint(equalTo: verifiedBadge.centerYAnchor),
                verifiedLabel.trailingAnchor.constraint(equalTo: verifiedBadge.trailingAnchor, constant: -8),
                
                verifiedBadge.heightAnchor.constraint(equalToConstant: 24)
            ])
        }
        
        // Location and details
        let locationIcon = UIImageView(image: UIImage(systemName: "location.fill"))
        locationIcon.tintColor = AppColors.primaryPurple
        locationIcon.contentMode = .scaleAspectFit
        
        let locationLabel = UILabel()
        locationLabel.text = property.location
        locationLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        locationLabel.textColor = AppColors.textSecondary
        
        let detailsContainer = UIView()
        detailsContainer.backgroundColor = AppColors.separatorColor.withAlphaComponent(0.3)
        detailsContainer.layer.cornerRadius = 12
        
        let bedroomIcon = UIImageView(image: UIImage(systemName: "bed.double.fill"))
        bedroomIcon.tintColor = AppColors.textSecondary
        bedroomIcon.contentMode = .scaleAspectFit
        
        let bedroomLabel = UILabel()
        bedroomLabel.text = "\(property.bedrooms) bed"
        bedroomLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        bedroomLabel.textColor = AppColors.textPrimary
        
        let bathroomIcon = UIImageView(image: UIImage(systemName: "drop.fill"))
        bathroomIcon.tintColor = AppColors.textSecondary
        bathroomIcon.contentMode = .scaleAspectFit
        
        let bathroomLabel = UILabel()
        bathroomLabel.text = "\(property.bathrooms) bath"
        bathroomLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        bathroomLabel.textColor = AppColors.textPrimary
        
        // Add subviews
        infoView.addSubview(topContainer)
        topContainer.addSubview(titleLabel)
        topContainer.addSubview(priceContainer)
        priceContainer.addSubview(priceLabel)
        priceContainer.addSubview(periodLabel)
        
        infoView.addSubview(ratingContainer)
        ratingContainer.addSubview(starIcon)
        ratingContainer.addSubview(ratingLabel)
        if property.isVerified {
            ratingContainer.addSubview(verifiedBadge)
        }
        
        infoView.addSubview(locationIcon)
        infoView.addSubview(locationLabel)
        infoView.addSubview(detailsContainer)
        detailsContainer.addSubview(bedroomIcon)
        detailsContainer.addSubview(bedroomLabel)
        detailsContainer.addSubview(bathroomIcon)
        detailsContainer.addSubview(bathroomLabel)
        
        // Setup constraints
        [topContainer, titleLabel, priceContainer, priceLabel, periodLabel, ratingContainer,
         starIcon, ratingLabel, locationIcon, locationLabel, detailsContainer, bedroomIcon,
         bedroomLabel, bathroomIcon, bathroomLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        var constraints = [
            topContainer.topAnchor.constraint(equalTo: infoView.topAnchor, constant: 24),
            topContainer.leadingAnchor.constraint(equalTo: infoView.leadingAnchor, constant: 24),
            topContainer.trailingAnchor.constraint(equalTo: infoView.trailingAnchor, constant: -24),
            
            titleLabel.topAnchor.constraint(equalTo: topContainer.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: topContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: priceContainer.leadingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: topContainer.bottomAnchor),
            
            priceContainer.topAnchor.constraint(equalTo: topContainer.topAnchor),
            priceContainer.trailingAnchor.constraint(equalTo: topContainer.trailingAnchor),
            priceContainer.bottomAnchor.constraint(equalTo: topContainer.bottomAnchor),
            
            priceLabel.topAnchor.constraint(equalTo: priceContainer.topAnchor, constant: 12),
            priceLabel.leadingAnchor.constraint(equalTo: priceContainer.leadingAnchor, constant: 16),
            priceLabel.trailingAnchor.constraint(equalTo: priceContainer.trailingAnchor, constant: -16),
            
            periodLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 2),
            periodLabel.leadingAnchor.constraint(equalTo: priceContainer.leadingAnchor, constant: 16),
            periodLabel.trailingAnchor.constraint(equalTo: priceContainer.trailingAnchor, constant: -16),
            periodLabel.bottomAnchor.constraint(equalTo: priceContainer.bottomAnchor, constant: -12),
            
            ratingContainer.topAnchor.constraint(equalTo: topContainer.bottomAnchor, constant: 20),
            ratingContainer.leadingAnchor.constraint(equalTo: infoView.leadingAnchor, constant: 24),
            ratingContainer.heightAnchor.constraint(equalToConstant: 24),
            
            starIcon.leadingAnchor.constraint(equalTo: ratingContainer.leadingAnchor),
            starIcon.centerYAnchor.constraint(equalTo: ratingContainer.centerYAnchor),
            starIcon.widthAnchor.constraint(equalToConstant: 16),
            starIcon.heightAnchor.constraint(equalToConstant: 16),
            
            ratingLabel.leadingAnchor.constraint(equalTo: starIcon.trailingAnchor, constant: 6),
            ratingLabel.centerYAnchor.constraint(equalTo: ratingContainer.centerYAnchor),
            ratingLabel.trailingAnchor.constraint(equalTo: ratingContainer.trailingAnchor),
            
            locationIcon.topAnchor.constraint(equalTo: ratingContainer.bottomAnchor, constant: 16),
            locationIcon.leadingAnchor.constraint(equalTo: infoView.leadingAnchor, constant: 24),
            locationIcon.widthAnchor.constraint(equalToConstant: 16),
            locationIcon.heightAnchor.constraint(equalToConstant: 16),
            
            locationLabel.centerYAnchor.constraint(equalTo: locationIcon.centerYAnchor),
            locationLabel.leadingAnchor.constraint(equalTo: locationIcon.trailingAnchor, constant: 8),
            locationLabel.trailingAnchor.constraint(equalTo: infoView.trailingAnchor, constant: -24),
            
            detailsContainer.topAnchor.constraint(equalTo: locationIcon.bottomAnchor, constant: 16),
            detailsContainer.leadingAnchor.constraint(equalTo: infoView.leadingAnchor, constant: 24),
            detailsContainer.trailingAnchor.constraint(equalTo: infoView.trailingAnchor, constant: -24),
            detailsContainer.bottomAnchor.constraint(equalTo: infoView.bottomAnchor, constant: -24),
            detailsContainer.heightAnchor.constraint(equalToConstant: 40),
            
            bedroomIcon.leadingAnchor.constraint(equalTo: detailsContainer.leadingAnchor, constant: 16),
            bedroomIcon.centerYAnchor.constraint(equalTo: detailsContainer.centerYAnchor),
            bedroomIcon.widthAnchor.constraint(equalToConstant: 16),
            bedroomIcon.heightAnchor.constraint(equalToConstant: 16),
            
            bedroomLabel.leadingAnchor.constraint(equalTo: bedroomIcon.trailingAnchor, constant: 8),
            bedroomLabel.centerYAnchor.constraint(equalTo: detailsContainer.centerYAnchor),
            
            bathroomIcon.leadingAnchor.constraint(equalTo: bedroomLabel.trailingAnchor, constant: 24),
            bathroomIcon.centerYAnchor.constraint(equalTo: detailsContainer.centerYAnchor),
            bathroomIcon.widthAnchor.constraint(equalToConstant: 16),
            bathroomIcon.heightAnchor.constraint(equalToConstant: 16),
            
            bathroomLabel.leadingAnchor.constraint(equalTo: bathroomIcon.trailingAnchor, constant: 8),
            bathroomLabel.centerYAnchor.constraint(equalTo: detailsContainer.centerYAnchor),
            bathroomLabel.trailingAnchor.constraint(lessThanOrEqualTo: detailsContainer.trailingAnchor, constant: -16)
        ]
        
        if property.isVerified {
            constraints.append(contentsOf: [
                verifiedBadge.leadingAnchor.constraint(equalTo: ratingLabel.trailingAnchor, constant: 12),
                verifiedBadge.centerYAnchor.constraint(equalTo: ratingContainer.centerYAnchor),
                verifiedBadge.trailingAnchor.constraint(lessThanOrEqualTo: infoView.trailingAnchor, constant: -24)
            ])
        }
        
        NSLayoutConstraint.activate(constraints)
        
        return infoView
    }
    
    private func createDescriptionSection() -> UIView {
        let section = UIView()
        section.backgroundColor = AppColors.cardBackground
        section.layer.cornerRadius = 16
        
        let titleLabel = UILabel()
        titleLabel.text = "Description"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = AppColors.textPrimary
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = "This beautiful property offers modern living in the heart of the city. Features include updated appliances, hardwood floors, and plenty of natural light. Perfect for professionals or students looking for a comfortable and convenient home."
        descriptionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        descriptionLabel.textColor = AppColors.textSecondary
        descriptionLabel.numberOfLines = 0
        
        section.addSubview(titleLabel)
        section.addSubview(descriptionLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: section.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -20),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -20),
            descriptionLabel.bottomAnchor.constraint(equalTo: section.bottomAnchor, constant: -20)
        ])
        
        return section
    }
    
    private func createAmenitiesSection() -> UIView {
        let section = UIView()
        section.backgroundColor = AppColors.cardBackground
        section.layer.cornerRadius = 16
        
        let titleLabel = UILabel()
        titleLabel.text = "Amenities"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = AppColors.textPrimary
        
        let amenitiesStackView = UIStackView()
        amenitiesStackView.axis = .vertical
        amenitiesStackView.spacing = 12
        amenitiesStackView.distribution = .fill
        
        for amenity in property.amenities {
            let amenityView = createAmenityRow(title: amenity)
            amenitiesStackView.addArrangedSubview(amenityView)
        }
        
        section.addSubview(titleLabel)
        section.addSubview(amenitiesStackView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        amenitiesStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: section.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -20),
            
            amenitiesStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            amenitiesStackView.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 20),
            amenitiesStackView.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -20),
            amenitiesStackView.bottomAnchor.constraint(equalTo: section.bottomAnchor, constant: -20)
        ])
        
        return section
    }
    
    private func createAmenityRow(title: String) -> UIView {
        let row = UIView()
        
        let checkIcon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkIcon.tintColor = AppColors.successGreen
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = AppColors.textPrimary
        
        row.addSubview(checkIcon)
        row.addSubview(titleLabel)
        
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            checkIcon.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            checkIcon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            checkIcon.widthAnchor.constraint(equalToConstant: 20),
            checkIcon.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: checkIcon.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            
            row.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return row
    }
    
    private func createContactSection() -> UIView {
        let section = UIView()
        
        let contactButton = UIButton(type: .system)
        contactButton.setTitle("Contact Landlord", for: .normal)
        contactButton.backgroundColor = AppColors.primaryPurple
        contactButton.setTitleColor(.white, for: .normal)
        contactButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        contactButton.layer.cornerRadius = 25
        contactButton.addTarget(self, action: #selector(contactTapped), for: .touchUpInside)
        
        let negotiateButton = UIButton(type: .system)
        negotiateButton.setTitle("AI Negotiate Price", for: .normal)
        negotiateButton.backgroundColor = AppColors.accentBlue
        negotiateButton.setTitleColor(.white, for: .normal)
        negotiateButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        negotiateButton.layer.cornerRadius = 25
        negotiateButton.addTarget(self, action: #selector(negotiateTapped), for: .touchUpInside)
        
        section.addSubview(contactButton)
        section.addSubview(negotiateButton)
        
        contactButton.translatesAutoresizingMaskIntoConstraints = false
        negotiateButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            contactButton.topAnchor.constraint(equalTo: section.topAnchor),
            contactButton.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 20),
            contactButton.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -20),
            contactButton.heightAnchor.constraint(equalToConstant: 50),
            
            negotiateButton.topAnchor.constraint(equalTo: contactButton.bottomAnchor, constant: 16),
            negotiateButton.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 20),
            negotiateButton.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -20),
            negotiateButton.heightAnchor.constraint(equalToConstant: 50),
            negotiateButton.bottomAnchor.constraint(equalTo: section.bottomAnchor)
        ])
        
        return section
    }
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func favoriteTapped() {
        // Toggle favorite status with animation
        favoriteButton.isSelected.toggle()
        
        let newImage = favoriteButton.isSelected ? UIImage(systemName: "heart.fill") : UIImage(systemName: "heart")
        favoriteButton.setImage(newImage, for: .normal)
        
        // Animate button
        UIView.animate(withDuration: 0.2, animations: {
            self.favoriteButton.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.favoriteButton.transform = .identity
            }
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    @objc private func shareTapped() {
        let shareText = "Check out this amazing property: \(property.title) for $\(property.price)/month in \(property.location)"
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        
        present(activityVC, animated: true)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    @objc private func contactTapped() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        let alert = UIAlertController(title: "Contact Landlord", message: "Choose your preferred contact method", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "📞 Call Now", style: .default) { _ in
            self.makePhoneCall()
        })
        
        alert.addAction(UIAlertAction(title: "💬 Send Message", style: .default) { _ in
            self.sendMessage()
        })
        
        alert.addAction(UIAlertAction(title: "📧 Email Inquiry", style: .default) { _ in
            self.sendEmail()
        })
        
        alert.addAction(UIAlertAction(title: "📅 Schedule Tour", style: .default) { _ in
            self.scheduleTour()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func makePhoneCall() {
        let phoneNumber = "tel://+1234567890"
        if let url = URL(string: phoneNumber), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            showContactAlert(message: "Phone calling is not available on this device.")
        }
    }
    
    private func sendMessage() {
        // Show native messaging interface
        let alert = UIAlertController(title: "Send Message", message: "Your message will be sent to the landlord.", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Type your message here..."
            textField.font = .systemFont(ofSize: 16)
        }
        
        alert.addAction(UIAlertAction(title: "Send", style: .default) { _ in
            if let message = alert.textFields?.first?.text, !message.isEmpty {
                self.showContactAlert(message: "Message sent successfully!")
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func sendEmail() {
        let email = "mailto:landlord@property.com?subject=Inquiry about \(property.title)&body=Hi, I'm interested in learning more about this property."
        if let url = URL(string: email), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            showContactAlert(message: "Email is not configured on this device.")
        }
    }
    
    private func scheduleTour() {
        let alert = UIAlertController(title: "Schedule Tour", message: "When would you like to schedule a property tour?", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "🌅 Tomorrow Morning", style: .default) { _ in
            self.showContactAlert(message: "Tour scheduled for tomorrow morning. You'll receive a confirmation email shortly.")
        })
        
        alert.addAction(UIAlertAction(title: "🌆 Tomorrow Afternoon", style: .default) { _ in
            self.showContactAlert(message: "Tour scheduled for tomorrow afternoon. You'll receive a confirmation email shortly.")
        })
        
        alert.addAction(UIAlertAction(title: "🗺️ This Weekend", style: .default) { _ in
            self.showContactAlert(message: "Tour scheduled for this weekend. You'll receive a confirmation email shortly.")
        })
        
        alert.addAction(UIAlertAction(title: "📅 Choose Custom Time", style: .default) { _ in
            self.showDatePicker()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }
    
    private func showDatePicker() {
        let alert = UIAlertController(title: "Select Date & Time", message: "\n\n\n\n\n\n", preferredStyle: .alert)
        
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .compact
        datePicker.minimumDate = Date()
        
        alert.setValue(datePicker, forKey: "contentViewController")
        
        alert.addAction(UIAlertAction(title: "Schedule", style: .default) { _ in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let dateString = formatter.string(from: datePicker.date)
            self.showContactAlert(message: "Tour scheduled for \(dateString). You'll receive a confirmation email shortly.")
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showContactAlert(message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        
        // Add success haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    @objc private func negotiateTapped() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Show AI negotiation options
        let alert = UIAlertController(title: "AI Negotiation Assistant", message: "Let our AI help you negotiate the best deal!", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "🤖 Start AI Negotiation Chat", style: .default) { _ in
            self.startAINegotiation()
        })
        
        alert.addAction(UIAlertAction(title: "📊 Get Market Analysis", style: .default) { _ in
            self.getMarketAnalysis()
        })
        
        alert.addAction(UIAlertAction(title: "💰 Price Suggestion Tool", style: .default) { _ in
            self.showPriceSuggestion()
        })
        
        alert.addAction(UIAlertAction(title: "📝 Generate Counter Offer", style: .default) { _ in
            self.generateCounterOffer()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }
    
    private func startAINegotiation() {
        // Navigate to AI chat with pre-filled negotiation context
        if let tabBarController = self.tabBarController {
            tabBarController.selectedIndex = 3 // Switch to chat tab
        }
        
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    private func getMarketAnalysis() {
        let alert = UIAlertController(
            title: "Market Analysis", 
            message: "Based on current market data:\n\n• Average rent in \(property.location): $\(property.price + 200)\n• This property is 8% below market average\n• Similar properties: $\(property.price - 100) - $\(property.price + 300)\n• Negotiation potential: Medium", 
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showPriceSuggestion() {
        let suggestedPrice = property.price - 150
        let alert = UIAlertController(
            title: "AI Price Suggestion", 
            message: "Based on market analysis and property features, we suggest negotiating for:\n\n$\(suggestedPrice)/month\n\nThis represents a $150 monthly savings and is within reasonable negotiation range.", 
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Use This Price", style: .default) { _ in
            self.generateCounterOffer(withPrice: suggestedPrice)
        })
        
        alert.addAction(UIAlertAction(title: "Adjust Price", style: .default) { _ in
            self.showCustomPriceInput()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showCustomPriceInput() {
        let alert = UIAlertController(title: "Custom Price", message: "Enter your desired monthly rent:", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "$\(self.property.price - 100)"
            textField.keyboardType = .numberPad
            textField.font = .systemFont(ofSize: 16)
        }
        
        alert.addAction(UIAlertAction(title: "Generate Offer", style: .default) { _ in
            if let priceText = alert.textFields?.first?.text,
               let customPrice = Int(priceText.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) {
                self.generateCounterOffer(withPrice: customPrice)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func generateCounterOffer(withPrice price: Int? = nil) {
        let offerPrice = price ?? (property.price - 150)
        let savings = property.price - offerPrice
        
        let alert = UIAlertController(
            title: "Generated Counter Offer", 
            message: "Dear Landlord,\n\nI'm very interested in \(property.title). Based on my research of comparable properties in \(property.location), I would like to propose a monthly rent of $\(offerPrice).\n\nThis would represent fair market value considering current conditions. I'm a reliable tenant and ready to sign a lease promptly.\n\nBest regards", 
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Send Offer", style: .default) { _ in
            self.showContactAlert(message: "Counter offer sent successfully! You'll hear back within 24 hours.")
        })
        
        alert.addAction(UIAlertAction(title: "Edit Offer", style: .default) { _ in
            self.showCustomPriceInput()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
}

// MARK: - UIScrollViewDelegate
extension PropertyDetailViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == imageScrollView {
            // Update page control for image gallery
            let pageIndex = round(scrollView.contentOffset.x / scrollView.frame.width)
            imagePageControl.currentPage = Int(pageIndex)
            currentImageIndex = Int(pageIndex)
        } else {
            // Handle main scroll view for navigation bar transparency
            let offset = scrollView.contentOffset.y
            let alpha = min(1.0, max(0.0, offset / 100.0))
            
            // Update navigation bar appearance
            navigationController?.navigationBar.backgroundColor = AppColors.backgroundColor.withAlphaComponent(alpha)
            navigationController?.navigationBar.tintColor = alpha > 0.5 ? AppColors.primaryPurple : .white
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView == imageScrollView {
            // Add haptic feedback when changing images
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}