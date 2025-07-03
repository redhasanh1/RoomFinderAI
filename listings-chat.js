// Chat System Functions
async function setupChat() {
    console.log('🎬 Setting up chat system...');
    
    const chatModal = document.getElementById('chatModal');
    const chatSendBtn = document.getElementById('chatSendBtn');
    const chatInput = document.getElementById('chatInput');
    const fileInput = document.getElementById('fileInput');
    const fileUploadBtn = document.getElementById('fileUploadBtn');
    const closeButtons = document.querySelectorAll('.chat-close-button');

    if (!chatModal || !chatSendBtn || !chatInput) {
        console.error('❌ Chat elements not found');
        return;
    }

    // Close modal event listeners
    closeButtons.forEach(button => {
        button.addEventListener('click', () => {
            chatModal.classList.remove('active');
            currentConversationId = null;
        });
    });

    // Close modal on outside click
    chatModal.addEventListener('click', (e) => {
        if (e.target === chatModal) {
            chatModal.classList.remove('active');
            currentConversationId = null;
        }
    });

    // Send message event listeners
    chatSendBtn.addEventListener('click', sendMessage);
    chatInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });

    // File upload handling
    if (fileInput && fileUploadBtn) {
        fileInput.addEventListener('change', handleFileSelection);
        fileUploadBtn.classList.remove('hidden');
    }

    console.log('✅ Chat system setup complete');
}

async function loadMessages(conversationId) {
    console.log('📬 Loading messages for conversation:', conversationId);
    
    try {
        const { data: messages, error } = await supabase
            .from('messages')
            .select('*')
            .eq('conversation_id', conversationId)
            .order('created_at', { ascending: true });

        if (error) throw error;

        const chatMessages = document.getElementById('chatMessages');
        if (!chatMessages) return;

        const currentUser = JSON.parse(localStorage.getItem('currentUser'));
        
        chatMessages.innerHTML = messages.map(message => {
            const isSent = message.sender_email === currentUser.email;
            const messageClass = isSent ? 'sent' : 'received';
            
            let messageContent = message.content;
            
            // Handle file messages
            if (message.file_url) {
                const fileName = message.file_name || 'File';
                const fileSize = message.file_size ? formatFileSize(message.file_size) : '';
                messageContent = `
                    <div class="file-message">
                        <a href="${message.file_url}" target="_blank" class="flex items-center space-x-2 text-blue-600 hover:text-blue-800">
                            <span>📎</span>
                            <div>
                                <div class="font-medium">${fileName}</div>
                                ${fileSize ? `<div class="text-xs text-gray-500">${fileSize}</div>` : ''}
                            </div>
                        </a>
                    </div>
                `;
            }
            
            return `
                <div class="message ${messageClass}">
                    <div>${messageContent}</div>
                    <div class="message-timestamp">${new Date(message.created_at).toLocaleString()}</div>
                </div>
            `;
        }).join('');

        // Scroll to bottom
        chatMessages.scrollTop = chatMessages.scrollHeight;
        
        console.log(`✅ Loaded ${messages.length} messages`);
        
    } catch (error) {
        console.error('❌ Error loading messages:', error);
    }
}

async function sendMessage() {
    const chatInput = document.getElementById('chatInput');
    const selectedFiles = document.getElementById('selectedFiles');
    
    if (!chatInput || !currentConversationId) return;

    const messageText = chatInput.value.trim();
    const fileInputElement = document.getElementById('fileInput');
    const files = fileInputElement?.files;

    if (!messageText && (!files || files.length === 0)) return;

    const currentUser = JSON.parse(localStorage.getItem('currentUser'));
    if (!currentUser) return;

    try {
        // Send text message
        if (messageText) {
            const { error } = await supabase
                .from('messages')
                .insert({
                    conversation_id: currentConversationId,
                    sender_email: currentUser.email,
                    content: messageText
                });

            if (error) throw error;
        }

        // Send file messages
        if (files && files.length > 0) {
            for (const file of files) {
                await sendFileMessage(file);
            }
            
            // Clear file selection
            fileInputElement.value = '';
            selectedFiles.innerHTML = '';
            selectedFiles.classList.add('hidden');
        }

        // Clear text input
        chatInput.value = '';
        
        // Reload messages
        await loadMessages(currentConversationId);
        
    } catch (error) {
        console.error('❌ Error sending message:', error);
        alert('Failed to send message: ' + error.message);
    }
}

