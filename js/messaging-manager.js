// Messaging Manager - Handles chat and messaging functionality
class MessagingManager {
    constructor() {
        this.supabase = null;
        this.currentConversationId = null;
        this.currentUser = null;
        this.locallyReadConversations = new Set();
        this.globalUserConversations = [];
        this.globalUnreadCount = 0;
    }

    // Initialize with Supabase client
    initialize(supabaseClient) {
        this.supabase = supabaseClient;
        this.currentUser = JSON.parse(localStorage.getItem('currentUser'));
        this.setupChatModal();
        this.setupMessagingPanel();
        console.log('✅ MessagingManager initialized');
    }

    // Start conversation for a listing
    async startConversation(listing) {
        console.log('Starting conversation for listing:', listing.title);
        this.currentUser = JSON.parse(localStorage.getItem('currentUser'));
        
        if (!this.currentUser) {
            alert('Please log in to start a conversation.');
            window.location.href = '/login';
            return;
        }

        // Hide city dropdown
        const cityContainer = document.getElementById('city-container');
        if (cityContainer) {
            cityContainer.style.display = 'none';
            console.log('City dropdown hidden');
        }

        // Set chat title
        document.getElementById('chatTitle').textContent = 'Chat about ' + listing.title;

        // Check for existing conversation
        if (!this.supabase) {
            console.error('Supabase not initialized - cannot start conversation');
            alert('Database connection error. Please refresh the page.');
            return;
        }
        
        const { data: conversations, error } = await this.supabase
            .from('conversations')
            .select('*')
            .eq('listing_id', listing.id)
            .eq('sender_email', this.currentUser.email)
            .eq('receiver_email', listing.user_email);

        if (error) {
            console.error('Error checking conversation:', error);
            alert('Failed to load conversation: ' + error.message);
            return;
        }

        let conversation;
        if (conversations && conversations.length > 0) {
            conversation = conversations[0];
            console.log('Existing conversation found:', conversation.id);
        } else {
            // Create new conversation
            const { data, error: insertError } = await this.supabase
                .from('conversations')
                .insert({
                    listing_id: listing.id,
                    sender_email: this.currentUser.email,
                    receiver_email: listing.user_email,
                    created_at: new Date().toISOString()
                })
                .select()
                .single();

            if (insertError) {
                console.error('Error creating conversation:', insertError);
                alert('Failed to start conversation: ' + insertError.message);
                return;
            }
            conversation = data;
            console.log('New conversation created:', conversation.id);
        }

        this.currentConversationId = conversation.id;
        await this.loadMessages(conversation.id);
        
        const modalElement = document.getElementById('chatModal');
        console.log('Modal element found:', !!modalElement);
        console.log('Modal computed style before:', window.getComputedStyle(modalElement).display);
        modalElement.style.display = 'block';
        modalElement.style.setProperty('display', 'block', 'important');
        console.log('Modal computed style after:', window.getComputedStyle(modalElement).display);
        console.log('Chat modal opened for conversation:', conversation.id);
    }

    // Load messages for a conversation
    async loadMessages(conversationId) {
        console.log('Loading messages for conversation:', conversationId);
        const { data: messages, error } = await this.supabase
            .from('messages')
            .select('*')
            .eq('conversation_id', conversationId)
            .order('created_at', { ascending: true });

        if (error) {
            console.error('Error loading messages:', error);
            alert('Failed to load messages: ' + error.message);
            return;
        }

        const chatMessagesContainer = document.getElementById('chatMessages');
        chatMessagesContainer.innerHTML = '';

        messages.forEach(message => {
            const messageElement = document.createElement('div');
            messageElement.className = 'message ' + (message.sender_email === this.currentUser.email ? 'sent' : 'received');
            messageElement.innerHTML = 
                '<p>' + this.escapeHtml(message.content) + '</p>' +
                '<div class="message-timestamp">' + new Date(message.created_at).toLocaleTimeString() + '</div>';
            chatMessagesContainer.appendChild(messageElement);
        });

        chatMessagesContainer.scrollTop = chatMessagesContainer.scrollHeight;
        console.log('Messages loaded:', messages.length);
    }

