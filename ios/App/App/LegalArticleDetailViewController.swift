import UIKit

class LegalArticleDetailViewController: UIViewController {
    
    // MARK: - Properties
    var article: LegalArticle?
    
    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let readTimeLabel = UILabel()
    private let urgentBadge = UIView()
    private let urgentLabel = UILabel()
    private let contentLabel = UILabel()
    private let shareButton = UIButton(type: .system)
    private let bookmarkButton = UIButton(type: .system)
    private let helpButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        configureContent()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = Theme.backgroundColor
        
        // Configure navigation
        navigationItem.largeTitleDisplayMode = .never
        
        // Configure scroll view
        scrollView.backgroundColor = Theme.backgroundColor
        scrollView.showsVerticalScrollIndicator = false
        
        // Configure content view
        contentView.backgroundColor = Theme.backgroundColor
        
        // Configure title
        titleLabel.font = Theme.boldFont(size: 24)
        titleLabel.textColor = Theme.textColor
        titleLabel.numberOfLines = 0
        
        // Configure read time
        readTimeLabel.font = Theme.regularFont(size: 14)
        readTimeLabel.textColor = Theme.secondaryTextColor
        
        // Configure urgent badge
        urgentBadge.backgroundColor = UIColor.systemRed
        urgentBadge.layer.cornerRadius = 12
        urgentBadge.isHidden = true
        
        urgentLabel.text = "URGENT"
        urgentLabel.font = Theme.boldFont(size: 10)
        urgentLabel.textColor = .white
        urgentLabel.textAlignment = .center
        
        // Configure content
        contentLabel.font = Theme.regularFont(size: 16)
        contentLabel.textColor = Theme.textColor
        contentLabel.numberOfLines = 0
        contentLabel.lineBreakMode = .byWordWrapping
        
        // Configure buttons
        configureActionButton(shareButton, title: "Share Article", color: Theme.primaryColor)
        configureActionButton(bookmarkButton, title: "Bookmark", color: Theme.secondaryColor)
        configureActionButton(helpButton, title: "Get Legal Help", color: UIColor.systemRed)
        
        shareButton.addTarget(self, action: #selector(shareArticle), for: .touchUpInside)
        bookmarkButton.addTarget(self, action: #selector(bookmarkArticle), for: .touchUpInside)
        helpButton.addTarget(self, action: #selector(getLegalHelp), for: .touchUpInside)
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(readTimeLabel)
        contentView.addSubview(urgentBadge)
        urgentBadge.addSubview(urgentLabel)
        contentView.addSubview(contentLabel)
        contentView.addSubview(shareButton)
        contentView.addSubview(bookmarkButton)
        contentView.addSubview(helpButton)
    }
    
    private func configureActionButton(_ button: UIButton, title: String, color: UIColor) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = color
        button.titleLabel?.font = Theme.boldFont(size: 16)
        button.layer.cornerRadius = 12
    }
    
    // MARK: - Constraints
    
    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        readTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        urgentBadge.translatesAutoresizingMaskIntoConstraints = false
        urgentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        bookmarkButton.translatesAutoresizingMaskIntoConstraints = false
        helpButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            
            // Read time
            readTimeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            readTimeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            // Urgent badge
            urgentBadge.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            urgentBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            urgentBadge.widthAnchor.constraint(equalToConstant: 60),
            urgentBadge.heightAnchor.constraint(equalToConstant: 24),
            
            // Urgent label
            urgentLabel.centerXAnchor.constraint(equalTo: urgentBadge.centerXAnchor),
            urgentLabel.centerYAnchor.constraint(equalTo: urgentBadge.centerYAnchor),
            
            // Content
            contentLabel.topAnchor.constraint(equalTo: readTimeLabel.bottomAnchor, constant: 30),
            contentLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Share button
            shareButton.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 40),
            shareButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            shareButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            shareButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Bookmark button
            bookmarkButton.topAnchor.constraint(equalTo: shareButton.bottomAnchor, constant: 15),
            bookmarkButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            bookmarkButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Help button
            helpButton.topAnchor.constraint(equalTo: bookmarkButton.bottomAnchor, constant: 15),
            helpButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            helpButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            helpButton.heightAnchor.constraint(equalToConstant: 50),
            helpButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Configuration
    
    private func configureContent() {
        guard let article = article else { return }
        
        titleLabel.text = article.title
        readTimeLabel.text = article.readTime
        urgentBadge.isHidden = !article.isUrgent
        
        // Format content with markdown-like styling
        let formattedContent = formatContent(article.content)
        contentLabel.attributedText = formattedContent
    }
    
