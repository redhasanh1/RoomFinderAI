import UIKit

class ChatViewController: UIViewController {
    
    private let tableView = UITableView()
    private let emptyStateView = EmptyStateView()
    private var conversations: [ChatConversation] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadConversations()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animateTableView()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .compose,
            target: self,
            action: #selector(composeTapped)
        )
        
        // Configure table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ConversationTableViewCell.self, forCellReuseIdentifier: "ConversationCell")
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Configure empty state
        emptyStateView.configure(
            title: "No Messages",
            message: "Start a conversation with property owners",
            imageName: "message"
        )
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    private func loadConversations() {
        guard SessionManager.shared.isSessionValid() else {
            updateEmptyState()
            return
        }
        
        // Use both old and new API services for backward compatibility
        APIService.shared.getConversations { [weak self] result in
            switch result {
            case .success(let conversations):
                self?.conversations = conversations
                self?.tableView.reloadData()
                self?.updateEmptyState()
            case .failure(let error):
                print("Error loading conversations: \(error)")
                // Try with new secure API service
                self?.loadConversationsFromSecureAPI()
            }
        }
    }
    
    private func loadConversationsFromSecureAPI() {
        // This would be implemented when the backend supports the new secure endpoints
        // For now, fallback to sample data
        loadSampleConversations()
    }
    
    private func loadSampleConversations() {
        let sampleUser = User(
            id: "user1",
            email: "owner@example.com",
            firstName: "John",
            lastName: "Smith",
            phone: "555-0123",
            profileImage: nil,
            createdAt: "2024-01-01T00:00:00Z"
        )
        
        let sampleConversation = ChatConversation(
            id: "conv1",
            participantIds: ["user1", "user2"],
            propertyId: "prop1",
            propertyTitle: "Downtown Apartment",
            lastMessage: "Is this property still available?",
            lastMessageTime: "2024-01-08T10:30:00Z",
            unreadCount: 2,
            otherParticipant: sampleUser,
            createdAt: "2024-01-07T15:00:00Z"
        )
        
        conversations = [sampleConversation]
        tableView.reloadData()
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !conversations.isEmpty
        tableView.isHidden = conversations.isEmpty
    }
    
    private func animateTableView() {
        guard !conversations.isEmpty else { return }
        
        tableView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.tableView.alpha = 1
        }
        
        let cells = tableView.visibleCells
        for (index, cell) in cells.enumerated() {
            cell.transform = CGAffineTransform(translationX: -50, y: 0)
            cell.alpha = 0
            
            UIView.animate(withDuration: 0.4, delay: Double(index) * 0.05, options: .curveEaseOut) {
                cell.transform = .identity
                cell.alpha = 1
            }
        }
    }
    
    @objc private func composeTapped() {
        // Present compose view
        let composeVC = ComposeMessageViewController()
        let navController = UINavigationController(rootViewController: composeVC)
        present(navController, animated: true)
    }
}

// MARK: - Table View Data Source & Delegate
extension ChatViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ConversationCell", for: indexPath) as! ConversationTableViewCell
        if indexPath.row < conversations.count {
            cell.configure(with: conversations[indexPath.row])
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let conversation = conversations[indexPath.row]
        let chatDetailVC = ChatDetailViewController()
        chatDetailVC.conversation = conversation
        navigationController?.pushViewController(chatDetailVC, animated: true)
    }
}

// MARK: - Conversation Table View Cell
class ConversationTableViewCell: UITableViewCell {
    private let containerView = UIView()
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let messageLabel = UILabel()
    private let timestampLabel = UILabel()
    private let unreadIndicator = UIView()
    private let propertyLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        containerView.backgroundColor = .systemBackground
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Avatar
        avatarView.backgroundColor = .systemBlue
        avatarView.layer.cornerRadius = 25
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(avatarView)
        
        avatarLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarView.addSubview(avatarLabel)
        
        // Name
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(nameLabel)
        
        // Message
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 1
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(messageLabel)
        
        // Timestamp
        timestampLabel.font = .systemFont(ofSize: 12)
        timestampLabel.textColor = .tertiaryLabel
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(timestampLabel)
        
        // Unread indicator
        unreadIndicator.backgroundColor = .systemBlue
        unreadIndicator.layer.cornerRadius = 6
        unreadIndicator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(unreadIndicator)
        
