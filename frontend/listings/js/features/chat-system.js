/**
 * Chat System Module
 * Comprehensive real-time messaging system with file sharing and health monitoring
 */

class ChatSystem {
    constructor(options = {}) {
        this.supabase = null;
        this.currentUser = null;
        this.isInitialized = false;
        this.conversations = new Map();
        this.activeConversation = null;
        this.subscriptions = [];
        this.healthMonitoring = false;
        this.healthInterval = null;
        
        // Configuration options
        this.config = {
            healthCheckInterval: 30000, // 30 seconds
            maxFileSize: 5 * 1024 * 1024, // 5MB
            allowedFileTypes: [
                'application/pdf',
                'application/msword',
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                'text/plain',
                'image/jpeg',
                'image/png',
                'image/gif',
                'image/webp'
            ],
            retryAttempts: 3,
            retryDelay: 1000,
            messageLoadLimit: 50,
            enableNotifications: true,
            autoReconnect: true,
            ...options
        };
        
        // DOM elements cache
        this.elements = {};
        
        console.log('💬 Chat System initialized with config:', this.config);
    }
    
    /**
     * Initialize the chat system
     */
    async initialize(supabaseClient = null) {
        try {
            // Get Supabase client
            if (supabaseClient) {
                this.supabase = supabaseClient;
            } else if (window.ClientConfig && window.ClientConfig.getSupabaseClient) {
                this.supabase = window.ClientConfig.getSupabaseClient();
            } else {
                throw new Error('No Supabase client available');
            }
            
            // Get current user
            await this.getCurrentUser();
            
            // Cache DOM elements
            this.cacheElements();
            
            // Setup event listeners
            this.setupEventListeners();
            
            // Initialize components
            await this.setupChat();
            
            // Start health monitoring
            if (this.config.enableNotifications) {
                this.startHealthMonitoring();
            }
            
            this.isInitialized = true;
            console.log('✅ Chat System initialized successfully');
            
            // Trigger initialization event
            document.dispatchEvent(new CustomEvent('chatSystemInitialized', {
                detail: { chatSystem: this }
            }));
            
            return true;
            
        } catch (error) {
            console.error('❌ Chat System initialization failed:', error);
            this.showError('Chat system failed to initialize. Some features may not work.');
            return false;
        }
    }
    
    /**
     * Get current authenticated user
     */
    async getCurrentUser() {
        try {
            const { data: { user }, error } = await this.supabase.auth.getUser();
            
            if (error) {
                throw error;
            }
            
            this.currentUser = user;
            
            if (user) {
                console.log('👤 Chat system user:', user.email);
            } else {
                console.warn('⚠️ No authenticated user for chat system');
            }
            
            return user;
            
        } catch (error) {
            console.error('❌ Error getting current user:', error);
            throw error;
        }
    }
    
    /**
     * Cache DOM elements for performance
     */
    cacheElements() {
        this.elements = {
            chatModal: document.getElementById('chatModal'),
            chatMessages: document.getElementById('chatMessages'),
            chatInput: document.getElementById('chatInput'),
            chatSendBtn: document.getElementById('chatSendBtn'),
            chatClose: document.getElementById('chatClose'),
            chatTitle: document.getElementById('chatTitle'),
            fileUpload: document.getElementById('fileUpload'),
            healthStatus: document.getElementById('healthStatus'),
            messagingPanel: document.getElementById('messagingPanel'),
            conversationsList: document.getElementById('conversationTabs'),
            messagesContainer: document.getElementById('messagesContainer')
        };
        
        console.log('📋 DOM elements cached');
    }
    
    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Chat modal events
        if (this.elements.chatClose) {
            this.elements.chatClose.addEventListener('click', () => this.closeChatModal());
        }
        
        if (this.elements.chatSendBtn) {
            this.elements.chatSendBtn.addEventListener('click', () => this.sendMessage());
        }
        