async function sendFileMessage(file) {
    if (!currentConversationId) return;

    const currentUser = JSON.parse(localStorage.getItem('currentUser'));
    if (!currentUser) return;

    try {
        // Upload file to Supabase storage
        const fileName = `${Date.now()}_${file.name}`;
        const { data: uploadData, error: uploadError } = await supabase.storage
            .from('chat-files')
            .upload(fileName, file);

        if (uploadError) throw uploadError;

        // Get public URL
        const { data: urlData } = supabase.storage
            .from('chat-files')
            .getPublicUrl(fileName);

        // Insert file message
        const { error: messageError } = await supabase
            .from('messages')
            .insert({
                conversation_id: currentConversationId,
                sender_email: currentUser.email,
                content: `Sent a file: ${file.name}`,
                file_url: urlData.publicUrl,
                file_name: file.name,
                file_size: file.size
            });

        if (messageError) throw messageError;

    } catch (error) {
        console.error('❌ Error sending file:', error);
        throw error;
    }
}

function handleFileSelection() {
    const fileInput = document.getElementById('fileInput');
    const selectedFiles = document.getElementById('selectedFiles');
    
    if (!fileInput || !selectedFiles) return;

    const files = fileInput.files;
    
    if (files.length === 0) {
        selectedFiles.classList.add('hidden');
        return;
    }

    selectedFiles.innerHTML = Array.from(files).map((file, index) => `
        <div class="flex items-center justify-between bg-gray-100 p-2 rounded">
            <span class="text-sm">${file.name} (${formatFileSize(file.size)})</span>
            <button onclick="removeFile(${index})" class="text-red-600 hover:text-red-800">✕</button>
        </div>
    `).join('');
    
    selectedFiles.classList.remove('hidden');
}

function removeFile(index) {
    const fileInput = document.getElementById('fileInput');
    if (!fileInput) return;

    const dt = new DataTransfer();
    const files = fileInput.files;
    
    for (let i = 0; i < files.length; i++) {
        if (i !== index) {
            dt.items.add(files[i]);
        }
    }
    
    fileInput.files = dt.files;
    handleFileSelection();
}

function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// Global variables for chat
let currentListing = null;
let isCurrentUserLandlord = false;

async function startConversationWithListing(listing) {
    console.log('💬 Starting conversation for listing:', listing);
    
    const currentUser = JSON.parse(localStorage.getItem('currentUser'));
    if (!currentUser) {
        alert('Please log in to start a chat.');
        window.location.href = '/login';
        return;
    }

    // Verify listing has owner email
    if (!listing.user_email) {
        alert('Cannot start chat: Listing owner not specified.');
        return;
    }

    if (listing.user_email === currentUser.email) {
        alert('You cannot start a conversation with yourself.');
        return;
    }

    try {
        // Store current listing for context
        currentListing = listing;
        
        // Check if conversation already exists
        const { data: existingConversations, error: searchError } = await supabase
            .from('conversations')
            .select('*')
            .eq('listing_id', listing.id)
            .or(`and(sender_email.eq.${currentUser.email},receiver_email.eq.${listing.user_email}),and(sender_email.eq.${listing.user_email},receiver_email.eq.${currentUser.email})`);

        if (searchError) {
            console.error('Error searching conversations:', searchError);
            throw searchError;
        }

        let conversation;
        
        if (existingConversations && existingConversations.length > 0) {
            conversation = existingConversations[0];
            console.log('Found existing conversation:', conversation.id);
        } else {
            // Create new conversation
            const { data: newConversation, error: createError } = await supabase
                .from('conversations')
                .insert({
                    listing_id: listing.id,
                    sender_email: currentUser.email,
                    receiver_email: listing.user_email
                })
                .select('*')
                .single();

            if (createError) {
                console.error('Error creating conversation:', createError);
                throw createError;
            }
            
            conversation = newConversation;
            console.log('Created new conversation:', conversation.id);
        }

        // Set up chat modal
        currentConversationId = conversation.id;
        document.getElementById('chatTitle').textContent = `Chat about ${listing.title}`;
        
        // Show/hide file upload button based on user role
        const fileUploadBtn = document.getElementById('fileUploadBtn');
        isCurrentUserLandlord = currentUser.email === listing.user_email;
        if (fileUploadBtn) {
            if (isCurrentUserLandlord) {
                fileUploadBtn.classList.remove('hidden');
            } else {
                fileUploadBtn.classList.add('hidden');
            }
        }
        
        // Load messages and show chat modal
        await loadMessages(currentConversationId);
        document.getElementById('chatModal').classList.add('active');
        
        console.log('✅ Chat opened successfully');

    } catch (error) {
        console.error('❌ Error starting conversation:', error);
        alert('Failed to start conversation: ' + error.message);
    }
}

async function startConversation(listingId, listingTitle) {
    // Legacy function for compatibility
    const listing = allListings.find(l => l.id === listingId);
    if (listing) {
        await startConversationWithListing(listing);
    } else {
        console.error('Listing not found:', listingId);
    }
}