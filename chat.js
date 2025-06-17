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
        const currentUser = JSON.parse(localStorage.getItem('currentUser'));
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
        const currentUser = JSON.parse(localStorage.getItem('currentUser'));

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

        const currentUser = JSON.parse(localStorage.getItem('currentUser'));
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

    // Real-time message subscription
    supabase
        .channel('public:messages')
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages' }, (payload) => {
            if (currentConversationId === payload.new.conversation_id) {
                console.log('New message received:', payload.new);
                loadMessages(supabase, currentConversationId);
            }
        })
        .subscribe();

    document.addEventListener('click', (e) => {
        if (e.target.classList.contains('chat-btn')) {
            const listing = JSON.parse(e.target.dataset.listing);
            startConversation(listing);
        }
    });
}

export { setupChat };