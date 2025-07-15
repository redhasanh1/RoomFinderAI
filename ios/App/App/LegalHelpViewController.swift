import UIKit

class LegalHelpViewController: UIViewController {
    
    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // Categories
    private let categoriesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 15
        layout.minimumInteritemSpacing = 15
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()
    
    // Articles Table View
    private let articlesTableView = UITableView()
    
    // Emergency Contact Button
    private let emergencyContactButton = UIButton(type: .system)
    
    // Data
    private var categories: [LegalCategory] = []
    private var articles: [LegalArticle] = []
    private var selectedCategory: LegalCategory?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        setupTableView()
        setupConstraints()
        loadData()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = Theme.Colors.background
        title = "Legal Help"
        
        // Configure scroll view
        scrollView.backgroundColor = Theme.Colors.background
        scrollView.showsVerticalScrollIndicator = false
        
        // Configure content view
        contentView.backgroundColor = Theme.Colors.background
        
        // Configure title
        titleLabel.text = "Legal Resources"
        titleLabel.font = Theme.Fonts.title1
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.textAlignment = .center
        
        // Configure subtitle
        subtitleLabel.text = "Get help with rental agreements, tenant rights, and legal issues"
        subtitleLabel.font = Theme.Fonts.body
        subtitleLabel.textColor = Theme.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        // Configure categories collection view
        categoriesCollectionView.backgroundColor = Theme.Colors.background
        categoriesCollectionView.showsHorizontalScrollIndicator = false
        
        // Configure articles table view
        articlesTableView.backgroundColor = Theme.Colors.background
        articlesTableView.separatorStyle = .none
        articlesTableView.showsVerticalScrollIndicator = false
        
        // Configure emergency contact button
        emergencyContactButton.setTitle("🚨 Emergency Legal Help", for: .normal)
        emergencyContactButton.backgroundColor = UIColor.systemRed
        emergencyContactButton.setTitleColor(.white, for: .normal)
        emergencyContactButton.titleLabel?.font = Theme.Fonts.buttonLarge
        emergencyContactButton.layer.cornerRadius = 12
        emergencyContactButton.addTarget(self, action: #selector(emergencyContactTapped), for: .touchUpInside)
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(categoriesCollectionView)
        contentView.addSubview(articlesTableView)
        contentView.addSubview(emergencyContactButton)
    }
    
    private func setupCollectionView() {
        categoriesCollectionView.delegate = self
        categoriesCollectionView.dataSource = self
        categoriesCollectionView.register(LegalCategoryCell.self, forCellWithReuseIdentifier: "LegalCategoryCell")
    }
    
    private func setupTableView() {
        articlesTableView.delegate = self
        articlesTableView.dataSource = self
        articlesTableView.register(LegalArticleCell.self, forCellReuseIdentifier: "LegalArticleCell")
    }
    
    // MARK: - Constraints
    
    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        categoriesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        articlesTableView.translatesAutoresizingMaskIntoConstraints = false
        emergencyContactButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            // Categories collection view
            categoriesCollectionView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            categoriesCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            categoriesCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            categoriesCollectionView.heightAnchor.constraint(equalToConstant: 100),
            
            // Articles table view
            articlesTableView.topAnchor.constraint(equalTo: categoriesCollectionView.bottomAnchor, constant: 20),
            articlesTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            articlesTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            articlesTableView.heightAnchor.constraint(equalToConstant: 400),
            
            // Emergency contact button
            emergencyContactButton.topAnchor.constraint(equalTo: articlesTableView.bottomAnchor, constant: 20),
            emergencyContactButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            emergencyContactButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            emergencyContactButton.heightAnchor.constraint(equalToConstant: 50),
            emergencyContactButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        categories = [
            LegalCategory(id: "1", name: "Tenant Rights", icon: "🏠", color: .systemBlue),
            LegalCategory(id: "2", name: "Landlord Issues", icon: "⚖️", color: .systemRed),
            LegalCategory(id: "3", name: "Lease Agreements", icon: "📄", color: .systemGreen),
            LegalCategory(id: "4", name: "Security Deposits", icon: "💰", color: .systemOrange),
            LegalCategory(id: "5", name: "Eviction Protection", icon: "🛡️", color: .systemPurple),
            LegalCategory(id: "6", name: "Subletting", icon: "🔄", color: .systemTeal)
        ]
        