        if (this.elements.chatInput) {
            this.elements.chatInput.addEventListener('keypress', (e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    this.sendMessage();
                }
            });
        }
        
        // File upload events
        if (this.elements.fileUpload) {
            this.elements.fileUpload.addEventListener('change', (e) => this.handleFileUpload(e));
        }
        
        // Auth state changes
        if (this.supabase) {
            this.supabase.auth.onAuthStateChange((event, session) => {
                if (event === 'SIGNED_OUT') {
                    this.cleanup();
                } else if (event === 'SIGNED_IN' && session) {
                    this.currentUser = session.user;
                    this.restartSubscriptions();
                }
            });
        }
        
        console.log('🔗 Event listeners setup complete');
    }
    
    /**
     * Setup chat functionality
     */
    async setupChat() {
        try {
            // Setup real-time subscriptions
            await this.setupRealTimeSubscriptions();
            
            // Load existing conversations
            await this.loadConversations();
            
            // Initialize messaging panel if available
            if (this.elements.messagingPanel) {
                await this.initializeMessagingPanel();
            }
            
            console.log('💬 Chat setup completed');
            return true;
            
        } catch (error) {
            console.error('❌ Chat setup failed:', error);
            return false;
        }
    }
    
    /**
     * Setup real-time subscriptions
     */
    async setupRealTimeSubscriptions() {
        if (!this.currentUser) {
            console.warn('⚠️ No user, skipping real-time subscriptions');
            return;
        }
        
        try {
            // Subscribe to all messages where user is either sender or recipient
            // This ensures both users in a conversation receive real-time updates
            const messageSubscription = this.supabase
                .channel('messages-changes')
                .on('postgres_changes', 
                    { 
                        event: '*', 
                        schema: 'public', 
                        table: 'messages'
                        // Remove the filter to catch all messages, we'll filter in the handler
                    }, 
                    (payload) => this.handleMessageUpdate(payload)
                )
                .subscribe();
            
            this.subscriptions.push(messageSubscription);
            
            // Subscribe to conversations where user is tenant or landlord
            const conversationSubscription = this.supabase
                .channel('conversations-changes')
                .on('postgres_changes', 
                    { 
                        event: '*', 
                        schema: 'public', 
                        table: 'conversations'
                    }, 
                    (payload) => this.handleConversationUpdate(payload)
                )
                .subscribe();
            
            this.subscriptions.push(conversationSubscription);
            
            console.log('📡 Real-time subscriptions established for all messages and conversations');
            
        } catch (error) {
            console.error('❌ Failed to setup real-time subscriptions:', error);
        }
    }
    
    /**
     * Get conversation IDs for current user
     */
    async getUserConversationIds() {
        if (!this.currentUser) return '';
        
        try {
            const { data, error } = await this.supabase
                .from('conversations')
                .select('id')
                .or(`tenant_id.eq.${this.currentUser.id},landlord_id.eq.${this.currentUser.id}`);
            
            if (error) throw error;
            
            return data.map(conv => conv.id).join(',') || '0';
            
        } catch (error) {
            console.error('❌ Error getting conversation IDs:', error);
            return '0';
        }
    }
    
    /**
     * Handle real-time message updates
     */
    handleMessageUpdate(payload) {
        console.log('📨 Message update:', payload);
        
        const { eventType, new: newRecord, old: oldRecord } = payload;
        
        // Filter out messages that don't involve the current user
        const messageRecord = newRecord || oldRecord;
        if (!this.isMessageRelevantToUser(messageRecord)) {
            return; // Skip messages not involving this user
        }
        
        switch (eventType) {
            case 'INSERT':
                this.handleNewMessage(newRecord);
                break;
            case 'UPDATE':
                this.handleMessageEdit(newRecord, oldRecord);
                break;
            case 'DELETE':
                this.handleMessageDelete(oldRecord);
                break;
        }
    }
    
    /**
     * Check if a message is relevant to the current user
     */
    isMessageRelevantToUser(message) {
        if (!message || !this.currentUser) return false;
        
        // Check if user is sender, recipient, tenant, or landlord in this message
        return message.sender_id === this.currentUser.id ||
               message.recipient_id === this.currentUser.id ||
               message.tenant_id === this.currentUser.id ||
               message.landlord_id === this.currentUser.id;
    }
    
    /**
     * Handle new message from real-time subscription
     */
    handleNewMessage(message) {
        // Don't handle our own messages (already shown)
        if (message.sender_id === this.currentUser?.id) {
            return;
        }
        
        // Add to conversation
        const conversation = this.conversations.get(message.conversation_id);
        if (conversation) {
            conversation.messages.push(message);
            conversation.lastMessage = message;
            conversation.unreadCount = (conversation.unreadCount || 0) + 1;
        }
        
        // Update UI if this conversation is active
        if (this.activeConversation?.id === message.conversation_id) {
            this.displayMessage(message);
            this.scrollToBottom();
        }
        
        // Update conversations list
        this.updateConversationsList();
        
        // Update notification badge
        this.updateNotificationBadge();
        
        // Show notification
        if (this.config.enableNotifications) {
            this.showNotification(`New message from ${message.sender_email}`, message.content);
        }
    }
    
    /**
     * Handle conversation updates from real-time subscription
     */
    handleConversationUpdate(payload) {
        console.log('💬 Conversation update:', payload);
        
        const { eventType, new: newRecord, old: oldRecord } = payload;
        
        // Filter out conversations that don't involve the current user
        const conversationRecord = newRecord || oldRecord;
        if (!this.isConversationRelevantToUser(conversationRecord)) {
            return; // Skip conversations not involving this user
        }
        
        switch (eventType) {
            case 'INSERT':
                // New conversation created
                this.conversations.set(newRecord.id, {
                    ...newRecord,
                    messages: [],
                    unreadCount: 0
                });
                this.updateConversationsList();
                break;
            case 'UPDATE':
                // Conversation updated
                const existingConv = this.conversations.get(newRecord.id);
                if (existingConv) {
                    Object.assign(existingConv, newRecord);
                    this.updateConversationsList();
                }
                break;
            case 'DELETE':
                // Conversation deleted
                this.conversations.delete(oldRecord.id);
                this.updateConversationsList();
                break;
        }
    }
    
    /**
     * Check if a conversation is relevant to the current user
     */
    isConversationRelevantToUser(conversation) {
        if (!conversation || !this.currentUser) return false;
        
        return conversation.tenant_id === this.currentUser.id ||
               conversation.landlord_id === this.currentUser.id;
    }
    
    /**
     * Start or open a conversation
     */
    async startConversation(listingId, listingTitle, landlordId = null) {
        if (!this.currentUser) {
            this.showError('Please log in to start a conversation');
            return false;
        }
        
        // Verify user is authenticated in Supabase Auth
        const { data: { user }, error: authError } = await this.supabase.auth.getUser();
        if (authError || !user) {
            this.showError('You must be logged in with a verified account to start conversations');
            // Redirect to login if needed
            if (window.location.pathname !== '/frontend/login.html') {
                window.location.href = '/frontend/login.html?redirect=' + encodeURIComponent(window.location.href);
            }
            return false;
        }
        
        try {
            // Check if conversation already exists
            let conversation = await this.findExistingConversation(listingId, landlordId);
            
            if (!conversation) {
                // Create new conversation
                conversation = await this.createConversation(listingId, listingTitle, landlordId);
            }
            
            if (conversation) {
                // Load and display conversation
                await this.openConversation(conversation);
                return true;
            }
            
            return false;
            
        } catch (error) {
            console.error('❌ Error starting conversation:', error);
            this.showError('Failed to start conversation. Please try again.');
            return false;
        }
    }
    
    /**
     * Find existing conversation
     */
    async findExistingConversation(listingId, landlordId) {
        try {
            const { data, error } = await this.supabase
                .from('conversations')
                .select('*')
                .eq('listing_id', listingId)
                .eq('tenant_id', this.currentUser.id)
                .maybeSingle();
            
            if (error && error.code !== 'PGRST116') { // PGRST116 = no rows returned
                throw error;
            }
            
            return data;
            
        } catch (error) {
            console.error('❌ Error finding conversation:', error);
            return null;
        }
    }
    
    /**
     * Create new conversation
     */
    async createConversation(listingId, listingTitle, landlordId) {
        try {
            // Get listing details if landlordId not provided
            let actualLandlordId = landlordId;
            let landlordEmail = null;
            
            if (!actualLandlordId) {
                const { data: listing, error: listingError } = await this.supabase
                    .from('listings')
                    .select('user_id, user_email')
                    .eq('id', listingId)
                    .single();
                
                if (listingError) throw listingError;
                
                actualLandlordId = listing.user_id;
                landlordEmail = listing.user_email;
                
                // If no user_id but have email, try to find user by email
                if (!actualLandlordId && landlordEmail) {
                    const { data: userProfile } = await this.supabase
                        .from('profiles')
                        .select('id')
                        .eq('email', landlordEmail)
                        .single();
                    
                    if (userProfile) {
                        actualLandlordId = userProfile.id;
                    }
                }
            }
            
            // Don't allow self-conversation
            if (actualLandlordId === this.currentUser.id) {
                this.showError('You cannot start a conversation with yourself');
                return null;
            }
            
            const conversationData = {
                listing_id: listingId,
                listing_title: listingTitle,
                tenant_id: this.currentUser.id,
                landlord_id: actualLandlordId,
                created_at: new Date().toISOString()
            };
            
            const { data, error } = await this.supabase
                .from('conversations')
                .insert([conversationData])
                .select()
                .single();
            
            if (error) throw error;
            
            console.log('✅ Conversation created:', data.id);
            return data;
            
        } catch (error) {
            console.error('❌ Error creating conversation:', error);
            throw error;
        }
    }
    
    /**
     * Open and display a conversation
     */
    async openConversation(conversation) {
        try {
            this.activeConversation = conversation;
            
            // Store in conversations map
            this.conversations.set(conversation.id, {
                ...conversation,
                messages: [],
                unreadCount: 0
            });
            
            // Update chat modal title
            if (this.elements.chatTitle) {
                this.elements.chatTitle.textContent = `Chat about: ${conversation.listing_title}`;
            }
            
            // Load messages
            await this.loadMessages(conversation.id);
            
            // Show chat modal
            this.showChatModal();
            
            // Mark as read
            await this.markConversationAsRead(conversation.id);
            
            console.log('✅ Conversation opened:', conversation.id);
            
        } catch (error) {
            console.error('❌ Error opening conversation:', error);
            this.showError('Failed to open conversation');
        }
    }
    
    /**
     * Load messages for a conversation
     */
    async loadMessages(conversationId) {
        try {
            const { data, error } = await this.supabase
                .from('messages')
                .select('*')
                .eq('conversation_id', conversationId)
                .order('created_at', { ascending: true })
                .limit(this.config.messageLoadLimit);
            
            if (error) throw error;
            
            // Store messages
            const conversation = this.conversations.get(conversationId);
            if (conversation) {
                conversation.messages = data || [];
            }
            
            // Display messages
            this.displayMessages(data || []);
            
            console.log(`📨 Loaded ${data?.length || 0} messages for conversation ${conversationId}`);
            
        } catch (error) {
            console.error('❌ Error loading messages:', error);
            this.showError('Failed to load messages');
        }
    }
    
    /**
     * Display messages in chat
     */
    displayMessages(messages) {
        if (!this.elements.chatMessages) return;
        
        this.elements.chatMessages.innerHTML = '';
        
        messages.forEach(message => {
            this.displayMessage(message);
        });
        
        this.scrollToBottom();
    }
    
    /**
     * Display a single message
     */
    displayMessage(message) {
        if (!this.elements.chatMessages) return;
        
        const messageElement = document.createElement('div');
        const isOwnMessage = message.sender_id === this.currentUser?.id;
        
        messageElement.className = `message ${isOwnMessage ? 'sent' : 'received'}`;
        
        let content = `
            <div class="message-content">
                ${this.escapeHtml(message.content)}
            </div>
        `;
        
        // Add file attachment if present
        if (message.file_url) {
            content += `
                <div class="message-attachment">
                    <a href="${message.file_url}" target="_blank" class="attachment-link">
                        📎 ${this.escapeHtml(message.file_name || 'Download file')}
                    </a>
                </div>
            `;
        }
        
        content += `
            <div class="message-timestamp">
                ${this.formatMessageTime(message.created_at)}
            </div>
        `;
        
        messageElement.innerHTML = content;
        this.elements.chatMessages.appendChild(messageElement);
    }
    
    /**
     * Send a message
     */
    async sendMessage() {
        if (!this.activeConversation || !this.currentUser) {
            this.showError('No active conversation');
            return;
        }
        
        // Check if user is authenticated in Supabase Auth
        const { data: { user }, error: authError } = await this.supabase.auth.getUser();
        if (authError || !user) {
            this.showError('You must be logged in with a verified account to send messages');
            return;
        }
        
        const content = this.elements.chatInput?.value.trim();
        if (!content) {
            return;
        }
        
        try {
            // Disable send button
            if (this.elements.chatSendBtn) {
                this.elements.chatSendBtn.disabled = true;
            }
            
            // Determine if current user is landlord or tenant
            const isLandlord = this.activeConversation.landlord_id === this.currentUser.id;
            const recipientId = isLandlord ? 
                this.activeConversation.tenant_id : 
                this.activeConversation.landlord_id;
            
            const messageData = {
                conversation_id: this.activeConversation.id,
                sender_id: this.currentUser.id,
                sender_email: this.currentUser.email,
                recipient_id: recipientId,  // Add recipient ID (landlord or tenant)
                landlord_id: this.activeConversation.landlord_id,  // Always save landlord ID
                tenant_id: this.activeConversation.tenant_id,  // Always save tenant ID
                content: content,
                created_at: new Date().toISOString()
            };
            
            const { data, error } = await this.supabase
                .from('messages')
                .insert([messageData])
                .select()
                .single();
            
            if (error) throw error;
            
            // Clear input
            if (this.elements.chatInput) {
                this.elements.chatInput.value = '';
            }
            
            // Add to local conversation
            const conversation = this.conversations.get(this.activeConversation.id);
            if (conversation) {
                conversation.messages.push(data);
                conversation.lastMessage = data;
            }
            
            // Display message immediately (optimistic update)
            this.displayMessage(data);
            this.scrollToBottom();
            
            console.log('✅ Message sent:', data.id);
            
        } catch (error) {
            console.error('❌ Error sending message:', error);
            this.showError('Failed to send message. Please try again.');
        } finally {
            // Re-enable send button
            if (this.elements.chatSendBtn) {
                this.elements.chatSendBtn.disabled = false;
            }
        }
    }
    
    /**
     * Handle file upload
     */
    async handleFileUpload(event) {
        const file = event.target.files[0];
        if (!file) return;
        
        try {
            // Validate file
            if (file.size > this.config.maxFileSize) {
                this.showError(`File too large. Maximum size is ${this.formatFileSize(this.config.maxFileSize)}`);
                return;
            }
            
            if (!this.config.allowedFileTypes.includes(file.type)) {
                this.showError('File type not allowed');
                return;
            }
            
            // Upload file
            const fileUrl = await this.uploadFile(file);
            
            if (fileUrl) {
                // Send message with file attachment
                await this.sendFileMessage(file.name, fileUrl);
            }
            
        } catch (error) {
            console.error('❌ File upload error:', error);
            this.showError('File upload failed. Please try again.');
        } finally {
            // Clear file input
            event.target.value = '';
        }
    }
    
    /**
     * Upload file to storage
     */
    async uploadFile(file) {
        try {
            const fileExt = file.name.split('.').pop();
            const fileName = `${this.activeConversation.id}/${Date.now()}-${Math.random().toString(36).substr(2, 9)}.${fileExt}`;
            
            const { data, error } = await this.supabase.storage
                .from('chat-files')
                .upload(fileName, file);
            
            if (error) throw error;
            
            // Get public URL
            const { data: { publicUrl } } = this.supabase.storage
                .from('chat-files')
                .getPublicUrl(fileName);
            
            console.log('✅ File uploaded:', fileName);
            return publicUrl;
            
        } catch (error) {
            console.error('❌ File upload error:', error);
            throw error;
        }
    }
    
    /**
     * Send message with file attachment
     */
    async sendFileMessage(fileName, fileUrl) {
        if (!this.activeConversation || !this.currentUser) return;
        
        try {
            const messageData = {
                conversation_id: this.activeConversation.id,
                sender_id: this.currentUser.id,
                sender_email: this.currentUser.email,
                content: `Shared a file: ${fileName}`,
                file_name: fileName,
                file_url: fileUrl,
                created_at: new Date().toISOString()
            };
            
            const { data, error } = await this.supabase
                .from('messages')
                .insert([messageData])
                .select()
                .single();
            
            if (error) throw error;
            
            // Add to conversation and display
            const conversation = this.conversations.get(this.activeConversation.id);
            if (conversation) {
                conversation.messages.push(data);
                conversation.lastMessage = data;
            }
            
            this.displayMessage(data);
            this.scrollToBottom();
            
            console.log('✅ File message sent:', data.id);
            
        } catch (error) {
            console.error('❌ Error sending file message:', error);
            throw error;
        }
    }
    
    /**
     * Load all conversations for current user
     */
    async loadConversations() {
        if (!this.currentUser) return;
        
        try {
            const { data, error } = await this.supabase
                .from('conversations')
                .select(`
                    *,
                    messages!inner(
                        content,
                        created_at,
                        sender_id,
                        file_name
                    )
                `)
                .or(`tenant_id.eq.${this.currentUser.id},landlord_id.eq.${this.currentUser.id}`)
                .order('updated_at', { ascending: false });
            
            if (error) throw error;
            
            // Process conversations
            data?.forEach(conv => {
                const lastMessage = conv.messages?.[conv.messages.length - 1];
                
                // Calculate unread count (messages not from current user that are recent)
                const unreadCount = conv.messages?.filter(msg => 
                    msg.sender_id !== this.currentUser.id &&
                    new Date(msg.created_at) > new Date(conv.last_read_at || 0)
                ).length || 0;
                
                this.conversations.set(conv.id, {
                    ...conv,
                    messages: conv.messages || [],
                    lastMessage,
                    unreadCount
                });
            });
            
            console.log(`📂 Loaded ${data?.length || 0} conversations`);
            
            // Update notification badge
            this.updateNotificationBadge();
            
        } catch (error) {
            console.error('❌ Error loading conversations:', error);
        }
    }
    
    /**
     * Show chat modal
     */
    showChatModal() {
        if (this.elements.chatModal) {
            this.elements.chatModal.classList.add('active');
            document.body.style.overflow = 'hidden';
            
            // Focus input
            if (this.elements.chatInput) {
                setTimeout(() => this.elements.chatInput.focus(), 100);
            }
        }
    }
    
    /**
     * Close chat modal
     */
    closeChatModal() {
        if (this.elements.chatModal) {
            this.elements.chatModal.classList.remove('active');
            document.body.style.overflow = '';
            this.activeConversation = null;
        }
    }
    
    /**
     * Start health monitoring
     */
    startHealthMonitoring() {
        if (this.healthInterval) {
            clearInterval(this.healthInterval);
        }
        
        this.healthMonitoring = true;
        this.healthInterval = setInterval(() => {
            this.performHealthCheck();
        }, this.config.healthCheckInterval);
        
        // Initial health check
        this.performHealthCheck();
        
        console.log('🔍 Health monitoring started');
    }
    
    /**
     * Perform health check
     */
    async performHealthCheck() {
        try {
            const health = {
                timestamp: new Date().toISOString(),
                supabase: false,
                auth: false,
                realtime: false,
                database: false
            };
            
            // Check Supabase connection
            if (this.supabase) {
                health.supabase = true;
                
                // Check auth
                const { data: { user } } = await this.supabase.auth.getUser();
                health.auth = !!user;
                
                // Check database
                try {
                    const { error } = await this.supabase
                        .from('conversations')
                        .select('count', { count: 'exact', head: true });
                    health.database = !error;
                } catch (dbError) {
                    health.database = false;
                }
                
                // Check realtime
                health.realtime = this.subscriptions.length > 0;
            }
            
            this.updateHealthStatus(health);
            
        } catch (error) {
            console.error('❌ Health check failed:', error);
        }
    }
    
    /**
     * Update health status display
     */
    updateHealthStatus(health) {
        if (!this.elements.healthStatus) return;
        
        const allHealthy = Object.values(health).every(status => 
            typeof status === 'boolean' ? status : true
        );
        
        this.elements.healthStatus.className = `health-status ${allHealthy ? 'healthy' : 'unhealthy'}`;
        this.elements.healthStatus.textContent = allHealthy ? '🟢 Online' : '🔴 Issues detected';
        
        if (!allHealthy) {
            console.warn('⚠️ Chat system health issues:', health);
        }
    }
    
    /**
     * Mark conversation as read
     */
    async markConversationAsRead(conversationId) {
        try {
            const conversation = this.conversations.get(conversationId);
            if (conversation) {
                conversation.unreadCount = 0;
            }
            
            // Update UI
            this.updateConversationsList();
            
        } catch (error) {
            console.error('❌ Error marking conversation as read:', error);
        }
    }
    
    /**
     * Update conversations list UI
     */
    updateConversationsList() {
        if (!this.elements.conversationsList) return;
        
        const conversations = Array.from(this.conversations.values())
            .sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at));
        
        if (conversations.length === 0) {
            // Show "no conversations" message
            this.elements.conversationsList.innerHTML = `
                <div id="noConversations" class="p-4 text-gray-500 text-center">
                    No conversations yet
                </div>
            `;
            return;
        }
        
        this.elements.conversationsList.innerHTML = conversations.map(conv => {
            const unreadBadge = conv.unreadCount > 0 ? 
                `<span class="unread-badge">${conv.unreadCount}</span>` : '';
            
            return `
                <div class="conversation-item" data-id="${conv.id}">
                    <div class="conversation-title">${this.escapeHtml(conv.listing_title || 'Chat')}</div>
                    <div class="conversation-preview">
                        ${conv.lastMessage ? this.escapeHtml(conv.lastMessage.content.substring(0, 50)) : 'No messages yet'}
                    </div>
                    <div class="conversation-time">
                        ${conv.lastMessage ? this.formatMessageTime(conv.lastMessage.created_at) : ''}
                    </div>
                    ${unreadBadge}
                </div>
            `;
        }).join('');
        
        // Add click handlers
        this.elements.conversationsList.querySelectorAll('.conversation-item').forEach(item => {
            item.addEventListener('click', () => {
                const convId = item.dataset.id;
                const conversation = this.conversations.get(convId);
                if (conversation) {
                    this.openConversation(conversation);
                }
            });
        });
    }
    
    /**
     * Utility functions
     */
    scrollToBottom() {
        if (this.elements.chatMessages) {
            this.elements.chatMessages.scrollTop = this.elements.chatMessages.scrollHeight;
        }
    }
    
    escapeHtml(text) {
        if (!text || typeof text !== 'string') return '';
        
        // Log special characters for debugging
        if (/[?!öÖäÄüÜßáéíóúàèìòùâêîôûãñç]/.test(text)) {
            console.log('🔤 Special characters detected in message (will be preserved):', text);
        }
        
        // Create a DOM element and use textContent to safely escape only dangerous HTML characters
        // This preserves UTF-8 characters, punctuation, and international characters
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    
    formatMessageTime(timestamp) {
        const date = new Date(timestamp);
        const now = new Date();
        const diffMs = now - date;
        const diffHours = diffMs / (1000 * 60 * 60);
        
        if (diffHours < 24) {
            return date.toLocaleTimeString('en-US', { 
                hour: 'numeric', 
                minute: '2-digit',
                hour12: true 
            });
        } else {
            return date.toLocaleDateString('en-US', { 
                month: 'short', 
                day: 'numeric' 
            });
        }
    }
    
    formatFileSize(bytes) {
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        if (bytes === 0) return '0 Byte';
        const i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
        return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
    }
    
    showError(message) {
        console.error('💬 Chat Error:', message);
        // TODO: Implement user-friendly error display
        alert(message); // Temporary - replace with better notification system
    }
    
    showNotification(title, message) {
        if ('Notification' in window && Notification.permission === 'granted') {
            new Notification(title, {
                body: message,
                icon: '/favicon.ico'
            });
        }
    }
    
    /**
     * Update notification badge in bottom right
     */
    updateNotificationBadge() {
        // Calculate total unread count
        let totalUnread = 0;
        this.conversations.forEach(conv => {
            totalUnread += conv.unreadCount || 0;
        });
        
        // Update badge in messaging panel
        const badge = document.getElementById('messageNotificationBadge');
        if (badge) {
            if (totalUnread > 0) {
                badge.textContent = totalUnread > 99 ? '99+' : totalUnread.toString();
                badge.classList.remove('hidden');
                
                // Add pulse animation for new messages
                badge.classList.add('animate-pulse');
                setTimeout(() => {
                    badge.classList.remove('animate-pulse');
                }, 3000);
            } else {
                badge.classList.add('hidden');
            }
        }
        
        // Update page title with unread count
        if (totalUnread > 0) {
            document.title = `(${totalUnread}) ${document.title.replace(/^\(\d+\) /, '')}`;
        } else {
            document.title = document.title.replace(/^\(\d+\) /, '');
        }
    }
    
    /**
     * Cleanup and destroy
     */
    cleanup() {
        // Stop health monitoring
        if (this.healthInterval) {
            clearInterval(this.healthInterval);
            this.healthInterval = null;
        }
        
        // Remove subscriptions
        this.subscriptions.forEach(subscription => {
            if (this.supabase) {
                this.supabase.removeChannel(subscription);
            }
        });
        this.subscriptions = [];
        
        // Clear data
        this.conversations.clear();
        this.activeConversation = null;
        this.currentUser = null;
        this.isInitialized = false;
        
        console.log('🧹 Chat system cleaned up');
    }
    
    /**
     * Restart subscriptions (useful after auth changes)
     */
    async restartSubscriptions() {
        // Remove existing subscriptions
        this.subscriptions.forEach(subscription => {
            if (this.supabase) {
                this.supabase.removeChannel(subscription);
            }
        });
        this.subscriptions = [];
        
        // Setup new subscriptions
        await this.setupRealTimeSubscriptions();
        
        console.log('🔄 Chat subscriptions restarted');
    }
}

