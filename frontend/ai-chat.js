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
            this.appendMessage('AI', 'Hello! I\'m your AI assistant. Tell me what you\'re looking for (e.g., "I want a house in Hong Kong for $1500") and I\'ll search our database for matching listings and help you negotiate with landlords!', 'left');
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
            // Extract rental criteria from message
            console.log('🔍 Extracting rental criteria...');
            const extractedData = await this.extractRentalInfo(message);
            console.log('📊 Extracted data:', extractedData);
            
            // Update user needs
            this.updateUserNeeds(extractedData);
            
            // Check if we should search for listings
            const shouldSearch = extractedData.intent === 'search' || 
                                (extractedData.price && extractedData.city) ||
                                (extractedData.house_type && (extractedData.price || extractedData.city));
            
            console.log('🎯 Should search for listings:', shouldSearch, {
                hasIntent: extractedData.intent === 'search',
                hasPrice: !!extractedData.price,
                hasCity: !!extractedData.city,
                hasType: !!extractedData.house_type,
                shouldSearch
            });
            
            if (shouldSearch) {
                this.appendMessage('AI', 'I understand! Searching for matching listings in our database...', 'left');
                setTimeout(() => this.searchAndMessage(), 1000);
            } else {
                this.appendMessage('AI', 'I understand your preferences. To search for listings, try saying something like "I need a 2-bedroom apartment under $1500 in Toronto"', 'left');
            }
        } catch (error) {
            console.error('Error processing message:', error);
            this.appendMessage('AI', 'I\'m having trouble processing your request. Please try rephrasing your message.', 'left');
        }
    }

    // Extract rental information using OpenAI
    async extractRentalInfo(message) {
        if (!this.config?.OPENAI_API_KEY) {
            console.log('⚠️ OpenAI not configured, using manual extraction');
            return this.extractManually(message);
        }

        try {
            console.log('🤖 Using OpenAI to extract rental criteria...');
            
            const prompt = `Extract rental criteria from this message. Return ONLY a JSON object with these exact fields:
            {
                "intent": "search" if looking for rentals, otherwise null,
                "price": number (max budget) or null,
                "city": city name in lowercase or null,
                "house_type": "House", "Apartment", "Condo", "Studio", or "Basement" or null,
                "bedrooms": number or null,
                "utilities": "included", "separate", or null
            }

            Message: "${message}"
            
            JSON:`;

            const response = await fetch('https://api.openai.com/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.config.OPENAI_API_KEY}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    model: this.config.OPENAI_MODEL || 'gpt-3.5-turbo',
                    messages: [{ role: 'user', content: prompt }],
                    max_tokens: 150,
                    temperature: 0.1
                })
            });

            if (!response.ok) throw new Error('OpenAI API error');

            const data = await response.json();
            const extractedText = data.choices[0].message.content.trim();
            
            try {
                const extracted = JSON.parse(extractedText);
                console.log('✅ OpenAI extraction successful:', extracted);
                return extracted;
            } catch (parseError) {
                console.log('⚠️ JSON parse failed, using manual extraction');
                return this.extractManually(message);
            }
        } catch (error) {
            console.log('⚠️ OpenAI extraction failed, using manual extraction:', error.message);
            return this.extractManually(message);
        }
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
        
        // Additional location patterns for "in [city]"
        const inCityMatch = message.match(/\bin\s+(hong kong|karachi|paris|tehran|toronto|moscow|sydney|vancouver|montreal|calgary|islamabad|lahore|rawalpindi)\b/i);
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
        
        // Step 2: Apply location filter using 'city' and 'street' columns
        if (this.userNeeds.preferredLocation) {
            const location = this.userNeeds.preferredLocation.trim().toLowerCase();
            // Search in city, street, and title columns
            query = query.or(`city.ilike.*${location}*,street.ilike.*${location}*,title.ilike.*${location}*`);
            appliedFilters.push(`location contains: ${location}`);
            hasSpecificCriteria = true;
            console.log(`✅ Step 2: Location filter applied - searching for "${location}" in city/street/title columns`);
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
        
        if (this.negotiationEngine) {
            this.sendMessage(listing);
        } else {
            this.sendBasicMessage(listing);
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
                // Display listings based on your actual database schema
                const titleText = listing.title || 'Untitled Property';
                const cityText = listing.city || 'City not specified';
                const streetText = listing.street ? ` - ${listing.street}` : '';
                const priceText = listing.price ? ` - $${listing.price}` : '';
                const typeText = listing.house_type ? ` (${listing.house_type})` : '';
                this.appendMessage('AI', `🏠 ${titleText} - ${cityText}${streetText}${priceText}${typeText}`, 'left');
            }
            
            // Ask if user wants to negotiate
            this.appendMessage('AI', 'Would you like me to help you negotiate with any of these landlords? I can send professional messages on your behalf using market data and negotiation strategies!', 'left');
            
            // Set pending response context so "yes" will trigger negotiations
            this.pendingUserResponse = 'negotiate_offer';
            
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

    // Check if the message is a negotiation response (yes, sure, etc.)
    checkForNegotiationResponse(message) {
        console.log('🔍 [NEGOTIATION CHECK] Starting check for message:', message);
        const cleanMessage = message.toLowerCase().trim();
        
        // First check: Do we have any active conversations waiting for user response?
        const hasActiveContext = this.pendingUserResponse !== null || this.activeConversations.size > 0;
        
        if (hasActiveContext) {
            console.log('🔍 [NEGOTIATION CHECK] Has active context, checking responses...');
            
            // Check for affirmative responses
            const affirmativeResponses = ['yes', 'sure', 'ok', 'okay', 'please', 'go ahead', 'proceed', 'contact them', 'negotiate', 'send message'];
            const isAffirmative = affirmativeResponses.some(response => cleanMessage.includes(response));
            
            if (isAffirmative && this.matchingListings.length > 0) {
                console.log('✅ [NEGOTIATION CHECK] Affirmative response detected, starting negotiations');
                this.appendMessage('AI', '🤖 Great! I\'ll contact the landlords for you using smart negotiation strategies...', 'left');
                
                // Clear pending response
                this.pendingUserResponse = null;
                
                // Start negotiations for all matching listings
                setTimeout(() => this.startNegotiationsForAllListings(), 1000);
                return true;
            }
        }
        
        // Check for direct negotiation requests about specific listings
        const negotiationKeywords = ['negotiate', 'contact', 'message', 'talk to landlord', 'reach out'];
        const hasNegotiationKeyword = negotiationKeywords.some(keyword => cleanMessage.includes(keyword));
        
        if (hasNegotiationKeyword && this.matchingListings.length > 0) {
            console.log('✅ [NEGOTIATION CHECK] Direct negotiation request detected');
            this.appendMessage('AI', '🤖 I\'ll help you negotiate with the landlords. Starting contact now...', 'left');
            setTimeout(() => this.startNegotiationsForAllListings(), 1000);
            return true;
        }
        
        console.log('❌ [NEGOTIATION CHECK] No negotiation response detected');
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

    // Start negotiation for a specific listing
    async startNegotiationForListing(listing) {
        try {
            this.appendMessage('AI', `📤 Sending negotiation message for listing ${listing.id}...`, 'left');
            
            // Prepare request data
            const requestData = {
                message: `I'm interested in listing ${listing.id} - ${listing.title || 'Property'} in ${listing.city || listing.street}. Please help me negotiate a good deal.`,
                conversationHistory: this.conversationHistory.slice(-5),
                userEmail: this.currentUser?.email,
                listingData: listing
            };
            
            console.log('📤 AI Negotiate Request Details:');
            console.log('- URL:', '/api/ai-negotiate');
            console.log('- Method:', 'POST');
            console.log('- Request Data:', requestData);
            console.log('- User Email:', this.currentUser?.email);
            console.log('- Listing ID:', listing.id);
            console.log('- Message Length:', requestData.message.length);
            console.log('- Conversation History Length:', requestData.conversationHistory.length);
            
            // Call the AI negotiation API
            const response = await fetch('/api/ai-negotiate', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(requestData)
            });

            console.log('🔍 AI Negotiate Response Details:');
            console.log('- Status:', response.status);
            console.log('- Status Text:', response.statusText);
            console.log('- Headers:', Object.fromEntries(response.headers.entries()));
            
            if (response.ok) {
                const data = await response.json();
                console.log('✅ Success Response:', data);
                this.appendMessage('AI', `✅ Negotiation initiated for listing ${listing.id}`, 'left');
                this.appendMessage('AI', data.response, 'left');
            } else {
                // Try to get error details from response
                let errorDetails = 'No additional details';
                try {
                    const errorData = await response.json();
                    console.error('❌ Server Error Response:', errorData);
                    errorDetails = errorData.error || errorData.details || JSON.stringify(errorData);
                } catch (e) {
                    console.error('❌ Could not parse error response as JSON');
                    const textResponse = await response.text().catch(() => 'Could not read response');
                    console.error('❌ Raw error response:', textResponse);
                    errorDetails = textResponse;
                }
                
                this.appendMessage('AI', `❌ Failed to initiate negotiation for listing ${listing.id}`, 'left');
                this.appendMessage('AI', `Error: ${errorDetails}`, 'left');
                console.error('❌ Full error context:', {
                    status: response.status,
                    statusText: response.statusText,
                    errorDetails: errorDetails
                });
            }
        } catch (error) {
            console.error('Negotiation error:', error);
            this.appendMessage('AI', `❌ Error negotiating for listing ${listing.id}: ${error.message}`, 'left');
        }
    }

    // Load conversation history from Supabase
    async loadConversationHistory() {
        if (!this.currentUser?.email || !this.supabase) {
            console.log('Cannot load history: no user or supabase');
            return;
        }

        try {
            // Load from Supabase ai_chat_history table
            const { data, error } = await this.supabase
                .from('ai_chat_history')
                .select('conversation_data, updated_at')
                .eq('user_email', this.currentUser.email)
                .order('updated_at', { ascending: false })
                .limit(1)
                .maybeSingle();

            if (error) {
                console.log('Error loading chat history:', error.message);
                return;
            }

            if (data && data.conversation_data) {
                this.conversationHistory = JSON.parse(data.conversation_data);
                console.log(`📂 Loaded ${this.conversationHistory.length} messages from history`);

                // Display loaded messages
                this.conversationHistory.forEach(msg => {
                    if (msg.role === 'user') {
                        this.appendMessage('You', msg.content, 'right');
                    } else {
                        this.appendMessage('AI', msg.content, 'left');
                    }
                });
            }
        } catch (error) {
            console.error('Error loading conversation history:', error);
        }
    }

    // Save conversation history to Supabase
    async saveConversationHistory() {
        if (!this.currentUser?.email || !this.supabase) {
            console.log('Cannot save history: no user or supabase');
            return;
        }

        try {
            const conversationData = JSON.stringify(this.conversationHistory);

            // Upsert to Supabase
            const { error } = await this.supabase
                .from('ai_chat_history')
                .upsert({
                    user_email: this.currentUser.email,
                    conversation_data: conversationData,
                    updated_at: new Date().toISOString()
                }, {
                    onConflict: 'user_email'
                });

            if (error) {
                console.error('Error saving chat history:', error.message);
            } else {
                console.log('✅ Chat history saved successfully');
            }
        } catch (error) {
            console.error('Error saving conversation history:', error);
        }
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
        messageDiv.className = `chat-bubble ${sender.toLowerCase()}`;
        
        if (sender.toLowerCase() === 'ai') {
            messageDiv.innerHTML = `
                <div class="font-semibold text-sm text-gray-500 mb-1">AI Assistant</div>
                <p>${message}</p>
            `;
        } else {
            messageDiv.innerHTML = `
                <div class="font-semibold text-sm text-blue-200 mb-1">You</div>
                <p>${message}</p>
            `;
        }
        
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

    // Remove typing indicator
    removeTypingIndicator() {
        const typingIndicator = document.getElementById('typing-indicator');
        if (typingIndicator) typingIndicator.remove();
    }
}

// Make the class globally available
window.AIChatHandler = AIChatHandler;