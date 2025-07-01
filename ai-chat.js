// AI Chat functionality for the negotiator
// This handles all the messaging, search, and negotiation logic

class AIChatHandler {
    constructor(supabase, config) {
        this.supabase = supabase;
        this.config = config;
        this.currentUser = null;
        this.conversationHistory = [];
        this.userNeeds = {
            maxPrice: null,
            minPrice: null,
            preferredLocation: null,
            houseType: null,
            bedrooms: null,
            utilities: null
        };
        this.matchingListings = [];
        this.negotiationState = 'idle';
        this.activeNegotiations = new Map();
        this.lastMessageTime = 0;
        this.negotiationEngine = null;
    }

    // Initialize the chat system
    async init(currentUser) {
        this.currentUser = currentUser;
        
        // Load previous conversation history
        await this.loadConversationHistory();
        
        // Setup user profile for messaging
        const setupSuccess = await this.setupAIUser();
        if (!setupSuccess) {
            this.appendMessage('AI', 'Warning: Messaging setup incomplete. Please register/login to send messages to landlords.', 'left');
        }
        
        // Only show welcome message if no previous conversation
        if (this.conversationHistory.length === 0) {
            this.appendMessage('AI', 'Hello! I\'m your AI Negotiator. Tell me what you\'re looking for (e.g., "I need a 2-bedroom apartment under $1500 in Toronto") and I\'ll find matching listings and negotiate with landlords for you automatically using market data!', 'left');
        }
    }

    // Set negotiation engine
    setNegotiationEngine(engine) {
        this.negotiationEngine = engine;
        console.log('🔗 Negotiation engine connected to AI chat');
        
        // Listen for negotiation completion updates
        this.listenForNegotiationUpdates();
    }

