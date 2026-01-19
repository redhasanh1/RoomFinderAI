/**
 * RoomFinderAI Chat System Module
 * 
 * A comprehensive chat system module that provides real-time messaging functionality
 * with file upload, health monitoring, and seamless integration with Supabase.
 * 
 * Features:
 * - Real-time messaging with Supabase
 * - File upload and sharing (landlords only)
 * - Message persistence and history
 * - Health monitoring and diagnostics
 * - Error handling and auto-recovery
 * - Notification system
 * - Connection monitoring
 * - Conversation management
 * 
 * @author RoomFinderAI Development Team
 * @version 1.0.0
 * @requires supabase-js
 */

class ChatSystem {
    constructor() {
        // System status tracking
        this.chatSystemStatus = {
            isInitialized: false,
            elementsReady: false,
            supabaseConnected: false,
            setupAttempts: 0,
            errors: [],
            lastHealthCheck: null,
            databaseErrors: {
                constraintViolations: 0,
                connectionFailures: 0,
                lastConstraintError: null
            }
        };

        // Chat state
        this.currentConversationId = null;
        this.currentListing = null;
        this.selectedFiles = [];
        this.isCurrentUserLandlord = false;

        // Conversation management
        this.globalUserConversations = [];
        this.globalUnreadCount = 0;
        this.locallyReadConversations = new Set();

        // Connection monitoring
        this.connectionMonitor = {
            isOnline: navigator.onLine,
            lastPingTime: null,
            pingInterval: null,
            reconnectAttempts: 0,
            maxReconnectAttempts: 5
        };

        // Event listeners
        this.eventListeners = new Map();

        // Bind methods
        this.bindMethods();
    }

    /**
     * Bind all methods to preserve `this` context
     */
    bindMethods() {
        this.setupChat = this.setupChat.bind(this);
        this.sendMessage = this.sendMessage.bind(this);
        this.loadMessages = this.loadMessages.bind(this);
        this.startConversation = this.startConversation.bind(this);
        this.handleOnline = this.handleOnline.bind(this);
        this.handleOffline = this.handleOffline.bind(this);
        this.pingSupabase = this.pingSupabase.bind(this);
    }

    /**
     * Initialize the chat system
     * @param {Object} supabaseClient - Initialized Supabase client
     * @param {Object} options - Configuration options
     */
    async initialize(supabaseClient, options = {}) {
        console.log('🔧 Initializing Chat System...');
        
        if (!supabaseClient) {
            throw new Error('Supabase client is required for chat system initialization');
        }

        this.supabase = supabaseClient;
        this.options = {
            maxFileSize: options.maxFileSize || 5 * 1024 * 1024, // 5MB default
            allowedFileTypes: options.allowedFileTypes || ['.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png', '.txt'],
            enableDiagnostics: options.enableDiagnostics || false,
            enablePolling: options.enablePolling || true,
            pollingInterval: options.pollingInterval || 3000,
            ...options
        };

        try {
            await this.setupChat();
            this.initializeConnectionMonitoring();
            this.setupMessagingPanel();
            
            if (this.options.enableDiagnostics) {
                this.createChatDiagnosticsPanel();
            }

            console.log('✅ Chat System initialized successfully');
            return true;
        } catch (error) {
            console.error('❌ Chat System initialization failed:', error);
            this.chatSystemStatus.errors.push({
                timestamp: new Date(),
                error: 'Initialization failed',
                details: error.message
            });
            throw error;
        }
    }

    /**
     * Setup chat system with health checks and error recovery
     */
    async setupChat() {
        console.log('🔧 Setting up chat system...');
        this.chatSystemStatus.setupAttempts++;
        
        // Perform comprehensive health check
        const healthCheck = this.performChatHealthCheck();
        if (!healthCheck.healthy) {
            console.error('❌ Chat health check failed:', healthCheck);
            this.chatSystemStatus.errors.push({
                timestamp: new Date(),
                error: 'Health check failed',
                details: healthCheck.issues
            });

            // Attempt auto-recovery
            if (this.chatSystemStatus.setupAttempts <= 3) {
                console.log(`🔄 Attempting chat auto-recovery (attempt ${this.chatSystemStatus.setupAttempts}/3)...`);
                await new Promise(resolve => setTimeout(resolve, 2000));
                return this.setupChat();
            } else {
                console.error('💥 Chat system setup failed after 3 attempts');
                this.displayChatSystemError();
                throw new Error('Chat system setup failed after multiple attempts');
            }
        }

        // Get DOM elements
        const chatModal = document.getElementById('chatModal');
        const chatCloseButton = document.querySelector('.chat-close-button');
        const chatMessagesContainer = document.getElementById('chatMessages');
        const chatInput = document.getElementById('chatInput');
        const chatSendBtn = document.getElementById('chatSendBtn');

        console.log('✅ All chat elements found:', {
            chatModal: !!chatModal,
            chatCloseButton: !!chatCloseButton,
            chatMessagesContainer: !!chatMessagesContainer,
            chatInput: !!chatInput,
            chatSendBtn: !!chatSendBtn
        });

        this.chatSystemStatus.elementsReady = true;

        // Setup event listeners
        this.setupEventListeners();

        // Initialize file upload functionality
        this.initializeFileUpload();

        // Setup real-time subscription
        this.setupRealtimeSubscription();

        // Mark chat system as successfully initialized
        this.chatSystemStatus.isInitialized = true;
        this.chatSystemStatus.lastHealthCheck = this.performChatHealthCheck();
        
        console.log('✅ Chat system setup completed successfully!', this.chatSystemStatus);
        
        // Remove any existing error messages since setup was successful
        const errorDiv = document.getElementById('chat-system-error');
        if (errorDiv) {
            errorDiv.remove();
        }
    }

