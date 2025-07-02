// Chat functionality module
window.ChatManager = (function() {
    let activeConversations = new Map();
    let unreadCounts = new Map();
    let chatSubscriptions = new Map();
    let currentConversation = null;
    let messagePanel = null;
    let chatModal = null;
    let conversationTabs = null;
    let notificationBadge = null;

    // Initialize chat system
    function initialize() {
        setupChatUI();
        setupMessagePanel();
        setupRealtimeSubscriptions();
        loadExistingConversations();
        console.log('💬 Chat system initialized');
    }

    // Setup chat UI elements
    function setupChatUI() {
        messagePanel = document.getElementById('messagePanel');
        chatModal = document.getElementById('chatModal');
        conversationTabs = document.getElementById('conversationTabs');
        notificationBadge = document.getElementById('messageNotificationBadge');

        // Message toggle button
        const messageToggleBtn = document.getElementById('messageToggleBtn');
        if (messageToggleBtn) {
            messageToggleBtn.addEventListener('click', toggleMessagePanel);
        }

        // Chat modal elements
        const chatSendBtn = document.getElementById('chatSendBtn');
        const chatInput = document.getElementById('chatInput');
        
        if (chatSendBtn) {
            chatSendBtn.addEventListener('click', sendMessage);
        }

        if (chatInput) {
            chatInput.addEventListener('keypress', (e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    sendMessage();
                }
            });
        }

        // File upload handling
        const fileInput = document.getElementById('fileInput');
        if (fileInput) {
            fileInput.addEventListener('change', handleFileSelection);
        }

        // Close modal handlers
        const chatCloseButtons = document.querySelectorAll('.chat-close-button');
        chatCloseButtons.forEach(btn => {
            btn.addEventListener('click', closeChatModal);
        });

        // Force hide notifications button
        const forceHideBtn = document.getElementById('forceHideNotifications');
        if (forceHideBtn) {
            forceHideBtn.addEventListener('click', forceHideAllNotifications);
        }

        console.log('🎛️ Chat UI elements initialized');
    }

    // Setup message panel functionality
    function setupMessagePanel() {
        if (!messagePanel || !conversationTabs) return;

        // Initially hide the panel
        messagePanel.classList.add('hidden');
        
        console.log('📱 Message panel setup completed');
    }

    // Toggle message panel visibility
    function toggleMessagePanel() {
        if (!messagePanel) return;

        if (messagePanel.classList.contains('hidden')) {
            messagePanel.classList.remove('hidden');
            refreshConversationTabs();
        } else {
            messagePanel.classList.add('hidden');
        }
    }

    // Start new conversation
    async function startConversation(recipientEmail, listingTitle = 'Property') {
        console.log('💬 Starting conversation with:', recipientEmail, 'about:', listingTitle);

        if (!window.AuthManager.checkAuthForAction('start a conversation')) {
            return;
        }

        const currentUser = window.AuthManager.getCurrentUser();
        if (!currentUser) {
            window.Utils?.showError('Please log in to start conversations');
            return;
        }

        if (recipientEmail === currentUser.email) {
            window.Utils?.showError('Cannot start conversation with yourself');
            return;
        }

        try {
            // Create conversation key
            const conversationId = createConversationId(currentUser.email, recipientEmail);
            
            // Check if conversation already exists
            const { data: existingConversation } = await window.AppConfig.supabase
                .from('conversations')
                .select('*')
                .eq('id', conversationId)
                .single();

            let conversation = existingConversation;

            if (!conversation) {
                // Create new conversation
                const { data, error } = await window.AppConfig.supabase
                    .from('conversations')
                    .insert([{
                        id: conversationId,
                        participants: [currentUser.email, recipientEmail],
                        listing_title: listingTitle,
                        created_at: new Date().toISOString(),
                        last_message_at: new Date().toISOString()
                    }])
                    .select()
                    .single();

                if (error) throw error;
                conversation = data;
            }

            // Store conversation locally
            activeConversations.set(conversationId, conversation);
            
            // Open chat modal
            openChatModal(conversation);
            
            // Load messages
            await loadMessages(conversationId);

        } catch (error) {
            console.error('Error starting conversation:', error);
            window.Utils?.showError('Failed to start conversation');
        }
    }

    // Create conversation ID from participant emails
    function createConversationId(email1, email2) {
        return [email1, email2].sort().join('_');
    }

    // Open chat modal
    function openChatModal(conversation) {
        if (!chatModal) return;

        currentConversation = conversation;
        
        // Update modal title
        const chatTitle = document.getElementById('chatTitle');
        if (chatTitle) {
            const otherParticipant = getOtherParticipant(conversation);
            chatTitle.textContent = `Chat about ${conversation.listing_title} with ${otherParticipant}`;
        }

        chatModal.classList.add('active');
        
        // Focus input
        const chatInput = document.getElementById('chatInput');
        if (chatInput) {
            setTimeout(() => chatInput.focus(), 100);
        }
    }

    // Close chat modal
    function closeChatModal() {
        if (chatModal) {
            chatModal.classList.remove('active');
        }
        currentConversation = null;
    }

    // Get other participant in conversation
    function getOtherParticipant(conversation) {
        const currentUser = window.AuthManager.getCurrentUser();
        if (!currentUser) return 'Unknown';
        
        return conversation.participants.find(email => email !== currentUser.email) || 'Unknown';
    }

    // Load messages for conversation
    async function loadMessages(conversationId) {
        try {
            const { data: messages, error } = await window.AppConfig.supabase
                .from('messages')
                .select('*')
                .eq('conversation_id', conversationId)
                .order('created_at', { ascending: true });

            if (error) throw error;

            displayMessages(messages || []);

        } catch (error) {
            console.error('Error loading messages:', error);
            window.Utils?.showError('Failed to load messages');
        }
    }

    // Display messages in chat modal
    function displayMessages(messages) {
        const chatMessages = document.getElementById('chatMessages');
        if (!chatMessages) return;

        const currentUser = window.AuthManager.getCurrentUser();
        if (!currentUser) return;

        chatMessages.innerHTML = '';

        messages.forEach(message => {
            const messageDiv = document.createElement('div');
            messageDiv.className = `message ${message.sender_email === currentUser.email ? 'sent' : 'received'}`;
            
            const time = new Date(message.created_at).toLocaleTimeString([], { 
                hour: '2-digit', 
                minute: '2-digit' 
            });

            messageDiv.innerHTML = `
                <div class="message-content">
                    <p>${message.content}</p>
                    ${message.file_urls && message.file_urls.length > 0 ? 
                        `<div class="message-files">
                            ${message.file_urls.map(url => 
                                `<a href="${url}" target="_blank" class="file-link">📎 Attachment</a>`
                            ).join('')}
                        </div>` : ''
                    }
                </div>
                <div class="message-time">${time}</div>
            `;

            chatMessages.appendChild(messageDiv);
        });

        // Scroll to bottom
        chatMessages.scrollTop = chatMessages.scrollHeight;
    }

    // Send message
    async function sendMessage() {
        if (!currentConversation) return;

        const chatInput = document.getElementById('chatInput');
        const selectedFiles = document.getElementById('selectedFiles');
        
        if (!chatInput) return;

        const content = chatInput.value.trim();
        if (!content && (!selectedFiles || selectedFiles.children.length === 0)) {
            return;
        }

        const currentUser = window.AuthManager.getCurrentUser();
        if (!currentUser) return;

        try {
            // Handle file uploads if any
            let fileUrls = [];
            const fileInputs = selectedFiles?.querySelectorAll('input[type="file"]') || [];
            
            for (const input of fileInputs) {
                if (input.files.length > 0) {
                    const uploadedUrls = await uploadChatFiles(Array.from(input.files));
                    fileUrls.push(...uploadedUrls);
                }
            }

            // Send message to database
            const { data, error } = await window.AppConfig.supabase
                .from('messages')
                .insert([{
                    conversation_id: currentConversation.id,
                    sender_email: currentUser.email,
                    content: content,
                    file_urls: fileUrls,
                    created_at: new Date().toISOString()
                }])
                .select()
                .single();

            if (error) throw error;

            // Update conversation last message time
            await window.AppConfig.supabase
                .from('conversations')
                .update({ last_message_at: new Date().toISOString() })
                .eq('id', currentConversation.id);

            // Clear input and files
            chatInput.value = '';
            if (selectedFiles) {
                selectedFiles.innerHTML = '';
                selectedFiles.classList.add('hidden');
            }

            // Add message to display
            displayMessages([...await getConversationMessages(currentConversation.id), data]);

        } catch (error) {
            console.error('Error sending message:', error);
            window.Utils?.showError('Failed to send message');
        }
    }

    // Upload chat files
    async function uploadChatFiles(files) {
        const uploadPromises = files.map(async (file, index) => {
            try {
                const fileName = `chat_${Date.now()}_${index}_${file.name}`;
                const { data, error } = await window.AppConfig.supabase.storage
                    .from('chat-files')
                    .upload(fileName, file);

                if (error) throw error;

                const { data: urlData } = window.AppConfig.supabase.storage
                    .from('chat-files')
                    .getPublicUrl(fileName);

                return urlData.publicUrl;
            } catch (error) {
                console.error(`Failed to upload ${file.name}:`, error);
                return null;
            }
        });

        const results = await Promise.all(uploadPromises);
        return results.filter(url => url !== null);
    }

    // Handle file selection for chat
    function handleFileSelection() {
        const fileInput = document.getElementById('fileInput');
        const selectedFiles = document.getElementById('selectedFiles');
        
        if (!fileInput || !selectedFiles || !fileInput.files.length) return;

        selectedFiles.innerHTML = '';
        selectedFiles.classList.remove('hidden');

        Array.from(fileInput.files).forEach((file, index) => {
            const fileDiv = document.createElement('div');
            fileDiv.className = 'selected-file flex items-center justify-between p-2 bg-gray-100 rounded';
            fileDiv.innerHTML = `
                <span class="text-sm truncate">${file.name} (${window.Utils?.formatFileSize(file.size) || 'Unknown size'})</span>
                <button onclick="this.parentElement.remove(); checkFileCount()" class="text-red-500 hover:text-red-700">×</button>
            `;
            selectedFiles.appendChild(fileDiv);
        });
    }

    // Get conversation messages
    async function getConversationMessages(conversationId) {
        try {
            const { data, error } = await window.AppConfig.supabase
                .from('messages')
                .select('*')
                .eq('conversation_id', conversationId)
                .order('created_at', { ascending: true });

            if (error) throw error;
            return data || [];
        } catch (error) {
            console.error('Error getting messages:', error);
            return [];
        }
    }

    // Setup realtime subscriptions
    function setupRealtimeSubscriptions() {
        if (!window.AppConfig.supabase) return;

        const currentUser = window.AuthManager.getCurrentUser();
        if (!currentUser) return;

        // Subscribe to messages for current user
        const messageSubscription = window.AppConfig.supabase
            .channel('messages_channel')
            .on('postgres_changes', {
                event: 'INSERT',
                schema: 'public',
                table: 'messages'
            }, (payload) => {
                handleNewMessage(payload.new);
            })
            .subscribe();

        console.log('📡 Chat realtime subscriptions setup');
    }

    // Handle new message from realtime
    function handleNewMessage(message) {
        const currentUser = window.AuthManager.getCurrentUser();
        if (!currentUser) return;

        // Check if message is for current user's conversation
        if (currentConversation && message.conversation_id === currentConversation.id) {
            // Add to current chat if modal is open
            displayMessages([...document.querySelectorAll('#chatMessages .message')].map(el => ({
                sender_email: el.classList.contains('sent') ? currentUser.email : 'other',
                content: el.querySelector('.message-content p').textContent,
                created_at: new Date().toISOString()
            })).concat([message]));
        }

        // Update unread count if not from current user
        if (message.sender_email !== currentUser.email) {
            const conversationId = message.conversation_id;
            const currentCount = unreadCounts.get(conversationId) || 0;
            unreadCounts.set(conversationId, currentCount + 1);
            updateNotificationBadge();
        }
    }

    // Load existing conversations
    async function loadExistingConversations() {
        const currentUser = window.AuthManager.getCurrentUser();
        if (!currentUser) return;

        try {
            const { data: conversations, error } = await window.AppConfig.supabase
                .from('conversations')
                .select('*')
                .contains('participants', [currentUser.email])
                .order('last_message_at', { ascending: false });

            if (error) throw error;

            conversations?.forEach(conversation => {
                activeConversations.set(conversation.id, conversation);
            });

            refreshConversationTabs();

        } catch (error) {
            console.error('Error loading conversations:', error);
        }
    }

    // Refresh conversation tabs
    function refreshConversationTabs() {
        if (!conversationTabs) return;

        const currentUser = window.AuthManager.getCurrentUser();
        if (!currentUser) return;

        conversationTabs.innerHTML = '';

        if (activeConversations.size === 0) {
            conversationTabs.innerHTML = '<div id="noConversations" class="p-4 text-gray-500 text-center">No conversations yet</div>';
            return;
        }

        Array.from(activeConversations.values()).forEach(conversation => {
            const otherParticipant = getOtherParticipant(conversation);
            const unreadCount = unreadCounts.get(conversation.id) || 0;
            
            const tabDiv = document.createElement('div');
            tabDiv.className = 'conversation-tab p-3 border-b hover:bg-gray-50 cursor-pointer';
            tabDiv.innerHTML = `
                <div class="flex justify-between items-start">
                    <div class="flex-1">
                        <h4 class="font-medium text-sm">${conversation.listing_title}</h4>
                        <p class="text-xs text-gray-600">${otherParticipant}</p>
                    </div>
                    ${unreadCount > 0 ? 
                        `<span class="bg-red-500 text-white text-xs rounded-full px-2 py-1">${unreadCount}</span>` : 
                        ''
                    }
                </div>
            `;

            tabDiv.addEventListener('click', () => {
                openChatModal(conversation);
                loadMessages(conversation.id);
                // Clear unread count for this conversation
                unreadCounts.set(conversation.id, 0);
                updateNotificationBadge();
            });

            conversationTabs.appendChild(tabDiv);
        });
    }

    // Update notification badge
    function updateNotificationBadge() {
        if (!notificationBadge) return;

        const totalUnread = Array.from(unreadCounts.values()).reduce((sum, count) => sum + count, 0);
        
        if (totalUnread > 0) {
            notificationBadge.textContent = totalUnread.toString();
            notificationBadge.classList.remove('hidden');
        } else {
            notificationBadge.classList.add('hidden');
        }
    }

    // Force hide all notifications
    function forceHideAllNotifications() {
        unreadCounts.clear();
        updateNotificationBadge();
        console.log('🔥 All notifications force hidden');
    }

    // Public API
    return {
        initialize,
        startConversation,
        openChatModal,
        closeChatModal,
        sendMessage,
        loadMessages,
        refreshConversationTabs,
        forceHideAllNotifications,
        get activeConversations() { return activeConversations; },
        get unreadCounts() { return unreadCounts; }
    };
})();

// Global function for backwards compatibility
window.startConversation = function(userEmail, listingTitle) {
    if (window.ChatManager) {
        window.ChatManager.startConversation(userEmail, listingTitle);
    } else {
        console.warn('Chat functionality not available');
    }
};