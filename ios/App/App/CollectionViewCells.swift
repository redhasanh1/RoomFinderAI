import UIKit

// MARK: - Category Cell
class CategoryCell: UICollectionViewCell {
    
    private let containerView = UIView()
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        containerView.backgroundColor = AppColors.cardBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.08
        containerView.layer.shadowOffset = CGSize(width: 0, y: 2)
        containerView.layer.shadowRadius = 8
        
        iconLabel.font = .systemFont(ofSize: 24)
        iconLabel.textAlignment = .center
        
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        
        countLabel.font = .systemFont(ofSize: 10, weight: .medium)
        countLabel.textColor = AppColors.textSecondary
        countLabel.textAlignment = .center
        
        contentView.addSubview(containerView)
        containerView.addSubview(iconLabel)
        containerView.addSubview(titleLabel)
        containerView.addSubview(countLabel)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            iconLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            iconLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
            
            countLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            countLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            countLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with category: CategoryModel) {
        iconLabel.text = category.icon
        titleLabel.text = category.name
        countLabel.text = "\(category.count) available"
        
        // Add subtle color accent
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = category.color.withAlphaComponent(0.2).cgColor
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconLabel.text = nil
        titleLabel.text = nil
        countLabel.text = nil
        containerView.layer.borderColor = UIColor.clear.cgColor
    }
}

// MARK: - Property Card
class PropertyCard: UICollectionViewCell {
    
