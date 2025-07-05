import UIKit

class ChatViewController: UIViewController {
    
    private let tableView = UITableView()
    private let inputContainerView = UIView()
    private let textView = UITextView()
    private let sendButton = UIButton(type: .system)
    private var messages: [ChatMessage] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupInputView()
        setupTableView()
        loadInitialMessages()
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.backgroundColor
        title = "AI Assistant"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(infoTapped)
        )
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = AppColors.backgroundColor
        tableView.separatorStyle = .none
        tableView.register(ChatMessageCell.self, forCellReuseIdentifier: "ChatMessageCell")
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor)
        ])
    }
    
    private func setupInputView() {
        inputContainerView.backgroundColor = AppColors.cardBackground
        inputContainerView.layer.borderWidth = 1
        inputContainerView.layer.borderColor = AppColors.separatorColor.cgColor
        
        textView.backgroundColor = AppColors.backgroundColor
        textView.layer.cornerRadius = 20
        textView.layer.borderWidth = 1
        textView.layer.borderColor = AppColors.separatorColor.cgColor
        textView.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        textView.textColor = AppColors.textPrimary
        textView.text = "Ask me anything about finding rooms..."
        textView.textColor = AppColors.textSecondary
        textView.delegate = self
        
        sendButton.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        sendButton.backgroundColor = AppColors.primaryPurple
        sendButton.tintColor = .white
        sendButton.layer.cornerRadius = 22
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        
        view.addSubview(inputContainerView)
        inputContainerView.addSubview(textView)
        inputContainerView.addSubview(sendButton)
        
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            inputContainerView.heightAnchor.constraint(equalToConstant: 80),
            
            textView.topAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: inputContainerView.bottomAnchor, constant: -12),
            
            sendButton.centerYAnchor.constraint(equalTo: textView.centerYAnchor),
            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -16),
            sendButton.widthAnchor.constraint(equalToConstant: 44),
            sendButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func loadInitialMessages() {
        messages = [
            ChatMessage(text: "👋 Hello! I'm your AI assistant for finding the perfect room. I can help you with:", isFromUser: false),
            ChatMessage(text: "• Finding rooms based on your preferences\n• Negotiating better prices\n• Answering questions about properties\n• Scheduling viewings", isFromUser: false),
            ChatMessage(text: "What can I help you with today?", isFromUser: false)
        ]
        tableView.reloadData()
    }
    
    @objc private func sendTapped() {
        guard let text = textView.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add user message
        messages.append(ChatMessage(text: text, isFromUser: true))
        textView.text = ""
        
        // Add typing indicator
        tableView.reloadData()
        scrollToBottom()
        
        // Simulate AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.simulateAIResponse(for: text)
        }
    }
    
    private func simulateAIResponse(for userMessage: String) {
        let responses = [
            "I'd be happy to help you find the perfect room! What's your budget range?",
            "Great question! Based on your preferences, I can suggest some properties in your area.",
            "I can help you negotiate a better price. Let me find some comparable listings.",
            "Would you like me to schedule a viewing for you? I can coordinate with the landlord.",
            "I found some great options that match your criteria. Would you like me to show them to you?"
        ]
        
        let randomResponse = responses.randomElement() ?? "Thanks for your message! How else can I assist you?"
        messages.append(ChatMessage(text: randomResponse, isFromUser: false))
        
        tableView.reloadData()
        scrollToBottom()
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    @objc private func infoTapped() {
        let alert = UIAlertController(title: "AI Assistant", message: "Your personal AI assistant powered by advanced machine learning to help you find the perfect room and negotiate the best deals.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension ChatViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == AppColors.textSecondary {
            textView.text = ""
            textView.textColor = AppColors.textPrimary
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Ask me anything about finding rooms..."
            textView.textColor = AppColors.textSecondary
        }
    }
}

extension ChatViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatMessageCell", for: indexPath) as! ChatMessageCell
        cell.configure(with: messages[indexPath.row])
        return cell
    }
}

struct ChatMessage {
    let text: String
    let isFromUser: Bool
}

class ChatMessageCell: UITableViewCell {
    
    private let messageView = UIView()
    private let messageLabel = UILabel()
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        messageView.layer.cornerRadius = 16
        
        messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        messageLabel.numberOfLines = 0
        
        avatarView.layer.cornerRadius = 16
        avatarView.backgroundColor = AppColors.primaryPurple
        
        avatarLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        
        contentView.addSubview(messageView)
        contentView.addSubview(avatarView)
        messageView.addSubview(messageLabel)
        avatarView.addSubview(avatarLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        messageView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            avatarView.widthAnchor.constraint(equalToConstant: 32),
            avatarView.heightAnchor.constraint(equalToConstant: 32),
            
            messageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            messageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            messageLabel.topAnchor.constraint(equalTo: messageView.topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: messageView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: messageView.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: messageView.bottomAnchor, constant: -12),
            
            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor)
        ])
    }
    
    func configure(with message: ChatMessage) {
        messageLabel.text = message.text
        
        if message.isFromUser {
            // User message - right aligned
            messageView.backgroundColor = AppColors.primaryPurple
            messageLabel.textColor = .white
            avatarLabel.text = "You"
            
            NSLayoutConstraint.activate([
                avatarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                messageView.trailingAnchor.constraint(equalTo: avatarView.leadingAnchor, constant: -8),
                messageView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60)
            ])
        } else {
            // AI message - left aligned
            messageView.backgroundColor = AppColors.cardBackground
            messageLabel.textColor = AppColors.textPrimary
            avatarLabel.text = "AI"
            
            NSLayoutConstraint.activate([
                avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                messageView.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 8),
                messageView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -60)
            ])
        }
    }
}