    private func formatContent(_ content: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            if line.isEmpty {
                attributedString.append(NSAttributedString(string: "\n"))
                continue
            }
            
            if line.hasPrefix("**") && line.hasSuffix("**") {
                // Bold headers
                let text = String(line.dropFirst(2).dropLast(2))
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: Theme.boldFont(size: 18),
                    .foregroundColor: Theme.textColor
                ]
                attributedString.append(NSAttributedString(string: text + "\n", attributes: attributes))
            } else if line.hasPrefix("- ") {
                // Bullet points
                let text = String(line.dropFirst(2))
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: Theme.regularFont(size: 16),
                    .foregroundColor: Theme.textColor
                ]
                attributedString.append(NSAttributedString(string: "• " + text + "\n", attributes: attributes))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                // Empty line
                attributedString.append(NSAttributedString(string: "\n"))
            } else {
                // Regular text
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: Theme.regularFont(size: 16),
                    .foregroundColor: Theme.textColor
                ]
                attributedString.append(NSAttributedString(string: line + "\n", attributes: attributes))
            }
        }
        
        // Add paragraph spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8
        
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedString.length))
        
        return attributedString
    }
    
    // MARK: - Actions
    
    @objc private func shareArticle() {
        guard let article = article else { return }
        
        let shareText = """
        \(article.title)
        
        \(article.summary)
        
        Read more legal resources on RoomFinderAI
        """
        
        let activityViewController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = shareButton
            popoverController.sourceRect = shareButton.bounds
        }
        
        present(activityViewController, animated: true)
    }
    
    @objc private func bookmarkArticle() {
        guard let article = article else { return }
        
        // Save to UserDefaults for now (in a real app, save to Core Data or server)
        var bookmarkedArticles = UserDefaults.standard.array(forKey: "bookmarked_articles") as? [String] ?? []
        
        if bookmarkedArticles.contains(article.id) {
            bookmarkedArticles.removeAll { $0 == article.id }
            bookmarkButton.setTitle("Bookmark", for: .normal)
            bookmarkButton.backgroundColor = Theme.secondaryColor
            showAlert(title: "Removed", message: "Article removed from bookmarks")
        } else {
            bookmarkedArticles.append(article.id)
            bookmarkButton.setTitle("Bookmarked ✓", for: .normal)
            bookmarkButton.backgroundColor = UIColor.systemGreen
            showAlert(title: "Saved", message: "Article saved to bookmarks")
        }
        
        UserDefaults.standard.set(bookmarkedArticles, forKey: "bookmarked_articles")
    }
    
    @objc private func getLegalHelp() {
        let alert = UIAlertController(title: "Get Legal Help", message: "Choose how you'd like to get help:", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Find Legal Aid Near Me", style: .default) { _ in
            if let url = URL(string: "https://www.legalaid.org/find-legal-aid") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Contact Tenant Hotline", style: .default) { _ in
            if let url = URL(string: "tel:1-800-TENANT") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Schedule Consultation", style: .default) { _ in
            self.showConsultationForm()
        })
        
        alert.addAction(UIAlertAction(title: "Emergency Legal Help", style: .destructive) { _ in
            self.showEmergencyHelp()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = helpButton
            popoverController.sourceRect = helpButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func showConsultationForm() {
        let alert = UIAlertController(title: "Schedule Consultation", message: "We'll connect you with a legal professional", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Your Name"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Phone Number"
            textField.keyboardType = .phonePad
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Brief Description of Issue"
        }
        
        alert.addAction(UIAlertAction(title: "Submit Request", style: .default) { _ in
            // In a real app, this would send the request to your backend
            self.showAlert(title: "Request Submitted", message: "A legal professional will contact you within 24 hours.")
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showEmergencyHelp() {
        let alert = UIAlertController(title: "Emergency Legal Help", message: "If you're facing immediate legal issues:", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Call Emergency Hotline", style: .destructive) { _ in
            if let url = URL(string: "tel:911") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Tenant Emergency Line", style: .default) { _ in
            if let url = URL(string: "tel:1-800-TENANT") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Find Emergency Legal Aid", style: .default) { _ in
            if let url = URL(string: "https://www.legalaid.org/find-legal-aid") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Update bookmark button state
        guard let article = article else { return }
        let bookmarkedArticles = UserDefaults.standard.array(forKey: "bookmarked_articles") as? [String] ?? []
        
        if bookmarkedArticles.contains(article.id) {
            bookmarkButton.setTitle("Bookmarked ✓", for: .normal)
            bookmarkButton.backgroundColor = UIColor.systemGreen
        } else {
            bookmarkButton.setTitle("Bookmark", for: .normal)
            bookmarkButton.backgroundColor = Theme.secondaryColor
        }
    }
}