        // Property label
        propertyLabel.font = .systemFont(ofSize: 12)
        propertyLabel.textColor = .systemBlue
        propertyLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(propertyLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            avatarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            avatarView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 50),
            avatarView.heightAnchor.constraint(equalToConstant: 50),
            
            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            
            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: timestampLabel.leadingAnchor, constant: -8),
            
            messageLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            messageLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: unreadIndicator.leadingAnchor, constant: -8),
            
            propertyLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            propertyLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 2),
            propertyLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            
            timestampLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            timestampLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            
            unreadIndicator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            unreadIndicator.centerYAnchor.constraint(equalTo: messageLabel.centerYAnchor),
            unreadIndicator.widthAnchor.constraint(equalToConstant: 12),
            unreadIndicator.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    func configure(with conversation: ChatConversation) {
        if let participant = conversation.otherParticipant {
            nameLabel.text = "\(participant.firstName) \(participant.lastName)"
            avatarLabel.text = String(participant.firstName.prefix(1))
        } else {
            nameLabel.text = "Unknown User"
            avatarLabel.text = "?"
        }
        
        messageLabel.text = conversation.lastMessage ?? "No messages yet"
        propertyLabel.text = conversation.propertyTitle ?? ""
        
        // Format timestamp
        if let lastMessageTime = conversation.lastMessageTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            if let date = formatter.date(from: lastMessageTime) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .short
                displayFormatter.timeStyle = .short
                timestampLabel.text = displayFormatter.string(from: date)
            } else {
                timestampLabel.text = "Now"
            }
        } else {
            timestampLabel.text = "Now"
        }
        
        // Show/hide unread indicator
        unreadIndicator.isHidden = conversation.unreadCount == 0
    }
}

// MARK: - Compose Message View Controller
class ComposeMessageViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "New Message"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}

// MARK: - Chat Detail View Controller
class ChatDetailViewController: UIViewController {
    
    var conversation: ChatConversation?
    
    private let tableView = UITableView()
    private let messageInputContainer = UIView()
    private let messageTextField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let attachmentButton = UIButton(type: .system)
    
    private var messages: [ChatMessage] = []
    private var bottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupKeyboardHandling()
        loadMessages()
        
        if let conversation = conversation {
            title = conversation.otherParticipant?.firstName ?? "Chat"
            
            // Mark messages as read
            APIService.shared.markMessagesAsRead(conversationId: conversation.id) { result in
                if case .failure(let error) = result {
                    print("Error marking messages as read: \(error)")
                }
            }
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Configure table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ChatMessageCell.self, forCellReuseIdentifier: "MessageCell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Configure message input container
        messageInputContainer.backgroundColor = .systemBackground
        messageInputContainer.layer.borderWidth = 1
        messageInputContainer.layer.borderColor = UIColor.systemGray4.cgColor
        messageInputContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageInputContainer)
        
        // Configure attachment button
        attachmentButton.setImage(UIImage(systemName: "paperclip"), for: .normal)
        attachmentButton.tintColor = Theme.Colors.primary
        attachmentButton.translatesAutoresizingMaskIntoConstraints = false
        messageInputContainer.addSubview(attachmentButton)
        
        // Configure message text field
        messageTextField.placeholder = "Type a message..."
        messageTextField.borderStyle = .roundedRect
        messageTextField.backgroundColor = .systemGray6
        messageTextField.delegate = self
        messageTextField.translatesAutoresizingMaskIntoConstraints = false
        messageInputContainer.addSubview(messageTextField)
        
        // Configure send button
        sendButton.setTitle("Send", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.backgroundColor = Theme.Colors.primary
        sendButton.layer.cornerRadius = 18
        sendButton.titleLabel?.font = Theme.Fonts.callout
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        messageInputContainer.addSubview(sendButton)
        
        updateSendButtonState()
    }
    
    private func setupConstraints() {
        bottomConstraint = messageInputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: messageInputContainer.topAnchor),
            
            messageInputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            messageInputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            messageInputContainer.heightAnchor.constraint(equalToConstant: 60),
            bottomConstraint,
            
            attachmentButton.leadingAnchor.constraint(equalTo: messageInputContainer.leadingAnchor, constant: 12),
            attachmentButton.centerYAnchor.constraint(equalTo: messageInputContainer.centerYAnchor),
            attachmentButton.widthAnchor.constraint(equalToConstant: 30),
            attachmentButton.heightAnchor.constraint(equalToConstant: 30),
            
            messageTextField.leadingAnchor.constraint(equalTo: attachmentButton.trailingAnchor, constant: 8),
            messageTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            messageTextField.centerYAnchor.constraint(equalTo: messageInputContainer.centerYAnchor),
            messageTextField.heightAnchor.constraint(equalToConstant: 36),
            
            sendButton.trailingAnchor.constraint(equalTo: messageInputContainer.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: messageInputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60),
            sendButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func loadMessages() {
        guard let conversation = conversation else { return }
        
        APIService.shared.getMessages(conversationId: conversation.id) { [weak self] result in
            switch result {
            case .success(let messages):
                self?.messages = messages
                self?.tableView.reloadData()
                self?.scrollToBottom()
            case .failure(let error):
                print("Error loading messages: \(error)")
                self?.loadSampleMessages()
            }
        }
    }
    
    private func loadSampleMessages() {
        let sampleMessage1 = ChatMessage(
            id: "msg1",
            conversationId: conversation?.id ?? "",
            senderId: "user1",
            receiverId: "user2",
            content: "Hi! I'm interested in this property. Is it still available?",
            messageType: "text",
            timestamp: "2024-01-08T10:30:00Z",
            isRead: true,
            senderName: "John Smith",
            propertyId: conversation?.propertyId
        )
        
        let sampleMessage2 = ChatMessage(
            id: "msg2",
            conversationId: conversation?.id ?? "",
            senderId: "user2",
            receiverId: "user1",
            content: "Yes, it's still available! Would you like to schedule a viewing?",
            messageType: "text",
            timestamp: "2024-01-08T10:32:00Z",
            isRead: true,
            senderName: "Current User",
            propertyId: conversation?.propertyId
        )
        
        messages = [sampleMessage1, sampleMessage2]
        tableView.reloadData()
        scrollToBottom()
    }
    
