// AI Negotiation Engine
// Handles real-time negotiation with landlords using market data and OpenAI

class AINegotatior {
    constructor(supabase, config) {
        this.supabase = supabase;
        this.config = config;
        this.activeNegotiations = new Map(); // Track ongoing negotiations
        this.marketData = new Map(); // Cache market data
        this.aiUserInitialized = false;
        this.init();
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
        if (this.aiUserInitialized) return true;
        
        try {
            const aiEmail = 'ai-negotiator@roomfinder.com';
            
            // Check if AI user exists - use maybeSingle to avoid 406 errors
            const { data: existingUser, error: checkError } = await this.supabase
                .from('users')
                .select('email')
                .eq('email', aiEmail)
                .maybeSingle();

            if (checkError) {
                console.log('Error checking for existing AI user:', checkError.message);
                // Continue to try creating user
            }

            if (!existingUser) {
                console.log('Creating AI negotiator user...');
                // Try different schema combinations to find what works
                const attempts = [
                    // Attempt 1: Full schema
                    {
                        first_name: 'AI',
                        last_name: 'Negotiator', 
                        email: aiEmail,
                        password_hash: 'ai_user_placeholder_hash',
                        profile_image: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xlIGN4PSIyMCIgY3k9IjIwIiByPSIyMCIgZmlsbD0iIzRiNWU3YSIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IndoaXRlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBkeT0iLjNlbSI+QUk8L3RleHQ+PC9zdmc+'
                    },
                    // Attempt 2: Without password_hash
                    {
                        first_name: 'AI',
                        last_name: 'Negotiator', 
                        email: aiEmail,
                        profile_image: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xlIGN4PSIyMCIgY3k9IjIwIiByPSIyMCIgZmlsbD0iIzRiNWU3YSIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IndoaXRlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBkeT0iLjNlbSI+QUk8L3RleHQ+PC9zdmc+'
                    },
                    // Attempt 3: Minimal schema with ID
                    {
                        id: crypto.randomUUID(),
                        first_name: 'AI',
                        last_name: 'Negotiator', 
                        email: aiEmail
                    },
                    // Attempt 4: Single name field with ID
                    {
                        id: crypto.randomUUID(),
                        name: 'AI Negotiator',
                        email: aiEmail
                    },
                    // Attempt 5: Just email with ID
                    {
                        id: crypto.randomUUID(),
                        email: aiEmail
                    }
                ];

                let created = false;
                for (let i = 0; i < attempts.length && !created; i++) {
                    console.log(`Attempt ${i + 1}: Trying to create AI user with schema:`, Object.keys(attempts[i]));
                    
                    const { error } = await this.supabase
                        .from('users')
                        .insert(attempts[i]);
                    
                    if (!error) {
                        console.log(`✅ AI user created successfully with attempt ${i + 1}`);
                        created = true;
                    } else {
                        console.log(`❌ Attempt ${i + 1} failed:`, error.message);
                    }
                }
                
                if (!created) {
                    console.log('⚠️ Could not create AI user with any schema, continuing anyway...');
                }
            }

            this.aiUserInitialized = true;
            console.log('✅ AI user setup complete');
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
            const marketData = JSON.parse(data.choices[0].message.content.trim());
            
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

    // Generate strategic negotiation message with human psychology
    async generateNegotiationMessage(listing, userBudget, marketData) {
        try {
            console.log('🤖 Generating strategic negotiation message for:', listing.title);

            // Calculate strategic anchor price using negotiation psychology
            const strategicPrice = this.calculateStrategicAnchorPrice(listing.price, userBudget, marketData);
            const personalityStyle = this.selectNegotiationPersonality();
            const urgencyTactic = this.generateUrgencyTactic();
            const valueProposition = this.generateValueProposition();

            const prompt = `You are a highly skilled human rental negotiator with excellent emotional intelligence and proven success closing deals. Generate a personable, strategic negotiation message.

PROPERTY CONTEXT:
- Property: ${listing.title} 
- Asking Price: $${listing.price}/month
- Type: ${listing.house_type}, ${listing.bedrooms} bedrooms
- Location: ${listing.city || 'Not specified'}
- Market Average: $${marketData.average} (${marketData.count} comparable properties)

YOUR STRATEGY:
- Personality Style: ${personalityStyle.style} - ${personalityStyle.description}
- Strategic Anchor: $${strategicPrice}/month (${this.getAnchorJustification(strategicPrice, listing.price, marketData)})
- Value Proposition: ${valueProposition}
- Urgency: ${urgencyTactic}

NEGOTIATION PSYCHOLOGY RULES:
1. ANCHORING: Start with your strategic anchor price with clear market-based justification
2. RECIPROCITY: Offer something valuable in return (quick move-in, long lease, etc.)
3. SOCIAL PROOF: Reference market data or similar successful deals
4. RAPPORT: Show genuine enthusiasm for THIS specific property
5. CONFIDENCE: Be direct but warm - avoid phrases like "I hope" or "maybe"
6. HUMAN TOUCH: Use conversational language, show personality

FORBIDDEN PHRASES (too robotic):
- "Thank you for your message"
- "I'm very interested in the property"  
- "Could you provide more details"
- "I'm a qualified tenant"
- "Are you open to flexibility"

GENERATE: Write as a confident, friendly human who genuinely loves this property. Be direct about your offer. Show personality. 2-3 sentences max.`;

            const response = await fetch('https://api.openai.com/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.config.OPENAI_API_KEY}`,
                    'OpenAI-Organization': this.config.OPENAI_ORG_ID
                },
                body: JSON.stringify({
                    model: this.config.OPENAI_MODEL || 'gpt-4',
                    messages: [{ role: 'system', content: prompt }],
                    max_tokens: 120,
                    temperature: 0.8
                })
            });

            if (!response.ok) {
                throw new Error(`OpenAI API error: ${response.status}`);
            }

            const data = await response.json();
            const message = data.choices[0].message.content.trim();
            
            console.log('✅ Generated strategic negotiation message');
            return message;

        } catch (error) {
            console.error('Error generating negotiation message:', error);
            
            // Strategic fallback with personality
            const strategicPrice = this.calculateStrategicAnchorPrice(listing.price, userBudget, marketData);
            const fallbackMessages = [
                `This ${listing.house_type} caught my eye immediately! Based on similar properties in ${listing.city}, I'd love to offer $${strategicPrice}/month. I can move in next week and take excellent care of the place.`,
                `Wow, this place looks perfect for me! I've been searching for exactly this type of ${listing.house_type} in ${listing.city}. Would $${strategicPrice}/month work? I'm ready to sign today with excellent references.`,
                `Your ${listing.title} is exactly what I've been looking for! Market data shows similar places around $${strategicPrice}/month - I'd be thrilled to pay that and can move in immediately. Deal?`
            ];
            
            return fallbackMessages[Math.floor(Math.random() * fallbackMessages.length)];
        }
    }

