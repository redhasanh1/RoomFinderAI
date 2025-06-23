// AI Chat functionality for the negotiator
// This handles all the messaging, search, and negotiation logic

class AINegotiator {
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
    init(currentUser) {
        this.currentUser = currentUser;
        this.setupAIUser();
        this.appendMessage('AI', 'Hello! I\'m your AI Negotiator. Tell me what you\'re looking for (e.g., "I need a 2-bedroom apartment under $1500 in Toronto") and I\'ll find matching listings and negotiate with landlords for you automatically using market data!', 'left');
    }

    // Set negotiation engine
    setNegotiationEngine(engine) {
        this.negotiationEngine = engine;
        console.log('🔗 Negotiation engine connected to AI chat');
    }

    // Append message to chat
    appendMessage(sender, message, align, isTypingIndicator = false) {
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
        if (!isTypingIndicator) this.conversationHistory.push({ role: sender.toLowerCase(), content: message });
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
            const manualResult = this.extractManually(message);
            console.log('🔧 Manual extraction result:', manualResult);
            return manualResult;
        }
    }

    // Extract using OpenAI
    async extractWithOpenAI(message) {
        const prompt = `
        Extract rental property information from: "${message}"
        
        EXTRACTION TARGETS (matching database columns):
        - price: Maximum budget (number only)
        - city: City name (e.g., "paris", "tehran", "toronto", "moscow") 
        - house_type: Property type ("Apartment", "Condo", "House", "Studio", "Basement")
        - bedrooms: Number of bedrooms (1-5)
        - utilities: "included" or "not included"
        - intent: "search" or "general"
        
        RULES:
        - For price: look for "under $1200", "max $2000", etc.
        - For city: extract ANY city mentioned and return lowercase: "paris", "tehran", "toronto", "moscow"
        - For house_type: use exact values from database
        - Be conservative - only extract what's clearly mentioned
        
        Return JSON with only fields that have values:
        `;
        
        const response = await fetch('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.config.OPENAI_API_KEY}`,
                'OpenAI-Organization': this.config.OPENAI_ORG_ID
            },
            body: JSON.stringify({
                model: this.config.OPENAI_MODEL || 'gpt-3.5-turbo',
                messages: [{ role: 'system', content: prompt }],
                max_tokens: 200,
                temperature: 0.3
            })
        });
        
        if (!response.ok) {
            throw new Error(`OpenAI API error: ${response.status}`);
        }
        
        const data = await response.json();
        const result = JSON.parse(data.choices[0].message.content.trim());
        
        // Clean city data if present
        if (result.city) {
            result.city = result.city.toString().trim().split(',')[0].trim();
            result.city = result.city.replace(/\s+(fr|france|canada|ca|usa|us|australia|au)$/i, '');
        }
        
        return result;
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
        
        // Extract city - UPDATED LIST based on actual database listings
        const cityMatch = message.match(/\b(paris|tehran|toronto|moscow|sydney|vancouver|montreal|calgary|ottawa|edmonton|winnipeg|hamilton|quebec|saskatoon|regina|halifax|london|kitchener|waterloo|windsor|markham|mississauga|brampton|iran|australia|canada|france|new york|los angeles|chicago|miami|boston)\b/i);
        if (cityMatch) {
            result.city = cityMatch[1].toLowerCase().trim();
            console.log('🏙️ Extracted city:', result.city);
        }
        
        // Additional location patterns for "in [city]"
        const inCityMatch = message.match(/\bin\s+(paris|tehran|toronto|moscow|sydney|vancouver|montreal|calgary)\b/i);
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
            message.toLowerCase().includes('want')) {
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
        
        let query = this.supabase.from('listings').select('id, title, price, house_type, bedrooms, utilities, description, user_email, city');
        let appliedFilters = [];
        let hasSpecificCriteria = false;
        
        // Exclude user's own listings
        if (this.currentUser?.email) {
            query = query.neq('user_email', this.currentUser.email);
        }
        
        // Price filter - include listings AT the max price
        if (this.userNeeds.maxPrice) {
            query = query.lte('price', this.userNeeds.maxPrice);
            appliedFilters.push(`price up to $${this.userNeeds.maxPrice} (inclusive)`);
            hasSpecificCriteria = true;
        }
        
        // Location filter - STRICT (search in title, description, AND city)
        if (this.userNeeds.preferredLocation) {
            console.log(`🔍 STRICT search for location "${this.userNeeds.preferredLocation}" in title, description, and city`);
            const location = this.userNeeds.preferredLocation.trim();
            
            // First try exact city match, then fallback to any field containing the location
            // Also search for country codes (since cities in DB may be like "france" instead of "paris")
            let locationQuery;
            if (location === 'paris') {
                locationQuery = `city.ilike.%france%,city.ilike.%paris%,title.ilike.%${location}%,description.ilike.%${location}%`;
            } else if (location === 'tehran') {
                locationQuery = `city.ilike.%iran%,city.ilike.%tehran%,title.ilike.%${location}%,description.ilike.%${location}%`;
            } else if (location === 'moscow') {
                locationQuery = `city.ilike.%russia%,city.ilike.%moscow%,title.ilike.%${location}%,description.ilike.%${location}%`;
            } else if (location === 'toronto') {
                locationQuery = `city.ilike.%canada%,city.ilike.%toronto%,title.ilike.%${location}%,description.ilike.%${location}%`;
            } else {
                locationQuery = `city.ilike.%${location}%,title.ilike.%${location}%,description.ilike.%${location}%`;
            }
            
            query = query.or(locationQuery);
            appliedFilters.push(`location: ${location} (searching city/title/description)`);
            hasSpecificCriteria = true;
            
            console.log(`📍 Location filter applied: ${locationQuery}`);
        } else {
            console.log('❌ NO LOCATION EXTRACTED - searching all locations');
        }
        
        // House type filter
        if (this.userNeeds.houseType) {
            query = query.eq('house_type', this.userNeeds.houseType);
            appliedFilters.push(`house type: ${this.userNeeds.houseType}`);
            hasSpecificCriteria = true;
        }
        
        // Bedroom filter
        if (this.userNeeds.bedrooms) {
            query = query.eq('bedrooms', this.userNeeds.bedrooms);
            appliedFilters.push(`bedrooms: ${this.userNeeds.bedrooms}`);
            hasSpecificCriteria = true;
        }
        
        if (!hasSpecificCriteria) {
            throw new Error('Please provide specific criteria (location, house type, price, etc.)');
        }
        
        console.log('🔍 Applied filters:', appliedFilters.join(', '));
        console.log('🔎 User needs for debugging:', this.userNeeds);
        
        const { data: listings, error } = await query.order('created_at', { ascending: false }).limit(20);
        
        if (error) {
            throw new Error(`Database query failed: ${error.message}`);
        }
        
        console.log('📊 Query results:', listings?.length || 0, 'listings found');
        
        // Debug: Log what we actually found
        if (listings && listings.length > 0) {
            console.log('🏠 Found listings details:');
            listings.forEach((listing, i) => {
                console.log(`  ${i+1}. "${listing.title}" - $${listing.price} - ${listing.house_type} - City: "${listing.city || 'NO CITY'}" - ID: ${listing.id}`);
            });
        } else {
            console.log('❌ No listings found with current filters');
            
            // Let's also check what's actually in the database
            const { data: allListings } = await this.supabase
                .from('listings')
                .select('title, city, price, house_type')
                .limit(10);
            
            console.log('🗃️ Sample of ALL listings in database:');
            allListings?.forEach((listing, i) => {
                console.log(`  ${i+1}. "${listing.title}" - City: "${listing.city || 'NO CITY'}" - $${listing.price} - ${listing.house_type}`);
            });
        }
        
        return listings || [];
    }

    // Test function to verify search works for known listings
    async testSearchForKnownListings() {
        console.log('🧪 TESTING SEARCH FOR KNOWN LISTINGS');
        
        const testCases = [
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
                this.appendMessage('AI', `🏠 "${listing.title}" - $${listing.price}/month (${bedText} ${typeText})${utilitiesText}`, 'left');
            }
            
            // Filter valid listings and message owners
            const validListings = this.matchingListings.filter(listing => listing.user_email && listing.id);
            
            if (validListings.length === 0) {
                this.appendMessage('AI', 'Found listings, but none have valid owner emails for messaging.', 'left');
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
                query = query.eq('house_type', this.userNeeds.houseType);
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
                this.appendMessage('AI', `📋 "${listing.title}" - $${listing.price}/month (${listing.bedrooms} bed ${listing.house_type})${locationText} - ${descText}`, 'left');
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
            return await this.sendBasicMessage(listing);
        }
    }

    // Fallback basic message
    async sendBasicMessage(listing) {
        try {
            const conversation = await this.getOrCreateConversation(listing);
            if (!conversation) return false;

            const basicMessage = `Hi! I'm interested in your ${listing.house_type || 'property'} "${listing.title}". ${this.userNeeds.maxPrice ? `My budget is around $${this.userNeeds.maxPrice}.` : ''} I'm a qualified tenant ready to move quickly. Are you open to discussing the terms?`;

            const { error } = await this.supabase
                .from('messages')
                .insert({
                    conversation_id: conversation.id,
                    sender_email: this.currentUser.email,
                    content: basicMessage
                });

            return !error;
        } catch (error) {
            console.error('Basic message send error:', error);
            return false;
        }
    }

    // Get or create conversation
    async getOrCreateConversation(listing) {
        try {
            // Check if conversation already exists
            const { data: existingConv } = await this.supabase
                .from('conversations')
                .select('*')
                .eq('listing_id', listing.id)
                .eq('user_email', this.currentUser.email)
                .single();

            if (existingConv) {
                return existingConv;
            }

            // Create new conversation
            const { data: newConv, error } = await this.supabase
                .from('conversations')
                .insert({
                    listing_id: listing.id,
                    user_email: this.currentUser.email,
                    landlord_email: listing.user_email,
                    sender_email: this.currentUser.email
                })
                .select()
                .single();

            if (error) {
                console.error('Error creating conversation:', error);
                return null;
            }

            return newConv;
        } catch (error) {
            console.error('Error in getOrCreateConversation:', error);
            return null;
        }
    }

    // Setup AI user account
    async setupAIUser() {
        // Implementation would go here
        console.log('AI user setup...');
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
        
        // Extract requirements
        const extractedData = await this.extractRentalInfo(message);
        console.log('📊 Raw extracted data:', extractedData);
        this.updateUserNeeds(extractedData);
        console.log('🎯 Final user needs after update:', this.userNeeds);
        console.log('🔍 Location that will be used in search:', this.userNeeds.preferredLocation);
        
        this.removeTypingIndicator();
        
        // Check if user is expressing needs
        const needsKeywords = ['looking for', 'need', 'want', 'searching for', 'find me'];
        const isSearchRequest = needsKeywords.some(keyword => message.toLowerCase().includes(keyword));
        
        if (isSearchRequest && extractedData.intent === 'search') {
            this.appendMessage('AI', 'I understand! Searching for matching listings and contacting landlords...', 'left');
            setTimeout(() => this.searchAndMessage(), 1000);
        } else {
            this.appendMessage('AI', 'I understand your preferences. To search for listings, try saying something like "I need a 2-bedroom apartment under $1500 in Toronto"', 'left');
        }
    }
}

// Export for use in HTML
window.AINegotiator = AINegotiator;