    private let containerView = UIView()
    private let imageView = UIImageView()
    private let overlayView = UIView()
    private let verifiedBadge = UIView()
    private let verifiedIcon = UIImageView()
    private let verifiedLabel = UILabel()
    private let favoriteButton = UIButton(type: .system)
    private let ratingContainer = UIView()
    private let starIcon = UIImageView()
    private let ratingLabel = UILabel()
    private let titleLabel = UILabel()
    private let locationLabel = UILabel()
    private let priceLabel = UILabel()
    private let detailsLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        // Container
        containerView.backgroundColor = AppColors.cardBackground
        containerView.layer.cornerRadius = 20
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, y: 4)
        containerView.layer.shadowRadius = 12
        containerView.clipsToBounds = false
        
        // Image
        imageView.backgroundColor = AppColors.separatorColor
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.image = UIImage(systemName: "photo.fill")
        imageView.tintColor = AppColors.textSecondary
        
        // Overlay for better text readability
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        overlayView.layer.cornerRadius = 16
        
        // Verified badge
        verifiedBadge.backgroundColor = AppColors.successGreen
        verifiedBadge.layer.cornerRadius = 12
        verifiedBadge.isHidden = true
        
        verifiedIcon.image = UIImage(systemName: "checkmark")
        verifiedIcon.tintColor = .white
        verifiedIcon.contentMode = .scaleAspectFit
        
        verifiedLabel.text = "Verified"
        verifiedLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        verifiedLabel.textColor = .white
        
        // Favorite button
        favoriteButton.setImage(UIImage(systemName: "heart"), for: .normal)
        favoriteButton.setImage(UIImage(systemName: "heart.fill"), for: .selected)
        favoriteButton.tintColor = AppColors.errorRed
        favoriteButton.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        favoriteButton.layer.cornerRadius = 18
        favoriteButton.layer.shadowColor = UIColor.black.cgColor
        favoriteButton.layer.shadowOpacity = 0.2
        favoriteButton.layer.shadowOffset = CGSize(width: 0, y: 2)
        favoriteButton.layer.shadowRadius = 4
        favoriteButton.addTarget(self, action: #selector(favoriteToggled), for: .touchUpInside)
        
        // Rating
        ratingContainer.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        ratingContainer.layer.cornerRadius = 12
        ratingContainer.layer.shadowColor = UIColor.black.cgColor
        ratingContainer.layer.shadowOpacity = 0.1
        ratingContainer.layer.shadowOffset = CGSize(width: 0, y: 1)
        ratingContainer.layer.shadowRadius = 3
        
        starIcon.image = UIImage(systemName: "star.fill")
        starIcon.tintColor = .systemYellow
        starIcon.contentMode = .scaleAspectFit
        
        ratingLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        ratingLabel.textColor = AppColors.textPrimary
        
        // Labels
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.numberOfLines = 2
        
        locationLabel.font = .systemFont(ofSize: 13, weight: .medium)
        locationLabel.textColor = AppColors.textSecondary
        
        priceLabel.font = .systemFont(ofSize: 18, weight: .bold)
        priceLabel.textColor = AppColors.primaryPurple
        
        detailsLabel.font = .systemFont(ofSize: 12, weight: .medium)
        detailsLabel.textColor = AppColors.textSecondary
        
        // Add subviews
        contentView.addSubview(containerView)
        containerView.addSubview(imageView)
        imageView.addSubview(overlayView)
        imageView.addSubview(verifiedBadge)
        verifiedBadge.addSubview(verifiedIcon)
        verifiedBadge.addSubview(verifiedLabel)
        imageView.addSubview(favoriteButton)
        imageView.addSubview(ratingContainer)
        ratingContainer.addSubview(starIcon)
        ratingContainer.addSubview(ratingLabel)
        containerView.addSubview(titleLabel)
        containerView.addSubview(locationLabel)
        containerView.addSubview(priceLabel)
        containerView.addSubview(detailsLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        [containerView, imageView, overlayView, verifiedBadge, verifiedIcon, verifiedLabel, 
         favoriteButton, ratingContainer, starIcon, ratingLabel, titleLabel, locationLabel, 
         priceLabel, detailsLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            imageView.heightAnchor.constraint(equalToConstant: 160),
            
            overlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            
            verifiedBadge.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 12),
            verifiedBadge.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 12),
            verifiedBadge.heightAnchor.constraint(equalToConstant: 24),
            
            verifiedIcon.leadingAnchor.constraint(equalTo: verifiedBadge.leadingAnchor, constant: 6),
            verifiedIcon.centerYAnchor.constraint(equalTo: verifiedBadge.centerYAnchor),
            verifiedIcon.widthAnchor.constraint(equalToConstant: 12),
            verifiedIcon.heightAnchor.constraint(equalToConstant: 12),
            
            verifiedLabel.leadingAnchor.constraint(equalTo: verifiedIcon.trailingAnchor, constant: 4),
            verifiedLabel.centerYAnchor.constraint(equalTo: verifiedBadge.centerYAnchor),
            verifiedLabel.trailingAnchor.constraint(equalTo: verifiedBadge.trailingAnchor, constant: -6),
            
            favoriteButton.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 12),
            favoriteButton.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -12),
            favoriteButton.widthAnchor.constraint(equalToConstant: 36),
            favoriteButton.heightAnchor.constraint(equalToConstant: 36),
            
            ratingContainer.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -12),
            ratingContainer.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 12),
            ratingContainer.heightAnchor.constraint(equalToConstant: 24),
            
            starIcon.leadingAnchor.constraint(equalTo: ratingContainer.leadingAnchor, constant: 8),
            starIcon.centerYAnchor.constraint(equalTo: ratingContainer.centerYAnchor),
            starIcon.widthAnchor.constraint(equalToConstant: 12),
            starIcon.heightAnchor.constraint(equalToConstant: 12),
            
            ratingLabel.leadingAnchor.constraint(equalTo: starIcon.trailingAnchor, constant: 4),
            ratingLabel.centerYAnchor.constraint(equalTo: ratingContainer.centerYAnchor),
            ratingLabel.trailingAnchor.constraint(equalTo: ratingContainer.trailingAnchor, constant: -8),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            locationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            locationLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            locationLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            priceLabel.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 8),
            priceLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            
            detailsLabel.centerYAnchor.constraint(equalTo: priceLabel.centerYAnchor),
            detailsLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            detailsLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with property: PropertyModel) {
        titleLabel.text = property.title
        locationLabel.text = "📍 \(property.location)"
        priceLabel.text = "$\(property.price)/mo"
        detailsLabel.text = "\(property.bedrooms) bed • \(property.bathrooms) bath"
        ratingLabel.text = String(format: "%.1f", property.rating)
        
        verifiedBadge.isHidden = !property.isVerified
        
        // Add parallax effect
        addParallaxEffect()
    }
    
    private func addParallaxEffect() {
        let parallaxIntensity: CGFloat = 20
        
        let horizontalMotion = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        horizontalMotion.minimumRelativeValue = -parallaxIntensity
        horizontalMotion.maximumRelativeValue = parallaxIntensity
        
        let verticalMotion = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        verticalMotion.minimumRelativeValue = -parallaxIntensity
        verticalMotion.maximumRelativeValue = parallaxIntensity
        
        let motionGroup = UIMotionEffectGroup()
        motionGroup.motionEffects = [horizontalMotion, verticalMotion]
        
        containerView.addMotionEffect(motionGroup)
    }
    
    @objc private func favoriteToggled() {
        favoriteButton.isSelected.toggle()
        
        // Animate heart
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
    
    override func prepareForReuse() {
        super.prepareForReuse()
        favoriteButton.isSelected = false
        verifiedBadge.isHidden = true
        containerView.motionEffects.removeAll()
    }
}

