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
        
        // Track active conversation contexts
        this.activeConversations = new Map(); // conversation_id -> {listing, landlord, lastMessage, status}
        this.pendingUserResponse = null; // Track what the user is responding to
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
            if (!this.supabase) {
                console.error('❌ Supabase client not initialized for real-time updates');
                return;
            }
            
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
            
        } catch (error) {
            console.error('Error setting up real-time subscription:', error);
            this.setupFallbackPolling();
        }
    }

    // Cleanup method for proper resource management
    cleanup() {
        if (this.subscriptionChannel) {
            console.log('🧹 Cleaning up real-time subscription channel');
            this.subscriptionChannel.unsubscribe();
            this.subscriptionChannel = null;
        }
        
        if (this.pollingInterval) {
            console.log('🧹 Cleaning up polling interval');
            clearInterval(this.pollingInterval);
            this.pollingInterval = null;
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
                
                // Set up context for user response
                this.pendingUserResponse = {
                    id: chat.id || 'landlord_reply',
                    listing: {
                        id: chat.listing_id || 'unknown',
                        title: chat.listing_title || 'Property',
                        price: chat.listing_price || null,
                        landlord_email: chat.landlord_email || 'unknown'
                    },
                    lastMessage: content,
                    phase: 'awaiting_user_response',
                    timestamp: new Date().toISOString()
                };
                
                console.log('📝 Set pending user response context:', this.pendingUserResponse);
                
                // Add subtle animation to highlight new message
                this.highlightNewMessage();
            } else {
                console.warn('⚠️ Invalid landlord reply data structure');
                this.appendMessage('AI', '💬 Received reply from landlord', 'left');
                
                // Still set up basic context
                this.pendingUserResponse = {
                    id: 'generic_reply',
                    listing: { id: 'unknown', title: 'Property', price: null },
                    lastMessage: 'Landlord replied',
                    phase: 'awaiting_user_response'
                };
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
                this.appendMessage('AI', `📧 Contacting landlord for: ${listing.title} ($${listing.price}/month)`, 'left');
                
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
            console.log('❌ NO MANUAL FALLBACK - OpenAI extraction required');
            throw new Error(`OpenAI extraction failed: ${error.message}`);
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
        
        console.log('🔍 Building search query for your Supabase database schema...');
        
        // Query all columns from your actual schema: id, street, location, user_email, updated_at, country
        let query = this.supabase
            .from('listings')
            .select('*'); // Select all columns to get complete listing data
        
        let appliedFilters = [];
        let hasSpecificCriteria = false;
        
        // Step 1: Exclude user's own listings
        if (this.currentUser?.email) {
            query = query.neq('user_email', this.currentUser.email);
            console.log('✅ Step 1: Excluded own listings');
        }
        
        // Step 2: Apply location filter using 'location' and 'street' columns
        if (this.userNeeds.preferredLocation) {
            const location = this.userNeeds.preferredLocation.trim().toLowerCase();
            // Search in location, street, and country columns
            query = query.or(`location.ilike.*${location}*,street.ilike.*${location}*,country.ilike.*${location}*`);
            appliedFilters.push(`location contains: ${location}`);
            hasSpecificCriteria = true;
            console.log(`✅ Step 2: Location filter applied - searching for "${location}" in location/street/country columns`);
            console.log(`🔍 SEARCH PATTERN: location.ilike.*${location}*,street.ilike.*${location}*,country.ilike.*${location}*`);
        }
        
        // Step 3: Apply price filter if max price is provided
        if (this.userNeeds.maxPrice) {
            // Assuming there might be a price column, but we'll handle it gracefully
            try {
                query = query.lte('price', this.userNeeds.maxPrice);
                appliedFilters.push(`max price: $${this.userNeeds.maxPrice}`);
                hasSpecificCriteria = true;
                console.log(`✅ Step 3: Price filter applied - max $${this.userNeeds.maxPrice}`);
            } catch (error) {
                console.log('⚠️ Price column not available in database schema, skipping price filter');
            }
        }
        
        if (!hasSpecificCriteria) {
            throw new Error('Please provide specific criteria (location, price, etc.)');
        }
        
        console.log('🔍 Applied filters:', appliedFilters.join(', '));
        console.log('🔎 User needs for debugging:', this.userNeeds);
        
        // Execute the query with your actual database schema
        console.log('🚀 Executing query with your database schema...');
        
        const { data: listings, error } = await query.order('updated_at', { ascending: false }).limit(20);
        
        if (error) {
            throw new Error(`Database query failed: ${error.message}`);
        }
        
        console.log('📊 Query results:', listings?.length || 0, 'listings found');
        console.log('🔍 User requested location:', this.userNeeds.preferredLocation);
        
        // Process results with your actual database schema
        if (listings && listings.length > 0) {
            console.log('🏠 Found listings from your database:');
            listings.forEach((listing, i) => {
                // Display listing info based on your actual schema: id, street, location, user_email, updated_at, country
                console.log(`  ${i+1}. ID: ${listing.id}`);
                console.log(`      Street: ${listing.street || 'Not specified'}`);
                console.log(`      Location: ${listing.location || 'Not specified'}`);
                console.log(`      Country: ${listing.country || 'Not specified'}`);
                console.log(`      Owner: ${listing.user_email || 'No contact'}`);
                console.log(`      Updated: ${listing.updated_at || 'Unknown'}`);
                console.log('      ---');
            });
        } else {
            console.log('❌ No listings found with current filters');
            
            // Debug: Check what's actually in your database
            const { data: allListings } = await this.supabase
                .from('listings')
                .select('*')
                .limit(10);
            
            console.log('🗃️ Sample listings from your database:');
            allListings?.forEach((listing, i) => {
                console.log(`  ${i+1}. ID: ${listing.id}`);
                console.log(`      Street: ${listing.street || 'None'}`);
                console.log(`      Location: ${listing.location || 'None'}`);
                console.log(`      Country: ${listing.country || 'None'}`);
                console.log(`      Owner: ${listing.user_email || 'None'}`);
            });
        }
        
        return listings || [];
    }

    // Helper function to check if listing matches location (updated for your schema)
    matchesLocation(listing, searchLocation) {
        const location = searchLocation.toLowerCase();
        const listingLocation = (listing.location || '').toLowerCase();
        const street = (listing.street || '').toLowerCase();
        const country = (listing.country || '').toLowerCase();
        
        // Check location, street, and country columns from your schema
        return listingLocation.includes(location) || 
               street.includes(location) || 
               country.includes(location);
    }

    // Update left sidebar with matching listings
    updateSidebarWithListings(listings) {
        const activeNegotiations = document.getElementById('activeNegotiations');
        if (!activeNegotiations) {
            console.warn('⚠️ activeNegotiations element not found');
            return;
        }

        if (!listings || listings.length === 0) {
            activeNegotiations.innerHTML = '<p class="text-gray-500 text-sm">No matching listings found. Try adjusting your search criteria.</p>';
            return;
        }

        // Create HTML for the listings
        let listingsHTML = '<h4 class="text-sm font-semibold text-gray-700 mb-3">🏠 Matching Listings</h4>';
        
        listings.slice(0, 5).forEach((listing, index) => {
            const locationText = listing.location || 'Location not specified';
            const streetText = listing.street ? ` - ${listing.street}` : '';
            const countryText = listing.country ? ` (${listing.country})` : '';
            
            listingsHTML += `
                <div class="bg-gray-50 rounded-lg p-3 mb-3 border border-gray-200 hover:bg-gray-100 transition-colors">
                    <div class="flex items-start justify-between">
                        <div class="flex-1">
                            <p class="text-sm font-medium text-gray-800">📍 ${locationText}</p>
                            ${streetText ? `<p class="text-xs text-gray-600 mt-1">${streetText}</p>` : ''}
                            ${countryText ? `<p class="text-xs text-gray-500">${countryText}</p>` : ''}
                            <p class="text-xs text-gray-400 mt-1">ID: ${listing.id}</p>
                        </div>
                        <button onclick="window.aiChat?.contactLandlord('${listing.id}')" 
                                class="text-xs bg-blue-500 text-white px-2 py-1 rounded hover:bg-blue-600 transition-colors">
                            Contact
                        </button>
                    </div>
                </div>
            `;
        });

        if (listings.length > 5) {
            listingsHTML += `<p class="text-xs text-gray-500 mt-2">... and ${listings.length - 5} more listings</p>`;
        }

        activeNegotiations.innerHTML = listingsHTML;
        console.log(`✅ Updated sidebar with ${listings.length} listings`);
    }

    // Handle contact landlord button clicks from sidebar
    contactLandlord(listingId) {
        const listing = this.matchingListings.find(l => l.id === listingId);
        if (!listing) {
            console.error('❌ Listing not found:', listingId);
            return;
        }

        this.appendMessage('AI', `📧 Initiating contact with landlord for listing ${listingId}...`, 'left');
        
        if (this.negotiationEngine) {
            this.sendMessage(listing);
        } else {
            this.sendBasicMessage(listing);
        }
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
            
            // Update the left sidebar with matching listings
            this.updateSidebarWithListings(this.matchingListings);
            
            for (const listing of this.matchingListings.slice(0, 3)) {
                // Display listings based on your actual database schema: id, street, location, user_email, updated_at, country
                const locationText = listing.location ? `${listing.location}` : 'Location not specified';
                const streetText = listing.street ? ` - ${listing.street}` : '';
                const countryText = listing.country ? ` (${listing.country})` : '';
                this.appendMessage('AI', `🏠 Listing ID: ${listing.id} - ${locationText}${streetText}${countryText}`, 'left');
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
        
        // Try to find similar listings with your actual database schema
        let query = this.supabase
            .from('listings')
            .select('*') // Use your actual schema: id, street, location, user_email, updated_at, country
            .neq('user_email', this.currentUser?.email || '')
            .limit(10);

        // Show any available listings since we don't have all filtering options
        const { data: similarListings } = await query.order('updated_at', { ascending: false });
        
        if (similarListings?.length > 0) {
            const criteria = [];
            if (this.userNeeds.houseType) criteria.push(this.userNeeds.houseType.toLowerCase());
            if (this.userNeeds.preferredLocation) criteria.push(`in ${this.userNeeds.preferredLocation}`);
            if (this.userNeeds.maxPrice) criteria.push(`under $${this.userNeeds.maxPrice}`);
            
            this.appendMessage('AI', `I searched for: ${criteria.join(' + ')}. Here are similar listings:`, 'left');
            
            let shownCount = 0;
            for (const listing of similarListings.slice(0, 5)) {
                // Display with your actual database schema: id, street, location, user_email, updated_at, country
                const locationText = listing.location ? `${listing.location}` : 'Location not specified';
                const streetText = listing.street ? ` - ${listing.street}` : '';
                const countryText = listing.country ? ` (${listing.country})` : '';
                this.appendMessage('AI', `📋 Listing ID: ${listing.id} - ${locationText}${streetText}${countryText}`, 'left');
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

            // Use the advanced negotiation engine
            const negotiationResult = await this.negotiationEngine.startNegotiation(
                listing, 
                this.userNeeds.maxPrice, 
                this.currentUser.email
            );

            // Create or get conversation
            const conversation = await this.getOrCreateConversation(listing);
            if (!conversation) {
                console.error('Failed to create conversation');
                return false;
            }

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
            
            // Set up context for potential landlord response in basic message mode
            this.pendingUserResponse = {
                id: `basic_message_${conversation.id}`,
                listing: {
                    id: listing.id,
                    title: listing.title,
                    price: listing.price,
                    landlord_email: listing.user_email
                },
                lastMessage: `Sent basic message: "${basicMessage}"`,
                phase: 'awaiting_landlord_response',
                timestamp: new Date().toISOString(),
                messageId: data[0]?.id
            };
            
            console.log('📝 [CONTEXT SET] Basic message context created:', {
                id: this.pendingUserResponse.id,
                phase: this.pendingUserResponse.phase,
                listingTitle: this.pendingUserResponse.listing.title,
                timestamp: this.pendingUserResponse.timestamp
            });
            
            // Also add to conversation tracking
            this.activeConversations.set(conversation.id, {
                listing: this.pendingUserResponse.listing,
                lastMessage: basicMessage,
                status: 'message_sent',
                timestamp: new Date().toISOString()
            });
            
            console.log('📝 [CONTEXT SET] Active conversations updated:', this.activeConversations.size);
            
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
            
            // Create new conversation with correct schema
            const { data: newConv, error } = await this.supabase
                .from('conversations')
                .insert({
                    listing_id: listing.id,
                    sender_email: this.currentUser.email,
                    receiver_email: listing.user_email,
                    created_at: new Date().toISOString()
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
        
        // Check if this is a negotiation response first
        console.log('🔍 [PROCESS MESSAGE] About to check if negotiation response...');
        const isNegotiationResponse = this.checkForNegotiationResponse(message);
        console.log('🔍 [PROCESS MESSAGE] Negotiation response check result:', isNegotiationResponse);
        
        if (isNegotiationResponse) {
            console.log('🤝 [PROCESS MESSAGE] Detected negotiation response, handling...');
            this.removeTypingIndicator();
            await this.handleNegotiationResponse(message);
            console.log('🤝 [PROCESS MESSAGE] Negotiation response handling complete, returning');
            return;
        }
        
        console.log('🔍 [PROCESS MESSAGE] Not a negotiation response, proceeding with search logic...');
        
        // Extract requirements for search requests
        const extractedData = await this.extractRentalInfo(message);
        console.log('📊 Raw extracted data:', extractedData);
        this.updateUserNeeds(extractedData);
        console.log('🎯 Final user needs after update:', this.userNeeds);
        console.log('🔍 Location that will be used in search:', this.userNeeds.preferredLocation);
        
        this.removeTypingIndicator();
        
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

    // Check if the message is a negotiation response (yes, sure, etc.)
    checkForNegotiationResponse(message) {
        console.log('🔍 [NEGOTIATION CHECK] Starting check for message:', message);
        const cleanMessage = message.toLowerCase().trim();
        
        // First check: Do we have any active conversations waiting for user response?
        const hasActiveContext = this.pendingUserResponse !== null || this.activeConversations.size > 0;
        
        console.log('🔍 [NEGOTIATION CHECK] Active context check:', {
            pendingUserResponse: this.pendingUserResponse ? {
                id: this.pendingUserResponse.id,
                phase: this.pendingUserResponse.phase,
                listingTitle: this.pendingUserResponse.listing?.title
            } : null,
            activeConversationsCount: this.activeConversations.size,
            hasActiveContext
        });
        
        // Secondary check: Look for conversation patterns in recent history
        const recentMessages = this.conversationHistory.slice(-5); // Check more messages
        const interactionKeywords = [
            'discussing', 'terms', 'open to', 'interested in', 
            'landlord', 'landlords', 'property', 'listing', 
            'contacting', 'message', 'sent', 'negotiat', 
            'reply', 'respond', 'owner', 'rent'
        ];
        
        const hasRecentLandlordInteraction = recentMessages.some(msg => 
            msg.role === 'ai' && interactionKeywords.some(keyword => 
                msg.content.toLowerCase().includes(keyword.toLowerCase())
            )
        );
        
        console.log('🔍 Recent interaction check:', {
            recentMessages: recentMessages.map(m => ({ role: m.role, content: m.content.substring(0, 50) + '...' })),
            hasRecentLandlordInteraction,
            matchedKeywords: interactionKeywords.filter(keyword => 
                recentMessages.some(msg => msg.role === 'ai' && msg.content.toLowerCase().includes(keyword.toLowerCase()))
            )
        });
        
        if (!hasActiveContext && !hasRecentLandlordInteraction) {
            console.log('🔍 No active negotiation context or recent interaction - treating as search request');
            return false;
        }
        
        // If we have recent landlord interaction but no context, create temporary context
        if (!hasActiveContext && hasRecentLandlordInteraction) {
            console.log('🔧 Creating temporary context based on recent conversation');
            this.pendingUserResponse = {
                id: 'conversation_continuation',
                listing: { id: 'ongoing', title: 'Ongoing Discussion', price: null },
                lastMessage: 'Recent conversation detected',
                phase: 'continuing_conversation'
            };
        }
        
        // Acceptance patterns - same as in ai-negotiation.js
        const acceptancePatterns = [
            /^(sure|yes|ok|okay|sounds good|works|fine|agreed|deal|sounds great|yep|yeah|absolutely)$/i,
            /^(yes\s+(sure|absolutely|definitely|of course|certainly|i am))/i,
            /^(sure\s+(thing|yes|absolutely|definitely))/i,
            /^(yeah\s+(sure|that works|sounds good|okay))/i,
            /^(absolutely\s+(yes|sure)?)/i,
            /^(definitely\s+(yes|sure)?)/i,
            /^(of course\s+(yes|sure)?)/i,
            /^(that\s+(works|sounds good|sounds great))/i,
            /^(sounds\s+(good|great|perfect|fine))/i,
            /^(works\s+for me)/i,
            /^(i\s+accept)/i,
            /^(perfect)/i,
            /^(excellent)/i
        ];
        
        const isAcceptance = acceptancePatterns.some(pattern => pattern.test(cleanMessage));
        
        // Debug pattern matching
        const matchingPatterns = acceptancePatterns.filter(pattern => pattern.test(cleanMessage));
        console.log('🔍 [PATTERN MATCHING] Testing acceptance patterns:', {
            cleanMessage,
            isAcceptance,
            matchingPatterns: matchingPatterns.map(p => p.toString()),
            allPatternResults: acceptancePatterns.map((pattern, index) => ({
                pattern: pattern.toString(),
                matches: pattern.test(cleanMessage)
            }))
        });
        
        // Also check for negotiation keywords
        const negotiationKeywords = ['price', 'rent', 'lower', 'higher', 'counter', 'offer', 'deal'];
        const hasNegotiationKeywords = negotiationKeywords.some(keyword => cleanMessage.includes(keyword));
        
        const finalDecision = isAcceptance || hasNegotiationKeywords;
        
        console.log('🔍 [FINAL DECISION] Negotiation response check result:', {
            cleanMessage,
            hasActiveContext,
            hasRecentLandlordInteraction,
            isAcceptance,
            hasNegotiationKeywords,
            finalDecision,
            pendingResponse: this.pendingUserResponse ? 'SET' : 'NULL',
            activeConversations: this.activeConversations.size,
            decision: finalDecision ? 'TREATING AS NEGOTIATION RESPONSE' : 'TREATING AS SEARCH REQUEST'
        });
        
        return finalDecision;
    }

    // Handle negotiation responses
    async handleNegotiationResponse(message) {
        console.log('🤝 Handling negotiation response:', message);
        
        // Check for active conversation context
        if (!this.pendingUserResponse && this.activeConversations.size === 0) {
            console.log('⚠️ No active negotiation context found');
            this.appendMessage('AI', 'I understand you\'re ready to proceed! However, I don\'t see any active negotiations at the moment. Try starting with: "I\'m looking for a 2-bedroom apartment under $1500" and I\'ll find properties and start negotiations for you!', 'left');
            return;
        }
        
        // Check if user is responding before landlord has replied
        if (this.pendingUserResponse && this.pendingUserResponse.phase === 'awaiting_landlord_response') {
            console.log('⚠️ User responding before landlord reply received');
            this.appendMessage('AI', `I understand you're eager to proceed! However, I just sent a message to the landlord about "${this.pendingUserResponse.listing.title}" and we haven't received their reply yet. Once they respond, I'll let you know and help continue the conversation. Please wait for their response first! 📧`, 'left');
            return;
        }
        
        // Check if negotiation engine is available
        if (!this.negotiationEngine) {
            console.warn('⚠️ Negotiation engine not available');
            this.appendMessage('AI', 'I understand your response! However, the negotiation system is currently initializing. Please try again in a moment.', 'left');
            return;
        }
        
        try {
            // If we have a pending response context, use it
            let negotiationContext = this.pendingUserResponse;
            
            // Otherwise, get the most recent active conversation
            if (!negotiationContext && this.activeConversations.size > 0) {
                const latestConversation = Array.from(this.activeConversations.values())[0];
                negotiationContext = {
                    id: 'active_conversation',
                    listing: latestConversation.listing,
                    lastMessage: latestConversation.lastMessage,
                    phase: 'user_response'
                };
            }
            
            // Still no context - create a generic one to maintain conversation flow
            if (!negotiationContext) {
                negotiationContext = {
                    id: 'general_inquiry',
                    listing: {
                        id: 'inquiry',
                        title: 'Property Inquiry',
                        price: null,
                        landlord_email: 'unknown'
                    },
                    lastOffer: null,
                    phase: 'initial_interest'
                };
            }
            
            // Use the negotiation engine to analyze the response
            const analysis = await this.negotiationEngine.analyzeReply(message, negotiationContext, negotiationContext.listing);
            console.log('📊 Negotiation analysis:', analysis);
            
            if (analysis.acceptsOffer) {
                this.appendMessage('AI', `🎉 Excellent! I understand you're interested in proceeding. Let me help coordinate the next steps. I'll continue the negotiation process and update you on any progress!`, 'left');
                
                // Add celebration effect
                this.celebrateSuccess();
                
                // Clear pending response since it's been handled
                this.pendingUserResponse = null;
            } else if (analysis.makesCounterOffer && analysis.priceOffered) {
                this.appendMessage('AI', `💬 I see you're interested in negotiating the price to $${analysis.priceOffered}. Let me continue working with the landlords on your behalf!`, 'left');
            } else {
                // General positive response
                this.appendMessage('AI', `👍 I understand your response! I'm working on finding the best options for you and will negotiate on your behalf. Let me continue the process...`, 'left');
            }
            
            // Show that AI is taking action
            setTimeout(() => {
                this.appendMessage('AI', '📧 Continuing negotiations with landlords... I\'ll update you when I receive responses!', 'left');
            }, 2000);
            
        } catch (error) {
            console.error('Error handling negotiation response:', error);
            this.appendMessage('AI', 'I understand your response! I\'m working on coordinating with landlords and will update you soon.', 'left');
        }
    }
}

// Export for use in HTML
window.AIChatHandler = AIChatHandler;