    @objc private func sendMessage() {
        guard let conversation = conversation,
              let messageText = messageTextField.text,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        messageTextField.text = ""
        updateSendButtonState()
        
        APIService.shared.sendMessage(conversationId: conversation.id, content: messageText) { [weak self] result in
            switch result {
            case .success(let message):
                self?.messages.append(message)
                self?.tableView.reloadData()
                self?.scrollToBottom()
            case .failure(let error):
                print("Error sending message: \(error)")
                // Show error alert
                let alert = UIAlertController(title: "Error", message: "Failed to send message", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
    
    private func updateSendButtonState() {
        let hasText = !(messageTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        sendButton.isEnabled = hasText
        sendButton.backgroundColor = hasText ? Theme.Colors.primary : Theme.Colors.primary.withAlphaComponent(0.5)
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        
        DispatchQueue.main.async {
            let indexPath = IndexPath(row: self.messages.count - 1, section: 0)
            self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardHeight = keyboardFrame.cgRectValue.height
            bottomConstraint.constant = -keyboardHeight
            
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
            
            scrollToBottom()
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        bottomConstraint.constant = 0
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - ChatDetailViewController Extensions
extension ChatDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! ChatMessageCell
        cell.configure(with: messages[indexPath.row])
        return cell
    }
}

extension ChatDetailViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        DispatchQueue.main.async {
            self.updateSendButtonState()
        }
        return true
    }
}

// MARK: - Chat Message Cell
class ChatMessageCell: UITableViewCell {
    private let messageContainer = UIView()
    private let messageLabel = UILabel()
    private let timestampLabel = UILabel()
    private let senderLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        messageContainer.layer.cornerRadius = 12
        messageContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(messageContainer)
        
        messageLabel.numberOfLines = 0
        messageLabel.font = Theme.Fonts.body
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageContainer.addSubview(messageLabel)
        
        timestampLabel.font = Theme.Fonts.caption2
        timestampLabel.textColor = .secondaryLabel
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timestampLabel)
        
        senderLabel.font = Theme.Fonts.caption1
        senderLabel.textColor = .secondaryLabel
        senderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(senderLabel)
    }
    
    func configure(with message: ChatMessage) {
        messageLabel.text = message.content
        senderLabel.text = message.senderName
        
        // Format timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        if let date = formatter.date(from: message.timestamp) {
            let displayFormatter = DateFormatter()
            displayFormatter.timeStyle = .short
            timestampLabel.text = displayFormatter.string(from: date)
        } else {
            timestampLabel.text = "Now"
        }
        
        // Configure message appearance based on sender
        let isCurrentUser = message.senderId == SessionManager.shared.getCurrentUser()?.id
        
        if isCurrentUser {
            // Sent message (right side)
            messageContainer.backgroundColor = Theme.Colors.primary
            messageLabel.textColor = .white
            
            NSLayoutConstraint.activate([
                messageContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                messageContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                messageContainer.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60),
                
                messageLabel.topAnchor.constraint(equalTo: messageContainer.topAnchor, constant: 8),
                messageLabel.leadingAnchor.constraint(equalTo: messageContainer.leadingAnchor, constant: 12),
                messageLabel.trailingAnchor.constraint(equalTo: messageContainer.trailingAnchor, constant: -12),
                messageLabel.bottomAnchor.constraint(equalTo: messageContainer.bottomAnchor, constant: -8),
                
                timestampLabel.topAnchor.constraint(equalTo: messageContainer.bottomAnchor, constant: 4),
                timestampLabel.trailingAnchor.constraint(equalTo: messageContainer.trailingAnchor),
                timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
            ])
        } else {
            // Received message (left side)
            messageContainer.backgroundColor = .systemGray5
            messageLabel.textColor = .label
            
            NSLayoutConstraint.activate([
                messageContainer.topAnchor.constraint(equalTo: senderLabel.bottomAnchor, constant: 4),
                messageContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                messageContainer.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -60),
                
                senderLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                senderLabel.leadingAnchor.constraint(equalTo: messageContainer.leadingAnchor),
                
                messageLabel.topAnchor.constraint(equalTo: messageContainer.topAnchor, constant: 8),
                messageLabel.leadingAnchor.constraint(equalTo: messageContainer.leadingAnchor, constant: 12),
                messageLabel.trailingAnchor.constraint(equalTo: messageContainer.trailingAnchor, constant: -12),
                messageLabel.bottomAnchor.constraint(equalTo: messageContainer.bottomAnchor, constant: -8),
                
                timestampLabel.topAnchor.constraint(equalTo: messageContainer.bottomAnchor, constant: 4),
                timestampLabel.leadingAnchor.constraint(equalTo: messageContainer.leadingAnchor),
                timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
            ])
        }
    }
}