        loadArticlesForCategory(categories.first)
        categoriesCollectionView.reloadData()
    }
    
    private func loadArticlesForCategory(_ category: LegalCategory?) {
        guard let category = category else { return }
        
        selectedCategory = category
        
        switch category.id {
        case "1": // Tenant Rights
            articles = [
                LegalArticle(
                    id: "1",
                    title: "Know Your Rights as a Tenant",
                    summary: "Understanding your basic rights and protections as a renter",
                    content: getTenantRightsContent(),
                    categoryId: "1",
                    readTime: "5 min read",
                    isUrgent: false
                ),
                LegalArticle(
                    id: "2",
                    title: "Habitability Standards",
                    summary: "What your landlord must provide for a livable space",
                    content: getHabitabilityContent(),
                    categoryId: "1",
                    readTime: "3 min read",
                    isUrgent: false
                ),
                LegalArticle(
                    id: "3",
                    title: "Privacy Rights",
                    summary: "When and how your landlord can enter your rental",
                    content: getPrivacyRightsContent(),
                    categoryId: "1",
                    readTime: "4 min read",
                    isUrgent: false
                )
            ]
        case "2": // Landlord Issues
            articles = [
                LegalArticle(
                    id: "4",
                    title: "Dealing with Unresponsive Landlords",
                    summary: "Steps to take when your landlord won't address issues",
                    content: getUnresponsiveLandlordContent(),
                    categoryId: "2",
                    readTime: "6 min read",
                    isUrgent: true
                ),
                LegalArticle(
                    id: "5",
                    title: "Harassment and Discrimination",
                    summary: "Protecting yourself from illegal landlord behavior",
                    content: getHarassmentContent(),
                    categoryId: "2",
                    readTime: "7 min read",
                    isUrgent: true
                )
            ]
        case "3": // Lease Agreements
            articles = [
                LegalArticle(
                    id: "6",
                    title: "Understanding Your Lease",
                    summary: "Key terms and clauses to review before signing",
                    content: getLeaseUnderstandingContent(),
                    categoryId: "3",
                    readTime: "8 min read",
                    isUrgent: false
                ),
                LegalArticle(
                    id: "7",
                    title: "Breaking a Lease Legally",
                    summary: "When and how you can terminate your lease early",
                    content: getBreakingLeaseContent(),
                    categoryId: "3",
                    readTime: "6 min read",
                    isUrgent: false
                )
            ]
        case "4": // Security Deposits
            articles = [
                LegalArticle(
                    id: "8",
                    title: "Getting Your Deposit Back",
                    summary: "How to ensure you receive your full security deposit",
                    content: getDepositBackContent(),
                    categoryId: "4",
                    readTime: "5 min read",
                    isUrgent: false
                )
            ]
        case "5": // Eviction Protection
            articles = [
                LegalArticle(
                    id: "9",
                    title: "Eviction Process and Your Rights",
                    summary: "Understanding the legal eviction process",
                    content: getEvictionProcessContent(),
                    categoryId: "5",
                    readTime: "10 min read",
                    isUrgent: true
                )
            ]
        case "6": // Subletting
            articles = [
                LegalArticle(
                    id: "10",
                    title: "Subletting Legally",
                    summary: "How to sublet your rental without breaking the law",
                    content: getSublettingContent(),
                    categoryId: "6",
                    readTime: "7 min read",
                    isUrgent: false
                )
            ]
        default:
            articles = []
        }
        
        articlesTableView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func emergencyContactTapped() {
        let alert = UIAlertController(title: "Emergency Legal Help", message: "Choose an option:", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Call Tenant Hotline", style: .default) { _ in
            if let url = URL(string: "tel:1-800-TENANT") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Find Legal Aid", style: .default) { _ in
            if let url = URL(string: "https://www.legalaid.org/find-legal-aid") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Contact Local Bar Association", style: .default) { _ in
            if let url = URL(string: "https://www.americanbar.org/groups/legal_services/flh-home/") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Content Methods
    
    private func getTenantRightsContent() -> String {
        return """
        As a tenant, you have several important rights protected by law:
        
        **Right to Habitability**
        - Your rental must be safe and livable
        - Landlord must maintain basic utilities
        - Repairs must be made in reasonable time
        
        **Right to Privacy**
        - Landlord must give proper notice before entering
        - Usually 24-48 hours advance notice required
        - Emergency exceptions apply
        
        **Right to Fair Treatment**
        - Protection from discrimination
        - Right to peaceful enjoyment of property
        - Protection from harassment
        
        **Right to Security Deposit Return**
        - Deposit must be returned within specified timeframe
        - Deductions must be documented
        - Interest may be required in some areas
        
        **What to Do If Rights Are Violated**
        1. Document everything in writing
        2. Keep records of all communications
        3. Know your local tenant laws
        4. Contact tenant rights organizations
        5. Consider legal consultation if needed
        """
    }
    
    private func getHabitabilityContent() -> String {
        return """
        Your landlord is legally required to maintain your rental in habitable condition:
        
        **Essential Services**
        - Heat and hot water
        - Electricity and gas
        - Plumbing and sewage
        - Adequate ventilation
        
        **Safety Requirements**
        - Smoke and carbon monoxide detectors
        - Secure locks and windows
        - Safe electrical systems
        - Structural integrity
        
        **If Conditions Are Unlivable**
        - Document issues with photos/video
        - Notify landlord in writing
        - Give reasonable time for repairs
        - Know your local "repair and deduct" laws
        - Consider withholding rent (check local laws)
        """
    }
    
    private func getPrivacyRightsContent() -> String {
        return """
        You have the right to privacy in your rental unit:
        
        **Notice Requirements**
        - Landlord must give advance notice (usually 24-48 hours)
        - Notice must specify reason for entry
        - Preferred times are usually business hours
        
        **Valid Reasons for Entry**
        - Repairs and maintenance
        - Inspections (reasonable frequency)
        - Showing to prospective tenants/buyers
        - Emergencies (no notice required)
        
        **What You Can Do**
        - Request specific times for visits
        - Be present during inspections if possible
        - Document unauthorized entries
        - Know your state's specific laws
        """
    }
    
    private func getUnresponsiveLandlordContent() -> String {
        return """
        If your landlord is unresponsive to legitimate concerns:
        
        **Steps to Take**
        1. Document all attempts to communicate
        2. Send certified mail with return receipt
        3. Know your local tenant laws
        4. Contact local housing authority
        5. Consider legal action if necessary
        
        **Emergency Situations**
        - Contact local emergency services
        - Document the emergency
        - Make necessary repairs (save receipts)
        - Know your "repair and deduct" rights
        
        **Resources**
        - Tenant rights organizations
        - Local housing authority
        - Legal aid services
        - Small claims court
        """
    }
    
    private func getHarassmentContent() -> String {
        return """
        Landlord harassment and discrimination are illegal:
        
        **Forms of Harassment**
        - Excessive or unannounced visits
        - Threats or intimidation
        - Cutting off utilities
        - Changing locks without notice
        - Refusing reasonable requests
        
        **Protected Classes**
        - Race, color, religion
        - National origin
        - Sex, familial status
        - Disability
        - Age (in some areas)
        
        **What to Do**
        1. Document every incident
        2. Keep detailed records
        3. Report to housing authorities
        4. File complaints with civil rights agencies
        5. Consult with an attorney
        """
    }
    
    private func getLeaseUnderstandingContent() -> String {
        return """
        Key lease terms to review carefully:
        
        **Essential Clauses**
        - Rent amount and due date
        - Lease term and renewal options
        - Security deposit requirements
        - Pet policies
        - Maintenance responsibilities
        
        **Watch Out For**
        - Excessive fees
        - Unusual restrictions
        - Automatic renewal clauses
        - Broad damage definitions
        - Waiver of tenant rights
        
        **Before Signing**
        - Read everything carefully
        - Ask questions about unclear terms
        - Negotiate problematic clauses
        - Get everything in writing
        - Keep copies of all documents
        """
    }
    
    private func getBreakingLeaseContent() -> String {
        return """
        Valid reasons to break a lease legally:
        
        **Legal Reasons**
        - Uninhabitable conditions
        - Landlord harassment
        - Military deployment
        - Domestic violence situations
        - Landlord's breach of lease
        
        **Process**
        1. Review your lease terms
        2. Document the reason
        3. Provide written notice
        4. Follow state-specific procedures
        5. Know your financial obligations
        
        **Minimizing Costs**
        - Help find replacement tenant
        - Negotiate with landlord
        - Understand mitigation duties
        - Consider subletting options
        """
    }
    
    private func getDepositBackContent() -> String {
        return """
        Tips for getting your full security deposit back:
        
        **Before Moving Out**
        - Document current condition with photos
        - Complete all required cleaning
        - Fix any damage you caused
        - Review lease cleaning requirements
        - Schedule final walkthrough
        
        **Know the Law**
        - Time limits for deposit return
        - Valid reasons for deductions
        - Required documentation
        - Interest requirements
        
        **If Deposit Is Wrongfully Kept**
        - Request detailed accounting
        - Dispute unfair charges
        - Know your state's penalty laws
        - Consider small claims court
        """
    }
    
    private func getEvictionProcessContent() -> String {
        return """
        Understanding the eviction process:
        
        **Common Grounds for Eviction**
        - Non-payment of rent
        - Lease violations
        - Illegal activities
        - End of lease term
        - No-fault evictions (where legal)
        
        **The Legal Process**
        1. Notice to quit/cure
        2. Filing of eviction lawsuit
        3. Court hearing
        4. Judgment
        5. Enforcement (if necessary)
        
        **Your Rights**
        - Right to proper notice
        - Right to contest in court
        - Right to legal representation
        - Right to reasonable time to move
        
        **Getting Help**
        - Contact tenant rights organizations
        - Seek legal aid
        - Know your local laws
        - Don't ignore court papers
        """
    }
    
    private func getSublettingContent() -> String {
        return """
        How to sublet legally:
        
        **Check Your Lease**
        - Look for subletting clauses
        - Get written permission if required
        - Understand restrictions
        - Know your ongoing responsibilities
        
        **Legal Requirements**
        - Follow local subletting laws
        - Screen potential subtenants
        - Create written subletting agreement
        - Collect appropriate deposits
        
        **Protecting Yourself**
        - Stay responsible to original landlord
        - Maintain insurance coverage
        - Keep communication open
        - Document everything
        
        **If Problems Arise**
        - Know eviction procedures for subtenants
        - Understand your liability
        - Keep landlord informed
        - Consider mediation services
        """
    }
}

// MARK: - Collection View Delegate & DataSource

extension LegalHelpViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LegalCategoryCell", for: indexPath) as! LegalCategoryCell
        let category = categories[indexPath.item]
        cell.configure(with: category, isSelected: category.id == selectedCategory?.id)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 80, height: 100)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let category = categories[indexPath.item]
        loadArticlesForCategory(category)
        collectionView.reloadData()
    }
}