    /**
     * Setup event listeners for chat functionality
     */
    setupEventListeners() {
        const chatModal = document.getElementById('chatModal');
        const chatCloseButton = document.querySelector('.chat-close-button');
        const chatInput = document.getElementById('chatInput');
        const chatSendBtn = document.getElementById('chatSendBtn');

        // Close modal listeners
        if (chatCloseButton) {
            chatCloseButton.addEventListener('click', () => {
                chatModal.classList.remove('active');
                console.log('Chat modal closed');
            });
        }

        // Click outside to close
        window.addEventListener('click', (event) => {
            if (event.target === chatModal) {
                chatModal.classList.remove('active');
                console.log('Chat modal closed by clicking outside');
            }
        });

        // Send message listeners
        if (chatSendBtn) {
            chatSendBtn.addEventListener('click', this.sendMessage);
        }

        // Enter key support
        if (chatInput) {
            chatInput.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    this.sendMessage();
                }
            });
        }
    }

    /**
     * Initialize file upload functionality
     */
    initializeFileUpload() {
        const fileInput = document.getElementById('fileInput');
        const selectedFilesContainer = document.getElementById('selectedFiles');
        const fileUploadBtn = document.getElementById('fileUploadBtn');

        if (!fileInput || !selectedFilesContainer || !fileUploadBtn) {
            console.warn('File upload elements not found');
            return;
        }

        fileInput.addEventListener('change', (e) => {
            const files = Array.from(e.target.files);
            this.selectedFiles = files;
            this.displaySelectedFiles(files);
        });

        // Global function for removing files
        window.removeFileFromChat = (index) => {
            this.selectedFiles.splice(index, 1);
            this.displaySelectedFiles(this.selectedFiles);
            
            // Update file input
            const dt = new DataTransfer();
            this.selectedFiles.forEach(file => dt.items.add(file));
            fileInput.files = dt.files;
        };
    }

    /**
     * Display selected files in the UI
     */
    displaySelectedFiles(files) {
        const selectedFilesContainer = document.getElementById('selectedFiles');
        
        if (files.length === 0) {
            selectedFilesContainer.classList.add('hidden');
            return;
        }

        selectedFilesContainer.classList.remove('hidden');
        selectedFilesContainer.innerHTML = files.map((file, index) => `
            <div class="flex items-center justify-between bg-gray-100 p-2 rounded">
                <div class="flex items-center space-x-2">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-gray-600">
                        <path d="M7.5 18A5.5 5.5 0 0 1 2 12.5A5.5 5.5 0 0 1 7.5 7H18A4 4 0 0 1 22 11A4 4 0 0 1 18 15H9.5A2.5 2.5 0 0 1 7 12.5A2.5 2.5 0 0 1 9.5 10H17V11.5H9.5A1 1 0 0 0 8.5 12.5A1 1 0 0 0 9.5 13.5H18A2.5 2.5 0 0 0 20.5 11A2.5 2.5 0 0 0 18 8.5H7.5A4 4 0 0 0 3.5 12.5A4 4 0 0 0 7.5 16.5H17V18H7.5Z"/>
                    </svg>
                    <span class="text-sm text-gray-700">${file.name}</span>
                    <span class="text-xs text-gray-500">(${this.formatFileSize(file.size)})</span>
                </div>
                <button onclick="window.removeFileFromChat(${index})" class="text-red-500 hover:text-red-700 text-sm">×</button>
            </div>
        `).join('');
    }

    /**
     * Send message (text and/or files)
     */
    async sendMessage() {
        const chatInput = document.getElementById('chatInput');
        const messageContent = chatInput.value.trim();
        
        // Check if we have content or files to send
        if (!messageContent && (!this.selectedFiles || this.selectedFiles.length === 0)) {
            console.warn('No message content or files to send');
            return;
        }

        if (!this.currentConversationId) {
            console.warn('No conversation ID');
            return;
        }

        const currentUser = JSON.parse(null);
        if (!currentUser) {
            console.error('No authenticated user');
            return;
        }

        const timestamp = new Date().toISOString();

        try {
            // Send text message if there's content
            if (messageContent) {
                await this.sendTextMessage(messageContent, currentUser, timestamp);
                chatInput.value = '';
            }

            // Send files if any are selected and user is landlord
            if (this.selectedFiles && this.selectedFiles.length > 0 && this.isCurrentUserLandlord) {
                for (const file of this.selectedFiles) {
                    await this.sendFileMessage(file, currentUser, timestamp);
                }
                
                // Clear selected files
                this.selectedFiles = [];
                const fileInput = document.getElementById('fileInput');
                if (fileInput) fileInput.value = '';
                const selectedFilesContainer = document.getElementById('selectedFiles');
                if (selectedFilesContainer) selectedFilesContainer.classList.add('hidden');
            }

        } catch (error) {
            console.error('❌ Error sending message/files:', error);
            this.showConnectionNotification('Failed to send message: ' + error.message, 'error');
        }
    }

    /**
     * Send text message
     */
    async sendTextMessage(messageContent, currentUser, timestamp) {
        const chatMessagesContainer = document.getElementById('chatMessages');
        
        // Instant UI update
        const messageElement = document.createElement('div');
        messageElement.className = 'message sent';
        messageElement.innerHTML = `
            <p>${this.sanitizeInput(messageContent)}</p>
            <div class="message-timestamp">${new Date(timestamp).toLocaleTimeString()}</div>
        `;
        chatMessagesContainer.appendChild(messageElement);
        chatMessagesContainer.scrollTop = chatMessagesContainer.scrollHeight;
        
        // Send to database
        const { error } = await this.supabase
            .from('messages')
            .insert({
                conversation_id: this.currentConversationId,
                sender_email: currentUser.email,
                content: messageContent,
                message_type: 'text',
                created_at: timestamp
            });

        if (error) {
            messageElement.remove();
            const chatInput = document.getElementById('chatInput');
            if (chatInput) chatInput.value = messageContent; // Restore message
            throw error;
        }
    }

    /**
     * Send file message
     */
    async sendFileMessage(file, currentUser, timestamp) {
        const chatMessagesContainer = document.getElementById('chatMessages');
        
        // Validate file size
        if (file.size > this.options.maxFileSize) {
            throw new Error(`File ${file.name} is too large. Maximum size is ${this.formatFileSize(this.options.maxFileSize)}.`);
        }

        // Show uploading status
        const messageElement = document.createElement('div');
        messageElement.className = 'message sent';
        messageElement.innerHTML = `
            <div class="file-message bg-blue-50 p-3 rounded">
                <div class="flex items-center space-x-2">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-blue-600">
                        <path d="M7.5 18A5.5 5.5 0 0 1 2 12.5A5.5 5.5 0 0 1 7.5 7H18A4 4 0 0 1 22 11A4 4 0 0 1 18 15H9.5A2.5 2.5 0 0 1 7 12.5A2.5 2.5 0 0 1 9.5 10H17V11.5H9.5A1 1 0 0 0 8.5 12.5A1 1 0 0 0 9.5 13.5H18A2.5 2.5 0 0 0 20.5 11A2.5 2.5 0 0 0 18 8.5H7.5A4 4 0 0 0 3.5 12.5A4 4 0 0 0 7.5 16.5H17V18H7.5Z"/>
                    </svg>
                    <div>
                        <p class="font-medium text-blue-900">${file.name}</p>
                        <p class="text-sm text-blue-600">Uploading... (${this.formatFileSize(file.size)})</p>
                    </div>
                </div>
            </div>
            <div class="message-timestamp">${new Date(timestamp).toLocaleTimeString()}</div>
        `;
        chatMessagesContainer.appendChild(messageElement);
        chatMessagesContainer.scrollTop = chatMessagesContainer.scrollHeight;

        try {
            // Upload file to Supabase storage
            const fileName = `chat-${this.currentConversationId}-${Date.now()}-${file.name}`;
            const filePath = `chat-files/${fileName}`;

            const { data: uploadData, error: uploadError } = await this.supabase.storage
                .from('chat-documents')
                .upload(filePath, file, {
                    contentType: file.type,
                    upsert: false
                });

            if (uploadError) {
                throw new Error('Failed to upload file: ' + uploadError.message);
            }

            // Get public URL
            const { data: urlData } = this.supabase.storage
                .from('chat-documents')
                .getPublicUrl(filePath);

            // Save message to database
            const { error: dbError } = await this.supabase
                .from('messages')
                .insert({
                    conversation_id: this.currentConversationId,
                    sender_email: currentUser.email,
                    content: `Shared file: ${file.name}`,
                    message_type: 'file',
                    file_url: urlData.publicUrl,
                    file_name: file.name,
                    file_size: file.size,
                    file_type: file.type,
                    created_at: timestamp
                });

            if (dbError) {
                throw new Error('Failed to save message: ' + dbError.message);
            }

            // Update UI with download link
            messageElement.innerHTML = `
                <div class="file-message bg-blue-50 p-3 rounded">
                    <div class="flex items-center space-x-2">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-blue-600">
                            <path d="M7.5 18A5.5 5.5 0 0 1 2 12.5A5.5 5.5 0 0 1 7.5 7H18A4 4 0 0 1 22 11A4 4 0 0 1 18 15H9.5A2.5 2.5 0 0 1 7 12.5A2.5 2.5 0 0 1 9.5 10H17V11.5H9.5A1 1 0 0 0 8.5 12.5A1 1 0 0 0 9.5 13.5H18A2.5 2.5 0 0 0 20.5 11A2.5 2.5 0 0 0 18 8.5H7.5A4 4 0 0 0 3.5 12.5A4 4 0 0 0 7.5 16.5H17V18H7.5Z"/>
                        </svg>
                        <div>
                            <p class="font-medium text-blue-900">${file.name}</p>
                            <p class="text-sm text-blue-600">${this.formatFileSize(file.size)}</p>
                            <a href="${urlData.publicUrl}" target="_blank" class="text-blue-800 hover:text-blue-900 text-sm font-medium inline-flex items-center space-x-1">
                                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
                                    <polyline points="7,10 12,15 17,10"/>
                                    <line x1="12" y1="15" x2="12" y2="3"/>
                                </svg>
                                <span>Download</span>
                            </a>
                        </div>
                    </div>
                </div>
                <div class="message-timestamp">${new Date(timestamp).toLocaleTimeString()}</div>
            `;

            console.log('✅ File sent successfully:', file.name);

        } catch (error) {
            messageElement.remove();
            throw error;
        }
    }

    /**
     * Load messages for a conversation
     */
    async loadMessages(conversationId) {
        console.log('🔄 Loading messages for conversation:', conversationId);
        
        try {
            const { data: messages, error } = await this.supabase
                .from('messages')
                .select('*')
                .eq('conversation_id', conversationId)
                .order('created_at', { ascending: true });

            if (error) {
                console.error('❌ Error loading messages:', error);
                throw error;
            }

            const chatMessagesContainer = document.getElementById('chatMessages');
            if (!chatMessagesContainer) {
                console.error('❌ Chat messages container not found!');
                return;
            }
            
            chatMessagesContainer.innerHTML = '';
            const currentUser = JSON.parse(null);

            messages.forEach((message) => {
                const messageElement = document.createElement('div');
                messageElement.className = `message ${message.sender_email === currentUser.email ? 'sent' : 'received'}`;
                
                // Handle different message types
                let messageContent;
                if (message.message_type === 'file' && message.file_url) {
                    const isOwner = message.sender_email === currentUser.email;
                    messageContent = `
                        <div class="file-message ${isOwner ? 'bg-blue-50' : 'bg-gray-50'} p-3 rounded">
                            <div class="flex items-center space-x-2">
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="${isOwner ? 'text-blue-600' : 'text-gray-600'}">
                                    <path d="M7.5 18A5.5 5.5 0 0 1 2 12.5A5.5 5.5 0 0 1 7.5 7H18A4 4 0 0 1 22 11A4 4 0 0 1 18 15H9.5A2.5 2.5 0 0 1 7 12.5A2.5 2.5 0 0 1 9.5 10H17V11.5H9.5A1 1 0 0 0 8.5 12.5A1 1 0 0 0 9.5 13.5H18A2.5 2.5 0 0 0 20.5 11A2.5 2.5 0 0 0 18 8.5H7.5A4 4 0 0 0 3.5 12.5A4 4 0 0 0 7.5 16.5H17V18H7.5Z"/>
                                </svg>
                                <div>
                                    <p class="font-medium ${isOwner ? 'text-blue-900' : 'text-gray-900'}">${this.sanitizeInput(message.file_name || 'File')}</p>
                                    <p class="text-sm ${isOwner ? 'text-blue-600' : 'text-gray-600'}">${message.file_size ? this.formatFileSize(message.file_size) : ''}</p>
                                    <a href="${message.file_url}" target="_blank" class="${isOwner ? 'text-blue-800 hover:text-blue-900' : 'text-gray-800 hover:text-gray-900'} text-sm font-medium inline-flex items-center space-x-1">
                                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
                                            <polyline points="7,10 12,15 17,10"/>
                                            <line x1="12" y1="15" x2="12" y2="3"/>
                                        </svg>
                                        <span>Download</span>
                                    </a>
                                </div>
                            </div>
                        </div>
                    `;
                } else {
                    messageContent = `<p>${this.sanitizeInput(message.content)}</p>`;
                }
                
                messageElement.innerHTML = `
                    ${messageContent}
                    <div class="message-timestamp">${new Date(message.created_at).toLocaleTimeString()}</div>
                `;
                chatMessagesContainer.appendChild(messageElement);
            });

            chatMessagesContainer.scrollTop = chatMessagesContainer.scrollHeight;
            console.log('✅ Messages loaded successfully:', messages.length, 'messages displayed');
            
        } catch (error) {
            console.error('💥 Exception in loadMessages:', error);
            throw error;
        }
    }

    /**
     * Start a conversation for a listing
     */
    async startConversation(listing) {
        try {
            console.log('🚀 Starting conversation for listing:', listing?.title || 'Unknown listing');
        
            // Verify authentication
            const currentUser = JSON.parse(null);
            if (!currentUser) {
                console.error('❌ No authenticated user found');
                this.showConnectionNotification('Please log in to start a chat.', 'warning');
                return;
            }

            if (!listing.user_email) {
                console.error('❌ Listing missing user_email:', listing);
                this.showConnectionNotification('Cannot start chat: Listing owner not specified.', 'error');
                return;
            }

            // Auto-create profiles if needed
            await this.ensureUserProfiles(currentUser, listing);

            // Set up chat UI
            this.currentListing = listing;
            const chatTitle = document.getElementById('chatTitle');
            if (chatTitle) {
                chatTitle.textContent = `Chat about ${listing.title}`;
            }

            // Check for existing conversation or create new one
            let conversation = await this.findOrCreateConversation(currentUser, listing);
            this.currentConversationId = conversation.id;
            
            // Load messages and show modal
            await this.loadMessages(conversation.id);
            
            // Show file upload button only for listing owners
            const fileUploadBtn = document.getElementById('fileUploadBtn');
            this.isCurrentUserLandlord = currentUser.email === listing.user_email;
            if (fileUploadBtn) {
                if (this.isCurrentUserLandlord) {
                    fileUploadBtn.classList.remove('hidden');
                } else {
                    fileUploadBtn.classList.add('hidden');
                }
            }
            
            const chatModal = document.getElementById('chatModal');
            if (chatModal) {
                chatModal.classList.add('active');
                console.log('✅ Chat modal opened for conversation:', conversation.id);
            }

        } catch (error) {
            console.error('❌ Error starting conversation:', error);
            this.showConnectionNotification('Failed to start chat: ' + error.message, 'error');
        }
    }

    /**
     * Ensure user profiles exist for both users
     */
    async ensureUserProfiles(currentUser, listing) {
        // Check current user profile
        const { data: currentProfile, error: currentError } = await this.supabase
            .from('profiles')
            .select('email')
            .eq('email', currentUser.email)
            .single();

        if (currentError || !currentProfile) {
            await this.supabase
                .from('profiles')
                .insert({
                    email: currentUser.email,
                    first_name: currentUser.firstName || 'User',
                    last_name: currentUser.lastName || '',
                    created_at: new Date().toISOString()
                });
        }

        // Check listing owner profile
        const { data: ownerProfile, error: ownerError } = await this.supabase
            .from('profiles')
            .select('email')
            .eq('email', listing.user_email)
            .single();

        if (ownerError || !ownerProfile) {
            await this.supabase
                .from('profiles')
                .insert({
                    email: listing.user_email,
                    first_name: 'User',
                    last_name: '',
                    created_at: new Date().toISOString()
                });
        }
    }

    /**
     * Find existing conversation or create new one
     */
    async findOrCreateConversation(currentUser, listing) {
        const { data: conversations, error } = await this.supabase
            .from('conversations')
            .select('*')
            .eq('listing_id', listing.id)
            .eq('sender_email', currentUser.email)
            .eq('receiver_email', listing.user_email);

        if (error) {
            throw error;
        }

        if (conversations && conversations.length > 0) {
            return conversations[0];
        }

        // Create new conversation
        const { data, error: insertError } = await this.supabase
            .from('conversations')
            .insert({
                listing_id: listing.id,
                sender_email: currentUser.email,
                receiver_email: listing.user_email,
                created_at: new Date().toISOString()
            })
            .select()
            .single();

        if (insertError) {
            throw insertError;
        }

        return data;
    }

    /**
     * Setup real-time subscription for messages
     */
    setupRealtimeSubscription() {
        // Validate supabase client
        if (!this.supabase) {
            console.warn('⚠️ Supabase client not available for real-time subscription');
            return;
        }

        if (typeof this.supabase.channel !== 'function') {
            console.warn('⚠️ Supabase client does not have channel method, skipping real-time setup');
            return;
        }

        try {
            const messageChannel = this.supabase
                .channel('messages_realtime_' + Math.random())
                .on('postgres_changes', {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'messages'
                }, (payload) => {
                    console.log('🔔 REALTIME EVENT RECEIVED:', payload);

                    if (this.currentConversationId && this.currentConversationId === payload.new.conversation_id) {
                        console.log('✅ Message is for current conversation!');
                        this.loadMessages(this.currentConversationId);
                    }
                })
                .subscribe((status) => {
                    console.log('💬 REALTIME SUBSCRIPTION STATUS:', status);
                    if (status === 'SUBSCRIBED') {
                        console.log('✅ Successfully subscribed to messages!');
                    } else if (status === 'CHANNEL_ERROR') {
                        console.error('❌ Channel error - real-time not working');
                        this.chatSystemStatus.databaseErrors.connectionFailures++;
                    } else if (status === 'TIMED_OUT') {
                        console.error('⏰ Subscription timed out');
                    }
                });

            console.log('✅ Real-time subscription setup complete');
        } catch (error) {
            console.error('❌ Error setting up real-time subscription:', error);
            // Non-fatal error - continue without real-time
        }

        this.messageChannel = messageChannel;
    }

    /**
     * Setup messaging panel for conversation management
     */
    setupMessagingPanel() {
        const messageToggleBtn = document.getElementById('messageToggleBtn');
        const messagePanel = document.getElementById('messagePanel');
        
        if (!messageToggleBtn || !messagePanel) {
            console.warn('Messaging panel elements not found');
            return;
        }

        let isMessagingPanelOpen = false;

        messageToggleBtn.addEventListener('click', async () => {
            isMessagingPanelOpen = !isMessagingPanelOpen;
            if (isMessagingPanelOpen) {
                messagePanel.classList.remove('hidden');
                await this.loadUserConversations();
            } else {
                messagePanel.classList.add('hidden');
            }
        });

        // Close panel when clicking outside
        document.addEventListener('click', (event) => {
            if (!event.target.closest('#messagingPanel')) {
                messagePanel.classList.add('hidden');
                isMessagingPanelOpen = false;
            }
        });

        // Setup real-time updates for messaging panel
        this.setupMessagingPanelRealtime();
    }

    /**
     * Load user conversations
     */
    async loadUserConversations() {
        const currentUser = JSON.parse(null);
        if (!currentUser) return;

        try {
            const { data: conversations, error } = await this.supabase
                .from('conversations')
                .select(`
                    *,
                    listings (title, id)
                `)
                .or(`sender_email.eq.${currentUser.email},receiver_email.eq.${currentUser.email}`)
                .order('created_at', { ascending: false });

            if (error) {
                console.error('Error loading conversations:', error);
                return;
            }

            // Get unread counts for each conversation
            const conversationsWithUnread = [];
            for (const conv of conversations || []) {
                const { data: readData } = await this.supabase
                    .from('conversation_reads')
                    .select('last_read_at')
                    .eq('conversation_id', conv.id)
                    .eq('user_email', currentUser.email)
                    .maybeSingle();

                const lastReadAt = readData?.last_read_at || '1970-01-01T00:00:00Z';

                const { count: unreadCount } = await this.supabase
                    .from('messages')
                    .select('*', { count: 'exact', head: true })
                    .eq('conversation_id', conv.id)
                    .neq('sender_email', currentUser.email)
                    .gt('created_at', lastReadAt);

                conv.unread_count = unreadCount || 0;
                conversationsWithUnread.push(conv);
            }

            this.globalUserConversations = conversationsWithUnread;
            this.displayConversations();
            this.updateUnreadCount();

        } catch (error) {
            console.error('Error loading conversations:', error);
        }
    }

    /**
     * Display conversations in the messaging panel
     */
    displayConversations() {
        const conversationTabs = document.getElementById('conversationTabs');
        if (!conversationTabs) return;

        const currentUser = JSON.parse(null);
        
        if (this.globalUserConversations.length === 0) {
            conversationTabs.innerHTML = '<div class="p-4 text-gray-500 text-center">No conversations yet</div>';
            return;
        }

        conversationTabs.innerHTML = this.globalUserConversations.map(conv => {
            const otherUserEmail = conv.sender_email === currentUser.email ? conv.receiver_email : conv.sender_email;
            const listingTitle = conv.listings ? conv.listings.title : 'Unknown Listing';
            const otherUserName = otherUserEmail.split('@')[0];
            const hasUnread = conv.unread_count > 0;
            const unreadBadge = hasUnread ? `<span class="bg-red-500 text-white rounded-full w-5 h-5 text-xs flex items-center justify-center ml-2">${conv.unread_count}</span>` : '';
            
            return `
                <div class="border-b hover:bg-gray-50 cursor-pointer ${hasUnread ? 'bg-blue-50' : ''}" onclick="chatSystem.openConversationInModal('${conv.id}', '${listingTitle}', '${conv.listing_id}', '${otherUserEmail}')">
                    <div class="p-3">
                        <div class="flex justify-between items-start">
                            <div class="flex-1">
                                <div class="font-medium text-sm text-gray-900 flex items-center">
                                    ${otherUserName}
                                    ${unreadBadge}
                                </div>
                                <div class="text-xs text-gray-600">${listingTitle}</div>
                                <div class="text-xs text-gray-400 mt-1">
                                    ${new Date(conv.created_at).toLocaleDateString()}
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            `;
        }).join('');
    }

    /**
     * Open conversation in modal
     */
    async openConversationInModal(conversationId, listingTitle, listingId, otherUserEmail) {
        // Close messaging panel
        const messagePanel = document.getElementById('messagePanel');
        if (messagePanel) {
            messagePanel.classList.add('hidden');
        }
        
        // Mark as read
        this.locallyReadConversations.add(conversationId);
        
        // Update conversation in local array
        const convIndex = this.globalUserConversations.findIndex(c => c.id === conversationId);
        if (convIndex !== -1) {
            this.globalUserConversations[convIndex].unread_count = 0;
        }
        
        this.updateUnreadCount();
        
        // Set up chat modal
        this.currentConversationId = conversationId;
        const otherUserName = otherUserEmail ? otherUserEmail.split('@')[0] : 'User';
        const chatTitle = document.getElementById('chatTitle');
        if (chatTitle) {
            chatTitle.textContent = `Chat with ${otherUserName} about ${listingTitle}`;
        }
        
        await this.loadMessages(conversationId);
        
        const chatModal = document.getElementById('chatModal');
        if (chatModal) {
            chatModal.classList.add('active');
        }
        
        // Update database in background
        this.markConversationAsRead(conversationId);
    }

    /**
     * Mark conversation as read in database
     */
    async markConversationAsRead(conversationId) {
        const currentUser = JSON.parse(null);
        if (!currentUser) return;

        try {
            await this.supabase
                .from('conversation_reads')
                .upsert({
                    conversation_id: conversationId,
                    user_email: currentUser.email,
                    last_read_at: new Date().toISOString()
                }, {
                    onConflict: 'conversation_id,user_email'
                });
        } catch (error) {
            console.error('Error marking conversation as read:', error);
        }
    }

    /**
     * Update unread message count
     */
    updateUnreadCount() {
        const messageNotificationBadge = document.getElementById('messageNotificationBadge');
        const profileNotificationBadge = document.getElementById('profileNotificationBadge');
        
        if (!messageNotificationBadge || !profileNotificationBadge) return;

        let totalUnread = 0;
        for (const conv of this.globalUserConversations) {
            const isLocallyRead = this.locallyReadConversations.has(conv.id);
            const unreadCount = isLocallyRead ? 0 : (conv.unread_count || 0);
            
            if (unreadCount > 0) {
                totalUnread += unreadCount;
            }
        }
        
        if (totalUnread === 0) {
            messageNotificationBadge.classList.add('hidden');
            profileNotificationBadge.classList.add('hidden');
        } else {
            messageNotificationBadge.textContent = totalUnread;
            messageNotificationBadge.classList.remove('hidden');
            profileNotificationBadge.textContent = totalUnread;
            profileNotificationBadge.classList.remove('hidden');
        }
        
        this.globalUnreadCount = totalUnread;
    }

    /**
     * Setup real-time updates for messaging panel
     */
    setupMessagingPanelRealtime() {
        const panelChannel = this.supabase
            .channel('panel_realtime_' + Math.random())
            .on('postgres_changes', { 
                event: 'INSERT', 
                schema: 'public', 
                table: 'messages' 
            }, (payload) => {
                console.log('🔔 PANEL: New message event:', payload);
                const currentUser = JSON.parse(null);
                
                if (payload.new.sender_email !== currentUser.email) {
                    const convIndex = this.globalUserConversations.findIndex(c => c.id === payload.new.conversation_id);
                    if (convIndex !== -1 && !this.locallyReadConversations.has(payload.new.conversation_id)) {
                        this.globalUserConversations[convIndex].unread_count = 
                            (this.globalUserConversations[convIndex].unread_count || 0) + 1;
                        this.updateUnreadCount();
                    }
                }
            })
            .subscribe((status) => {
                console.log('📱 PANEL SUBSCRIPTION STATUS:', status);
            });

        this.panelChannel = panelChannel;
    }

    /**
     * Initialize connection monitoring
     */
    initializeConnectionMonitoring() {
        console.log('🌐 Initializing connection monitoring...');
        
        window.addEventListener('online', this.handleOnline);
        window.addEventListener('offline', this.handleOffline);
        
        // Start periodic ping
        this.connectionMonitor.pingInterval = setInterval(this.pingSupabase, 30000);
        this.pingSupabase();
    }

    /**
     * Handle online event
     */
    handleOnline() {
        console.log('🌐 Connection restored');
        this.connectionMonitor.isOnline = true;
        this.connectionMonitor.reconnectAttempts = 0;
        this.showConnectionNotification('Connection restored! Chat is back online.', 'success');
        
        if (!this.chatSystemStatus.isInitialized) {
            setTimeout(() => {
                this.setupChat();
            }, 1000);
        }
    }

    /**
     * Handle offline event
     */
    handleOffline() {
        console.log('🌐 Connection lost');
        this.connectionMonitor.isOnline = false;
        this.showConnectionNotification('Connection lost. Chat may not work properly.', 'warning');
    }

    /**
     * Ping Supabase to check connection
     */
    async pingSupabase() {
        if (!this.supabase) return;

        try {
            const { data, error } = await this.supabase
                .from('conversations')
                .select('count')
                .limit(1);

            if (error) throw error;

            this.connectionMonitor.lastPingTime = new Date();
            this.chatSystemStatus.supabaseConnected = true;
            
        } catch (error) {
            console.error('📡 Supabase ping failed:', error);
            this.chatSystemStatus.supabaseConnected = false;
            this.handleSupabaseConnectionError(error);
        }
    }

    /**
     * Handle Supabase connection error
     */
    handleSupabaseConnectionError(error) {
        this.connectionMonitor.reconnectAttempts++;
        
        if (this.connectionMonitor.reconnectAttempts <= this.connectionMonitor.maxReconnectAttempts) {
            console.log(`🔄 Attempting to reconnect (${this.connectionMonitor.reconnectAttempts}/${this.connectionMonitor.maxReconnectAttempts})`);
            
            this.showConnectionNotification(
                `Database connection issue. Retrying... (${this.connectionMonitor.reconnectAttempts}/${this.connectionMonitor.maxReconnectAttempts})`,
                'warning'
            );
            
            const delay = Math.min(1000 * Math.pow(2, this.connectionMonitor.reconnectAttempts), 30000);
            setTimeout(() => this.pingSupabase(), delay);
        } else {
            console.error('💥 Max reconnection attempts reached');
            this.showConnectionNotification(
                'Database connection failed. Chat may not work properly. Please refresh the page.',
                'error'
            );
        }
    }

    /**
     * Show connection notification
     */
    showConnectionNotification(message, type = 'info') {
        // Remove existing notification
        const existing = document.getElementById('connection-notification');
        if (existing) {
            existing.remove();
        }

        const colors = {
            success: { bg: '#d1fae5', border: '#10b981', text: '#065f46' },
            warning: { bg: '#fef3c7', border: '#f59e0b', text: '#92400e' },
            error: { bg: '#fee2e2', border: '#ef4444', text: '#991b1b' },
            info: { bg: '#dbeafe', border: '#3b82f6', text: '#1e40af' }
        };

        const color = colors[type] || colors.info;

        const notification = document.createElement('div');
        notification.id = 'connection-notification';
        notification.style.cssText = `
            position: fixed;
            top: 70px;
            right: 20px;
            background: ${color.bg};
            border: 1px solid ${color.border};
            color: ${color.text};
            padding: 12px 16px;
            border-radius: 8px;
            font-family: Arial, sans-serif;
            font-size: 14px;
            max-width: 350px;
            z-index: 9999;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            animation: slideInRight 0.3s ease-out;
        `;

        notification.innerHTML = `
            <div style="display: flex; align-items: center; justify-content: space-between;">
                <span>${message}</span>
                <button onclick="this.parentElement.parentElement.remove()" style="
                    background: none; 
                    border: none; 
                    color: ${color.text}; 
                    font-size: 18px; 
                    cursor: pointer;
                    margin-left: 10px;
                ">×</button>
            </div>
        `;

        document.body.appendChild(notification);

        // Auto-remove after delay
        const autoRemoveDelay = (type === 'success' || type === 'info') ? 5000 : 10000;
        setTimeout(() => {
            if (notification.parentElement) {
                notification.remove();
            }
        }, autoRemoveDelay);
    }

    /**
     * Perform health check
     */
    performChatHealthCheck() {
        const issues = [];
        
        const requiredElements = [
            { id: 'chatModal', element: document.getElementById('chatModal') },
            { id: 'chatMessages', element: document.getElementById('chatMessages') },
            { id: 'chatInput', element: document.getElementById('chatInput') },
            { id: 'chatSendBtn', element: document.getElementById('chatSendBtn') },
            { selector: '.chat-close-button', element: document.querySelector('.chat-close-button') }
        ];

        requiredElements.forEach(item => {
            if (!item.element) {
                issues.push(`Missing DOM element: ${item.id || item.selector}`);
            }
        });

        if (!this.supabase) {
            issues.push('Supabase client not initialized');
        }

        const currentUser = JSON.parse(null);
        if (!currentUser) {
            issues.push('No authenticated user (warning only)');
        }

        const isHealthy = issues.filter(issue => !issue.includes('warning only')).length === 0;
        
        return {
            healthy: isHealthy,
            issues: issues,
            elementsFound: requiredElements.filter(item => !!item.element).length,
            totalElements: requiredElements.length,
            timestamp: new Date()
        };
    }

    /**
     * Create diagnostics panel
     */
    createChatDiagnosticsPanel() {
        if (document.getElementById('chat-diagnostics-panel')) {
            return;
        }

        const panel = document.createElement('div');
        panel.id = 'chat-diagnostics-panel';
        panel.style.cssText = `
            position: fixed;
            top: 10px;
            right: 10px;
            width: 300px;
            background: rgba(0, 0, 0, 0.9);
            color: white;
            padding: 15px;
            border-radius: 8px;
            font-family: monospace;
            font-size: 12px;
            z-index: 10000;
            max-height: 400px;
            overflow-y: auto;
            border: 2px solid #4ade80;
        `;

        this.updateDiagnosticsContent();
        document.body.appendChild(panel);

        // Auto-update every 5 seconds
        setInterval(() => this.updateDiagnosticsContent(), 5000);
    }

    /**
     * Update diagnostics content
     */
    updateDiagnosticsContent() {
        const panel = document.getElementById('chat-diagnostics-panel');
        if (!panel) return;

        const currentUser = JSON.parse(null);
        const now = new Date().toLocaleTimeString();

        panel.innerHTML = `
            <div style="border-bottom: 1px solid #4ade80; margin-bottom: 10px; padding-bottom: 8px;">
                <strong>🔧 Chat System Status</strong>
                <button onclick="this.parentElement.parentElement.remove()" style="float: right; background: #dc2626; color: white; border: none; padding: 2px 6px; border-radius: 3px; cursor: pointer;">×</button>
                <br><small>Last Update: ${now}</small>
            </div>

            <div style="margin-bottom: 8px;">
                <strong>System Health:</strong>
                <span style="color: ${this.chatSystemStatus.isInitialized ? '#4ade80' : '#ef4444'}">
                    ${this.chatSystemStatus.isInitialized ? '✅ Healthy' : '❌ Error'}
                </span>
            </div>

            <div style="margin-bottom: 8px;">
                <strong>Components:</strong><br>
                • DOM Elements: <span style="color: ${this.chatSystemStatus.elementsReady ? '#4ade80' : '#ef4444'}">${this.chatSystemStatus.elementsReady ? 'Ready' : 'Missing'}</span><br>
                • Supabase: <span style="color: ${this.chatSystemStatus.supabaseConnected ? '#4ade80' : '#ef4444'}">${this.chatSystemStatus.supabaseConnected ? 'Connected' : 'Disconnected'}</span><br>
                • User Auth: <span style="color: ${currentUser ? '#4ade80' : '#fbbf24'}">${currentUser ? 'Logged In' : 'Anonymous'}</span>
            </div>

            <div style="margin-bottom: 8px;">
                <strong>Setup Info:</strong><br>
                • Attempts: ${this.chatSystemStatus.setupAttempts}<br>
                • Errors: ${this.chatSystemStatus.errors.length}
            </div>

            <div style="margin-bottom: 8px;">
                <strong>Database Stats:</strong><br>
                • Constraint Violations: <span style="color: ${this.chatSystemStatus.databaseErrors.constraintViolations > 0 ? '#fbbf24' : '#4ade80'}">${this.chatSystemStatus.databaseErrors.constraintViolations}</span><br>
                • Connection Failures: <span style="color: ${this.chatSystemStatus.databaseErrors.connectionFailures > 0 ? '#ef4444' : '#4ade80'}">${this.chatSystemStatus.databaseErrors.connectionFailures}</span>
            </div>

            <div style="margin-top: 10px; text-align: center;">
                <button onclick="chatSystem.runDiagnostics()" style="background: #3b82f6; color: white; border: none; padding: 4px 8px; border-radius: 4px; cursor: pointer; margin: 2px;">Run Test</button>
                <button onclick="chatSystem.setupChat()" style="background: #059669; color: white; border: none; padding: 4px 8px; border-radius: 4px; cursor: pointer; margin: 2px;">Retry Setup</button>
            </div>
        `;
    }

    /**
     * Run diagnostics
     */
    runDiagnostics() {
        console.log('🔍 Running comprehensive chat diagnostics...');
        
        const healthCheck = this.performChatHealthCheck();
        console.log('Health Check Result:', healthCheck);
        
        if (this.supabase) {
            this.supabase.from('conversations').select('count').limit(1)
                .then(result => {
                    console.log('✅ Supabase connection test successful:', result);
                })
                .catch(error => {
                    console.error('❌ Supabase connection test failed:', error);
                });
        }
        
        this.updateDiagnosticsContent();
        this.showConnectionNotification('Diagnostics completed. Check console for details.', 'info');
    }

    /**
     * Display chat system error
     */
    displayChatSystemError() {
        console.error('🚨 Displaying chat system error to user');
        
        const errorContainer = document.getElementById('chatMessages') || document.body;
        
        const errorDiv = document.createElement('div');
        errorDiv.id = 'chat-system-error';
        errorDiv.style.cssText = `
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: #fee2e2;
            border: 1px solid #ef4444;
            color: #991b1b;
            padding: 20px;
            border-radius: 8px;
            max-width: 400px;
            z-index: 10001;
            text-align: center;
        `;

        errorDiv.innerHTML = `
            <h3>Chat System Error</h3>
            <p>The chat system encountered an error during initialization. Please refresh the page to try again.</p>
            <button onclick="location.reload()" style="
                background: #dc2626; 
                color: white; 
                border: none; 
                padding: 8px 16px; 
                border-radius: 4px; 
                cursor: pointer;
                margin-top: 10px;
            ">Refresh Page</button>
        `;

        errorContainer.appendChild(errorDiv);
    }

    /**
     * Utility: Format file size
     */
    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    /**
     * Utility: Sanitize input
     */
    sanitizeInput(input) {
        if (typeof input !== 'string') return '';
        return input
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    /**
     * Cleanup resources
     */
    cleanup() {
        console.log('🧹 Cleaning up chat system resources...');
        
        // Clear intervals
        if (this.connectionMonitor.pingInterval) {
            clearInterval(this.connectionMonitor.pingInterval);
        }

        // Remove event listeners
        window.removeEventListener('online', this.handleOnline);
        window.removeEventListener('offline', this.handleOffline);

        // Unsubscribe from channels
        if (this.messageChannel) {
            this.messageChannel.unsubscribe();
        }
        if (this.panelChannel) {
            this.panelChannel.unsubscribe();
        }

        // Clear global functions
        delete window.removeFileFromChat;
        delete window.openConversationInModal;

        console.log('✅ Chat system cleanup completed');
    }

    /**
     * Get system status
     */
    getStatus() {
        return {
            ...this.chatSystemStatus,
            currentConversationId: this.currentConversationId,
            globalUnreadCount: this.globalUnreadCount,
            connectionStatus: this.connectionMonitor
        };
    }
}

// Export the ChatSystem class
export default ChatSystem;

// Also create a global instance for backward compatibility
window.ChatSystem = ChatSystem;

// Initialize with default configuration if running in browser
if (typeof window !== 'undefined' && window.supabase) {
    window.chatSystem = new ChatSystem();
    
    // Auto-initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            if (window.supabase) {
                window.chatSystem.initialize(window.supabase);
            }
        });
    } else if (window.supabase) {
        window.chatSystem.initialize(window.supabase);
    }
}