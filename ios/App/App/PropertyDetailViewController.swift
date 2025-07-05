import UIKit

class PropertyDetailViewController: UIViewController {
    
    private let property: PropertyModel
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
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
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.backgroundColor
        title = property.title
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "heart"),
            style: .plain,
            target: self,
            action: #selector(favoriteTapped)
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
        let gallery = UIView()
        
        let imageView = UIImageView()
        imageView.backgroundColor = AppColors.separatorColor
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.image = UIImage(systemName: "photo")
        imageView.tintColor = AppColors.textSecondary
        
        gallery.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: gallery.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: gallery.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: gallery.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: gallery.bottomAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        return gallery
    }
    
    private func createPropertyInfo() -> UIView {
        let infoView = UIView()
        infoView.backgroundColor = AppColors.cardBackground
        infoView.layer.cornerRadius = 16
        
        let titleLabel = UILabel()
        titleLabel.text = property.title
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.numberOfLines = 0
        
        let priceLabel = UILabel()
        priceLabel.text = "$\(property.price)/month"
        priceLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        priceLabel.textColor = AppColors.primaryPurple
        
        let locationLabel = UILabel()
        locationLabel.text = "📍 \(property.location)"
        locationLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        locationLabel.textColor = AppColors.textSecondary
        
        let detailsLabel = UILabel()
        detailsLabel.text = "\(property.bedrooms) bedroom • \(property.bathrooms) bathroom"
        detailsLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        detailsLabel.textColor = AppColors.textSecondary
        
        infoView.addSubview(titleLabel)
        infoView.addSubview(priceLabel)
        infoView.addSubview(locationLabel)
        infoView.addSubview(detailsLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        locationLabel.translatesAutoresizingMaskIntoConstraints = false
        detailsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: infoView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: infoView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: priceLabel.leadingAnchor, constant: -16),
            
            priceLabel.topAnchor.constraint(equalTo: infoView.topAnchor, constant: 20),
            priceLabel.trailingAnchor.constraint(equalTo: infoView.trailingAnchor, constant: -20),
            priceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            locationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            locationLabel.leadingAnchor.constraint(equalTo: infoView.leadingAnchor, constant: 20),
            locationLabel.trailingAnchor.constraint(equalTo: infoView.trailingAnchor, constant: -20),
            
            detailsLabel.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 8),
            detailsLabel.leadingAnchor.constraint(equalTo: infoView.leadingAnchor, constant: 20),
            detailsLabel.trailingAnchor.constraint(equalTo: infoView.trailingAnchor, constant: -20),
            detailsLabel.bottomAnchor.constraint(equalTo: infoView.bottomAnchor, constant: -20)
        ])
        
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
    
    @objc private func favoriteTapped() {
        // Toggle favorite status
        let isFavorited = navigationItem.rightBarButtonItem?.image == UIImage(systemName: "heart.fill")
        let newImage = isFavorited ? UIImage(systemName: "heart") : UIImage(systemName: "heart.fill")
        navigationItem.rightBarButtonItem?.image = newImage
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    @objc private func contactTapped() {
        let alert = UIAlertController(title: "Contact Landlord", message: "Would you like to call or message the landlord?", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Call", style: .default) { _ in
            // Implement call functionality
        })
        
        alert.addAction(UIAlertAction(title: "Message", style: .default) { _ in
            // Implement message functionality
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func negotiateTapped() {
        // Navigate to AI chat with pre-filled negotiation context
        if let tabBarController = self.tabBarController {
            tabBarController.selectedIndex = 3 // Switch to chat tab
        }
    }
}