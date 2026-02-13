/**
 * Chat Controller Module
 * Handles chat system initialization, messaging, and conversation management
 */

class ChatController {
    constructor() {
        this.currentConversationId = null;
        this.currentListing = null;
        this.isInitialized = false;
        this.selectedFiles = [];
        this.isCurrentUserLandlord = false;
        this.userScrolledUp = false; // Track if user manually scrolled up
        this.chatSystemStatus = {
            isInitialized: false,
            elementsReady: false,
            supabaseConnected: false,
            lastHealthCheck: null,
            setupAttempts: 0,
            errors: [],
            databaseErrors: {
                constraintViolations: 0,
                connectionFailures: 0,
                lastConstraintError: null
            }
        };
    }

    /**
     * Initialize the chat system
     */
    async init() {
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
                setTimeout(() => {
                    this.init();
                }, 2000);
                return false;
            } else {
                console.error('💥 Chat system setup failed after 3 attempts');
                this.displayChatSystemError();
                return false;
            }
        }

        this.setupEventListeners();
        this.setupRealtimeSubscription();
        this.initializeFileUpload();
        this.setupScrollTracking();
        this.createScrollToBottomButton();

        // Mark chat system as successfully initialized
        this.chatSystemStatus.isInitialized = true;
        this.chatSystemStatus.lastHealthCheck = this.performChatHealthCheck();
        this.isInitialized = true;

        console.log('✅ Chat system setup completed successfully!', this.chatSystemStatus);

        // Remove any existing error messages since setup was successful
        const errorDiv = document.getElementById('chat-system-error');
        if (errorDiv) {
            errorDiv.remove();
        }

        return true;
    }

    /**
     * Setup event listeners for chat elements
     */
    setupEventListeners() {
        const chatModal = document.getElementById('chatModal');
        const chatCloseButton = document.querySelector('.chat-close-button');
        const chatInput = document.getElementById('chatInput');
        const chatSendBtn = document.getElementById('chatSendBtn');

        if (!chatModal || !chatCloseButton || !chatInput || !chatSendBtn) {
            console.error('❌ Required chat elements not found');
            return;
        }

        this.chatSystemStatus.elementsReady = true;

        // Close button event
        chatCloseButton.addEventListener('click', () => {
            chatModal.classList.remove('active');
            console.log('Chat modal closed');
        });

        // Click outside to close
        window.addEventListener('click', (event) => {
            if (event.target === chatModal) {
                chatModal.classList.remove('active');
                console.log('Chat modal closed by clicking outside');
            }
        });

        // Send button click
        chatSendBtn.addEventListener('click', () => this.sendMessage());

        // Enter key support for instant messaging
        chatInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.sendMessage();
            }
        });
    }

    /**
     * Setup real-time subscription for messages
     */
    setupRealtimeSubscription() {
        const supabase = window.configManager ? window.configManager.getSupabase() : null;
        if (!supabase) {
            console.error('Supabase client not available for real-time subscription');
            return;
        }

        const messageChannel = supabase
            .channel('messages_realtime_' + Math.random())
            .on('postgres_changes', {
                event: 'INSERT',
                schema: 'public',
                table: 'messages'
            }, (payload) => {
                // Only handle messages for current conversation
                if (!this.currentConversationId || this.currentConversationId !== payload.new.conversation_id) {
                    return;
                }

                const currentUser = window.authManager ? window.authManager.getCurrentUser() : null;
                if (!currentUser) return;

                // Skip if this is our own message (already added instantly when sent)
                if (payload.new.sender_email === currentUser.email) {
                    return;
                }

                // Append the new message from other user
                const chatMessagesContainer = document.getElementById('chatMessages');
                if (chatMessagesContainer) {
                    const messageElement = this.createMessageElement(payload.new, currentUser);
                    chatMessagesContainer.appendChild(messageElement);
                    // Scroll to bottom only if user wasn't reading history
                    this.scrollToBottom(false);
                }
            })
            .subscribe();
    }

    /**
     * Start a conversation with a listing owner
     */
    async startConversation(listing) {
        try {
            console.log('🚀 Starting conversation for listing:', listing?.title || 'Unknown listing');

            // Verify authentication
            const currentUser = window.authManager ? window.authManager.getCurrentUser() : null;
            console.log('👤 Authentication check:', {
                hasUser: !!currentUser,
                userEmail: currentUser?.email
            });

            if (!currentUser) {
                console.error('❌ No authenticated user found');
                alert('Please log in to start a chat.');
                if (window.authManager) {
                    window.location.href = '/login';
                }
                return;
            }

            // Verify Supabase connection
            const supabase = window.configManager ? window.configManager.getSupabase() : null;
            if (!supabase) {
                console.error('❌ Supabase client not initialized');
                alert('Connection error. Please refresh the page and try again.');
                return;
            }

            if (!listing.user_email) {
                console.error('❌ Listing missing user_email:', listing);
                alert('Cannot start chat: Listing owner not specified.');
                return;
            }

            console.log('📧 Chat participants:', {
                sender: currentUser.email,
                receiver: listing.user_email,
                listingId: listing.id
            });

            // Verify and create profiles if needed
            await this.ensureUserProfiles(currentUser, listing.user_email, supabase);

            // Set up chat UI
            this.currentListing = listing;
            const chatTitle = document.getElementById('chatTitle');
            if (chatTitle) {
                chatTitle.textContent = `Chat about ${listing.title}`;
            }

            // Find or create conversation
            const conversation = await this.findOrCreateConversation(listing, currentUser, supabase);
            if (!conversation) {
                return;
            }

            this.currentConversationId = conversation.id;

            // Setup file upload - enabled for all users
            this.isCurrentUserLandlord = currentUser.email === listing.user_email;
            this.showFileUploadButton();

            // Load messages and show modal
            await this.loadAndShowChat(conversation.id);

        } catch (error) {
            console.error('❌ Unexpected error in startConversation:', error);
            alert('An unexpected error occurred while opening the chat. Please refresh the page and try again.');
        }
    }

    /**
     * Ensure user profiles exist for both conversation participants
     */
    async ensureUserProfiles(currentUser, listingOwnerEmail, supabase) {
        console.log('🔍 Checking user profiles...');

        try {
            // Check current user profile
            const { data: currentUserProfile, error: currentUserError } = await supabase
                .from('profiles')
                .select('email')
                .eq('email', currentUser.email)
                .single();

            console.log('👤 Current user profile check:', {
                found: !!currentUserProfile,
                error: currentUserError?.message
            });

            // Check listing owner profile
            const { data: listingOwnerProfile, error: listingOwnerError } = await supabase
                .from('profiles')
                .select('email')
                .eq('email', listingOwnerEmail)
                .single();

            console.log('🏠 Listing owner profile check:', {
                found: !!listingOwnerProfile,
                error: listingOwnerError?.message
            });

            // Create missing profiles
            if (currentUserError || !currentUserProfile) {
                await this.createUserProfile(currentUser, supabase);
            }

            if (listingOwnerError || !listingOwnerProfile) {
                await this.createOwnerProfile(listingOwnerEmail, supabase);
            }

        } catch (profileError) {
            console.error('💥 Error checking profiles:', profileError);
            alert('Database connection error. Please try again.');
            throw profileError;
        }
    }

    /**
     * Create user profile
     */
    async createUserProfile(currentUser, supabase) {
        console.log('Creating missing profile for current user...');
        const { error } = await supabase
            .from('profiles')
            .insert([{
                email: currentUser.email,
                first_name: currentUser.firstName || 'User',
                last_name: currentUser.lastName || '',
                created_at: new Date().toISOString()
            }]);

        if (error) {
            console.error('Error creating current user profile:', error);
            alert('Error setting up your profile. Please try refreshing the page.');
            throw error;
        }
        console.log('✅ Created profile for current user');
    }

    /**
     * Create owner profile
     */
    async createOwnerProfile(ownerEmail, supabase) {
        console.log('Creating missing profile for listing owner...');
        const { error } = await supabase
            .from('profiles')
            .insert([{
                email: ownerEmail,
                first_name: 'User',
                last_name: '',
                created_at: new Date().toISOString()
            }]);

        if (error) {
            console.error('Error creating listing owner profile:', error);
            alert('Error setting up chat. Please try again.');
            throw error;
        }
        console.log('✅ Created profile for listing owner');
    }

    /**
     * Find existing conversation or create new one (BIDIRECTIONAL)
     * Checks both directions: currentUser->landlord AND landlord->currentUser
     */
    async findOrCreateConversation(listing, currentUser, supabase) {
        console.log('🔍 Checking for existing conversations (bidirectional)...');

        try {
            const userA = currentUser.email;
            const userB = listing.user_email;

            // Check direction 1: current user as sender
            const { data: conv1, error: err1 } = await supabase
                .from('conversations')
                .select('*')
                .eq('listing_id', listing.id)
                .eq('sender_email', userA)
                .eq('receiver_email', userB)
                .maybeSingle();

            if (err1 && err1.code !== 'PGRST116') {
                console.error('❌ Error checking conversation (direction 1):', err1);
            }

            if (conv1) {
                console.log('✅ Found existing conversation (user->landlord):', conv1.id);
                return conv1;
            }

            // Check direction 2: current user as receiver
            const { data: conv2, error: err2 } = await supabase
                .from('conversations')
                .select('*')
                .eq('listing_id', listing.id)
                .eq('sender_email', userB)
                .eq('receiver_email', userA)
                .maybeSingle();

            if (err2 && err2.code !== 'PGRST116') {
                console.error('❌ Error checking conversation (direction 2):', err2);
            }

            if (conv2) {
                console.log('✅ Found existing conversation (landlord->user):', conv2.id);
                return conv2;
            }

            // No existing conversation - create new one
            console.log('📝 No existing conversation found, creating new...');
            const { data, error: insertError } = await supabase
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
                console.error('❌ Error creating conversation:', insertError);
                alert('Failed to start conversation: ' + insertError.message);
                return null;
            }

            console.log('✅ New conversation created:', data.id);
            return data;

        } catch (queryError) {
            console.error('💥 Error querying conversations:', queryError);
            alert('Database error while loading conversation. Please try again.');
            return null;
        }
    }

    /**
     * Load messages and show chat modal
     */
    async loadAndShowChat(conversationId) {
        const chatModal = document.getElementById('chatModal');
        if (!chatModal) {
            console.error('❌ Chat modal element not found');
            alert('Chat interface error. Please refresh the page.');
            return;
        }

        // Show loading state
        console.log('⏳ Loading messages...');
        const chatMessages = document.getElementById('chatMessages');
        if (chatMessages) {
            chatMessages.innerHTML = '<div style="text-align: center; padding: 20px; color: #6b7280;">Loading messages...</div>';
        }

        try {
            // Reset scroll state when opening chat
            this.userScrolledUp = false;
            await this.loadMessages(conversationId);
            chatModal.classList.add('active');
            // Force scroll to bottom when first opening
            this.scrollToBottom(true);
            console.log('Chat modal opened for conversation:', conversationId);
        } catch (loadError) {
            console.error('❌ Error loading messages:', loadError);
            alert('Failed to load chat messages. Please try again.');
            if (chatMessages) {
                chatMessages.innerHTML = '<div style="text-align: center; padding: 20px; color: #ef4444;">Failed to load messages</div>';
            }
        }
    }

    /**
     * Show file upload button - enabled for all users
     */
    showFileUploadButton() {
        const fileUploadBtn = document.getElementById('fileUploadBtn');
        if (fileUploadBtn) {
            fileUploadBtn.classList.remove('hidden');
            console.log('File upload enabled for user');
        }
        console.log('User role:', this.isCurrentUserLandlord ? 'Landlord' : 'Tenant');
    }

    /**
     * Load messages for a conversation
     */
    async loadMessages(conversationId) {
        console.log('🔄 Loading messages for conversation:', conversationId);

        const supabase = window.configManager ? window.configManager.getSupabase() : null;
        if (!supabase) {
            console.error('❌ Supabase client not available');
            return;
        }

        try {
            const { data: messages, error } = await supabase
                .from('messages')
                .select('*')
                .eq('conversation_id', conversationId)
                .order('created_at', { ascending: true });

            console.log('📨 Messages query result:', { messages, error, count: messages?.length });

            if (error) {
                console.error('❌ Error loading messages:', error);
                alert('Failed to load messages: ' + error.message);
                return;
            }

            const chatMessagesContainer = document.getElementById('chatMessages');
            if (!chatMessagesContainer) {
                console.error('❌ Chat messages container not found!');
                return;
            }

            chatMessagesContainer.innerHTML = '';
            const currentUser = window.authManager ? window.authManager.getCurrentUser() : null;

            messages.forEach((message, index) => {
                console.log(`💬 Processing message ${index + 1}:`, {
                    sender: message.sender_email,
                    content: message.content?.substring(0, 50) + '...',
                    type: message.message_type,
                    timestamp: message.created_at
                });

                const messageElement = this.createMessageElement(message, currentUser);
                chatMessagesContainer.appendChild(messageElement);
            });

            // Only auto-scroll if user hasn't scrolled up to read history
            this.scrollToBottom(false);
            console.log('Messages loaded successfully:', messages.length, 'messages displayed');

        } catch (error) {
            console.error('💥 Exception in loadMessages:', error);
            alert('Failed to load messages due to an error: ' + error.message);
        }
    }

    /**
     * Create a message element
     */
    createMessageElement(message, currentUser) {
        const messageElement = document.createElement('div');
        messageElement.className = `message ${message.sender_email === currentUser.email ? 'sent' : 'received'}`;

        // Handle different message types
        let messageContent;
        if (message.message_type === 'file' && message.file_url) {
            const isOwner = message.sender_email === currentUser.email;
            messageContent = `
                <div class="file-message ${isOwner ? 'bg-blue-50' : 'bg-gray-50'} p-3 rounded">
                    <div class="flex items-center space-x-2">
                        <svg class="w-5 h-5 ${isOwner ? 'text-blue-600' : 'text-gray-600'}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>
                        <div>
                            <p class="font-medium ${isOwner ? 'text-blue-900' : 'text-gray-900'}">${this.sanitizeInput(message.file_name || 'File')}</p>
                            <p class="text-sm ${isOwner ? 'text-blue-600' : 'text-gray-600'}">${message.file_size ? this.formatFileSize(message.file_size) : ''}</p>
                            <a href="${message.file_url}" target="_blank" class="${isOwner ? 'text-blue-800 hover:text-blue-900' : 'text-gray-800 hover:text-gray-900'} text-sm font-medium flex items-center gap-1"><svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path></svg> Download</a>
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

        return messageElement;
    }

    /**
     * Send a message
     */
    async sendMessage() {
        const chatInput = document.getElementById('chatInput');
        const messageContent = chatInput ? chatInput.value.trim() : '';

        // Check if we have content or files to send
        if (!messageContent && (!this.selectedFiles || this.selectedFiles.length === 0)) {
            console.warn('No message content or files to send');
            return;
        }

        if (!this.currentConversationId) {
            console.warn('No conversation ID');
            return;
        }

        const currentUser = window.authManager ? window.authManager.getCurrentUser() : null;
        if (!currentUser) {
            console.error('No current user for sending message');
            return;
        }

        const timestamp = new Date().toISOString();

        try {
            // Send text message if there's content
            if (messageContent) {
                await this.sendTextMessage(messageContent, currentUser, timestamp);
                if (chatInput) {
                    chatInput.value = '';
                }
            }

            // Send files if any are selected - enabled for all users
            if (this.selectedFiles && this.selectedFiles.length > 0) {
                for (const file of this.selectedFiles) {
                    await this.sendFileMessage(file, currentUser, timestamp);
                }

                // Clear selected files
                this.clearSelectedFiles();
            }

        } catch (error) {
            console.error('❌ Error sending message/files:', error);
            alert('Failed to send message: ' + error.message);
        }
    }

    /**
     * Send text message
     */
    async sendTextMessage(messageContent, currentUser, timestamp) {
        const chatMessagesContainer = document.getElementById('chatMessages');
        const supabase = window.configManager ? window.configManager.getSupabase() : null;

        if (!supabase || !chatMessagesContainer) {
            throw new Error('Required elements not available');
        }

        // Instant UI update
        const messageElement = document.createElement('div');
        messageElement.className = 'message sent';
        messageElement.innerHTML = `
            <p>${this.sanitizeInput(messageContent)}</p>
            <div class="message-timestamp">${new Date(timestamp).toLocaleTimeString()}</div>
        `;
        chatMessagesContainer.appendChild(messageElement);
        // Force scroll when user sends a message
        this.scrollToBottom(true);

        // Send to database
        const { error } = await supabase
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
            if (chatInput) {
                chatInput.value = messageContent; // Restore message
            }
            throw error;
        }

        // Create notification for the recipient (landlord) in AI negotiations section
        await this.createMessageNotificationForRecipient(currentUser, messageContent);
    }

    /**
     * Create a notification in ai_chats table for the message recipient
     * Uses Supabase RPC function to bypass RLS restrictions
     */
    async createMessageNotificationForRecipient(currentUser, messageContent) {
        try {
            console.log('🔔 createMessageNotificationForRecipient called');

            if (!this.currentListing || !this.currentListing.user_email) {
                console.log('🔔 No listing or user_email, skipping notification');
                return;
            }

            const landlordEmail = this.currentListing.user_email;
            console.log('🔔 Landlord email:', landlordEmail, 'Current user:', currentUser.email);

            // Skip if user is the landlord
            if (currentUser.email === landlordEmail) {
                console.log('🔔 User is landlord, skipping notification');
                return;
            }

            const supabase = window.configManager ? window.configManager.getSupabase() : null;
            if (!supabase) {
                console.error('🔔 Supabase not available');
                return;
            }

            const listingTitle = this.currentListing.title || 'Property';
            const truncatedMessage = messageContent.length > 100
                ? messageContent.substring(0, 100) + '...'
                : messageContent;

            const notificationContent = `New Message from Tenant\n\nProperty: ${listingTitle}\nFrom: ${currentUser.email}\n\nMessage: "${truncatedMessage}"\n\nReply in the chat to continue the conversation.`;

            console.log('🔔 Calling create_notification RPC for:', landlordEmail);

            // Use Supabase RPC function to bypass RLS
            const { data, error } = await supabase.rpc('create_notification', {
                recipient_email: landlordEmail,
                notification_title: `New Message: ${listingTitle}`,
                notification_content: notificationContent
            });

            if (error) {
                console.error('🔔 RPC error:', error);
                // Fallback: Try direct insert (might fail due to RLS but worth trying)
                console.log('🔔 Trying fallback direct insert...');
                const { error: insertError } = await supabase
                    .from('ai_chats')
                    .insert({
                        user_email: landlordEmail,
                        title: `New Message: ${listingTitle}`,
                        conversation_data: JSON.stringify([{ role: 'assistant', content: notificationContent }])
                    });

                if (insertError) {
                    console.error('🔔 Fallback insert also failed:', insertError);
                } else {
                    console.log('🔔 Fallback insert succeeded!');
                }
            } else {
                console.log('🔔 Notification created successfully via RPC! ID:', data);
            }
        } catch (error) {
            console.error('🔔 Error creating notification:', error);
        }
    }

    /**
     * Send file message
     */
    async sendFileMessage(file, currentUser, timestamp) {
        const chatMessagesContainer = document.getElementById('chatMessages');
        const supabase = window.configManager ? window.configManager.getSupabase() : null;

        if (!supabase || !chatMessagesContainer) {
            throw new Error('Required elements not available');
        }

        // Validate file size (5MB limit)
        if (file.size > 5 * 1024 * 1024) {
            throw new Error(`File ${file.name} is too large. Maximum size is 5MB.`);
        }

        // Show uploading status
        const messageElement = document.createElement('div');
        messageElement.className = 'message sent';
        messageElement.innerHTML = `
            <div class="file-message bg-blue-50 p-3 rounded">
                <div class="flex items-center space-x-2">
                    <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>
                    <div>
                        <p class="font-medium text-blue-900">${file.name}</p>
                        <p class="text-sm text-blue-600">Uploading... (${this.formatFileSize(file.size)})</p>
                    </div>
                </div>
            </div>
            <div class="message-timestamp">${new Date(timestamp).toLocaleTimeString()}</div>
        `;
        chatMessagesContainer.appendChild(messageElement);
        // Force scroll when user sends a file
        this.scrollToBottom(true);

        try {
            // Upload file to Supabase storage
            const fileName = `chat-${this.currentConversationId}-${Date.now()}-${file.name}`;
            const filePath = `chat-files/${fileName}`;

            const { data: uploadData, error: uploadError } = await supabase.storage
                .from('chat-documents')
                .upload(filePath, file, {
                    contentType: file.type,
                    upsert: false
                });

            if (uploadError) {
                throw new Error('Failed to upload file: ' + uploadError.message);
            }

            // Get public URL
            const { data: urlData } = supabase.storage
                .from('chat-documents')
                .getPublicUrl(filePath);

            // Save message to database
            const { error: dbError } = await supabase
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
                        <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>
                        <div>
                            <p class="font-medium text-blue-900">${file.name}</p>
                            <p class="text-sm text-blue-600">${this.formatFileSize(file.size)}</p>
                            <a href="${urlData.publicUrl}" target="_blank" class="text-blue-800 hover:text-blue-900 text-sm font-medium flex items-center gap-1"><svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path></svg> Download</a>
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

        // Setup file upload button click
        fileUploadBtn.addEventListener('click', () => {
            fileInput.click();
        });
    }

    /**
     * Display selected files
     */
    displaySelectedFiles(files) {
        const selectedFilesContainer = document.getElementById('selectedFiles');
        if (!selectedFilesContainer) return;

        if (files.length === 0) {
            selectedFilesContainer.classList.add('hidden');
            return;
        }

        selectedFilesContainer.classList.remove('hidden');
        selectedFilesContainer.innerHTML = files.map((file, index) => `
            <div class="flex items-center justify-between bg-gray-100 p-2 rounded">
                <div class="flex items-center space-x-2">
                    <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>
                    <span class="text-sm text-gray-700">${file.name}</span>
                    <span class="text-xs text-gray-500">(${this.formatFileSize(file.size)})</span>
                </div>
                <button onclick="chatController.removeFileFromChat(${index})" class="text-red-500 hover:text-red-700 text-sm">x</button>
            </div>
        `).join('');
    }

    /**
     * Remove file from chat selection
     */
    removeFileFromChat(index) {
        this.selectedFiles.splice(index, 1);
        this.displaySelectedFiles(this.selectedFiles);

        // Update file input
        const fileInput = document.getElementById('fileInput');
        if (fileInput) {
            const dt = new DataTransfer();
            this.selectedFiles.forEach(file => dt.items.add(file));
            fileInput.files = dt.files;
        }
    }

    /**
     * Clear selected files
     */
    clearSelectedFiles() {
        this.selectedFiles = [];
        const fileInput = document.getElementById('fileInput');
        if (fileInput) fileInput.value = '';
        const selectedFilesContainer = document.getElementById('selectedFiles');
        if (selectedFilesContainer) selectedFilesContainer.classList.add('hidden');
    }

    /**
     * Setup scroll tracking to detect when user scrolls up
     */
    setupScrollTracking() {
        const chatMessagesContainer = document.getElementById('chatMessages');
        if (!chatMessagesContainer) return;

        chatMessagesContainer.addEventListener('scroll', () => {
            const { scrollTop, scrollHeight, clientHeight } = chatMessagesContainer;
            const distanceFromBottom = scrollHeight - scrollTop - clientHeight;

            // User is "at bottom" if within 100px of bottom
            this.userScrolledUp = distanceFromBottom > 100;
            this.updateScrollButtonVisibility();
        });
    }

    /**
     * Create scroll to bottom button
     */
    createScrollToBottomButton() {
        const chatMessagesContainer = document.getElementById('chatMessages');
        if (!chatMessagesContainer) return;

        // Check if button already exists
        if (document.getElementById('scrollToBottomBtn')) return;

        const scrollBtn = document.createElement('button');
        scrollBtn.id = 'scrollToBottomBtn';
        scrollBtn.className = 'scroll-to-bottom-btn';
        scrollBtn.innerHTML = `
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3"></path>
            </svg>
        `;
        scrollBtn.style.cssText = `
            position: absolute;
            bottom: 80px;
            right: 20px;
            width: 40px;
            height: 40px;
            border-radius: 50%;
            background: rgba(59, 130, 246, 0.9);
            color: white;
            border: none;
            cursor: pointer;
            display: none;
            align-items: center;
            justify-content: center;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
            transition: all 0.2s ease;
            z-index: 100;
        `;
        scrollBtn.addEventListener('mouseenter', () => {
            scrollBtn.style.background = 'rgba(37, 99, 235, 1)';
            scrollBtn.style.transform = 'scale(1.1)';
        });
        scrollBtn.addEventListener('mouseleave', () => {
            scrollBtn.style.background = 'rgba(59, 130, 246, 0.9)';
            scrollBtn.style.transform = 'scale(1)';
        });
        scrollBtn.addEventListener('click', () => this.scrollToBottom(true));

        // Insert button into chat modal content area
        const chatContent = chatMessagesContainer.parentElement;
        if (chatContent) {
            chatContent.style.position = 'relative';
            chatContent.appendChild(scrollBtn);
        }
    }

    /**
     * Update scroll button visibility
     */
    updateScrollButtonVisibility() {
        const scrollBtn = document.getElementById('scrollToBottomBtn');
        if (scrollBtn) {
            scrollBtn.style.display = this.userScrolledUp ? 'flex' : 'none';
        }
    }

    /**
     * Scroll to bottom of chat - only if user hasn't scrolled up or if forced
     */
    scrollToBottom(force = false) {
        const chatMessagesContainer = document.getElementById('chatMessages');
        if (!chatMessagesContainer) return;

        if (force || !this.userScrolledUp) {
            chatMessagesContainer.scrollTo({
                top: chatMessagesContainer.scrollHeight,
                behavior: force ? 'smooth' : 'auto'
            });
            this.userScrolledUp = false;
            this.updateScrollButtonVisibility();
        }
    }

    /**
     * Perform chat health check
     */
    performChatHealthCheck() {
        console.log('🔍 Performing chat health check...');
        const issues = [];

        // Check DOM elements
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

        // Check Supabase connection
        const supabase = window.configManager ? window.configManager.getSupabase() : null;
        if (!supabase) {
            issues.push('Supabase client not initialized');
        } else {
            this.chatSystemStatus.supabaseConnected = true;
        }

        // Check authentication
        const currentUser = window.authManager ? window.authManager.getCurrentUser() : null;
        if (!currentUser) {
            issues.push('No authenticated user (warning only)');
        }

        const isHealthy = issues.filter(issue => !issue.includes('warning only')).length === 0;

        const result = {
            healthy: isHealthy,
            issues: issues,
            elementsFound: requiredElements.filter(item => !!item.element).length,
            totalElements: requiredElements.length,
            timestamp: new Date()
        };

        this.chatSystemStatus.lastHealthCheck = result;
        console.log('🏥 Health check result:', result);

        return result;
    }

    /**
     * Display chat system error
     */
    displayChatSystemError() {
        console.error('🚨 Displaying chat system error to user');

        // Try to find a place to show the error
        const errorContainer = document.getElementById('chatMessages') || document.body;

        const errorDiv = document.createElement('div');
        errorDiv.id = 'chat-system-error';
        errorDiv.style.cssText = `
            background: #fee2e2;
            border: 1px solid #fca5a5;
            border-radius: 8px;
            padding: 12px;
            margin: 10px;
            color: #dc2626;
            font-family: Arial, sans-serif;
            font-size: 14px;
            position: relative;
            z-index: 1000;
        `;

        errorDiv.innerHTML = `
            <strong>⚠️ Chat System Error</strong><br>
            The chat system couldn't initialize properly.
            <button onclick="chatController.retryChatSetup()" style="
                background: #dc2626;
                color: white;
                border: none;
                padding: 4px 8px;
                border-radius: 4px;
                cursor: pointer;
                margin-left: 8px;
            ">Retry</button>
            <button onclick="this.parentElement.remove()" style="
                background: #6b7280;
                color: white;
                border: none;
                padding: 4px 8px;
                border-radius: 4px;
                cursor: pointer;
                margin-left: 4px;
            ">Dismiss</button>
        `;

        // Remove any existing error messages
        const existingError = document.getElementById('chat-system-error');
        if (existingError) {
            existingError.remove();
        }

        errorContainer.appendChild(errorDiv);
    }

    /**
     * Retry chat setup
     */
    retryChatSetup() {
        console.log('🔄 Manual chat system retry triggered');
        this.chatSystemStatus.setupAttempts = 0; // Reset attempt counter
        this.chatSystemStatus.errors = []; // Clear errors

        const errorDiv = document.getElementById('chat-system-error');
        if (errorDiv) {
            errorDiv.remove();
        }

        this.init();
    }

    /**
     * Format file size
     */
    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    /**
     * Sanitize input
     */
    sanitizeInput(input) {
        if (typeof input !== 'string') return '';
        return input.replace(/[^a-zA-Z0-9\s,.-]/g, '').trim();
    }

    /**
     * Debug chat system
     */
    debugChatSystem() {
        console.log('🔍 Chat System Debug Information:');
        console.log('- Chat Modal Element:', !!document.getElementById('chatModal'));
        console.log('- Chat Close Button:', !!document.querySelector('.chat-close-button'));
        console.log('- Chat Input:', !!document.getElementById('chatInput'));
        console.log('- Chat Send Button:', !!document.getElementById('chatSendBtn'));
        console.log('- Supabase Client:', !!window.configManager?.getSupabase());
        console.log('- Current User:', !!window.authManager?.getCurrentUser());
        console.log('- Chat System Status:', this.chatSystemStatus);
        console.log('- Active Chat Buttons:', document.querySelectorAll('.chat-btn:not([disabled])').length);
        console.log('- Disabled Chat Buttons:', document.querySelectorAll('.chat-btn[disabled]').length);
    }

    /**
     * Get current conversation ID
     */
    getCurrentConversationId() {
        return this.currentConversationId;
    }

    /**
     * Get current listing
     */
    getCurrentListing() {
        return this.currentListing;
    }

    /**
     * Check if chat is initialized
     */
    isReady() {
        return this.isInitialized;
    }
}

// Create global instance
window.chatController = new ChatController();

// Global functions for backward compatibility
window.setupChat = () => {
    if (window.chatController) {
        return window.chatController.init();
    }
};

window.startConversation = (listing) => {
    if (window.chatController) {
        window.chatController.startConversation(listing);
    }
};

window.retryChatSetup = () => {
    if (window.chatController) {
        window.chatController.retryChatSetup();
    }
};

window.debugChatSystem = () => {
    if (window.chatController) {
        window.chatController.debugChatSystem();
    }
};

export default window.chatController;