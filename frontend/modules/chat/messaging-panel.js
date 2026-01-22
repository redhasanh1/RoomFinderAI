/**
 * Messaging Panel Module
 * Handles the messaging panel, conversation list, and notifications
 */

class MessagingPanel {
    constructor() {
        this.isOpen = false;
        this.isInitialized = false;
        this.globalUserConversations = [];
        this.globalUnreadCount = 0;
        this.locallyReadConversations = new Set(); // Track conversations marked as read locally
        this.messageToggleBtn = null;
        this.messagePanel = null;
        this.updateInterval = null;
    }

    /**
     * Initialize the messaging panel
     */
    init() {
        this.messageToggleBtn = document.getElementById('messageToggleBtn');
        this.messagePanel = document.getElementById('messagePanel');

        if (!this.messageToggleBtn || !this.messagePanel) {
            console.warn('Messaging panel elements not found');
            return false;
        }

        this.setupEventListeners();
        this.startPeriodicUpdates();

        this.isInitialized = true;
        console.log('✅ Messaging Panel initialized');
        return true;
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Toggle message panel
        this.messageToggleBtn.addEventListener('click', async () => {
            this.isOpen = !this.isOpen;
            if (this.isOpen) {
                this.messagePanel.classList.remove('hidden');
                await this.loadUserConversations();
            } else {
                this.messagePanel.classList.add('hidden');
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
                this.messagePanel.classList.add('hidden');
                this.isOpen = false;
            }
        });
    }

    /**
     * Start periodic updates for conversations
     * Optimized: Only polls when page is visible to reduce egress costs
     */
    startPeriodicUpdates() {
        // Update conversations every 30 seconds if user is authenticated AND page is visible
        this.updateInterval = setInterval(() => {
            // Skip polling when page is not visible to save bandwidth
            if (document.hidden) {
                console.log('⏸️ Skipping conversation poll - page not visible');
                return;
            }

            const currentUser = window.authManager ? window.authManager.getCurrentUser() : null;
            if (currentUser) {
                this.loadUserConversations();
            }
        }, 30000);
    }

    /**
     * Load user conversations
     */
    async loadUserConversations() {
        const currentUser = window.authManager ? window.authManager.getCurrentUser() : null;
        const supabase = window.configManager ? window.configManager.getSupabase() : null;

        if (!currentUser || !supabase) {
            console.log('⚠️ Cannot load conversations - user or supabase not available');
            return;
        }

        try {
            console.log('🔄 Loading user conversations for:', currentUser.email);

            // Get conversations where user is sender or receiver
            const { data: conversations, error } = await supabase
                .from('conversations')
                .select(`
                    id,
                    listing_id,
                    sender_email,
                    receiver_email,
                    created_at,
                    listings!inner(title, user_email)
                `)
                .or(`sender_email.eq.${currentUser.email},receiver_email.eq.${currentUser.email}`)
                .order('created_at', { ascending: false });

            if (error) {
                console.error('❌ Error loading conversations:', error);
                return;
            }

            console.log('📧 Raw conversations loaded:', conversations?.length || 0);

            // Get unread counts for each conversation
            const conversationsWithUnread = await this.getUnreadCounts(conversations, currentUser, supabase);

            this.globalUserConversations = conversationsWithUnread;
            this.displayConversations();
            this.updateUnreadCount();

            console.log('✅ Conversations loaded and displayed:', this.globalUserConversations.length);

        } catch (error) {
            console.error('💥 Error in loadUserConversations:', error);
        }
    }