    // Send a message
    async sendMessage() {
        const chatInput = document.getElementById('chatInput');
        const messageContent = chatInput.value.trim();
        
        if (!messageContent || !this.currentConversationId) return;

        const timestamp = new Date().toISOString();

        // Add message to UI immediately
        const chatMessagesContainer = document.getElementById('chatMessages');
        const messageElement = document.createElement('div');
        messageElement.className = 'message sent';
        messageElement.innerHTML = 
            '<p>' + this.escapeHtml(messageContent) + '</p>' +
            '<div class="message-timestamp">' + new Date(timestamp).toLocaleTimeString() + '</div>';
        chatMessagesContainer.appendChild(messageElement);
        chatMessagesContainer.scrollTop = chatMessagesContainer.scrollHeight;

        // Clear input
        chatInput.value = '';

        // Send to database
        const { error } = await this.supabase
            .from('messages')
            .insert({
                conversation_id: this.currentConversationId,
                sender_email: this.currentUser.email,
                content: messageContent,
                created_at: timestamp
            });

        if (error) {
            console.error('❌ Error sending message:', error);
            messageElement.remove();
            chatInput.value = messageContent;
            alert('Failed to send message: ' + error.message);
            return;
        }

        console.log('✅ Message sent successfully');
    }

    // Setup chat modal
    setupChatModal() {
        const chatModal = document.getElementById('chatModal');
        const chatCloseButton = document.querySelector('.chat-close-button');
        const chatMessagesContainer = document.getElementById('chatMessages');
        const chatInput = document.getElementById('chatInput');
        const chatSendBtn = document.getElementById('chatSendBtn');
        
        // Add event listener for chat buttons
        document.addEventListener('click', (e) => {
            console.log('Click detected on:', e.target.className);
            if (e.target.classList.contains('chat-btn')) {
                console.log('Chat button clicked!');
                const listingData = e.target.dataset.listing;
                console.log('Listing data:', listingData);
                if (listingData) {
                    try {
                        const listing = JSON.parse(listingData);
                        console.log('Parsed listing:', listing);
                        this.startConversation(listing);
                    } catch (error) {
                        console.error('Error parsing listing data:', error);
                    }
                } else {
                    console.error('No listing data found on chat button');
                }
            }
        });

        if (!chatModal || !chatCloseButton || !chatMessagesContainer || !chatInput || !chatSendBtn) {
            console.error('Chat modal elements missing:', {
                chatModal: !!chatModal,
                chatCloseButton: !!chatCloseButton,
                chatMessagesContainer: !!chatMessagesContainer,
                chatInput: !!chatInput,
                chatSendBtn: !!chatSendBtn
            });
            return;
        }

        chatCloseButton.addEventListener('click', () => {
            chatModal.style.display = 'none';
            console.log('Chat modal closed');
        });

        window.addEventListener('click', (event) => {
            if (event.target === chatModal) {
                chatModal.style.display = 'none';
                console.log('Chat modal closed by clicking outside');
            }
        });

        chatSendBtn.addEventListener('click', () => this.sendMessage());

        chatInput.addEventListener('keydown', (event) => {
            if (event.key === 'Enter' && !event.shiftKey) {
                event.preventDefault();
                this.sendMessage();
            }
        });
    }

    // Setup messaging panel
    setupMessagingPanel() {
        const messageToggleBtn = document.getElementById('messageToggleBtn');
        const messagePanel = document.getElementById('messagePanel');
        const profileNotificationBadge = document.getElementById('profileNotificationBadge');
        const messageNotificationBadge = document.getElementById('messageNotificationBadge');
        
        if (!messageToggleBtn || !messagePanel) {
            console.warn('Messaging panel elements not found');
            return;
        }

        let isMessagingPanelOpen = false;

        // Toggle message panel
        messageToggleBtn.addEventListener('click', async () => {
            isMessagingPanelOpen = !isMessagingPanelOpen;
            if (isMessagingPanelOpen) {
                messagePanel.classList.remove('hidden');
                await this.loadUserConversations();
            } else {
                messagePanel.classList.add('hidden');
            }
        });

        // Force hide notifications button
        const forceHideBtn = document.getElementById('forceHideNotifications');
        if (forceHideBtn) {
            forceHideBtn.addEventListener('click', () => {
                console.log('🔥 FORCE HIDING ALL NOTIFICATIONS');
                
                // Mark ALL conversations as locally read
                this.globalUserConversations.forEach(conv => {
                    this.locallyReadConversations.add(conv.id);
                    conv.unread_count = 0;
                });
                
                // Force update
                this.updateUnreadCount();
                
                // Also update the display
                this.displayConversations();
            });
        }

        // Close panel when clicking outside
        document.addEventListener('click', (event) => {
            if (!event.target.closest('#messagingPanel')) {
                messagePanel.classList.add('hidden');
                isMessagingPanelOpen = false;
            }
        });
    }

