import UIKit

class FilterViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFilters()
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.backgroundColor
        title = "Filters"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Apply",
            style: .done,
            target: self,
            action: #selector(applyTapped)
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
    
    private func setupFilters() {
        // Price Range Section
        let priceSection = createFilterSection(title: "Price Range")
        let priceSlider = createPriceRangeSlider()
        
        // Location Section
        let locationSection = createFilterSection(title: "Location")
        let locationPicker = createLocationPicker()
        
        // Room Type Section
        let roomTypeSection = createFilterSection(title: "Room Type")
        let roomTypePicker = createRoomTypePicker()
        
        // Amenities Section
        let amenitiesSection = createFilterSection(title: "Amenities")
        let amenitiesPicker = createAmenitiesPicker()
        
        contentView.addSubview(priceSection)
        contentView.addSubview(priceSlider)
        contentView.addSubview(locationSection)
        contentView.addSubview(locationPicker)
        contentView.addSubview(roomTypeSection)
        contentView.addSubview(roomTypePicker)
        contentView.addSubview(amenitiesSection)
        contentView.addSubview(amenitiesPicker)
        
        priceSection.translatesAutoresizingMaskIntoConstraints = false
        priceSlider.translatesAutoresizingMaskIntoConstraints = false
        locationSection.translatesAutoresizingMaskIntoConstraints = false
        locationPicker.translatesAutoresizingMaskIntoConstraints = false
        roomTypeSection.translatesAutoresizingMaskIntoConstraints = false
        roomTypePicker.translatesAutoresizingMaskIntoConstraints = false
        amenitiesSection.translatesAutoresizingMaskIntoConstraints = false
        amenitiesPicker.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            priceSection.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            priceSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            priceSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            priceSlider.topAnchor.constraint(equalTo: priceSection.bottomAnchor, constant: 16),
            priceSlider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            priceSlider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            locationSection.topAnchor.constraint(equalTo: priceSlider.bottomAnchor, constant: 32),
            locationSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            locationSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            locationPicker.topAnchor.constraint(equalTo: locationSection.bottomAnchor, constant: 16),
            locationPicker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            locationPicker.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            roomTypeSection.topAnchor.constraint(equalTo: locationPicker.bottomAnchor, constant: 32),
            roomTypeSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            roomTypeSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            roomTypePicker.topAnchor.constraint(equalTo: roomTypeSection.bottomAnchor, constant: 16),
            roomTypePicker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            roomTypePicker.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            amenitiesSection.topAnchor.constraint(equalTo: roomTypePicker.bottomAnchor, constant: 32),
            amenitiesSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            amenitiesSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            amenitiesPicker.topAnchor.constraint(equalTo: amenitiesSection.bottomAnchor, constant: 16),
            amenitiesPicker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            amenitiesPicker.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            amenitiesPicker.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }
    
    private func createFilterSection(title: String) -> UIView {
        let section = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = AppColors.textPrimary
        
        section.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: section.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -20),
            titleLabel.bottomAnchor.constraint(equalTo: section.bottomAnchor)
        ])
        
        return section
    }
    
    private func createPriceRangeSlider() -> UIView {
        let container = UIView()
        container.backgroundColor = AppColors.cardBackground
        container.layer.cornerRadius = 16
        
        let minLabel = UILabel()
        minLabel.text = "$200"
        minLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        minLabel.textColor = AppColors.primaryPurple
        
        let maxLabel = UILabel()
        maxLabel.text = "$3000"
        maxLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        maxLabel.textColor = AppColors.primaryPurple
        
        let slider = UISlider()
        slider.minimumValue = 200
        slider.maximumValue = 3000
        slider.value = 1000
        slider.tintColor = AppColors.primaryPurple
        
        container.addSubview(minLabel)
        container.addSubview(maxLabel)
        container.addSubview(slider)
        
        minLabel.translatesAutoresizingMaskIntoConstraints = false
        maxLabel.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            minLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            minLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            
            maxLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            maxLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            
            slider.topAnchor.constraint(equalTo: minLabel.bottomAnchor, constant: 16),
            slider.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            slider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            slider.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            
            container.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        return container
    }
    
    private func createLocationPicker() -> UIView {
        return createPickerView(options: ["All Locations", "Downtown", "Midtown", "Upper East", "Brooklyn", "University District"])
    }
    
    private func createRoomTypePicker() -> UIView {
        return createPickerView(options: ["All Types", "Studio", "1 Bedroom", "2 Bedroom", "3+ Bedroom", "Shared Room"])
    }
    
    private func createAmenitiesPicker() -> UIView {
        return createPickerView(options: ["WiFi", "Gym", "Pool", "Parking", "Laundry", "Pet Friendly", "Air Conditioning"])
    }
    
    private func createPickerView(options: [String]) -> UIView {
        let container = UIView()
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.distribution = .fill
        
        for option in options {
            let optionView = createOptionView(title: option)
            stackView.addArrangedSubview(optionView)
        }
        
        container.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createOptionView(title: String) -> UIView {
        let optionView = UIView()
        optionView.backgroundColor = AppColors.cardBackground
        optionView.layer.cornerRadius = 12
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = AppColors.textPrimary
        
        let checkBox = UIButton(type: .system)
        checkBox.setImage(UIImage(systemName: "circle"), for: .normal)
        checkBox.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .selected)
        checkBox.tintColor = AppColors.primaryPurple
        
        optionView.addSubview(titleLabel)
        optionView.addSubview(checkBox)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        checkBox.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: optionView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: optionView.centerYAnchor),
            
            checkBox.trailingAnchor.constraint(equalTo: optionView.trailingAnchor, constant: -16),
            checkBox.centerYAnchor.constraint(equalTo: optionView.centerYAnchor),
            checkBox.widthAnchor.constraint(equalToConstant: 24),
            checkBox.heightAnchor.constraint(equalToConstant: 24),
            
            optionView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(optionTapped(_:)))
        optionView.addGestureRecognizer(tapGesture)
        optionView.isUserInteractionEnabled = true
        
        return optionView
    }
    
    @objc private func optionTapped(_ gesture: UITapGestureRecognizer) {
        guard let optionView = gesture.view,
              let checkBox = optionView.subviews.compactMap({ $0 as? UIButton }).first else { return }
        
        checkBox.isSelected.toggle()
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func applyTapped() {
        dismiss(animated: true)
    }
}