    // Calculate strategic anchor price using negotiation psychology
    calculateStrategicAnchorPrice(listingPrice, userBudget, marketData) {
        // Strategic anchoring: Start 10-15% below listing but above your real budget
        const marketBaseline = marketData.average || listingPrice;
        const maxAnchor = Math.min(userBudget * 1.05, listingPrice * 0.85); // Slight buffer above budget
        const minAnchor = Math.max(userBudget * 0.85, marketBaseline * 0.90); // Don't go too low initially
        
        // Use market data to justify the anchor
        if (listingPrice > marketBaseline * 1.1) {
            // Overpriced property - anchor closer to market rate
            return Math.round(Math.min(maxAnchor, marketBaseline * 0.95));
        } else if (listingPrice < marketBaseline * 0.9) {
            // Underpriced property - can anchor closer to listing price
            return Math.round(Math.min(maxAnchor, listingPrice * 0.92));
        } else {
            // Fair market price - anchor in between
            return Math.round((minAnchor + maxAnchor) / 2);
        }
    }

    // Get justification for anchor price
    getAnchorJustification(anchorPrice, listingPrice, marketData) {
        const priceDiff = ((listingPrice - anchorPrice) / listingPrice * 100).toFixed(0);
        const marketDiff = marketData.average ? ((anchorPrice - marketData.average) / marketData.average * 100).toFixed(0) : 0;
        
        if (listingPrice > marketData.average * 1.1) {
            return `${priceDiff}% below asking, based on market average of $${marketData.average}`;
        } else if (marketDiff > 0) {
            return `${Math.abs(marketDiff)}% above market average, showing strong interest`;
        } else {
            return `market-competitive offer based on comparable properties`;
        }
    }

