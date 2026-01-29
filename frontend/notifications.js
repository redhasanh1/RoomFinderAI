// Comprehensive Notification Service for AI Negotiator
// Handles in-app, browser push, and localStorage-based notifications

class NotificationService {
    constructor(supabase, userEmail) {
        this.supabase = supabase;
        this.userEmail = userEmail;
        this.notifications = [];
        this.unreadCount = 0;
        this.listeners = new Set();
        this.isPolling = false;
        this.pollInterval = null;

        this.init();
    }

    async init() {
        console.log('🔔 Initializing notification service for:', this.userEmail);

        // Load existing notifications from localStorage
        this.loadFromLocalStorage();

        // Setup real-time subscriptions
        this.setupRealtimeSubscription();

        // Setup polling fallback
        this.startPolling();

        // Load initial notifications from database
        await this.loadNotifications();

        console.log('✅ Notification service initialized');
    }

    // Load notifications from localStorage (offline support)
    loadFromLocalStorage() {
        try {
            const stored = localStorage.getItem(`notifications_${this.userEmail}`);
            if (stored) {
                this.notifications = JSON.parse(stored);
                this.updateUnreadCount();
                console.log(`📦 Loaded ${this.notifications.length} notifications from localStorage`);
            }
        } catch (error) {
            console.error('Error loading from localStorage:', error);
        }
    }

    // Save notifications to localStorage
    saveToLocalStorage() {
        try {
            // Keep only last 50 notifications
            const toSave = this.notifications.slice(-50);
            localStorage.setItem(`notifications_${this.userEmail}`, JSON.stringify(toSave));
        } catch (error) {
            console.error('Error saving to localStorage:', error);
        }
    }

    // Setup real-time subscription for new notifications
    setupRealtimeSubscription() {
        if (!this.supabase) {
            console.warn('⚠️ Supabase not available, using polling only');
            return;
        }

        try {
            const channel = this.supabase
                .channel(`notifications_${this.userEmail}_${Date.now()}`)
                .on('postgres_changes', {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'ai_chats',
                    filter: `user_email=eq.${this.userEmail}`
                }, (payload) => {
                    console.log('🔔 Real-time notification received:', payload);
                    this.handleNewNotification(payload.new);
                })
                .on('postgres_changes', {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'messages'
                }, async (payload) => {
                    // Check if this message is relevant to user's negotiations
                    console.log('📨 New message detected:', payload);
                    await this.checkMessageRelevance(payload.new);
                })
                .subscribe((status) => {
                    console.log('🔔 Notification subscription status:', status);
                });

            console.log('✅ Real-time subscription established');
        } catch (error) {
            console.error('❌ Failed to setup real-time subscription:', error);
        }
    }

    // Check if a message is relevant to user's negotiations
    async checkMessageRelevance(message) {
        try {
            // Check if this is a landlord reply to one of user's negotiations
            // Select only needed columns to reduce egress costs
            const { data: conversation } = await this.supabase
                .from('conversations')
                .select('id, listing_id, sender_email, receiver_email')
                .eq('id', message.conversation_id)
                .or(`sender_email.eq.${this.userEmail},receiver_email.eq.${this.userEmail}`)
                .maybeSingle();

            if (conversation && message.sender_email !== this.userEmail) {
                // This is a reply from landlord
                const { data: listing } = await this.supabase
                    .from('listings')
                    .select('title')
                    .eq('id', conversation.listing_id)
                    .maybeSingle();

                const notification = {
                    id: `msg_${message.id}`,
                    type: 'landlord_reply',
                    title: `Reply from landlord`,
                    message: message.content.substring(0, 100) + '...',
                    listingTitle: listing?.title || 'Unknown property',
                    conversationId: conversation.id,
                    timestamp: new Date().toISOString(),
                    read: false
                };

                this.addNotification(notification);
            }
        } catch (error) {
            console.error('Error checking message relevance:', error);
        }
    }

    // Start polling for updates (fallback for when real-time fails)
    startPolling(interval = 30000) {
        if (this.pollInterval) {
            clearInterval(this.pollInterval);
        }

        this.pollInterval = setInterval(async () => {
            if (!document.hidden) { // Only poll when page is visible
                await this.loadNotifications();
            }
        }, interval);

        console.log(`📡 Started polling every ${interval/1000}s`);
    }

    // Stop polling
    stopPolling() {
        if (this.pollInterval) {
            clearInterval(this.pollInterval);
            this.pollInterval = null;
        }
    }