    /**
     * Get unread counts for conversations
     * Optimized: Uses batch queries instead of N+1 queries to reduce egress costs
     */
    async getUnreadCounts(conversations, currentUser, supabase) {
        if (!conversations || conversations.length === 0) {
            return [];
        }

        try {
            // Get all conversation IDs
            const conversationIds = conversations.map(c => c.id);

            // BATCH QUERY 1: Get all last_read_at timestamps in a single query
            const { data: readDataArray } = await supabase
                .from('conversation_reads')
                .select('conversation_id, last_read_at')
                .in('conversation_id', conversationIds)
                .eq('user_email', currentUser.email);

            // Create a map for quick lookup
            const readDataMap = new Map();
            if (readDataArray) {
                readDataArray.forEach(rd => {
                    readDataMap.set(rd.conversation_id, rd.last_read_at);
                });
            }

            // BATCH QUERY 2: Get unread counts for all conversations
            // Using a single query with grouping would be ideal, but Supabase doesn't support it well
            // Instead, we get all relevant messages and count client-side
            const { data: allMessages } = await supabase
                .from('messages')
                .select('conversation_id, created_at')
                .in('conversation_id', conversationIds)
                .neq('sender_email', currentUser.email);

            // Count unread messages per conversation
            const unreadCountMap = new Map();
            if (allMessages) {
                allMessages.forEach(msg => {
                    const lastReadAt = readDataMap.get(msg.conversation_id) || '1970-01-01T00:00:00Z';
                    if (new Date(msg.created_at) > new Date(lastReadAt)) {
                        unreadCountMap.set(
                            msg.conversation_id,
                            (unreadCountMap.get(msg.conversation_id) || 0) + 1
                        );
                    }
                });
            }

            // Build result array
            return conversations.map(conv => {
                const isUserSender = conv.sender_email === currentUser.email;
                const otherUserEmail = isUserSender ? conv.receiver_email : conv.sender_email;
                const listingTitle = conv.listings?.title || 'Unknown Property';
                const lastReadAt = readDataMap.get(conv.id) || '1970-01-01T00:00:00Z';

                return {
                    ...conv,
                    unread_count: unreadCountMap.get(conv.id) || 0,
                    other_user_email: otherUserEmail,
                    listing_title: listingTitle,
                    last_read_at: lastReadAt
                };
            });

        } catch (error) {
            console.error('Error in batch getUnreadCounts:', error);
            // Fallback: return conversations with 0 unread
            return conversations.map(conv => ({
                ...conv,
                unread_count: 0,
                other_user_email: conv.sender_email === currentUser.email ? conv.receiver_email : conv.sender_email,
                listing_title: conv.listings?.title || 'Unknown Property',
                last_read_at: '1970-01-01T00:00:00Z'
            }));
        }
    }

