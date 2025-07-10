import UIKit

protocol FilterViewControllerDelegate: AnyObject {
    func didApplyFilters(_ filters: [String: Any])
}

class FilterViewController: UIViewController {
    
    weak var delegate: FilterViewControllerDelegate?
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let priceRangeView = FilterSectionView()
    private let bedroomsView = FilterSectionView()
    private let bathroomsView = FilterSectionView()
    private let propertyTypeView = FilterSectionView()
    private let amenitiesView = FilterSectionView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Filters"
        
        // Navigation bar
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Apply",
            style: .done,
            target: self,
            action: #selector(applyTapped)
        )
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Configure filter sections
        priceRangeView.configure(
            title: "Price Range",
            type: .range,
            options: ["$500", "$1000", "$1500", "$2000", "$2500+"]
        )
        
        bedroomsView.configure(
            title: "Bedrooms",
            type: .selection,
            options: ["Any", "1", "2", "3", "4+"]
        )
        
        bathroomsView.configure(
            title: "Bathrooms",
            type: .selection,
            options: ["Any", "1", "2", "3+"]
        )
        
        propertyTypeView.configure(
            title: "Property Type",
            type: .multiSelection,
            options: ["Apartment", "House", "Condo", "Studio", "Room"]
        )
        
        amenitiesView.configure(
            title: "Amenities",
            type: .multiSelection,
            options: ["Parking", "Gym", "Pool", "Laundry", "Pet Friendly", "Balcony"]
        )
        
        let sections = [priceRangeView, bedroomsView, bathroomsView, propertyTypeView, amenitiesView]
        
        for section in sections {
            section.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(section)
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            priceRangeView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            priceRangeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            priceRangeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            bedroomsView.topAnchor.constraint(equalTo: priceRangeView.bottomAnchor, constant: 20),
            bedroomsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bedroomsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            bathroomsView.topAnchor.constraint(equalTo: bedroomsView.bottomAnchor, constant: 20),
            bathroomsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bathroomsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            propertyTypeView.topAnchor.constraint(equalTo: bathroomsView.bottomAnchor, constant: 20),
            propertyTypeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            propertyTypeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            amenitiesView.topAnchor.constraint(equalTo: propertyTypeView.bottomAnchor, constant: 20),
            amenitiesView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            amenitiesView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            amenitiesView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func applyTapped() {
        let filters: [String: Any] = [
            "priceRange": priceRangeView.selectedValues,
            "bedrooms": bedroomsView.selectedValues,
            "bathrooms": bathroomsView.selectedValues,
            "propertyType": propertyTypeView.selectedValues,
            "amenities": amenitiesView.selectedValues
        ]
        
        delegate?.didApplyFilters(filters)
        dismiss(animated: true)
    }
}

// MARK: - Filter Section View
class FilterSectionView: UIView {
    
    private let titleLabel = UILabel()
    private let optionsStackView = UIStackView()
    private var filterType: FilterType = .selection
    private var options: [String] = []
    
    var selectedValues: [String] = []
    
    enum FilterType {
        case selection      // Single selection
        case multiSelection // Multiple selection
        case range          // Range selection
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        // Title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        // Options stack view
        optionsStackView.axis = .vertical
        optionsStackView.spacing = 8
        optionsStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(optionsStackView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            optionsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            optionsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            optionsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            optionsStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    func configure(title: String, type: FilterType, options: [String]) {
        titleLabel.text = title
        self.filterType = type
        self.options = options
        
        // Clear existing options
        optionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Create horizontal stack views for options (2 per row)
        for i in stride(from: 0, to: options.count, by: 2) {
            let horizontalStack = UIStackView()
            horizontalStack.axis = .horizontal
            horizontalStack.spacing = 12
            horizontalStack.distribution = .fillEqually
            
            let button1 = createOptionButton(title: options[i])
            horizontalStack.addArrangedSubview(button1)
            
            if i + 1 < options.count {
                let button2 = createOptionButton(title: options[i + 1])
                horizontalStack.addArrangedSubview(button2)
            } else {
                horizontalStack.addArrangedSubview(UIView()) // Empty view for spacing
            }
            
            optionsStackView.addArrangedSubview(horizontalStack)
        }
    }
    
    private func createOptionButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.backgroundColor = .systemBackground
        button.setTitleColor(.label, for: .normal)
        button.addTarget(self, action: #selector(optionButtonTapped(_:)), for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }
    
    @objc private func optionButtonTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        
        switch filterType {
        case .selection:
            // Single selection - deselect all others
            optionsStackView.arrangedSubviews.forEach { stackView in
                if let horizontalStack = stackView as? UIStackView {
                    horizontalStack.arrangedSubviews.forEach { view in
                        if let button = view as? UIButton, button != sender {
                            deselectButton(button)
                        }
                    }
                }
            }
            
            if selectedValues.contains(title) {
                selectedValues.removeAll { $0 == title }
                deselectButton(sender)
            } else {
                selectedValues = [title]
                selectButton(sender)
            }
            
        case .multiSelection:
            // Multiple selection
            if selectedValues.contains(title) {
                selectedValues.removeAll { $0 == title }
                deselectButton(sender)
            } else {
                selectedValues.append(title)
                selectButton(sender)
            }
            
        case .range:
            // Range selection - implement range logic
            if selectedValues.contains(title) {
                selectedValues.removeAll { $0 == title }
                deselectButton(sender)
            } else {
                selectedValues = [title]
                selectButton(sender)
            }
        }
    }
    
    private func selectButton(_ button: UIButton) {
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.borderColor = UIColor.systemBlue.cgColor
    }
    
    private func deselectButton(_ button: UIButton) {
        button.backgroundColor = .systemBackground
        button.setTitleColor(.label, for: .normal)
        button.layer.borderColor = UIColor.systemGray4.cgColor
    }
}