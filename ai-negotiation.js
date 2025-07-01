// AI Negotiation Engine
// Handles real-time negotiation with landlords using market data and OpenAI

// Note: AILearningSystem temporarily disabled for browser compatibility
// const AILearningSystem = require('./ai-learning');

class AINegotiationEngine {
    constructor(supabase, config) {
        this.supabase = supabase;
        this.config = config;
        this.activeNegotiations = new Map(); // Track ongoing negotiations
        this.marketData = new Map(); // Cache market data
        this.aiUserInitialized = false;
        this.conversationalMemory = new Map(); // Track used responses per negotiation
        this.responseTemplates = this.initializeResponseTemplates();
        
        // Initialize AI Learning System
        // this.learningSystem = new AILearningSystem(this.supabase);
        this.learningSystem = this.initializeLearningSystem();
        this.learningEnabled = true;
        
        // Validate OpenAI configuration
        this.validateOpenAIConfig();
        
        this.init();
    }

    // Initialize response templates for variety
    initializeResponseTemplates() {
        return {
            counterOfferAcceptance: [
                "That works perfectly for me! $${price}/month sounds excellent.",
                "I accept your offer of $${price}/month. Great doing business with you!",
                "Perfect! $${price}/month is exactly what I was hoping for.",
                "Excellent! I'm very happy to agree to $${price}/month.",
                "Wonderful! $${price}/month works great for me.",
                "That's a deal! $${price}/month it is.",
                "I'm delighted to accept $${price}/month.",
                "Outstanding! $${price}/month is perfect."
            ],
            strategicCounterOffers: [
                "I appreciate your counter-offer. How about we meet at $${price}/month?",
                "That's getting closer! Would you consider $${price}/month?",
                "I understand your position. I can do $${price}/month with excellent references.",
                "Let's find middle ground - how does $${price}/month sound?",
                "I'm flexible - would $${price}/month work for you?",
                "I can stretch to $${price}/month for the right place.",
                "How about $${price}/month with immediate move-in?",
                "I could do $${price}/month if we can finalize quickly."
            ],
            marketBasedResponses: [
                "Based on comparable properties, $${price}/month reflects fair market value.",
                "Market data shows similar places at $${price}/month - would that work?",
                "Given the current market, I can offer $${price}/month.",
                "Research indicates $${price}/month is appropriate for this type of property.",
                "Considering market rates, $${price}/month seems reasonable.",
                "Market analysis supports $${price}/month for this location."
            ],
            valuePropositions: [
                "At $${price}/month, you get an excellent tenant with pristine references.",
                "For $${price}/month, I guarantee reliable rent and property care.",
                "I offer $${price}/month plus exceptional tenant qualities.",
                "$${price}/month with a long-term, responsible tenant like me is a great deal.",
                "At $${price}/month, you're getting reliability and peace of mind."
            ],
            meetingCoordination: [
                "Perfect! Tonight works excellently for me. What time should we meet? I'll bring all necessary documentation.",
                "Fantastic! I'm available after 6 PM tonight. Should we meet at the property? I have all my paperwork ready.",
                "Wonderful! Tonight is ideal. What time works best for you? I can bring references, ID, and first month's rent.",
                "Excellent! I'm free this evening. Would you prefer to meet at the property or another location?",
                "Great! Tonight sounds perfect. I'm available anytime after 5 PM. What would be most convenient for you?",
                "Outstanding! I can meet tonight. Should I bring the first month's rent and security deposit?",
                "Perfect timing! I'm ready to finalize everything tonight. What documents do you need me to bring?",
                "Excellent! Tonight works wonderfully. I have all required paperwork ready. What time shall we meet?"
            ],
            documentPreparation: [
                "I'll bring all necessary documents including references, employment verification, and ID.",
                "I have everything ready: references, proof of income, first month's rent, and security deposit.",
                "I can provide employment verification, previous landlord references, and credit information.",
                "I'll come prepared with ID, references, financial documentation, and payment.",
                "I have all required paperwork: rental application, references, and financial proof.",
                "I'll bring comprehensive documentation including background check and employment letter."
            ],
            securityDepositResponses: [
                "Absolutely! For a $${price}/month rental, I'm prepared to provide a security deposit. The standard amount is typically one month's rent ($${price}). I can transfer this immediately along with the first month's rent.",
                "Perfect! I'm ready to provide the security deposit right away. Is one month's rent ($${price}) the amount you require? I can handle the transfer today.",
                "Of course! I have the security deposit ready. Should we do one month's rent ($${price}) as is standard? I can send it via wire transfer or certified check immediately.",
                "Excellent! I'm prepared for the security deposit. Is $${price} (one month's rent) the correct amount? I can arrange payment today along with first month's rent.",
                "Absolutely! I have the security deposit funds ready. Is the standard one month ($${price}) what you need? I can process the payment immediately.",
                "Perfect! I'm ready with the security deposit. Should I prepare $${price} for the deposit? I can transfer both first month and security deposit today."
            ],
            moveInLogistics: [
                "Great! Tomorrow night works perfectly for me. What time should I arrive? I'll have all my documents and payments ready.",
                "Wonderful! I can move in tomorrow evening. What time works best for you? Should I bring anything specific?",
                "Perfect timing! Tomorrow night is ideal. What time should we coordinate for key exchange and final walkthrough?",
                "Excellent! I'm ready to move in tomorrow night. What time would be convenient for you? I'll bring all required documentation.",
                "Outstanding! Tomorrow evening works great. What time should I plan to arrive? I have everything prepared.",
                "Fantastic! Tomorrow night is perfect for move-in. What time should we meet? I'll bring all necessary paperwork and payments."
            ]
        };
    }

    // Initialize simple learning system for browser compatibility
    initializeLearningSystem() {
        return {
            // Track successful negotiation patterns
            successfulPatterns: new Map(),
            failedPatterns: new Map(),
            
            // Learn from negotiation outcome
            learnFromOutcome: (negotiationData, outcome) => {
                const pattern = {
                    propertyType: negotiationData.listing?.house_type,
                    location: negotiationData.listing?.city,
                    priceRange: Math.floor((negotiationData.originalPrice || 1500) / 500) * 500,
                    discountOffered: negotiationData.originalPrice ? 
                        ((negotiationData.originalPrice - (negotiationData.finalPrice || negotiationData.originalPrice)) / negotiationData.originalPrice) : 0,
                    messageStyle: negotiationData.messageStyle || 'balanced',
                    responseTime: negotiationData.responseTime || 'normal'
                };
                
                const patternKey = `${pattern.propertyType}_${pattern.location}_${pattern.priceRange}`;
                
                if (outcome.success) {
                    console.log('📚 Learning: Success pattern recorded for', patternKey);
                    this.successfulPatterns.set(patternKey, {
                        ...pattern,
                        successCount: (this.successfulPatterns.get(patternKey)?.successCount || 0) + 1,
                        lastSuccess: new Date()
                    });
                } else {
                    console.log('📚 Learning: Failed pattern recorded for', patternKey);
                    this.failedPatterns.set(patternKey, {
                        ...pattern,
                        failCount: (this.failedPatterns.get(patternKey)?.failCount || 0) + 1,
                        lastFail: new Date()
                    });
                }
            },
            
            // Get optimal strategy based on learned patterns
            getOptimalStrategy: (listing, userBudget) => {
                const patternKey = `${listing.house_type}_${listing.city}_${Math.floor((listing.price || 1500) / 500) * 500}`;
                const successPattern = this.successfulPatterns.get(patternKey);
                const failPattern = this.failedPatterns.get(patternKey);
                
                if (successPattern && successPattern.successCount > 0) {
                    console.log('📚 Learning: Using successful pattern for', patternKey);
                    return {
                        recommendedDiscount: successPattern.discountOffered,
                        messageStyle: successPattern.messageStyle,
                        confidence: Math.min(successPattern.successCount / 5, 1.0)
                    };
                } else if (failPattern) {
                    console.log('📚 Learning: Avoiding failed pattern for', patternKey);
                    return {
                        recommendedDiscount: Math.max(0.05, failPattern.discountOffered - 0.02),
                        messageStyle: failPattern.messageStyle === 'aggressive' ? 'balanced' : 'professional',
                        confidence: 0.3
                    };
                }
                
                // Default strategy for new patterns
                return {
                    recommendedDiscount: 0.05,
                    messageStyle: 'balanced',
                    confidence: 0.1
                };
            }
        };
    }

    // Get AI learning insights for personalized negotiation
    async getLearningInsights(listing, userBudget) {
        try {
            if (!this.learningEnabled || !this.learningSystem) {
                return this.getDefaultLearningInsights();
            }

            // Use the new learning system to get optimal strategy
            const strategy = this.learningSystem.getOptimalStrategy(listing, userBudget);
            
            return {
                successfulStrategies: `Recommended discount: ${(strategy.recommendedDiscount * 100).toFixed(1)}% (confidence: ${(strategy.confidence * 100).toFixed(0)}%)`,
                optimalTiming: strategy.messageStyle === 'aggressive' ? 'Fast response' : 'Measured approach',
                valueProps: strategy.messageStyle === 'professional' ? 'Professional credentials' : 'Personal connection',
                landlordBehavior: `Pattern confidence: ${(strategy.confidence * 100).toFixed(0)}%`
            };
        } catch (error) {
            console.error('Error getting learning insights:', error);
            return this.getDefaultLearningInsights();
        }
    }

    // Learn from negotiation outcome
    learnFromNegotiation(negotiation, outcome) {
        if (!this.learningEnabled || !this.learningSystem) {
            return;
        }

        try {
            // Prepare negotiation data for learning
            const learningData = {
                listing: {
                    house_type: negotiation.listing?.house_type || 'Unknown',
                    city: negotiation.listing?.city || 'Unknown'
                },
                originalPrice: negotiation.originalPrice,
                finalPrice: outcome.finalPrice || negotiation.finalPrice,
                messageStyle: negotiation.messageStyle || 'balanced',
                responseTime: 'normal' // Could be enhanced to track actual timing
            };

            // Let the learning system learn from this outcome
            this.learningSystem.learnFromOutcome(learningData, outcome);
            
            console.log('📚 Learning system updated with negotiation outcome');
        } catch (error) {
            console.error('Error learning from negotiation:', error);
        }
    }

    // Get contextual learning from similar properties
    async getContextualLearning(propertyType, city) {
        try {
            const { data: contextData, error } = await this.supabase
                .from('ai_chats')
                .select('conversation_data, metadata')
                .eq('metadata->dealClosed', true)
                .ilike('listing_type', `%${propertyType}%`)
                .ilike('listing_location', `%${city}%`)
                .limit(15);

            if (error) {
                return this.getDefaultContextualLearning();
            }

            return {
                similarNegotiations: `${contextData?.length || 0} successful deals in similar properties`,
                locationStrategies: this.extractLocationStrategies(contextData),
                propertyTypeStrategies: this.extractPropertyTypeStrategies(contextData)
            };
        } catch (error) {
            console.error('Error getting contextual learning:', error);
            return this.getDefaultContextualLearning();
        }
    }

    // Analyze successful negotiation strategies
    analyzeSuccessfulStrategies(negotiations) {
        if (!negotiations || negotiations.length === 0) {
            return 'Market-based pricing with value emphasis';
        }

        const strategies = negotiations.map(n => n.metadata?.strategy || 'market_based');
        const mostSuccessful = this.getMostCommon(strategies);
        
        return `${mostSuccessful} approach with ${Math.round((strategies.filter(s => s === mostSuccessful).length / strategies.length) * 100)}% success rate`;
    }

    // Analyze optimal timing patterns
    analyzeOptimalTiming(negotiations) {
        if (!negotiations || negotiations.length === 0) {
            return 'Quick response within 2-4 hours';
        }

        // Analyze response times from successful negotiations
        const avgResponseTime = negotiations.reduce((sum, n) => {
            const responseTime = n.metadata?.avgResponseTime || 180; // minutes
            return sum + responseTime;
        }, 0) / negotiations.length;

        if (avgResponseTime < 60) return 'Immediate response within 1 hour';
        if (avgResponseTime < 240) return 'Quick response within 2-4 hours';
        return 'Same-day response preferred';
    }

    // Analyze effective value propositions
    analyzeValuePropositions(negotiations) {
        if (!negotiations || negotiations.length === 0) {
            return 'Reliable tenant with references';
        }

        const valueProps = negotiations.map(n => n.metadata?.valueProposition || 'reliability');
        const topValue = this.getMostCommon(valueProps);
        
        return `${topValue} emphasis with quick decision capability`;
    }

    // Analyze landlord behavior patterns
    analyzeLandlordBehavior(negotiations) {
        if (!negotiations || negotiations.length === 0) {
            return 'Professional, price-conscious, values reliability';
        }

        const behaviors = negotiations.map(n => n.metadata?.landlordStyle || 'professional');
        const commonBehavior = this.getMostCommon(behaviors);
        
        return `Typically ${commonBehavior}, responds well to ${commonBehavior === 'professional' ? 'data-driven' : 'personal'} approaches`;
    }

    // Extract location-specific strategies
    extractLocationStrategies(contextData) {
        if (!contextData || contextData.length === 0) {
            return 'Standard market approach';
        }

        const strategies = contextData.map(d => d.metadata?.locationStrategy || 'market_comparison');
        const topStrategy = this.getMostCommon(strategies);
        
        return `${topStrategy} works best in this area`;
    }

    // Extract property type strategies
    extractPropertyTypeStrategies(contextData) {
        if (!contextData || contextData.length === 0) {
            return 'Value-based negotiation';
        }

        const strategies = contextData.map(d => d.metadata?.propertyStrategy || 'value_focus');
        const topStrategy = this.getMostCommon(strategies);
        
        return `${topStrategy} approach for this property type`;
    }

    // Get most common element in array
    getMostCommon(arr) {
        if (!arr || arr.length === 0) return 'standard';
        
        const counts = {};
        arr.forEach(item => counts[item] = (counts[item] || 0) + 1);
        
        return Object.keys(counts).reduce((a, b) => counts[a] > counts[b] ? a : b);
    }

    // Default learning insights fallback
    getDefaultLearningInsights() {
        return {
            successfulStrategies: 'Market-based pricing with value emphasis',
            optimalTiming: 'Quick response within 2-4 hours',
            valueProps: 'Reliable tenant with excellent references',
            landlordBehavior: 'Professional, responds to data-driven approaches'
        };
    }

    // Default contextual learning fallback
    getDefaultContextualLearning() {
        return {
            similarNegotiations: 'Standard market analysis',
            locationStrategies: 'Market comparison approach',
            propertyTypeStrategies: 'Value-focused negotiation'
        };
    }

    // Initialize the negotiation engine
    async init() {
        try {
            await this.ensureAIUserExists();
            this.setupMessageListener();
        } catch (error) {
            console.error('Error initializing AI negotiation engine:', error);
        }
    }

    // Ensure AI user exists in database
    async ensureAIUserExists() {
        if (this.aiUserInitialized) {
            console.log('✅ AI user already initialized, skipping check');
            return true;
        }
        
        try {
            const aiEmail = 'ai-negotiator@roomfinder.com';
            
            console.log('🔍 Checking if AI user exists...');
            
            // Check if AI user exists - use maybeSingle to avoid 406 errors
            const { data: existingUser, error: checkError } = await this.supabase
                .from('users')
                .select('id, email, first_name, last_name')
                .eq('email', aiEmail)
                .maybeSingle();

            if (checkError && !checkError.message.includes('No rows')) {
                console.log('⚠️ Error checking for existing AI user:', checkError.message);
                // Mark as initialized to avoid infinite retry
                this.aiUserInitialized = true;
                return true;
            }

            if (existingUser) {
                console.log('✅ AI user already exists:', existingUser.first_name, existingUser.last_name);
                this.aiUserInitialized = true;
                return true;
            }
            
            console.log('❌ AI user not found, creating AI user...');
            
            // Create AI user
            const { data: newUser, error: createError } = await this.supabase
                .from('users')
                .insert({
                    email: aiEmail,
                    first_name: 'AI',
                    last_name: 'Negotiator',
                    password: 'dummy-password-not-used'
                })
                .select()
                .single();

            if (createError) {
                console.error('❌ Error creating AI user:', createError);
                console.log('⚠️ Continuing without AI user - messages will use fallback email');
                this.aiUserInitialized = true;
                return true;
            }

            console.log('✅ AI user created successfully:', newUser);
            this.aiUserInitialized = true;
            return true;

        } catch (error) {
            console.error('Error ensuring AI user exists:', error);
            // Don't fail completely - continue with existing functionality
            this.aiUserInitialized = true;
            return true;
        }
    }

    // Get real market data for pricing analysis
    async getMarketData(location, houseType, bedrooms) {
        const cacheKey = `${location}-${houseType}-${bedrooms}`;
        
        // Check cache first
        if (this.marketData.has(cacheKey)) {
            console.log('📊 Using cached market data for:', cacheKey);
            return this.marketData.get(cacheKey);
        }

        try {
            console.log('🔍 Gathering market data for:', { location, houseType, bedrooms });

            // Query database for similar properties
            let query = this.supabase.from('listings').select('price, title, city, bedrooms, house_type');
            
            if (location) {
                const cleanLocation = location.trim();
                query = query.or(`city.ilike.%${cleanLocation}%,title.ilike.%${cleanLocation}%`);
            }
            if (houseType) {
                query = query.eq('house_type', houseType);
            }
            if (bedrooms) {
                query = query.eq('bedrooms', bedrooms);
            }

            const { data: listings, error } = await query.limit(50);
            
            if (error || !listings?.length) {
                console.log('⚠️ No market data found in database');
                return this.getAIMarketData(location, houseType, bedrooms);
            }

            // Calculate market statistics
            const prices = listings.map(l => l.price).filter(p => p > 0);
            const stats = {
                average: Math.round(prices.reduce((a, b) => a + b, 0) / prices.length),
                median: this.calculateMedian(prices),
                min: Math.min(...prices),
                max: Math.max(...prices),
                count: prices.length,
                listings: listings.slice(0, 5), // Sample listings
                source: 'database'
            };

            // Cache the result
            this.marketData.set(cacheKey, stats);
            console.log('📊 Market data calculated:', stats);
            
            return stats;

        } catch (error) {
            console.error('Error getting market data:', error);
            return this.getAIMarketData(location, houseType, bedrooms);
        }
    }

