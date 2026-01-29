// AI Chat functionality for the negotiator with Supabase database integration
// This handles messaging, database search, and negotiation logic

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
        this.activeConversations = new Map();
        this.pendingUserResponse = null;

        // Requirements collection state - must collect ALL before searching
        this.requiredFields = {
            budget: null,
            bedrooms: null,
            location: null
        };
        this.requirementsComplete = false;
        this.listingSelectionMode = false;
        this.currentViewedListing = null;
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
            this.showWelcomeWithChips();
        }
    }

    // Show welcome message with quick start chips
    showWelcomeWithChips() {
        const chatMessages = document.getElementById('chatMessages');
        if (!chatMessages) return;

        chatMessages.innerHTML = `
            <div class="chat-bubble ai">
                <p>I can help you find a rental and negotiate a lower price with the landlord. What are you looking for?</p>
            </div>
        `;
    }

    // Send quick message from chip
    sendQuickMessage(message) {
        const messageInput = document.getElementById('messageInput');
        if (messageInput) {
            messageInput.value = message;
        }
        this.processMessage(message);
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

        // Unsubscribe from existing channel if any
        if (this.negotiationChannel) {
            console.log('🔄 Removing existing subscription');
            this.supabase.removeChannel(this.negotiationChannel);
        }

        try {
            // Use consistent channel name instead of timestamp
            this.negotiationChannel = this.supabase
                .channel(`negotiation_updates_${this.currentUser.email.replace(/[^a-zA-Z0-9]/g, '_')}`)
                .on('postgres_changes', {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'ai_chats'
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
                            console.log('📧 Landlord reply detected!');
                            this.displayLandlordReply(newChat);
                        }
                    } catch (error) {
                        console.error('Error processing real-time update:', error);
                    }
                })
                .subscribe();

            console.log('✅ Real-time subscription established');
        } catch (error) {
            console.error('❌ Failed to setup real-time subscription:', error);
        }
    }

    // Setup AI user profile for messaging
    async setupAIUser() {
        if (!this.currentUser?.email || !this.supabase) {
            return false;
        }

        // If user is logged in (not anonymous), assume they can message
        if (this.currentUser.email !== 'anonymous@user.com') {
            console.log('✅ User is logged in, messaging enabled:', this.currentUser.email);
            return true;
        }

        try {
            const { data: profile, error } = await this.supabase
                .from('profiles')
                .select('*')
                .eq('email', this.currentUser.email)
                .single();

            if (error) {
                console.log('⚠️ Profile not found for anonymous user');
                return false;
            }

            console.log('✅ User profile found for messaging:', profile.first_name);
            return true;
        } catch (error) {
            console.error('Error setting up AI user:', error);
            return false;
        }
    }

    // Process user message
    async processMessage(message) {
        console.log('🔄 Processing user message:', message);

        // Store user message
        this.appendMessage('You', message, 'right');
        this.conversationHistory.push({ role: 'user', content: message });
        this.saveConversationHistory();

        // Reset negotiation state for new requests
        this.negotiationState = 'idle';

        // Check if this is a negotiation response first
        if (this.checkForNegotiationResponse(message)) {
            return;
        }

        try {
            // Call the AI chat endpoint for intelligent conversation
            console.log('🤖 Calling AI chat endpoint...');
            const chatResponse = await this.callAIChatEndpoint(message);

            if (chatResponse.fallback) {
                // API unavailable, fall back to manual extraction
                console.log('⚠️ Falling back to manual extraction');
                const extractedData = this.extractManually(message);
                this.handleExtractedData(extractedData, null);
                return;
            }

            console.log('📊 AI Response:', chatResponse.response?.substring(0, 100));
            console.log('📊 Extracted criteria:', chatResponse.criteria);

            // Display the AI's conversational response
            if (chatResponse.response) {
                this.appendMessage('AI', chatResponse.response, 'left');
                this.conversationHistory.push({ role: 'assistant', content: chatResponse.response });
                this.saveConversationHistory();
            }

            // Handle extracted criteria
            if (chatResponse.criteria) {
                this.handleExtractedData(chatResponse.criteria, chatResponse.response);
            }

        } catch (error) {
            console.error('Error processing message:', error);
            // Fall back to manual extraction on error
            const extractedData = this.extractManually(message);
            this.handleExtractedData(extractedData, null);
        }
    }

    // Call the backend AI chat endpoint
    async callAIChatEndpoint(message) {
        try {
            const response = await fetch('/api/chat', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    message: message,
                    conversationHistory: this.conversationHistory.slice(-10),
                    userEmail: this.currentUser?.email
                })
            });

            if (!response.ok) {
                const errorData = await response.json().catch(() => ({}));
                console.error('❌ Chat API error:', response.status, errorData);
                return { fallback: true, error: errorData };
            }

            return await response.json();
        } catch (error) {
            console.error('❌ Error calling chat API:', error);
            return { fallback: true, error: error.message };
        }
    }

    // Handle extracted rental criteria - NEW: Collect ALL requirements before searching
    handleExtractedData(extractedData, aiResponse) {
        // Update user needs from extracted data
        this.updateUserNeeds(extractedData);

        // Update required fields from extracted data
        if (extractedData.price) {
            this.requiredFields.budget = extractedData.price;
            console.log('📝 Captured budget:', extractedData.price);
        }
        if (extractedData.bedrooms) {
            this.requiredFields.bedrooms = extractedData.bedrooms;
            console.log('📝 Captured bedrooms:', extractedData.bedrooms);
        }
        if (extractedData.city) {
            this.requiredFields.location = extractedData.city;
            console.log('📝 Captured location:', extractedData.city);
        }

        // Check if this looks like a rental search intent
        const hasSearchIntent = extractedData.intent === 'search' ||
            extractedData.price || extractedData.city || extractedData.bedrooms ||
            extractedData.house_type;

        if (!hasSearchIntent) {
            // Not a rental search - let the AI response handle it
            console.log('ℹ️ No rental search intent detected');
            return;
        }

        // Check if all requirements are complete
        const status = this.checkRequirementsComplete();
        console.log('🔍 Requirements status:', status);

        if (!status.complete) {
            // Ask for the missing requirement (only if AI didn't already ask)
            if (!aiResponse || !aiResponse.toLowerCase().includes(status.missing)) {
                this.appendMessage('AI', status.question, 'left');
            }
            console.log(`⏳ Missing requirement: ${status.missing}`);
            return;
        }

        // All requirements complete - now search!
        this.requirementsComplete = true;
        console.log('✅ All requirements collected, starting search...');

        const summary = `Got it! Searching for ${this.requiredFields.bedrooms}-bedroom places in ${this.requiredFields.location} under $${this.requiredFields.budget}/month...`;
        this.appendMessage('AI', summary, 'left');

        setTimeout(() => this.searchAndMessage(), 1000);
    }

    // Extract rental information - now primarily uses API, with manual fallback
    async extractRentalInfo(message) {
        // Try API first, fall back to manual extraction
        const chatResponse = await this.callAIChatEndpoint(message);
        if (chatResponse.fallback || !chatResponse.criteria) {
            console.log('🔍 Using manual extraction for rental criteria...');
            return this.extractManually(message);
        }
        return chatResponse.criteria;
    }

    // Manual extraction fallback
    extractManually(message) {
        console.log('Using manual extraction for:', message);
        const result = {};
        
        // Extract price
        const priceMatch = message.match(/(?:under|below|max|up to|for|at|around)?\s*\$?(\d{1,5})/i);
        if (priceMatch) {
            const extractedPrice = Number(priceMatch[1]);
            if (extractedPrice > 100) {
                result.price = extractedPrice;
                console.log('💰 Extracted price:', extractedPrice);
            }
        }
        
        // Extract city - international cities
        const cityMatch = message.match(/\b(hong kong|karachi|paris|tehran|toronto|moscow|sydney|vancouver|montreal|calgary|ottawa|edmonton|winnipeg|hamilton|quebec|saskatoon|regina|halifax|london|kitchener|waterloo|windsor|markham|mississauga|brampton|islamabad|lahore|rawalpindi|faisalabad|multan|hyderabad|peshawar|quetta|new york|los angeles|chicago|miami|boston)\b/i);
        if (cityMatch) {
            result.city = cityMatch[1].toLowerCase().trim();
            console.log('🏙️ Extracted city:', result.city);
        }

        // Extract country names as location fallback
        const countryMatch = message.match(/\b(pakistan|canada|usa|united states|uk|united kingdom|australia|france|germany|india|china|japan|iran|russia)\b/i);
        if (countryMatch && !result.city) {
            result.city = countryMatch[1].toLowerCase().trim();
            console.log('🌍 Extracted country as location:', result.city);
        }

        // Flexible "in [location]" pattern - captures any word after "in"
        const inLocationMatch = message.match(/\bin\s+([a-zA-Z\s]+?)(?:\s+for|\s+under|\s+with|\s*$|\s*,|\s*\.)/i);
        if (inLocationMatch && !result.city) {
            const location = inLocationMatch[1].trim().toLowerCase();
            // Only use if it looks like a place name (not common words)
            const skipWords = ['a', 'an', 'the', 'my', 'your', 'this', 'that', 'good', 'nice', 'great'];
            if (!skipWords.includes(location) && location.length > 1) {
                result.city = location;
                console.log('📍 Extracted location from "in" pattern:', result.city);
            }
        }
        
        // Extract house type (fallback only - OpenAI handles this primarily)
        const msg = message.toLowerCase();
        if (msg.includes('apartment')) {
            result.house_type = 'Apartment';
        } else if (msg.includes('condo')) {
            result.house_type = 'Condo';
        } else if (msg.includes('townhouse') || msg.includes('town house')) {
            result.house_type = 'Townhouse';
        } else if (msg.includes('house')) {
            result.house_type = 'House';
        } else if (msg.includes('studio')) {
            result.house_type = 'Studio';
        } else if (msg.includes('basement')) {
            result.house_type = 'Basement';
        } else if (msg.includes('room')) {
            result.house_type = 'Room';
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
        
        // Backup logic: if we extracted rental criteria, assume search intent
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
            let cleanCity = extractedData.city.toString().trim().toLowerCase();
            cleanCity = cleanCity.split(',')[0].trim();
            cleanCity = cleanCity.replace(/\s+(fr|france|canada|ca|usa|us|australia|au)$/i, '');
            this.userNeeds.preferredLocation = cleanCity;
            console.log('✅ Set location:', cleanCity);
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

    // Check if all required fields are collected before searching
    checkRequirementsComplete() {
        const { budget, bedrooms, location } = this.requiredFields;
        console.log('🔍 Checking requirements:', { budget, bedrooms, location });

        // Check in priority order: location, budget, bedrooms
        if (!location) {
            return {
                complete: false,
                missing: 'location',
                question: "What area or city are you looking to rent in?"
            };
        }
        if (!budget) {
            return {
                complete: false,
                missing: 'budget',
                question: "What's your monthly budget for rent?"
            };
        }
        if (!bedrooms) {
            return {
                complete: false,
                missing: 'bedrooms',
                question: "How many bedrooms do you need?"
            };
        }

        console.log('✅ All requirements complete!');
        return { complete: true };
    }

    // Search for matching listings in Supabase
    async findMatchingListings() {
        console.log('🔍 Starting search with criteria:', this.userNeeds);
        
        console.log('🔍 Building search query for your Supabase database...');
        
        // Query all columns from your actual schema: id, title, price, city, street, postal_code, house_type, bedrooms, utilities, description, media, user_email, created_at, updated_at
        let query = this.supabase
            .from('listings')
            .select('*');
        
        let appliedFilters = [];
        let hasSpecificCriteria = false;
        
        // Step 1: Exclude user's own listings
        if (this.currentUser?.email) {
            query = query.neq('user_email', this.currentUser.email);
            console.log('✅ Step 1: Excluded own listings');
        }
        
        // Step 2: Apply location filter using city, street, country, and title columns
        if (this.userNeeds.preferredLocation) {
            const location = this.userNeeds.preferredLocation.trim().toLowerCase();
            // Search in city, street, country, and title columns for flexible matching
            query = query.or(`city.ilike.*${location}*,street.ilike.*${location}*,title.ilike.*${location}*,country.ilike.*${location}*`);
            appliedFilters.push(`location contains: ${location}`);
            hasSpecificCriteria = true;
            console.log(`✅ Step 2: Location filter applied - searching for "${location}" in city/street/title/country columns`);
        }
        
        // Step 3: Apply house type filter
        if (this.userNeeds.houseType) {
            query = query.eq('house_type', this.userNeeds.houseType);
            appliedFilters.push(`house type: ${this.userNeeds.houseType}`);
            hasSpecificCriteria = true;
            console.log(`✅ Step 3: House type filter applied - ${this.userNeeds.houseType}`);
        }
        
        // Step 4: Apply price filter if max price is provided
        if (this.userNeeds.maxPrice) {
            try {
                query = query.lte('price', this.userNeeds.maxPrice);
                appliedFilters.push(`max price: $${this.userNeeds.maxPrice}`);
                hasSpecificCriteria = true;
                console.log(`✅ Step 4: Price filter applied - max $${this.userNeeds.maxPrice}`);
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
                console.log(`  ${i+1}. ID: ${listing.id}`);
                console.log(`      Title: ${listing.title || 'Not specified'}`);
                console.log(`      City: ${listing.city || 'Not specified'}`);
                console.log(`      Street: ${listing.street || 'Not specified'}`);
                console.log(`      Price: $${listing.price || 'Not specified'}`);
                console.log(`      Type: ${listing.house_type || 'Not specified'}`);
                console.log(`      Owner: ${listing.user_email || 'No contact'}`);
                console.log(`      Updated: ${listing.updated_at || 'Unknown'}`);
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
                console.log(`      Title: ${listing.title || 'None'}`);
                console.log(`      City: ${listing.city || 'None'}`);
                console.log(`      Street: ${listing.street || 'None'}`);
                console.log(`      Price: $${listing.price || 'None'}`);
                console.log(`      Type: ${listing.house_type || 'None'}`);
                console.log(`      Owner: ${listing.user_email || 'None'}`);
            });
        }
        
        return listings || [];
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
        
        listings.slice(0, 5).forEach((listing) => {
            const titleText = listing.title || 'Untitled Property';
            const cityText = listing.city || 'City not specified';
            const streetText = listing.street ? ` - ${listing.street}` : '';
            const priceText = listing.price ? `$${listing.price}` : 'Price not listed';
            const typeText = listing.house_type || 'Type not specified';
            
            listingsHTML += `
                <div class="bg-gray-50 rounded-lg p-3 mb-3 border border-gray-200 hover:bg-gray-100 transition-colors">
                    <div class="flex items-start justify-between">
                        <div class="flex-1">
                            <p class="text-sm font-medium text-gray-800">🏠 ${titleText}</p>
                            <p class="text-xs text-gray-600 mt-1">📍 ${cityText}${streetText}</p>
                            <p class="text-xs text-blue-600 font-medium">💰 ${priceText} • ${typeText}</p>
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

        // Use the proper method to start negotiation
        this.startNegotiationForListing(listing);
    }

    // Handle viewing a specific listing by number - Opens popup modal
    handleListingView(listingNumber) {
        console.log('👁️ User wants to view listing #', listingNumber);

        // Validate the selection
        if (!this.matchingListings || this.matchingListings.length === 0) {
            this.appendMessage('AI', 'No listings available. Please search for listings first.', 'left');
            return;
        }

        const index = listingNumber - 1; // Convert to 0-based index
        if (index < 0 || index >= this.matchingListings.length) {
            this.appendMessage('AI', `Invalid selection. Please choose a number between 1 and ${Math.min(this.matchingListings.length, 5)}.`, 'left');
            return;
        }

        const listing = this.matchingListings[index];
        this.currentViewedListing = listing;

        // Open the popup modal to show listing details
        if (typeof window.openListingPopup === 'function') {
            window.openListingPopup(listing);
        } else {
            // Fallback: Show details as text if popup not available
            console.warn('Popup function not available, showing text details');
            this.appendMessage('AI', `📋 **${listing.title || 'Property Details'}**`, 'left');
            this.appendMessage('AI', `📍 Location: ${listing.city || 'Not specified'}${listing.street ? `, ${listing.street}` : ''}`, 'left');
            this.appendMessage('AI', `💰 Price: $${listing.price || 'Not listed'}/month`, 'left');
            this.appendMessage('AI', `🛏️ Bedrooms: ${listing.bedrooms || 'Not specified'}`, 'left');
            this.appendMessage('AI', `🏠 Type: ${listing.house_type || 'Not specified'}`, 'left');
            this.appendMessage('AI', 'Would you like me to message this landlord on your behalf?', 'left');
            this.pendingUserResponse = 'contact_landlord';
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
            
            // Show found listings with numbered selection
            this.appendMessage('AI', `Found ${this.matchingListings.length} matching listing(s)!`, 'left');

            // Update the left sidebar with matching listings
            this.updateSidebarWithListings(this.matchingListings);

            // Display listings with clickable View buttons
            const listingsToShow = this.matchingListings.slice(0, 5);
            for (let i = 0; i < listingsToShow.length; i++) {
                const listing = listingsToShow[i];
                const titleText = listing.title || 'Untitled Property';
                const cityText = listing.city || 'City not specified';
                const priceText = listing.price ? `$${listing.price}/month` : 'Price not listed';
                const bedroomText = listing.bedrooms ? `${listing.bedrooms}BR` : '';
                const typeText = listing.house_type || '';
                const details = [bedroomText, typeText].filter(Boolean).join(' ');

                // Create a listing card with View button
                const listingCardHTML = `
                    <div class="listing-card-chat">
                        <div class="listing-card-chat-title">${i + 1}. ${titleText}</div>
                        <div class="listing-card-chat-details">
                            📍 ${cityText} • 💰 ${priceText}${details ? ` • ${details}` : ''}
                        </div>
                        <button class="listing-view-btn" onclick="window.aiChat.handleListingView(${i + 1})">
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                                <circle cx="12" cy="12" r="3"/>
                            </svg>
                            View Details
                        </button>
                    </div>
                `;
                this.appendMessageHTML('AI', listingCardHTML, 'left');
            }

            if (this.matchingListings.length > 5) {
                this.appendMessage('AI', `...and ${this.matchingListings.length - 5} more listings available.`, 'left');
            }

            // Ask user to select a listing to view
            this.appendMessage('AI', 'Click "View Details" on any listing to see more information.', 'left');

            // Set pending response for listing selection
            this.listingSelectionMode = true;
            this.pendingUserResponse = 'listing_selection';
            
        } catch (error) {
            this.removeTypingIndicator();
            console.error('Search error:', error);
            this.appendMessage('AI', `Search failed: ${error.message}`, 'left');
            this.negotiationState = 'idle';
        }
    }

    // Handle when no matches are found
    async handleNoMatches() {
        const extracted = [];
        if (this.userNeeds.preferredLocation) extracted.push(`Location: ${this.userNeeds.preferredLocation}`);
        if (this.userNeeds.maxPrice) extracted.push(`Max Price: $${this.userNeeds.maxPrice}`);
        if (this.userNeeds.houseType) extracted.push(`Type: ${this.userNeeds.houseType}`);
        
        this.appendMessage('AI', `❌ No exact matches found. I searched for: ${extracted.join(', ')}`, 'left');
        
        // Try to find similar listings with your actual database schema
        let query = this.supabase
            .from('listings')
            .select('*')
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
                // Display with your actual database schema
                const titleText = listing.title || 'Untitled Property';
                const cityText = listing.city || 'City not specified';
                const streetText = listing.street ? ` - ${listing.street}` : '';
                const priceText = listing.price ? ` - $${listing.price}` : '';
                const typeText = listing.house_type ? ` (${listing.house_type})` : '';
                this.appendMessage('AI', `📋 ${titleText} - ${cityText}${streetText}${priceText}${typeText}`, 'left');
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

    // Check if the message is a response to pending questions (listing selection, contact, etc.)
    checkForNegotiationResponse(message) {
        console.log('🔍 [RESPONSE CHECK] Checking message:', message, 'Pending:', this.pendingUserResponse);
        const cleanMessage = message.toLowerCase().trim();

        // Define common responses
        const affirmativeResponses = ['yes', 'sure', 'ok', 'okay', 'please', 'go ahead', 'proceed', 'yep', 'yeah', 'definitely', 'absolutely'];
        const negativeResponses = ['no', 'nope', 'not yet', 'pass', 'skip', 'nah', 'maybe later'];
        const isAffirmative = affirmativeResponses.some(r => cleanMessage.includes(r));
        const isNegative = negativeResponses.some(r => cleanMessage.includes(r));

        // Handle listing selection (user says "1", "2", "view 2", etc.)
        if (this.pendingUserResponse === 'listing_selection') {
            // Check for number in message
            const numberMatch = cleanMessage.match(/(\d+)/);
            if (numberMatch) {
                const listingNum = parseInt(numberMatch[1]);
                console.log('✅ User selected listing #', listingNum);
                this.handleListingView(listingNum);
                return true;
            }

            // FIX 1: Auto-select if affirmative and only 1 listing
            if (isAffirmative && this.matchingListings && this.matchingListings.length === 1) {
                console.log('✅ Auto-selecting only listing (single match + affirmative)');
                this.handleListingView(1);
                return true;
            }

            // Handle "view" or "view this" without number when only 1 listing
            if ((cleanMessage.includes('view') || cleanMessage.includes('this') || cleanMessage.includes('that'))
                && this.matchingListings && this.matchingListings.length === 1) {
                console.log('✅ Auto-selecting only listing (view keyword + single match)');
                this.handleListingView(1);
                return true;
            }

            // Check if user wants to see all or contact all
            if (cleanMessage.includes('all') || cleanMessage.includes('contact') || cleanMessage.includes('message')) {
                this.appendMessage('AI', 'Which listing number would you like to view first? (1, 2, 3...)', 'left');
                return true;
            }
        }

        // Handle contact landlord response (after viewing a listing)
        if (this.pendingUserResponse === 'contact_landlord') {
            // FIX 2: Better keyword detection for "msg landlord", "message the landlord", "I like it contact", etc.
            const wantsToMessage = cleanMessage.includes('msg') ||
                                   cleanMessage.includes('message') ||
                                   cleanMessage.includes('contact') ||
                                   cleanMessage.includes('reach out') ||
                                   cleanMessage.includes('landlord');
            const likesIt = cleanMessage.includes('like') ||
                            cleanMessage.includes('good') ||
                            cleanMessage.includes('great') ||
                            cleanMessage.includes('perfect') ||
                            cleanMessage.includes('love') ||
                            cleanMessage.includes('interested');

            // Check affirmative OR explicit message intent OR likes it + has listing
            if ((isAffirmative || wantsToMessage || likesIt) && this.currentViewedListing) {
                console.log('✅ User wants to contact landlord (affirmative/keyword match)');
                this.appendMessage('AI', `Great! I'll reach out to the landlord for "${this.currentViewedListing.title}"...`, 'left');
                this.pendingUserResponse = null;
                setTimeout(() => this.startNegotiationForListing(this.currentViewedListing), 1000);
                return true;
            } else if (isNegative) {
                console.log('❌ User declined to contact landlord');
                this.pendingUserResponse = 'continue_browsing';
                this.appendMessage('AI', 'No problem! Would you like to view another listing, or is there anything else I can help with?', 'left');
                return true;
            }
        }

        // Handle continue browsing response
        if (this.pendingUserResponse === 'continue_browsing') {
            // Check if they want to view another listing
            const numberMatch = cleanMessage.match(/(\d+)/);
            if (numberMatch) {
                const listingNum = parseInt(numberMatch[1]);
                console.log('✅ User wants to view another listing #', listingNum);
                this.handleListingView(listingNum);
                return true;
            }

            if (cleanMessage.includes('another') || cleanMessage.includes('other') || cleanMessage.includes('different')) {
                this.appendMessage('AI', 'Sure! Which listing number would you like to view?', 'left');
                this.pendingUserResponse = 'listing_selection';
                return true;
            }

            if (isNegative || cleanMessage.includes('nothing') || cleanMessage.includes('done') || cleanMessage.includes('that\'s all')) {
                this.appendMessage('AI', 'Alright! Feel free to search again if you need anything else. Good luck with your rental search!', 'left');
                this.pendingUserResponse = null;
                this.listingSelectionMode = false;
                return true;
            }
        }

        // Legacy: Handle old negotiate_offer response type
        if (this.pendingUserResponse === 'negotiate_offer' && isAffirmative && this.matchingListings.length > 0) {
            console.log('✅ Legacy negotiate_offer - redirecting to listing selection');
            this.appendMessage('AI', 'Which listing would you like me to contact the landlord for? Just say the number.', 'left');
            this.pendingUserResponse = 'listing_selection';
            return true;
        }

        // Check for direct negotiation requests
        const negotiationKeywords = ['negotiate', 'contact landlord', 'message landlord', 'talk to landlord', 'reach out'];
        const hasNegotiationKeyword = negotiationKeywords.some(keyword => cleanMessage.includes(keyword));

        if (hasNegotiationKeyword && this.matchingListings.length > 0) {
            console.log('✅ Direct negotiation request - asking which listing');
            this.appendMessage('AI', 'Which listing would you like me to contact the landlord for? Just say the number (e.g., "1").', 'left');
            this.pendingUserResponse = 'listing_selection';
            return true;
        }

        // FIX 3: CRITICAL - Prevent fall-through to AI API when pending response exists
        // If we have a pending response but didn't match above, ask for clarification instead of calling AI
        if (this.pendingUserResponse && ['listing_selection', 'contact_landlord', 'continue_browsing'].includes(this.pendingUserResponse)) {
            console.log('⚠️ Pending response not matched, asking for clarification instead of calling AI');
            if (this.pendingUserResponse === 'listing_selection') {
                this.appendMessage('AI', 'Please enter a listing number to view its details (e.g., "1" or "2").', 'left');
            } else if (this.pendingUserResponse === 'contact_landlord') {
                this.appendMessage('AI', 'Would you like me to message this landlord? Just say "yes" or "no".', 'left');
            } else if (this.pendingUserResponse === 'continue_browsing') {
                this.appendMessage('AI', 'Would you like to view another listing, or is there anything else I can help with?', 'left');
            }
            return true; // CRITICAL: This prevents the AI API call which would trigger a new search
        }

        console.log('❌ [RESPONSE CHECK] No matching response detected');
        return false;
    }

    // Start negotiations for all matching listings
    async startNegotiationsForAllListings() {
        if (!this.matchingListings || this.matchingListings.length === 0) {
            this.appendMessage('AI', 'No listings available for negotiation. Please search for properties first.', 'left');
            return;
        }

        this.appendMessage('AI', `📧 Contacting landlords for ${this.matchingListings.length} listing(s)...`, 'left');

        for (const listing of this.matchingListings) {
            if (listing.user_email && listing.user_email !== this.currentUser?.email) {
                setTimeout(() => this.startNegotiationForListing(listing), 500);
            }
        }
    }

    // Start negotiation for a specific listing - HUMAN-LIKE PHASED APPROACH
    async startNegotiationForListing(listing) {
        try {
            this.appendMessage('AI', `Starting conversation with landlord for "${listing.title}"...`, 'left');

            if (!this.currentUser?.email) {
                this.appendMessage('AI', 'You need to be logged in to contact landlords.', 'left');
                return;
            }

            if (!listing.user_email) {
                this.appendMessage('AI', 'This listing has no landlord contact information.', 'left');
                return;
            }

            // Step 1: Check if conversation already exists
            console.log('🔍 Checking for existing conversation...');
            const { data: existingConversations, error: checkError } = await this.supabase
                .from('conversations')
                .select('id')
                .eq('listing_id', listing.id)
                .or(`and(sender_email.eq.${this.currentUser.email},receiver_email.eq.${listing.user_email}),and(sender_email.eq.${listing.user_email},receiver_email.eq.${this.currentUser.email})`)
                .maybeSingle();

            if (checkError) {
                console.error('❌ Error checking for existing conversation:', checkError);
            }

            let conversationId = existingConversations?.id;

            // Step 2: Create conversation if it doesn't exist
            if (!conversationId) {
                console.log('📝 Creating new conversation...');
                const { data: newConversation, error: createError } = await this.supabase
                    .from('conversations')
                    .insert({
                        listing_id: listing.id,
                        sender_email: this.currentUser.email,
                        receiver_email: listing.user_email
                    })
                    .select('id')
                    .single();

                if (createError) {
                    console.error('❌ Error creating conversation:', createError);
                    this.appendMessage('AI', `Failed to create conversation: ${createError.message}`, 'left');
                    return;
                }

                conversationId = newConversation.id;
                console.log('✅ Created new conversation with ID:', conversationId);
            } else {
                console.log('✅ Found existing conversation with ID:', conversationId);
            }

            // Step 3: Use HUMAN-LIKE phased conversation approach
            if (this.negotiationEngine) {
                console.log('🎭 [NEW CODE v2] Starting human-like phased conversation - NO PRICING IN FIRST MESSAGE');

                const budget = this.userNeeds.maxPrice || listing.price * 0.85; // Default to 85% of listing price
                const userName = this.currentUser.firstName || this.currentUser.email.split('@')[0];

                // Start with introduction phase (NO pricing)
                const conversationData = await this.negotiationEngine.startHumanLikeConversation(
                    listing,
                    budget,
                    this.currentUser.email,
                    userName
                );

                if (conversationData && conversationData.message) {
                    // Store the negotiation ID for tracking
                    this.activeNegotiationId = conversationData.negotiationId;
                    this.activeConversationId = conversationId;
                    this.activeListing = listing;

                    // Send the introduction message
                    console.log('📤 Sending introduction message (no pricing):', conversationData.message);
                    const sent = await this.negotiationEngine.sendNegotiationMessage(
                        conversationId,
                        conversationData.message,
                        this.currentUser.email,
                        listing.user_email,
                        listing.title
                    );

                    if (sent) {
                        this.appendMessage('AI', `Reached out to the landlord for "${listing.title}"`, 'left');
                        this.appendMessage('AI', `Sent: "${conversationData.message}"`, 'left');
                        this.appendMessage('AI', `I'll continue the conversation naturally when they reply - building rapport before discussing price.`, 'left');

                        // Set up auto-reply listener for this conversation
                        this.setupConversationAutoReply(conversationId, conversationData.negotiationId, listing);
                    } else {
                        this.appendMessage('AI', `Failed to send message to landlord`, 'left');
                    }
                } else {
                    this.appendMessage('AI', 'Failed to start conversation', 'left');
                }
            } else {
                // Fallback: Send basic human-like message without full AI engine
                console.log('📤 Sending basic introduction (no AI engine available)...');
                const message = `Hey! I saw your listing for "${listing.title}" and it caught my eye. Is it still available?`;

                const { error: sendError } = await this.supabase
                    .from('messages')
                    .insert({
                        conversation_id: conversationId,
                        sender_email: this.currentUser.email,
                        content: message
                    });

                if (sendError) {
                    console.error('❌ Error sending message:', sendError);
                    this.appendMessage('AI', `Failed to send message: ${sendError.message}`, 'left');
                    return;
                }

                this.appendMessage('AI', `Sent message to landlord for "${listing.title}"`, 'left');
                this.appendMessage('AI', `Message: "${message}"`, 'left');
            }
        } catch (error) {
            console.error('Conversation error:', error);
            this.appendMessage('AI', `Error contacting landlord: ${error.message}`, 'left');
        }
    }

    // Set up auto-reply for landlord responses
    setupConversationAutoReply(conversationId, negotiationId, listing) {
        console.log('🔔 Setting up auto-reply listener for conversation:', conversationId);

        // Subscribe to new messages in this conversation
        const channel = this.supabase
            .channel(`conversation_${conversationId}`)
            .on(
                'postgres_changes',
                {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'messages',
                    filter: `conversation_id=eq.${conversationId}`
                },
                async (payload) => {
                    const newMessage = payload.new;

                    // Only respond to landlord messages (not our own)
                    if (newMessage.sender_email === listing.user_email) {
                        console.log('📩 Landlord replied:', newMessage.content);

                        // Process the reply and generate phased response
                        await this.handleLandlordAutoReply(newMessage, conversationId, negotiationId, listing);
                    }
                }
            )
            .subscribe((status) => {
                console.log('🔔 Auto-reply subscription status:', status);
            });

        // Store channel for cleanup
        if (!this.autoReplyChannels) {
            this.autoReplyChannels = new Map();
        }
        this.autoReplyChannels.set(conversationId, channel);
    }

    // Handle landlord reply and auto-respond with next phase
    async handleLandlordAutoReply(landlordMessage, conversationId, negotiationId, listing) {
        try {
            console.log('🤖 Auto-replying to landlord message...');

            if (!this.negotiationEngine) {
                console.error('No negotiation engine available');
                return;
            }

            // Get phased response from negotiation engine
            const response = await this.negotiationEngine.handleLandlordReplyWithPhases(
                landlordMessage.content,
                negotiationId,
                listing
            );

            if (response && response.message) {
                // Apply human-like delay before responding
                const delay = response.delay || 2000;
                console.log(`⏳ Waiting ${delay}ms before responding (human-like delay)...`);

                await new Promise(resolve => setTimeout(resolve, delay));

                // Send the response
                const userName = this.currentUser?.firstName || this.currentUser?.email?.split('@')[0] || 'Tenant';
                const sent = await this.negotiationEngine.sendNegotiationMessage(
                    conversationId,
                    response.message,
                    this.currentUser.email,
                    listing.user_email,
                    listing.title
                );

                if (sent) {
                    console.log(`✅ Sent ${response.phase} response:`, response.message);

                    // Notify user about the exchange
                    this.appendMessage('AI', `Landlord replied: "${landlordMessage.content}"`, 'left');
                    this.appendMessage('AI', `I responded (${response.phase.replace(/_/g, ' ').toLowerCase()}): "${response.message}"`, 'left');
                } else {
                    console.error('Failed to send auto-reply');
                }
            }
        } catch (error) {
            console.error('Error handling landlord auto-reply:', error);
        }
    }

    // Load conversation history from Supabase
    async loadConversationHistory() {
        // Disabled - table doesn't exist in database
        // Each session starts fresh
        return;
    }

    // Save conversation history to Supabase
    async saveConversationHistory() {
        // Disabled - table doesn't exist in database
        // Chat history is stored in memory only during session
        return;
    }

    // Clear conversation history
    async clearConversationHistory() {
        this.conversationHistory = [];

        if (this.currentUser?.email && this.supabase) {
            try {
                const { error } = await this.supabase
                    .from('ai_chat_history')
                    .delete()
                    .eq('user_email', this.currentUser.email);

                if (error) {
                    console.error('Error clearing chat history:', error.message);
                }
            } catch (error) {
                console.error('Error clearing conversation history:', error);
            }
        }

        // Clear UI
        const messages = document.getElementById('chatMessages');
        if (messages) {
            messages.innerHTML = '';
        }
    }

    // Display message to chat (without saving to history)
    displayMessage(sender, message, align, isTypingIndicator = false) {
        const messages = document.getElementById('chatMessages');
        if (!messages) {
            console.error('Error: #chatMessages element not found');
            return;
        }

        const messageDiv = document.createElement('div');
        // Use align parameter: 'right' = sent (user), 'left' = received (other)
        const alignClass = align === 'right' ? 'sent' : 'received';
        messageDiv.className = `message ${alignClass}`;

        // Determine display name
        let displayName = sender;
        if (sender.toLowerCase() === 'you') displayName = 'You';
        else if (sender.toLowerCase() === 'ai') displayName = 'AI Assistant';
        else if (sender.toLowerCase() === 'ai negotiator') displayName = 'AI Negotiator';
        else if (sender.toLowerCase() === 'landlord') displayName = 'Landlord';
        else if (sender.toLowerCase() === 'system') displayName = 'System';

        const labelClass = align === 'right' ? 'text-indigo-200' : 'text-gray-500';

        messageDiv.innerHTML = `
            <div class="font-semibold text-xs ${labelClass} mb-1">${displayName}</div>
            <p>${message}</p>
        `;

        messages.appendChild(messageDiv);
        messages.scrollTop = messages.scrollHeight;
    }

    // Append message to chat and save to history
    appendMessage(sender, message, align, isTypingIndicator = false) {
        // Display the message
        this.displayMessage(sender, message, align, isTypingIndicator);

        // Save to history and localStorage (skip typing indicators)
        if (!isTypingIndicator) {
            // Map display names to OpenAI-compatible roles
            const role = sender.toLowerCase() === 'you' ? 'user' :
                        sender.toLowerCase() === 'ai' ? 'assistant' :
                        sender.toLowerCase();
            this.conversationHistory.push({ role: role, content: message });
            this.saveConversationHistory();
        }
    }

    // Append HTML message to chat (for cards, buttons, etc.) - doesn't save to history
    appendMessageHTML(sender, htmlContent, align) {
        const messages = document.getElementById('chatMessages');
        if (!messages) {
            console.error('Error: #chatMessages element not found');
            return;
        }

        const messageDiv = document.createElement('div');
        const alignClass = align === 'right' ? 'sent' : 'received';
        messageDiv.className = `message ${alignClass}`;

        // Determine display name
        let displayName = sender;
        if (sender.toLowerCase() === 'you') displayName = 'You';
        else if (sender.toLowerCase() === 'ai') displayName = 'AI Assistant';

        const labelClass = align === 'right' ? 'text-indigo-200' : 'text-gray-500';

        messageDiv.innerHTML = `
            <div class="font-semibold text-xs ${labelClass} mb-1">${displayName}</div>
            ${htmlContent}
        `;

        messages.appendChild(messageDiv);
        messages.scrollTop = messages.scrollHeight;
    }

    // Remove typing indicator
    removeTypingIndicator() {
        const typingIndicator = document.getElementById('typing-indicator');
        if (typingIndicator) typingIndicator.remove();
    }

    // Display negotiation success notification
    displayNegotiationSuccess(chatData) {
        try {
            const conversationData = JSON.parse(chatData.conversation_data);
            const message = conversationData[0]?.content || 'Negotiation successful!';

            this.appendMessage('AI', message, 'left');

            // Visual celebration effect
            this.celebrateSuccess();
        } catch (error) {
            console.error('Error displaying negotiation success:', error);
            this.appendMessage('AI', '🎉 Negotiation completed successfully!', 'left');
        }
    }

    // Display landlord reply notification
    displayLandlordReply(chatData) {
        try {
            const conversationData = JSON.parse(chatData.conversation_data);
            const message = conversationData[0]?.content || 'Received reply from landlord';

            this.appendMessage('AI', message, 'left');
        } catch (error) {
            console.error('Error displaying landlord reply:', error);
            this.appendMessage('AI', '💬 Received a reply from the landlord', 'left');
        }
    }

    // Celebrate negotiation success with visual effects
    celebrateSuccess() {
        const messages = document.getElementById('chatMessages');
        if (!messages) return;

        // Add celebration animation
        const celebration = document.createElement('div');
        celebration.className = 'celebration-animation';
        celebration.innerHTML = '🎉🎊✨';
        celebration.style.cssText = `
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 4rem;
            animation: celebrate 2s ease-out;
            pointer-events: none;
            z-index: 1000;
        `;

        messages.style.position = 'relative';
        messages.appendChild(celebration);

        // Remove after animation
        setTimeout(() => celebration.remove(), 2000);
    }
}

// Make the class globally available
window.AIChatHandler = AIChatHandler;