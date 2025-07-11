import UIKit

class AINegotiatorViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let heroView = UIView()
    private let heroLabel = UILabel()
    private let heroSubtitleLabel = UILabel()
    private let featuresStackView = UIStackView()
    private let startNegotiationButton = UIButton(type: .system)
    private let howItWorksView = UIView()
    private let chatContainer = UIView()
    
    private let features = [
        ("AI-Powered Analysis", "Get data-driven insights on property values and market trends", "chart.bar.xaxis"),
        ("Smart Negotiation", "AI crafts personalized negotiation strategies based on your preferences", "brain.head.profile"),
        ("Real-Time Messaging", "Chat directly with property owners through our secure platform", "message.badge"),
        ("Success Tracking", "Monitor your negotiation progress and savings achieved", "dollarsign.circle")
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        animateOnAppear()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Apply background gradient
        view.applyGradient(colors: Theme.Colors.gradientBackground, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1))
    }
    
    private func setupUI() {
        title = "AI Negotiator"
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Configure hero view
        heroView.applyGlassEffect(alpha: 0.9)
        heroView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(heroView)
        
        // Configure hero label
        heroLabel.text = "AI-Powered Rent Negotiation"
        heroLabel.font = Theme.Fonts.displayMedium
        heroLabel.textColor = Theme.Colors.textPrimary
        heroLabel.textAlignment = .center
        heroLabel.numberOfLines = 0
        heroLabel.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(heroLabel)
        
        // Configure hero subtitle
        heroSubtitleLabel.text = "Let our AI negotiate the best price for your dream property. Save up to 15% on rent with smart, data-driven negotiations."
        heroSubtitleLabel.font = Theme.Fonts.body
        heroSubtitleLabel.textColor = Theme.Colors.textSecondary
        heroSubtitleLabel.textAlignment = .center
        heroSubtitleLabel.numberOfLines = 0
        heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(heroSubtitleLabel)
        
        // Configure start button
        startNegotiationButton.setTitle("Start AI Negotiation", for: .normal)
        startNegotiationButton.applyMagneticStyle()
        startNegotiationButton.addTarget(self, action: #selector(startNegotiationTapped), for: .touchUpInside)
        startNegotiationButton.translatesAutoresizingMaskIntoConstraints = false
        heroView.addSubview(startNegotiationButton)
        
        // Configure features stack view
        featuresStackView.axis = .vertical
        featuresStackView.spacing = Theme.Spacing.lg
        featuresStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(featuresStackView)
        
        // Add feature cards
        for feature in features {
            let featureCard = createFeatureCard(title: feature.0, description: feature.1, iconName: feature.2)
            featuresStackView.addArrangedSubview(featureCard)
        }
        
        // Configure how it works section
        setupHowItWorksSection()
        
        // Configure chat container
        setupChatContainer()
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
            
            heroView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Spacing.lg),
            heroView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            heroView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            heroLabel.topAnchor.constraint(equalTo: heroView.topAnchor, constant: Theme.Spacing.xl),
            heroLabel.leadingAnchor.constraint(equalTo: heroView.leadingAnchor, constant: Theme.Spacing.lg),
            heroLabel.trailingAnchor.constraint(equalTo: heroView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            heroSubtitleLabel.topAnchor.constraint(equalTo: heroLabel.bottomAnchor, constant: Theme.Spacing.md),
            heroSubtitleLabel.leadingAnchor.constraint(equalTo: heroView.leadingAnchor, constant: Theme.Spacing.lg),
            heroSubtitleLabel.trailingAnchor.constraint(equalTo: heroView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            startNegotiationButton.topAnchor.constraint(equalTo: heroSubtitleLabel.bottomAnchor, constant: Theme.Spacing.xl),
            startNegotiationButton.centerXAnchor.constraint(equalTo: heroView.centerXAnchor),
            startNegotiationButton.widthAnchor.constraint(equalToConstant: 240),
            startNegotiationButton.heightAnchor.constraint(equalToConstant: Theme.Spacing.buttonHeight),
            startNegotiationButton.bottomAnchor.constraint(equalTo: heroView.bottomAnchor, constant: -Theme.Spacing.xl),
            
            featuresStackView.topAnchor.constraint(equalTo: heroView.bottomAnchor, constant: Theme.Spacing.sectionSpacing),
            featuresStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            featuresStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            howItWorksView.topAnchor.constraint(equalTo: featuresStackView.bottomAnchor, constant: Theme.Spacing.sectionSpacing),
            howItWorksView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            howItWorksView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            chatContainer.topAnchor.constraint(equalTo: howItWorksView.bottomAnchor, constant: Theme.Spacing.sectionSpacing),
            chatContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.lg),
            chatContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.lg),
            chatContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Spacing.xl)
        ])
    }
    
    private func createFeatureCard(title: String, description: String, iconName: String) -> UIView {
        let card = UIView()
        card.applyPremiumCardStyle()
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = Theme.Colors.primary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconView)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.Fonts.title3
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
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: Theme.Spacing.lg),
            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Theme.Spacing.lg),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: Theme.Spacing.lg),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Theme.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.lg),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.sm),
            descriptionLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Theme.Spacing.md),
            descriptionLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Theme.Spacing.lg),
            descriptionLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Theme.Spacing.lg)
        ])
        
        return card
    }
    
    private func setupHowItWorksSection() {
        howItWorksView.applyGlassEffect(alpha: 0.8)
        howItWorksView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(howItWorksView)
        
        let titleLabel = UILabel()
        titleLabel.text = "How AI Negotiation Works"
        titleLabel.font = Theme.Fonts.displaySmall
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        howItWorksView.addSubview(titleLabel)
        
        let stepsStackView = UIStackView()
        stepsStackView.axis = .vertical
        stepsStackView.spacing = Theme.Spacing.lg
        stepsStackView.translatesAutoresizingMaskIntoConstraints = false
        howItWorksView.addSubview(stepsStackView)
        
        let steps = [
            ("1", "Share Property Details", "Tell us about the property you're interested in"),
            ("2", "AI Analysis", "Our AI analyzes market data and property value"),
            ("3", "Negotiation Strategy", "AI creates a personalized negotiation approach"),
            ("4", "Automated Outreach", "AI communicates with the property owner"),
            ("5", "Success!", "You get the best possible deal")
        ]
        
        for step in steps {
            let stepView = createStepView(number: step.0, title: step.1, description: step.2)
            stepsStackView.addArrangedSubview(stepView)
        }
        
        NSLayoutConstraint.activate([
            howItWorksView.heightAnchor.constraint(greaterThanOrEqualToConstant: 400),
            
            titleLabel.topAnchor.constraint(equalTo: howItWorksView.topAnchor, constant: Theme.Spacing.xl),
            titleLabel.leadingAnchor.constraint(equalTo: howItWorksView.leadingAnchor, constant: Theme.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: howItWorksView.trailingAnchor, constant: -Theme.Spacing.lg),
            
            stepsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xl),
            stepsStackView.leadingAnchor.constraint(equalTo: howItWorksView.leadingAnchor, constant: Theme.Spacing.lg),
            stepsStackView.trailingAnchor.constraint(equalTo: howItWorksView.trailingAnchor, constant: -Theme.Spacing.lg),
            stepsStackView.bottomAnchor.constraint(equalTo: howItWorksView.bottomAnchor, constant: -Theme.Spacing.xl)
        ])
    }
    
    private func createStepView(number: String, title: String, description: String) -> UIView {
        let container = UIView()
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
            numberView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            numberView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            numberView.widthAnchor.constraint(equalToConstant: 40),
            numberView.heightAnchor.constraint(equalToConstant: 40),
            
            numberLabel.centerXAnchor.constraint(equalTo: numberView.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: numberView.centerYAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: numberView.trailingAnchor, constant: Theme.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xs),
            descriptionLabel.leadingAnchor.constraint(equalTo: numberView.trailingAnchor, constant: Theme.Spacing.md),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func setupChatContainer() {
        chatContainer.applyPremiumCardStyle()
        chatContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(chatContainer)
        
        let chatTitleLabel = UILabel()
        chatTitleLabel.text = "Try AI Negotiation Demo"
        chatTitleLabel.font = Theme.Fonts.title2
        chatTitleLabel.textColor = Theme.Colors.textPrimary
        chatTitleLabel.textAlignment = .center
        chatTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        chatContainer.addSubview(chatTitleLabel)
        
        let demoButton = UIButton(type: .system)
        demoButton.setTitle("Start Demo Chat", for: .normal)
        demoButton.applySecondaryStyle()
        demoButton.addTarget(self, action: #selector(startDemoTapped), for: .touchUpInside)
        demoButton.translatesAutoresizingMaskIntoConstraints = false
        chatContainer.addSubview(demoButton)
        
        NSLayoutConstraint.activate([
            chatContainer.heightAnchor.constraint(equalToConstant: 150),
            
            chatTitleLabel.topAnchor.constraint(equalTo: chatContainer.topAnchor, constant: Theme.Spacing.xl),
            chatTitleLabel.leadingAnchor.constraint(equalTo: chatContainer.leadingAnchor, constant: Theme.Spacing.lg),
            chatTitleLabel.trailingAnchor.constraint(equalTo: chatContainer.trailingAnchor, constant: -Theme.Spacing.lg),
            
            demoButton.topAnchor.constraint(equalTo: chatTitleLabel.bottomAnchor, constant: Theme.Spacing.lg),
            demoButton.centerXAnchor.constraint(equalTo: chatContainer.centerXAnchor),
            demoButton.widthAnchor.constraint(equalToConstant: 180),
            demoButton.heightAnchor.constraint(equalToConstant: Theme.Spacing.buttonHeight)
        ])
    }
    
    private func animateOnAppear() {
        heroView.transform = CGAffineTransform(translationX: 0, y: -50)
        heroView.alpha = 0
        
        featuresStackView.transform = CGAffineTransform(translationX: 0, y: 50)
        featuresStackView.alpha = 0
        
        UIView.animate(withDuration: Theme.Animation.slow, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.heroView.transform = .identity
            self.heroView.alpha = 1
        }
        
        UIView.animate(withDuration: Theme.Animation.slow, delay: 0.3, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.featuresStackView.transform = .identity
            self.featuresStackView.alpha = 1
        }
    }
    
    @objc private func startNegotiationTapped() {
        let alert = UIAlertController(
            title: "Start AI Negotiation",
            message: "This feature connects you with our AI negotiation system. Would you like to begin?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Start Now", style: .default) { _ in
            // Navigate to chat with AI negotiation context
            let chatVC = ChatViewController()
            self.navigationController?.pushViewController(chatVC, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Learn More", style: .default) { _ in
            self.showLearnMore()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func startDemoTapped() {
        let demoVC = AINegotiationDemoViewController()
        navigationController?.pushViewController(demoVC, animated: true)
    }
    
    private func showLearnMore() {
        let alert = UIAlertController(
            title: "AI Negotiation Benefits",
            message: "• Save 10-15% on average rent\n• Data-driven negotiation strategies\n• Professional communication\n• Higher success rates\n• 24/7 availability",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Demo View Controller
class AINegotiationDemoViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Colors.background
        title = "AI Negotiation Demo"
        
        let comingSoonLabel = UILabel()
        comingSoonLabel.text = "🤖 AI Negotiation Demo\nComing Soon!"
        comingSoonLabel.font = Theme.Fonts.displaySmall
        comingSoonLabel.textColor = Theme.Colors.textPrimary
        comingSoonLabel.textAlignment = .center
        comingSoonLabel.numberOfLines = 0
        comingSoonLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(comingSoonLabel)
        
        NSLayoutConstraint.activate([
            comingSoonLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            comingSoonLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}