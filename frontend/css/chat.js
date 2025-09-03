import { sanitizeInput } from './utils.js';

let currentConversationId = null;
let currentListing = null;

function setupChat(supabase) {
    const chatModal = document.getElementById('chatModal');
    const chatCloseButton = document.querySelector('.chat-close-button');
    const chatMessagesContainer = document.getElementById('chatMessages');
    const chatInput = document.getElementById('chatInput');
    const chatSendBtn = document.getElementById('chatSendBtn');

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

    async function startConversation(listing) {
        const currentUser = JSON.parse(null);
        if (!currentUser) {
            alert('Please log in to start a chat.');
            window.location.href = '/login';
            return;
        }

        currentListing = listing;
        document.getElementById('chatTitle').textContent = `Chat about ${listing.title}`;

        const { data: conversations, error } = await supabase
            .from('conversations')
            .select('*')
            .eq('listing_id', listing.id)
            .eq('sender_email', currentUser.email)
            .eq('receiver_email', listing.user_email);

        if (error) {
            console.error('Error checking conversation:', error);
            alert('Failed to load conversation: ' + error.message);
            return;
        }

        let conversation;
        if (conversations && conversations.length > 0) {
            conversation = conversations[0];
        } else {
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
                console.error('Error creating conversation:', insertError);
                alert('Failed to start conversation: ' + insertError.message);
                return;
            }
            conversation = data;
        }

        currentConversationId = conversation.id;
        await loadMessages(supabase, conversation.id);
        chatModal.style.display = 'block';
        console.log('Conversation started/loaded:', conversation.id);
    }

    async function loadMessages(supabase, conversationId) {
        const { data: messages, error } = await supabase
            .from('messages')
            .select('*')
            .eq('conversation_id', conversationId)
            .order('created_at', { ascending: true });

        if (error) {
            console.error('Error loading messages:', error);
            alert('Failed to load messages: ' + error.message);
            return;
        }

        chatMessagesContainer.innerHTML = '';
        const currentUser = JSON.parse(null);

        messages.forEach(message => {
            const messageElement = document.createElement('div');
            messageElement.className = `message ${message.sender_email === currentUser.email ? 'sent' : 'received'}`;
            messageElement.innerHTML = `
                <p>${sanitizeInput(message.content)}</p>
                <div class="message-timestamp">${new Date(message.created_at).toLocaleTimeString()}</div>
            `;
            chatMessagesContainer.appendChild(messageElement);
        });

        chatMessagesContainer.scrollTop = chatMessagesContainer.scrollHeight;
        console.log('Messages loaded:', messages.length);
    }

    chatSendBtn.addEventListener('click', async () => {
        const messageContent = chatInput.value.trim();
        if (!messageContent || !currentConversationId) return;

        const currentUser = JSON.parse(null);
        const { error } = await supabase
            .from('messages')
            .insert({
                conversation_id: currentConversationId,
                sender_email: currentUser.email,
                content: messageContent,
                created_at: new Date().toISOString()
            });

        if (error) {
            console.error('Error sending message:', error);
            alert('Failed to send message: ' + error.message);
            return;
        }

        chatInput.value = '';
        await loadMessages(supabase, currentConversationId);
        console.log('Message sent:', messageContent);
    });

    // Enhanced real-time subscriptions
    const realtimeChannel = supabase
        .channel('enhanced_chat_' + Math.random())
        .on('postgres_changes', { 
            event: 'INSERT', 
            schema: 'public', 
            table: 'messages' 
        }, (payload) => {
            if (currentConversationId === payload.new.conversation_id) {
                console.log('📨 New message received:', payload.new);
                appendMessageToUI(payload.new);
                updateReadStatus();
            }
        })
        .on('postgres_changes', { 
            event: 'UPDATE', 
            schema: 'public', 
            table: 'conversation_reads' 
        }, (payload) => {
            if (currentConversationId === payload.new.conversation_id) {
                console.log('👁️ Read status updated:', payload.new);
                updateMessageReadStatus(payload.new);
            }
        })
        .on('presence', { event: 'sync' }, () => {
            console.log('👥 Presence sync');
            updateUserPresence();
        })
        .on('presence', { event: 'join' }, ({ key, newPresences }) => {
            console.log('✅ User joined:', key, newPresences);
            showUserOnline(key);
        })
        .on('presence', { event: 'leave' }, ({ key, leftPresences }) => {
            console.log('❌ User left:', key, leftPresences);
            showUserOffline(key);
        })
        .on('broadcast', { event: 'typing' }, (payload) => {
            if (payload.conversation_id === currentConversationId) {
                console.log('⌨️ Typing indicator:', payload);
                showTypingIndicator(payload.user_email, payload.is_typing);
            }
        })
        .subscribe();

    // Store channel reference for cleanup
    window.currentChatChannel = realtimeChannel;

    // Set up typing indicators
    setupTypingIndicators();
    
    // Set up presence tracking
    setupPresenceTracking();
    
    // Set up connection monitoring
    setupConnectionMonitoring();

    document.addEventListener('click', (e) => {
        if (e.target.classList.contains('chat-btn')) {
            const listing = JSON.parse(e.target.dataset.listing);
            startConversation(listing);
        }
    });
}