    // Get AI-generated market data when database data is insufficient
    async getAIMarketData(location, houseType, bedrooms) {
        try {
            console.log('🤖 Getting AI market estimates for:', { location, houseType, bedrooms });

            const prompt = `
            You are a real estate market analyst. Provide realistic rental market data for:
            - Location: ${location || 'General area'}
            - Property Type: ${houseType || 'Any'}
            - Bedrooms: ${bedrooms || 'Any'}

            Based on current market conditions, provide realistic estimates in this JSON format:
            {
                "average": 1200,
                "median": 1150,
                "min": 900,
                "max": 1500,
                "analysis": "Brief market analysis explaining the pricing",
                "negotiationTips": "Tips for negotiating in this market"
            }

            Focus on realistic prices for the specified location and property type.
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
                    max_tokens: 300,
                    temperature: 0.3
                })
            });

            if (!response.ok) {
                throw new Error(`OpenAI API error: ${response.status}`);
            }

            const data = await response.json();
            let marketData;
            
            try {
                const content = data.choices[0]?.message?.content?.trim();
                if (!content) {
                    throw new Error('No content in OpenAI market data response');
                }
                
                // Validate JSON format
                if (!content.startsWith('{') || !content.endsWith('}')) {
                    throw new Error('OpenAI market data response is not valid JSON');
                }
                
                marketData = JSON.parse(content);
                
                // Validate required market data fields
                if (!marketData.hasOwnProperty('average')) {
                    throw new Error('Market data response missing required fields');
                }
                
            } catch (parseError) {
                console.warn('⚠️ Failed to parse OpenAI market data response:', parseError.message);
                console.warn('⚠️ Raw market data content:', data.choices[0]?.message?.content);
                
                // Fallback to default market data
                marketData = {
                    average: 1500,
                    min: 1200,
                    max: 1800,
                    source: 'fallback_estimate'
                };
            }
            
            return {
                ...marketData,
                count: 0,
                source: 'ai_estimate'
            };

        } catch (error) {
            console.error('Error getting AI market data:', error);
            
            // Fallback to basic estimates
            return {
                average: 1200,
                median: 1150,
                min: 900,
                max: 1500,
                count: 0,
                source: 'fallback',
                analysis: 'Limited market data available'
            };
        }
    }

    // Calculate median price
    calculateMedian(prices) {
        const sorted = [...prices].sort((a, b) => a - b);
        const mid = Math.floor(sorted.length / 2);
        return sorted.length % 2 !== 0 ? sorted[mid] : Math.round((sorted[mid - 1] + sorted[mid]) / 2);
    }

    // Enhanced negotiation message generation with conversation memory and learning
    async generateNegotiationMessage(listing, userBudget, marketData, conversationHistory = []) {
        try {
            console.log('🤖 Generating enhanced negotiation message for:', listing.title);

            // Get AI learning insights for this user and property type
            const learningInsights = await this.getLearningInsights(listing, userBudget);
            
            // Build conversation context from previous successful negotiations
            const contextualLearning = await this.getContextualLearning(listing.house_type, listing.city);

            const enhancedPrompt = `
            Write a friendly, natural message from a prospective tenant to a landlord. Be casual and human-like:

            Property: ${listing.title} - $${listing.price}/month
            Budget: $${userBudget}

            Write a short message (1-2 sentences) expressing interest. If budget is lower than asking price, make a reasonable offer. Be friendly and mention being a qualified tenant ready to move quickly.

            Example style: "Hi! I'm interested in your apartment. I'm a qualified tenant with good references and can move in quickly. Would you consider $X/month?"
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
                    messages: [
                        { 
                            role: 'system', 
                            content: enhancedPrompt 
                        },
                        {
                            role: 'user',
                            content: `Property: ${listing.title} - $${listing.price}/month. Budget: $${userBudget}`
                        }
                    ],
                    max_tokens: 50,
                    temperature: 0.7,
                    top_p: 0.9,
                    frequency_penalty: 0.3,
                    presence_penalty: 0.2
                })
            });

            if (!response.ok) {
                throw new Error(`OpenAI API error: ${response.status}`);
            }

            const data = await response.json();
            const message = data.choices[0].message.content.trim();
            
            console.log('✅ Generated negotiation message');
            return message;

        } catch (error) {
            console.error('Error generating negotiation message:', error);
            
            // Fallback message
            const suggestion = listing.price > marketData.average ? 
                `Would you consider $${Math.round(marketData.average * 0.95)} based on current market rates?` :
                'Are you open to any flexibility on the rent?';
            
            return `Hi! I'm very interested in your ${listing.house_type} "${listing.title}". I'm a qualified tenant ready to move quickly. ${suggestion}`;
        }
    }

    // Handle incoming replies and continue negotiation
    async handleNegotiationReply(message, conversationId, listing) {
        try {
            console.log('💬 Handling negotiation reply from:', message.sender_email);
            console.log('💬 Message content:', message.content);
            console.log('💬 Conversation ID:', conversationId);
            console.log('💬 Listing:', listing.title);

            // Find negotiation by conversation ID or create if from landlord direct reply
            let negotiation = this.activeNegotiations.get(conversationId);
            
            if (!negotiation) {
                // Check if this is a landlord replying to an initial AI message
                // Look for active negotiations with this listing
                for (const [key, neg] of this.activeNegotiations.entries()) {
                    if (neg.listingId === listing.id && neg.landlordEmail === message.sender_email) {
                        negotiation = neg;
                        // Update the conversation ID mapping
                        this.activeNegotiations.delete(key);
                        this.activeNegotiations.set(conversationId, negotiation);
                        break;
                    }
                }
            }

            if (!negotiation) {
                console.log('⚠️ No active negotiation found, creating new one');
                
                // Try to get user email from conversation
                let userEmail = 'user@example.com'; // Default fallback
                try {
                    const { data: conversation, error: convError } = await this.supabase
                        .from('conversations')
                        .select('sender_email, receiver_email')
                        .eq('id', conversationId)
                        .maybeSingle();
                    
                    if (convError) {
                        console.log('Error fetching conversation:', convError.message);
                    } else if (conversation) {
                        // Determine which email is the user (not the AI)
                        if (conversation.sender_email !== 'ai-negotiator@roomfinder.com') {
                            userEmail = conversation.sender_email;
                        } else if (conversation.receiver_email !== 'ai-negotiator@roomfinder.com') {
                            userEmail = conversation.receiver_email;
                        }
                    }
                } catch (error) {
                    console.log('Could not fetch conversation details, using default email');
                }
                
                // Extract user budget from conversation history
                // Start with a realistic default based on listing price (85% of asking price - 15% discount max)
                let userBudget = listing.price ? Math.round(listing.price * 0.85) : 1500;
                try {
                    // Get conversation messages to find AI's initial offer
                    const { data: messages, error: msgError } = await this.supabase
                        .from('messages')
                        .select('content, sender_email')
                        .eq('conversation_id', conversationId)
                        .order('created_at', { ascending: true });
                    
                    if (!msgError && messages) {
                        // Look for AI messages with price mentions
                        for (const msg of messages) {
                            if (msg.sender_email === 'ai-negotiator@roomfinder.com' && msg.content) {
                                const extractedPrice = this.extractPriceFromMessage(msg.content);
                                if (extractedPrice && extractedPrice > 0) {
                                    userBudget = extractedPrice;
                                    console.log(`✅ Extracted userBudget from AI message: $${userBudget}`);
                                    break;
                                }
                            }
                        }
                    }
                } catch (error) {
                    console.log('Could not extract budget from conversation history, using default');
                }
                
                // Ensure budget is never less than 85% of listing price (15% discount max)
                if (listing.price && listing.price > 0) {
                    const minBudget = Math.round(listing.price * 0.85);
                    if (userBudget < minBudget) {
                        userBudget = minBudget;
                        console.log(`✅ Adjusted userBudget to minimum 85% of listing price: $${userBudget}`);
                    }
                }
                
                // Create new negotiation state from this reply
                negotiation = {
                    listingId: listing.id,
                    listingTitle: listing.title,
                    originalPrice: listing.price,
                    userBudget: userBudget,
                    userEmail: userEmail,
                    landlordEmail: listing.user_email,
                    status: 'active',
                    startTime: new Date(),
                    messages: []
                };
                this.activeNegotiations.set(conversationId, negotiation);
            }

            // Analyze the landlord's reply
            const analysis = await this.analyzeReply(message.content, negotiation, listing);
            
            console.log('📊 Reply analysis:', analysis);

            // Update negotiation state
            negotiation.messages.push({
                sender: 'landlord',
                content: message.content,
                timestamp: new Date(),
                analysis: analysis
            });

            // Always notify user about landlord's reply first
            await this.notifyLandlordReply(negotiation, message.content);
            
            // Also directly update the AI chat if it's available
            try {
                if (typeof window !== 'undefined' && window.aiNegotiator) {
                    window.aiNegotiator.appendMessage('AI', `💬 **Landlord Reply**: "${message.content}" - Processing response...`, 'left');
                }
            } catch (error) {
                console.log('Could not directly update AI chat:', error.message);
            }

            // Generate response if needed
            if (analysis.shouldRespond) {
                console.log('🚀 Generating response based on analysis:', analysis);
                const response = await this.generateCounterResponse(analysis, negotiation, listing);
                
                if (response) {
                    console.log('📝 Generated response:', response);
                    
                    // Wait a bit to simulate thinking time
                    await new Promise(resolve => setTimeout(resolve, 2000));
                    
                    // Check for duplicates before sending
                    if (this.isRecentDuplicate(response, negotiation)) {
                        console.log('🚫 Duplicate response detected, generating alternative...');
                        // Generate alternative response with different strategy
                        response = await this.generateAlternativeResponse(analysis, negotiation, listing);
                    }
                    
                    // Send the response
                    console.log('📤 Sending response to conversation:', conversationId);
                    const sentSuccessfully = await this.sendNegotiationMessage(conversationId, response, negotiation.userEmail);
                    
                    if (sentSuccessfully) {
                        console.log('✅ Response sent successfully');
                        
                        // Update negotiation state
                        negotiation.messages.push({
                            sender: 'ai',
                            content: response,
                            timestamp: new Date()
                        });

                        // Check if negotiation is complete
                        if (analysis.isFinalized) {
                            negotiation.status = 'finalized';
                            let finalPrice = analysis.agreedPrice || this.extractLastOfferedPrice(negotiation);
                            
                            // CRITICAL: Ensure finalPrice is never null/undefined/0
                            if (!finalPrice || finalPrice <= 0) {
                                console.error('❌ CRITICAL: Invalid finalPrice in finalization, using fallback');
                                finalPrice = negotiation.userBudget || negotiation.originalPrice || 1500;
                                console.log('✅ Using fallback price for finalization:', finalPrice);
                            }
                            
                            negotiation.finalPrice = finalPrice;
                            console.log('🎉 NEGOTIATION FINALIZED at $', negotiation.finalPrice);
                            
                            // Learn from successful negotiation
                            this.learnFromNegotiation(negotiation, { success: true, finalPrice });
                            
                            // PRIORITY 1: Direct UI update (immediate feedback)
                            const savings = negotiation.originalPrice - negotiation.finalPrice;
                            const savingsText = savings > 0 ? ` (Saved $${savings}!)` : '';
                            const successMessage = `🎉 **DEAL CLOSED!** Landlord said "${message.content}" and accepted $${negotiation.finalPrice}/month${savingsText}. Property: ${negotiation.listingTitle}`;
                            
                            try {
                                if (typeof window !== 'undefined' && window.aiNegotiator) {
                                    console.log('🎯 DIRECTLY updating AI chat interface with success');
                                    window.aiNegotiator.appendMessage('AI', `💬 **Landlord:** "${message.content}"`, 'left');
                                    window.aiNegotiator.appendMessage('AI', `🤖 **AI Response:** "${response}"`, 'left');
                                    window.aiNegotiator.appendMessage('AI', successMessage, 'left');
                                    window.aiNegotiator.celebrateSuccess();
                                    console.log('✅ Direct UI update successful!');
                                } else {
                                    console.log('⚠️ Window AI negotiator not available for direct update');
                                }
                            } catch (error) {
                                console.log('❌ Direct UI update failed:', error.message);
                            }
                            
                            // PRIORITY 2: Try database notification (may fail due to constraints)
                            try {
                                await this.notifyNegotiationComplete(negotiation, message.content);
                            } catch (dbError) {
                                console.log('Database notification failed (expected):', dbError.message);
                            }
                            
                            // PRIORITY 3: Store in localStorage as backup
                            try {
                                const backupData = {
                                    type: 'negotiation_success',
                                    timestamp: new Date().toISOString(),
                                    userEmail: negotiation.userEmail,
                                    message: successMessage,
                                    landlordReply: message.content,
                                    aiResponse: response
                                };
                                
                                const existingBackups = JSON.parse(localStorage.getItem('ai_negotiation_backups') || '[]');
                                existingBackups.push(backupData);
                                // Keep only last 10 items
                                if (existingBackups.length > 10) {
                                    existingBackups.splice(0, existingBackups.length - 10);
                                }
                                localStorage.setItem('ai_negotiation_backups', JSON.stringify(existingBackups));
                                console.log('✅ Backup stored in localStorage');
                            } catch (storageError) {
                                console.log('Storage backup failed:', storageError.message);
                            }
                            
                            // PRIORITY 4: Track negotiation outcome for learning
                            try {
                                console.log('📊 Tracking successful negotiation outcome');
                                await this.trackNegotiationOutcome(negotiation, 'success', negotiation.finalPrice);
                            } catch (trackingError) {
                                console.log('Learning tracking failed:', trackingError.message);
                            }
                        } else {
                            // Show AI response in chat for ongoing negotiation
                            try {
                                if (typeof window !== 'undefined' && window.aiNegotiator) {
                                    window.aiNegotiator.appendMessage('AI', `🤖 **My Response**: "${response}"`, 'left');
                                }
                            } catch (error) {
                                console.log('Could not directly update AI chat with response:', error.message);
                            }
                            
                            // Notify user about the ongoing exchange
                            await this.notifyLandlordReply(negotiation, message.content, response);
                        }
                    } else {
                        console.error('❌ Failed to send response');
                    }
                } else {
                    console.log('❌ No response generated');
                }
            } else {
                console.log('ℹ️ Analysis indicates no response needed');
            }
            
            // Handle special case for negative sentiment when no response was generated above
            if (analysis.sentiment === 'negative' && !analysis.shouldRespond) {
                // Handle rejection with intelligent market-based response
                console.log('❌ Received negative response, attempting market-based negotiation');
                
                const marketResponse = await this.generateMarketBasedNegotiation(negotiation, listing, message.content, analysis);
                if (marketResponse) {
                    await new Promise(resolve => setTimeout(resolve, 2000));
                    await this.sendNegotiationMessage(conversationId, marketResponse, negotiation.userEmail);
                    
                    negotiation.messages.push({
                        sender: 'ai',
                        content: marketResponse,
                        timestamp: new Date()
                    });
                    
                    // Notify user about the rejection and our counter-response
                    await this.notifyLandlordReply(negotiation, message.content, marketResponse);
                    
                    // Show in AI chat immediately
                    try {
                        if (typeof window !== 'undefined' && window.aiNegotiator) {
                            window.aiNegotiator.appendMessage('AI', `❌ **Landlord Rejected**: "${message.content}" - Sent market-based counter-offer: "${marketResponse}"`, 'left');
                        }
                    } catch (error) {
                        console.log('Could not directly update AI chat with rejection response:', error.message);
                    }
                    
                    // Mark as final attempt
                    negotiation.finalAttempt = true;
                }
            }

            // Update active negotiation
            this.activeNegotiations.set(conversationId, negotiation);

        } catch (error) {
            console.error('Error handling negotiation reply:', error);
        }
    }

    // Analyze landlord's reply with advanced intelligence
    async analyzeReply(replyContent, negotiation, listing) {
        console.log('🔍 Starting advanced reply analysis for:', replyContent);
        
        // Check for specific meeting coordination first
        const meetingPatterns = /(?:meet|tonight|today|at\s+\d|pm|am|cafe|restaurant|office|property)/i;
        const hasMeetingDetails = meetingPatterns.test(replyContent);
        
        // Check for already finalized negotiation by looking at recent messages
        const recentMessages = negotiation.messages?.slice(-5) || [];
        const hasRecentAgreement = recentMessages.some(msg => 
            msg.sender === 'ai' && (
                msg.content.includes('accept') || 
                msg.content.includes('deal') ||
                msg.content.includes('perfect') ||
                msg.content.includes('excellent')
            )
        );
        
        if (hasMeetingDetails && hasRecentAgreement) {
            console.log('📅 MEETING COORDINATION DETECTED after agreement:', replyContent);
            return {
                sentiment: 'positive',
                priceOffered: null,
                acceptsOffer: false,
                makesCounterOffer: false,
                shouldRespond: true,
                isFinalized: false,
                agreedPrice: this.extractLastOfferedPrice(negotiation),
                responseStrategy: 'meeting_coordination',
                suggestedResponse: 'Meeting coordination needed',
                negotiationPhase: 'logistics',
                originalReply: replyContent,
                landlordPersonality: this.detectLandlordPersonality(replyContent, negotiation),
                negotiationContext: this.analyzeNegotiationContext(negotiation)
            };
        }

        // Check for security deposit requests - PRIORITY DETECTION (works anytime)
        const securityDepositPatterns = /\b(security deposit|deposit|first month|payment|money|transfer|funds|rent upfront|i need|need.*deposit)\b/i;
        const hasSecurityDepositMention = securityDepositPatterns.test(replyContent);
        
        if (hasSecurityDepositMention) {
            console.log('💰 SECURITY DEPOSIT REQUEST DETECTED:', replyContent);
            return {
                sentiment: 'positive',
                priceOffered: null,
                acceptsOffer: false,
                makesCounterOffer: false,
                shouldRespond: true,
                isFinalized: false,
                agreedPrice: this.extractLastOfferedPrice(negotiation),
                responseStrategy: 'security_deposit',
                suggestedResponse: 'Security deposit discussion needed',
                negotiationPhase: 'logistics',
                originalReply: replyContent,
                landlordPersonality: this.detectLandlordPersonality(replyContent, negotiation),
                negotiationContext: this.analyzeNegotiationContext(negotiation)
            };
        }

        // Check for move-in logistics (only after agreement)
        const moveInPatterns = /\b(move.?in|tomorrow|tonight|today|when can you|available|ready)\b/i;
        const hasMoveInMention = moveInPatterns.test(replyContent);
        
        if (hasMoveInMention && hasRecentAgreement) {
            console.log('🏠 MOVE-IN LOGISTICS DETECTED:', replyContent);
            return {
                sentiment: 'positive',
                priceOffered: null,
                acceptsOffer: false,
                makesCounterOffer: false,
                shouldRespond: true,
                isFinalized: false,
                agreedPrice: this.extractLastOfferedPrice(negotiation),
                responseStrategy: 'move_in_logistics',
                suggestedResponse: 'Move-in logistics needed',
                negotiationPhase: 'logistics',
                originalReply: replyContent,
                landlordPersonality: this.detectLandlordPersonality(replyContent, negotiation),
                negotiationContext: this.analyzeNegotiationContext(negotiation)
            };
        }
        
        // Check for vague responses that need clarification (PRIORITY CHECK)
        const simpleReply = replyContent.trim().toLowerCase();
        const vageResponsePatterns = /\b(sure but|maybe|i guess|i mean|kinda|sorta|a little|somewhat|perhaps|slight adjustment|small adjustment|little adjustment|minor change)\b/i;
        const isVagueResponse = vageResponsePatterns.test(replyContent);
        
        if (isVagueResponse) {
            console.log('❓ VAGUE RESPONSE DETECTED - needs clarification:', replyContent);
            return {
                sentiment: 'neutral',
                priceOffered: null,
                acceptsOffer: false,
                makesCounterOffer: false,
                shouldRespond: true,
                isFinalized: false,
                agreedPrice: null,
                responseStrategy: 'clarify_vague',
                suggestedResponse: 'Need clarification on vague response',
                negotiationPhase: 'clarification',
                originalReply: replyContent,
                landlordPersonality: this.detectLandlordPersonality(replyContent, negotiation),
                negotiationContext: this.analyzeNegotiationContext(negotiation)
            };
        }
        
        // First check for simple acceptance patterns IMMEDIATELY
        const isSimpleAcceptance = /^(sure|yes|ok|okay|sounds good|works|fine|agreed|deal|sounds great|yep|yeah|absolutely)$/i.test(simpleReply) ||
                                  /^(i can discuss|can discuss|i'm open|open to|let's discuss|we can discuss)$/i.test(simpleReply);
        
        if (isSimpleAcceptance) {
            console.log('🎯 IMMEDIATE ACCEPTANCE DETECTED:', simpleReply);
            const lastOffer = this.extractLastOfferedPrice(negotiation);
            return {
                sentiment: 'positive',
                priceOffered: null,
                acceptsOffer: true,
                makesCounterOffer: false,
                shouldRespond: true,
                isFinalized: true,
                agreedPrice: lastOffer || negotiation.userBudget,
                responseStrategy: 'thank',
                suggestedResponse: `Excellent! Thank you for accepting the $${lastOffer || negotiation.userBudget}/month offer.`,
                negotiationPhase: 'closing',
                landlordPersonality: this.detectLandlordPersonality(replyContent, negotiation),
                negotiationContext: this.analyzeNegotiationContext(negotiation)
            };
        }

        // Advanced personality and sentiment detection
        const personalityProfile = this.detectLandlordPersonality(replyContent, negotiation);
        const emotionalState = this.detectEmotionalState(replyContent);
        const negotiationContext = this.analyzeNegotiationContext(negotiation);

        try {
            console.log('🤖 Attempting OpenAI analysis...');
            console.log('🤖 OpenAI Config Check:', {
                hasKey: !!this.config.OPENAI_API_KEY,
                keyPreview: this.config.OPENAI_API_KEY ? this.config.OPENAI_API_KEY.substring(0, 10) + '...' : 'Missing',
                model: this.config.OPENAI_MODEL || 'gpt-3.5-turbo',
                hasOrgId: !!this.config.OPENAI_ORG_ID
            });
            
            const lastAIMessage = negotiation.messages
                .filter(m => m.sender === 'ai')
                .pop();
            
            const prompt = `
            Analyze this landlord reply in a rental negotiation:

            LANDLORD REPLY: "${replyContent}"
            
            NEGOTIATION CONTEXT:
            - Original listing price: $${listing.price}
            - Last AI offer/message: "${lastAIMessage?.content || 'Initial contact'}"
            - User budget: $${negotiation.userBudget}
            - Current negotiation status: ${negotiation.status}
            - Conversation history: ${negotiation.messages.slice(-3).map(m => `${m.sender}: ${m.content}`).join(' | ')}

            Analyze the reply and return JSON:
            {
                "sentiment": "positive/neutral/negative",
                "priceOffered": null or number,
                "acceptsOffer": true/false,
                "makesCounterOffer": true/false,
                "shouldRespond": true/false,
                "isFinalized": true/false,
                "agreedPrice": null or number,
                "responseStrategy": "accept/counter/negotiate/thank/clarify/increase_request/security_deposit",
                "suggestedResponse": "brief response if shouldRespond is true",
                "negotiationPhase": "initial/bargaining/closing/rejected"
            }

            ENHANCED ANALYSIS RULES:
            - "sure", "yes", "ok", "sounds good", "fine", "agreed", "deal" = acceptance of last offer
            - "I might consider X", "how about X", "what about X", "I could do X" = counter-offer
            - "too low", "too high", "not enough" = rejection requiring counter
            - "X is my best", "final offer X", "can't go lower than X" = firm counter-offer
            - "can you raise it", "can you increase", "bump it up", "go higher" = responseStrategy: "increase_request"
            - "i need deposit", "security deposit", "deposit required" = responseStrategy: "security_deposit"
            - "sure but", "maybe", "i guess", "a little", "kinda" = VAGUE responses, shouldRespond=true but isFinalized=false
            - Extract ALL numbers: $790, 790, "seven ninety", "790/month", "790 per month"
            - Look for conditional acceptance: "maybe X", "possibly X", "perhaps X"
            - If they accept: isFinalized=true, agreedPrice=last offered price
            - If they counter with price: extract exact number, shouldRespond=true
            - NEVER finalize on vague responses - require explicit price agreement
            - If they show flexibility ("might consider"): makesCounterOffer=true
            - Consider context: if discussing price and mention number, likely counter-offer
            
            MEETING COORDINATION DETECTION:
            - "let's meet", "we can do it tonight", "sounds great", "tonight", "today" = meeting logistics phase
            - "when can we", "what time", "where should", "I'm available" = scheduling discussion
            - If price already agreed and they mention timing = responseStrategy should be "meeting_coordination"
            - After acceptance, logistics phrases should trigger meeting planning responses
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
                    max_tokens: 250,
                    temperature: 0.1
                })
            });

            if (!response.ok) {
                const errorText = await response.text();
                console.error('❌ OpenAI API failed with status:', response.status);
                console.error('❌ OpenAI API error details:', errorText);
                console.error('❌ OpenAI API key being used:', this.config.OPENAI_API_KEY ? 'Present' : 'Missing');
                console.error('❌ OpenAI Model:', this.config.OPENAI_MODEL);
                console.error('❌ OpenAI Org ID:', this.config.OPENAI_ORG_ID ? 'Present' : 'Missing');
                console.warn('⚠️ Using fallback analysis instead');
                throw new Error(`OpenAI API error: ${response.status} - ${errorText}`);
            }

            const data = await response.json();
            let analysis;
            
            try {
                const content = data.choices[0]?.message?.content?.trim();
                if (!content) {
                    throw new Error('No content in OpenAI response');
                }
                
                // Validate that it looks like JSON before parsing
                if (!content.startsWith('{') || !content.endsWith('}')) {
                    throw new Error('OpenAI response is not valid JSON format');
                }
                
                analysis = JSON.parse(content);
                
                // Validate required fields
                if (!analysis.hasOwnProperty('shouldRespond')) {
                    throw new Error('OpenAI response missing required fields');
                }
                
            } catch (parseError) {
                console.warn('⚠️ Failed to parse OpenAI response as JSON:', parseError.message);
                console.warn('⚠️ Raw OpenAI content:', data.choices[0]?.message?.content);
                throw new Error('Invalid OpenAI response format');
            }
            
            // Double-check for acceptance patterns in AI response too
            if (/\b(sure|yes|ok|okay|sounds good|works|fine|agreed|deal)\b/i.test(simpleReply)) {
                console.log('🎯 AI also detected acceptance in:', simpleReply);
                analysis.acceptsOffer = true;
                analysis.isFinalized = true;
                analysis.sentiment = 'positive';
                analysis.shouldRespond = true;
                analysis.responseStrategy = 'thank';
                const lastOffer = this.extractLastOfferedPrice(negotiation);
                if (lastOffer) {
                    analysis.agreedPrice = lastOffer;
                }
            }
            
            console.log('📊 AI Analysis result:', analysis);
            return analysis;

        } catch (error) {
            console.error('Error with AI analysis, using enhanced fallback:', error);
            
            // Enhanced fallback analysis with better detection
            const replyLower = replyContent.toLowerCase().trim();
            const hasPrice = replyContent.match(/\$(\d+)/);
            const seemsPositive = /\b(yes|ok|sure|accept|agree|sounds good|works|fine|deal|great|perfect)\b/i.test(replyContent);
            const hasAcceptanceWords = /\b(sure|yes|ok|okay|sounds good|works|fine|agreed|deal|sounds great|perfect|great|excellent)\b/i.test(replyLower);
            
            // Check for increase requests like "can you raise it"
            const isAskingForIncrease = /\b(can you|could you|would you).*(raise|increase|go up|higher)/i.test(replyContent) ||
                                      /\b(raise it|increase it|go higher|bump it up)/i.test(replyContent);
            
            console.log('🔧 Fallback analysis - hasAcceptanceWords:', hasAcceptanceWords, 'isAskingForIncrease:', isAskingForIncrease, 'for:', replyLower);
            
            return {
                sentiment: seemsPositive || isAskingForIncrease ? 'positive' : 'neutral',
                priceOffered: hasPrice ? parseInt(hasPrice[1]) : null,
                acceptsOffer: hasAcceptanceWords && !hasPrice && !isAskingForIncrease,
                makesCounterOffer: !!hasPrice || isAskingForIncrease,
                shouldRespond: true,
                isFinalized: hasAcceptanceWords && !hasPrice && !isAskingForIncrease,
                agreedPrice: (hasAcceptanceWords && !hasPrice && !isAskingForIncrease) ? this.extractLastOfferedPrice(negotiation) : null,
                responseStrategy: (hasAcceptanceWords && !hasPrice && !isAskingForIncrease) ? 'thank' : 
                                 (isAskingForIncrease ? 'increase_request' : 
                                 (hasPrice ? 'counter' : 'clarify')),
                negotiationPhase: (hasAcceptanceWords && !hasPrice && !isAskingForIncrease) ? 'closing' : 'bargaining',
                originalReply: replyContent
            };
        }
    }

    // Generate counter-response
    async generateCounterResponse(analysis, negotiation, listing) {
        if (!analysis.shouldRespond) return null;

        try {
            const negotiationId = this.getNegotiationId(negotiation);
            const roundNumber = negotiation.messages?.length || 1;
            
            console.log(`🎯 Generating response for round ${roundNumber}, sentiment: ${analysis.sentiment}`);

            if (analysis.isFinalized && analysis.acceptsOffer) {
                let finalPrice = analysis.agreedPrice || this.extractLastOfferedPrice(negotiation);
                
                // CRITICAL: Ensure finalPrice is never null/undefined/0
                if (!finalPrice || finalPrice <= 0) {
                    console.error('❌ CRITICAL: No valid price found, using fallback');
                    finalPrice = negotiation.userBudget || listing?.price || 1500;
                    console.log('✅ Using fallback price:', finalPrice);
                }
                
                console.log('🎉 GENERATING FINAL ACCEPTANCE RESPONSE - Price:', finalPrice);
                return await this.generateVariedAcceptanceResponse(finalPrice, negotiationId, roundNumber);
            }

            if (analysis.makesCounterOffer && analysis.priceOffered) {
                console.log('💰 Generating sophisticated counter-offer response');
                return await this.generateSophisticatedCounterOffer(analysis, negotiation, listing, roundNumber);
            }

            if (analysis.responseStrategy === 'meeting_coordination') {
                console.log('📅 Generating meeting coordination response');
                // Pass the original reply for context
                analysis.originalReply = analysis.originalReply || analysis.suggestedResponse || '';
                return this.generateMeetingCoordinationResponse(analysis, negotiation, roundNumber);
            }

            if (analysis.responseStrategy === 'security_deposit') {
                console.log('💰 Generating security deposit response');
                let finalPrice = analysis.agreedPrice || this.extractLastOfferedPrice(negotiation);
                
                // CRITICAL: Ensure finalPrice is never null/undefined/0
                if (!finalPrice || finalPrice <= 0) {
                    console.error('❌ CRITICAL: No valid price for security deposit, using fallback');
                    finalPrice = negotiation.userBudget || listing?.price || 1500;
                    console.log('✅ Using fallback price for security deposit:', finalPrice);
                }
                
                return this.generateSecurityDepositResponse(finalPrice, negotiationId, roundNumber);
            }

            if (analysis.responseStrategy === 'move_in_logistics') {
                console.log('🏠 Generating move-in logistics response');
                return this.generateMoveInLogisticsResponse(negotiationId, roundNumber);
            }

            if (analysis.responseStrategy === 'increase_request') {
                console.log('⬆️ Generating increase request response');
                return this.generateIncreaseRequestResponse(negotiation, listing, negotiationId, roundNumber);
            }

            if (analysis.responseStrategy === 'clarify_vague') {
                console.log('❓ Generating clarification request for vague response');
                return this.generateVagueClarificationResponse(negotiation, listing, negotiationId, roundNumber);
            }

            if (analysis.sentiment === 'negative' || analysis.responseStrategy === 'clarify') {
                console.log('🔄 Generating strategic response for negative sentiment');
                return await this.generateStrategicResponse(negotiation, listing, roundNumber);
            }

            // Use progressive negotiation tactics
            console.log('🧠 Generating progressive contextual response');
            return await this.generateProgressiveResponse(analysis, negotiation, listing, roundNumber);

        } catch (error) {
            console.error('Error generating counter-response:', error);
            return this.getFallbackResponse(negotiation.messages?.length || 1);
        }
    }

    // Get unique negotiation ID for memory tracking
    getNegotiationId(negotiation) {
        return negotiation.negotiationId || negotiation.listingId || 'default';
    }

    // Generate varied acceptance response to prevent repetition
    async generateVariedAcceptanceResponse(finalPrice, negotiationId, roundNumber) {
        // CRITICAL: Ensure finalPrice is never null/undefined/0
        if (!finalPrice || finalPrice <= 0) {
            console.error('❌ CRITICAL: Invalid finalPrice detected:', finalPrice);
            // Get negotiation to access fallback prices
            const negotiation = this.activeNegotiations.get(negotiationId);
            const listing = Array.from(this.activeNegotiations.values()).find(n => n.id === negotiationId)?.listing;
            // Use 85% of listing price as fallback (15% discount max)
            finalPrice = negotiation?.userBudget || (listing?.price ? Math.round(listing.price * 0.85) : 1500);
            console.log('✅ Using fallback price:', finalPrice);
        }
        
        const templates = this.responseTemplates.counterOfferAcceptance;
        const usedResponses = this.conversationalMemory.get(negotiationId) || new Set();
        
        let selectedTemplate;
        let templateIndex;
        
        // Use AI Learning System for intelligent template selection
        if (this.learningEnabled) {
            try {
                const context = await this.buildLearningContext('counter_offer_acceptance', negotiation, listing);
                const optimalTemplate = await this.learningSystem.getOptimalTemplate(context);
                
                templateIndex = optimalTemplate.templateId;
                selectedTemplate = templates[templateIndex];
                
                console.log('🧠 AI Learning selected template:', templateIndex, 'Reason:', optimalTemplate.reason);
            } catch (error) {
                console.error('❌ Learning system failed, falling back to random selection:', error);
                // Fallback to original logic
                const availableTemplates = templates.filter((_, index) => !usedResponses.has(`acceptance_${index}`));
                
                if (availableTemplates.length > 0) {
                    selectedTemplate = availableTemplates[Math.floor(Math.random() * availableTemplates.length)];
                } else {
                    usedResponses.clear();
                    selectedTemplate = templates[Math.floor(Math.random() * templates.length)];
                }
                templateIndex = templates.indexOf(selectedTemplate);
            }
        } else {
            // Original random selection logic
            const availableTemplates = templates.filter((_, index) => !usedResponses.has(`acceptance_${index}`));
            
            if (availableTemplates.length > 0) {
                selectedTemplate = availableTemplates[Math.floor(Math.random() * availableTemplates.length)];
            } else {
                usedResponses.clear();
                selectedTemplate = templates[Math.floor(Math.random() * templates.length)];
            }
            templateIndex = templates.indexOf(selectedTemplate);
        }
        
        // Mark this template as used
        usedResponses.add(`acceptance_${templateIndex}`);
        this.conversationalMemory.set(negotiationId, usedResponses);
        
        // Add price confirmation and closing details with variation
        const confirmationVariations = [
            `Just to confirm - we're agreeing on $${finalPrice}/month for the rental, correct?`,
            `Perfect! So we're set at $${finalPrice}/month - is that confirmed?`,
            `Excellent! To make sure we're on the same page - $${finalPrice}/month works for both of us?`,
            `Great! Just want to double-check - $${finalPrice}/month is our agreed price?`,
            `Wonderful! Confirming the final rent amount - $${finalPrice}/month, right?`
        ];
        
        const closingVariations = [
            " I'm ready to proceed immediately with all necessary documentation.",
            " I can provide excellent references and complete paperwork right away.",
            " I'm excited to finalize this! I have all my documents ready.",
            " I'm prepared to move quickly with references and paperwork.",
            " I can handle all the paperwork immediately."
        ];
        
        const confirmationIndex = roundNumber % confirmationVariations.length;
        const closingIndex = roundNumber % closingVariations.length;
        const baseResponse = selectedTemplate.replace(/\$\$\{price\}/g, finalPrice);
        
        return `${baseResponse} ${confirmationVariations[confirmationIndex]}${closingVariations[closingIndex]}`;
    }

    // Generate sophisticated counter-offer with progressive tactics
    async generateSophisticatedCounterOffer(analysis, negotiation, listing, roundNumber) {
        const landlordPrice = analysis.priceOffered;
        const userBudget = negotiation.userBudget;
        const negotiationId = this.getNegotiationId(negotiation);
        const lastOffer = this.extractLastOfferedPrice(negotiation);
        
        // SMART DIRECTION: Check if we should go UP or DOWN
        let targetPrice;
        let strategy;
        
        if (landlordPrice > lastOffer) {
            // Landlord wants MORE money - we should consider going UP from our last offer
            if (roundNumber <= 2) {
                // Early rounds: Meet them partway
                targetPrice = Math.min(userBudget, lastOffer + Math.round((landlordPrice - lastOffer) * 0.5));
                strategy = 'meeting_halfway';
            } else if (roundNumber <= 4) {
                // Middle rounds: Go closer to their price
                targetPrice = Math.min(userBudget, lastOffer + Math.round((landlordPrice - lastOffer) * 0.7));
                strategy = 'value_added';
            } else {
                // Later rounds: Get very close to their price
                targetPrice = Math.min(userBudget, lastOffer + Math.round((landlordPrice - lastOffer) * 0.85));
                strategy = 'closing_focus';
            }
            console.log(`⬆️ GOING UP: Landlord wants $${landlordPrice}, last offer was $${lastOffer}, increasing to $${targetPrice}`);
        } else {
            // Use original logic when landlord wants less or equal
            if (roundNumber <= 2) {
                targetPrice = Math.min(userBudget, Math.round(landlordPrice * 0.95));
                strategy = 'market_informed';
            } else if (roundNumber <= 4) {
                targetPrice = Math.min(userBudget, Math.round(landlordPrice * 0.97));
                strategy = 'value_added';
            } else {
                targetPrice = Math.min(userBudget, Math.round(landlordPrice * 0.985));
                strategy = 'closing_focus';
            }
        }
        
        // Ensure we don't exceed budget
        targetPrice = Math.min(targetPrice, userBudget);
        
        // CRITICAL: Ensure we never offer below 85% of listing price (15% discount max)
        if (listing.price && listing.price > 0) {
            const minOffer = Math.round(listing.price * 0.85);
            if (targetPrice < minOffer) {
                targetPrice = minOffer;
                console.log(`✅ Adjusted offer to minimum 85% of listing price: $${targetPrice}`);
            }
        }
        
        console.log(`🎯 Round ${roundNumber} strategy: ${strategy}, offering: $${targetPrice}`);
        
        return this.generateVariedCounterOffer(targetPrice, landlordPrice, strategy, negotiationId, roundNumber, listing);
    }

    // Generate varied counter-offer responses
    generateVariedCounterOffer(targetPrice, landlordPrice, strategy, negotiationId, roundNumber, listing) {
        const usedResponses = this.conversationalMemory.get(negotiationId) || new Set();
        
        let baseTemplate;
        let additionalContext = '';
        
        switch (strategy) {
            case 'market_informed':
                const marketTemplates = this.responseTemplates.marketBasedResponses;
                baseTemplate = this.selectUnusedTemplate(marketTemplates, usedResponses, 'market', negotiationId);
                additionalContext = " I've researched comparable properties to ensure fair pricing.";
                break;
                
            case 'value_added':
                const valueTemplates = this.responseTemplates.valuePropositions;
                baseTemplate = this.selectUnusedTemplate(valueTemplates, usedResponses, 'value', negotiationId);
                additionalContext = this.getValueAddOns(roundNumber);
                break;
                
            case 'closing_focus':
                const strategicTemplates = this.responseTemplates.strategicCounterOffers;
                baseTemplate = this.selectUnusedTemplate(strategicTemplates, usedResponses, 'strategic', negotiationId);
                additionalContext = " I'm ready to finalize this today if we can agree on terms.";
                break;
                
            default:
                const defaultTemplates = this.responseTemplates.strategicCounterOffers;
                baseTemplate = this.selectUnusedTemplate(defaultTemplates, usedResponses, 'default', negotiationId);
        }
        
        // CRITICAL: Ensure targetPrice is never null/undefined/0
        if (!targetPrice || targetPrice <= 0) {
            console.error('❌ CRITICAL: Invalid targetPrice detected:', targetPrice);
            const negotiation = this.activeNegotiations.get(negotiationId);
            // Use 85% of listing price as fallback (15% discount max)
            targetPrice = negotiation?.userBudget || (listing.price ? Math.round(listing.price * 0.85) : 1500);
            console.log('✅ Using fallback targetPrice:', targetPrice);
        }
        
        const response = baseTemplate.replace(/\$\$\{price\}/g, targetPrice) + additionalContext;
        
        console.log(`💬 Generated varied response (round ${roundNumber}): ${response.substring(0, 50)}...`);
        return this.formatMessage(response);
    }

    // Select unused template with fallback
    selectUnusedTemplate(templates, usedResponses, category, negotiationId) {
        const availableTemplates = templates.filter((_, index) => !usedResponses.has(`${category}_${index}`));
        
        let selectedTemplate;
        if (availableTemplates.length > 0) {
            selectedTemplate = availableTemplates[Math.floor(Math.random() * availableTemplates.length)];
        } else {
            // Reset category if all used
            for (let key of usedResponses) {
                if (key.startsWith(`${category}_`)) {
                    usedResponses.delete(key);
                }
            }
            selectedTemplate = templates[Math.floor(Math.random() * templates.length)];
        }
        
        // Mark as used
        const templateIndex = templates.indexOf(selectedTemplate);
        usedResponses.add(`${category}_${templateIndex}`);
        this.conversationalMemory.set(negotiationId, usedResponses);
        
        return selectedTemplate;
    }

    // Get value-added propositions based on round
    getValueAddOns(roundNumber) {
        const valueAdds = [
            " Plus, I can offer a longer lease commitment for stability.",
            " I'm also willing to handle minor maintenance to keep the property in excellent condition.",
            " Additionally, I can provide first and last month upfront for your security.",
            " I'm flexible on move-in dates to work with your schedule.",
            " I can also provide additional security deposit if that helps."
        ];
        
        return valueAdds[roundNumber % valueAdds.length];
    }

    // Generate strategic response for negative sentiment
    async generateStrategicResponse(negotiation, listing, roundNumber) {
        const userBudget = negotiation.userBudget;
        const dynamicMarketData = await this.getDynamicMarketData(
            listing.city, 
            listing.house_type, 
            listing.bedrooms
        );
        
        let adjustedOffer = Math.min(
            userBudget || listing.price, 
            Math.round((dynamicMarketData?.adjustedAverage || listing.price) * 0.96)
        );
        
        // CRITICAL: Ensure adjustedOffer is never null/undefined/0
        if (!adjustedOffer || adjustedOffer <= 0) {
            console.error('❌ CRITICAL: Invalid adjustedOffer detected:', adjustedOffer);
            adjustedOffer = userBudget || listing.price || 1500;
            console.log('✅ Using fallback price for strategic response:', adjustedOffer);
        }
        
        const strategicResponses = [
            `I understand your position. Let me present a comprehensive offer: $${adjustedOffer}/month with excellent references, immediate occupancy, and long-term reliability. This reflects both market conditions and my value as a tenant.`,
            `I appreciate your feedback. Based on current market analysis, I can offer $${adjustedOffer}/month. This represents fair value while ensuring you have a responsible, verified tenant who takes excellent care of properties.`,
            `I respect your perspective. My research shows comparable properties at around $${adjustedOffer}/month. I'm offering this rate plus the peace of mind that comes with a reliable, long-term tenant with pristine references.`,
            `I hear you. Let me propose $${adjustedOffer}/month, which aligns with market data for similar properties. I bring exceptional tenant qualities including financial stability, property care, and communication.`
        ];
        
        const responseIndex = roundNumber % strategicResponses.length;
        return this.formatMessage(strategicResponses[responseIndex]);
    }

    // Generate progressive response using advanced tactics
    async generateProgressiveResponse(analysis, negotiation, listing, roundNumber) {
        const personality = analysis.landlordPersonality || this.detectLandlordPersonality(analysis.originalReply || '', negotiation);
        const userBudget = negotiation.userBudget;
        
        // SMART NEGOTIATION DIRECTION: Check what landlord actually wants
        let offerPrice;
        const lastOffer = this.extractLastOfferedPrice(negotiation);
        const landlordMessage = analysis.originalReply || '';
        
        // Check if landlord is asking for higher price
        const requestedPrice = this.extractPriceFromMessage(landlordMessage);
        const isAskingForMore = /\b(want|need|require)\s*\$?(\d+)/i.test(landlordMessage) ||
                               /\b(can you|could you).*(raise|increase|go up|higher)/i.test(landlordMessage);
        
        if (requestedPrice && isAskingForMore && requestedPrice > lastOffer) {
            // Landlord wants MORE - tenant should consider going UP (not down!)
            const increaseAmount = Math.min(
                userBudget - lastOffer, 
                Math.round((requestedPrice - lastOffer) * 0.7) // Meet them 70% of the way
            );
            offerPrice = Math.min(userBudget, lastOffer + increaseAmount);
            console.log(`🔄 CORRECTED DIRECTION: Landlord wants $${requestedPrice}, increasing from $${lastOffer} to $${offerPrice}`);
        } else {
            // Realistic progressive pricing based on rounds (15% max discount)
            const basePrice = listing.price;
            if (roundNumber === 1) {
                offerPrice = Math.min(userBudget, Math.round(basePrice * 0.85)); // Start at 15% below (minimum)
            } else if (roundNumber <= 3) {
                offerPrice = Math.min(userBudget, Math.round(basePrice * 0.90)); // Move to 10% below
            } else if (roundNumber <= 5) {
                offerPrice = Math.min(userBudget, Math.round(basePrice * 0.95)); // Move to 5% below
            } else {
                offerPrice = Math.min(userBudget, Math.round(basePrice * 0.97)); // Get very close to asking
            }
        }
        
        // Personality-adapted responses
        if (personality.communicationStyle === 'casual') {
            return this.generateCasualProgressiveResponse(offerPrice, roundNumber, listing);
        } else if (personality.traits?.includes('professional')) {
            return this.generateProfessionalProgressiveResponse(offerPrice, roundNumber, listing);
        } else {
            return this.generateBalancedProgressiveResponse(offerPrice, roundNumber, listing);
        }
    }

    // Generate casual progressive responses
    generateCasualProgressiveResponse(price, round, listing) {
        // CRITICAL: Ensure price is never null/undefined/0
        if (!price || price <= 0) {
            console.error('❌ CRITICAL: Invalid price in casual response:', price);
            price = listing.price || 1500;
            console.log('✅ Using fallback price for casual response:', price);
        }
        
        const casualResponses = [
            `Hey! Thanks for getting back to me. I'm really interested in the ${listing.house_type}. How about $${price}/month? I'm a great tenant - clean, quiet, and always on time with rent.`,
            `I appreciate you considering my offer! Would $${price}/month work? I'm flexible and really love the place. Plus, I'm super reliable and take great care of properties.`,
            `Thanks for the response! How about we settle on $${price}/month? I'm ready to move fast and I think you'll find I'm exactly the kind of tenant you want.`,
            `I hear you! What if we do $${price}/month? I'm really excited about this place and I guarantee you won't have any issues with me as a tenant.`
        ];
        
        return this.formatMessage(casualResponses[round % casualResponses.length]);
    }

    // Generate professional progressive responses
    generateProfessionalProgressiveResponse(price, round, listing) {
        // CRITICAL: Ensure price is never null/undefined/0
        if (!price || price <= 0) {
            console.error('❌ CRITICAL: Invalid price in professional response:', price);
            price = listing.price || 1500;
            console.log('✅ Using fallback price for professional response:', price);
        }
        
        const professionalResponses = [
            `Thank you for your consideration. I would like to propose $${price}/month for the ${listing.house_type}. I am a qualified professional tenant with excellent credit and references.`,
            `I appreciate your response. My offer is $${price}/month, reflecting both market conditions and my credentials as a reliable, long-term tenant with verifiable income and references.`,
            `Thank you for continuing our discussion. I can offer $${price}/month and provide comprehensive documentation including employment verification, credit report, and landlord references.`,
            `I value your time and consideration. My proposal of $${price}/month represents fair market value while ensuring you receive a dependable tenant with proven financial stability.`
        ];
        
        return this.formatMessage(professionalResponses[round % professionalResponses.length]);
    }

    // Generate balanced progressive responses
    generateBalancedProgressiveResponse(price, round, listing) {
        // CRITICAL: Ensure price is never null/undefined/0
        if (!price || price <= 0) {
            console.error('❌ CRITICAL: Invalid price in balanced response:', price);
            price = listing.price || 1500;
            console.log('✅ Using fallback price for balanced response:', price);
        }
        
        const balancedResponses = [
            `Thank you for your reply. I'd like to offer $${price}/month for this ${listing.house_type}. I'm a responsible tenant with excellent references and I'm ready to move forward quickly.`,
            `I appreciate your consideration. Would $${price}/month work for you? I can provide strong references and I'm committed to maintaining the property in excellent condition.`,
            `Thanks for getting back to me. I can offer $${price}/month and I'm prepared to provide all necessary documentation. I believe this represents good value for both of us.`,
            `I understand your position. My offer is $${price}/month, and I want to emphasize that you'll be getting a reliable, communicative tenant who respects both the property and landlord relationship.`
        ];
        
        return this.formatMessage(balancedResponses[round % balancedResponses.length]);
    }

    // Generate meeting coordination response
    generateMeetingCoordinationResponse(analysis, negotiation, roundNumber) {
        const negotiationId = this.getNegotiationId(negotiation);
        const usedResponses = this.conversationalMemory.get(negotiationId) || new Set();
        
        // Check if this is a follow-up to an already accepted offer
        const recentMessages = negotiation.messages?.slice(-3) || [];
        const hasRecentAcceptance = recentMessages.some(msg => 
            msg.sender === 'ai' && (
                msg.content.includes('accept') || 
                msg.content.includes('works excellently') ||
                msg.content.includes('Perfect') ||
                msg.content.includes('Excellent')
            )
        );
        
        if (hasRecentAcceptance) {
            // This is follow-up logistics, not initial acceptance
            return this.generateLogisticsFollowUp(analysis, roundNumber, negotiationId);
        } else {
            // This is initial meeting acceptance
            return this.generateInitialMeetingResponse(analysis, roundNumber, negotiationId);
        }
    }
    
    // Generate logistics follow-up (when we already accepted, now discussing meeting)
    generateLogisticsFollowUp(analysis, roundNumber, negotiationId) {
        const landlordMessage = analysis.originalReply || '';
        
        // Check if landlord provided specific meeting details
        const hasVenue = /(?:at\s+\w+|cafe|restaurant|office|property)/i.test(landlordMessage);
        const hasTime = /(?:\d{1,2}\s*(?:pm|am)|tonight|today|this evening)/i.test(landlordMessage);
        
        if (hasVenue || hasTime) {
            // Landlord provided specific details, confirm them
            const confirmationResponses = [
                "Perfect! That works excellently for me. I'll be there with all necessary documents and payment ready.",
                "Excellent! I can definitely make that work. I'll bring all required paperwork and be on time.",
                "Great! That sounds perfect. I'll come prepared with references, ID, and first month's rent.",
                "Wonderful! I'll see you there. I have all documentation ready and I'm excited to finalize everything.",
                "Outstanding! That timing works perfectly for me. I'll bring everything needed to complete the rental.",
                "Perfect! I'll be there with all necessary paperwork. Looking forward to finalizing our agreement!",
                "Fantastic! That works great for me. I'll come prepared with all documents and payment ready.",
                "Excellent! I can be there on time with all required documentation. See you then!"
            ];
            
            const responseIndex = roundNumber % confirmationResponses.length;
            return this.formatMessage(confirmationResponses[responseIndex]);
        } else {
            // General logistics coordination
            const logisticsResponses = [
                "Fantastic! I'm excited to finalize everything. What time works best for you? I'm available after 6 PM.",
                "Perfect! Should we meet at the property? I have all my documents ready including references and payment.",
                "Wonderful! What time should we arrange to meet? I can bring everything needed to complete the rental agreement.",
                "Excellent! I'm free this evening. Would you prefer to meet at 7 PM or later? I'll bring all necessary paperwork.",
                "Great! I'm ready to proceed tonight. What location would be most convenient for you?",
                "Outstanding! What time works for your schedule? I'll come prepared with all required documentation.",
                "Perfect! I'm available anytime after 5:30 PM. Should I bring the first month's rent and security deposit?",
                "Fantastic! What would be the best time and place to meet? I have everything organized and ready to go."
            ];
            
            const responseIndex = roundNumber % logisticsResponses.length;
            return this.formatMessage(logisticsResponses[responseIndex]);
        }
    }
    
    // Generate initial meeting response (when accepting and coordinating simultaneously)
    generateInitialMeetingResponse(analysis, roundNumber, negotiationId) {
        const meetingTemplates = this.responseTemplates.meetingCoordination;
        const documentTemplates = this.responseTemplates.documentPreparation;
        
        const meetingResponse = this.selectUnusedTemplate(meetingTemplates, this.conversationalMemory.get(negotiationId) || new Set(), 'meeting', negotiationId);
        const documentResponse = documentTemplates[roundNumber % documentTemplates.length];
        
        const combinedResponse = `${meetingResponse} ${documentResponse}`;
        return this.formatMessage(combinedResponse);
    }
    
    // Format message with proper punctuation and spacing
    formatMessage(message) {
        let formatted = message
            // Add space after periods if missing
            .replace(/\.([A-Z])/g, '. $1')
            // Add space after commas if missing
            .replace(/,([A-Z])/g, ', $1')
            // Add space after question marks if missing
            .replace(/\?([A-Z])/g, '? $1')
            // Add space after exclamation marks if missing
            .replace(/!([A-Z])/g, '! $1')
            // Fix multiple spaces
            .replace(/\s+/g, ' ')
            // Trim whitespace
            .trim();
        
        // Ensure proper capitalization after sentence endings
        formatted = formatted.replace(/([.!?]\s*)([a-z])/g, (match, punctuation, letter) => {
            return punctuation + letter.toUpperCase();
        });
        
        return formatted;
    }
    
    // Enhanced duplicate prevention
    isRecentDuplicate(message, negotiation) {
        if (!negotiation.messages || negotiation.messages.length === 0) return false;
        
        // Check last 3 AI messages for similarity
        const recentAIMessages = negotiation.messages
            .filter(m => m.sender === 'ai')
            .slice(-3)
            .map(m => m.content.toLowerCase().replace(/[^\w\s]/g, ''));
        
        const cleanCurrentMessage = message.toLowerCase().replace(/[^\w\s]/g, '');
        
        // Calculate similarity threshold (80% similar = duplicate)
        return recentAIMessages.some(prevMessage => {
            const similarity = this.calculateMessageSimilarity(cleanCurrentMessage, prevMessage);
            return similarity > 0.8;
        });
    }
    
    // Calculate message similarity (simple word overlap)
    calculateMessageSimilarity(message1, message2) {
        const words1 = new Set(message1.split(/\s+/));
        const words2 = new Set(message2.split(/\s+/));
        
        const intersection = new Set([...words1].filter(word => words2.has(word)));
        const union = new Set([...words1, ...words2]);
        
        return intersection.size / union.size;
    }

    // Generate alternative response when duplicate detected
    async generateAlternativeResponse(analysis, negotiation, listing) {
        console.log('🔄 Generating alternative response to avoid duplication');
        
        const roundNumber = negotiation.messages?.length || 1;
        const alternativeStrategies = [
            'casual_approach',
            'professional_approach', 
            'value_focused',
            'time_sensitive',
            'document_focused'
        ];
        
        const strategy = alternativeStrategies[roundNumber % alternativeStrategies.length];
        
        switch (strategy) {
            case 'casual_approach':
                return this.formatMessage("Awesome! I'm really excited about this place. When would be a good time to meet up? I've got everything ready to go!");
                
            case 'professional_approach':
                return this.formatMessage("Excellent. I appreciate your prompt response. Shall we arrange a meeting to finalize the rental agreement? I have all documentation prepared.");
                
            case 'value_focused':
                return this.formatMessage("Perfect! I'm confident you'll find me to be an ideal tenant. What's the best way to proceed with finalizing everything?");
                
            case 'time_sensitive':
                return this.formatMessage("Great! I'm ready to move forward immediately. What time works best for you today or this evening?");
                
            case 'document_focused':
                return this.formatMessage("Wonderful! I have all necessary paperwork including references and financial verification ready. How should we arrange to complete the process?");
                
            default:
                return this.formatMessage("Thank you! I'm looking forward to moving forward. What would be the next step?");
        }
    }

    // Get fallback response with variety
    getFallbackResponse(roundNumber) {
        const fallbacks = [
            "Thank you for your response. I'm very interested in moving forward with this rental and I'm flexible on terms.",
            "I appreciate your time. I'm committed to finding a mutually beneficial arrangement for this property.",
            "Thanks for continuing our discussion. I'm confident we can reach an agreement that works for both of us.",
            "I value your consideration. I'm a serious tenant looking to establish a positive rental relationship."
        ];
        
        return this.formatMessage(fallbacks[roundNumber % fallbacks.length]);
    }

    // Generate advanced counter-offer with sophisticated tactics (legacy method - keeping for compatibility)
    async generateAdvancedCounterOffer(analysis, negotiation, listing) {
        const userBudget = negotiation.userBudget;
        const counterPrice = analysis.priceOffered;
        const marketData = negotiation.marketData;
        const personality = analysis.landlordPersonality || this.detectLandlordPersonality(analysis.originalReply || '', negotiation);
        const context = analysis.negotiationContext || this.analyzeNegotiationContext(negotiation);

        console.log('🎯 Generating advanced counter-offer with personality:', personality.type);

        if (counterPrice <= userBudget) {
            return await this.generateAcceptanceResponse(counterPrice, personality, context);
        } else {
            return await this.generateCounterOfferWithStrategy(counterPrice, userBudget, marketData, personality, context, listing);
        }
    }

    // Generate acceptance response tailored to landlord personality
    async generateAcceptanceResponse(agreedPrice, personality, context) {
        if (personality.communicationStyle === 'casual') {
            return `Perfect! $${agreedPrice}/month works great for me. I'm ready to move fast and can provide solid references. When can we make this official?`;
        } else if (personality.traits.includes('professional')) {
            return `Excellent. I accept your offer of $${agreedPrice}/month. I'm prepared to proceed immediately with all necessary documentation and can provide comprehensive references and financial verification. Please advise on the next steps for finalizing our rental agreement.`;
        } else {
            return `Perfect! $${agreedPrice}/month works excellently for me. I'm ready to proceed immediately and can provide excellent references. When can we arrange to finalize the rental agreement?`;
        }
    }

    // Generate counter-offer with advanced strategy
    async generateCounterOfferWithStrategy(counterPrice, userBudget, marketData, personality, context, listing) {
        // Determine negotiation strategy based on personality and context
        const strategy = this.selectNegotiationStrategy(personality, context, marketData);
        console.log('🧠 Selected negotiation strategy:', strategy);

        let baseOffer = Math.min(userBudget, Math.round(counterPrice * 0.92));
        let response = '';

        switch (strategy) {
            case 'value_proposition':
                response = await this.generateValuePropositionResponse(baseOffer, counterPrice, personality, listing);
                break;
            case 'market_data':
                response = await this.generateMarketDataResponse(baseOffer, counterPrice, marketData, personality);
                break;
            case 'emotional_appeal':
                response = await this.generateEmotionalResponse(baseOffer, counterPrice, personality, context);
                break;
            case 'compromise_creative':
                response = await this.generateCreativeCompromise(baseOffer, counterPrice, personality, listing);
                break;
            case 'final_attempt':
                response = await this.generateFinalAttemptResponse(baseOffer, counterPrice, personality);
                break;
            default:
                response = await this.generateStandardResponse(baseOffer, counterPrice, marketData, personality);
        }

        return response;
    }

    // Select the best negotiation strategy
    selectNegotiationStrategy(personality, context, marketData) {
        // If landlord is frustrated/skeptical, use value proposition
        if (personality.emotionalState === 'frustrated' || personality.traits.includes('skeptical')) {
            return 'value_proposition';
        }
        
        // If landlord is experienced, use market data
        if (personality.traits.includes('experienced')) {
            return 'market_data';
        }
        
        // If landlord is casual/informal, use emotional appeal
        if (personality.communicationStyle === 'casual') {
            return 'emotional_appeal';
        }
        
        // If we're in later rounds, try creative compromise
        if (context.roundsOfNegotiation >= 3) {
            return 'compromise_creative';
        }
        
        // If significant price reduction already made, final attempt
        if (context.priceReductions.significant) {
            return 'final_attempt';
        }
        
        return 'market_data'; // Default to data-driven approach
    }

    // Generate value proposition response (for skeptical landlords)
    async generateValuePropositionResponse(offer, counterPrice, personality, listing) {
        const valueProp = this.generateValuePropositions(listing);
        
        if (personality.communicationStyle === 'casual') {
            return `I hear you! Look, I get that you've heard it all before. Here's the real deal - I can do $${offer}/month, and here's what you get: ${valueProp.casual}. I'm not just another tenant making promises.`;
        } else {
            return `I understand your position and appreciate your directness. I can offer $${offer}/month, and I'd like to present some concrete value: ${valueProp.formal}. I believe this creates a win-win situation for both of us.`;
        }
    }

    // Generate market data response (for experienced landlords)
    async generateMarketDataResponse(offer, counterPrice, marketData, personality) {
        if (!marketData) {
            return `I appreciate your counter-offer. Based on my research of comparable properties, I can offer $${offer}/month. This reflects current market conditions while ensuring fair value for both parties.`;
        }

        const marketJustification = counterPrice > marketData.average ? 
            `current market data shows similar properties averaging $${marketData.average}/month` :
            `this aligns well with current market rates of around $${marketData.average}/month`;

        if (personality.communicationStyle === 'formal') {
            return `Thank you for your counter-offer. Based on comprehensive market analysis, ${marketJustification}. I can offer $${offer}/month, which represents fair market value while recognizing the quality of your property.`;
        } else {
            return `I appreciate the counter! Looking at ${marketJustification}, I can do $${offer}/month. Fair deal for both of us based on what's out there right now.`;
        }
    }

    // Generate emotional appeal response (for casual landlords)
    async generateEmotionalResponse(offer, counterPrice, personality, context) {
        if (personality.communicationStyle === 'casual') {
            return `I really love this place and can see myself living here long-term. I can stretch to $${offer}/month - that's honestly my max but I'd rather pay it for the right spot with a cool landlord. What do you think?`;
        } else {
            return `I'm genuinely excited about this property and can envision making it my home. I can offer $${offer}/month, which represents my maximum budget. I'm committed to being an exemplary tenant who takes excellent care of the property.`;
        }
    }

    // Generate creative compromise (for extended negotiations)
    async generateCreativeCompromise(offer, counterPrice, personality, listing) {
        const compromises = [
            `$${offer}/month with a 18-month lease commitment`,
            `$${offer}/month plus I'll handle minor maintenance and upkeep`,
            `$${offer}/month with first and last month paid upfront`,
            `$${offer}/month and I'll help with property improvements`
        ];

        const selectedCompromise = compromises[Math.floor(Math.random() * compromises.length)];

        if (personality.communicationStyle === 'casual') {
            return `How about we get creative here? I can do ${selectedCompromise}. That way we both win - you get a reliable tenant and I get a fair deal. Sound good?`;
        } else {
            return `I'd like to propose a mutually beneficial arrangement: ${selectedCompromise}. This provides additional value and security for you while working within my budget constraints.`;
        }
    }

    // Generate final attempt response
    async generateFinalAttemptResponse(offer, counterPrice, personality) {
        if (personality.communicationStyle === 'casual') {
            return `Alright, final offer: $${offer}/month. That's genuinely my absolute max. If it works, awesome! If not, no hard feelings and thanks for your time.`;
        } else {
            return `I appreciate your time and consideration. My final offer is $${offer}/month - this represents my absolute maximum budget. If this works for you, I'm ready to proceed immediately. If not, I completely understand and thank you for the opportunity.`;
        }
    }

    // Generate standard response
    async generateStandardResponse(offer, counterPrice, marketData, personality) {
        let justification = '';
        if (marketData && counterPrice > marketData.average) {
            justification = ` Given that similar properties in the area average around $${marketData.average}/month,`;
        }
        
        return `I really appreciate your counter-offer!${justification} Would you consider $${offer}/month? This fits perfectly within my budget and I can guarantee immediate occupancy with excellent references. I'm a serious, reliable tenant looking to establish a long-term rental relationship.`;
    }

    // Generate value propositions
    generateValuePropositions(listing) {
        return {
            casual: "long-term lease (I'm not going anywhere), excellent credit, no parties, and I actually take care of places better than most owners",
            formal: "a minimum 12-month lease commitment, verifiable excellent credit history, comprehensive renters insurance, and meticulous property care with regular maintenance updates"
        };
    }

    // Generate market-based response for rejections
    async generateMarketBasedResponse(negotiation, listing) {
        const marketData = negotiation.marketData || await this.getMarketData(
            listing.city, listing.house_type, listing.bedrooms
        );
        
        const suggestion = Math.min(
            negotiation.userBudget, 
            Math.round(marketData.average * 0.95)
        );
        
        return `I understand your position. Based on current market data for similar ${listing.house_type}s in ${listing.city}, comparable properties are typically renting for around $${marketData.average}/month. Would you consider $${suggestion}/month? I'm a qualified, reliable tenant with excellent references and I'm ready to move in immediately.`;
    }

    // Generate contextual response using AI
    async generateContextualResponse(analysis, negotiation, listing) {
        try {
            const prompt = `
            Generate a persuasive rental negotiation response based on this context:
            
            LANDLORD'S SENTIMENT: ${analysis.sentiment}
            STRATEGY NEEDED: ${analysis.responseStrategy}
            NEGOTIATION PHASE: ${analysis.negotiationPhase}
            
            PROPERTY: ${listing.title} - $${listing.price}/month (${listing.house_type})
            USER BUDGET: $${negotiation.userBudget}/month
            CONVERSATION: ${negotiation.messages.slice(-2).map(m => `${m.sender}: ${m.content}`).join(' | ')}
            
            IMPORTANT PRICING RULES:
            - NEVER offer less than 85% of the listing price ($${Math.round(listing.price * 0.85)}/month minimum)
            - Start negotiations at 85% and gradually increase (85% → 90% → 95% → 97%)
            - Maximum discount is 15% below listing price
            
            Generate a professional, persuasive response (2-3 sentences max) that:
            1. Acknowledges their position respectfully
            2. Emphasizes tenant reliability and quick decision-making
            3. Makes a reasonable counter-proposal if needed (respecting pricing rules above)
            4. Shows genuine interest in the property
            
            Be concise and professional. Do NOT include greetings or signatures.
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
                    max_tokens: 120,
                    temperature: 0.7
                })
            });

            if (response.ok) {
                const data = await response.json();
                return data.choices[0].message.content.trim();
            }
        } catch (error) {
            console.error('Error generating contextual response:', error);
        }
        
        return `Thank you for your consideration. I'm very interested in this ${listing.house_type} and I'm a reliable tenant ready to move quickly. Is there any flexibility we can work with?`;
    }

    // Send negotiation message
    async sendNegotiationMessage(conversationId, message, userEmail) {
        try {
            // Ensure AI user exists first
            await this.ensureAIUserExists();
            
            const senderEmail = 'ai-negotiator@roomfinder.com';
            
            console.log('📤 Attempting to send message as:', senderEmail);
            console.log('📤 Message content preview:', message.substring(0, 50) + '...');
            
            const { error } = await this.supabase
                .from('messages')
                .insert({
                    conversation_id: conversationId,
                    sender_email: senderEmail,
                    content: `🤖 AI Negotiator on behalf of ${userEmail}:\n\n${message}`
                });

            if (error) {
                console.error('❌ Error sending negotiation message with AI email:', error);
                console.error('❌ Error details:', error.message);
                
                // Fallback: try using the user's email instead
                console.log('Retrying with user email...');
                const { error: retryError } = await this.supabase
                    .from('messages')
                    .insert({
                        conversation_id: conversationId,
                        sender_email: userEmail,
                        content: `🤖 AI Negotiator:\n\n${message}`
                    });

                if (retryError) {
                    console.error('Error sending negotiation message with user email:', retryError);
                    return false;
                }
            }

            console.log('✅ Sent negotiation message');
            return true;

        } catch (error) {
            console.error('Error in sendNegotiationMessage:', error);
            return false;
        }
    }

    // Setup real-time message listener
    setupMessageListener() {
        try {
            const messageChannel = this.supabase
                .channel(`negotiation_messages_${Date.now()}`)
                .on('postgres_changes', {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'messages'
                }, async (payload) => {
                    const newMessage = payload.new;
                    console.log('🔔 [AI NEGOTIATION] ========== NEW MESSAGE RECEIVED ==========');
                    console.log('🔔 Message ID:', newMessage.id);
                    console.log('🔔 Message sender:', newMessage.sender_email);
                    console.log('🔔 Message content:', newMessage.content);
                    console.log('🔔 Conversation ID:', newMessage.conversation_id);
                    console.log('🔔 Created at:', newMessage.created_at);
                    
                    // Check if this is a reply to an AI negotiation
                    if (newMessage.sender_email !== 'ai-negotiator@roomfinder.com') {
                        console.log('📨 Processing reply from:', newMessage.sender_email);
                        console.log('📨 Looking for conversation:', newMessage.conversation_id);
                        
                        const { data: conversation, error: convError } = await this.supabase
                            .from('conversations')
                            .select('*')
                            .eq('id', newMessage.conversation_id)
                            .maybeSingle();
                            
                        if (convError) {
                            console.log('❌ Conversation lookup error:', convError.message);
                            return;
                        }
                        
                        console.log('📨 Found conversation:', conversation);
                        
                        // Enhanced AI conversation detection
                        let isAIConversation = false;
                        
                        // Method 1: Check if conversation directly involves AI
                        if (conversation && (
                            conversation.sender_email === 'ai-negotiator@roomfinder.com' || 
                            conversation.receiver_email === 'ai-negotiator@roomfinder.com'
                        )) {
                            console.log('📨 ✅ Direct AI conversation detected');
                            isAIConversation = true;
                        }
                        
                        // Method 2: Check if AI has sent messages in this conversation (more reliable)
                        if (!isAIConversation && conversation) {
                            console.log('📨 Checking for AI messages in this conversation...');
                            
                            const { data: aiMessages, error: aiMsgError } = await this.supabase
                                .from('messages')
                                .select('sender_email, content, created_at')
                                .eq('conversation_id', conversation.id)
                                .eq('sender_email', 'ai-negotiator@roomfinder.com')
                                .limit(1);
                            
                            if (!aiMsgError && aiMessages && aiMessages.length > 0) {
                                console.log('📨 ✅ Found AI messages in conversation:', aiMessages.length);
                                isAIConversation = true;
                            }
                        }
                        
                        // Method 3: Check conversation metadata for AI negotiation flag
                        if (!isAIConversation && conversation) {
                            try {
                                const metadata = conversation.metadata ? JSON.parse(conversation.metadata) : {};
                                if (metadata.ai_negotiation || metadata.ai_initiated) {
                                    console.log('📨 ✅ Conversation metadata indicates AI negotiation');
                                    isAIConversation = true;
                                }
                            } catch (error) {
                                console.log('📨 Could not parse conversation metadata:', error.message);
                            }
                        }
                        
                        // Method 4: Check if this conversation has active negotiations tracked
                        if (!isAIConversation && conversation) {
                            const hasActiveNegotiation = this.activeNegotiations.has(conversation.id);
                            if (hasActiveNegotiation) {
                                console.log('📨 ✅ Found active negotiation for this conversation');
                                isAIConversation = true;
                            }
                        }
                        
                        // Method 5: Enhanced content-based detection
                        if (!isAIConversation && conversation) {
                            console.log('📨 Performing enhanced content analysis...');
                            
                            const { data: allMessages, error: allMsgError } = await this.supabase
                                .from('messages')
                                .select('content, sender_email')
                                .eq('conversation_id', conversation.id)
                                .limit(15);
                            
                            if (!allMsgError && allMessages) {
                                const conversationText = allMessages.map(m => m.content).join(' ').toLowerCase();
                                
                                // Enhanced keyword detection
                                const negotiationKeywords = [
                                    'negotiate', 'negotiation', 'counter offer', 'counter-offer', 'counteroffer',
                                    'price', 'rent', 'monthly', 'budget', 'offer', 'deal',
                                    'apartment', 'bedroom', 'bedrooms', 'house', 'condo', 'property',
                                    'qualified tenant', 'references', 'move in', 'lease', 'rental',
                                    'market data', 'market rate', 'comparable', 'interested',
                                    'security deposit', 'first month', 'available'
                                ];
                                
                                // Check for AI negotiation patterns
                                const aiPatterns = [
                                    'ai negotiator', 'market analysis', 'based on comparable',
                                    'qualified tenant with', 'ready to move', 'market data shows'
                                ];
                                
                                const keywordMatches = negotiationKeywords.filter(keyword => 
                                    conversationText.includes(keyword)
                                ).length;
                                
                                const aiPatternMatches = aiPatterns.filter(pattern => 
                                    conversationText.includes(pattern)
                                ).length;
                                
                                console.log('📨 Keyword matches:', keywordMatches, 'AI pattern matches:', aiPatternMatches);
                                
                                // More lenient detection: 2+ keywords or 1+ AI pattern
                                if (keywordMatches >= 2 || aiPatternMatches >= 1) {
                                    console.log('📨 ✅ Enhanced content detection: negotiation conversation detected');
                                    isAIConversation = true;
                                }
                            }
                        }
                        
                        // Method 6: Check current message content for immediate response patterns
                        if (!isAIConversation) {
                            const messageText = newMessage.content.toLowerCase();
                            const responsePatterns = [
                                'sure', 'ok', 'okay', 'yes', 'accept', 'agree', 'deal',
                                'sounds good', 'works for me', 'perfect', 'great',
                                'counter', 'how about', 'what about', 'can you',
                                'interested', 'maybe', 'consider', 'think about'
                            ];
                            
                            const hasResponsePattern = responsePatterns.some(pattern => 
                                messageText.includes(pattern)
                            );
                            
                            if (hasResponsePattern && conversation?.listing_id) {
                                console.log('📨 ✅ Response pattern detected in message with listing context');
                                isAIConversation = true;
                            }
                        }
                        
                        console.log('📨 Final decision - Is AI conversation?', isAIConversation);
                        
                        if (!isAIConversation) {
                            console.log('📨 Not an AI negotiation conversation, skipping');
                            return;
                        }

                        if (conversation) {
                            console.log('📨 Getting listing details for listing ID:', conversation.listing_id);
                            
                            // Get listing details
                            const { data: listing, error: listingError } = await this.supabase
                                .from('listings')
                                .select('*')
                                .eq('id', conversation.listing_id)
                                .single();

                            if (listingError) {
                                console.log('❌ Listing lookup error:', listingError.message);
                                return;
                            }
                            
                            console.log('📨 Found listing:', listing);

                            if (listing) {
                                console.log('🚀 Starting handleNegotiationReply...');
                                await this.handleNegotiationReply(newMessage, conversation.id, listing);
                                console.log('✅ handleNegotiationReply completed');
                            }
                        }
                    }
                })
                .subscribe((status, err) => {
                    console.log('🔔 [AI NEGOTIATION] Message listener status:', status);
                    if (err) {
                        console.error('❌ [AI NEGOTIATION] Message listener error:', err);
                    }
                    if (status === 'SUBSCRIBED') {
                        console.log('✅ [AI NEGOTIATION] Message listener active and ready');
                    }
                });

            console.log('🔔 Negotiation message listener setup complete');

        } catch (error) {
            console.error('Error setting up message listener:', error);
        }
    }

    // Start a new negotiation
    async startNegotiation(listing, userBudget, userEmail, conversationId = null) {
        try {
            console.log('🚀 Starting negotiation for:', listing.title);
            
            // Check for existing negotiations but allow continuation
            const existingNegotiation = Array.from(this.activeNegotiations.values())
                .find(neg => neg.listingId === listing.id && neg.userEmail === userEmail);
            
            if (existingNegotiation) {
                console.log('🔄 Found existing negotiation, checking if it can continue...');
                
                // Allow continuation if the negotiation is still active and not finalized
                if (existingNegotiation.status !== 'finalized' && existingNegotiation.status !== 'failed') {
                    console.log('✅ Continuing existing negotiation');
                    // Return the existing negotiation data to continue
                    return {
                        success: true,
                        message: `Continuing our conversation about ${listing.title}. What would you like to discuss?`,
                        marketData: existingNegotiation.marketData,
                        existingNegotiation: true
                    };
                } else {
                    console.log('⚠️ Previous negotiation was finalized, starting fresh');
                    // Remove the old negotiation and start fresh
                    this.activeNegotiations.delete(existingNegotiation.negotiationId);
                }
            }

            // Clean up location data before getting market data
            let cleanCity = listing.city ? listing.city.toString().trim() : null;
            if (cleanCity) {
                cleanCity = cleanCity.split(',')[0].trim();
                cleanCity = cleanCity.replace(/\s+(fr|france|canada|ca|usa|us|australia|au)$/i, '');
            }

            // Get market data
            const marketData = await this.getMarketData(cleanCity, listing.house_type, listing.bedrooms);

            // Generate negotiation message
            const message = await this.generateNegotiationMessage(listing, userBudget, marketData);

            // Create negotiation tracking
            const negotiationId = `neg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
            
            const negotiationData = {
                listingId: listing.id,
                listingTitle: listing.title,
                originalPrice: listing.price,
                userBudget: userBudget,
                userEmail: userEmail,
                landlordEmail: listing.user_email,
                marketData: marketData,
                status: 'active',
                startTime: new Date(),
                conversationId: conversationId,
                messages: [{
                    sender: 'ai',
                    content: message,
                    timestamp: new Date()
                }]
            };
            
            this.activeNegotiations.set(negotiationId, negotiationData);
            
            // Also track by conversation ID if available for faster lookup
            if (conversationId) {
                this.activeNegotiations.set(conversationId, negotiationData);
                console.log('✅ Negotiation tracked by both negotiation ID and conversation ID');
            }

            return {
                message,
                marketData,
                negotiationId
            };

        } catch (error) {
            console.error('Error starting negotiation:', error);
            throw error;
        }
    }

    // Extract the last offered price from negotiation history
    extractLastOfferedPrice(negotiation) {
        try {
            console.log('🔍 Extracting last offered price from negotiation...');
            
            // First, check if there's an explicitly stored final price
            if (negotiation.finalPrice) {
                console.log('✅ Found stored final price:', negotiation.finalPrice);
                return negotiation.finalPrice;
            }
            
            // Look through all recent messages (AI and landlord) for price mentions
            const recentMessages = negotiation.messages?.slice(-5) || [];
            
            for (let i = recentMessages.length - 1; i >= 0; i--) {
                const message = recentMessages[i].content;
                
                // Enhanced price matching patterns
                const priceMatches = [
                    /\$(\d+)\/month/gi,
                    /\$(\d+)\s*per\s*month/gi,
                    /\$(\d+)\s*monthly/gi,
                    /(\d+)\/month/gi,
                    /(\d+)\s*per\s*month/gi,
                    /(\d+)\s*monthly/gi,
                    // Also match simple number patterns when context is about price
                    /(?:accept|agreed?|deal|works?|sounds?\s+good).*?(\d{3,4})(?!\d)/gi,
                    /(\d{3,4})(?!\d).*?(?:accept|agreed?|deal|works?|sounds?\s+good)/gi
                ];
                
                for (const pattern of priceMatches) {
                    const matches = [...message.matchAll(pattern)];
                    if (matches.length > 0) {
                        const price = parseInt(matches[0][1]);
                        if (price >= 100 && price <= 5000) { // Reasonable rent range
                            console.log(`✅ Found price ${price} in message: "${message.substring(0, 50)}..."`);
                            return price;
                        }
                    }
                }
            }
            
            // Fallback to user budget if no specific price found
            const fallbackPrice = negotiation.userBudget || negotiation.originalPrice || 1500;
            console.log('⚠️ No price found, using fallback:', fallbackPrice);
            return fallbackPrice;
        } catch (error) {
            console.error('Error extracting last offered price:', error);
            const fallbackPrice = negotiation.userBudget || negotiation.originalPrice || 1500;
            console.log('✅ Error fallback price:', fallbackPrice);
            return fallbackPrice;
        }
    }

    // Generate market-based negotiation response to rejections
    // Enhanced dynamic pricing model with market intelligence
    async getDynamicMarketData(location, houseType, bedrooms, seasonality = null) {
        const cacheKey = `dynamic_${location}-${houseType}-${bedrooms}-${seasonality || 'default'}`;
        
        if (this.marketData.has(cacheKey)) {
            console.log('📊 Using cached dynamic market data for:', cacheKey);
            return this.marketData.get(cacheKey);
        }

        try {
            // Get base market data
            const baseMarketData = await this.getMarketData(location, houseType, bedrooms);
            
            // Apply dynamic adjustments
            const adjustments = await this.calculateMarketAdjustments(location, houseType, bedrooms);
            
            const dynamicData = {
                ...baseMarketData,
                adjustedAverage: Math.round(baseMarketData.average * adjustments.priceMultiplier),
                adjustedMedian: Math.round(baseMarketData.median * adjustments.priceMultiplier),
                seasonalFactor: adjustments.seasonalFactor,
                demandLevel: adjustments.demandLevel,
                competitiveIndex: adjustments.competitiveIndex,
                locationDesirability: adjustments.locationDesirability,
                negotiationLeverage: this.calculateNegotiationLeverage(adjustments),
                pricingStrategy: this.determinePricingStrategy(adjustments),
                adjustmentFactors: adjustments
            };
            
            this.marketData.set(cacheKey, dynamicData);
            console.log('📊 Dynamic market data calculated:', dynamicData);
            
            return dynamicData;
        } catch (error) {
            console.error('Error getting dynamic market data:', error);
            return await this.getMarketData(location, houseType, bedrooms);
        }
    }

    // Calculate market adjustment factors for dynamic pricing
    async calculateMarketAdjustments(location, houseType, bedrooms) {
        try {
            const currentMonth = new Date().getMonth() + 1;
            const currentYear = new Date().getFullYear();
            
            // Seasonal adjustment (rental market seasonality)
            const seasonalFactor = this.getSeasonalAdjustment(currentMonth);
            
            // Property age and condition adjustment
            const propertyAgeAdjustment = this.getPropertyAgeAdjustment(houseType);
            
            // Location desirability scoring
            const locationDesirability = await this.calculateLocationDesirability(location);
            
            // Demand vs supply analysis
            const demandLevel = await this.analyzeDemandLevel(location, houseType, bedrooms);
            
            // Competitive pricing analysis
            const competitiveIndex = await this.calculateCompetitiveIndex(location, houseType, bedrooms);
            
            // Calculate overall price multiplier
            const priceMultiplier = (
                seasonalFactor * 
                propertyAgeAdjustment * 
                locationDesirability * 
                demandLevel * 
                competitiveIndex
            );
            
            return {
                seasonalFactor,
                propertyAgeAdjustment,
                locationDesirability,
                demandLevel,
                competitiveIndex,
                priceMultiplier: Math.max(0.7, Math.min(1.4, priceMultiplier)) // Cap between 70% and 140%
            };
        } catch (error) {
            console.error('Error calculating market adjustments:', error);
            return {
                seasonalFactor: 1.0,
                propertyAgeAdjustment: 1.0,
                locationDesirability: 1.0,
                demandLevel: 1.0,
                competitiveIndex: 1.0,
                priceMultiplier: 1.0
            };
        }
    }

    // Seasonal adjustment based on rental market patterns
    getSeasonalAdjustment(month) {
        // Peak season: May-September (higher prices)
        // Off-season: November-March (lower prices)
        const seasonalMap = {
            1: 0.92,   // January - low demand
            2: 0.90,   // February - lowest demand
            3: 0.95,   // March - starting to pick up
            4: 1.02,   // April - spring demand
            5: 1.08,   // May - peak season starts
            6: 1.10,   // June - peak demand
            7: 1.12,   // July - highest demand
            8: 1.10,   // August - still high
            9: 1.05,   // September - demand cooling
            10: 0.98,  // October - moderate
            11: 0.94,  // November - slowing down
            12: 0.92   // December - holiday slowdown
        };
        return seasonalMap[month] || 1.0;
    }

    // Property age and condition factor
    getPropertyAgeAdjustment(houseType) {
        // Newer properties command higher rents
        const typeAdjustments = {
            'apartment': 1.0,
            'house': 1.05,     // Houses typically rent for more
            'condo': 1.02,
            'townhouse': 1.03,
            'studio': 0.95,
            'room': 0.85       // Rooms rent for less
        };
        return typeAdjustments[houseType?.toLowerCase()] || 1.0;
    }

    // Calculate location desirability score
    async calculateLocationDesirability(location) {
        if (!location) return 1.0;
        
        const locationLower = location.toLowerCase();
        
        // Major city centers get higher scores
        const cityScores = {
            'paris': 1.20,
            'toronto': 1.15,
            'vancouver': 1.18,
            'montreal': 1.10,
            'london': 1.22,
            'new york': 1.25,
            'san francisco': 1.30,
            'los angeles': 1.18,
            'chicago': 1.12,
            'boston': 1.15,
            'seattle': 1.20,
            'washington': 1.17,
            'miami': 1.14,
            'berlin': 1.10,
            'amsterdam': 1.16,
            'sydney': 1.18,
            'melbourne': 1.15
        };
        
        for (const [city, score] of Object.entries(cityScores)) {
            if (locationLower.includes(city)) {
                return score;
            }
        }
        
        // Default for other locations
        return 1.0;
    }

    // Analyze demand level for specific market segment
    async analyzeDemandLevel(location, houseType, bedrooms) {
        try {
            // Query recent listing activity
            const { data: recentListings } = await this.supabase
                .from('listings')
                .select('price, created_at')
                .gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
                .ilike('city', `%${location}%`)
                .eq('house_type', houseType)
                .eq('bedrooms', bedrooms)
                .limit(20);
            
            if (!recentListings?.length) return 1.0;
            
            // High activity = high demand = higher prices
            const activityLevel = recentListings.length;
            
            if (activityLevel >= 15) return 1.08;      // Very high demand
            if (activityLevel >= 10) return 1.05;      // High demand
            if (activityLevel >= 5) return 1.02;       // Moderate demand
            return 0.98;                               // Lower demand
            
        } catch (error) {
            console.error('Error analyzing demand level:', error);
            return 1.0;
        }
    }

    // Calculate competitive index based on similar listings
    async calculateCompetitiveIndex(location, houseType, bedrooms) {
        try {
            // Get similar active listings
            const { data: competitors } = await this.supabase
                .from('listings')
                .select('price')
                .ilike('city', `%${location}%`)
                .eq('house_type', houseType)
                .eq('bedrooms', bedrooms)
                .gte('price', 1) // Only listings with valid prices
                .limit(30);
            
            if (!competitors?.length) return 1.0;
            
            const prices = competitors.map(c => c.price);
            const priceVariation = (Math.max(...prices) - Math.min(...prices)) / Math.max(...prices);
            
            // High price variation = more negotiation room
            if (priceVariation > 0.3) return 0.95;     // High variation, lower baseline
            if (priceVariation > 0.2) return 0.98;     // Moderate variation
            return 1.02;                               // Low variation, premium market
            
        } catch (error) {
            console.error('Error calculating competitive index:', error);
            return 1.0;
        }
    }

    // Calculate negotiation leverage based on market conditions
    calculateNegotiationLeverage(adjustments) {
        const leverageScore = (
            (1 - adjustments.demandLevel) * 0.3 + // Lower demand = more leverage
            (1 - adjustments.competitiveIndex) * 0.3 + // Less competition = more leverage
            (1 - adjustments.seasonalFactor) * 0.2 + // Off-season = more leverage
            (1 - adjustments.locationDesirability) * 0.2 // Less desirable = more leverage
        );
        
        if (leverageScore > 0.15) return 'high';
        if (leverageScore > 0.05) return 'medium';
        return 'low';
    }

    // Determine optimal pricing strategy
    determinePricingStrategy(adjustments) {
        const priceMultiplier = adjustments.priceMultiplier;
        
        if (priceMultiplier > 1.1) return 'premium_market';
        if (priceMultiplier < 0.9) return 'aggressive_pricing';
        return 'balanced_approach';
    }

    // Select advanced negotiation strategy based on context
    selectAdvancedNegotiationStrategy(analysis, negotiation, dynamicMarketData) {
        const personality = analysis.landlordPersonality;
        const leverage = dynamicMarketData?.negotiationLeverage || 'medium';
        const pricingStrategy = dynamicMarketData?.pricingStrategy || 'balanced_approach';
        
        if (personality?.emotionalState === 'frustrated' || personality?.traits.includes('skeptical')) {
            return "VALUE PROPOSITION STRATEGY: Focus on tenant quality, reliability, and non-monetary benefits. Emphasize quick decision-making and long-term tenancy.";
        }
        
        if (personality?.traits.includes('experienced') || personality?.communicationStyle === 'business') {
            return "MARKET DATA STRATEGY: Present comprehensive market analysis with specific comparables and pricing justification. Use data-driven arguments.";
        }
        
        if (leverage === 'high' && pricingStrategy === 'aggressive_pricing') {
            return "MARKET LEVERAGE STRATEGY: Highlight current market conditions favoring tenants. Present alternative options and competitive pricing.";
        }
        
        if (personality?.traits.includes('flexible') && negotiation.messages?.length <= 2) {
            return "CREATIVE COMPROMISE STRATEGY: Offer package deals including longer lease terms, utilities, maintenance responsibilities, or other value-adds.";
        }
        
        if (negotiation.messages?.length >= 3) {
            return "FINAL ATTEMPT STRATEGY: Present best and final offer with clear reasoning and deadline for response. Show respect for their position while maintaining firm stance.";
        }
        
        return "BALANCED PERSUASION STRATEGY: Combine market data with personal tenant qualities and reasonable compromise offers.";
    }

    // Extract price from message content
    extractPriceFromMessage(content) {
        const priceMatch = content.match(/\$([0-9,]+)/);
        return priceMatch ? parseInt(priceMatch[1].replace(/,/g, '')) : null;
    }

    async generateMarketBasedNegotiation(negotiation, listing, landlordMessage, analysis) {
        try {
            console.log('🏢 Generating advanced market-based response with dynamic pricing');
            
            // Get enhanced market data with dynamic pricing
            const dynamicMarketData = await this.getDynamicMarketData(
                listing.city, 
                listing.house_type, 
                listing.bedrooms
            );
            
            console.log('🏠 Using enhanced market data for negotiation:', dynamicMarketData);
            
            const prompt = `
            You are an expert rental negotiator with advanced market intelligence responding to a landlord's rejection.

            LANDLORD'S RESPONSE: "${landlordMessage}"
            SENTIMENT: ${analysis.sentiment}
            LANDLORD PERSONALITY: ${analysis.landlordPersonality?.type || 'unknown'}
            
            PROPERTY DETAILS:
            - ${listing.title}
            - Current Price: $${listing.price}/month
            - Type: ${listing.house_type}
            - Bedrooms: ${listing.bedrooms}
            - Location: ${listing.city}
            
            ADVANCED MARKET INTELLIGENCE:
            - Base Market Average: $${negotiation.marketData?.average || 'Unknown'}
            - Dynamic Adjusted Average: $${dynamicMarketData?.adjustedAverage || dynamicMarketData?.average || 'Unknown'}
            - Seasonal Factor: ${((dynamicMarketData?.seasonalFactor || 1) * 100 - 100).toFixed(1)}% ${(dynamicMarketData?.seasonalFactor || 1) > 1 ? 'premium' : 'discount'}
            - Location Desirability: ${(((dynamicMarketData?.locationDesirability || 1) * 100) - 100).toFixed(1)}% adjustment
            - Market Demand Level: ${(dynamicMarketData?.demandLevel || 1) > 1.05 ? 'High' : (dynamicMarketData?.demandLevel || 1) > 0.98 ? 'Moderate' : 'Low'}
            - Negotiation Leverage: ${dynamicMarketData?.negotiationLeverage || 'medium'}
            - Pricing Strategy: ${dynamicMarketData?.pricingStrategy || 'balanced_approach'}
            - Competitive Index: ${(((dynamicMarketData?.competitiveIndex || 1) * 100) - 100).toFixed(1)}% vs market
            
            NEGOTIATION CONTEXT:
            - Original ask: $${listing.price}
            - User budget: $${negotiation.userBudget}
            - Messages exchanged: ${negotiation.messages?.length || 0}
            - Previous offers: ${negotiation.messages?.filter(m => m.sender === 'ai').map(m => this.extractPriceFromMessage(m.content)).filter(p => p).join(', ') || 'None'}
            
            ADVANCED STRATEGY SELECTION:
            ${this.selectAdvancedNegotiationStrategy(analysis, negotiation, dynamicMarketData)}
            
            Generate a sophisticated response that:
            1. Acknowledges their position with emotional intelligence
            2. Presents compelling market-based evidence using dynamic data
            3. Offers value-added proposals beyond just price (lease terms, utilities, maintenance, etc.)
            4. Demonstrates tenant quality and reliability
            5. Provides a specific counter-offer with multi-factor justification
            6. Adapts tone to landlord's personality and communication style
            
            Keep response professional, persuasive, and appropriately detailed (2-4 sentences):
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
                    max_tokens: 150,
                    temperature: 0.7
                })
            });

            if (!response.ok) {
                throw new Error(`OpenAI API error: ${response.status}`);
            }

            const data = await response.json();
            const negotiationResponse = data.choices[0].message.content.trim();
            
            console.log('✅ Generated market-based negotiation response');
            return negotiationResponse;

        } catch (error) {
            console.error('Error generating market-based negotiation:', error);
            
            // Fallback to simpler market-based response
            const marketData = negotiation.marketData || { average: negotiation.userBudget };
            const counterOffer = Math.min(negotiation.userBudget, Math.round(marketData.average * 0.97));
            
            return `I understand your position. Based on current market data for similar ${listing.house_type}s in ${listing.city}, comparable properties average around $${marketData.average}/month. I'm offering $${counterOffer}/month with immediate occupancy and excellent references. I'm a reliable tenant who values long-term stability. Would this work for you?`;
        }
    }

    // Advanced negotiation success tracking and learning system
    async trackNegotiationOutcome(negotiation, outcome, finalPrice = null) {
        try {
            console.log('📊 Tracking negotiation outcome:', outcome, 'for listing:', negotiation.listingTitle);
            
            const outcomeData = {
                negotiation_id: negotiation.negotiationId || `neg_${Date.now()}`,
                listing_id: negotiation.listingId,
                user_email: negotiation.userEmail,
                landlord_email: negotiation.landlordEmail,
                original_price: negotiation.originalPrice,
                user_budget: negotiation.userBudget,
                final_price: finalPrice || negotiation.finalPrice,
                outcome: outcome, // 'success', 'failure', 'abandoned'
                negotiation_duration: negotiation.startTime ? (Date.now() - new Date(negotiation.startTime).getTime()) / 1000 : null,
                message_count: negotiation.messages?.length || 0,
                market_data: negotiation.marketData,
                dynamic_market_data: negotiation.dynamicMarketData,
                landlord_personality: negotiation.landlordPersonality,
                strategies_used: negotiation.strategiesUsed || [],
                success_factors: this.analyzeSuccessFactors(negotiation, outcome, finalPrice),
                created_at: new Date().toISOString()
            };
            
            // Enhanced conversation logging to Supabase
            await this.logConversationToSupabase(outcomeData, negotiation);
            
            // Store in localStorage as backup
            this.storeOutcomeLocally(outcomeData);
            console.log('✅ Negotiation outcome tracked successfully');
            
            // Update learning model
            await this.updateLearningModel(outcomeData);
            
        } catch (error) {
            console.error('Error tracking negotiation outcome:', error);
            // Fallback to local storage
            try {
                this.storeOutcomeLocally({
                    outcome,
                    finalPrice,
                    timestamp: new Date().toISOString(),
                    listingTitle: negotiation.listingTitle
                });
            } catch (storageError) {
                console.error('Failed to store outcome locally:', storageError);
            }
        }
    }

    // Enhanced conversation logging to Supabase for learning system
    async logConversationToSupabase(outcomeData, negotiation) {
        try {
            console.log('📊 Logging comprehensive conversation data to Supabase');
            
            // Prepare enhanced conversation data with learning insights
            const conversationData = {
                user_email: negotiation.userEmail,
                conversation_data: JSON.stringify([
                    {
                        role: 'system',
                        content: `Negotiation completed: ${outcomeData.outcome}`,
                        timestamp: new Date().toISOString()
                    },
                    {
                        role: 'assistant', 
                        content: `Property: ${negotiation.listingTitle}\nOriginal Price: $${negotiation.originalPrice}\nFinal Price: $${outcomeData.final_price}\nSavings: $${negotiation.originalPrice - outcomeData.final_price}\nDuration: ${Math.round(outcomeData.negotiation_duration / 60)} minutes\nMessages: ${outcomeData.message_count}`,
                        timestamp: new Date().toISOString()
                    }
                ]),
                title: `Negotiation ${outcomeData.outcome}: ${negotiation.listingTitle}`,
                created_at: new Date().toISOString(),
                // Enhanced metadata for learning system
                metadata: {
                    // Core negotiation data
                    negotiationId: outcomeData.negotiation_id,
                    listingId: outcomeData.listing_id,
                    outcome: outcomeData.outcome,
                    success: outcomeData.outcome === 'success',
                    dealClosed: outcomeData.outcome === 'success',
                    
                    // Financial data  
                    originalPrice: outcomeData.original_price,
                    finalPrice: outcomeData.final_price,
                    userBudget: outcomeData.user_budget,
                    savings: outcomeData.original_price - outcomeData.final_price,
                    savingsPercentage: Math.round(((outcomeData.original_price - outcomeData.final_price) / outcomeData.original_price) * 100),
                    
                    // Negotiation metrics
                    duration: outcomeData.negotiation_duration,
                    messageCount: outcomeData.message_count,
                    avgResponseTime: outcomeData.negotiation_duration / Math.max(outcomeData.message_count, 1),
                    
                    // Market context
                    marketData: outcomeData.market_data,
                    dynamicMarketData: outcomeData.dynamic_market_data,
                    
                    // Learning insights
                    landlordPersonality: outcomeData.landlord_personality,
                    strategiesUsed: outcomeData.strategies_used,
                    successFactors: outcomeData.success_factors,
                    
                    // Property context for learning
                    propertyType: negotiation.listingType || 'unknown',
                    location: negotiation.listingLocation || 'unknown',
                    priceRange: this.categorizePriceRange(outcomeData.original_price),
                    
                    // Conversation patterns
                    conversationFlow: this.analyzeConversationFlow(negotiation),
                    keyTurningPoints: this.identifyTurningPoints(negotiation),
                    
                    // AI performance metrics
                    aiResponseQuality: this.assessAIResponseQuality(negotiation),
                    promptOptimization: this.assessPromptPerformance(negotiation),
                    
                    // Learning optimization data
                    learningCategory: this.categorizeLearningData(outcomeData, negotiation),
                    trainingValue: this.calculateTrainingValue(outcomeData),
                    
                    // Timestamp for trend analysis
                    timestamp: new Date().toISOString(),
                    sessionId: negotiation.sessionId || `session_${Date.now()}`
                }
            };

            // Insert comprehensive conversation log
            const { data, error } = await this.supabase
                .from('ai_chats')
                .insert(conversationData);

            if (error) {
                console.error('❌ Error logging conversation to Supabase:', error);
                throw error;
            }

            console.log('✅ Comprehensive conversation logged to Supabase with learning metadata');
            
            // Also log individual messages for detailed analysis
            await this.logDetailedMessageHistory(negotiation, outcomeData.negotiation_id);
            
        } catch (error) {
            console.error('Error in comprehensive conversation logging:', error);
            // Don't throw - fallback to localStorage will handle it
        }
    }

    // Log detailed message history for analysis
    async logDetailedMessageHistory(negotiation, negotiationId) {
        try {
            if (!negotiation.messages || negotiation.messages.length === 0) return;

            console.log('📝 Logging detailed message history for analysis');
            
            // Create individual entries for each message exchange
            for (let i = 0; i < negotiation.messages.length; i++) {
                const message = negotiation.messages[i];
                const messageData = {
                    user_email: negotiation.userEmail,
                    conversation_data: JSON.stringify([{
                        role: message.sender === 'ai' ? 'assistant' : 'user',
                        content: message.content,
                        timestamp: message.timestamp || new Date().toISOString(),
                        messageIndex: i,
                        sender: message.sender
                    }]),
                    title: `Message ${i + 1}: ${negotiation.listingTitle}`,
                    metadata: {
                        negotiationId: negotiationId,
                        messageIndex: i,
                        sender: message.sender,
                        messageType: this.classifyMessageType(message.content),
                        priceOffered: this.extractPriceFromMessage(message.content),
                        sentiment: this.analyzeMessageSentiment(message.content),
                        strategy: this.identifyMessageStrategy(message.content),
                        timestamp: message.timestamp || new Date().toISOString()
                    }
                };

                await this.supabase.from('ai_chats').insert(messageData);
            }

            console.log('✅ Detailed message history logged');
        } catch (error) {
            console.error('Error logging detailed message history:', error);
        }
    }

    // Analyze conversation flow patterns
    analyzeConversationFlow(negotiation) {
        if (!negotiation.messages) return 'simple';
        
        const messageCount = negotiation.messages.length;
        const aiMessages = negotiation.messages.filter(m => m.sender === 'ai').length;
        const landlordMessages = negotiation.messages.filter(m => m.sender === 'landlord').length;
        
        if (messageCount <= 2) return 'quick_resolution';
        if (messageCount <= 5) return 'standard_negotiation';
        if (messageCount <= 10) return 'complex_negotiation';
        return 'extended_negotiation';
    }

    // Identify key turning points in conversation
    identifyTurningPoints(negotiation) {
        const turningPoints = [];
        
        if (!negotiation.messages) return turningPoints;
        
        negotiation.messages.forEach((message, index) => {
            const price = this.extractPriceFromMessage(message.content);
            if (price) {
                turningPoints.push({
                    messageIndex: index,
                    type: 'price_mention',
                    value: price,
                    sender: message.sender
                });
            }
            
            // Detect sentiment changes
            const sentiment = this.analyzeMessageSentiment(message.content);
            if (sentiment === 'positive' && index > 0) {
                turningPoints.push({
                    messageIndex: index,
                    type: 'sentiment_positive',
                    sender: message.sender
                });
            }
        });
        
        return turningPoints;
    }

    // Assess AI response quality for learning
    assessAIResponseQuality(negotiation) {
        if (!negotiation.messages) return 'unknown';
        
        const aiMessages = negotiation.messages.filter(m => m.sender === 'ai');
        if (aiMessages.length === 0) return 'no_ai_messages';
        
        // Simple quality assessment based on response patterns
        const hasVariety = new Set(aiMessages.map(m => m.content.substring(0, 20))).size > 1;
        const appropriateLength = aiMessages.every(m => m.content.length > 20 && m.content.length < 500);
        
        if (hasVariety && appropriateLength) return 'high';
        if (hasVariety || appropriateLength) return 'medium';
        return 'low';
    }

    // Assess prompt performance
    assessPromptPerformance(negotiation) {
        // This would analyze how well the AI prompts performed
        return {
            responseRelevance: 'high',
            contextAwareness: 'medium', 
            goalAlignment: 'high',
            creativityLevel: 'medium'
        };
    }

    // Categorize learning data
    categorizeLearningData(outcomeData, negotiation) {
        if (outcomeData.outcome === 'success') {
            if (outcomeData.message_count <= 3) return 'quick_success';
            if (outcomeData.final_price < outcomeData.original_price * 0.9) return 'high_savings_success';
            return 'standard_success';
        } else {
            if (outcomeData.message_count <= 2) return 'quick_rejection';
            if (outcomeData.message_count >= 5) return 'prolonged_failure';
            return 'standard_failure';
        }
    }

    // Calculate training value of this conversation
    calculateTrainingValue(outcomeData) {
        let value = 1;
        
        // Higher value for successful negotiations
        if (outcomeData.outcome === 'success') value *= 2;
        
        // Higher value for complex negotiations
        if (outcomeData.message_count >= 5) value *= 1.5;
        
        // Higher value if significant savings achieved
        const savingsPercent = ((outcomeData.original_price - outcomeData.final_price) / outcomeData.original_price) * 100;
        if (savingsPercent > 10) value *= 1.3;
        
        return Math.round(value * 10) / 10; // Round to 1 decimal
    }

    // Classify message type for analysis
    classifyMessageType(content) {
        const lower = content.toLowerCase();
        
        if (this.extractPriceFromMessage(content)) return 'price_offer';
        if (/accept|agree|deal|sure|yes|ok/i.test(lower)) return 'acceptance';
        if (/reject|no|too|expensive/i.test(lower)) return 'rejection';
        if (/counter|how about|what about/i.test(lower)) return 'counter_offer';
        if (/meet|when|time|tonight/i.test(lower)) return 'logistics';
        if (/deposit|payment|document/i.test(lower)) return 'financial_details';
        
        return 'general_communication';
    }

    // Analyze message sentiment
    analyzeMessageSentiment(content) {
        const lower = content.toLowerCase();
        
        const positiveWords = ['great', 'excellent', 'perfect', 'wonderful', 'agree', 'accept', 'yes', 'sure'];
        const negativeWords = ['no', 'reject', 'too', 'expensive', 'cannot', 'impossible'];
        
        const positiveScore = positiveWords.filter(word => lower.includes(word)).length;
        const negativeScore = negativeWords.filter(word => lower.includes(word)).length;
        
        if (positiveScore > negativeScore) return 'positive';
        if (negativeScore > positiveScore) return 'negative';
        return 'neutral';
    }

    // Identify message strategy
    identifyMessageStrategy(content) {
        const lower = content.toLowerCase();
        
        if (/market|comparable|average|data/i.test(lower)) return 'market_based';
        if (/reliable|tenant|references|quality/i.test(lower)) return 'value_proposition';
        if (/quick|immediate|today|asap/i.test(lower)) return 'urgency';
        if (/budget|afford|maximum/i.test(lower)) return 'budget_constraint';
        if (/final|last|best/i.test(lower)) return 'final_offer';
        
        return 'standard';
    }

    // Store negotiation outcome in localStorage as backup
    storeOutcomeLocally(outcomeData) {
        try {
            const existingOutcomes = JSON.parse(localStorage.getItem('negotiation_outcomes') || '[]');
            existingOutcomes.push(outcomeData);
            
            // Keep only last 50 outcomes
            if (existingOutcomes.length > 50) {
                existingOutcomes.splice(0, existingOutcomes.length - 50);
            }
            
            localStorage.setItem('negotiation_outcomes', JSON.stringify(existingOutcomes));
            console.log('💾 Outcome stored locally as backup');
        } catch (error) {
            console.error('Error storing outcome locally:', error);
        }
    }

    // Analyze factors that contributed to success or failure
    analyzeSuccessFactors(negotiation, outcome, finalPrice) {
        const factors = {
            price_reduction_achieved: null,
            percentage_saved: null,
            market_leverage_utilized: false,
            personality_adaptation: false,
            timing_factors: [],
            strategy_effectiveness: {},
            communication_style: null
        };
        
        if (outcome === 'success' && finalPrice && negotiation.originalPrice) {
            factors.price_reduction_achieved = negotiation.originalPrice - finalPrice;
            factors.percentage_saved = ((negotiation.originalPrice - finalPrice) / negotiation.originalPrice * 100).toFixed(2);
        }
        
        // Analyze market leverage usage
        if (negotiation.dynamicMarketData?.negotiationLeverage === 'high') {
            factors.market_leverage_utilized = true;
            factors.timing_factors.push('favorable_market_conditions');
        }
        
        // Check if seasonal timing was beneficial
        const seasonalFactor = negotiation.dynamicMarketData?.seasonalFactor || 1;
        if (seasonalFactor < 1.0) {
            factors.timing_factors.push('off_season_advantage');
        }
        
        // Analyze personality adaptation
        if (negotiation.landlordPersonality && negotiation.strategiesUsed?.length > 0) {
            factors.personality_adaptation = true;
            factors.communication_style = negotiation.landlordPersonality.communicationStyle;
        }
        
        // Strategy effectiveness analysis
        if (negotiation.strategiesUsed) {
            negotiation.strategiesUsed.forEach(strategy => {
                factors.strategy_effectiveness[strategy] = outcome === 'success' ? 'effective' : 'ineffective';
            });
        }
        
        return factors;
    }

    // Update the learning model based on negotiation outcomes
    async updateLearningModel(outcomeData) {
        try {
            console.log('🧠 Updating learning model with new outcome data');
            
            // Get recent outcomes for pattern analysis
            const recentOutcomes = await this.getRecentNegotiationOutcomes();
            
            // Analyze patterns and update strategies
            const patterns = this.analyzeNegotiationPatterns(recentOutcomes);
            
            // Store learning insights
            const learningUpdate = {
                timestamp: new Date().toISOString(),
                patterns_analyzed: patterns,
                sample_size: recentOutcomes.length,
                success_rate: this.calculateSuccessRate(recentOutcomes),
                most_effective_strategies: this.identifyEffectiveStrategies(recentOutcomes),
                market_insights: this.extractMarketInsights(recentOutcomes),
                personality_insights: this.extractPersonalityInsights(recentOutcomes)
            };
            
            // Store learning data
            localStorage.setItem('negotiation_learning_model', JSON.stringify(learningUpdate));
            console.log('✅ Learning model updated');
            
        } catch (error) {
            console.error('Error updating learning model:', error);
        }
    }

    // Get recent negotiation outcomes for analysis
    async getRecentNegotiationOutcomes() {
        try {
            // Database disabled - use localStorage only
            // const { data: dbOutcomes } = await this.supabase
            //     .from('negotiation_outcomes')
            //     .select('*')
            //     .gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
            //     .order('created_at', { ascending: false })
            //     .limit(100);
            
            // Use localStorage data
            const localOutcomes = JSON.parse(localStorage.getItem('negotiation_outcomes') || '[]');
            return localOutcomes.slice(-30); // Last 30 outcomes
            
        } catch (error) {
            console.error('Error getting recent outcomes:', error);
            return [];
        }
    }

    // Analyze patterns in negotiation outcomes
    analyzeNegotiationPatterns(outcomes) {
        const patterns = {
            success_by_property_type: {},
            success_by_price_range: {},
            success_by_season: {},
            success_by_message_count: {},
            average_negotiation_duration: 0,
            most_effective_strategies: []
        };
        
        if (!outcomes.length) return patterns;
        
        outcomes.forEach(outcome => {
            // Property type analysis
            const propType = outcome.listing_type || 'unknown';
            if (!patterns.success_by_property_type[propType]) {
                patterns.success_by_property_type[propType] = { success: 0, total: 0 };
            }
            patterns.success_by_property_type[propType].total++;
            if (outcome.outcome === 'success') {
                patterns.success_by_property_type[propType].success++;
            }
            
            // Price range analysis
            const priceRange = this.categorizePriceRange(outcome.original_price);
            if (!patterns.success_by_price_range[priceRange]) {
                patterns.success_by_price_range[priceRange] = { success: 0, total: 0 };
            }
            patterns.success_by_price_range[priceRange].total++;
            if (outcome.outcome === 'success') {
                patterns.success_by_price_range[priceRange].success++;
            }
            
            // Duration analysis
            if (outcome.negotiation_duration) {
                patterns.average_negotiation_duration += outcome.negotiation_duration;
            }
        });
        
        patterns.average_negotiation_duration /= outcomes.length;
        
        return patterns;
    }

    // Calculate overall success rate
    calculateSuccessRate(outcomes) {
        if (!outcomes.length) return 0;
        const successCount = outcomes.filter(o => o.outcome === 'success').length;
        return ((successCount / outcomes.length) * 100).toFixed(2);
    }

    // Identify most effective negotiation strategies
    identifyEffectiveStrategies(outcomes) {
        const strategySuccess = {};
        
        outcomes.forEach(outcome => {
            if (outcome.strategies_used && Array.isArray(outcome.strategies_used)) {
                outcome.strategies_used.forEach(strategy => {
                    if (!strategySuccess[strategy]) {
                        strategySuccess[strategy] = { success: 0, total: 0 };
                    }
                    strategySuccess[strategy].total++;
                    if (outcome.outcome === 'success') {
                        strategySuccess[strategy].success++;
                    }
                });
            }
        });
        
        // Calculate success rates and sort
        return Object.entries(strategySuccess)
            .map(([strategy, stats]) => ({
                strategy,
                success_rate: (stats.success / stats.total * 100).toFixed(2),
                sample_size: stats.total
            }))
            .sort((a, b) => parseFloat(b.success_rate) - parseFloat(a.success_rate))
            .slice(0, 5); // Top 5 strategies
    }

    // Extract market insights from outcomes
    extractMarketInsights(outcomes) {
        const insights = {
            best_negotiation_months: [],
            price_flexibility_by_location: {},
            demand_correlation: {}
        };
        
        outcomes.forEach(outcome => {
            if (outcome.created_at && outcome.outcome === 'success') {
                const month = new Date(outcome.created_at).getMonth() + 1;
                insights.best_negotiation_months.push(month);
            }
        });
        
        return insights;
    }

    // Extract personality-based insights
    extractPersonalityInsights(outcomes) {
        const insights = {
            most_responsive_personalities: [],
            communication_preferences: {},
            success_by_personality_type: {}
        };
        
        outcomes.forEach(outcome => {
            if (outcome.landlord_personality) {
                const personalityType = outcome.landlord_personality.type;
                if (!insights.success_by_personality_type[personalityType]) {
                    insights.success_by_personality_type[personalityType] = { success: 0, total: 0 };
                }
                insights.success_by_personality_type[personalityType].total++;
                if (outcome.outcome === 'success') {
                    insights.success_by_personality_type[personalityType].success++;
                }
            }
        });
        
        return insights;
    }

    // Categorize price range for analysis
    categorizePriceRange(price) {
        if (price < 800) return 'budget';
        if (price < 1200) return 'mid_range';
        if (price < 1800) return 'premium';
        return 'luxury';
    }

    // Get learning-based strategy recommendations
    async getStrategyRecommendations(listing, userBudget, marketData) {
        try {
            const learningModel = JSON.parse(localStorage.getItem('negotiation_learning_model') || '{}');
            
            if (!learningModel.most_effective_strategies) {
                return ['balanced_persuasion', 'market_data', 'value_proposition'];
            }
            
            // Filter strategies based on current context
            const priceRange = this.categorizePriceRange(listing.price);
            const recommendations = learningModel.most_effective_strategies
                .filter(strategy => parseFloat(strategy.success_rate) > 60)
                .map(strategy => strategy.strategy)
                .slice(0, 3);
            
            return recommendations.length > 0 ? recommendations : ['balanced_persuasion', 'market_data'];
            
        } catch (error) {
            console.error('Error getting strategy recommendations:', error);
            return ['balanced_persuasion', 'market_data'];
        }
    }

    // Generate final attempt when facing rejection (kept for backward compatibility)
    async generateFinalAttempt(negotiation, listing) {
        try {
            const maxBudget = negotiation.userBudget;
            const marketData = negotiation.marketData || await this.getMarketData(
                listing.city, listing.house_type, listing.bedrooms
            );
            
            const finalOffer = Math.min(maxBudget, Math.round(marketData.average * 0.98));
            
            return `I completely understand your position. As a final offer, I can do $${finalOffer}/month with immediate occupancy and excellent references. I'm a reliable, long-term tenant who takes great care of properties. If this works for you, I'm ready to proceed today. If not, I truly appreciate your time and consideration.`;
            
        } catch (error) {
            console.error('Error generating final attempt:', error);
            return null;
        }
    }

    // Notify when negotiation is complete
    async notifyNegotiationComplete(negotiation, landlordMessage = null) {
        try {
            console.log('📤 Sending negotiation completion notification for user:', negotiation.userEmail);
            
            const landlordReply = landlordMessage ? `\n\n**Landlord's Reply:** "${landlordMessage}"` : '';
            const savings = negotiation.originalPrice - negotiation.finalPrice;
            const savingsText = savings > 0 ? `\nSavings: $${savings}/month` : '';
            
            const notificationData = {
                user_email: negotiation.userEmail,
                conversation_data: JSON.stringify([{
                    role: 'assistant',
                    content: `🎉 **Negotiation Successful!**\n\nProperty: ${negotiation.listingTitle}\nFinal Price: $${negotiation.finalPrice}/month\nOriginal Price: $${negotiation.originalPrice}/month${savingsText}${landlordReply}\n\n✅ The landlord has accepted your offer! Next steps: Contact the landlord to finalize the rental agreement.`
                }]),
                title: `Negotiation Success: ${negotiation.listingTitle}`
            };
            
            console.log('📝 Notification data:', notificationData);
            
            const { data, error } = await this.supabase
                .from('ai_chats')
                .insert(notificationData);
                
            if (error) {
                console.error('❌ Database error:', error);
            } else {
                console.log('✅ Negotiation completion notification sent successfully');
            }
            
        } catch (error) {
            console.error('Error notifying negotiation complete:', error);
        }
    }

    // Notify about landlord reply in real-time
    async notifyLandlordReply(negotiation, landlordMessage, aiResponse = null) {
        try {
            console.log('📢 Notifying user about landlord reply');
            
            const content = `💬 **New Reply from Landlord**\n\nProperty: ${negotiation.listingTitle}\nLandlord said: "${landlordMessage}"${aiResponse ? `\n\nMy response: "${aiResponse}"` : ''}\n\nNegotiation continuing...`;
            
            const { error } = await this.supabase
                .from('ai_chats')
                .insert({
                    user_email: negotiation.userEmail,
                    conversation_data: JSON.stringify([{
                        role: 'assistant',
                        content: content
                    }]),
                    title: `Landlord Reply: ${negotiation.listingTitle}`
                });
                
            if (error) {
                console.error('❌ Error notifying landlord reply:', error);
            } else {
                console.log('✅ Landlord reply notification sent');
            }
            
        } catch (error) {
            console.error('Error notifying landlord reply:', error);
        }
    }

    // Debug function - test negotiation flow
    testNegotiationFlow() {
        console.log('🧪 Testing negotiation flow...');
        console.log('Active negotiations:', this.activeNegotiations);
        console.log('AI user initialized:', this.aiUserInitialized);
        console.log('Supabase connected:', !!this.supabase);
        console.log('OpenAI API key present:', !!this.config?.OPENAI_API_KEY);
        
        // Test simple analysis
        const testNegotiation = {
            userBudget: 1000,
            messages: [{sender: 'ai', content: 'I can offer $950/month'}]
        };
        
        const testResult = this.extractLastOfferedPrice(testNegotiation);
        console.log('Price extraction test:', testResult);
    }

    // Test message handling manually
    async testMessageHandling(testMessage = 'sure') {
        console.log('🧪 Testing message handling with:', testMessage);
        
        // Create test data that matches your scenario
        const testListing = {
            id: 'test-listing-id',
            title: '2 bedroom house in Tehran',
            price: 1000,
            city: 'Tehran',
            house_type: 'House',
            bedrooms: 2,
            user_email: 'landlord@test.com'
        };
        
        const testMessageObj = {
            content: testMessage,
            sender_email: 'user@test.com',
            conversation_id: 'test-conversation-id'
        };
        
        // Create a test negotiation with some history to make it more realistic
        const testConversationId = 'test-conversation-id';
        this.activeNegotiations.set(testConversationId, {
            listingId: testListing.id,
            listingTitle: testListing.title,
            originalPrice: testListing.price,
            userBudget: 950, // User wants it for less
            userEmail: 'user@test.com',
            landlordEmail: testListing.user_email,
            status: 'active',
            startTime: new Date(),
            messages: [{
                sender: 'ai',
                content: 'Would you consider $950/month? I can move in immediately.',
                timestamp: new Date()
            }]
        });
        
        console.log('🧪 Test setup complete, calling handleNegotiationReply...');
        
        try {
            await this.handleNegotiationReply(testMessageObj, testConversationId, testListing);
            console.log('✅ Manual message test completed');
            
            // Check final state
            const finalNegotiation = this.activeNegotiations.get(testConversationId);
            console.log('📊 Final negotiation state:', finalNegotiation);
            
        } catch (error) {
            console.error('❌ Manual message test failed:', error);
        }
    }

    // Detect landlord personality from communication patterns
    detectLandlordPersonality(replyContent, negotiation) {
        const reply = replyContent.toLowerCase();
        const allMessages = negotiation.messages.filter(m => m.sender === 'landlord').map(m => m.content.toLowerCase());
        const fullConversation = allMessages.join(' ') + ' ' + reply;
        
        let personality = {
            type: 'neutral',
            traits: [],
            communicationStyle: 'formal',
            flexibility: 'medium',
            emotionalState: 'neutral'
        };
        
        // Analyze communication style
        if (/lol|haha|😂|😄|casual|btw|omg/i.test(fullConversation)) {
            personality.communicationStyle = 'casual';
            personality.traits.push('informal');
        } else if (/sir|madam|please|thank you|regards|sincerely/i.test(fullConversation)) {
            personality.communicationStyle = 'formal';
            personality.traits.push('professional');
        }
        
        // Analyze flexibility
        if (/not flexible|no negotiation|firm|final|non-negotiable|take it or leave it/i.test(fullConversation)) {
            personality.flexibility = 'low';
            personality.type = 'rigid';
            personality.traits.push('inflexible');
        } else if (/flexible|negotiable|discuss|consider|maybe|depends/i.test(fullConversation)) {
            personality.flexibility = 'high';
            personality.type = 'collaborative';
            personality.traits.push('accommodating');
        }
        
        // Analyze emotional state
        if (/annoyed|frustrated|tired|everyone says that|heard it all/i.test(reply)) {
            personality.emotionalState = 'frustrated';
            personality.traits.push('skeptical');
        } else if (/interested|sounds good|like that|appreciate/i.test(reply)) {
            personality.emotionalState = 'positive';
            personality.traits.push('receptive');
        }
        
        // Detect negotiation experience
        if (/everyone says|heard that before|typical|usual|standard/i.test(reply)) {
            personality.traits.push('experienced');
        }
        
        console.log('🧠 Detected landlord personality:', personality);
        return personality;
    }
    
    // Detect emotional state from recent message
    detectEmotionalState(replyContent) {
        const reply = replyContent.toLowerCase();
        
        if (/lol|haha|great|excellent|perfect|love it/i.test(reply)) {
            return 'positive';
        } else if (/frustrated|annoyed|tired|sick of|enough/i.test(reply)) {
            return 'negative';
        } else if (/maybe|consider|think about|possibly/i.test(reply)) {
            return 'contemplative';
        } else if (/busy|quick|hurry|time/i.test(reply)) {
            return 'rushed';
        }
        
        return 'neutral';
    }
    
    // Analyze negotiation context and history
    analyzeNegotiationContext(negotiation) {
        return {
            roundsOfNegotiation: negotiation.messages.filter(m => m.sender === 'ai').length,
            priceReductions: this.calculatePriceReductions(negotiation),
            timeElapsed: Date.now() - new Date(negotiation.startTime).getTime(),
            marketPosition: this.assessMarketPosition(negotiation),
            userFlexibility: this.assessUserFlexibility(negotiation)
        };
    }
    
    // Calculate how much the price has been reduced
    calculatePriceReductions(negotiation) {
        const originalPrice = negotiation.originalPrice;
        const currentOffer = this.extractLastOfferedPrice(negotiation);
        const reduction = originalPrice - currentOffer;
        const percentageReduction = (reduction / originalPrice) * 100;
        
        return {
            absolute: reduction,
            percentage: Math.round(percentageReduction * 100) / 100,
            significant: percentageReduction > 10
        };
    }
    
    // Assess market position
    assessMarketPosition(negotiation) {
        if (!negotiation.marketData) return 'unknown';
        
        const originalPrice = negotiation.originalPrice;
        const marketAverage = negotiation.marketData.average;
        
        if (originalPrice > marketAverage * 1.2) return 'overpriced';
        if (originalPrice < marketAverage * 0.8) return 'underpriced';
        return 'market_rate';
    }
    
    // Assess user's flexibility
    assessUserFlexibility(negotiation) {
        const budgetFlexibility = (negotiation.userBudget / negotiation.originalPrice) * 100;
        
        if (budgetFlexibility > 90) return 'high';
        if (budgetFlexibility > 70) return 'medium';
        return 'low';
    }

    // Check recent messages to see if we're missing anything
    async checkRecentMessages() {
        try {
            console.log('🔍 Checking recent messages in database...');
            
            const { data: recentMessages, error } = await this.supabase
                .from('messages')
                .select('*')
                .order('created_at', { ascending: false })
                .limit(10);
            
            if (error) {
                console.error('Error fetching recent messages:', error);
                return;
            }
            
            console.log(`Found ${recentMessages.length} recent messages:`);
            recentMessages.forEach((msg, i) => {
                console.log(`${i + 1}. From: ${msg.sender_email} | Content: "${msg.content}" | Time: ${msg.created_at}`);
            });
            
            // Check for recent "sure" messages
            const sureMessages = recentMessages.filter(msg => 
                msg.content.toLowerCase().includes('sure') || 
                msg.content.toLowerCase().includes('yes') ||
                msg.content.toLowerCase().includes('ok')
            );
            
            if (sureMessages.length > 0) {
                console.log('🎯 Found potential acceptance messages:');
                sureMessages.forEach(msg => {
                    console.log(`  - "${msg.content}" from ${msg.sender_email} at ${msg.created_at}`);
                });
            } else {
                console.log('❌ No recent acceptance messages found');
            }
            
        } catch (error) {
            console.error('Error checking recent messages:', error);
        }
    }

    // Generate security deposit response
    generateSecurityDepositResponse(finalPrice, negotiationId, roundNumber) {
        // CRITICAL: Ensure finalPrice is never null/undefined/0
        if (!finalPrice || finalPrice <= 0) {
            console.error('❌ CRITICAL: Invalid finalPrice in security deposit:', finalPrice);
            // Get negotiation to access fallback prices
            const negotiation = this.activeNegotiations.get(negotiationId);
            finalPrice = negotiation?.userBudget || 1500; // Safe fallback
            console.log('✅ Using fallback price for security deposit:', finalPrice);
        }
        
        const templates = this.responseTemplates.securityDepositResponses;
        const responseIndex = roundNumber % templates.length;
        let response = templates[responseIndex];
        
        // Replace price placeholder
        response = response.replace(/\$\$\{price\}/g, finalPrice);
        
        return this.formatMessage(response);
    }

    // Generate move-in logistics response  
    generateMoveInLogisticsResponse(negotiationId, roundNumber) {
        const templates = this.responseTemplates.moveInLogistics;
        const responseIndex = roundNumber % templates.length;
        
        return this.formatMessage(templates[responseIndex]);
    }

    // Generate response to increase requests like "can you raise it"
    generateIncreaseRequestResponse(negotiation, listing, negotiationId, roundNumber) {
        let lastOffer = this.extractLastOfferedPrice(negotiation);
        
        // CRITICAL: Ensure lastOffer is never null/undefined/0
        if (!lastOffer || lastOffer <= 0) {
            console.error('❌ CRITICAL: Invalid lastOffer in increase request, using fallback');
            lastOffer = negotiation.userBudget || listing?.price || 1500;
            console.log('✅ Using fallback price for increase request:', lastOffer);
        }
        
        const userBudget = negotiation.userBudget;
        
        // Calculate a reasonable increase
        const increaseAmount = Math.min(
            userBudget - lastOffer,
            Math.round(lastOffer * 0.03) // 3% increase
        );
        const newOffer = Math.min(userBudget, lastOffer + increaseAmount);
        
        const increaseResponses = [
            `Of course! I can go up to $${newOffer}/month. Would that work for you?`,
            `Absolutely! I can increase my offer to $${newOffer}/month. Is that more in line with what you're looking for?`,
            `Sure thing! How about $${newOffer}/month? I'm flexible and want to make this work.`,
            `Yes, I can do $${newOffer}/month. That's getting close to my maximum but I really like the place.`,
            `I can bump it up to $${newOffer}/month. Would that be acceptable?`,
            `Definitely! I can raise it to $${newOffer}/month. I'm committed to making this work.`
        ];
        
        const responseIndex = roundNumber % increaseResponses.length;
        return this.formatMessage(increaseResponses[responseIndex]);
    }

    // Generate clarification request for vague responses
    generateVagueClarificationResponse(negotiation, listing, negotiationId, roundNumber) {
        let lastOffer = this.extractLastOfferedPrice(negotiation);
        
        // CRITICAL: Ensure lastOffer is never null/undefined/0
        if (!lastOffer || lastOffer <= 0) {
            console.error('❌ CRITICAL: Invalid lastOffer in vague clarification, using fallback');
            lastOffer = negotiation.userBudget || listing?.price || 1500;
            console.log('✅ Using fallback price for vague clarification:', lastOffer);
        }
        
        const clarificationResponses = [
            `I appreciate your response! Just to clarify - what specific price would work for you? I offered $${lastOffer}/month.`,
            `Thanks for considering it! Could you let me know what amount you'd be comfortable with? My last offer was $${lastOffer}/month.`,
            `I want to make sure I understand correctly - are you open to my $${lastOffer}/month offer, or did you have a different amount in mind?`,
            `I'd love to work something out! What price range were you thinking? I proposed $${lastOffer}/month.`,
            `Great to hear you're interested! Could you specify what rent amount would work for you? I suggested $${lastOffer}/month.`,
            `I'm glad you're considering it! What would be a good monthly rent from your perspective? I offered $${lastOffer}/month.`
        ];
        
        const responseIndex = roundNumber % clarificationResponses.length;
        return this.formatMessage(clarificationResponses[responseIndex]);
    }

    // Extract price from any message format
    extractPriceFromMessage(message) {
        const pricePatterns = [
            /\$(\d+)/,           // $1340
            /(\d+)\s*dollars?/i, // 1340 dollars
            /(\d+)\s*\/month/i,  // 1340/month
            /(\d+)\s*per month/i, // 1340 per month
            /(\d+)month/i,       // 3000month (no space)
            /(\d+)\s*month/i     // 3000 month (with space)
        ];
        
        for (const pattern of pricePatterns) {
            const match = message.match(pattern);
            if (match) {
                return parseInt(match[1]);
            }
        }
        return null;
    }

    // AI Learning System Integration Methods
    async buildLearningContext(strategyType, negotiation, listing) {
        try {
            const context = {
                strategyType: strategyType,
                landlordPersonality: negotiation?.landlordPersonality || 'unknown',
                marketConditions: {
                    competitiveness: 'medium',
                    marketTrend: 'stable',
                    pricePosition: 'market_rate'
                },
                priceRange: this.determinePriceRange(listing, negotiation),
                negotiationStage: this.determineNegotiationStage(negotiation),
                timeContext: this.getTimeContext()
            };

            // Enhance with market data if available
            if (this.marketData.has(listing?.id)) {
                const marketInfo = this.marketData.get(listing.id);
                context.marketConditions = this.analyzeMarketConditions(listing, marketInfo);
            }

            return context;
        } catch (error) {
            console.error('Failed to build learning context:', error);
            // Return basic context as fallback
            return {
                strategyType: strategyType,
                landlordPersonality: 'unknown',
                marketConditions: { competitiveness: 'medium' },
                priceRange: 'moderate'
            };
        }
    }

    async recordNegotiationOutcome(conversationId, success, finalPrice, templateUsed, strategyType) {
        if (!this.learningEnabled) return;

        try {
            const negotiation = this.activeNegotiations.get(conversationId);
            if (!negotiation) return;

            const conversationData = {
                id: conversationId,
                messages: negotiation.messageHistory || [],
                success: success,
                finalPrice: finalPrice,
                initialPrice: negotiation.userBudget || 0,
                templateUsed: templateUsed,
                strategyType: strategyType,
                created_at: new Date().toISOString()
            };

            await this.learningSystem.processConversation(conversationData);
            console.log('✅ Recorded negotiation outcome for learning system');
        } catch (error) {
            console.error('❌ Failed to record negotiation outcome:', error);
        }
    }

    determinePriceRange(listing, negotiation) {
        const price = negotiation?.userBudget || listing?.price || 0;
        
        if (price < 1000) return 'budget';
        if (price < 2000) return 'moderate';
        if (price < 3000) return 'premium';
        return 'luxury';
    }

    determineNegotiationStage(negotiation) {
        if (!negotiation?.messageHistory) return 'initial';
        
        const messageCount = negotiation.messageHistory.length;
        if (messageCount <= 2) return 'initial_contact';
        if (messageCount <= 5) return 'exploration';
        if (messageCount <= 10) return 'active_negotiation';
        return 'closing';
    }

    analyzeMarketConditions(listing, marketInfo) {
        const listingPrice = listing?.price || 0;
        const marketAvg = marketInfo?.averagePrice || listingPrice;
        
        let competitiveness = 'medium';
        if (listingPrice > marketAvg * 1.2) {
            competitiveness = 'low'; // Overpriced, less competitive
        } else if (listingPrice < marketAvg * 0.8) {
            competitiveness = 'high'; // Underpriced, very competitive
        }

        return {
            competitiveness: competitiveness,
            marketTrend: marketInfo?.trend || 'stable',
            pricePosition: listingPrice > marketAvg ? 'above_market' : 'below_market'
        };
    }

    getTimeContext() {
        const now = new Date();
        const hour = now.getHours();
        const isWeekend = now.getDay() === 0 || now.getDay() === 6;
        
        return {
            hour: hour,
            isWeekend: isWeekend,
            isBusinessHours: hour >= 9 && hour <= 17 && !isWeekend
        };
    }

    // Enhanced template selection for other strategies
    async selectTemplateWithLearning(strategyType, templates, negotiation, listing) {
        if (!this.learningEnabled) {
            // Fallback to random selection
            return templates[Math.floor(Math.random() * templates.length)];
        }

        try {
            const context = await this.buildLearningContext(strategyType, negotiation, listing);
            const optimalTemplate = await this.learningSystem.getOptimalTemplate(context);
            
            console.log(`🧠 Learning system selected template ${optimalTemplate.templateId} for ${strategyType}: ${optimalTemplate.reason}`);
            
            return templates[optimalTemplate.templateId] || templates[0];
        } catch (error) {
            console.error(`❌ Template selection failed for ${strategyType}, using random:`, error);
            return templates[Math.floor(Math.random() * templates.length)];
        }
    }

    // Method to get learning system performance metrics
    async getLearningMetrics() {
        if (!this.learningEnabled) return null;

        try {
            return await this.learningSystem.getPerformanceMetrics();
        } catch (error) {
            console.error('Failed to get learning metrics:', error);
            return null;
        }
    }

    // Method to trigger learning system optimization
    async optimizeLearningSystem() {
        if (!this.learningEnabled) return;

        try {
            const result = await this.learningSystem.updateLearning();
            console.log('🔄 Learning system optimization completed:', result);
            return result;
        } catch (error) {
            console.error('Learning system optimization failed:', error);
        }
    }

    // Toggle learning system on/off
    toggleLearningSystem(enabled) {
        this.learningEnabled = enabled;
        console.log(`🧠 Learning system ${enabled ? 'ENABLED' : 'DISABLED'}`);
    }

    // Validate OpenAI configuration
    validateOpenAIConfig() {
        console.log('🔧 Validating OpenAI configuration...');
        console.log('🔧 Config object:', {
            hasOpenAIKey: !!this.config?.OPENAI_API_KEY,
            hasOrgId: !!this.config?.OPENAI_ORG_ID,
            model: this.config?.OPENAI_MODEL,
            configKeys: this.config ? Object.keys(this.config) : 'No config'
        });
        
        if (!this.config) {
            console.error('❌ No config object provided to AINegotiationEngine');
            return false;
        }
        
        if (!this.config.OPENAI_API_KEY) {
            console.error('❌ OPENAI_API_KEY missing from config');
            console.error('❌ Available config keys:', Object.keys(this.config));
            return false;
        }
        
        if (this.config.OPENAI_API_KEY.startsWith('sk-')) {
            console.log('✅ OpenAI API key format looks correct');
        } else {
            console.warn('⚠️ OpenAI API key format might be incorrect (should start with sk-)');
        }
        
        console.log('✅ OpenAI configuration validated');
        return true;
    }

    // Test OpenAI API connectivity
    async testOpenAIConnectivity() {
        console.log('🧪 Testing OpenAI API connectivity...');
        console.log('🔑 API Key present:', !!this.config.OPENAI_API_KEY);
        console.log('🔑 API Key preview:', this.config.OPENAI_API_KEY ? this.config.OPENAI_API_KEY.substring(0, 10) + '...' : 'Missing');
        console.log('🔑 Org ID present:', !!this.config.OPENAI_ORG_ID);
        console.log('🔑 Model:', this.config.OPENAI_MODEL || 'gpt-3.5-turbo');
        
        if (!this.config.OPENAI_API_KEY) {
            console.error('❌ OpenAI API key is missing from config');
            return false;
        }

        try {
            const response = await fetch('https://api.openai.com/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.config.OPENAI_API_KEY}`,
                    'OpenAI-Organization': this.config.OPENAI_ORG_ID
                },
                body: JSON.stringify({
                    model: this.config.OPENAI_MODEL || 'gpt-3.5-turbo',
                    messages: [{ role: 'user', content: 'Test connection. Reply with just "OK".' }],
                    max_tokens: 10,
                    temperature: 0
                })
            });

            console.log('🔗 OpenAI API Response Status:', response.status);
            
            if (!response.ok) {
                const errorText = await response.text();
                console.error('❌ OpenAI API test failed:', response.status, errorText);
                return false;
            }

            const data = await response.json();
            console.log('✅ OpenAI API test successful!');
            console.log('📝 Test response:', data.choices[0]?.message?.content);
            return true;

        } catch (error) {
            console.error('❌ OpenAI API test error:', error);
            return false;
        }
    }
}

// Export for use
window.AINegotiationEngine = AINegotiationEngine;