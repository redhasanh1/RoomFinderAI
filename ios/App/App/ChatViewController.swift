import UIKit

class ChatViewController: UIViewController {
    
    private let tableView = UITableView()
    private let inputContainerView = UIView()
    private let textView = UITextView()
    private let sendButton = UIButton(type: .system)
    private let voiceButton = UIButton(type: .system)
    private let attachmentButton = UIButton(type: .system)
    private var messages: [ChatMessage] = []
    
    // AI Features
    private var isTyping = false
    private let typingIndicator = UIActivityIndicatorView(style: .medium)
    
    // Quick suggestions
    private let quickSuggestionsView = UIView()
    private let suggestionsScrollView = UIScrollView()
    private let suggestionsStackView = UIStackView()
    
    // Voice recording
    private var isRecording = false
    private var recordingTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupQuickSuggestions()
        setupInputView()
        setupTableView()
        loadInitialMessages()
        setupKeyboardObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.backgroundColor
        title = "AI Assistant"
        
        // Navigation buttons
        let infoButton = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(infoTapped)
        )
        
        let clearButton = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(clearChatTapped)
        )
        
        navigationItem.rightBarButtonItems = [infoButton, clearButton]
        
        // Typing indicator setup
        typingIndicator.color = AppColors.primaryPurple
        typingIndicator.hidesWhenStopped = true
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
            tableView.topAnchor.constraint(equalTo: quickSuggestionsView.bottomAnchor),
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
        
        // Send button
        sendButton.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        sendButton.backgroundColor = AppColors.primaryPurple
        sendButton.tintColor = .white
        sendButton.layer.cornerRadius = 22
        sendButton.layer.shadowColor = UIColor.black.cgColor
        sendButton.layer.shadowOpacity = 0.2
        sendButton.layer.shadowOffset = CGSize(width: 0, y: 2)
        sendButton.layer.shadowRadius = 4
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        
        // Voice button
        voiceButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        voiceButton.setImage(UIImage(systemName: "stop.circle.fill"), for: .selected)
        voiceButton.backgroundColor = AppColors.accentBlue
        voiceButton.tintColor = .white
        voiceButton.layer.cornerRadius = 22
        voiceButton.layer.shadowColor = UIColor.black.cgColor
        voiceButton.layer.shadowOpacity = 0.2
        voiceButton.layer.shadowOffset = CGSize(width: 0, y: 2)
        voiceButton.layer.shadowRadius = 4
        voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)
        
        // Attachment button
        attachmentButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        attachmentButton.backgroundColor = AppColors.successGreen
        attachmentButton.tintColor = .white
        attachmentButton.layer.cornerRadius = 22
        attachmentButton.layer.shadowColor = UIColor.black.cgColor
        attachmentButton.layer.shadowOpacity = 0.2
        attachmentButton.layer.shadowOffset = CGSize(width: 0, y: 2)
        attachmentButton.layer.shadowRadius = 4
        attachmentButton.addTarget(self, action: #selector(attachmentTapped), for: .touchUpInside)
        
        view.addSubview(inputContainerView)
        inputContainerView.addSubview(textView)
        inputContainerView.addSubview(sendButton)
        inputContainerView.addSubview(voiceButton)
        inputContainerView.addSubview(attachmentButton)
        inputContainerView.addSubview(typingIndicator)
        
        [inputContainerView, textView, sendButton, voiceButton, attachmentButton, typingIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            inputContainerView.heightAnchor.constraint(equalToConstant: 80),
            
            textView.topAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: attachmentButton.trailingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: voiceButton.leadingAnchor, constant: -8),
            textView.bottomAnchor.constraint(equalTo: inputContainerView.bottomAnchor, constant: -12),
            
            attachmentButton.centerYAnchor.constraint(equalTo: textView.centerYAnchor),
            attachmentButton.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 16),
            attachmentButton.widthAnchor.constraint(equalToConstant: 44),
            attachmentButton.heightAnchor.constraint(equalToConstant: 44),
            
            voiceButton.centerYAnchor.constraint(equalTo: textView.centerYAnchor),
            voiceButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            voiceButton.widthAnchor.constraint(equalToConstant: 44),
            voiceButton.heightAnchor.constraint(equalToConstant: 44),
            
            sendButton.centerYAnchor.constraint(equalTo: textView.centerYAnchor),
            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -16),
            sendButton.widthAnchor.constraint(equalToConstant: 44),
            sendButton.heightAnchor.constraint(equalToConstant: 44),
            
            typingIndicator.centerXAnchor.constraint(equalTo: inputContainerView.centerXAnchor),
            typingIndicator.topAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: 8)
        ])
    }
    
    private func setupQuickSuggestions() {
        quickSuggestionsView.backgroundColor = AppColors.backgroundColor
        
        suggestionsScrollView.showsHorizontalScrollIndicator = false
        suggestionsStackView.axis = .horizontal
        suggestionsStackView.spacing = 12
        suggestionsStackView.distribution = .fill
        
        let suggestions = ["Find 1BR under $2000", "Pet-friendly places", "Near subway", "Negotiate price", "Schedule tour"]
        
        for suggestion in suggestions {
            let button = createSuggestionButton(title: suggestion)
            suggestionsStackView.addArrangedSubview(button)
        }
        
        quickSuggestionsView.addSubview(suggestionsScrollView)
        suggestionsScrollView.addSubview(suggestionsStackView)
        view.addSubview(quickSuggestionsView)
        
        [quickSuggestionsView, suggestionsScrollView, suggestionsStackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            quickSuggestionsView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            quickSuggestionsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            quickSuggestionsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            quickSuggestionsView.heightAnchor.constraint(equalToConstant: 60),
            
            suggestionsScrollView.topAnchor.constraint(equalTo: quickSuggestionsView.topAnchor, constant: 8),
            suggestionsScrollView.leadingAnchor.constraint(equalTo: quickSuggestionsView.leadingAnchor),
            suggestionsScrollView.trailingAnchor.constraint(equalTo: quickSuggestionsView.trailingAnchor),
            suggestionsScrollView.bottomAnchor.constraint(equalTo: quickSuggestionsView.bottomAnchor, constant: -8),
            
            suggestionsStackView.topAnchor.constraint(equalTo: suggestionsScrollView.topAnchor),
            suggestionsStackView.leadingAnchor.constraint(equalTo: suggestionsScrollView.leadingAnchor, constant: 16),
            suggestionsStackView.trailingAnchor.constraint(equalTo: suggestionsScrollView.trailingAnchor, constant: -16),
            suggestionsStackView.bottomAnchor.constraint(equalTo: suggestionsScrollView.bottomAnchor),
            suggestionsStackView.heightAnchor.constraint(equalTo: suggestionsScrollView.heightAnchor)
        ])
    }
    
    private func createSuggestionButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(AppColors.primaryPurple, for: .normal)
        button.backgroundColor = AppColors.cardBackground
        button.layer.cornerRadius = 20
        button.layer.borderWidth = 1
        button.layer.borderColor = AppColors.primaryPurple.withAlphaComponent(0.3).cgColor
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        button.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    private func setupKeyboardObservers() {
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
    
    private func loadInitialMessages() {
        messages = [
            ChatMessage(text: "🤖 Hello! I'm your AI-powered real estate assistant. I can help you with:", isFromUser: false),
            ChatMessage(text: "🏠 Finding perfect rooms based on your budget & preferences\n💰 Negotiating better rental prices\n📅 Scheduling property viewings\n📊 Market analysis & insights\n🗣️ Voice commands & smart search", isFromUser: false),
            ChatMessage(text: "Try asking me something like 'Find me a 1-bedroom under $2000' or tap a suggestion above!", isFromUser: false)
        ]
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.scrollToBottom()
        }
    }
    
    @objc private func sendTapped() {
        guard let text = textView.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Add user message
        messages.append(ChatMessage(text: text, isFromUser: true))
        textView.text = ""
        textView.textColor = AppColors.textSecondary
        textView.text = "Ask me anything about finding rooms..."
        
        // Show typing indicator
        showTypingIndicator()
        
        // Reload table and scroll
        tableView.reloadData()
        scrollToBottom()
        
        // Simulate AI response with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.5...3.0)) {
            self.hideTypingIndicator()
            self.simulateAIResponse(for: text)
        }
    }
    
    @objc private func suggestionTapped(_ sender: UIButton) {
        guard let suggestion = sender.titleLabel?.text else { return }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Animate button
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = .identity
            }
        }
        
        // Add message and process
        messages.append(ChatMessage(text: suggestion, isFromUser: true))
        showTypingIndicator()
        tableView.reloadData()
        scrollToBottom()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.hideTypingIndicator()
            self.simulateAIResponse(for: suggestion)
        }
    }
    
    @objc private func voiceTapped() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        isRecording.toggle()
        voiceButton.isSelected = isRecording
        
        if isRecording {
            startVoiceRecording()
        } else {
            stopVoiceRecording()
        }
    }
    
    @objc private func attachmentTapped() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        let actionSheet = UIAlertController(title: "Share Property Info", message: "What would you like to share?", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "📷 Take Photo", style: .default) { _ in
            self.showCamera()
        })
        
        actionSheet.addAction(UIAlertAction(title: "📱 Share Screenshot", style: .default) { _ in
            self.shareScreenshot()
        })
        
        actionSheet.addAction(UIAlertAction(title: "📍 Share Location", style: .default) { _ in
            self.shareLocation()
        })
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = attachmentButton
            popover.sourceRect = attachmentButton.bounds
        }
        
        present(actionSheet, animated: true)
    }
    
    @objc private func clearChatTapped() {
        let alert = UIAlertController(title: "Clear Chat", message: "Are you sure you want to clear all messages?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            self.messages.removeAll()
            self.loadInitialMessages()
            
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        UIView.animate(withDuration: 0.3) {
            self.view.transform = CGAffineTransform(translationX: 0, y: -keyboardHeight + self.view.safeAreaInsets.bottom)
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        UIView.animate(withDuration: 0.3) {
            self.view.transform = .identity
        }
    }
    
    private func simulateAIResponse(for userMessage: String) {
        let message = userMessage.lowercased()
        var response: String
        
        // Smart AI responses based on keywords
        if message.contains("find") || message.contains("looking") || message.contains("search") {
            if message.contains("1br") || message.contains("1 bed") {
                response = "🏠 I found 12 one-bedroom apartments that match your criteria! Here are the top options:\n\n1. Modern Studio in Manhattan - $1,800/mo\n2. Cozy 1BR in Brooklyn - $1,400/mo\n3. Pet-friendly 1BR in Queens - $1,200/mo\n\nWould you like me to show you details for any of these?"
            } else if message.contains("under") && message.contains("2000") {
                response = "💰 Perfect! I found 8 properties under $2,000/month in your preferred areas. The average rent is $1,650. Would you like me to filter by specific neighborhoods or amenities?"
            } else {
                response = "🔍 I'm searching through our database of 500+ verified properties. To help narrow down the best options, could you tell me:\n\n• Your budget range\n• Preferred neighborhoods\n• Number of bedrooms\n• Must-have amenities"
            }
        } else if message.contains("negotiate") || message.contains("price") || message.contains("lower") {
            response = "💬 I can definitely help you negotiate! Based on market analysis, properties in this area typically have 5-10% negotiation room. I'll prepare a compelling offer with:\n\n• Market comparison data\n• Your strong tenant profile\n• Flexible move-in terms\n\nShall I draft a proposal?"
        } else if message.contains("schedule") || message.contains("tour") || message.contains("viewing") {
            response = "📅 I'll help you schedule viewings! I can coordinate with landlords to set up:\n\n• Individual property tours\n• Group viewings to save time\n• Virtual tours for initial screening\n\nWhen are you available? Weekdays or weekends work better?"
        } else if message.contains("pet") {
            response = "🐕 Found 15 pet-friendly properties! Most allow cats and small dogs with a $200-500 pet deposit. Some even have dog parks nearby. What type of pet do you have?"
        } else if message.contains("subway") || message.contains("transport") {
            response = "🚇 I'll filter for properties near subway stations! Properties within 5 minutes of subway typically rent for 15% more, but the convenience is worth it. Which subway lines do you prefer?"
        } else {
            let genericResponses = [
                "I'd be happy to help! Could you provide more details about what you're looking for?",
                "That's a great question! Let me search our database for the best options.",
                "Based on current market trends, I can provide personalized recommendations. What's most important to you?",
                "I'm here to help you find the perfect place! What specific assistance do you need?"
            ]
            response = genericResponses.randomElement() ?? "How can I assist you today?"
        }
        
        messages.append(ChatMessage(text: response, isFromUser: false))
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.scrollToBottom()
        }
    }
    
    private func showTypingIndicator() {
        isTyping = true
        typingIndicator.startAnimating()
        
        UIView.animate(withDuration: 0.3) {
            self.typingIndicator.alpha = 1
        }
    }
    
    private func hideTypingIndicator() {
        isTyping = false
        
        UIView.animate(withDuration: 0.3, animations: {
            self.typingIndicator.alpha = 0
        }) { _ in
            self.typingIndicator.stopAnimating()
        }
    }
    
    private func startVoiceRecording() {
        // Simulate voice recording
        UIView.animate(withDuration: 0.3, animations: {
            self.voiceButton.backgroundColor = AppColors.errorRed
            self.voiceButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        })
        
        // Start recording timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Animate recording pulse
            UIView.animate(withDuration: 0.5, delay: 0, options: [.autoreverse, .repeat], animations: {
                self.voiceButton.alpha = 0.7
            })
        }
    }
    
    private func stopVoiceRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        UIView.animate(withDuration: 0.3) {
            self.voiceButton.backgroundColor = AppColors.accentBlue
            self.voiceButton.transform = .identity
            self.voiceButton.alpha = 1
        }
        
        // Simulate voice transcription
        let voiceMessages = [
            "Find me a one bedroom apartment under two thousand dollars",
            "Show me pet friendly places in Brooklyn",
            "I need a place near the subway with a gym",
            "Help me negotiate the price for the apartment I saw yesterday"
        ]
        
        if let voiceMessage = voiceMessages.randomElement() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.messages.append(ChatMessage(text: "🎤 " + voiceMessage, isFromUser: true))
                self.showTypingIndicator()
                self.tableView.reloadData()
                self.scrollToBottom()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.hideTypingIndicator()
                    self.simulateAIResponse(for: voiceMessage)
                }
            }
        }
    }
    
    private func showCamera() {
        // Simulate camera functionality
        let alert = UIAlertController(title: "📷 Camera", message: "Camera feature will allow you to take photos of properties and get AI analysis of room features, lighting, and space optimization.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Got it!", style: .default))
        present(alert, animated: true)
    }
    
    private func shareScreenshot() {
        let alert = UIAlertController(title: "📱 Screenshot", message: "Share property screenshots with friends and get their opinions through our collaborative decision feature.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cool!", style: .default))
        present(alert, animated: true)
    }
    
    private func shareLocation() {
        let alert = UIAlertController(title: "📍 Location", message: "Share your current location to get personalized property recommendations based on your commute preferences.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Awesome!", style: .default))
        present(alert, animated: true)
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