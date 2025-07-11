import UIKit

class StudentHousingViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Hero Section
    private let heroView = UIView()
    private let heroTitleLabel = UILabel()
    private let heroSubtitleLabel = UILabel()
    private let quickStatsStackView = UIStackView()
    private let quickMatchButton = UIButton(type: .system)
    
    // Features Section
    private let featuresView = UIView()
    private let featuresStackView = UIStackView()
    
    // Journey Steps Section
    private let journeyView = UIView()
    private let journeyStepsStackView = UIStackView()
    
    // Tools Tabs Section
    private let toolsView = UIView()
    private let toolsTabSegment = UISegmentedControl(items: ["Budget", "Compare", "Sublease", "Safety", "Resources"])
    private let toolsContentView = UIView()
    
    // Budget Calculator Views
    private let budgetCalculatorView = UIView()
    private let incomeStackView = UIStackView()
    private let expensesStackView = UIStackView()
    private let budgetResultView = UIView()
    
    // Housing Comparison Views
    private let comparisonView = UIView()
    private let housingOptionsStackView = UIStackView()
    
    // Roommate Tools Views
    private let roommateView = UIView()
    private let roommateOptionsStackView = UIStackView()
    
    // Sublease Views
    private let subleaseView = UIView()
    private let subleaseSegment = UISegmentedControl(items: ["Find", "Post", "My Requests"])
    private let subleaseContentView = UIView()
    
    // Safety Views
    private let safetyView = UIView()
    private let emergencyContactsView = UIView()
    private let safetyChecklistView = UIView()
    
    // Resources Views
    private let resourcesView = UIView()
    private let universitiesScrollView = UIScrollView()
    private let universitiesStackView = UIStackView()
    
    // Data
    private var monthlyBudget: Double = 1000
    private var selectedHousingType: String = ""
    private var budgetBreakdown: [String: Double] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupHeroSection()
        setupFeaturesSection()
        setupJourneySection()
        setupToolsSection()
        setupConstraints()
        
        // Set default tab
        toolsTabSegment.selectedSegmentIndex = 0
        showToolsTab(index: 0)
        
        animateOnAppear()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.applyGradient(colors: [
            UIColor(red: 0.40, green: 0.50, blue: 0.92, alpha: 1.0),
            UIColor(red: 0.46, green: 0.29, blue: 0.64, alpha: 1.0),
            UIColor(red: 0.94, green: 0.58, blue: 0.98, alpha: 1.0)
        ], startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1))
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Student Housing"
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add all main sections to content view
        [heroView, featuresView, journeyView, toolsView].forEach {
            contentView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    private func setupHeroSection() {
        heroView.applyGradient(colors: [
            UIColor(red: 0.40, green: 0.50, blue: 0.92, alpha: 0.9),
            UIColor(red: 0.46, green: 0.29, blue: 0.64, alpha: 0.9),
            UIColor(red: 0.94, green: 0.58, blue: 0.98, alpha: 0.9)
        ])
        heroView.layer.cornerRadius = Theme.CornerRadius.large
        
        // Hero Title
        heroTitleLabel.text = "🎓 Find Your Perfect Student Housing"
        heroTitleLabel.font = Theme.Fonts.displayLarge
        heroTitleLabel.textColor = Theme.Colors.textOnPrimary
        heroTitleLabel.numberOfLines = 0
        heroTitleLabel.textAlignment = .center
        heroTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(heroTitleLabel)
        
        // Hero Subtitle
        heroSubtitleLabel.text = "AI matches you with the perfect housing, roommates, and budget - all FREE for students"
        heroSubtitleLabel.font = Theme.Fonts.title3
        heroSubtitleLabel.textColor = Theme.Colors.textOnPrimary
        heroSubtitleLabel.numberOfLines = 0
        heroSubtitleLabel.textAlignment = .center
        heroSubtitleLabel.alpha = 0.9
        heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(heroSubtitleLabel)
        
        // Quick Stats
        quickStatsStackView.axis = .horizontal
        quickStatsStackView.distribution = .fillEqually
        quickStatsStackView.spacing = Theme.Spacing.sm
        quickStatsStackView.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(quickStatsStackView)
        
        let stats = [
            ("50k+", "Students"),
            ("100%", "Free"),
            ("$847", "Avg Savings"),
            ("24/7", "Support")
        ]
        
        for stat in stats {
            let statView = createStatView(value: stat.0, label: stat.1)
            quickStatsStackView.addArrangedSubview(statView)
        }
        
        // Quick Match Button
        quickMatchButton.setTitle("🎯 Quick Match - 2 Min Setup", for: .normal)
        quickMatchButton.titleLabel?.font = Theme.Fonts.headline
        quickMatchButton.setTitleColor(Theme.Colors.textPrimary, for: .normal)
        quickMatchButton.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        quickMatchButton.layer.cornerRadius = Theme.CornerRadius.medium
        quickMatchButton.addTarget(self, action: #selector(quickMatchTapped), for: .touchUpInside)
        quickMatchButton.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(quickMatchButton)
        
        // Hero constraints
        NSLayoutConstraint.activate([
            heroTitleLabel.topAnchor.constraint(equalTo: heroView.topAnchor, constant: Theme.Spacing.xxl),
            heroTitleLabel.leadingAnchor.constraint(equalTo: heroView.leadingAnchor, constant: Theme.Spacing.lg),
            heroTitleLabel.trailingAnchor.constraint(equalTo: heroView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            heroSubtitleLabel.topAnchor.constraint(equalTo: heroTitleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            heroSubtitleLabel.leadingAnchor.constraint(equalTo: heroView.leadingAnchor, constant: Theme.Spacing.lg),
            heroSubtitleLabel.trailingAnchor.constraint(equalTo: heroView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            quickStatsStackView.topAnchor.constraint(equalTo: heroSubtitleLabel.bottomAnchor, constant: Theme.Spacing.xl),
            quickStatsStackView.leadingAnchor.constraint(equalTo: heroView.leadingAnchor, constant: Theme.Spacing.lg),
            quickStatsStackView.trailingAnchor.constraint(equalTo: heroView.trailingAnchor, constant: -Theme.Spacing.lg),
            quickStatsStackView.heightAnchor.constraint(equalToConstant: 60),
            
            quickMatchButton.topAnchor.constraint(equalTo: quickStatsStackView.bottomAnchor, constant: Theme.Spacing.xl),
            quickMatchButton.centerXAnchor.constraint(equalTo: heroView.centerXAnchor),
            quickMatchButton.widthAnchor.constraint(equalToConstant: 280),
            quickMatchButton.heightAnchor.constraint(equalToConstant: Theme.Spacing.buttonHeight),
            quickMatchButton.bottomAnchor.constraint(equalTo: heroView.bottomAnchor, constant: -Theme.Spacing.xxl)
        ])
    }
    
    private func createStatView(value: String, label: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        container.layer.cornerRadius = Theme.CornerRadius.small
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = Theme.Fonts.title1
        valueLabel.textColor = Theme.Colors.textOnPrimary
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueLabel)
        
        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = Theme.Fonts.caption1
        titleLabel.textColor = Theme.Colors.textOnPrimary
        titleLabel.textAlignment = .center
        titleLabel.alpha = 0.8
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            valueLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: Theme.Spacing.sm),
            valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Theme.Spacing.xs),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Theme.Spacing.xs),
            
            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: Theme.Spacing.xs),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Theme.Spacing.xs),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Theme.Spacing.xs),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Theme.Spacing.sm)
        ])
        
        return container
    }
    
    private func setupFeaturesSection() {
        featuresView.applyGlassEffect(alpha: 0.95)
        
        let titleLabel = UILabel()
        titleLabel.text = "🌟 Student-Focused Features"
        titleLabel.font = Theme.Fonts.title1
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        featuresView.addSubview(titleLabel)
        
        featuresStackView.axis = .vertical
        featuresStackView.spacing = Theme.Spacing.lg
        featuresStackView.translatesAutoresizingMaskIntoConstraints = false
        featuresView.addSubview(featuresStackView)
        
        let features = [
            ("🔍", "Smart Housing Search", "AI-powered search matching your budget, location, and lifestyle preferences"),
            ("👥", "Perfect Roommate Matching", "Compatibility algorithms to find roommates with similar lifestyles and habits"),
            ("🛡️", "Legal Protection", "Lease review, tenant rights education, and scam protection for students")
        ]
        
        for feature in features {
            let featureCard = createFeatureCard(icon: feature.0, title: feature.1, description: feature.2)
            featuresStackView.addArrangedSubview(featureCard)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: featuresView.topAnchor, constant: Theme.Spacing.xl),
            titleLabel.leadingAnchor.constraint(equalTo: featuresView.leadingAnchor, constant: Theme.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: featuresView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            featuresStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xl),
            featuresStackView.leadingAnchor.constraint(equalTo: featuresView.leadingAnchor, constant: Theme.Spacing.lg),
            featuresStackView.trailingAnchor.constraint(equalTo: featuresView.trailingAnchor, constant: -Theme.Spacing.lg),
            featuresStackView.bottomAnchor.constraint(equalTo: featuresView.bottomAnchor, constant: -Theme.Spacing.xl)
        ])
    }
    
    private func createFeatureCard(icon: String, title: String, description: String) -> UIView {
        let card = UIView()
        card.applyPremiumCardStyle()
        card.backgroundColor = Theme.Colors.surface
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 32)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconLabel)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.Fonts.headline
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = Theme.Fonts.body
        descriptionLabel.textColor = Theme.Colors.textSecondary
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            iconLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: Theme.Spacing.lg),
            iconLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Theme.Spacing.lg),
            
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: Theme.Spacing.lg),
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: Theme.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.lg),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.sm),
            descriptionLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: Theme.Spacing.md),
            descriptionLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.lg),
            descriptionLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Theme.Spacing.lg)
        ])
        
        return card
    }
    
    private func setupJourneySection() {
        journeyView.applyGlassEffect(alpha: 0.95)
        
        let titleLabel = UILabel()
        titleLabel.text = "🗺️ Your Housing Journey"
        titleLabel.font = Theme.Fonts.title1
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        journeyView.addSubview(titleLabel)
        
        journeyStepsStackView.axis = .vertical
        journeyStepsStackView.spacing = Theme.Spacing.md
        journeyStepsStackView.translatesAutoresizingMaskIntoConstraints = false
        journeyView.addSubview(journeyStepsStackView)
        
        let steps = [
            ("1", "💰", "Set Budget", "Calculate what you can afford"),
            ("2", "🏠", "Compare Options", "Dorm vs apartment vs shared"),
            ("3", "👥", "Find Roommates", "Get matched with compatible people"),
            ("4", "🛡️", "Stay Safe", "Legal protection & safety tips"),
            ("5", "✅", "Get Started", "Apply & move in with confidence")
        ]
        
        for step in steps {
            let stepView = createJourneyStep(number: step.0, icon: step.1, title: step.2, description: step.3)
            journeyStepsStackView.addArrangedSubview(stepView)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: journeyView.topAnchor, constant: Theme.Spacing.xl),
            titleLabel.leadingAnchor.constraint(equalTo: journeyView.leadingAnchor, constant: Theme.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: journeyView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            journeyStepsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xl),
            journeyStepsStackView.leadingAnchor.constraint(equalTo: journeyView.leadingAnchor, constant: Theme.Spacing.lg),
            journeyStepsStackView.trailingAnchor.constraint(equalTo: journeyView.trailingAnchor, constant: -Theme.Spacing.lg),
            journeyStepsStackView.bottomAnchor.constraint(equalTo: journeyView.bottomAnchor, constant: -Theme.Spacing.xl)
        ])
    }
    
    private func createJourneyStep(number: String, icon: String, title: String, description: String) -> UIView {
        let container = UIView()
        container.backgroundColor = Theme.Colors.surface
        container.layer.cornerRadius = Theme.CornerRadius.medium
        container.applyShadow(Theme.Shadow.small)
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let numberView = UIView()
        numberView.backgroundColor = Theme.Colors.primary
        numberView.layer.cornerRadius = 20
        numberView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(numberView)
        
        let numberLabel = UILabel()
        numberLabel.text = number
        numberLabel.font = Theme.Fonts.headline
        numberLabel.textColor = Theme.Colors.textOnPrimary
        numberLabel.textAlignment = .center
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberView.addSubview(numberLabel)
        
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconLabel)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.Fonts.headline
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = Theme.Fonts.callout
        descriptionLabel.textColor = Theme.Colors.textSecondary
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 80),
            
            numberView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Theme.Spacing.lg),
            numberView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            numberView.widthAnchor.constraint(equalToConstant: 40),
            numberView.heightAnchor.constraint(equalToConstant: 40),
            
            numberLabel.centerXAnchor.constraint(equalTo: numberView.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: numberView.centerYAnchor),
            
            iconLabel.leadingAnchor.constraint(equalTo: numberView.trailingAnchor, constant: Theme.Spacing.md),
            iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: Theme.Spacing.md),
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: Theme.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Theme.Spacing.lg),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xs),
            descriptionLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: Theme.Spacing.md),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Theme.Spacing.lg),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -Theme.Spacing.md)
        ])
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(journeyStepTapped(_:)))
        container.addGestureRecognizer(tapGesture)
        container.tag = Int(number) ?? 0
        
        return container
    }
    
    private func setupToolsSection() {
        toolsView.applyGlassEffect(alpha: 0.95)
        
        let titleLabel = UILabel()
        titleLabel.text = "🛠️ Comprehensive Tools"
        titleLabel.font = Theme.Fonts.title1
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        toolsView.addSubview(titleLabel)
        
        // Tools Tab Segment
        toolsTabSegment.selectedSegmentIndex = 0
        toolsTabSegment.addTarget(self, action: #selector(toolsTabChanged), for: .valueChanged)
        toolsTabSegment.translatesAutoresizingMaskIntoConstraints = false
        toolsView.addSubview(toolsTabSegment)
        
        // Tools Content View
        toolsContentView.backgroundColor = Theme.Colors.surface
        toolsContentView.layer.cornerRadius = Theme.CornerRadius.medium
        toolsContentView.translatesAutoresizingMaskIntoConstraints = false
        toolsView.addSubview(toolsContentView)
        
        // Setup individual tool views
        setupBudgetCalculator()
        setupHousingComparison()
        setupRoommateTools()
        setupSubleaseTools()
        setupSafetyResources()
        setupUniversityResources()
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: toolsView.topAnchor, constant: Theme.Spacing.xl),
            titleLabel.leadingAnchor.constraint(equalTo: toolsView.leadingAnchor, constant: Theme.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: toolsView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            toolsTabSegment.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            toolsTabSegment.leadingAnchor.constraint(equalTo: toolsView.leadingAnchor, constant: Theme.Spacing.lg),
            toolsTabSegment.trailingAnchor.constraint(equalTo: toolsView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            toolsContentView.topAnchor.constraint(equalTo: toolsTabSegment.bottomAnchor, constant: Theme.Spacing.lg),
            toolsContentView.leadingAnchor.constraint(equalTo: toolsView.leadingAnchor, constant: Theme.Spacing.lg),
            toolsContentView.trailingAnchor.constraint(equalTo: toolsView.trailingAnchor, constant: -Theme.Spacing.lg),
            toolsContentView.heightAnchor.constraint(equalToConstant: 400),
            toolsContentView.bottomAnchor.constraint(equalTo: toolsView.bottomAnchor, constant: -Theme.Spacing.xl)
        ])
    }
    
    private func setupBudgetCalculator() {
        budgetCalculatorView.translatesAutoresizingMaskIntoConstraints = false
        toolsContentView.addSubview(budgetCalculatorView)
        
        let titleLabel = UILabel()
        titleLabel.text = "💰 Budget Calculator"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        budgetCalculatorView.addSubview(titleLabel)
        
        // Monthly Budget Slider
        let budgetSlider = UISlider()
        budgetSlider.minimumValue = 300
        budgetSlider.maximumValue = 2000
        budgetSlider.value = Float(monthlyBudget)
        budgetSlider.addTarget(self, action: #selector(budgetSliderChanged(_:)), for: .valueChanged)
        budgetSlider.translatesAutoresizingMaskIntoConstraints = false
        budgetCalculatorView.addSubview(budgetSlider)
        
        let budgetLabel = UILabel()
        budgetLabel.text = "$\(Int(monthlyBudget))/month"
        budgetLabel.font = Theme.Fonts.title1
        budgetLabel.textColor = Theme.Colors.primary
        budgetLabel.textAlignment = .center
        budgetLabel.tag = 100 // Tag for updating
        budgetLabel.translatesAutoresizingMaskIntoConstraints = false
        budgetCalculatorView.addSubview(budgetLabel)
        
        // Quick Presets
        let presetsStackView = UIStackView()
        presetsStackView.axis = .horizontal
        presetsStackView.distribution = .fillEqually
        presetsStackView.spacing = Theme.Spacing.sm
        presetsStackView.translatesAutoresizingMaskIntoConstraints = false
        budgetCalculatorView.addSubview(presetsStackView)
        
        let presets = [("Minimal", 500), ("Comfortable", 800), ("Premium", 1200)]
        for preset in presets {
            let button = UIButton(type: .system)
            button.setTitle(preset.0, for: .normal)
            button.applySecondaryButtonStyle()
            button.tag = preset.1
            button.addTarget(self, action: #selector(budgetPresetTapped(_:)), for: .touchUpInside)
            presetsStackView.addArrangedSubview(button)
        }
        
        // Calculate Button
        let calculateButton = UIButton(type: .system)
        calculateButton.setTitle("🧮 Calculate Housing Options", for: .normal)
        calculateButton.applyPrimaryButtonStyle()
        calculateButton.addTarget(self, action: #selector(calculateBudgetTapped), for: .touchUpInside)
        calculateButton.translatesAutoresizingMaskIntoConstraints = false
        budgetCalculatorView.addSubview(calculateButton)
        
        NSLayoutConstraint.activate([
            budgetCalculatorView.topAnchor.constraint(equalTo: toolsContentView.topAnchor),
            budgetCalculatorView.leadingAnchor.constraint(equalTo: toolsContentView.leadingAnchor),
            budgetCalculatorView.trailingAnchor.constraint(equalTo: toolsContentView.trailingAnchor),
            budgetCalculatorView.bottomAnchor.constraint(equalTo: toolsContentView.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: budgetCalculatorView.topAnchor, constant: Theme.Spacing.lg),
            titleLabel.centerXAnchor.constraint(equalTo: budgetCalculatorView.centerXAnchor),
            
            budgetLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            budgetLabel.centerXAnchor.constraint(equalTo: budgetCalculatorView.centerXAnchor),
            
            budgetSlider.topAnchor.constraint(equalTo: budgetLabel.bottomAnchor, constant: Theme.Spacing.lg),
            budgetSlider.leadingAnchor.constraint(equalTo: budgetCalculatorView.leadingAnchor, constant: Theme.Spacing.lg),
            budgetSlider.trailingAnchor.constraint(equalTo: budgetCalculatorView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            presetsStackView.topAnchor.constraint(equalTo: budgetSlider.bottomAnchor, constant: Theme.Spacing.lg),
            presetsStackView.leadingAnchor.constraint(equalTo: budgetCalculatorView.leadingAnchor, constant: Theme.Spacing.lg),
            presetsStackView.trailingAnchor.constraint(equalTo: budgetCalculatorView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            calculateButton.topAnchor.constraint(equalTo: presetsStackView.bottomAnchor, constant: Theme.Spacing.xl),
            calculateButton.centerXAnchor.constraint(equalTo: budgetCalculatorView.centerXAnchor),
            calculateButton.widthAnchor.constraint(equalToConstant: 250)
        ])
    }
    
    private func setupHousingComparison() {
        comparisonView.translatesAutoresizingMaskIntoConstraints = false
        toolsContentView.addSubview(comparisonView)
        
        let titleLabel = UILabel()
        titleLabel.text = "🏠 Housing Comparison"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        comparisonView.addSubview(titleLabel)
        
        housingOptionsStackView.axis = .vertical
        housingOptionsStackView.spacing = Theme.Spacing.sm
        housingOptionsStackView.translatesAutoresizingMaskIntoConstraints = false
        comparisonView.addSubview(housingOptionsStackView)
        
        let housingTypes = [
            ("🏫", "Dorms/On-Campus", "$8k-15k/year", "All-inclusive, close to campus"),
            ("🏢", "Off-Campus Apartments", "$400-1200/month", "More space & privacy, cheaper"),
            ("🏡", "Shared Houses", "$300-800/month", "Lowest cost, more space")
        ]
        
        for housing in housingTypes {
            let card = createHousingComparisonCard(icon: housing.0, type: housing.1, cost: housing.2, description: housing.3)
            housingOptionsStackView.addArrangedSubview(card)
        }
        
        NSLayoutConstraint.activate([
            comparisonView.topAnchor.constraint(equalTo: toolsContentView.topAnchor),
            comparisonView.leadingAnchor.constraint(equalTo: toolsContentView.leadingAnchor),
            comparisonView.trailingAnchor.constraint(equalTo: toolsContentView.trailingAnchor),
            comparisonView.bottomAnchor.constraint(equalTo: toolsContentView.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: comparisonView.topAnchor, constant: Theme.Spacing.lg),
            titleLabel.centerXAnchor.constraint(equalTo: comparisonView.centerXAnchor),
            
            housingOptionsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            housingOptionsStackView.leadingAnchor.constraint(equalTo: comparisonView.leadingAnchor, constant: Theme.Spacing.lg),
            housingOptionsStackView.trailingAnchor.constraint(equalTo: comparisonView.trailingAnchor, constant: -Theme.Spacing.lg)
        ])
        
        comparisonView.isHidden = true
    }
    
    private func createHousingComparisonCard(icon: String, type: String, cost: String, description: String) -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.Colors.surfaceSecondary
        card.layer.cornerRadius = Theme.CornerRadius.small
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconLabel)
        
        let typeLabel = UILabel()
        typeLabel.text = type
        typeLabel.font = Theme.Fonts.headline
        typeLabel.textColor = Theme.Colors.textPrimary
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(typeLabel)
        
        let costLabel = UILabel()
        costLabel.text = cost
        costLabel.font = Theme.Fonts.callout
        costLabel.textColor = Theme.Colors.primary
        costLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(costLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = Theme.Fonts.caption1
        descriptionLabel.textColor = Theme.Colors.textSecondary
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 80),
            
            iconLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Theme.Spacing.md),
            iconLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            
            typeLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: Theme.Spacing.sm),
            typeLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: Theme.Spacing.sm),
            typeLabel.trailingAnchor.constraint(lessThanOrEqualTo: costLabel.leadingAnchor, constant: -Theme.Spacing.sm),
            
            costLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: Theme.Spacing.sm),
            costLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.md),
            
            descriptionLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: Theme.Spacing.xs),
            descriptionLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: Theme.Spacing.sm),
            descriptionLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.md),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -Theme.Spacing.sm)
        ])
        
        return card
    }
    
    private func setupRoommateTools() {
        roommateView.translatesAutoresizingMaskIntoConstraints = false
        toolsContentView.addSubview(roommateView)
        
        let titleLabel = UILabel()
        titleLabel.text = "👥 Roommate Tools"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        roommateView.addSubview(titleLabel)
        
        roommateOptionsStackView.axis = .vertical
        roommateOptionsStackView.spacing = Theme.Spacing.md
        roommateOptionsStackView.translatesAutoresizingMaskIntoConstraints = false
        roommateView.addSubview(roommateOptionsStackView)
        
        let tools = [
            ("📝", "Roommate Agreement Generator", "Create comprehensive agreements"),
            ("🎯", "Compatibility Quiz", "Find your perfect match"),
            ("🤝", "Conflict Resolution", "Resolve issues peacefully")
        ]
        
        for tool in tools {
            let button = createRoommateToolButton(icon: tool.0, title: tool.1, description: tool.2)
            roommateOptionsStackView.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            roommateView.topAnchor.constraint(equalTo: toolsContentView.topAnchor),
            roommateView.leadingAnchor.constraint(equalTo: toolsContentView.leadingAnchor),
            roommateView.trailingAnchor.constraint(equalTo: toolsContentView.trailingAnchor),
            roommateView.bottomAnchor.constraint(equalTo: toolsContentView.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: roommateView.topAnchor, constant: Theme.Spacing.lg),
            titleLabel.centerXAnchor.constraint(equalTo: roommateView.centerXAnchor),
            
            roommateOptionsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            roommateOptionsStackView.leadingAnchor.constraint(equalTo: roommateView.leadingAnchor, constant: Theme.Spacing.lg),
            roommateOptionsStackView.trailingAnchor.constraint(equalTo: roommateView.trailingAnchor, constant: -Theme.Spacing.lg)
        ])
        
        roommateView.isHidden = true
    }
    
    private func createRoommateToolButton(icon: String, title: String, description: String) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = Theme.Colors.surfaceSecondary
        button.layer.cornerRadius = Theme.CornerRadius.medium
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(iconLabel)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.Fonts.headline
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(titleLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = Theme.Fonts.caption1
        descriptionLabel.textColor = Theme.Colors.textSecondary
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 70),
            
            iconLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: Theme.Spacing.lg),
            iconLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: button.topAnchor, constant: Theme.Spacing.md),
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: Theme.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -Theme.Spacing.lg),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xs),
            descriptionLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: Theme.Spacing.md),
            descriptionLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -Theme.Spacing.lg)
        ])
        
        return button
    }
    
    private func setupSubleaseTools() {
        subleaseView.translatesAutoresizingMaskIntoConstraints = false
        toolsContentView.addSubview(subleaseView)
        
        let titleLabel = UILabel()
        titleLabel.text = "🏠 Sublease & Housing"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subleaseView.addSubview(titleLabel)
        
        // Sublease segment control
        subleaseSegment.selectedSegmentIndex = 0
        subleaseSegment.addTarget(self, action: #selector(subleaseSegmentChanged), for: .valueChanged)
        subleaseSegment.translatesAutoresizingMaskIntoConstraints = false
        subleaseView.addSubview(subleaseSegment)
        
        // Sublease content view
        subleaseContentView.backgroundColor = Theme.Colors.surfaceSecondary
        subleaseContentView.layer.cornerRadius = Theme.CornerRadius.small
        subleaseContentView.translatesAutoresizingMaskIntoConstraints = false
        subleaseView.addSubview(subleaseContentView)
        
        // Quick action buttons
        let findButton = UIButton(type: .system)
        findButton.setTitle("🔍 Find Subleases", for: .normal)
        findButton.applySecondaryButtonStyle()
        findButton.addTarget(self, action: #selector(findSubleaseTapped), for: .touchUpInside)
        findButton.translatesAutoresizingMaskIntoConstraints = false
        subleaseContentView.addSubview(findButton)
        
        let postButton = UIButton(type: .system)
        postButton.setTitle("📝 Post Request", for: .normal)
        postButton.applySecondaryButtonStyle()
        postButton.addTarget(self, action: #selector(postSubleaseTapped), for: .touchUpInside)
        postButton.translatesAutoresizingMaskIntoConstraints = false
        subleaseContentView.addSubview(postButton)
        
        let myRequestsButton = UIButton(type: .system)
        myRequestsButton.setTitle("📋 My Requests", for: .normal)
        myRequestsButton.applySecondaryButtonStyle()
        myRequestsButton.addTarget(self, action: #selector(myRequestsTapped), for: .touchUpInside)
        myRequestsButton.translatesAutoresizingMaskIntoConstraints = false
        subleaseContentView.addSubview(myRequestsButton)
        
        NSLayoutConstraint.activate([
            subleaseView.topAnchor.constraint(equalTo: toolsContentView.topAnchor),
            subleaseView.leadingAnchor.constraint(equalTo: toolsContentView.leadingAnchor),
            subleaseView.trailingAnchor.constraint(equalTo: toolsContentView.trailingAnchor),
            subleaseView.bottomAnchor.constraint(equalTo: toolsContentView.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: subleaseView.topAnchor, constant: Theme.Spacing.lg),
            titleLabel.centerXAnchor.constraint(equalTo: subleaseView.centerXAnchor),
            
            subleaseSegment.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            subleaseSegment.leadingAnchor.constraint(equalTo: subleaseView.leadingAnchor, constant: Theme.Spacing.lg),
            subleaseSegment.trailingAnchor.constraint(equalTo: subleaseView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            subleaseContentView.topAnchor.constraint(equalTo: subleaseSegment.bottomAnchor, constant: Theme.Spacing.lg),
            subleaseContentView.leadingAnchor.constraint(equalTo: subleaseView.leadingAnchor, constant: Theme.Spacing.lg),
            subleaseContentView.trailingAnchor.constraint(equalTo: subleaseView.trailingAnchor, constant: -Theme.Spacing.lg),
            subleaseContentView.bottomAnchor.constraint(equalTo: subleaseView.bottomAnchor, constant: -Theme.Spacing.lg),
            
            findButton.topAnchor.constraint(equalTo: subleaseContentView.topAnchor, constant: Theme.Spacing.lg),
            findButton.leadingAnchor.constraint(equalTo: subleaseContentView.leadingAnchor, constant: Theme.Spacing.lg),
            findButton.trailingAnchor.constraint(equalTo: subleaseContentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            postButton.topAnchor.constraint(equalTo: findButton.bottomAnchor, constant: Theme.Spacing.md),
            postButton.leadingAnchor.constraint(equalTo: subleaseContentView.leadingAnchor, constant: Theme.Spacing.lg),
            postButton.trailingAnchor.constraint(equalTo: subleaseContentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            myRequestsButton.topAnchor.constraint(equalTo: postButton.bottomAnchor, constant: Theme.Spacing.md),
            myRequestsButton.leadingAnchor.constraint(equalTo: subleaseContentView.leadingAnchor, constant: Theme.Spacing.lg),
            myRequestsButton.trailingAnchor.constraint(equalTo: subleaseContentView.trailingAnchor, constant: -Theme.Spacing.lg),
            myRequestsButton.bottomAnchor.constraint(lessThanOrEqualTo: subleaseContentView.bottomAnchor, constant: -Theme.Spacing.lg)
        ])
        
        subleaseView.isHidden = true
    }
    
    private func setupSafetyResources() {
        safetyView.translatesAutoresizingMaskIntoConstraints = false
        toolsContentView.addSubview(safetyView)
        
        let titleLabel = UILabel()
        titleLabel.text = "🛡️ Safety & Legal"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        safetyView.addSubview(titleLabel)
        
        let emergencyButton = UIButton(type: .system)
        emergencyButton.setTitle("🚨 Emergency Contacts", for: .normal)
        emergencyButton.applySecondaryButtonStyle()
        emergencyButton.backgroundColor = Theme.Colors.error.withAlphaComponent(0.1)
        emergencyButton.addTarget(self, action: #selector(emergencyContactsTapped), for: .touchUpInside)
        emergencyButton.translatesAutoresizingMaskIntoConstraints = false
        safetyView.addSubview(emergencyButton)
        
        let checklistButton = UIButton(type: .system)
        checklistButton.setTitle("✅ Safety Checklist", for: .normal)
        checklistButton.applySecondaryButtonStyle()
        checklistButton.addTarget(self, action: #selector(safetyChecklistTapped), for: .touchUpInside)
        checklistButton.translatesAutoresizingMaskIntoConstraints = false
        safetyView.addSubview(checklistButton)
        
        let legalButton = UIButton(type: .system)
        legalButton.setTitle("⚖️ Legal Resources", for: .normal)
        legalButton.applySecondaryButtonStyle()
        legalButton.addTarget(self, action: #selector(legalResourcesTapped), for: .touchUpInside)
        legalButton.translatesAutoresizingMaskIntoConstraints = false
        safetyView.addSubview(legalButton)
        
        NSLayoutConstraint.activate([
            safetyView.topAnchor.constraint(equalTo: toolsContentView.topAnchor),
            safetyView.leadingAnchor.constraint(equalTo: toolsContentView.leadingAnchor),
            safetyView.trailingAnchor.constraint(equalTo: toolsContentView.trailingAnchor),
            safetyView.bottomAnchor.constraint(equalTo: toolsContentView.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: safetyView.topAnchor, constant: Theme.Spacing.lg),
            titleLabel.centerXAnchor.constraint(equalTo: safetyView.centerXAnchor),
            
            emergencyButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xl),
            emergencyButton.leadingAnchor.constraint(equalTo: safetyView.leadingAnchor, constant: Theme.Spacing.lg),
            emergencyButton.trailingAnchor.constraint(equalTo: safetyView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            checklistButton.topAnchor.constraint(equalTo: emergencyButton.bottomAnchor, constant: Theme.Spacing.md),
            checklistButton.leadingAnchor.constraint(equalTo: safetyView.leadingAnchor, constant: Theme.Spacing.lg),
            checklistButton.trailingAnchor.constraint(equalTo: safetyView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            legalButton.topAnchor.constraint(equalTo: checklistButton.bottomAnchor, constant: Theme.Spacing.md),
            legalButton.leadingAnchor.constraint(equalTo: safetyView.leadingAnchor, constant: Theme.Spacing.lg),
            legalButton.trailingAnchor.constraint(equalTo: safetyView.trailingAnchor, constant: -Theme.Spacing.lg)
        ])
        
        safetyView.isHidden = true
    }
    
    private func setupUniversityResources() {
        resourcesView.translatesAutoresizingMaskIntoConstraints = false
        toolsContentView.addSubview(resourcesView)
        
        let titleLabel = UILabel()
        titleLabel.text = "🎓 University Resources"
        titleLabel.font = Theme.Fonts.title2
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        resourcesView.addSubview(titleLabel)
        
        universitiesScrollView.showsHorizontalScrollIndicator = false
        universitiesScrollView.translatesAutoresizingMaskIntoConstraints = false
        resourcesView.addSubview(universitiesScrollView)
        
        universitiesStackView.axis = .horizontal
        universitiesStackView.spacing = Theme.Spacing.md
        universitiesStackView.translatesAutoresizingMaskIntoConstraints = false
        universitiesScrollView.addSubview(universitiesStackView)
        
        let universities = [
            ("🏫", "Harvard", "Cambridge, MA"),
            ("🎓", "Stanford", "Palo Alto, CA"),
            ("📚", "MIT", "Cambridge, MA"),
            ("🌟", "UCLA", "Los Angeles, CA"),
            ("🔬", "NYU", "New York, NY")
        ]
        
        for university in universities {
            let card = createUniversityCard(icon: university.0, name: university.1, location: university.2)
            universitiesStackView.addArrangedSubview(card)
        }
        
        NSLayoutConstraint.activate([
            resourcesView.topAnchor.constraint(equalTo: toolsContentView.topAnchor),
            resourcesView.leadingAnchor.constraint(equalTo: toolsContentView.leadingAnchor),
            resourcesView.trailingAnchor.constraint(equalTo: toolsContentView.trailingAnchor),
            resourcesView.bottomAnchor.constraint(equalTo: toolsContentView.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: resourcesView.topAnchor, constant: Theme.Spacing.lg),
            titleLabel.centerXAnchor.constraint(equalTo: resourcesView.centerXAnchor),
            
            universitiesScrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            universitiesScrollView.leadingAnchor.constraint(equalTo: resourcesView.leadingAnchor),
            universitiesScrollView.trailingAnchor.constraint(equalTo: resourcesView.trailingAnchor),
            universitiesScrollView.heightAnchor.constraint(equalToConstant: 120),
            
            universitiesStackView.topAnchor.constraint(equalTo: universitiesScrollView.topAnchor),
            universitiesStackView.leadingAnchor.constraint(equalTo: universitiesScrollView.leadingAnchor, constant: Theme.Spacing.lg),
            universitiesStackView.trailingAnchor.constraint(equalTo: universitiesScrollView.trailingAnchor, constant: -Theme.Spacing.lg),
            universitiesStackView.bottomAnchor.constraint(equalTo: universitiesScrollView.bottomAnchor),
            universitiesStackView.heightAnchor.constraint(equalTo: universitiesScrollView.heightAnchor)
        ])
        
        resourcesView.isHidden = true
    }
    
    private func createUniversityCard(icon: String, name: String, location: String) -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.Colors.surfaceSecondary
        card.layer.cornerRadius = Theme.CornerRadius.medium
        card.applyShadow(Theme.Shadow.small)
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 32)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconLabel)
        
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = Theme.Fonts.headline
        nameLabel.textColor = Theme.Colors.textPrimary
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(nameLabel)
        
        let locationLabel = UILabel()
        locationLabel.text = location
        locationLabel.font = Theme.Fonts.caption1
        locationLabel.textColor = Theme.Colors.textSecondary
        locationLabel.textAlignment = .center
        locationLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(locationLabel)
        
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: 140),
            
            iconLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: Theme.Spacing.md),
            iconLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: Theme.Spacing.sm),
            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Theme.Spacing.sm),
            nameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.sm),
            
            locationLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: Theme.Spacing.xs),
            locationLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Theme.Spacing.sm),
            locationLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.sm),
            locationLabel.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -Theme.Spacing.md)
        ])
        
        return card
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Hero View
            heroView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Spacing.lg),
            heroView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            heroView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            // Features View
            featuresView.topAnchor.constraint(equalTo: heroView.bottomAnchor, constant: Theme.Spacing.sectionSpacing),
            featuresView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            featuresView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            // Journey View
            journeyView.topAnchor.constraint(equalTo: featuresView.bottomAnchor, constant: Theme.Spacing.sectionSpacing),
            journeyView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            journeyView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            // Tools View
            toolsView.topAnchor.constraint(equalTo: journeyView.bottomAnchor, constant: Theme.Spacing.sectionSpacing),
            toolsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            toolsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            toolsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Spacing.xl)
        ])
    }
    
    private func animateOnAppear() {
        let views = [heroView, featuresView, journeyView, toolsView]
        
        for (index, view) in views.enumerated() {
            view.transform = CGAffineTransform(translationX: 0, y: 50)
            view.alpha = 0
            
            UIView.animate(withDuration: Theme.Animation.slow,
                           delay: Double(index) * 0.15,
                           usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 0) {
                view.transform = .identity
                view.alpha = 1
            }
        }
    }
    
    // MARK: - Actions
    @objc private func quickMatchTapped() {
        let alert = UIAlertController(title: "🎯 Quick Match", message: "Start your housing journey with our AI-powered matching system", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Start Matching", style: .default) { _ in
            // Switch to budget calculator tab
            self.toolsTabSegment.selectedSegmentIndex = 0
            self.showToolsTab(index: 0)
            
            // Scroll to tools section
            let toolsOffset = CGPoint(x: 0, y: self.toolsView.frame.origin.y - 100)
            self.scrollView.setContentOffset(toolsOffset, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func journeyStepTapped(_ gesture: UITapGestureRecognizer) {
        guard let stepNumber = gesture.view?.tag else { return }
        
        let stepActions = [
            1: "Budget Calculator",
            2: "Housing Comparison", 
            3: "Roommate Tools",
            4: "Safety Resources",
            5: "University Resources"
        ]
        
        if let tabIndex = stepActions.keys.first(where: { $0 == stepNumber }) {
            toolsTabSegment.selectedSegmentIndex = tabIndex - 1
            showToolsTab(index: tabIndex - 1)
            
            // Scroll to tools section
            let toolsOffset = CGPoint(x: 0, y: toolsView.frame.origin.y - 100)
            scrollView.setContentOffset(toolsOffset, animated: true)
        }
    }
    
    @objc private func toolsTabChanged() {
        showToolsTab(index: toolsTabSegment.selectedSegmentIndex)
    }
    
    private func showToolsTab(index: Int) {
        // Hide all tool views
        [budgetCalculatorView, comparisonView, roommateView, subleaseView, safetyView, resourcesView].forEach { $0.isHidden = true }
        
        // Show selected view
        switch index {
        case 0:
            budgetCalculatorView.isHidden = false
        case 1:
            comparisonView.isHidden = false
        case 2:
            subleaseView.isHidden = false
        case 3:
            safetyView.isHidden = false
        case 4:
            resourcesView.isHidden = false
        default:
            budgetCalculatorView.isHidden = false
        }
        
        // Animate transition
        UIView.transition(with: toolsContentView, duration: Theme.Animation.fast, options: .transitionCrossDissolve, animations: nil)
    }
    
    @objc private func budgetSliderChanged(_ slider: UISlider) {
        monthlyBudget = Double(slider.value)
        if let budgetLabel = budgetCalculatorView.viewWithTag(100) as? UILabel {
            budgetLabel.text = "$\(Int(monthlyBudget))/month"
        }
    }
    
    @objc private func budgetPresetTapped(_ sender: UIButton) {
        monthlyBudget = Double(sender.tag)
        if let budgetLabel = budgetCalculatorView.viewWithTag(100) as? UILabel {
            budgetLabel.text = "$\(Int(monthlyBudget))/month"
        }
        
        // Update slider
        if let slider = budgetCalculatorView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.value = Float(monthlyBudget)
        }
    }
    
    @objc private func calculateBudgetTapped() {
        let alert = UIAlertController(title: "💰 Budget Analysis", message: "Based on your $\(Int(monthlyBudget))/month budget:\n\n🏫 Dorms: \(monthlyBudget >= 800 ? "✅" : "❌") Affordable\n🏢 Apartments: \(monthlyBudget >= 600 ? "✅" : "❌") Affordable\n🏡 Shared: \(monthlyBudget >= 400 ? "✅" : "❌") Affordable", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Find Properties", style: .default) { _ in
            // Navigate to browse with budget filter
            self.tabBarController?.selectedIndex = 1
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func emergencyContactsTapped() {
        let alert = UIAlertController(title: "🚨 Emergency Contacts", message: "Emergency: 911\nCampus Police: (Contact your university)\nPoison Control: 1-800-222-1222\nCrisis Text: Text HOME to 741741", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Save to Contacts", style: .default))
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func safetyChecklistTapped() {
        let alert = UIAlertController(title: "✅ Safety Checklist", message: "□ Check door locks\n□ Test smoke detectors\n□ Know emergency exits\n□ Share location with trusted contacts\n□ Document property condition\n□ Get renters insurance", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func legalResourcesTapped() {
        let alert = UIAlertController(title: "⚖️ Legal Resources", message: "• Know your tenant rights\n• Read lease agreements carefully\n• Document everything\n• Get legal aid if needed\n• Understand deposit rules", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Sublease Actions
    
    @objc private func subleaseSegmentChanged() {
        // Handle sublease segment changes
        let selectedIndex = subleaseSegment.selectedSegmentIndex
        // Update content based on selection
    }
    
    @objc private func findSubleaseTapped() {
        // Navigate to full sublease search
        let subleaseViewController = SubleaseViewController()
        subleaseViewController.initialView = .find
        navigationController?.pushViewController(subleaseViewController, animated: true)
    }
    
    @objc private func postSubleaseTapped() {
        // Navigate to post sublease request
        let subleaseViewController = SubleaseViewController()
        subleaseViewController.initialView = .post
        navigationController?.pushViewController(subleaseViewController, animated: true)
    }
    
    @objc private func myRequestsTapped() {
        // Navigate to my requests
        let subleaseViewController = SubleaseViewController()
        subleaseViewController.initialView = .myRequests
        navigationController?.pushViewController(subleaseViewController, animated: true)
    }
}

// MARK: - Sublease View Controller

class SubleaseViewController: UIViewController {
    
    var initialView: SubleaseViewType = .find
    
    enum SubleaseViewType {
        case find
        case post
        case myRequests
    }
    
    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let segmentControl = UISegmentedControl(items: ["Find Sublease", "Post Request", "My Requests"])
    
    // Container views for different modes
    private let findContainer = UIView()
    private let postContainer = UIView()
    private let requestsContainer = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        
        // Set initial view
        switch initialView {
        case .find:
            segmentControl.selectedSegmentIndex = 0
        case .post:
            segmentControl.selectedSegmentIndex = 1
        case .myRequests:
            segmentControl.selectedSegmentIndex = 2
        }
        
        showSelectedView()
    }
    
    private func setupUI() {
        view.backgroundColor = Theme.backgroundColor
        title = "Student Housing"
        
        // Configure navigation
        navigationItem.largeTitleDisplayMode = .never
        
        // Configure scroll view
        scrollView.backgroundColor = Theme.backgroundColor
        scrollView.showsVerticalScrollIndicator = false
        
        // Configure segment control
        segmentControl.backgroundColor = Theme.cardBackgroundColor
        segmentControl.selectedSegmentTintColor = Theme.primaryColor
        segmentControl.layer.cornerRadius = 8
        segmentControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(segmentControl)
        contentView.addSubview(findContainer)
        contentView.addSubview(postContainer)
        contentView.addSubview(requestsContainer)
        
        setupFindSubleaseView()
        setupPostRequestView()
        setupMyRequestsView()
    }
    
    private func setupFindSubleaseView() {
        findContainer.backgroundColor = Theme.cardBackgroundColor
        findContainer.layer.cornerRadius = 12
        
        let titleLabel = UILabel()
        titleLabel.text = "Find Subleases"
        titleLabel.font = Theme.boldFont(size: 24)
        titleLabel.textColor = Theme.textColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        findContainer.addSubview(titleLabel)
        
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search by location, price, or amenities..."
        searchBar.backgroundColor = Theme.backgroundColor
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        findContainer.addSubview(searchBar)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: findContainer.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: findContainer.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: findContainer.trailingAnchor, constant: -20),
            
            searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            searchBar.leadingAnchor.constraint(equalTo: findContainer.leadingAnchor, constant: 20),
            searchBar.trailingAnchor.constraint(equalTo: findContainer.trailingAnchor, constant: -20),
            searchBar.bottomAnchor.constraint(equalTo: findContainer.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupPostRequestView() {
        postContainer.backgroundColor = Theme.cardBackgroundColor
        postContainer.layer.cornerRadius = 12
        
        let titleLabel = UILabel()
        titleLabel.text = "Post Sublease Request"
        titleLabel.font = Theme.boldFont(size: 24)
        titleLabel.textColor = Theme.textColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        postContainer.addSubview(titleLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = "Tell us what you're looking for and we'll help you find the perfect sublease"
        descriptionLabel.font = Theme.regularFont(size: 16)
        descriptionLabel.textColor = Theme.secondaryTextColor
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        postContainer.addSubview(descriptionLabel)
        
        let postButton = UIButton(type: .system)
        postButton.setTitle("Create Request", for: .normal)
        postButton.backgroundColor = Theme.primaryColor
        postButton.setTitleColor(.white, for: .normal)
        postButton.layer.cornerRadius = 12
        postButton.translatesAutoresizingMaskIntoConstraints = false
        postContainer.addSubview(postButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: postContainer.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: postContainer.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: postContainer.trailingAnchor, constant: -20),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: postContainer.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: postContainer.trailingAnchor, constant: -20),
            
            postButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            postButton.leadingAnchor.constraint(equalTo: postContainer.leadingAnchor, constant: 20),
            postButton.trailingAnchor.constraint(equalTo: postContainer.trailingAnchor, constant: -20),
            postButton.heightAnchor.constraint(equalToConstant: 50),
            postButton.bottomAnchor.constraint(equalTo: postContainer.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupMyRequestsView() {
        requestsContainer.backgroundColor = Theme.cardBackgroundColor
        requestsContainer.layer.cornerRadius = 12
        
        let titleLabel = UILabel()
        titleLabel.text = "My Requests"
        titleLabel.font = Theme.boldFont(size: 24)
        titleLabel.textColor = Theme.textColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        requestsContainer.addSubview(titleLabel)
        
        let emptyLabel = UILabel()
        emptyLabel.text = "No requests yet.\nCreate your first request to get started!"
        emptyLabel.font = Theme.regularFont(size: 16)
        emptyLabel.textColor = Theme.secondaryTextColor
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        requestsContainer.addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: requestsContainer.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: requestsContainer.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: requestsContainer.trailingAnchor, constant: -20),
            
            emptyLabel.centerXAnchor.constraint(equalTo: requestsContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: requestsContainer.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: requestsContainer.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: requestsContainer.trailingAnchor, constant: -40)
        ])
    }
    
    private func setupConstraints() {
        [scrollView, contentView, segmentControl, findContainer, postContainer, requestsContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Segment control
            segmentControl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            segmentControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            segmentControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            segmentControl.heightAnchor.constraint(equalToConstant: 40),
            
            // Containers
            findContainer.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 20),
            findContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            findContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            findContainer.heightAnchor.constraint(equalToConstant: 200),
            
            postContainer.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 20),
            postContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            postContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            postContainer.heightAnchor.constraint(equalToConstant: 200),
            
            requestsContainer.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 20),
            requestsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            requestsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            requestsContainer.heightAnchor.constraint(equalToConstant: 200),
            requestsContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func segmentChanged() {
        showSelectedView()
    }
    
    private func showSelectedView() {
        let selectedIndex = segmentControl.selectedSegmentIndex
        
        findContainer.isHidden = selectedIndex != 0
        postContainer.isHidden = selectedIndex != 1
        requestsContainer.isHidden = selectedIndex != 2
        
        // Animate transition
        UIView.transition(with: contentView, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }
}