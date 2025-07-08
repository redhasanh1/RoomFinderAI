import UIKit

// MARK: - Featured Property Cell
class FeaturedPropertyCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
        
        // Image view
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        // Gradient overlay
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.7).cgColor]
        gradientLayer.locations = [0.5, 1.0]
        imageView.layer.addSublayer(gradientLayer)
        
        // Title label
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Price label
        priceLabel.font = .systemFont(ofSize: 16, weight: .medium)
        priceLabel.textColor = .white
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(priceLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: priceLabel.topAnchor, constant: -4),
            
            priceLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            priceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            priceLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = imageView.bounds
    }
    
    func configure(with property: Property) {
        titleLabel.text = property.title
        priceLabel.text = "$\(Int(property.price))/month"
        
        // Load property image
        if let firstImage = property.images.first {
            imageView.loadImage(from: firstImage, placeholder: UIImage(systemName: "house.fill"))
        } else {
            // Fallback to a real property image if no image provided
            let fallbackUrl = "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400&h=250&fit=crop"
            imageView.loadImage(from: fallbackUrl, placeholder: UIImage(systemName: "house.fill"))
        }
    }
}

// MARK: - Category Cell
class CategoryCell: UICollectionViewCell {
    private let iconView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Icon container
        iconView.backgroundColor = Theme.Colors.primary.withAlphaComponent(0.1)
        iconView.layer.cornerRadius = 30
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)
        
        // Icon image
        iconImageView.tintColor = Theme.Colors.primary
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconImageView)
        
        // Title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            iconView.widthAnchor.constraint(equalToConstant: 60),
            iconView.heightAnchor.constraint(equalToConstant: 60),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 30),
            iconImageView.heightAnchor.constraint(equalToConstant: 30),
            
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with category: String) {
        titleLabel.text = category
        
        // Set appropriate icon
        let iconName: String
        switch category {
        case "Apartments":
            iconName = "building.2"
        case "Houses":
            iconName = "house"
        case "Condos":
            iconName = "building"
        case "Student Housing":
            iconName = "graduationcap"
        case "Subleases":
            iconName = "doc.text"
        case "Rooms":
            iconName = "bed.double"
        default:
            iconName = "house"
        }
        iconImageView.image = UIImage(systemName: iconName)
    }
}

// MARK: - Property Collection View Cell
class PropertyCollectionViewCell: UICollectionViewCell {
    private let containerView = UIView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let addressLabel = UILabel()
    private let priceLabel = UILabel()
    private let bedroomsLabel = UILabel()
    private let bathroomsLabel = UILabel()
    private let favoriteButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.08
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Image view
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray5
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        
        // Title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Address
        addressLabel.font = .systemFont(ofSize: 14)
        addressLabel.textColor = .secondaryLabel
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(addressLabel)
        
        // Price
        priceLabel.font = .systemFont(ofSize: 18, weight: .bold)
        priceLabel.textColor = .systemBlue
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(priceLabel)
        
        // Bedrooms
        bedroomsLabel.font = .systemFont(ofSize: 13)
        bedroomsLabel.textColor = .secondaryLabel
        bedroomsLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(bedroomsLabel)
        
        // Bathrooms
        bathroomsLabel.font = .systemFont(ofSize: 13)
        bathroomsLabel.textColor = .secondaryLabel
        bathroomsLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(bathroomsLabel)
        
        // Favorite button
        favoriteButton.setImage(UIImage(systemName: "heart"), for: .normal)
        favoriteButton.tintColor = .systemPink
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(favoriteButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            imageView.widthAnchor.constraint(equalToConstant: 100),
            
            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: favoriteButton.leadingAnchor, constant: -8),
            
            addressLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            addressLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            addressLabel.trailingAnchor.constraint(equalTo: favoriteButton.leadingAnchor, constant: -8),
            
            priceLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            priceLabel.bottomAnchor.constraint(equalTo: bedroomsLabel.topAnchor, constant: -4),
            
            bedroomsLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            bedroomsLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            
            bathroomsLabel.leadingAnchor.constraint(equalTo: bedroomsLabel.trailingAnchor, constant: 16),
            bathroomsLabel.centerYAnchor.constraint(equalTo: bedroomsLabel.centerYAnchor),
            
            favoriteButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            favoriteButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            favoriteButton.widthAnchor.constraint(equalToConstant: 30),
            favoriteButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    func configure(with property: Property) {
        titleLabel.text = property.title
        addressLabel.text = "\(property.city), \(property.state)"
        priceLabel.text = "$\(Int(property.price))/month"
        priceLabel.textColor = Theme.Colors.primary
        bedroomsLabel.text = "\(property.bedrooms) bed"
        bathroomsLabel.text = "\(property.bathrooms) bath"
        
        // Load property image
        if let firstImage = property.images.first {
            imageView.loadImage(from: firstImage, placeholder: UIImage(systemName: "house.fill"))
        } else {
            // Fallback to a real property image if no image provided
            let fallbackUrl = "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400&h=250&fit=crop"
            imageView.loadImage(from: fallbackUrl, placeholder: UIImage(systemName: "house.fill"))
        }
        
        // Set favorite button state
        let imageName = property.isFavorite == true ? "heart.fill" : "heart"
        favoriteButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
}