    // Select negotiation personality style
    selectNegotiationPersonality() {
        const personalities = [
            {
                style: "Enthusiastic Professional",
                description: "Confident, excited about the property, direct but warm"
            },
            {
                style: "Strategic Analyzer", 
                description: "Data-driven, market-focused, logical but personable"
            },
            {
                style: "Friendly Straight-shooter",
                description: "Honest, direct, builds quick rapport through authenticity"
            },
            {
                style: "Experienced Renter",
                description: "Knowledgeable about market, confident in value as tenant"
            }
        ];
        
        return personalities[Math.floor(Math.random() * personalities.length)];
    }

    // Generate urgency tactics (subtle, not pushy)
    generateUrgencyTactic() {
        const tactics = [
            "Need to decide this week due to current lease ending",
            "Ready to sign immediately with deposit",
            "Currently viewing several properties, yours is my top choice",
            "Moving from out of state, need quick decision",
            "Have pre-approved finances and references ready"
        ];
        
        return tactics[Math.floor(Math.random() * tactics.length)];
    }

    // Generate value propositions beyond just being "reliable"
    generateValueProposition() {
        const propositions = [
            "Long-term tenant (looking for 2+ year lease)",
            "Work from home, excellent care of property", 
            "No smoking, no pets, minimal wear and tear",
            "Excellent credit score and stable income",
            "Previous landlord references available immediately",
            "Professional who travels frequently (minimal property use)",
            "Willing to handle minor maintenance tasks"
        ];
        
        return propositions[Math.floor(Math.random() * propositions.length)];
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
                
                // Create new negotiation state from this reply
                negotiation = {
                    listingId: listing.id,
                    listingTitle: listing.title,
                    originalPrice: listing.price,
                    userBudget: 1000, // Default from your scenario
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
                            negotiation.finalPrice = analysis.agreedPrice || this.extractLastOfferedPrice(negotiation);
                            console.log('🎉 NEGOTIATION FINALIZED at $', negotiation.finalPrice);
                            
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

    // Enhanced reply analysis with better acceptance detection
    async analyzeReply(replyContent, negotiation, listing) {
        console.log('🔍 Starting enhanced reply analysis for:', replyContent);
        
        // Enhanced acceptance patterns - more comprehensive
        const simpleReply = replyContent.trim().toLowerCase();
        const acceptancePatterns = [
            /^(sure|yes|ok|okay|sounds good|works|fine|agreed|deal|sounds great|yep|yeah|absolutely|perfect|excellent|great)$/i,
            /^(that works|works for me|sounds perfect|i accept|accepted|let's do it|you got it)$/i,
            /^(sure thing|no problem|that's fine|alright|all right)$/i
        ];
        
        const isSimpleAcceptance = acceptancePatterns.some(pattern => pattern.test(simpleReply));
        
        // Also check for contextual acceptance ("sure" after a price offer)
        const hasContextualAcceptance = /\b(sure|yes|ok|okay|sounds good|works|agreed|deal)\b/i.test(simpleReply) && 
                                      simpleReply.length < 20 && // Short replies are often acceptance
                                      !/(too|low|high|can't|cannot|no|not)/i.test(simpleReply);
        
        if (isSimpleAcceptance || hasContextualAcceptance) {
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
                responseStrategy: 'celebrate_and_close',
                suggestedResponse: `🎉 Fantastic! I'm thrilled we agreed on $${lastOffer || negotiation.userBudget}/month. When can we finalize the paperwork?`,
                negotiationPhase: 'closing',
                confidence: 0.95
            };
        }

        try {
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
                "responseStrategy": "accept/counter/negotiate/thank/clarify",
                "suggestedResponse": "brief response if shouldRespond is true",
                "negotiationPhase": "initial/bargaining/closing/rejected"
            }

            ANALYSIS RULES:
            - "sure", "yes", "ok", "sounds good" = acceptance of last offer
            - If they accept: isFinalized=true, agreedPrice=last offered price
            - If they counter with price: extract exact number, shouldRespond=true
            - If they say "market price isn't $X": shouldRespond=true with market data
            - If outright rejection: shouldRespond=true for one final attempt
            - Simple positive words like "sure" mean agreement to last proposal
            - Extract prices carefully: look for $XXX or XXX/month patterns
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
                console.warn('OpenAI API failed, using fallback analysis');
                throw new Error(`OpenAI API error: ${response.status}`);
            }

            const data = await response.json();
            let analysis = JSON.parse(data.choices[0].message.content.trim());
            
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
            
            // Enhanced fallback analysis with psychological insights
            const replyLower = replyContent.toLowerCase().trim();
            const hasPrice = replyContent.match(/\$(\d+[,.]?\d*)/);
            const extractedPrice = hasPrice ? parseFloat(hasPrice[1].replace(',', '')) : null;
            
            // Better sentiment analysis
            const positiveWords = /\b(yes|ok|sure|accept|agree|sounds good|works|fine|deal|great|perfect|excellent|love|like|interested)\b/i;
            const negativeWords = /\b(no|nope|can't|cannot|won't|will not|too low|too high|not|never|impossible|ridiculous)\b/i;
            const neutralWords = /\b(maybe|possibly|consider|think about|let me|hmm|well)\b/i;
            
            let sentiment = 'neutral';
            if (positiveWords.test(replyContent) && !negativeWords.test(replyContent)) {
                sentiment = 'positive';
            } else if (negativeWords.test(replyContent)) {
                sentiment = 'negative';
            }
            
            // Enhanced acceptance detection
            const hasAcceptanceWords = /\b(sure|yes|ok|okay|sounds good|works|fine|agreed|deal|sounds great|perfect|great|excellent)\b/i.test(replyLower);
            const isShortPositive = replyLower.length < 15 && positiveWords.test(replyLower) && !negativeWords.test(replyLower);
            const isAcceptance = (hasAcceptanceWords || isShortPositive) && !hasPrice;
            
            // Detect communication style for adaptation
            const communicationStyle = this.detectCommunicationStyle(replyContent);
            
            console.log('🔧 Enhanced fallback analysis:', {
                hasAcceptanceWords,
                isShortPositive, 
                isAcceptance,
                sentiment,
                communicationStyle,
                extractedPrice
            });
            
            return {
                sentiment: sentiment,
                priceOffered: extractedPrice,
                acceptsOffer: isAcceptance,
                makesCounterOffer: !!extractedPrice,
                shouldRespond: true,
                isFinalized: isAcceptance,
                agreedPrice: isAcceptance ? this.extractLastOfferedPrice(negotiation) : null,
                responseStrategy: isAcceptance ? 'celebrate_and_close' : (extractedPrice ? 'strategic_counter' : 'clarify_and_persuade'),
                negotiationPhase: isAcceptance ? 'closing' : (extractedPrice ? 'bargaining' : 'persuasion'),
                communicationStyle: communicationStyle,
                confidence: isAcceptance ? 0.85 : 0.7
            };
        }
    }

    // Detect landlord communication style for better adaptation
    detectCommunicationStyle(replyContent) {
        const formal = /\b(thank you|please|kindly|regards|sincerely|appreciate)\b/i.test(replyContent);
        const casual = /\b(yeah|yep|nah|gonna|wanna|hey|hi|sup)\b/i.test(replyContent) || /[!]{2,}/.test(replyContent);
        const direct = replyContent.length < 20 && !/\b(please|thank|appreciate|sorry)\b/i.test(replyContent);
        const business = /\b(property|rental|lease|terms|agreement|contract)\b/i.test(replyContent);
        
        if (formal || business) return 'formal';
        if (casual) return 'casual';
        if (direct) return 'direct';
        return 'neutral';
        }
    }

    // Generate strategic counter-response with personality
    async generateCounterResponse(analysis, negotiation, listing) {
        if (!analysis.shouldRespond) return null;

        try {
            if (analysis.isFinalized && analysis.acceptsOffer) {
                const finalPrice = analysis.agreedPrice || this.extractLastOfferedPrice(negotiation);
                console.log('🎉 GENERATING CELEBRATORY ACCEPTANCE RESPONSE - Price:', finalPrice);
                
                // Celebratory responses with personality and clear next steps
                const celebratoryResponses = [
                    `🎉 Amazing! I'm so excited we agreed on $${finalPrice}/month - this place is perfect for me! I have deposit ready and can sign the lease this week. What's our next step?`,
                    `🎉 Fantastic! $${finalPrice}/month it is - I couldn't be happier! I have all documents ready (credit report, references, bank statements). When can we make this official?`,
                    `🎉 Perfect! Thank you for accepting $${finalPrice}/month. This is exactly what I was hoping for! I'm ready with first month's rent and deposit. How should we proceed with the paperwork?`
                ];
                
                return celebratoryResponses[Math.floor(Math.random() * celebratoryResponses.length)];
            }

            if (analysis.makesCounterOffer && analysis.priceOffered) {
                console.log('💰 Generating strategic counter-offer response');
                return await this.generateStrategicCounterOffer(analysis, negotiation, listing);
            }

            if (analysis.sentiment === 'negative') {
                console.log('🔄 Generating persuasive response for negative sentiment');
                return await this.generatePersuasiveResponse(analysis, negotiation, listing);
            }

            // Generate adaptive response based on communication style
            console.log('🎯 Generating adaptive response based on landlord style');
            return await this.generateAdaptiveResponse(analysis, negotiation, listing);

        } catch (error) {
            console.error('Error generating counter-response:', error);
            
            // Intelligent fallback based on analysis
            if (analysis.isFinalized) {
                const finalPrice = analysis.agreedPrice || this.extractLastOfferedPrice(negotiation);
                return `🎉 Perfect! I'm so excited we agreed on $${finalPrice}/month. This place is going to be amazing! When can we make it official?`;
            }
            
            const strategicPrice = Math.min(negotiation.userBudget, Math.round((negotiation.marketData?.average || negotiation.userBudget) * 0.95));
            return `I'm really interested in making this work! How about $${strategicPrice}/month? I can move in immediately and I'll take excellent care of your property.`;
        }
    }

    // Generate strategic counter-offer with psychological tactics
    async generateStrategicCounterOffer(analysis, negotiation, listing) {
        const userBudget = negotiation.userBudget;
        const counterPrice = analysis.priceOffered;
        const marketData = negotiation.marketData;
        const communicationStyle = analysis.communicationStyle || 'neutral';

        // If their counter-offer is within budget - accept enthusiastically
        if (counterPrice <= userBudget * 1.02) { // Small buffer for rounding
            const enthusiasticResponses = [
                `Perfect! $${counterPrice}/month works great for me - you've got a deal! I have deposit ready and can move in next week. When can we sign?`,
                `$${counterPrice}/month is exactly what I was hoping for! I'm ready to proceed immediately with first month and deposit. This is going to work out perfectly!`,
                `That works perfectly! $${counterPrice}/month it is. I'm so excited about this place - when can we make it official?`
            ];
            
            return enthusiasticResponses[Math.floor(Math.random() * enthusiasticResponses.length)];
        }

        // Strategic counter-offer using negotiation psychology
        const strategicCounter = this.calculateStrategicCounter(counterPrice, userBudget, marketData);
        const gap = counterPrice - strategicCounter;
        const personalityStyle = this.selectNegotiationPersonality();
        
        const prompt = `You're an expert negotiator responding to a landlord's counter-offer. Generate a strategic, human-like response.

SITUATION:
- Landlord counter-offered: $${counterPrice}/month
- Your strategic counter: $${strategicCounter}/month  
- Gap to close: $${gap}
- Your max budget: $${userBudget}/month
- Market average: $${marketData.average || 'unknown'}/month
- Landlord communication style: ${communicationStyle}
- Your personality: ${personalityStyle.style}

STRATEGIC GOALS:
1. BRIDGING: Acknowledge their offer positively, then bridge to your counter
2. JUSTIFICATION: Give compelling reason for your counter (market data, budget constraints, value you bring)
3. RECIPROCITY: Offer something valuable in return (longer lease, immediate move, excellent care)
4. URGENCY: Subtle time pressure without being pushy
5. RELATIONSHIP: Build rapport and show you want this to work

TONE: ${this.getCommunicationTone(communicationStyle)}

AVOID: Generic phrases, robotic language, weak justifications

Write a confident, warm response that makes your counter-offer compelling. 2-3 sentences max.`;

        try {
            const response = await fetch('https://api.openai.com/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.config.OPENAI_API_KEY}`,
                    'OpenAI-Organization': this.config.OPENAI_ORG_ID
                },
                body: JSON.stringify({
                    model: this.config.OPENAI_MODEL || 'gpt-4',
                    messages: [{ role: 'system', content: prompt }],
                    max_tokens: 120,
                    temperature: 0.8
                })
            });

            if (response.ok) {
                const data = await response.json();
                return data.choices[0].message.content.trim();
            }
        } catch (error) {
            console.error('Error generating strategic counter-offer:', error);
        }

