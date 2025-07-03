// Messaging Panel functionality
let globalUserConversations = [];
let globalUnreadCount = 0;
let locallyReadConversations = new Set(); // Track conversations marked as read locally

// Setup Messaging Panel
function setupMessagingPanel() {
    console.log('📱 Setting up messaging panel...');
    
    const messageToggleBtn = document.getElementById('messageToggleBtn');
    const messagePanel = document.getElementById('messagePanel');
    const profileNotificationBadge = document.getElementById('profileNotificationBadge');
    const messageNotificationBadge = document.getElementById('messageNotificationBadge');
    
    if (!messageToggleBtn || !messagePanel) {
        console.error('Messaging panel elements not found');
        return;
    }
    
    let isMessagingPanelOpen = false;

    // Toggle message panel
    messageToggleBtn.addEventListener('click', async () => {
        isMessagingPanelOpen = !isMessagingPanelOpen;
        if (isMessagingPanelOpen) {
            messagePanel.classList.remove('hidden');
            await loadUserConversations();
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
            globalUserConversations.forEach(conv => {
                locallyReadConversations.add(conv.id);
                conv.unread_count = 0;
            });
            
            // Force update
            window.updateUnreadCount();
            
            // Also update the display
            displayConversations();
        });
    }

    // Close panel when clicking outside
    document.addEventListener('click', (event) => {
        if (!event.target.closest('#messagingPanel')) {
            messagePanel.classList.add('hidden');
            isMessagingPanelOpen = false;
        }
    });

    // Load user's conversations
    async function loadUserConversations() {
        console.log('📬 Loading user conversations...');
        
        const currentUser = JSON.parse(localStorage.getItem('currentUser'));
        if (!currentUser) {
            console.log('No current user found');
            return;
        }

        try {
            // First verify current user is registered in profiles
            const { data: currentProfile, error: profileError } = await supabase
                .from('profiles')
                .select('email')
                .eq('email', currentUser.email)
                .single();

            if (profileError || !currentProfile) {
                console.error('Current user not found in profiles database:', profileError);
                const conversationTabs = document.getElementById('conversationTabs');
                if (conversationTabs) {
                    conversationTabs.innerHTML = '<div class="p-4 text-red-500 text-center">Please register to access messaging</div>';
                }
                return;
            }

            const { data: conversations, error } = await supabase
                .from('conversations')
                .select(`
                    id,
                    sender_email,
                    receiver_email,
                    listing_id,
                    created_at,
                    listings (
                        title
                    )
                `)
                .or(`sender_email.eq.${currentUser.email},receiver_email.eq.${currentUser.email}`)
                .order('created_at', { ascending: false });

            if (error) {
                console.error('Error loading conversations:', error);
                return;
            }

            console.log('📊 RAW CONVERSATIONS:', conversations);

            // Get unread counts for all conversations
            const conversationIds = conversations.map(c => c.id);
            const { data: unreadCounts, error: unreadError } = await supabase
                .rpc('get_unread_counts_for_user', { 
                    user_email: currentUser.email,
                    conversation_ids: conversationIds 
                });

            if (unreadError) {
                console.error('Error getting unread counts:', unreadError);
            }

            console.log('📊 UNREAD COUNTS:', unreadCounts);

            // Merge unread counts with conversations
            const filteredConversations = conversations.map(conv => {
                const unreadData = unreadCounts?.find(u => u.conversation_id === conv.id);
                let unreadCount = unreadData ? unreadData.unread_count : 0;
                
                // Override with local read state
                if (locallyReadConversations.has(conv.id)) {
                    unreadCount = 0;
                }
                
                return {
                    ...conv,
                    unread_count: unreadCount
                };
            });

            globalUserConversations = filteredConversations;
            window.globalUserConversations = globalUserConversations; // Keep global reference updated
            displayConversations();
            await window.updateUnreadCount();
            
        } catch (error) {
            console.error('Error in loadUserConversations:', error);
        }
    }

    // Display conversations in tabs
    function displayConversations() {
        const conversationTabs = document.getElementById('conversationTabs');
        const currentUser = JSON.parse(localStorage.getItem('currentUser'));
        
        if (!conversationTabs) return;
        
        if (globalUserConversations.length === 0) {
            conversationTabs.innerHTML = '<div id="noConversations" class="p-4 text-gray-500 text-center">No conversations yet</div>';
            return;
        }

        conversationTabs.innerHTML = globalUserConversations.map(conv => {
            const otherUserEmail = conv.sender_email === currentUser.email ? conv.receiver_email : conv.sender_email;
            const listingTitle = conv.listings ? conv.listings.title : 'Unknown Listing';
            
            // Extract username from email (part before @)
            const otherUserName = otherUserEmail.split('@')[0];
            
            // Check if conversation has unread messages
            const hasUnread = conv.unread_count > 0;
            const unreadBadge = hasUnread ? `<span class="bg-red-500 text-white rounded-full w-5 h-5 text-xs flex items-center justify-center ml-2">${conv.unread_count}</span>` : '';
            
            return `
                <div class="border-b hover:bg-gray-50 cursor-pointer ${hasUnread ? 'bg-blue-50' : ''}" onclick="openConversationInModal('${conv.id}', '${listingTitle}', '${conv.listing_id}', '${otherUserEmail}')">
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

    // Setup real-time subscriptions
    setupRealtimeSubscriptions(loadUserConversations);
    
    // Initialize
    loadUserConversations();
    
    // Expose function globally for external access
    window.refreshConversations = loadUserConversations;
    
    // Update global reference when conversations are loaded
    window.globalUserConversations = globalUserConversations;

    console.log('✅ Messaging panel setup complete');
}

// Update unread message count (now accessible globally)
window.updateUnreadCount = async function() {
    const messageNotificationBadge = document.getElementById('messageNotificationBadge');
    const profileNotificationBadge = document.getElementById('profileNotificationBadge');
    
    const currentUser = JSON.parse(localStorage.getItem('currentUser'));
    if (!currentUser) return;

    // Calculate total unread messages across all conversations
    let totalUnread = 0;
    const detailedLog = [];
    
    for (const conv of globalUserConversations) {
        const isLocallyRead = locallyReadConversations.has(conv.id);
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
        conversations: globalUserConversations.length,
        locallyReadSet: Array.from(locallyReadConversations),
        detailedLog: detailedLog,
        totalUnread: totalUnread
    });
    
    // FORCE hide notifications if totalUnread is 0
    if (totalUnread === 0) {
        if (messageNotificationBadge) messageNotificationBadge.classList.add('hidden');
        if (profileNotificationBadge) profileNotificationBadge.classList.add('hidden');
        console.log('🔥 FORCING notifications to hide - totalUnread is 0');
    } else {
        if (messageNotificationBadge) {
            messageNotificationBadge.textContent = totalUnread;
            messageNotificationBadge.classList.remove('hidden');
        }
        if (profileNotificationBadge) {
            profileNotificationBadge.textContent = totalUnread;
            profileNotificationBadge.classList.remove('hidden');
        }
        console.log('✅ Showing notifications:', totalUnread);
    }
    
    globalUnreadCount = totalUnread;
};

// Setup real-time subscriptions
function setupRealtimeSubscriptions(loadUserConversations) {
    console.log('🔔 Setting up real-time subscriptions...');
    
    const currentUser = JSON.parse(localStorage.getItem('currentUser'));
    if (!currentUser) return;

    // SIMPLIFIED Messaging panel real-time updates
    const panelChannel = supabase
        .channel('panel_realtime_' + Math.random())
        .on('postgres_changes', { 
            event: 'INSERT', 
            schema: 'public', 
            table: 'messages' 
        }, (payload) => {
            console.log('🔔 PANEL: New message event:', payload);
            
            // If message is for current user (not sent by them), instantly update UI
            if (payload.new.sender_email !== currentUser.email && window.globalUserConversations) {
                const convIndex = window.globalUserConversations.findIndex(c => c.id === payload.new.conversation_id);
                if (convIndex !== -1) {
                    // Only increment if this conversation hasn't been locally marked as read
                    if (!locallyReadConversations.has(payload.new.conversation_id)) {
                        console.log('⚡ INSTANTLY updating unread count for new message');
                        window.globalUserConversations[convIndex].unread_count = (window.globalUserConversations[convIndex].unread_count || 0) + 1;
                        if (window.updateUnreadCount) {
                            window.updateUnreadCount();
                        }
                    } else {
                        console.log('🔒 Skipping increment - conversation locally marked as read');
                    }
                }
            }
            
            // Reduce frequency of database refreshes to prevent overwrites
            if (!window.lastRefreshTime || Date.now() - window.lastRefreshTime > 5000) {
                window.lastRefreshTime = Date.now();
                setTimeout(() => loadUserConversations(), 3000);
            }
        })
        .on('postgres_changes', { 
            event: 'INSERT', 
            schema: 'public', 
            table: 'conversations' 
        }, (payload) => {
            console.log('💬 PANEL: New conversation event:', payload);
            
            if (payload.new.sender_email === currentUser.email || payload.new.receiver_email === currentUser.email) {
                console.log('🔄 Refreshing conversations panel for new conversation');
                loadUserConversations();
            }
        })
        .on('postgres_changes', { 
            event: '*', 
            schema: 'public', 
            table: 'conversation_reads' 
        }, (payload) => {
            console.log('👀 READ STATUS UPDATE:', payload);
            
            // Only refresh if the read status is for current user and not locally initiated
            if (payload.new?.user_email === currentUser.email) {
                console.log('🔄 Refreshing conversations due to read status change');
                setTimeout(() => loadUserConversations(), 1000);
            }
        })
        .subscribe((status) => {
            console.log('📱 PANEL SUBSCRIPTION STATUS:', status);
        });

    // FALLBACK: Polling for updates if real-time fails
    setTimeout(() => {
        console.log('⚠️ Starting fallback polling for messages');
        setInterval(() => {
            if (currentConversationId) {
                loadMessages(currentConversationId);
            }
            loadUserConversations();
        }, 3000);
    }, 10000);
}

// Global function to open conversation in modal
window.openConversationInModal = async function(conversationId, listingTitle, listingId, otherUserEmail) {
    // Close messaging panel
    const messagePanel = document.getElementById('messagePanel');
    if (messagePanel) {
        messagePanel.classList.add('hidden');
    }
    
    // INSTANTLY clear notifications - don't wait for database
    console.log('⚡ INSTANTLY clearing notifications for conversation:', conversationId);
    
    // Mark conversation as read locally and persistently
    locallyReadConversations.add(conversationId);
    console.log('🔒 Added to locally read set:', conversationId);
    
    // Find and update the conversation in local array
    if (window.globalUserConversations) {
        const convIndex = window.globalUserConversations.findIndex(c => c.id === conversationId);
        if (convIndex !== -1) {
            window.globalUserConversations[convIndex].unread_count = 0;
            console.log('✅ Locally marked conversation as read');
        }
    }
    
    // Immediately update notification badges
    if (window.updateUnreadCount) {
        window.updateUnreadCount();
    }
    
    // Set up chat modal with existing conversation
    currentConversationId = conversationId;
    const otherUserName = otherUserEmail ? otherUserEmail.split('@')[0] : 'User';
    const chatTitle = document.getElementById('chatTitle');
    if (chatTitle) {
        chatTitle.textContent = `Chat with ${otherUserName} about ${listingTitle}`;
    }
    
    await loadMessages(conversationId);
    
    const chatModal = document.getElementById('chatModal');
    if (chatModal) {
        chatModal.classList.add('active');
    }
    
    // Update database in background (don't wait)
    const currentUser = JSON.parse(localStorage.getItem('currentUser'));
    supabase
        .from('conversation_reads')
        .upsert({
            conversation_id: conversationId,
            user_email: currentUser.email,
            last_read_at: new Date().toISOString()
        }, {
            onConflict: 'conversation_id,user_email'
        })
        .then(({ error }) => {
            if (error) {
                console.error('❌ Background database update failed:', error);
            } else {
                console.log('✅ Conversation marked as read in database');
            }
        });
};