import UIKit

class PropertyDetailViewController: UIViewController {
    
    var property: Property?
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let imageScrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let addressLabel = UILabel()
    private let priceLabel = UILabel()
    private let favoriteButton = UIButton(type: .system)
    private let detailsStackView = UIStackView()
    private let descriptionLabel = UILabel()
    private let amenitiesView = AmenitiesView()
    private let contactButton = UIButton(type: .system)
    private let scheduleButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        populatePropertyData()
        animateOnAppear()
        validateDataSource()
    }
    
    private func validateDataSource() {
        guard let property = property else { return }
        
        Task {
            let isRealData = await DataValidationService.shared.validateAPIConnection()
            
            DispatchQueue.main.async {
                if isRealData {
                    print("✅ Property detail showing real data from Supabase API")
                } else {
                    print("🔄 Property detail showing sample data (API unavailable)")
                }
            }
            
            // Validate data quality
            let quality = DataValidationService.shared.validatePropertyData([property])
            print("📊 Property data quality: \(String(format: "%.1f", quality.overallQuality * 100))%")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hide navigation bar for immersive image viewing
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Configure image scroll view
        imageScrollView.isPagingEnabled = true
        imageScrollView.showsHorizontalScrollIndicator = false
        imageScrollView.delegate = self
        imageScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageScrollView)
        
        // Add sample images
        for i in 0..<5 {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = .systemGray5
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageScrollView.addSubview(imageView)
            
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: imageScrollView.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: imageScrollView.bottomAnchor),
                imageView.leadingAnchor.constraint(equalTo: imageScrollView.leadingAnchor, constant: CGFloat(i) * UIScreen.main.bounds.width),
                imageView.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width),
                imageView.heightAnchor.constraint(equalToConstant: 300)
            ])
        }
        
        imageScrollView.contentSize = CGSize(width: UIScreen.main.bounds.width * 5, height: 300)
        
        // Configure page control
        pageControl.numberOfPages = 5
        pageControl.currentPage = 0
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pageControl)
        
        // Configure header view
        headerView.backgroundColor = .systemBackground
        headerView.layer.cornerRadius = 16
        headerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerView)
        
        // Configure title
        titleLabel.text = "Modern Downtown Apartment"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)
        
        // Configure address
        addressLabel.text = "123 Main Street, Downtown"
        addressLabel.font = .systemFont(ofSize: 16)
        addressLabel.textColor = .secondaryLabel
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(addressLabel)
        
        // Configure price
        priceLabel.text = "$1,500/month"
        priceLabel.font = .systemFont(ofSize: 28, weight: .bold)
        priceLabel.textColor = .systemBlue
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(priceLabel)
        
        // Configure favorite button
        favoriteButton.setImage(UIImage(systemName: "heart"), for: .normal)
        favoriteButton.tintColor = .systemPink
        favoriteButton.backgroundColor = .systemBackground
        favoriteButton.layer.cornerRadius = 25
        favoriteButton.layer.shadowColor = UIColor.black.cgColor
        favoriteButton.layer.shadowOpacity = 0.1
        favoriteButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        favoriteButton.layer.shadowRadius = 4
        favoriteButton.addTarget(self, action: #selector(favoriteTapped), for: .touchUpInside)
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(favoriteButton)
        
        // Configure details stack view
        detailsStackView.axis = .horizontal
        detailsStackView.spacing = 20
        detailsStackView.distribution = .fillEqually
        detailsStackView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(detailsStackView)
        
        let bedroomsView = PropertyDetailView()
        bedroomsView.configure(icon: "bed.double", title: "Bedrooms", value: "2")
        
        let bathroomsView = PropertyDetailView()
        bathroomsView.configure(icon: "shower", title: "Bathrooms", value: "2")
        
        let areaView = PropertyDetailView()
        areaView.configure(icon: "square.split.2x2", title: "Area", value: "1,200 sqft")
        
        detailsStackView.addArrangedSubview(bedroomsView)
        detailsStackView.addArrangedSubview(bathroomsView)
        detailsStackView.addArrangedSubview(areaView)
        
        // Configure description
        descriptionLabel.text = "Beautiful modern apartment in the heart of downtown. This stunning 2-bedroom, 2-bathroom unit features high ceilings, large windows, and premium finishes throughout. The open-concept living space is perfect for entertaining."
        descriptionLabel.font = .systemFont(ofSize: 16)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(descriptionLabel)
        
        // Configure amenities
        amenitiesView.configure(amenities: ["Parking", "Gym", "Pool", "Laundry", "Pet Friendly", "Balcony"])
        amenitiesView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(amenitiesView)
        
        // Configure contact button
        contactButton.setTitle("Contact Owner", for: .normal)
        contactButton.applyPrimaryStyle()
        contactButton.addTarget(self, action: #selector(contactTapped), for: .touchUpInside)
        contactButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(contactButton)
        
        // Configure schedule button
        scheduleButton.setTitle("Schedule Tour", for: .normal)
        scheduleButton.applySecondaryStyle()
        scheduleButton.addTarget(self, action: #selector(scheduleTapped), for: .touchUpInside)
        scheduleButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(scheduleButton)
        
        // Add back button
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .white
        backButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        backButton.layer.cornerRadius = 20
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupConstraints() {
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
            
            imageScrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageScrollView.heightAnchor.constraint(equalToConstant: 300),
            
            pageControl.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: imageScrollView.bottomAnchor, constant: -16),
            
            favoriteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            favoriteButton.bottomAnchor.constraint(equalTo: imageScrollView.bottomAnchor, constant: -20),
            favoriteButton.widthAnchor.constraint(equalToConstant: 50),
            favoriteButton.heightAnchor.constraint(equalToConstant: 50),
            
            headerView.topAnchor.constraint(equalTo: imageScrollView.bottomAnchor, constant: -16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            addressLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            addressLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            addressLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            priceLabel.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 16),
            priceLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            
            detailsStackView.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 24),
            detailsStackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            detailsStackView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            detailsStackView.heightAnchor.constraint(equalToConstant: 60),
            
            descriptionLabel.topAnchor.constraint(equalTo: detailsStackView.bottomAnchor, constant: 24),
            descriptionLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            amenitiesView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 24),
            amenitiesView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            amenitiesView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            contactButton.topAnchor.constraint(equalTo: amenitiesView.bottomAnchor, constant: 32),
            contactButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            contactButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            contactButton.heightAnchor.constraint(equalToConstant: 50),
            
            scheduleButton.topAnchor.constraint(equalTo: contactButton.bottomAnchor, constant: 12),
            scheduleButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            scheduleButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            scheduleButton.heightAnchor.constraint(equalToConstant: 50),
            scheduleButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -40)
        ])
    }
    
    private func populatePropertyData() {
        guard let property = property else {
            // Load default data
            titleLabel.text = "Modern Downtown Apartment"
            addressLabel.text = "123 Main Street, Downtown"
            priceLabel.text = "$1,500/month"
            descriptionLabel.text = "Beautiful modern apartment in the heart of downtown."
            return
        }
        
        titleLabel.text = property.title
        addressLabel.text = "\(property.address), \(property.city), \(property.state)"
        priceLabel.text = "$\(Int(property.price))/month"
        descriptionLabel.text = property.description
        
        // Load property images
        if !property.images.isEmpty {
            pageControl.numberOfPages = property.images.count
            
            // Clear existing image views
            imageScrollView.subviews.forEach { $0.removeFromSuperview() }
            
            for (index, imageUrl) in property.images.enumerated() {
                let imageView = UIImageView()
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.backgroundColor = .systemGray5
                imageView.loadImage(from: imageUrl, placeholder: UIImage(systemName: "house.fill"))
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageScrollView.addSubview(imageView)
                
                NSLayoutConstraint.activate([
                    imageView.topAnchor.constraint(equalTo: imageScrollView.topAnchor),
                    imageView.bottomAnchor.constraint(equalTo: imageScrollView.bottomAnchor),
                    imageView.leadingAnchor.constraint(equalTo: imageScrollView.leadingAnchor, constant: CGFloat(index) * UIScreen.main.bounds.width),
                    imageView.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width),
                    imageView.heightAnchor.constraint(equalToConstant: 300)
                ])
            }
            
            imageScrollView.contentSize = CGSize(width: UIScreen.main.bounds.width * CGFloat(property.images.count), height: 300)
        }
        
        // Configure amenities
        amenitiesView.configure(amenities: property.amenities)
        
        // Update price label color
        priceLabel.textColor = Theme.Colors.primary
        
        // Set initial favorite state
        let imageName = property.isFavorite == true ? "heart.fill" : "heart"
        favoriteButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    private func animateOnAppear() {
        // Hero animation for header
        headerView.transform = CGAffineTransform(translationX: 0, y: 100)
        headerView.alpha = 0
        
        UIView.animate(withDuration: 0.6, delay: 0.2, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.headerView.transform = .identity
            self.headerView.alpha = 1
        }
        
        // Animate favorite button
        favoriteButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        favoriteButton.alpha = 0
        
        UIView.animate(withDuration: 0.4, delay: 0.4, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
            self.favoriteButton.transform = .identity
            self.favoriteButton.alpha = 1
        }
    }
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func favoriteTapped() {
        guard let property = property else { return }
        
        // Toggle favorite state with animation
        UIView.animate(withDuration: 0.1, animations: {
            self.favoriteButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.favoriteButton.transform = .identity
            }
        }
        
        // Call API to toggle favorite
        APIService.shared.toggleFavorite(propertyId: property.id) { [weak self] result in
            switch result {
            case .success(let isFavorited):
                let imageName = isFavorited ? "heart.fill" : "heart"
                self?.favoriteButton.setImage(UIImage(systemName: imageName), for: .normal)
                
                // Update property object
                self?.property?.isFavorite = isFavorited
                
                // Show feedback
                let message = isFavorited ? "Added to favorites" : "Removed from favorites"
                self?.showToast(message: message)
            case .failure(let error):
                print("Error toggling favorite: \(error)")
                // Show error
                let alert = UIAlertController(title: "Error", message: "Failed to update favorite", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
    
    private func showToast(message: String) {
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.font = Theme.Fonts.callout
        toastLabel.textColor = .white
        toastLabel.backgroundColor = Theme.Colors.primary.withAlphaComponent(0.8)
        toastLabel.textAlignment = .center
        toastLabel.layer.cornerRadius = 8
        toastLabel.clipsToBounds = true
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toastLabel)
        
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toastLabel.widthAnchor.constraint(equalToConstant: 200),
            toastLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Animate toast
        toastLabel.alpha = 0
        UIView.animate(withDuration: 0.3, animations: {
            toastLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, animations: {
                toastLabel.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
    
    @objc private func contactTapped() {
        guard let property = property else { return }
        
        let alert = UIAlertController(title: "Contact Owner", message: "Send a message to inquire about this property", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Type your message..."
            textField.text = "Hi! I'm interested in this property. Is it still available?"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send", style: .default) { [weak self] _ in
            guard let message = alert.textFields?.first?.text, !message.isEmpty else { return }
            
            // Start a new conversation
            APIService.shared.startConversation(propertyId: property.id, initialMessage: message) { [weak self] result in
                switch result {
                case .success(let conversation):
                    let chatDetailVC = ChatDetailViewController()
                    chatDetailVC.conversation = conversation
                    self?.navigationController?.pushViewController(chatDetailVC, animated: true)
                case .failure(let error):
                    print("Error starting conversation: \(error)")
                    // Show error alert
                    let errorAlert = UIAlertController(title: "Error", message: "Failed to start conversation", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(errorAlert, animated: true)
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    @objc private func scheduleTapped() {
        // Present schedule tour modal
        print("Schedule tour tapped")
    }
}

// MARK: - Scroll View Delegate
extension PropertyDetailViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == imageScrollView {
            let pageIndex = round(scrollView.contentOffset.x / scrollView.frame.width)
            pageControl.currentPage = Int(pageIndex)
        }
    }
}

// MARK: - Property Detail View (Reusable)
class PropertyDetailView: UIView {
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        iconImageView.tintColor = Theme.Colors.primary
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)
        
        titleLabel.font = .systemFont(ofSize: 14)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        valueLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: topAnchor),
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(icon: String, title: String, value: String) {
        iconImageView.image = UIImage(systemName: icon)
        titleLabel.text = title
        valueLabel.text = value
    }
}

// MARK: - Amenities View
class AmenitiesView: UIView {
    private let titleLabel = UILabel()
    private let stackView = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        titleLabel.text = "Amenities"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(amenities: [String]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for i in stride(from: 0, to: amenities.count, by: 2) {
            let horizontalStack = UIStackView()
            horizontalStack.axis = .horizontal
            horizontalStack.spacing = 16
            horizontalStack.distribution = .fillEqually
            
            let amenity1 = createAmenityView(amenities[i])
            horizontalStack.addArrangedSubview(amenity1)
            
            if i + 1 < amenities.count {
                let amenity2 = createAmenityView(amenities[i + 1])
                horizontalStack.addArrangedSubview(amenity2)
            } else {
                horizontalStack.addArrangedSubview(UIView())
            }
            
            stackView.addArrangedSubview(horizontalStack)
        }
    }
    
    private func createAmenityView(_ amenity: String) -> UIView {
        let container = UIView()
        
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark.circle.fill")
        imageView.tintColor = .systemGreen
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        
        let label = UILabel()
        label.text = amenity
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 20),
            imageView.heightAnchor.constraint(equalToConstant: 20),
            
            label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
}