    // Load notifications from database
    async loadNotifications() {
        if (!this.supabase) {
            console.log('🔔 loadNotifications: No supabase client');
            return;
        }

        try {
            console.log('🔔 loadNotifications: Querying ai_chats for', this.userEmail);

            // Load from ai_chats table
            // Select only needed columns to reduce egress costs
            const { data: aiChats, error } = await this.supabase
                .from('ai_chats')
                .select('id, title, conversation_data, created_at')
                .eq('user_email', this.userEmail)
                .order('created_at', { ascending: false })
                .limit(20);

            console.log('🔔 loadNotifications result:', { aiChats: aiChats?.length, error: error?.message });

            if (error) {
                console.error('🔔 Error loading notifications:', error);
                return;
            }

            // Also check negotiation backups in localStorage
            const backups = JSON.parse(localStorage.getItem('negotiation_backups') || '[]');

            // Merge and deduplicate
            const allNotifications = [];

            // Process ai_chats
            if (aiChats) {
                console.log('🔔 Processing', aiChats.length, 'ai_chats');
                aiChats.forEach(chat => {
                    try {
                        // Handle both JSONB (object) and string formats
                        let conversationData = chat.conversation_data;
                        if (typeof conversationData === 'string') {
                            conversationData = JSON.parse(conversationData);
                        }
                        const message = Array.isArray(conversationData)
                            ? (conversationData[0]?.content || '')
                            : (conversationData?.content || String(conversationData) || '');

                        console.log('🔔 Chat notification:', chat.title, message.substring(0, 50));

                        allNotifications.push({
                            id: `chat_${chat.id}`,
                            type: chat.title?.includes('Success') ? 'negotiation_success' :
                                  chat.title?.includes('Message') ? 'landlord_reply' : 'notification',
                            title: chat.title || 'Notification',
                            message: message.substring(0, 150),
                            timestamp: chat.created_at,
                            read: false
                        });
                    } catch (e) {
                        console.error('Error parsing chat:', e, chat);
                    }
                });
            }

            // Process backups
            backups.forEach(backup => {
                if (backup.userEmail === this.userEmail) {
                    allNotifications.push({
                        id: `backup_${backup.timestamp}`,
                        type: backup.type,
                        title: backup.type === 'negotiation_success' ? 'Negotiation Success!' : 'Update',
                        message: backup.message,
                        timestamp: backup.timestamp,
                        read: false,
                        landlordReply: backup.landlordReply,
                        aiResponse: backup.aiResponse
                    });
                }
            });

            // Sort by timestamp
            allNotifications.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

            // Update state
            this.notifications = allNotifications;
            this.updateUnreadCount();
            this.saveToLocalStorage();
            this.notifyListeners();

            console.log(`📬 Loaded ${this.notifications.length} notifications`);

        } catch (error) {
            console.error('Error loading notifications:', error);
        }
    }

    // Handle new notification from real-time subscription
    handleNewNotification(data) {
        try {
            console.log('🔔 handleNewNotification:', data);
            // Handle both JSONB (object) and string formats
            let conversationData = data.conversation_data;
            if (typeof conversationData === 'string') {
                conversationData = JSON.parse(conversationData);
            }
            const message = Array.isArray(conversationData)
                ? (conversationData[0]?.content || '')
                : (conversationData?.content || String(conversationData) || '');

            const notification = {
                id: `chat_${data.id}`,
                type: data.title?.includes('Success') ? 'negotiation_success' :
                      data.title?.includes('Message') ? 'landlord_reply' : 'notification',
                title: data.title || 'New Notification',
                message: message.substring(0, 150),
                timestamp: data.created_at || new Date().toISOString(),
                read: false
            };

            this.addNotification(notification);
        } catch (error) {
            console.error('Error handling new notification:', error);
        }
    }

    // Add a notification
    addNotification(notification) {
        // Check for duplicates
        const exists = this.notifications.some(n => n.id === notification.id);
        if (exists) return;

        this.notifications.unshift(notification);
        this.updateUnreadCount();
        this.saveToLocalStorage();
        this.notifyListeners();

        // Show browser notification if permitted
        this.showBrowserNotification(notification);

        console.log('➕ Added notification:', notification.title);
    }

    // Update unread count
    updateUnreadCount() {
        this.unreadCount = this.notifications.filter(n => !n.read).length;
    }

    // Mark notification as read
    markAsRead(notificationId) {
        const notification = this.notifications.find(n => n.id === notificationId);
        if (notification) {
            notification.read = true;
            this.updateUnreadCount();
            this.saveToLocalStorage();
            this.notifyListeners();
        }
    }

    // Mark all as read
    markAllAsRead() {
        this.notifications.forEach(n => n.read = true);
        this.updateUnreadCount();
        this.saveToLocalStorage();
        this.notifyListeners();
    }

    // Clear all notifications
    clearAll() {
        this.notifications = [];
        this.updateUnreadCount();
        this.saveToLocalStorage();
        this.notifyListeners();
    }

    // Show browser notification
    showBrowserNotification(notification) {
        if (!('Notification' in window)) {
            console.log('Browser does not support notifications');
            return;
        }

        if (Notification.permission === 'granted') {
            try {
                const n = new Notification(notification.title, {
                    body: notification.message,
                    icon: '/favicon.ico',
                    badge: '/favicon.ico',
                    tag: notification.id,
                    requireInteraction: notification.type === 'negotiation_success'
                });

                n.onclick = () => {
                    window.focus();
                    this.markAsRead(notification.id);
                    n.close();
                };
            } catch (error) {
                console.error('Error showing browser notification:', error);
            }
        } else if (Notification.permission !== 'denied') {
            Notification.requestPermission().then(permission => {
                if (permission === 'granted') {
                    this.showBrowserNotification(notification);
                }
            });
        }
    }

    // Register a listener for notification updates
    addListener(callback) {
        this.listeners.add(callback);
    }

    // Remove a listener
    removeListener(callback) {
        this.listeners.delete(callback);
    }

    // Notify all listeners
    notifyListeners() {
        this.listeners.forEach(callback => {
            try {
                callback({
                    notifications: this.notifications,
                    unreadCount: this.unreadCount
                });
            } catch (error) {
                console.error('Error in notification listener:', error);
            }
        });
    }

    // Get all notifications
    getNotifications() {
        return this.notifications;
    }

    // Get unread count
    getUnreadCount() {
        return this.unreadCount;
    }

    // Cleanup
    destroy() {
        this.stopPolling();
        this.listeners.clear();
        console.log('🧹 Notification service destroyed');
    }
}

// Make available globally
window.NotificationService = NotificationService;