// MARK: - Compact Property Card
class CompactPropertyCard: UICollectionViewCell {
    
    private let containerView = UIView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let locationLabel = UILabel()
    private let ratingContainer = UIView()
    private let starIcon = UIImageView()
    private let ratingLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        containerView.backgroundColor = AppColors.cardBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.08
        containerView.layer.shadowOffset = CGSize(width: 0, y: 2)
        containerView.layer.shadowRadius = 8
        
        imageView.backgroundColor = AppColors.separatorColor
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.image = UIImage(systemName: "photo.fill")
        imageView.tintColor = AppColors.textSecondary
        
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.numberOfLines = 2
        
        priceLabel.font = .systemFont(ofSize: 16, weight: .bold)
        priceLabel.textColor = AppColors.primaryPurple
        
        locationLabel.font = .systemFont(ofSize: 11, weight: .medium)
        locationLabel.textColor = AppColors.textSecondary
        
        ratingContainer.backgroundColor = AppColors.primaryPurple.withAlphaComponent(0.1)
        ratingContainer.layer.cornerRadius = 8
        
        starIcon.image = UIImage(systemName: "star.fill")
        starIcon.tintColor = .systemYellow
        starIcon.contentMode = .scaleAspectFit
        
        ratingLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        ratingLabel.textColor = AppColors.primaryPurple
        
        contentView.addSubview(containerView)
        containerView.addSubview(imageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(priceLabel)
        containerView.addSubview(locationLabel)
        containerView.addSubview(ratingContainer)
        ratingContainer.addSubview(starIcon)
        ratingContainer.addSubview(ratingLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        [containerView, imageView, titleLabel, priceLabel, locationLabel, 
         ratingContainer, starIcon, ratingLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            imageView.heightAnchor.constraint(equalToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            priceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            priceLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            
            ratingContainer.centerYAnchor.constraint(equalTo: priceLabel.centerYAnchor),
            ratingContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            ratingContainer.heightAnchor.constraint(equalToConstant: 16),
            
            starIcon.leadingAnchor.constraint(equalTo: ratingContainer.leadingAnchor, constant: 4),
            starIcon.centerYAnchor.constraint(equalTo: ratingContainer.centerYAnchor),
            starIcon.widthAnchor.constraint(equalToConstant: 8),
            starIcon.heightAnchor.constraint(equalToConstant: 8),
            
            ratingLabel.leadingAnchor.constraint(equalTo: starIcon.trailingAnchor, constant: 2),
            ratingLabel.centerYAnchor.constraint(equalTo: ratingContainer.centerYAnchor),
            ratingLabel.trailingAnchor.constraint(equalTo: ratingContainer.trailingAnchor, constant: -4),
            
            locationLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 2),
            locationLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            locationLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            locationLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with property: PropertyModel) {
        titleLabel.text = property.title
        priceLabel.text = "$\(property.price)/mo"
        locationLabel.text = "📍 \(property.location)"
        ratingLabel.text = String(format: "%.1f", property.rating)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        priceLabel.text = nil
        locationLabel.text = nil
        ratingLabel.text = nil
    }
}