    // Listen for negotiation completion updates
    listenForNegotiationUpdates() {
        if (!this.supabase) {
            console.warn('⚠️ Supabase not available for real-time updates');
            return;
        }
        
        if (!this.currentUser?.email) {
            console.warn('⚠️ User email not available for subscription filter');
            return;
        }

        console.log('🔔 Setting up real-time subscription for user:', this.currentUser.email);
        
        try {
            const channel = this.supabase
                .channel(`negotiation_updates_${Date.now()}`)
                .on('postgres_changes', {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'ai_chats'
                    // Remove filter - listen to all updates and filter in code
                }, (payload) => {
                    console.log('📬 Received real-time update:', payload);
                    try {
                        const newChat = payload.new;
                        
                        // Filter for current user
                        if (newChat.user_email !== this.currentUser.email) {
                            console.log('📭 Update not for current user, skipping');
                            return;
                        }
                        
                        console.log('📨 Processing update for current user:', newChat.title);
                        
                        if (newChat.title && newChat.title.includes('Negotiation Success')) {
                            console.log('🎉 Negotiation success detected!');
                            this.displayNegotiationSuccess(newChat);
                        } else if (newChat.title && newChat.title.includes('Landlord Reply')) {
                            console.log('💬 Landlord reply detected!');
                            this.displayLandlordReply(newChat);
                        } else {
                            console.log('📢 Other AI notification:', newChat.title);
                            // Display any other AI notifications
                            this.displayLandlordReply(newChat);
                        }
                    } catch (error) {
                        console.error('Error processing real-time update:', error);
                    }
                })
                .subscribe((status, err) => {
                    console.log('📡 Subscription status:', status);
                    if (err) {
                        console.error('❌ Subscription error:', err);
                        this.setupFallbackPolling();
                    }
                    if (status === 'SUBSCRIBED') {
                        console.log('✅ Real-time connection established');
                        // Keep polling as backup even when real-time works
                        this.setupFallbackPolling(); // More reliable to have both
                    } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
                        console.warn('⚠️ Real-time connection issues, using fallback');
                        this.setupFallbackPolling();
                    } else if (status === 'CLOSED') {
                        console.warn('📡 Real-time connection closed, attempting to reconnect...');
                        this.setupFallbackPolling();
                        // Try to reconnect after a delay
                        setTimeout(() => {
                            console.log('🔄 Attempting to reconnect real-time subscription...');
                            this.listenForNegotiationUpdates();
                        }, 5000);
                    }
                });

            // Store channel reference for cleanup
            this.subscriptionChannel = channel;
            
            // Also set up subscription for regular messages (conversations)
            this.setupMessagesSubscription();
            
        } catch (error) {
            console.error('Error setting up real-time subscription:', error);
            this.setupFallbackPolling();
        }
    }

    // Setup subscription for regular conversation messages
    setupMessagesSubscription() {
        try {
            console.log('🔔 Setting up messages subscription...');
            
            const messagesChannel = this.supabase
                .channel(`messages_updates_${Date.now()}`)
                .on('postgres_changes', {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'messages'
                }, (payload) => {
                    console.log('📬 Received message update:', payload);
                    try {
                        const newMessage = payload.new;
                        
                        // Check if this message is relevant to current user's conversations
                        if (newMessage.sender_email !== this.currentUser.email) {
                            console.log('📨 New landlord reply detected in conversation:', newMessage.conversation_id);
                            this.appendMessage('AI', `💬 New reply received from landlord! Check the conversation for details.`, 'left');
                            this.highlightNewMessage();
                        }
                    } catch (error) {
                        console.error('Error processing message update:', error);
                    }
                })
                .subscribe((status, err) => {
                    console.log('📡 Messages subscription status:', status);
                    if (err) {
                        console.error('❌ Messages subscription error:', err);
                    }
                });

            this.messagesSubscriptionChannel = messagesChannel;
            
        } catch (error) {
            console.error('Error setting up messages subscription:', error);
        }
    }

    // Display negotiation success message
    displayNegotiationSuccess(chat) {
        try {
            console.log('📨 Processing negotiation success:', chat);
            const conversationData = JSON.parse(chat.conversation_data);
            if (conversationData && conversationData[0] && conversationData[0].content) {
                const content = conversationData[0].content;
                this.appendMessage('AI', content, 'left');
                
                // Add celebration effect
                this.celebrateSuccess();
            } else {
                console.warn('⚠️ Invalid conversation data structure');
                this.appendMessage('AI', '🎉 Negotiation completed successfully!', 'left');
            }
        } catch (error) {
            console.error('Error displaying negotiation success:', error);
            this.appendMessage('AI', '🎉 Negotiation completed successfully!', 'left');
        }
    }

    // Display landlord reply message
    displayLandlordReply(chat) {
        try {
            console.log('📨 Processing landlord reply:', chat);
            const conversationData = JSON.parse(chat.conversation_data);
            if (conversationData && conversationData[0] && conversationData[0].content) {
                const content = conversationData[0].content;
                this.appendMessage('AI', content, 'left');
                
                // Add subtle animation to highlight new message
                this.highlightNewMessage();
            } else {
                console.warn('⚠️ Invalid landlord reply data structure');
                this.appendMessage('AI', '💬 Received reply from landlord', 'left');
            }
        } catch (error) {
            console.error('Error displaying landlord reply:', error);
            this.appendMessage('AI', '💬 Received reply from landlord', 'left');
        }
    }

    // Highlight new message with subtle animation
    highlightNewMessage() {
        const messages = document.getElementById('chatMessages');
        if (messages) {
            const lastMessage = messages.lastElementChild;
            if (lastMessage) {
                lastMessage.style.backgroundColor = '#e3f2fd';
                lastMessage.style.transition = 'background-color 2s ease';
                setTimeout(() => {
                    lastMessage.style.backgroundColor = '';
                }, 2000);
            }
        }
    }

    // Add celebration effect
    celebrateSuccess() {
        const chatContainer = document.querySelector('.chat-container');
        if (chatContainer) {
            chatContainer.style.animation = 'pulse 0.5s ease-in-out 3';
            setTimeout(() => {
                chatContainer.style.animation = '';
            }, 1500);
        }
    }

    // Setup fallback polling when real-time fails
    setupFallbackPolling() {
        if (this.pollingInterval) return; // Already polling
        
        console.log('🔄 Setting up fallback polling for updates');
        this.lastPollTime = new Date(Date.now() - 10000); // Check last 10 seconds
        
        this.pollingInterval = setInterval(async () => {
            try {
                const { data: newChats, error } = await this.supabase
                    .from('ai_chats')
                    .select('*')
                    .eq('user_email', this.currentUser?.email)
                    .gte('created_at', this.lastPollTime.toISOString())
                    .order('created_at', { ascending: false });
                
                if (error) {
                    console.error('Polling error:', error);
                    return;
                }
                
                if (newChats && newChats.length > 0) {
                    console.log(`🔄 Found ${newChats.length} new updates via polling`);
                    for (const chat of newChats) {
                        console.log('📨 Processing polled update:', chat.title);
                        if (chat.title && chat.title.includes('Negotiation Success')) {
                            this.displayNegotiationSuccess(chat);
                        } else if (chat.title && chat.title.includes('Landlord Reply')) {
                            this.displayLandlordReply(chat);
                        } else {
                            // Display any other AI notifications
                            this.displayLandlordReply(chat);
                        }
                    }
                    this.lastPollTime = new Date();
                }
            } catch (error) {
                console.error('Error in fallback polling:', error);
            }
        }, 2000); // Poll every 2 seconds for faster updates
    }

    // Stop polling when real-time is working
    stopFallbackPolling() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
            this.pollingInterval = null;
            console.log('🛑 Stopped fallback polling');
        }
    }

    // Auto-negotiate on behalf of user when listings are found
    async autoNegotiateListings(listings) {
        if (!this.negotiationEngine || !listings?.length) return;
        
        // Prevent duplicate auto-negotiations
        if (this.negotiationState === 'auto_negotiating') {
            console.log('⚠️ Auto-negotiation already in progress, skipping duplicate call');
            return;
        }
        
        this.negotiationState = 'auto_negotiating';
        this.appendMessage('AI', `🤖 Found ${listings.length} matching properties! Starting automatic negotiations with landlords...`, 'left');
        
        let successCount = 0;
        for (const listing of listings.slice(0, 3)) { // Limit to first 3 to avoid spam
            try {
                const priceDisplay = listing.price && listing.price > 0 ? `$${listing.price}/month` : 'price available on request';
                this.appendMessage('AI', `📧 Contacting landlord for: ${listing.title} (${priceDisplay})`, 'left');
                
                const success = await this.negotiateWithLandlord(listing);
                if (success) {
                    successCount++;
                    this.appendMessage('AI', `✅ Message sent successfully!`, 'left');
                } else {
                    this.appendMessage('AI', `❌ Failed to contact landlord for this property.`, 'left');
                }
                
                // Wait a bit between messages to avoid spam
                await new Promise(resolve => setTimeout(resolve, 1500));
                
            } catch (error) {
                console.error('Error in auto-negotiation:', error);
                this.appendMessage('AI', `⚠️ Error contacting landlord for: ${listing.title}`, 'left');
            }
        }
        
        if (successCount > 0) {
            this.appendMessage('AI', `🎯 Successfully contacted ${successCount} landlord(s)! I'll continue negotiating automatically when they reply. You'll be notified of any agreements reached.`, 'left');
        }
        
        // Reset negotiation state
        this.negotiationState = 'idle';
    }

    // Helper function for auto-negotiation - maps to existing sendMessage function
    async negotiateWithLandlord(listing) {
        return await this.sendMessage(listing);
    }

    // Load conversation history from localStorage
    async loadConversationHistory() {
        try {
            const storageKey = `ai_negotiator_chat_${this.currentUser?.email || 'anonymous'}`;
            const savedHistory = localStorage.getItem(storageKey);
            
            if (savedHistory) {
                this.conversationHistory = JSON.parse(savedHistory);
                console.log(`📂 Loaded ${this.conversationHistory.length} messages from history`);
                
                // Restore messages to the chat interface
                const messages = document.getElementById('chatMessages');
                if (messages) {
                    messages.innerHTML = ''; // Clear default content
                    
                    for (const message of this.conversationHistory) {
                        const displayRole = message.role.charAt(0).toUpperCase() + message.role.slice(1);
                        this.displayMessage(displayRole, message.content, message.role === 'user' ? 'right' : 'left', false);
                    }
                }
            }
        } catch (error) {
            console.error('Error loading conversation history:', error);
            this.conversationHistory = [];
        }
    }

    // Save conversation history to localStorage
    saveConversationHistory() {
        try {
            const storageKey = `ai_negotiator_chat_${this.currentUser?.email || 'anonymous'}`;
            localStorage.setItem(storageKey, JSON.stringify(this.conversationHistory));
        } catch (error) {
            console.error('Error saving conversation history:', error);
        }
    }

    // Clear conversation history
    clearConversationHistory() {
        try {
            const storageKey = `ai_negotiator_chat_${this.currentUser?.email || 'anonymous'}`;
            localStorage.removeItem(storageKey);
            this.conversationHistory = [];
            
            const messages = document.getElementById('chatMessages');
            if (messages) {
                messages.innerHTML = '';
            }
        } catch (error) {
            console.error('Error clearing conversation history:', error);
        }
    }

    // Debug function to test negotiation success notification
    testNegotiationSuccess() {
        console.log('🧪 Testing negotiation success notification...');
        const testChat = {
            title: 'Negotiation Success: Test Property',
            conversation_data: JSON.stringify([{
                role: 'assistant',
                content: '✅ **Negotiation Successful!**\n\nProperty: Test Property\nFinal Price: $950/month\nOriginal Price: $1000/month\nSavings: $50/month\n\nThe landlord has accepted your offer! Next steps: Contact the landlord to finalize the rental agreement.'
            }])
        };
        this.displayNegotiationSuccess(testChat);
    }

    // Display message to chat (without saving to history - used for loading)
    displayMessage(sender, message, align, isTypingIndicator = false) {
        const messages = document.getElementById('chatMessages');
        if (!messages) {
            console.error('Error: #chatMessages element not found');
            return;
        }
        const messageElement = document.createElement('p');
        messageElement.className = `text-${align} text-${sender === 'User' ? 'blue-600' : 'gray-600'} mt-2 ${isTypingIndicator ? 'typing-indicator' : ''}`;
        messageElement.textContent = isTypingIndicator ? message : `${sender}: ${message}`;
        messageElement.id = isTypingIndicator ? 'typing-indicator' : '';
        messages.appendChild(messageElement);
        messages.scrollTop = messages.scrollHeight;
    }

    // Append message to chat and save to history
    appendMessage(sender, message, align, isTypingIndicator = false) {
        // Display the message
        this.displayMessage(sender, message, align, isTypingIndicator);
        
        // Save to history and localStorage (skip typing indicators)
        if (!isTypingIndicator) {
            this.conversationHistory.push({ role: sender.toLowerCase(), content: message });
            this.saveConversationHistory();
        }
    }

    // Remove typing indicator
    removeTypingIndicator() {
        const typingIndicator = document.getElementById('typing-indicator');
        if (typingIndicator) typingIndicator.remove();
    }

    // Extract rental information from message
    async extractRentalInfo(message) {
        console.log('🔍 Extracting rental info from:', message);
        
        try {
            // Try OpenAI first
            const openAIResult = await this.extractWithOpenAI(message);
            console.log('🎯 OpenAI extracted:', openAIResult);
            return openAIResult;
        } catch (error) {
            console.log('⚠️ OpenAI extraction failed:', error.message);
            console.log('🔄 Falling back to manual extraction...');
            
            try {
                const manualResult = this.extractManually(message);
                console.log('🎯 Manual extraction result:', manualResult);
                return manualResult;
            } catch (manualError) {
                console.error('❌ Both OpenAI and manual extraction failed:', manualError);
                throw new Error(`Extraction failed: ${error.message}`);
            }
        }
    }

    // Extract using OpenAI
    async extractWithOpenAI(message) {
        const prompt = `
        Extract rental property information from: "${message}"
        
        EXTRACTION TARGETS (matching database columns):
        - price: Maximum budget (number only)
        - city: City name (e.g., "karachi", "paris", "tehran", "toronto", "moscow", "islamabad", "lahore") 
        - house_type: Property type ("Apartment", "Condo", "House", "Studio", "Basement")
        - bedrooms: Number of bedrooms (1-5)
        - utilities: "included" or "not included"
        - intent: "search" or "general"
        
        RULES:
        - For price: look for "under $1200", "max $2000", etc.
        - For city: extract ANY city mentioned including international cities like "karachi", "islamabad", "lahore", "rawalpindi" and return lowercase
        - For house_type: use exact values from database
        - Be conservative - only extract what's clearly mentioned
        - ALWAYS prioritize extracting the city name if mentioned
        - For intent: return "search" if user is looking for/wanting/needing rental properties (keywords: "want", "need", "looking for", "find", "search"), otherwise "general"
        
        Return JSON with only fields that have values:
        `;
        
        // Validate API key before making request
        if (!this.config.OPENAI_API_KEY) {
            console.error('❌ OpenAI API key missing - check Railway environment variables');
            throw new Error('OpenAI API key not configured. Please set OPENAI_API_KEY environment variable.');
        }

        console.log('🔑 Making OpenAI API request with key:', this.config.OPENAI_API_KEY.substring(0, 10) + '...');
        
        const response = await fetch('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.config.OPENAI_API_KEY}`,
                'OpenAI-Organization': this.config.OPENAI_ORG_ID
            },
            body: JSON.stringify({
                model: this.config.OPENAI_MODEL || 'gpt-3.5-turbo',
                messages: [
                    {
                        role: 'system',
                        content: 'You are a rental property information extractor. Return only valid JSON with extracted information.'
                    },
                    {
                        role: 'user',
                        content: prompt
                    }
                ],
                max_tokens: 150,
                temperature: 0.1
            })
        });
        
        if (!response.ok) {
            const errorText = await response.text();
            console.error('❌ OpenAI API Error:', {
                status: response.status,
                statusText: response.statusText,
                error: errorText,
                apiKey: this.config.OPENAI_API_KEY ? 'Present' : 'Missing'
            });
            
            if (response.status === 401) {
                throw new Error(`OpenAI API authentication failed (401). Please check your OPENAI_API_KEY environment variable. Key present: ${!!this.config.OPENAI_API_KEY}`);
            }
            
            throw new Error(`OpenAI API error: ${response.status} - ${errorText}`);
        }
        
        const data = await response.json();
        const content = data.choices[0]?.message?.content;
        
        if (!content) {
            throw new Error('No content from OpenAI');
        }
        
        // Try to parse JSON from the response
        try {
            const result = JSON.parse(content.trim());
            
            // Clean city data if present
            if (result.city) {
                result.city = result.city.toString().trim().toLowerCase().split(',')[0].trim();
                result.city = result.city.replace(/\s+(fr|france|canada|ca|usa|us|australia|au)$/i, '');
            }
            
            return result;
        } catch (parseError) {
            console.log('⚠️ Failed to parse OpenAI response as JSON:', content);
            throw new Error('Invalid JSON response from OpenAI');
        }
    }

    // Manual extraction fallback
    extractManually(message) {
        console.log('Using manual extraction for:', message);
        const result = {};
        
        // Extract price - improved regex to catch more patterns
        const priceMatch = message.match(/(?:under|below|max|up to|for|at|around)?\s*\$?(\d{1,5})/i);
        if (priceMatch) {
            const extractedPrice = Number(priceMatch[1]);
            if (extractedPrice > 100) {
                result.price = extractedPrice;
                console.log('💰 Extracted price:', extractedPrice);
            }
        }
        
        // Extract city - UPDATED LIST based on actual database listings + international cities
        const cityMatch = message.match(/\b(karachi|paris|tehran|toronto|moscow|sydney|vancouver|montreal|calgary|ottawa|edmonton|winnipeg|hamilton|quebec|saskatoon|regina|halifax|london|kitchener|waterloo|windsor|markham|mississauga|brampton|islamabad|lahore|rawalpindi|faisalabad|multan|hyderabad|peshawar|quetta|iran|australia|canada|france|pakistan|new york|los angeles|chicago|miami|boston)\b/i);
        if (cityMatch) {
            result.city = cityMatch[1].toLowerCase().trim();
            console.log('🏙️ Extracted city:', result.city);
        }
        
        // Additional location patterns for "in [city]"
        const inCityMatch = message.match(/\bin\s+(karachi|paris|tehran|toronto|moscow|sydney|vancouver|montreal|calgary|islamabad|lahore|rawalpindi)\b/i);
        if (inCityMatch && !result.city) {
            result.city = inCityMatch[1].toLowerCase().trim();
            console.log('🏙️ Extracted city from "in" pattern:', result.city);
        }
        
        // Extract house type
        if (message.toLowerCase().includes('apartment')) {
            result.house_type = 'Apartment';
        } else if (message.toLowerCase().includes('condo')) {
            result.house_type = 'Condo';
        } else if (message.toLowerCase().includes('house')) {
            result.house_type = 'House';
        } else if (message.toLowerCase().includes('studio')) {
            result.house_type = 'Studio';
        } else if (message.toLowerCase().includes('basement')) {
            result.house_type = 'Basement';
        }
        
        // Extract bedrooms
        const bedroomMatch = message.match(/(\d+)[\s-]?bedroom/i);
        if (bedroomMatch) {
            result.bedrooms = Number(bedroomMatch[1]);
        }
        
        // Set intent
        if (message.toLowerCase().includes('looking for') || 
            message.toLowerCase().includes('need') || 
            message.toLowerCase().includes('want') ||
            message.toLowerCase().includes('find') ||
            message.toLowerCase().includes('search')) {
            result.intent = 'search';
        }
        
        // Backup logic: if we extracted rental criteria (price + city), assume search intent
        if ((result.price || result.city) && !result.intent) {
            console.log('🎯 BACKUP LOGIC: Found rental criteria without intent, setting to search');
            result.intent = 'search';
        }
        
        return result;
    }

    // Update user needs from extracted data
    updateUserNeeds(extractedData) {
        console.log('🎯 Updating user needs with:', extractedData);
        
        if (extractedData.price) {
            this.userNeeds.maxPrice = extractedData.price;
            console.log('✅ Set max price:', extractedData.price);
        }
        
        if (extractedData.city) {
            // Clean up the city name - remove country codes and extra info
            let cleanCity = extractedData.city.toString().trim().toLowerCase();
            cleanCity = cleanCity.split(',')[0].trim(); // Remove everything after comma
            cleanCity = cleanCity.replace(/\s+(fr|france|canada|ca|usa|us|australia|au)$/i, ''); // Remove country codes
            this.userNeeds.preferredLocation = cleanCity;
            console.log('✅ Set location:', cleanCity, '(cleaned and lowercased from:', extractedData.city, ')');
        }
        
        if (extractedData.house_type) {
            this.userNeeds.houseType = extractedData.house_type;
            console.log('✅ Set house type:', extractedData.house_type);
        }
        
        if (extractedData.bedrooms) {
            this.userNeeds.bedrooms = extractedData.bedrooms;
            console.log('✅ Set bedrooms:', extractedData.bedrooms);
        }
        
        if (extractedData.utilities) {
            this.userNeeds.utilities = extractedData.utilities;
            console.log('✅ Set utilities:', extractedData.utilities);
        }
        
        console.log('🔧 Final user needs:', this.userNeeds);
    }

    // Search for matching listings
    async findMatchingListings() {
        console.log('🔍 Starting search with criteria:', this.userNeeds);
        
        console.log('🔍 Building search query step by step...');
        
        // Start with base query
        let query = this.supabase
            .from('listings')
            .select('id, street, city, user_email');
        
        let appliedFilters = [];
        let hasSpecificCriteria = false;
        
        // Step 1: Exclude user's own listings
        if (this.currentUser?.email) {
            query = query.neq('user_email', this.currentUser.email);
            console.log('✅ Step 1: Excluded own listings');
        }
        
        // Note: Price and house_type filters disabled - columns don't exist in current schema
        console.log('⚠️ Price and house_type filters skipped - not available in current database schema');
        
        // Step 4: Apply location filter (STRICT) with enhanced international city support
        if (this.userNeeds.preferredLocation) {
            const location = this.userNeeds.preferredLocation.trim();
            // Search for exact city match (now separated from country) and in street field
            query = query.or(`city.ilike.*${location}*,street.ilike.*${location}*`);
            appliedFilters.push(`location contains: ${location}`);
            hasSpecificCriteria = true;
            console.log(`✅ Step 4: STRICT location filter applied - searching for "${location}" in city/title/description/street/address`);
            console.log(`🔍 EXACT SEARCH PATTERN: city.ilike.*${location}*,street.ilike.*${location}*`);
        }
        
        // Step 5: Apply bedroom filter
        if (this.userNeeds.bedrooms) {
            query = query.eq('bedrooms', this.userNeeds.bedrooms);
            appliedFilters.push(`bedrooms: ${this.userNeeds.bedrooms}`);
            hasSpecificCriteria = true;
            console.log(`✅ Step 5: Bedroom filter applied - ${this.userNeeds.bedrooms} bedrooms`);
        }
        
        if (!hasSpecificCriteria) {
            throw new Error('Please provide specific criteria (location, house type, price, etc.)');
        }
        
        console.log('🔍 Applied filters:', appliedFilters.join(', '));
        console.log('🔎 User needs for debugging:', this.userNeeds);
        
        // Try a simpler approach that matches our working test query
        console.log('🚀 Executing final query...');
        
        let finalQuery = this.supabase
            .from('listings')
            .select('id, title, price, house_type, bedrooms, utilities, description, user_email, city, street');
            
        // Apply filters one by one like the working test
        if (this.currentUser?.email) {
            finalQuery = finalQuery.neq('user_email', this.currentUser.email);
        }
        
        if (this.userNeeds.maxPrice) {
            finalQuery = finalQuery.lte('price', this.userNeeds.maxPrice);
        }
        
        if (this.userNeeds.houseType === 'House') {
            finalQuery = finalQuery.in('house_type', ['House', 'Townhouse']);
        } else if (this.userNeeds.houseType) {
            finalQuery = finalQuery.eq('house_type', this.userNeeds.houseType);
        }
        
        if (this.userNeeds.preferredLocation) {
            const location = this.userNeeds.preferredLocation.trim();
            console.log(`🎯 FINAL QUERY - Applying location filter for: "${location}"`);
            finalQuery = finalQuery.or(`city.ilike.*${location}*,street.ilike.*${location}*`);
        }
        
        if (this.userNeeds.bedrooms) {
            finalQuery = finalQuery.eq('bedrooms', this.userNeeds.bedrooms);
        }
        
        const { data: listings, error } = await finalQuery.order('created_at', { ascending: false }).limit(20);
        
        if (error) {
            throw new Error(`Database query failed: ${error.message}`);
        }
        
        console.log('📊 Query results:', listings?.length || 0, 'listings found');
        console.log('🔍 User requested location:', this.userNeeds.preferredLocation);
        
        // Debug: Log what we actually found and validate matches
        if (listings && listings.length > 0) {
            console.log('🏠 Found listings details:');
            listings.forEach((listing, i) => {
                const matches = {
                    price: !this.userNeeds.maxPrice || listing.price <= this.userNeeds.maxPrice,
                    location: !this.userNeeds.preferredLocation || this.matchesLocation(listing, this.userNeeds.preferredLocation),
                    type: !this.userNeeds.houseType || listing.house_type === this.userNeeds.houseType || (this.userNeeds.houseType === 'House' && listing.house_type === 'Townhouse')
                };
                const matchScore = Object.values(matches).filter(Boolean).length;
                console.log(`  ${i+1}. "${listing.title}" - $${listing.price} - ${listing.house_type} - City: "${listing.city || 'NO CITY'}" - Street: "${listing.street || 'NO STREET'}" - MATCHES: ${matchScore}/3 (Price:${matches.price}, Location:${matches.location}, Type:${matches.type})`);
                
                // Enhanced debugging for location matching
                if (this.userNeeds.preferredLocation) {
                    const locationMatch = this.matchesLocation(listing, this.userNeeds.preferredLocation);
                    console.log(`    🌍 Location debug - Searching for "${this.userNeeds.preferredLocation}" in: city="${listing.city}", title="${listing.title}", street="${listing.street}" - Match: ${locationMatch}`);
                }
            });
        } else {
            console.log('❌ No listings found with current filters');
            
            // Let's check what's actually in the database with detailed info
            const { data: allListings } = await this.supabase
                .from('listings')
                .select('id, street, city, user_email')
                .limit(20);
            
            console.log('🗃️ ALL listings in database:');
            allListings?.forEach((listing, i) => {
                console.log(`  ${i+1}. ID: ${listing.id} - City: "${listing.city || 'NO CITY'}" - Street: "${listing.street || 'NO STREET'}" - User: "${listing.user_email || 'NO USER'}"`);
            });
            
            // Check for requested location specifically if user searched for any city
            if (this.userNeeds.preferredLocation) {
                const searchLocation = this.userNeeds.preferredLocation.toLowerCase();
                console.log(`🌍 SPECIFIC CHECK: Looking for "${searchLocation}"-related listings...`);
                const locationListings = allListings?.filter(listing => 
                    (listing.city && listing.city.toLowerCase().includes(searchLocation)) ||
                    (listing.street && listing.street.toLowerCase().includes(searchLocation))
                );
                
                if (locationListings && locationListings.length > 0) {
                    console.log(`✅ Found ${searchLocation} listings:`);
                    locationListings.forEach(listing => {
                        console.log(`  - ID: ${listing.id} in "${listing.city}" at "${listing.street}"`);
                    });
                } else {
                    console.log(`❌ NO ${searchLocation.toUpperCase()} LISTINGS FOUND in database - this explains the issue!`);
                }
            }
            
            // Test: Search for all houses under $1500 (no location filter)
            console.log('\n🔍 Testing: All houses under $1500 (no location filter)');
            const { data: houseTest } = await this.supabase
                .from('listings')
                .select('title, city, price, house_type, street')
                .in('house_type', ['House', 'Townhouse'])
                .lte('price', 1500)
                .limit(10);
            
            console.log(`Found ${houseTest?.length || 0} houses under $1500:`);
            houseTest?.forEach(listing => {
                console.log(`  - "${listing.title}" in "${listing.city}" - $${listing.price} (${listing.house_type}) - Street: "${listing.street}"`);
            });
            
            // Test the exact query that should find Calgary house
            console.log('\n🔍 Testing exact Calgary query that should work:');
            const { data: calgaryExactTest, error: calgaryError } = await this.supabase
                .from('listings')
                .select('title, city, price, house_type, street')
                .lte('price', 1500)
                .in('house_type', ['House', 'Townhouse'])
                .or(`city.ilike.%calgary%,title.ilike.%calgary%,description.ilike.%calgary%,street.ilike.%calgary%`)
                .limit(10);
            
            if (calgaryError) {
                console.log(`❌ Calgary test query error: ${calgaryError.message}`);
            } else {
                console.log(`✅ Calgary test found ${calgaryExactTest?.length || 0} results:`);
                calgaryExactTest?.forEach(listing => {
                    console.log(`  - "${listing.title}" in "${listing.city}" - $${listing.price} (${listing.house_type})`);
                });
            }
            
            // Specifically look for Calgary-related listings
            console.log('🔍 Looking specifically for Calgary-related listings...');
            const calgaryListings = allListings?.filter(listing => 
                listing.city?.toLowerCase().includes('calgary') ||
                listing.street?.toLowerCase().includes('calgary')
            );
            
            if (calgaryListings && calgaryListings.length > 0) {
                console.log('🏠 Found Calgary-related listings:');
                calgaryListings.forEach(listing => {
                    console.log(`  - ID: ${listing.id} in "${listing.city}" at "${listing.street}"`);
                });
            } else {
                console.log('❌ No Calgary listings found in database');
            }
        }
        
        return listings || [];
    }

    // Helper function to check if listing matches location
    matchesLocation(listing, searchLocation) {
        const location = searchLocation.toLowerCase();
        const city = (listing.city || '').toLowerCase();
        const title = (listing.title || '').toLowerCase();
        const description = (listing.description || '').toLowerCase();
        const street = (listing.street || '').toLowerCase();
        
        // Simple city matching (city and country are now separate fields)
        return city.includes(location) || 
               title.includes(location) || 
               description.includes(location) || 
               street.includes(location);
    }

    // Test function to verify search works for known listings
    async testSearchForKnownListings() {
        console.log('🧪 TESTING SEARCH FOR KNOWN LISTINGS');
        
        const testCases = [
            { message: "I want a house in Calgary under $1500", expectedCity: "calgary", expectedPrice: 1500, expectedType: "House" },
            { message: "I want a house in Paris under $1300", expectedCity: "paris", expectedPrice: 1300, expectedType: "House" },
            { message: "I need a condo in Moscow under $1000", expectedCity: "moscow", expectedPrice: 1000, expectedType: "Condo" },
            { message: "Looking for a house in Tehran under $1200", expectedCity: "tehran", expectedPrice: 1200, expectedType: "House" },
            { message: "I want a house in Toronto under $1000", expectedCity: "toronto", expectedPrice: 1000, expectedType: "House" }
        ];
        
        for (const test of testCases) {
            console.log(`\n--- Testing: "${test.message}" ---`);
            
            // Extract criteria
            const extracted = await this.extractRentalInfo(test.message);
            console.log('Extracted:', extracted);
            
            // Update user needs
            this.updateUserNeeds(extracted);
            console.log('User needs:', this.userNeeds);
            
            // Search
            const results = await this.findMatchingListings();
            console.log(`Found ${results.length} results`);
            
            // Reset for next test
            this.userNeeds = { maxPrice: null, minPrice: null, preferredLocation: null, houseType: null, bedrooms: null, utilities: null };
        }
    }
    
    // Debug function to manually check Calgary
    async debugCalgarySearch() {
        console.log('🔍 DEBUGGING CALGARY SEARCH SPECIFICALLY');
        
        // First, let's see all listings
        const { data: allListings } = await this.supabase
            .from('listings')
            .select('*')
            .limit(20);
        
        console.log('📊 All listings in database:');
        allListings?.forEach((listing, i) => {
            console.log(`${i+1}. "${listing.title}" - City: "${listing.city}" - $${listing.price} - ${listing.house_type} - Street: "${listing.street}"`);
        });
        
        // Now test different Calgary searches
        const calgaryTests = [
            `city.ilike.%calgary%`,
            `title.ilike.%calgary%`, 
            `street.ilike.%calgary%`,
            `description.ilike.%calgary%`,
            `house_type = 'Townhouse'`,
            `price <= 1500`
        ];
        
        for (const testQuery of calgaryTests) {
            console.log(`\n🔍 Testing query: ${testQuery}`);
            try {
                const { data: results } = await this.supabase
                    .from('listings')
                    .select('title, city, price, house_type, street')
                    .or(testQuery)
                    .limit(10);
                
                console.log(`Found ${results?.length || 0} results`);
                results?.forEach(listing => {
                    console.log(`  - "${listing.title}" in "${listing.city}" - $${listing.price} (${listing.house_type})`);
                });
            } catch (error) {
                console.log(`Error: ${error.message}`);
            }
        }
    }

    // Main search and messaging function
    async searchAndMessage() {
        try {
            this.negotiationState = 'searching';
            this.appendMessage('AI', 'Searching for matching listings...', 'left', true);
            
            this.matchingListings = await this.findMatchingListings();
            this.removeTypingIndicator();
            
            if (this.matchingListings.length === 0) {
                await this.handleNoMatches();
                return;
            }
            
            // Show found listings
            this.appendMessage('AI', `Found ${this.matchingListings.length} matching listing(s)!`, 'left');
            
            for (const listing of this.matchingListings.slice(0, 3)) {
                const bedText = listing.bedrooms ? `${listing.bedrooms} bed` : 'unknown bed';
                const typeText = listing.house_type || 'property';
                const utilitiesText = listing.utilities ? ` (utilities ${listing.utilities})` : '';
                const priceText = listing.price && listing.price > 0 ? `$${listing.price}/month` : 'price available on request';
                this.appendMessage('AI', `🏠 "${listing.title}" - ${priceText} (${bedText} ${typeText})${utilitiesText}`, 'left');
            }
            
            // Automatically start negotiations if negotiation engine is available
            if (this.negotiationEngine && this.matchingListings.length > 0) {
                await this.autoNegotiateListings(this.matchingListings);
                return; // Exit early since auto-negotiation handles messaging
            }
            
            // Filter valid listings and message owners
            const validListings = this.matchingListings.filter(listing => {
                if (!listing.user_email || !listing.id) {
                    console.log(`⚠️ Skipping listing "${listing.title}" - missing email or ID`);
                    return false;
                }
                if (listing.user_email === this.currentUser?.email) {
                    console.log(`⚠️ Skipping listing "${listing.title}" - user's own listing`);
                    return false;
                }
                return true;
            });
            
            console.log(`📧 Found ${validListings.length} valid listings for messaging out of ${this.matchingListings.length} total`);
            
            if (validListings.length === 0) {
                this.appendMessage('AI', 'Found listings, but none have valid owner emails for messaging (or they are your own listings).', 'left');
                this.negotiationState = 'idle';
                return;
            }
            
            const negotiationStatus = this.negotiationEngine ? 
                '📤 Contacting landlords with AI negotiation engine (market data + smart pricing)...' :
                '📤 Contacting landlords with basic messages...';
            this.appendMessage('AI', negotiationStatus, 'left');
            
            let successCount = 0;
            for (const listing of validListings) {
                const success = await this.sendMessage(listing);
                if (success) {
                    successCount++;
                    const negotiationType = this.negotiationEngine ? '🤖 AI Negotiation' : '📧 Basic Message';
                    this.appendMessage('AI', `✓ ${negotiationType} sent to owner of "${listing.title}"`, 'left');
                }
            }
            
            if (successCount > 0) {
                const enhancedMsg = this.negotiationEngine ? 
                    `✅ Sent ${successCount} intelligent negotiation message(s) with market data analysis! The AI will automatically handle replies and negotiate the best price for you. Check your profile page for updates.` :
                    `✅ Sent ${successCount} message(s)! Check your profile page.`;
                this.appendMessage('AI', enhancedMsg, 'left');
            }
            
            this.negotiationState = 'idle';
            
        } catch (error) {
            console.error('Search error:', error);
            this.removeTypingIndicator();
            this.appendMessage('AI', `Error: ${error.message}`, 'left');
            this.negotiationState = 'idle';
        }
    }

    // Handle no matches found
    async handleNoMatches() {
        // First, let's check if we extracted the criteria correctly
        const extracted = [];
        if (this.userNeeds.preferredLocation) extracted.push(`Location: "${this.userNeeds.preferredLocation}"`);
        if (this.userNeeds.maxPrice) extracted.push(`Max Price: $${this.userNeeds.maxPrice}`);
        if (this.userNeeds.houseType) extracted.push(`Type: ${this.userNeeds.houseType}`);
        
        this.appendMessage('AI', `❌ No exact matches found. I searched for: ${extracted.join(', ')}`, 'left');
        
        // Try to find similar listings with relaxed criteria
        let query = this.supabase
            .from('listings')
            .select('id, title, price, house_type, bedrooms, description, city')
            .neq('user_email', this.currentUser?.email || '')
            .limit(10);

        // First try: relax location requirement but keep other criteria
        let hasValidFilters = false;
        if (this.userNeeds.houseType || this.userNeeds.maxPrice) {
            if (this.userNeeds.maxPrice) {
                // Increase price range by 20%
                const relaxedPrice = Math.floor(this.userNeeds.maxPrice * 1.2);
                query = query.lte('price', relaxedPrice);
                hasValidFilters = true;
            }
            if (this.userNeeds.houseType) {
                if (this.userNeeds.houseType === 'House') {
                    // When user wants "House", also include "Townhouse" as they're similar
                    query = query.in('house_type', ['House', 'Townhouse']);
                } else {
                    query = query.eq('house_type', this.userNeeds.houseType);
                }
                hasValidFilters = true;
            }
        }
        
        // If we have a location preference, still try to prioritize it but don't make it required
        if (this.userNeeds.preferredLocation && hasValidFilters) {
            console.log(`🔍 Looking for similar listings, preferring location: ${this.userNeeds.preferredLocation}`);
        }
        
        const { data: similarListings } = await query.order('price', { ascending: true });
        
        if (similarListings?.length > 0) {
            const criteria = [];
            if (this.userNeeds.houseType) criteria.push(this.userNeeds.houseType.toLowerCase());
            if (this.userNeeds.preferredLocation) criteria.push(`in ${this.userNeeds.preferredLocation}`);
            if (this.userNeeds.maxPrice) criteria.push(`under $${this.userNeeds.maxPrice}`);
            
            this.appendMessage('AI', `I searched for: ${criteria.join(' + ')}. Here are similar listings:`, 'left');
            
            let shownCount = 0;
            for (const listing of similarListings.slice(0, 5)) {
                // Skip obvious test/fake listings
                if (listing.title.toLowerCase().includes('test') || 
                    listing.title.toLowerCase().includes('hello') ||
                    listing.title.toLowerCase().includes('eric')) {
                    continue;
                }
                
                const descText = listing.description ? listing.description.substring(0, 30) + '...' : 'No description';
                const locationText = listing.city ? ` in ${listing.city}` : '';
                const priceDisplay = listing.price && listing.price > 0 ? `$${listing.price}/month` : 'price available on request';
                this.appendMessage('AI', `📋 "${listing.title}" - ${priceDisplay} (${listing.bedrooms} bed ${listing.house_type})${locationText} - ${descText}`, 'left');
                shownCount++;
                
                if (shownCount >= 3) break;
            }
            
            if (shownCount === 0) {
                this.appendMessage('AI', 'No suitable listings found in the database. Try creating a listing or contact an administrator to add listings in your preferred location.', 'left');
            } else {
                const suggestions = [];
                if (this.userNeeds.maxPrice) suggestions.push(`increase your budget above $${this.userNeeds.maxPrice}`);
                if (this.userNeeds.preferredLocation) suggestions.push(`try nearby areas or add "${this.userNeeds.preferredLocation}" to listing titles`);
                
                if (suggestions.length > 0) {
                    this.appendMessage('AI', `💡 Suggestions: ${suggestions.join(' or ')}.`, 'left');
                }
            }
        } else {
            this.appendMessage('AI', 'No listings found in database. The database may be empty or all listings are from your account.', 'left');
        }
        
        this.negotiationState = 'idle';
    }

    // Send negotiation message to listing owner
    async sendMessage(listing) {
        try {
            console.log('🚀 Starting negotiation for:', listing.title);
            
            // Prevent duplicate messages to the same listing
            const negotiationKey = `${listing.id}_${this.currentUser?.email}`;
            if (this.activeNegotiations.has(negotiationKey)) {
                console.log('⚠️ Negotiation already active for this listing, skipping duplicate');
                return false;
            }
            
            // Mark this negotiation as active
            this.activeNegotiations.set(negotiationKey, {
                listingId: listing.id,
                listingTitle: listing.title,
                startTime: Date.now()
            });

            if (!this.negotiationEngine) {
                console.warn('⚠️ No negotiation engine available, using basic message');
                return await this.sendBasicMessage(listing);
            }

            // Create or get conversation first
            const conversation = await this.getOrCreateConversation(listing);
            if (!conversation) {
                console.error('Failed to create conversation');
                return false;
            }

            // Use the advanced negotiation engine with conversation ID
            const negotiationResult = await this.negotiationEngine.startNegotiation(
                listing, 
                this.userNeeds.maxPrice, 
                this.currentUser.email,
                conversation.id
            );

            // Send the negotiation message
            const success = await this.negotiationEngine.sendNegotiationMessage(
                conversation.id, 
                negotiationResult.message, 
                this.currentUser.email
            );

            if (success) {
                console.log('✅ Advanced negotiation message sent');
                console.log('📊 Market data used:', negotiationResult.marketData);
            }

            return success;

        } catch (error) {
            console.error('Negotiation send error:', error);
            // Clean up failed negotiation tracking
            const negotiationKey = `${listing.id}_${this.currentUser?.email}`;
            this.activeNegotiations.delete(negotiationKey);
            return await this.sendBasicMessage(listing);
        } finally {
            // Clean up after 30 seconds to allow for retry if needed
            setTimeout(() => {
                const negotiationKey = `${listing.id}_${this.currentUser?.email}`;
                this.activeNegotiations.delete(negotiationKey);
            }, 30000);
        }
    }

    // Fallback basic message
    async sendBasicMessage(listing) {
        try {
            console.log('📧 Sending basic message for listing:', listing.title);
            
            const conversation = await this.getOrCreateConversation(listing);
            if (!conversation) {
                console.error('❌ Failed to get/create conversation');
                return false;
            }

            const basicMessage = `Hi! I'm interested in your ${listing.house_type || 'property'} "${listing.title}". ${this.userNeeds.maxPrice ? `My budget is around $${this.userNeeds.maxPrice}.` : ''} I'm a qualified tenant ready to move quickly. Are you open to discussing the terms?`;

            console.log('💬 Message content:', basicMessage);
            console.log('📧 Sending to conversation:', conversation.id);

            const { data, error } = await this.supabase
                .from('messages')
                .insert({
                    conversation_id: conversation.id,
                    sender_email: this.currentUser.email,
                    content: basicMessage,
                    created_at: new Date().toISOString()
                })
                .select();

            if (error) {
                console.error('❌ Error inserting message:', error);
                return false;
            }

            console.log('✅ Message sent successfully:', data[0]?.id);
            return true;
        } catch (error) {
            console.error('❌ Basic message send error:', error);
            return false;
        }
    }

    // Get or create conversation
    async getOrCreateConversation(listing) {
        try {
            console.log('🔍 Looking for existing conversation for listing:', listing.id, 'user:', this.currentUser.email, 'owner:', listing.user_email);
            
            // Check if conversation already exists
            const { data: existingConv, error: searchError } = await this.supabase
                .from('conversations')
                .select('*')
                .eq('listing_id', listing.id)
                .eq('sender_email', this.currentUser.email)
                .eq('receiver_email', listing.user_email)
                .single();

            if (searchError && searchError.code !== 'PGRST116') {
                console.error('Error searching for conversation:', searchError);
            }

            if (existingConv) {
                console.log('✅ Found existing conversation:', existingConv.id);
                return existingConv;
            }

            console.log('📝 Creating new conversation...');
            
            // Create new conversation with correct schema and AI negotiation metadata
            const { data: newConv, error } = await this.supabase
                .from('conversations')
                .insert({
                    listing_id: listing.id,
                    sender_email: this.currentUser.email,
                    receiver_email: listing.user_email,
                    created_at: new Date().toISOString(),
                    metadata: JSON.stringify({
                        ai_negotiation: true,
                        ai_initiated: true,
                        user_budget: this.userNeeds.maxPrice,
                        negotiation_started: new Date().toISOString()
                    })
                })
                .select()
                .single();

            if (error) {
                console.error('❌ Error creating conversation:', error);
                return null;
            }

            console.log('✅ Created new conversation:', newConv.id);
            return newConv;
        } catch (error) {
            console.error('❌ Error in getOrCreateConversation:', error);
            return null;
        }
    }

    // Setup AI user account - ensure current user exists in profiles
    async setupAIUser() {
        if (!this.currentUser?.email) {
            console.error('❌ No current user found for AI setup');
            return false;
        }

        try {
            // Check if user exists in profiles table
            const { data: existingProfile, error: profileError } = await this.supabase
                .from('profiles')
                .select('email')
                .eq('email', this.currentUser.email)
                .single();

            if (profileError && profileError.code !== 'PGRST116') {
                console.error('❌ Error checking user profile:', profileError);
                return false;
            }

            if (!existingProfile) {
                console.log('📝 Creating user profile for messaging...');
                
                // Create profile for current user
                const { error: createError } = await this.supabase
                    .from('profiles')
                    .insert({
                        email: this.currentUser.email,
                        first_name: this.currentUser.firstName || 'User',
                        last_name: this.currentUser.lastName || '',
                        created_at: new Date().toISOString()
                    });

                if (createError) {
                    console.error('❌ Error creating user profile:', createError);
                    return false;
                }

                console.log('✅ User profile created successfully');
            } else {
                console.log('✅ User profile already exists');
            }

            return true;
        } catch (error) {
            console.error('❌ Error in setupAIUser:', error);
            return false;
        }
    }

    // Process user message
    async processMessage(message) {
        console.log('🔍 Processing message:', message);
        
        // Debounce
        const now = Date.now();
        if (now - this.lastMessageTime < 3000) {
            this.appendMessage('AI', 'Please wait 3 seconds between messages.', 'left');
            return;
        }
        this.lastMessageTime = now;
        
        this.appendMessage('User', message, 'right');
        this.appendMessage('AI', 'Analyzing your request...', 'left', true);
        
        try {
            // Extract requirements
            const extractedData = await this.extractRentalInfo(message);
            console.log('📊 Raw extracted data:', extractedData);
            this.updateUserNeeds(extractedData);
            console.log('🎯 Final user needs after update:', this.userNeeds);
            console.log('🔍 Location that will be used in search:', this.userNeeds.preferredLocation);
            
            this.removeTypingIndicator();
            
            // Continue with normal processing...
            await this.processExtractedData(message, extractedData);
            
        } catch (error) {
            console.error('❌ Error in message processing:', error);
            this.removeTypingIndicator();
            this.appendMessage('AI', 'I had trouble understanding your request. Could you try rephrasing it? For example: "I need a 2-bedroom apartment under $1500 in Toronto"', 'left');
        }
    }

    // Process extracted data (split from processMessage for better error handling)
    async processExtractedData(message, extractedData) {
        // Check if user is expressing needs
        const needsKeywords = ['looking for', 'need', 'want', 'searching for', 'find me', 'find', 'search'];
        const isSearchRequest = needsKeywords.some(keyword => message.toLowerCase().includes(keyword));
        
        // Improved logic: trigger search if either condition is true OR if we have rental criteria
        const shouldSearch = (isSearchRequest && extractedData.intent === 'search') || 
                           extractedData.intent === 'search' ||
                           (extractedData.price || extractedData.city);
        
        console.log('🔍 SEARCH DECISION:', {
            isSearchRequest,
            extractedIntent: extractedData.intent,
            hasPrice: !!extractedData.price,
            hasCity: !!extractedData.city,
            shouldSearch
        });
        
        if (shouldSearch) {
            this.appendMessage('AI', 'I understand! Searching for matching listings and contacting landlords...', 'left');
            setTimeout(() => this.searchAndMessage(), 1000);
        } else {
            this.appendMessage('AI', 'I understand your preferences. To search for listings, try saying something like "I need a 2-bedroom apartment under $1500 in Toronto"', 'left');
        }
    }

    // Cleanup method for subscriptions
    cleanup() {
        console.log('🧹 Cleaning up AI chat subscriptions...');
        
        if (this.subscriptionChannel) {
            this.subscriptionChannel.unsubscribe();
            this.subscriptionChannel = null;
            console.log('✅ Unsubscribed from AI chats channel');
        }
        
        if (this.messagesSubscriptionChannel) {
            this.messagesSubscriptionChannel.unsubscribe();
            this.messagesSubscriptionChannel = null;
            console.log('✅ Unsubscribed from messages channel');
        }
        
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
            this.pollingInterval = null;
            console.log('✅ Stopped fallback polling');
        }
    }
}

// Export for use in HTML
window.AIChatHandler = AIChatHandler;