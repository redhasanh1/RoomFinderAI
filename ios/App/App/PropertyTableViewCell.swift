import UIKit

class PropertyTableViewCell: UITableViewCell {
    
    private let containerView = UIView()
    private let propertyImageView = UIImageView()
    private let titleLabel = UILabel()
    private let addressLabel = UILabel()
    private let priceLabel = UILabel()
    private let detailsStackView = UIStackView()
    private let bedroomsView = PropertyInfoView()
    private let bathroomsView = PropertyInfoView()
    private let areaView = PropertyInfoView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        // Container view
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.05
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 4
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Image view
        propertyImageView.contentMode = .scaleAspectFill
        propertyImageView.layer.cornerRadius = 8
        propertyImageView.clipsToBounds = true
        propertyImageView.backgroundColor = .systemGray5
        propertyImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(propertyImageView)
        
        // Title label
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Address label
        addressLabel.font = .systemFont(ofSize: 14)
        addressLabel.textColor = .secondaryLabel
        addressLabel.numberOfLines = 1
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(addressLabel)
        
        // Price label
        priceLabel.font = .systemFont(ofSize: 18, weight: .bold)
        priceLabel.textColor = Theme.Colors.primary
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(priceLabel)
        
        // Details stack view
        detailsStackView.axis = .horizontal
        detailsStackView.spacing = 12
        detailsStackView.distribution = .fillEqually
        detailsStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(detailsStackView)
        
        // Configure detail views
        bedroomsView.configure(icon: "bed.double", value: "3 beds")
        bathroomsView.configure(icon: "shower", value: "2 baths")
        areaView.configure(icon: "square.split.2x2", value: "1,200 sqft")
        
        detailsStackView.addArrangedSubview(bedroomsView)
        detailsStackView.addArrangedSubview(bathroomsView)
        detailsStackView.addArrangedSubview(areaView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            propertyImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            propertyImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            propertyImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            propertyImageView.widthAnchor.constraint(equalToConstant: 80),
            propertyImageView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.leadingAnchor.constraint(equalTo: propertyImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            addressLabel.leadingAnchor.constraint(equalTo: propertyImageView.trailingAnchor, constant: 12),
            addressLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            addressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            priceLabel.leadingAnchor.constraint(equalTo: propertyImageView.trailingAnchor, constant: 12),
            priceLabel.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 4),
            priceLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -12),
            
            detailsStackView.leadingAnchor.constraint(equalTo: propertyImageView.trailingAnchor, constant: 12),
            detailsStackView.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 8),
            detailsStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            detailsStackView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -12),
            detailsStackView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        propertyImageView.image = nil
        titleLabel.text = nil
        addressLabel.text = nil
        priceLabel.text = nil
    }
    
    func configure(with property: Property) {
        titleLabel.text = property.title
        addressLabel.text = "\(property.address), \(property.city), \(property.state)"
        priceLabel.text = "$\(Int(property.price))/month"
        
        bedroomsView.configure(icon: "bed.double", value: "\(property.bedrooms) beds")
        bathroomsView.configure(icon: "shower", value: "\(property.bathrooms) baths")
        areaView.configure(icon: "square.split.2x2", value: "\(property.sqft) sqft")
        
        // Load property image
        if let firstImage = property.images.first {
            propertyImageView.loadImage(from: firstImage, placeholder: UIImage(systemName: "house.fill"))
        } else {
            // Fallback to a real property image if no image provided
            let fallbackUrl = "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400&h=250&fit=crop"
            propertyImageView.loadImage(from: fallbackUrl, placeholder: UIImage(systemName: "house.fill"))
        }
    }
}

// MARK: - Property Info View
class PropertyInfoView: UIView {
    private let iconImageView = UIImageView()
    private let valueLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        iconImageView.tintColor = .secondaryLabel
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)
        
        valueLabel.font = .systemFont(ofSize: 12)
        valueLabel.textColor = .secondaryLabel
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),
            
            valueLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 4),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    func configure(icon: String, value: String) {
        iconImageView.image = UIImage(systemName: icon)
        valueLabel.text = value
    }
}