// Enhanced real-time functions
let typingTimeout;
let isTyping = false;
let typingIndicators = new Map();

function setupTypingIndicators() {
    const messageInput = document.getElementById('messageInput');
    if (!messageInput) return;
    
    messageInput.addEventListener('input', () => {
        if (!isTyping) {
            isTyping = true;
            broadcastTyping(true);
        }
        
        clearTimeout(typingTimeout);
        typingTimeout = setTimeout(() => {
            isTyping = false;
            broadcastTyping(false);
        }, 1000);
    });
    
    messageInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            isTyping = false;
            broadcastTyping(false);
        }
    });
}

function broadcastTyping(typing) {
    if (!window.currentChatChannel || !currentConversationId) return;
    
    const currentUser = JSON.parse(null);
    if (!currentUser) return;
    
    window.currentChatChannel.send({
        type: 'broadcast',
        event: 'typing',
        payload: {
            conversation_id: currentConversationId,
            user_email: currentUser.email,
            is_typing: typing,
            timestamp: new Date().toISOString()
        }
    });
}

function showTypingIndicator(userEmail, isTyping) {
    const currentUser = JSON.parse(null);
    if (!currentUser || userEmail === currentUser.email) return;
    
    const chatContainer = document.getElementById('chatMessages');
    if (!chatContainer) return;
    
    const indicatorId = `typing-${userEmail.replace(/[^a-zA-Z0-9]/g, '')}`;
    let indicator = document.getElementById(indicatorId);
    
    if (isTyping) {
        if (!indicator) {
            indicator = document.createElement('div');
            indicator.id = indicatorId;
            indicator.className = 'typing-indicator message received';
            indicator.innerHTML = `
                <div class="typing-animation">
                    <span></span>
                    <span></span>
                    <span></span>
                </div>
                <div class="message-timestamp">typing...</div>
            `;
            chatContainer.appendChild(indicator);
            chatContainer.scrollTop = chatContainer.scrollHeight;
        }
        typingIndicators.set(userEmail, Date.now());
    } else {
        if (indicator) {
            indicator.remove();
        }
        typingIndicators.delete(userEmail);
    }
}

function setupPresenceTracking() {
    if (!window.currentChatChannel || !currentConversationId) return;
    
    const currentUser = JSON.parse(null);
    if (!currentUser) return;
    
    // Track presence
    window.currentChatChannel.track({
        user_email: currentUser.email,
        online_at: new Date().toISOString()
    });
}

function updateUserPresence() {
    if (!window.currentChatChannel) return;
    
    const presenceState = window.currentChatChannel.presenceState();
    const onlineUsers = Object.keys(presenceState);
    
    console.log('👥 Online users:', onlineUsers);
    
    // Update UI to show online users
    updatePresenceIndicators(onlineUsers);
}

function showUserOnline(userKey) {
    const presenceIndicator = document.querySelector(`[data-user="${userKey}"] .presence-indicator`);
    if (presenceIndicator) {
        presenceIndicator.classList.add('online');
        presenceIndicator.title = 'Online';
    }
}

function showUserOffline(userKey) {
    const presenceIndicator = document.querySelector(`[data-user="${userKey}"] .presence-indicator`);
    if (presenceIndicator) {
        presenceIndicator.classList.remove('online');
        presenceIndicator.title = 'Offline';
    }
}