// MARK: - Table View Delegate & DataSource

extension LegalHelpViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return articles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LegalArticleCell", for: indexPath) as! LegalArticleCell
        let article = articles[indexPath.row]
        cell.configure(with: article)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let article = articles[indexPath.row]
        
        // TODO: Implement LegalArticleDetailViewController
        let alert = UIAlertController(title: "Article Details", message: "Article: \(article.title)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Data Models

struct LegalCategory {
    let id: String
    let name: String
    let icon: String
    let color: UIColor
}

struct LegalArticle {
    let id: String
    let title: String
    let summary: String
    let content: String
    let categoryId: String
    let readTime: String
    let isUrgent: Bool
}

// MARK: - Custom Cells

class LegalCategoryCell: UICollectionViewCell {
    private let iconLabel = UILabel()
    private let nameLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = Theme.Colors.cardBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 4
        
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        iconLabel.textAlignment = .center
        
        nameLabel.font = Theme.Fonts.caption1
        nameLabel.textColor = Theme.Colors.textPrimary
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        
        addSubview(iconLabel)
        addSubview(nameLabel)
        
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconLabel.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            iconLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with category: LegalCategory, isSelected: Bool) {
        iconLabel.text = category.icon
        nameLabel.text = category.name
        
        if isSelected {
            backgroundColor = category.color.withAlphaComponent(0.2)
            layer.borderWidth = 2
            layer.borderColor = category.color.cgColor
        } else {
            backgroundColor = Theme.Colors.cardBackground
            layer.borderWidth = 0
        }
    }
}