// Global chat system instance
let globalChatSystem = null;

/**
 * Initialize chat system (for backward compatibility)
 */
async function setupChat() {
    try {
        if (!globalChatSystem) {
            globalChatSystem = new ChatSystem();
        }
        
        const success = await globalChatSystem.initialize();
        
        if (success) {
            console.log('✅ Global chat system setup complete');
        }
        
        return success;
        
    } catch (error) {
        console.error('❌ Global chat setup failed:', error);
        return false;
    }
}

/**
 * Open chat modal (for backward compatibility)
 */
async function openChatModal(listingId, listingTitle, landlordId = null) {
    if (globalChatSystem && globalChatSystem.isInitialized) {
        return await globalChatSystem.startConversation(listingId, listingTitle, landlordId);
    } else {
        console.warn('⚠️ Chat system not initialized');
        return false;
    }
}

/**
 * Initialize messaging panel (for backward compatibility)
 */
async function initializeMessagingPanel() {
    if (globalChatSystem && globalChatSystem.isInitialized) {
        await globalChatSystem.loadConversations();
        globalChatSystem.updateConversationsList();
        return true;
    } else {
        console.warn('⚠️ Chat system not initialized');
        return false;
    }
}

// Export for ES6 modules
export {
    ChatSystem,
    setupChat,
    openChatModal,
    initializeMessagingPanel
};

// Export to window for backward compatibility
window.ChatSystem = ChatSystem;
window.setupChat = setupChat;
window.openChatModal = openChatModal;
window.initializeMessagingPanel = initializeMessagingPanel;
window.globalChatSystem = () => globalChatSystem;