function updatePresenceIndicators(onlineUsers) {
    const chatHeader = document.querySelector('.chat-header');
    if (!chatHeader) return;
    
    let presenceDiv = chatHeader.querySelector('.presence-status');
    if (!presenceDiv) {
        presenceDiv = document.createElement('div');
        presenceDiv.className = 'presence-status';
        chatHeader.appendChild(presenceDiv);
    }
    
    const isOnline = onlineUsers.length > 1; // More than current user
    presenceDiv.innerHTML = `
        <div class="presence-indicator ${isOnline ? 'online' : 'offline'}"></div>
        <span class="presence-text">${isOnline ? 'Online' : 'Offline'}</span>
    `;
}

function appendMessageToUI(message) {
    const chatContainer = document.getElementById('chatMessages');
    if (!chatContainer) return;
    
    const currentUser = JSON.parse(null);
    const isCurrentUser = message.sender_email === currentUser.email;
    
    const messageElement = document.createElement('div');
    messageElement.className = `message ${isCurrentUser ? 'sent' : 'received'}`;
    messageElement.dataset.messageId = message.id;
    
    if (message.message_type === 'text') {
        messageElement.innerHTML = `
            <p>${message.content}</p>
            <div class="message-timestamp">
                ${new Date(message.created_at).toLocaleTimeString()}
                ${isCurrentUser ? '<span class="read-status" data-read="false">●</span>' : ''}
            </div>
        `;
    } else if (message.message_type === 'file') {
        const fileData = JSON.parse(message.content);
        messageElement.innerHTML = `
            <div class="file-message">
                <a href="${fileData.url}" target="_blank" class="file-link">
                    📎 ${fileData.name}
                </a>
            </div>
            <div class="message-timestamp">
                ${new Date(message.created_at).toLocaleTimeString()}
                ${isCurrentUser ? '<span class="read-status" data-read="false">●</span>' : ''}
            </div>
        `;
    }
    
    chatContainer.appendChild(messageElement);
    chatContainer.scrollTop = chatContainer.scrollHeight;
}

async function updateReadStatus() {
    if (!currentConversationId) return;
    
    const currentUser = JSON.parse(null);
    if (!currentUser) return;
    
    try {
        await supabase
            .from('conversation_reads')
            .upsert({
                conversation_id: currentConversationId,
                user_email: currentUser.email,
                last_read_at: new Date().toISOString()
            });
    } catch (error) {
        console.error('Error updating read status:', error);
    }
}

function updateMessageReadStatus(readData) {
    // Update read receipts for messages
    const messages = document.querySelectorAll('.message.sent');
    messages.forEach(message => {
        const readStatus = message.querySelector('.read-status');
        if (readStatus) {
            readStatus.setAttribute('data-read', 'true');
            readStatus.textContent = '✓✓';
            readStatus.style.color = '#10b981';
        }
    });
}

// Connection monitoring and offline support
let isOnline = navigator.onLine;
let messageQueue = [];
let reconnectAttempts = 0;
const maxReconnectAttempts = 5;

function setupConnectionMonitoring() {
    // Add connection status indicator
    const statusIndicator = document.createElement('div');
    statusIndicator.id = 'connection-status';
    statusIndicator.className = 'connection-status connected';
    statusIndicator.textContent = 'Connected';
    document.body.appendChild(statusIndicator);
    
    // Monitor online/offline status
    window.addEventListener('online', () => {
        isOnline = true;
        updateConnectionStatus('connected');
        processMessageQueue();
        reconnectRealtime();
    });
    
    window.addEventListener('offline', () => {
        isOnline = false;
        updateConnectionStatus('disconnected');
    });
    
    // Monitor Supabase connection
    if (window.currentChatChannel) {
        window.currentChatChannel.on('system', { event: 'disconnect' }, () => {
            updateConnectionStatus('disconnected');
            attemptReconnect();
        });
        
        window.currentChatChannel.on('system', { event: 'connect' }, () => {
            updateConnectionStatus('connected');
            reconnectAttempts = 0;
        });
    }
}

function updateConnectionStatus(status) {
    const indicator = document.getElementById('connection-status');
    if (!indicator) return;
    
    indicator.className = `connection-status ${status}`;
    
    switch (status) {
        case 'connected':
            indicator.textContent = 'Connected';
            break;
        case 'connecting':
            indicator.textContent = 'Connecting...';
            break;
        case 'disconnected':
            indicator.textContent = 'Offline';
            break;
    }
    
    // Auto-hide after 3 seconds if connected
    if (status === 'connected') {
        setTimeout(() => {
            indicator.style.opacity = '0';
            setTimeout(() => {
                indicator.style.opacity = '1';
            }, 3000);
        }, 2000);
    }
}