class LegalArticleCell: UITableViewCell {
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let readTimeLabel = UILabel()
    private let urgentIndicator = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = Theme.Colors.background
        selectionStyle = .none
        
        containerView.backgroundColor = Theme.Colors.cardBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowRadius = 4
        
        titleLabel.font = Theme.Fonts.headline
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.numberOfLines = 2
        
        summaryLabel.font = Theme.Fonts.subheadline
        summaryLabel.textColor = Theme.Colors.textSecondary
        summaryLabel.numberOfLines = 2
        
        readTimeLabel.font = Theme.Fonts.caption1
        readTimeLabel.textColor = Theme.Colors.textTertiary
        
        urgentIndicator.backgroundColor = UIColor.systemRed
        urgentIndicator.layer.cornerRadius = 4
        urgentIndicator.isHidden = true
        
        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(summaryLabel)
        containerView.addSubview(readTimeLabel)
        containerView.addSubview(urgentIndicator)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        readTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        urgentIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            urgentIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 15),
            urgentIndicator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            urgentIndicator.widthAnchor.constraint(equalToConstant: 8),
            urgentIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: urgentIndicator.leadingAnchor, constant: -10),
            
            summaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            summaryLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            summaryLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            
            readTimeLabel.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 8),
            readTimeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            readTimeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            readTimeLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -15)
        ])
    }
    
    func configure(with article: LegalArticle) {
        titleLabel.text = article.title
        summaryLabel.text = article.summary
        readTimeLabel.text = article.readTime
        urgentIndicator.isHidden = !article.isUrgent
    }
}