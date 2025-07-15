import UIKit

class PricingPlansViewController: UIViewController {
    
    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let plansStackView = UIStackView()
    private let freeTrialBanner = UIView()
    private let currentPlanLabel = UILabel()
    
    // Data
    private var pricingPlans: [PricingPlan] = []
    private var currentSubscription: SubscriptionInfo?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadPricingPlans()
        loadCurrentSubscription()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Pricing Plans"
        
        // Configure scroll view
        scrollView.backgroundColor = .systemBackground
        scrollView.showsVerticalScrollIndicator = false
        
        // Configure content view
        contentView.backgroundColor = .systemBackground
        
        // Configure title
        titleLabel.text = "Choose Your Plan"
        titleLabel.font = Theme.Fonts.displaySmall
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        
        // Configure subtitle
        subtitleLabel.text = "Unlock premium features and get the best housing experience"
        subtitleLabel.font = Theme.Fonts.body
        subtitleLabel.textColor = Theme.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        // Configure current plan label
        currentPlanLabel.font = Theme.Fonts.headline
        currentPlanLabel.textColor = Theme.Colors.primary
        currentPlanLabel.textAlignment = .center
        currentPlanLabel.isHidden = true
        
        // Configure plans stack view
        plansStackView.axis = .vertical
        plansStackView.spacing = 20
        plansStackView.distribution = .fillEqually
        