function attemptReconnect() {
    if (reconnectAttempts >= maxReconnectAttempts) {
        console.error('❌ Max reconnection attempts reached');
        return;
    }
    
    reconnectAttempts++;
    const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 30000); // Exponential backoff, max 30s
    
    updateConnectionStatus('connecting');
    console.log(`🔄 Attempting reconnection ${reconnectAttempts}/${maxReconnectAttempts} in ${delay}ms`);
    
    setTimeout(() => {
        reconnectRealtime();
    }, delay);
}

function reconnectRealtime() {
    if (window.currentChatChannel) {
        window.currentChatChannel.unsubscribe();
    }
    
    // Re-establish the connection
    setupChat(supabase);
}

function queueMessage(message) {
    messageQueue.push({
        ...message,
        timestamp: new Date().toISOString(),
        id: `temp_${Date.now()}_${Math.random()}`
    });
    
    console.log('📤 Message queued for sending when online:', message);
    
    // Show pending status in UI
    showPendingMessage(message);
}

async function processMessageQueue() {
    if (messageQueue.length === 0) return;
    
    console.log(`📨 Processing ${messageQueue.length} queued messages`);
    
    const messages = [...messageQueue];
    messageQueue = [];
    
    for (const message of messages) {
        try {
            await sendQueuedMessage(message);
            updatePendingMessage(message.id, 'sent');
        } catch (error) {
            console.error('❌ Failed to send queued message:', error);
            messageQueue.push(message); // Re-queue on failure
            updatePendingMessage(message.id, 'failed');
        }
    }
}

async function sendQueuedMessage(message) {
    const { error } = await supabase
        .from('messages')
        .insert({
            conversation_id: message.conversation_id,
            sender_email: message.sender_email,
            content: message.content,
            message_type: message.message_type || 'text'
        });
    
    if (error) throw error;
}

function showPendingMessage(message) {
    const chatContainer = document.getElementById('chatMessages');
    if (!chatContainer) return;
    
    const messageElement = document.createElement('div');
    messageElement.className = 'message sent pending';
    messageElement.id = `pending-${message.id}`;
    messageElement.innerHTML = `
        <p>${message.content}</p>
        <div class="message-timestamp">
            ${new Date(message.timestamp).toLocaleTimeString()}
            <span class="message-status pending">⏳ Sending...</span>
        </div>
    `;
    
    chatContainer.appendChild(messageElement);
    chatContainer.scrollTop = chatContainer.scrollHeight;
}

function updatePendingMessage(messageId, status) {
    const messageElement = document.getElementById(`pending-${messageId}`);
    if (!messageElement) return;
    
    const statusElement = messageElement.querySelector('.message-status');
    if (!statusElement) return;
    
    switch (status) {
        case 'sent':
            statusElement.textContent = '✓ Sent';
            statusElement.className = 'message-status delivered';
            messageElement.classList.remove('pending');
            break;
        case 'failed':
            statusElement.textContent = '❌ Failed';
            statusElement.className = 'message-status failed';
            break;
    }
}

// Enhanced message persistence with local storage
function saveMessageToLocal(message) {
    const key = `chat_message_${message.conversation_id}_${Date.now()}`;
    // localStorage removed - using Supabase);
}

function loadLocalMessages(conversationId) {
    const messages = [];
    for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key && key.startsWith(`chat_message_${conversationId}_`)) {
            try {
                const message = JSON.parse(null);
                messages.push(message);
            } catch (error) {
                console.error('Error parsing local message:', error);
            }
        }
    }
    return messages.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
}

function clearLocalMessages(conversationId) {
    const keysToRemove = [];
    for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key && key.startsWith(`chat_message_${conversationId}_`)) {
            keysToRemove.push(key);
        }
    }
    keysToRemove.forEach(key => // localStorage removed);
}

// Make functions available globally
window.setupConnectionMonitoring = setupConnectionMonitoring;
window.queueMessage = queueMessage;
window.processMessageQueue = processMessageQueue;

export { setupChat };