        // Fallback strategic response
        const valueOffers = [
            "I can move in immediately and sign a longer lease",
            "I'll take excellent care of the property and handle minor maintenance", 
            "I can provide first month + security deposit upfront",
            "I'm looking for a long-term rental (2+ years)"
        ];
        
        const selectedValue = valueOffers[Math.floor(Math.random() * valueOffers.length)];
        const justification = marketData && counterPrice > marketData.average ? 
            ` Given the market average is around $${marketData.average},` : '';
            
        return `I appreciate your counter-offer of $${counterPrice}!${justification} How about we meet in the middle at $${strategicCounter}/month? ${selectedValue} and I'm genuinely excited about this place!`;
    }

    // Calculate strategic counter-offer price
    calculateStrategicCounter(theirOffer, maxBudget, marketData) {
        // Never go over budget
        const absoluteMax = maxBudget;
        
        // Try to split the difference, but weighted toward your favor
        const lastOffer = this.getLastOfferFromNegotiation() || maxBudget * 0.9;
        const weightedMiddle = Math.round((theirOffer * 0.3) + (lastOffer * 0.7));
        
        // Ensure it's reasonable and within budget
        return Math.min(absoluteMax, Math.max(lastOffer + 50, weightedMiddle));
    }
    
    // Get last offer from negotiation history (placeholder - would need actual implementation)
    getLastOfferFromNegotiation() {
        // This would extract the last price offered by the AI
        // For now, return null to use fallback logic
        return null;
    }

    // Generate persuasive response for negative sentiment  
    async generatePersuasiveResponse(analysis, negotiation, listing) {
        const marketData = negotiation.marketData || await this.getMarketData(
            listing.city, listing.house_type, listing.bedrooms
        );
        
        const strategicOffer = Math.min(
            negotiation.userBudget, 
            Math.round(marketData.average * 0.97)
        );
        
        const communicationStyle = analysis.communicationStyle || 'neutral';
        const originalMessage = analysis.originalMessage || 'previous offer';
        
        const prompt = `The landlord rejected your offer with negative sentiment. Generate a persuasive response that turns this around.

CONTEXT:
- Landlord's rejection: "${originalMessage}"
- Communication style: ${communicationStyle}
- Your strategic final offer: $${strategicOffer}/month
- Market average: $${marketData.average}/month
- Property: ${listing.title} (${listing.house_type})

PERSUASION STRATEGY:
1. ACKNOWLEDGE: Respect their position without being defensive
2. REFRAME: Present new perspective or value proposition
3. MARKET DATA: Use data to support your position (if property is overpriced)
4. VALUE: Emphasize unique value you bring as tenant
5. FINAL OFFER: Make this feel like your best and final offer
6. URGENCY: Create gentle time pressure

PSYCHOLOGY:
- Use "yes, and..." instead of "but"
- Appeal to their desire for a reliable, long-term tenant
- Show you understand their business needs
- Make them feel smart for choosing you

TONE: ${this.getCommunicationTone(communicationStyle)}

Write a compelling response that addresses their concerns and makes your final offer irresistible. 3-4 sentences max.`;

        try {
            const response = await fetch('https://api.openai.com/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.config.OPENAI_API_KEY}`,
                    'OpenAI-Organization': this.config.OPENAI_ORG_ID
                },
                body: JSON.stringify({
                    model: this.config.OPENAI_MODEL || 'gpt-4',
                    messages: [{ role: 'system', content: prompt }],
                    max_tokens: 140,
                    temperature: 0.8
                })
            });

            if (response.ok) {
                const data = await response.json();
                return data.choices[0].message.content.trim();
            }
        } catch (error) {
            console.error('Error generating persuasive response:', error);
        }

        // Fallback persuasive response with personality
        const persuasiveMessages = [
            `I completely understand - you want the best value for your property! Based on current market rates for ${listing.house_type}s in ${listing.city} (averaging $${marketData.average}), I'd love to offer $${strategicOffer}/month as my final offer. I'm the kind of tenant who'll treat your place like my own and stay long-term. What do you think?`,
            `You're absolutely right to want fair market value! Looking at comparable properties in ${listing.city}, $${strategicOffer}/month would be competitive and I can guarantee you'll have zero headaches with me as a tenant. I'm ready to move in this week and plan to stay for years. Deal?`,
            `I hear you, and I want this to work for both of us! My research shows similar properties averaging $${marketData.average}/month, so $${strategicOffer} feels fair for both sides. Plus you're getting a reliable, long-term tenant who takes excellent care of properties. Sound good?`
        ];
        
        return persuasiveMessages[Math.floor(Math.random() * persuasiveMessages.length)];
    }

    // Generate adaptive response based on landlord communication style
    async generateAdaptiveResponse(analysis, negotiation, listing) {
        const communicationStyle = analysis.communicationStyle || 'neutral';
        const sentiment = analysis.sentiment;
        const marketData = negotiation.marketData;
        const strategicPrice = Math.min(negotiation.userBudget, Math.round(marketData.average * 0.95));
        
        const prompt = `Generate an adaptive response that matches the landlord's communication style and sentiment.

CONTEXT:
- Landlord communication style: ${communicationStyle}
- Landlord sentiment: ${sentiment} 
- Property: ${listing.title} ($${listing.price}/month)
- Your strategic price: $${strategicPrice}/month
- Market data: $${marketData.average}/month average
- Phase: ${analysis.negotiationPhase}

ADAPTATION RULES:
- If FORMAL style: Be professional, use proper grammar, respectful language
- If CASUAL style: Be friendly, use relaxed language, maybe light humor
- If DIRECT style: Be concise, straightforward, no fluff
- If BUSINESS style: Focus on practical aspects, ROI, professional relationship

STRATEGY based on sentiment:
- POSITIVE: Build on momentum, suggest moving forward
- NEUTRAL: Provide compelling reasons to engage
- NEGATIVE: Address concerns, reframe perspective

TONE: ${this.getCommunicationTone(communicationStyle)}

Write a response that feels natural for this landlord's style while advancing the negotiation. 2-3 sentences max.`;

        try {
            const response = await fetch('https://api.openai.com/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.config.OPENAI_API_KEY}`,
                    'OpenAI-Organization': this.config.OPENAI_ORG_ID
                },
                body: JSON.stringify({
                    model: this.config.OPENAI_MODEL || 'gpt-4',
                    messages: [{ role: 'system', content: prompt }],
                    max_tokens: 100,
                    temperature: 0.8
                })
            });

            if (response.ok) {
                const data = await response.json();
                return data.choices[0].message.content.trim();
            }
        } catch (error) {
            console.error('Error generating adaptive response:', error);
        }
        
        // Style-specific fallback responses
        const fallbackResponses = {
            formal: `I appreciate your consideration of my inquiry. Based on current market analysis showing similar properties at $${marketData.average}/month, would $${strategicPrice}/month be acceptable? I am prepared to proceed expeditiously with all necessary documentation.`,
            casual: `Hey, I really love this place! I've been looking at similar spots and they're going for around $${strategicPrice}/month. Would that work for you? I can move in super quick and I'm pretty low-maintenance!`,
            direct: `$${strategicPrice}/month. Market rate. Ready to sign today. Deal?`,
            business: `Given comparable properties average $${marketData.average}/month in this market, $${strategicPrice}/month represents fair value for both parties. I offer reliable tenancy and immediate occupancy. Shall we proceed?`
        };
        
        return fallbackResponses[communicationStyle] || fallbackResponses.formal;
    }
    
    // Get communication tone guidance based on style
    getCommunicationTone(style) {
        const tones = {
            formal: "Professional, respectful, proper grammar, courteous",
            casual: "Friendly, relaxed, conversational, maybe light humor", 
            direct: "Concise, straightforward, no-nonsense, brief",
            business: "Practical, focused on value and ROI, professional",
            neutral: "Balanced, polite but not overly formal, clear"
        };
        
        return tones[style] || tones.neutral;
    }

    // Send negotiation message
    async sendNegotiationMessage(conversationId, message, userEmail) {
        try {
            // Ensure AI user exists first
            await this.ensureAIUserExists();
            
            const senderEmail = 'ai-negotiator@roomfinder.com';
            
            const { error } = await this.supabase
                .from('messages')
                .insert({
                    conversation_id: conversationId,
                    sender_email: senderEmail,
                    content: `🤖 AI Negotiator on behalf of ${userEmail}:\n\n${message}`
                });

            if (error) {
                console.error('Error sending negotiation message with AI email:', error);
                
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
                    console.log('🔔 [AI NEGOTIATION] New message received:', newMessage);
                    console.log('🔔 Message sender:', newMessage.sender_email);
                    console.log('🔔 Message content:', newMessage.content);
                    
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
                        
                        // Check if this conversation involves the AI negotiator
                        // Look for either direct AI involvement OR check if recent messages were from AI
                        let isAIConversation = conversation && (
                            conversation.sender_email === 'ai-negotiator@roomfinder.com' || 
                            conversation.receiver_email === 'ai-negotiator@roomfinder.com'
                        );
                        
                        // If not directly AI conversation, check if AI has sent messages in this conversation
                        if (!isAIConversation && conversation) {
                            console.log('📨 Checking for AI messages in this conversation...');
                            const { data: aiMessages } = await this.supabase
                                .from('messages')
                                .select('*')
                                .eq('conversation_id', conversation.id)
                                .or('sender_email.eq.ai-negotiator@roomfinder.com,content.ilike.%AI Negotiator on behalf%')
                                .limit(5);
                            
                            if (aiMessages && aiMessages.length > 0) {
                                console.log('📨 Found AI messages in conversation:', aiMessages.length);
                                isAIConversation = true;
                            }
                        }
                        
                        console.log('📨 Is AI conversation?', isAIConversation);
                        
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
    async startNegotiation(listing, userBudget, userEmail) {
        try {
            console.log('🚀 Starting negotiation for:', listing.title);

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
            
            this.activeNegotiations.set(negotiationId, {
                listingId: listing.id,
                listingTitle: listing.title,
                originalPrice: listing.price,
                userBudget: userBudget,
                userEmail: userEmail,
                landlordEmail: listing.user_email,
                marketData: marketData,
                status: 'active',
                startTime: new Date(),
                messages: [{
                    sender: 'ai',
                    content: message,
                    timestamp: new Date()
                }]
            });

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
            // Look through AI messages for price offers
            const aiMessages = negotiation.messages.filter(m => m.sender === 'ai');
            
            for (let i = aiMessages.length - 1; i >= 0; i--) {
                const message = aiMessages[i].content;
                const priceMatch = message.match(/\$(\d+)\/month|\$(\d+) per month|\$(\d+)\s*monthly/i);
                if (priceMatch) {
                    return parseInt(priceMatch[1] || priceMatch[2] || priceMatch[3]);
                }
            }
            
            // Fallback to user budget if no specific price found
            return negotiation.userBudget;
        } catch (error) {
            console.error('Error extracting last offered price:', error);
            return negotiation.userBudget;
        }
    }

    // Generate market-based negotiation response to rejections
    async generateMarketBasedNegotiation(negotiation, listing, landlordMessage, analysis) {
        try {
            const marketData = negotiation.marketData || await this.getMarketData(
                listing.city, listing.house_type, listing.bedrooms
            );
            
            console.log('🏠 Using market data for negotiation:', marketData);
            
            const prompt = `
            You are an expert rental negotiator responding to a landlord who has rejected or objected to your offer. Generate a persuasive, professional response that uses market data strategically.

            LANDLORD'S REJECTION: "${landlordMessage}"
            
            PROPERTY DETAILS:
            - Property: ${listing.title}
            - Current asking price: $${listing.price}/month
            - Type: ${listing.house_type}
            - Bedrooms: ${listing.bedrooms}
            - Location: ${listing.city}
            
            MARKET DATA:
            - Average market price: $${marketData.average}/month
            - Price range: $${marketData.min} - $${marketData.max}
            - Number of comparable properties: ${marketData.count}
            - Data source: ${marketData.source}
            
            YOUR USER'S BUDGET: $${negotiation.userBudget}/month
            
            NEGOTIATION CONTEXT:
            - This is ${negotiation.finalAttempt ? 'a final attempt' : 'an active negotiation'}
            - Previous conversation: ${negotiation.messages.slice(-2).map(m => `${m.sender}: ${m.content}`).join(' | ')}
            
            RESPONSE STRATEGY:
            1. Acknowledge their concerns respectfully
            2. Present market data as evidence (if asking price is above market average)
            3. Emphasize your value as a tenant (reliability, immediate move-in, excellent care)
            4. Make a strategic counter-offer based on market data and budget
            5. Create urgency without being pushy
            6. Keep it professional and concise (3-4 sentences max)
            
            PRICING LOGIC:
            - If their price is above market average: Justify lower price with market data
            - If market supports their price: Offer value-adds (longer lease, maintenance, etc.)
            - If they rejected based on price: Focus on tenant quality and reliability
            - Always stay within user's budget of $${negotiation.userBudget}
            
            Generate ONLY the response message (no greetings or signatures):
            `;

            const response = await fetch('https://api.openai.com/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.config.OPENAI_API_KEY}`,
                    'OpenAI-Organization': this.config.OPENAI_ORG_ID
                },
                body: JSON.stringify({
                    model: this.config.OPENAI_MODEL || 'gpt-4',
                    messages: [{ role: 'system', content: prompt }],
                    max_tokens: 200,
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
}

// Export for use
window.AINegotatior = AINegotatior;