        // Configure free trial banner
        setupFreeTrialBanner()
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(currentPlanLabel)
        contentView.addSubview(freeTrialBanner)
        contentView.addSubview(plansStackView)
    }
    
    private func setupFreeTrialBanner() {
        freeTrialBanner.backgroundColor = Theme.Colors.primary.withAlphaComponent(0.1)
        freeTrialBanner.layer.cornerRadius = 12
        freeTrialBanner.layer.borderWidth = 1
        freeTrialBanner.layer.borderColor = Theme.Colors.primary.withAlphaComponent(0.3).cgColor
        
        let bannerLabel = UILabel()
        bannerLabel.text = "🎉 Start your 7-day free trial today!"
        bannerLabel.font = Theme.Fonts.headline
        bannerLabel.textColor = Theme.Colors.primary
        bannerLabel.textAlignment = .center
        bannerLabel.translatesAutoresizingMaskIntoConstraints = false
        freeTrialBanner.addSubview(bannerLabel)
        
        NSLayoutConstraint.activate([
            bannerLabel.centerXAnchor.constraint(equalTo: freeTrialBanner.centerXAnchor),
            bannerLabel.centerYAnchor.constraint(equalTo: freeTrialBanner.centerYAnchor),
            bannerLabel.leadingAnchor.constraint(equalTo: freeTrialBanner.leadingAnchor, constant: 20),
            bannerLabel.trailingAnchor.constraint(equalTo: freeTrialBanner.trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - Constraints
    
    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        currentPlanLabel.translatesAutoresizingMaskIntoConstraints = false
        freeTrialBanner.translatesAutoresizingMaskIntoConstraints = false
        plansStackView.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Current plan label
            currentPlanLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            currentPlanLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            currentPlanLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Free trial banner
            freeTrialBanner.topAnchor.constraint(equalTo: currentPlanLabel.bottomAnchor, constant: 20),
            freeTrialBanner.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            freeTrialBanner.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            freeTrialBanner.heightAnchor.constraint(equalToConstant: 60),
            
            // Plans stack view
            plansStackView.topAnchor.constraint(equalTo: freeTrialBanner.bottomAnchor, constant: 30),
            plansStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            plansStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            plansStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadPricingPlans() {
        pricingPlans = [
            PricingPlan(
                id: "free",
                name: "Free",
                price: 0,
                billingCycle: "forever",
                features: [
                    "Browse unlimited properties",
                    "Basic search filters",
                    "Contact property owners",
                    "Save up to 5 favorites",
                    "Basic mortgage calculator"
                ],
                isPopular: false,
                isCurrentPlan: true
            ),
            PricingPlan(
                id: "pro",
                name: "Pro",
                price: 9.99,
                billingCycle: "month",
                features: [
                    "Everything in Free",
                    "Unlimited favorites",
                    "Advanced search filters",
                    "Priority customer support",
                    "AI-powered recommendations",
                    "Legal help resources",
                    "Mortgage tools & calculators",
                    "Market insights & analytics"
                ],
                isPopular: true,
                isCurrentPlan: false
            ),
            PricingPlan(
                id: "premium",
                name: "Premium",
                price: 19.99,
                billingCycle: "month",
                features: [
                    "Everything in Pro",
                    "AI Negotiator assistant",
                    "Sublease matching service",
                    "Exclusive property listings",
                    "Personal housing consultant",
                    "Priority viewing scheduling",
                    "Background check services",
                    "Moving assistance coordination"
                ],
                isPopular: false,
                isCurrentPlan: false
            )
        ]
        
        createPlanViews()
    }
    
    private func loadCurrentSubscription() {
        guard SessionManager.shared.isSessionValid(),
              let user = SessionManager.shared.getCurrentUser() else {
            return
        }
        
        // Simulate API call for subscription status
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // Simulate user having a free plan
            self?.currentSubscription = SubscriptionInfo(plan: "free", status: "active", expiresAt: nil)
            self?.updateCurrentPlanDisplay()
        }
    }
    
    private func updateCurrentPlanDisplay() {
        guard let subscription = currentSubscription else {
            currentPlanLabel.text = "Current Plan: Free"
            currentPlanLabel.isHidden = false
            return
        }
        
        currentPlanLabel.text = "Current Plan: \(subscription.plan.capitalized)"
        currentPlanLabel.isHidden = false
        
        // Update plan states
        for plan in pricingPlans {
            plan.isCurrentPlan = plan.id == subscription.plan.lowercased()
        }
        
        // Refresh plan views
        createPlanViews()
    }
    
    private func createPlanViews() {
        // Clear existing views
        plansStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for plan in pricingPlans {
            let planView = createPlanView(for: plan)
            plansStackView.addArrangedSubview(planView)
        }
    }
    
    private func createPlanView(for plan: PricingPlan) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = Theme.Colors.cardBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowRadius = 8
        
        // Add popular badge
        if plan.isPopular {
            let popularBadge = UILabel()
            popularBadge.text = "MOST POPULAR"
            popularBadge.font = Theme.Fonts.caption1
            popularBadge.textColor = .white
            popularBadge.backgroundColor = Theme.Colors.primary
            popularBadge.textAlignment = .center
            popularBadge.layer.cornerRadius = 12
            popularBadge.clipsToBounds = true
            popularBadge.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(popularBadge)
            
            NSLayoutConstraint.activate([
                popularBadge.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -12),
                popularBadge.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                popularBadge.widthAnchor.constraint(equalToConstant: 120),
                popularBadge.heightAnchor.constraint(equalToConstant: 24)
            ])
        }
        
        // Plan name
        let nameLabel = UILabel()
        nameLabel.text = plan.name
        nameLabel.font = Theme.Fonts.title1
        nameLabel.textColor = Theme.Colors.textPrimary
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(nameLabel)
        
        // Price
        let priceLabel = UILabel()
        if plan.price == 0 {
            priceLabel.text = "Free"
        } else {
            priceLabel.text = "$\(String(format: "%.2f", plan.price))/\(plan.billingCycle)"
        }
        priceLabel.font = Theme.Fonts.title2
        priceLabel.textColor = Theme.Colors.primary
        priceLabel.textAlignment = .center
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(priceLabel)
        
        // Features
        let featuresStackView = UIStackView()
        featuresStackView.axis = .vertical
        featuresStackView.spacing = 8
        featuresStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(featuresStackView)
        
        for feature in plan.features {
            let featureLabel = UILabel()
            featureLabel.text = "✓ \(feature)"
            featureLabel.font = Theme.Fonts.subheadline
            featureLabel.textColor = Theme.Colors.textPrimary
            featureLabel.numberOfLines = 0
            featuresStackView.addArrangedSubview(featureLabel)
        }
        
        // Action button
        let actionButton = UIButton(type: .system)
        
        if plan.isCurrentPlan {
            actionButton.setTitle("Current Plan", for: .normal)
            actionButton.backgroundColor = Theme.Colors.secondary
            actionButton.isEnabled = false
        } else {
            actionButton.setTitle(plan.price == 0 ? "Downgrade" : "Upgrade", for: .normal)
            actionButton.backgroundColor = Theme.Colors.primary
            actionButton.isEnabled = true
        }
        
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.titleLabel?.font = Theme.Fonts.headline
        actionButton.layer.cornerRadius = 12
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.addTarget(self, action: #selector(planButtonTapped(_:)), for: .touchUpInside)
        actionButton.tag = pricingPlans.firstIndex(where: { $0.id == plan.id }) ?? 0
        containerView.addSubview(actionButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            priceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            priceLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            priceLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            featuresStackView.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 20),
            featuresStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            featuresStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            actionButton.topAnchor.constraint(equalTo: featuresStackView.bottomAnchor, constant: 20),
            actionButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            actionButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            actionButton.heightAnchor.constraint(equalToConstant: 50),
            actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
        
        return containerView
    }
    
    // MARK: - Actions
    
    @objc private func planButtonTapped(_ sender: UIButton) {
        let selectedPlan = pricingPlans[sender.tag]
        
        guard SessionManager.shared.isSessionValid() else {
            showLoginAlert()
            return
        }
        
        if selectedPlan.price == 0 {
            // Downgrade to free
            showDowngradeConfirmation(for: selectedPlan)
        } else {
            // Upgrade to paid plan
            showUpgradeConfirmation(for: selectedPlan)
        }
    }
    
    private func showLoginAlert() {
        let alert = UIAlertController(title: "Login Required", message: "Please log in to manage your subscription", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Login", style: .default) { _ in
            // Navigate to login screen
            let authVC = AuthViewController()
            let navController = UINavigationController(rootViewController: authVC)
            self.present(navController, animated: true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showUpgradeConfirmation(for plan: PricingPlan) {
        let alert = UIAlertController(
            title: "Upgrade to \(plan.name)",
            message: "Upgrade to \(plan.name) for $\(String(format: "%.2f", plan.price))/\(plan.billingCycle)?\n\nYou'll get access to all premium features.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Upgrade", style: .default) { _ in
            self.processUpgrade(to: plan)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showDowngradeConfirmation(for plan: PricingPlan) {
        let alert = UIAlertController(
            title: "Downgrade to Free",
            message: "Are you sure you want to downgrade to the free plan? You'll lose access to premium features.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Downgrade", style: .destructive) { _ in
            self.processDowngrade(to: plan)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func processUpgrade(to plan: PricingPlan) {
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Processing...", message: "Please wait while we process your upgrade", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // Simulate payment processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            loadingAlert.dismiss(animated: true) {
                // For demo purposes, show success
                self.showUpgradeSuccess(for: plan)
            }
        }
    }
    
    private func processDowngrade(to plan: PricingPlan) {
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Processing...", message: "Please wait while we process your downgrade", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // Simulate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            loadingAlert.dismiss(animated: true) {
                // For demo purposes, show success
                self.showDowngradeSuccess(for: plan)
            }
        }
    }
    
    private func showUpgradeSuccess(for plan: PricingPlan) {
        let alert = UIAlertController(
            title: "Upgrade Successful!",
            message: "Welcome to \(plan.name)! You now have access to all premium features.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Great!", style: .default) { _ in
            // Update current plan
            self.updatePlanStatus(to: plan)
        })
        
        present(alert, animated: true)
    }
    
    private func showDowngradeSuccess(for plan: PricingPlan) {
        let alert = UIAlertController(
            title: "Downgrade Successful",
            message: "You've been downgraded to the free plan. You can upgrade again anytime.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            // Update current plan
            self.updatePlanStatus(to: plan)
        })
        
        present(alert, animated: true)
    }
    
    private func updatePlanStatus(to plan: PricingPlan) {
        // Update plan states
        for existingPlan in pricingPlans {
            existingPlan.isCurrentPlan = existingPlan.id == plan.id
        }
        
        // Update UI
        currentPlanLabel.text = "Current Plan: \(plan.name)"
        createPlanViews()
    }
}

// MARK: - Data Models

struct SubscriptionInfo {
    let plan: String
    let status: String
    let expiresAt: String?
}

class PricingPlan {
    let id: String
    let name: String
    let price: Double
    let billingCycle: String
    let features: [String]
    let isPopular: Bool
    var isCurrentPlan: Bool
    
    init(id: String, name: String, price: Double, billingCycle: String, features: [String], isPopular: Bool, isCurrentPlan: Bool) {
        self.id = id
        self.name = name
        self.price = price
        self.billingCycle = billingCycle
        self.features = features
        self.isPopular = isPopular
        self.isCurrentPlan = isCurrentPlan
    }
}