    /**
     * Display conversations in the panel
     */
    displayConversations() {
        const conversationTabs = document.getElementById('conversationTabs');
        const noConversations = document.getElementById('noConversations');

        if (!conversationTabs) {
            console.warn('Conversation tabs element not found');
            return;
        }

        if (this.globalUserConversations.length === 0) {
            if (noConversations) {
                noConversations.style.display = 'block';
            }
            conversationTabs.innerHTML = '<div id="noConversations" class="p-4 text-gray-500 text-center">No conversations yet</div>';
            return;
        }

        if (noConversations) {
            noConversations.style.display = 'none';
        }

        const conversationsHtml = this.globalUserConversations.map(conv => {
            const isLocallyRead = this.locallyReadConversations.has(conv.id);
            const displayUnreadCount = isLocallyRead ? 0 : (conv.unread_count || 0);
            const otherUserName = conv.other_user_email ? conv.other_user_email.split('@')[0] : 'User';

            return `
                <div class="conversation-item border-b border-gray-200 p-3 hover:bg-gray-50 cursor-pointer ${displayUnreadCount > 0 ? 'bg-blue-50' : ''}"
                     onclick="messagingPanel.openConversationInModal('${conv.id}', '${conv.listing_title}', '${conv.listing_id}', '${conv.other_user_email}')">
                    <div class="flex justify-between items-start">
                        <div class="flex-1 min-w-0">
                            <div class="flex items-center justify-between">
                                <h4 class="text-sm font-medium text-gray-900 truncate">${otherUserName}</h4>
                                ${displayUnreadCount > 0 ? `<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">${displayUnreadCount}</span>` : ''}
                            </div>
                            <p class="text-xs text-gray-600 truncate mt-1">${conv.listing_title}</p>
                            <p class="text-xs text-gray-400 mt-1">${new Date(conv.created_at).toLocaleDateString()}</p>
                        </div>
                    </div>
                </div>
            `;
        }).join('');

        conversationTabs.innerHTML = conversationsHtml;

        console.log('📋 Displayed conversations:', {
            total: this.globalUserConversations.length,
            withUnread: this.globalUserConversations.filter(c => !this.locallyReadConversations.has(c.id) && c.unread_count > 0).length,
            locallyRead: this.locallyReadConversations.size
        });
    }

    /**
     * Update unread count badges
     */
    updateUnreadCount() {
        const messageNotificationBadge = document.getElementById('messageNotificationBadge');
        const profileNotificationBadge = document.getElementById('profileNotificationBadge');

        // Check if elements exist before proceeding
        if (!messageNotificationBadge || !profileNotificationBadge) {
            console.log('⚠️ Notification badge elements not found, skipping update');
            return;
        }

        const currentUser = window.authManager ? window.authManager.getCurrentUser() : null;
        if (!currentUser) return;

        // Calculate total unread messages across all conversations
        let totalUnread = 0;
        const detailedLog = [];

        for (const conv of this.globalUserConversations) {
            const isLocallyRead = this.locallyReadConversations.has(conv.id);
            const unreadCount = isLocallyRead ? 0 : (conv.unread_count || 0);

            detailedLog.push({
                id: conv.id,
                originalCount: conv.unread_count,
                isLocallyRead: isLocallyRead,
                finalCount: unreadCount
            });

            if (unreadCount > 0) {
                totalUnread += unreadCount;
            }
        }

        console.log('🔔 DETAILED UNREAD CALCULATION:', {
            conversations: this.globalUserConversations.length,
            locallyReadSet: Array.from(this.locallyReadConversations),
            detailedLog: detailedLog,
            totalUnread: totalUnread
        });

        // FORCE hide notifications if totalUnread is 0
        if (totalUnread === 0) {
            messageNotificationBadge.classList.add('hidden');
            profileNotificationBadge.classList.add('hidden');
            console.log('🔥 FORCING notifications to hide - totalUnread is 0');
        } else {
            messageNotificationBadge.textContent = totalUnread;
            messageNotificationBadge.classList.remove('hidden');
            profileNotificationBadge.textContent = totalUnread;
            profileNotificationBadge.classList.remove('hidden');
            console.log('✅ Showing notifications:', totalUnread);
        }

        this.globalUnreadCount = totalUnread;

        // Update auth manager badge if available
        if (window.authManager && window.authManager.updateNotificationBadge) {
            window.authManager.updateNotificationBadge(totalUnread);
        }
    }

    /**
     * Open conversation in modal
     */
    async openConversationInModal(conversationId, listingTitle, listingId, otherUserEmail) {
        // Close messaging panel
        this.messagePanel.classList.add('hidden');
        this.isOpen = false;

        // INSTANTLY clear notifications - don't wait for database
        console.log('⚡ INSTANTLY clearing notifications for conversation:', conversationId);

        // Mark conversation as read locally and persistently
        this.locallyReadConversations.add(conversationId);
        console.log('🔒 Added to locally read set:', conversationId);

        // Find and update the conversation in local array
        const convIndex = this.globalUserConversations.findIndex(c => c.id === conversationId);
        if (convIndex !== -1) {
            this.globalUserConversations[convIndex].unread_count = 0;
            console.log('✅ Locally marked conversation as read');
        }

        // Immediately update notification badges
        this.updateUnreadCount();

        // Set up chat modal with existing conversation
        if (window.chatController) {
            window.chatController.currentConversationId = conversationId;
        }

        const otherUserName = otherUserEmail ? otherUserEmail.split('@')[0] : 'User';
        const chatTitle = document.getElementById('chatTitle');
        if (chatTitle) {
            chatTitle.textContent = `Chat with ${otherUserName} about ${listingTitle}`;
        }

        // Load messages and show modal
        if (window.chatController && window.chatController.loadMessages) {
            await window.chatController.loadMessages(conversationId);
        }

        const chatModal = document.getElementById('chatModal');
        if (chatModal) {
            chatModal.classList.add('active');
        }

        // Update database in background (don't wait)
        this.updateConversationReadStatus(conversationId);
    }

    /**
     * Update conversation read status in background
     */
    async updateConversationReadStatus(conversationId) {
        const currentUser = window.authManager ? window.authManager.getCurrentUser() : null;
        const supabase = window.configManager ? window.configManager.getSupabase() : null;

        if (!currentUser || !supabase) {
            console.error('❌ Cannot update read status - user or supabase not available');
            return;
        }

        try {
            const { error } = await supabase
                .from('conversation_reads')
                .upsert({
                    conversation_id: conversationId,
                    user_email: currentUser.email,
                    last_read_at: new Date().toISOString()
                }, {
                    onConflict: 'conversation_id,user_email'
                });

            if (error) {
                console.error('❌ Background database update failed:', error);

                // Track constraint violations if chat controller is available
                if (window.chatController && error.message && error.message.includes('duplicate key')) {
                    window.chatController.chatSystemStatus.databaseErrors.constraintViolations++;
                    window.chatController.chatSystemStatus.databaseErrors.lastConstraintError = new Date();
                    console.log('📊 Constraint violation tracked');
                }

                console.log('🔄 Attempting fallback update method...');
                await this.fallbackUpdateReadStatus(conversationId, currentUser, supabase);
            } else {
                console.log('✅ Conversation read status updated successfully');
            }

        } catch (catchError) {
            console.error('💥 Unexpected error in conversation_reads update:', catchError);
            this.locallyReadConversations.delete(conversationId);
        }
    }

    /**
     * Fallback method for updating read status
     */
    async fallbackUpdateReadStatus(conversationId, currentUser, supabase) {
        try {
            // Try update first, then insert if not exists
            const { data: updateData, error: updateError } = await supabase
                .from('conversation_reads')
                .update({ last_read_at: new Date().toISOString() })
                .eq('conversation_id', conversationId)
                .eq('user_email', currentUser.email);

            if (updateError || !updateData || updateData.length === 0) {
                console.log('🔄 Update failed or no rows, attempting insert...');

                const { error: insertError } = await supabase
                    .from('conversation_reads')
                    .insert({
                        conversation_id: conversationId,
                        user_email: currentUser.email,
                        last_read_at: new Date().toISOString()
                    });

                if (insertError && !insertError.message.includes('duplicate key')) {
                    console.error('❌ Fallback insert failed:', insertError);
                    this.locallyReadConversations.delete(conversationId);
                } else {
                    console.log('✅ Fallback method successful');
                }
            } else {
                console.log('✅ Fallback update successful');
            }

        } catch (fallbackError) {
            console.error('❌ Fallback method failed:', fallbackError);
            this.locallyReadConversations.delete(conversationId);
        }
    }

    /**
     * Mark conversation as read
     */
    markConversationAsRead(conversationId) {
        this.locallyReadConversations.add(conversationId);

        // Find and update the conversation in local array
        const convIndex = this.globalUserConversations.findIndex(c => c.id === conversationId);
        if (convIndex !== -1) {
            this.globalUserConversations[convIndex].unread_count = 0;
        }

        this.updateUnreadCount();
        this.displayConversations();
    }

    /**
     * Get conversations
     */
    getConversations() {
        return this.globalUserConversations;
    }

    /**
     * Get unread count
     */
    getUnreadCount() {
        return this.globalUnreadCount;
    }

    /**
     * Force refresh conversations
     */
    async refresh() {
        if (this.isInitialized) {
            await this.loadUserConversations();
        }
    }

    /**
     * Clear all locally read conversations
     */
    clearLocallyRead() {
        this.locallyReadConversations.clear();
        this.updateUnreadCount();
        this.displayConversations();
    }

    /**
     * Show messaging panel
     */
    show() {
        if (this.messagePanel) {
            this.messagePanel.classList.remove('hidden');
            this.isOpen = true;
            this.loadUserConversations();
        }
    }

    /**
     * Hide messaging panel
     */
    hide() {
        if (this.messagePanel) {
            this.messagePanel.classList.add('hidden');
            this.isOpen = false;
        }
    }

    /**
     * Toggle messaging panel
     */
    toggle() {
        if (this.isOpen) {
            this.hide();
        } else {
            this.show();
        }
    }

    /**
     * Destroy messaging panel
     */
    destroy() {
        if (this.updateInterval) {
            clearInterval(this.updateInterval);
            this.updateInterval = null;
        }

        this.isInitialized = false;
        this.globalUserConversations = [];
        this.locallyReadConversations.clear();
        console.log('🗑️ Messaging Panel destroyed');
    }
}

// Create global instance
window.messagingPanel = new MessagingPanel();

// Global functions for backward compatibility
window.updateUnreadCount = () => {
    if (window.messagingPanel) {
        window.messagingPanel.updateUnreadCount();
    }
};

window.setupMessagingPanel = () => {
    if (window.messagingPanel) {
        return window.messagingPanel.init();
    }
};

window.openConversationInModal = (conversationId, listingTitle, listingId, otherUserEmail) => {
    if (window.messagingPanel) {
        window.messagingPanel.openConversationInModal(conversationId, listingTitle, listingId, otherUserEmail);
    }
};

export default window.messagingPanel;