    // Load user conversations
    async loadUserConversations() {
        if (!this.currentUser) return;

        // First verify current user is registered in profiles
        const { data: currentProfile, error: profileError } = await this.supabase
            .from('profiles')
            .select('email')
            .eq('email', this.currentUser.email)
            .single();

        if (profileError || !currentProfile) {
            console.error('Current user not found in profiles database:', profileError);
            const conversationTabs = document.getElementById('conversationTabs');
            if (conversationTabs) {
                conversationTabs.innerHTML = '<div class="p-4 text-red-500 text-center">Please register to access messaging</div>';
            }
            return;
        }

        const { data: conversations, error } = await this.supabase
            .from('conversations')
            .select(`
                *,
                listings (title, id)
            `)
            .or(`sender_email.eq.${this.currentUser.email},receiver_email.eq.${this.currentUser.email}`)
            .order('created_at', { ascending: false });

        if (error) {
            console.error('Error loading conversations:', error);
            return;
        }

        // Get unread counts for each conversation
        const conversationsWithUnread = [];
        for (const conv of conversations || []) {
            const { count } = await this.supabase
                .from('messages')
                .select('*', { count: 'exact', head: true })
                .eq('conversation_id', conv.id)
                .neq('sender_email', this.currentUser.email)
                .gt('created_at', conv.last_read_at || '1970-01-01');

            conversationsWithUnread.push({
                ...conv,
                unread_count: this.locallyReadConversations.has(conv.id) ? 0 : (count || 0)
            });
        }

        this.globalUserConversations = conversationsWithUnread;
        this.displayConversations();
        this.updateUnreadCount();
    }

    // Display conversations
    displayConversations() {
        const conversationTabs = document.getElementById('conversationTabs');
        const noConversations = document.getElementById('noConversations');
        
        if (!conversationTabs) return;

        if (this.globalUserConversations.length === 0) {
            if (noConversations) noConversations.style.display = 'block';
            return;
        }

        if (noConversations) noConversations.style.display = 'none';

        conversationTabs.innerHTML = this.globalUserConversations.map(conv => {
            const otherEmail = conv.sender_email === this.currentUser.email ? conv.receiver_email : conv.sender_email;
            const unreadBadge = conv.unread_count > 0 ? 
                `<span class="bg-red-500 text-white rounded-full px-2 py-1 text-xs">${conv.unread_count}</span>` : '';
            
            return `
                <div class="p-3 border-b cursor-pointer hover:bg-gray-50 conversation-tab" data-conversation-id="${conv.id}">
                    <div class="flex justify-between items-center">
                        <div>
                            <div class="font-medium">${conv.listings?.title || 'Property Chat'}</div>
                            <div class="text-sm text-gray-500">with ${otherEmail}</div>
                        </div>
                        ${unreadBadge}
                    </div>
                </div>
            `;
        }).join('');

        // Add click handlers for conversation tabs
        conversationTabs.querySelectorAll('.conversation-tab').forEach(tab => {
            tab.addEventListener('click', async () => {
                const convId = tab.dataset.conversationId;
                await this.openConversation(convId);
            });
        });
    }

    // Open a conversation
    async openConversation(conversationId) {
        this.currentConversationId = conversationId;
        
        // Mark as read locally
        this.locallyReadConversations.add(conversationId);
        
        // Update the conversation in the global list
        const convIndex = this.globalUserConversations.findIndex(c => c.id === conversationId);
        if (convIndex !== -1) {
            this.globalUserConversations[convIndex].unread_count = 0;
        }
        
        // Update UI
        this.displayConversations();
        this.updateUnreadCount();
        
        // Load messages
        await this.loadMessages(conversationId);
        
        // Show chat modal
        const chatModal = document.getElementById('chatModal');
        if (chatModal) {
            chatModal.style.display = 'block';
        }
    }

    // Update unread count
    updateUnreadCount() {
        const totalUnread = this.globalUserConversations.reduce((sum, conv) => sum + conv.unread_count, 0);
        this.globalUnreadCount = totalUnread;

        const messageNotificationBadge = document.getElementById('messageNotificationBadge');
        if (messageNotificationBadge) {
            if (totalUnread > 0) {
                messageNotificationBadge.textContent = totalUnread;
                messageNotificationBadge.classList.remove('hidden');
            } else {
                messageNotificationBadge.classList.add('hidden');
            }
        }

        // Also update profile notification if it exists
        const profileNotificationBadge = document.getElementById('profileNotificationBadge');
        if (profileNotificationBadge) {
            if (totalUnread > 0) {
                profileNotificationBadge.textContent = totalUnread;
                profileNotificationBadge.classList.remove('hidden');
            } else {
                profileNotificationBadge.classList.add('hidden');
            }
        }

        console.log('Updated unread count:', totalUnread);
    }

    // Escape HTML to prevent XSS
    escapeHtml(text) {
        const map = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#39;'
        };
        return text.replace(/[&<>"']/g, m => map[m]);
    }
}

// Export for global use
window.MessagingManager = MessagingManager;