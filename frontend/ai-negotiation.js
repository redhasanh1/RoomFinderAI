 // AI Negotiation Engine
// Handles real-time negotiation with landlords using market data and OpenAI

class AINegotiator {
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
            console.warn('⚠️ OpenAI market analysis unavailable, using estimates');

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

    // Generate intelligent negotiation message
    async generateNegotiationMessage(listing, userBudget, marketData) {
        try {
            console.log('🤖 Generating negotiation message for:', listing.title);

            const prompt = `
            You are an expert rental negotiator. Generate a professional negotiation message for this rental:

            LISTING DETAILS:
            - Title: ${listing.title}
            - Current Price: $${listing.price}/month
            - Type: ${listing.house_type}
            - Bedrooms: ${listing.bedrooms}
            - Location: ${listing.city || 'Not specified'}
            - Utilities: ${listing.utilities}

            USER REQUIREMENTS:
            - Budget: $${userBudget}
            - Looking for: ${listing.house_type}

            MARKET DATA:
            - Average market price: $${marketData.average}
            - Market range: $${marketData.min} - $${marketData.max}
            - Data source: ${marketData.source}
            - Analysis: ${marketData.analysis || 'Standard market conditions'}

            NEGOTIATION STRATEGY:
            1. Be professional and respectful
            2. Express genuine interest in the property
            3. Mention you're a qualified tenant ready to move quickly
            4. If listing price is above market average or user budget, suggest a lower price with justification
            5. Offer quick decision-making and reliable tenancy
            6. Keep message concise (2-3 sentences max)

            PRICING LOGIC:
            - If listing price > market average: Suggest price closer to market average
            - If listing price > user budget: Suggest price within budget
            - If listing price is fair: Express interest and ask about flexibility

            Generate ONLY the message content (no "Dear" or signatures):
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
            const message = data.choices[0].message.content.trim();
            
            console.log('✅ Generated negotiation message');
            return message;

        } catch (error) {
            console.warn('⚠️ OpenAI unavailable (CORS/network issue), using template message');

            // Fallback message - always works
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
                console.log('⚠️ No active negotiation found, reconstructing from database...');

                // Try to get user email and budget from conversation and localStorage
                let userEmail = 'user@example.com'; // Default fallback
                let userBudget = null; // Will be calculated dynamically
                let previousMessages = [];

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

                    // CRITICAL: Fetch ALL previous messages to reconstruct negotiation history
                    const { data: messages, error: msgError } = await this.supabase
                        .from('messages')
                        .select('*')
                        .eq('conversation_id', conversationId)
                        .order('created_at', { ascending: true });

                    if (!msgError && messages) {
                        previousMessages = messages;
                        console.log('📜 Found', previousMessages.length, 'previous messages in conversation');
                    }
                } catch (error) {
                    console.log('Could not fetch conversation details:', error.message);
                }

                // Extract offers already made from previous messages
                const offersMade = [];
                const landlordCounters = [];
                let lastOffer = null;
                let rejectionCount = 0;
                const reconstructedMessages = [];

                for (const msg of previousMessages) {
                    const isAI = msg.sender_email === 'ai-negotiator@roomfinder.com' ||
                                 msg.content?.includes('AI Negotiator');

                    // Extract prices from message
                    const priceMatches = msg.content?.match(/\$(\d+)/g) || [];
                    const prices = priceMatches.map(p => parseInt(p.replace('$', '')));

                    if (isAI && prices.length > 0) {
                        // AI made an offer - track all prices mentioned
                        for (const price of prices) {
                            if (!offersMade.includes(price)) {
                                offersMade.push(price);
                            }
                        }
                        lastOffer = prices[prices.length - 1]; // Last price in message
                    } else if (!isAI && prices.length > 0) {
                        // Landlord mentioned a price - might be counter-offer
                        for (const price of prices) {
                            if (!landlordCounters.includes(price)) {
                                landlordCounters.push(price);
                            }
                        }
                    }

                    // Check for rejection words in landlord messages
                    if (!isAI) {
                        const msgLower = msg.content?.toLowerCase() || '';
                        if (/\b(no|nope|can't|cannot|won't|too low|not possible)\b/.test(msgLower)) {
                            rejectionCount++;
                        }
                    }

                    reconstructedMessages.push({
                        sender: isAI ? 'ai' : 'landlord',
                        content: msg.content,
                        timestamp: new Date(msg.created_at)
                    });
                }

                console.log('📊 Reconstructed negotiation history:');
                console.log('   - Offers we made:', offersMade);
                console.log('   - Last offer:', lastOffer);
                console.log('   - Landlord counters:', landlordCounters);
                console.log('   - Rejection count:', rejectionCount);

                // Try to get user budget from localStorage
                try {
                    const savedBudget = localStorage.getItem('ai_negotiation_budget');
                    if (savedBudget) {
                        userBudget = parseInt(savedBudget);
                        console.log('📊 Retrieved budget from localStorage:', userBudget);
                    }
                } catch (e) {
                    console.log('Could not retrieve budget from localStorage');
                }

                // If no saved budget, use the HIGHEST offer we've made as our budget baseline
                // This prevents going backwards in negotiation
                if (!userBudget) {
                    if (offersMade.length > 0) {
                        userBudget = Math.max(...offersMade);
                        console.log('📊 Using highest previous offer as budget baseline:', userBudget);
                    } else {
                        // Fallback: calculate from listing price
                        userBudget = Math.round(listing.price * 0.82);
                        console.log('📊 Calculated budget from listing price:', userBudget);
                    }
                }

                // Create negotiation state with RECONSTRUCTED history
                negotiation = {
                    listingId: listing.id,
                    listingTitle: listing.title,
                    originalPrice: listing.price,
                    userBudget: userBudget,
                    userEmail: userEmail,
                    landlordEmail: listing.user_email,
                    status: 'active',
                    startTime: new Date(),
                    messages: reconstructedMessages,
                    // Enhanced state tracking - RECONSTRUCTED from history
                    negotiationState: {
                        offersMade: offersMade,
                        offersRejected: rejectionCount,
                        lastOffer: lastOffer || userBudget,
                        landlordCounters: landlordCounters,
                        tacticsUsed: [], // Can't reconstruct this, start fresh
                        concessionCount: offersMade.length > 0 ? offersMade.length - 1 : 0,
                        maxConcessions: 4,
                        currentPhase: rejectionCount > 0 ? 'bargaining' : 'opening'
                    }
                };
                this.activeNegotiations.set(conversationId, negotiation);
                console.log('✅ Negotiation state reconstructed successfully');
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

                                const existingBackups = JSON.parse(localStorage.getItem('negotiation_backups') || '[]');
                                existingBackups.push(backupData);
                                // Keep only last 10 items
                                if (existingBackups.length > 10) {
                                    existingBackups.splice(0, existingBackups.length - 10);
                                }
                                localStorage.setItem('negotiation_backups', JSON.stringify(existingBackups));
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

    // Analyze landlord's reply
    async analyzeReply(replyContent, negotiation, listing) {
        console.log('🔍 Starting reply analysis for:', replyContent);
        
        // First check for simple acceptance patterns IMMEDIATELY
        const simpleReply = replyContent.trim().toLowerCase();
        const isSimpleAcceptance = /^(sure|yes|ok|okay|sounds good|works|fine|agreed|deal|sounds great|yep|yeah|absolutely)$/i.test(simpleReply);
        
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
                negotiationPhase: 'closing'
            };
        }

        try {
            const lastAIMessage = negotiation.messages
                .filter(m => m.sender === 'ai')
                .pop();

            // Build FULL conversation history for context
            const fullHistory = negotiation.messages.map(m => `${m.sender.toUpperCase()}: ${m.content}`).join('\n');

            // Get negotiation state
            const state = negotiation.negotiationState || {
                offersMade: [],
                lastOffer: negotiation.userBudget,
                offersRejected: 0
            };

            const prompt = `
            Analyze this landlord reply in a rental negotiation.

            ===== LANDLORD'S REPLY =====
            "${replyContent}"

            ===== FULL CONVERSATION HISTORY =====
            ${fullHistory || 'First exchange'}

            ===== NEGOTIATION STATE =====
            - Original listing price: $${listing.price}
            - Our budget: $${negotiation.userBudget}
            - Last offer we made: $${state.lastOffer}
            - All offers we've made: ${state.offersMade.join(', ') || 'None yet'}
            - Times rejected: ${state.offersRejected}
            - Current status: ${negotiation.status}

            ===== LAST AI MESSAGE =====
            "${lastAIMessage?.content || 'Initial contact'}"

            Analyze and return JSON:
            {
                "sentiment": "positive/neutral/negative",
                "priceOffered": null or number (extract any $ amount they mention),
                "acceptsOffer": true/false,
                "makesCounterOffer": true/false,
                "shouldRespond": true/false,
                "isFinalized": true/false,
                "agreedPrice": null or number,
                "responseStrategy": "accept/counter/negotiate/thank/clarify",
                "suggestedResponse": "brief response if shouldRespond is true",
                "negotiationPhase": "initial/bargaining/closing/rejected"
            }

            CRITICAL ANALYSIS RULES:
            1. ACCEPTANCE DETECTION:
               - "sure", "yes", "ok", "okay", "sounds good", "deal", "fine", "agreed" = ACCEPTANCE
               - If accepted: isFinalized=true, agreedPrice=${state.lastOffer}

            2. COUNTER-OFFER DETECTION:
               - Look for any price mention: "$1100", "1100/month", "eleven hundred"
               - If they give a number: makesCounterOffer=true, priceOffered=that number

            3. REJECTION DETECTION:
               - "no", "can't do that", "too low", "not possible" = rejection
               - shouldRespond=true (we should try a different approach)

            4. NEVER assume rejection if they're just discussing or asking questions

            5. Extract prices carefully - any $ or number followed by "month" or "per month"
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

            console.log('📊 AI Analysis result:', analysis);
            return analysis;

        } catch (error) {
            console.error('Error with AI analysis, using enhanced fallback:', error);

            // Get negotiation state for proper tracking
            const state = negotiation.negotiationState || { lastOffer: negotiation.userBudget, offersMade: [] };

            // Enhanced fallback analysis with better detection
            const replyLower = replyContent.toLowerCase().trim();
            const hasPrice = replyContent.match(/\$(\d+)/);
            const priceValue = hasPrice ? parseInt(hasPrice[1]) : null;

            // Acceptance detection
            const hasAcceptanceWords = /\b(sure|yes|ok|okay|sounds good|works|fine|agreed|deal|sounds great|perfect|great|excellent|absolutely|yep|yeah)\b/i.test(replyLower);

            // Rejection detection
            const hasRejectionWords = /\b(no|nope|can't|cannot|won't|too low|not possible|firm|fixed|non-negotiable)\b/i.test(replyLower);

            // Question/discussion detection (not rejection)
            const isDiscussion = /\?|what if|how about|consider|maybe|perhaps/i.test(replyContent);

            console.log('🔧 Fallback analysis - acceptance:', hasAcceptanceWords, 'rejection:', hasRejectionWords, 'discussion:', isDiscussion);

            // Determine sentiment
            let sentiment = 'neutral';
            if (hasAcceptanceWords && !hasRejectionWords) sentiment = 'positive';
            else if (hasRejectionWords && !isDiscussion) sentiment = 'negative';

            // Get the last offer we made for acceptance tracking
            const lastOffer = state.lastOffer || this.extractLastOfferedPrice(negotiation);

            return {
                sentiment: sentiment,
                priceOffered: priceValue,
                acceptsOffer: hasAcceptanceWords && !hasPrice && !hasRejectionWords,
                makesCounterOffer: !!hasPrice,
                shouldRespond: true,
                isFinalized: hasAcceptanceWords && !hasPrice && !hasRejectionWords,
                agreedPrice: (hasAcceptanceWords && !hasPrice && !hasRejectionWords) ? lastOffer : null,
                responseStrategy: hasAcceptanceWords ? 'thank' : (hasPrice ? 'counter' : (hasRejectionWords ? 'negotiate' : 'clarify')),
                negotiationPhase: hasAcceptanceWords ? 'closing' : (hasRejectionWords ? 'bargaining' : 'bargaining')
            };
        }
    }

    // Generate counter-response
    async generateCounterResponse(analysis, negotiation, listing) {
        if (!analysis.shouldRespond) return null;

        try {
            if (analysis.isFinalized && analysis.acceptsOffer) {
                const finalPrice = analysis.agreedPrice || this.extractLastOfferedPrice(negotiation);
                console.log('🎉 GENERATING FINAL ACCEPTANCE RESPONSE - Price:', finalPrice);
                return `🎉 Excellent! Thank you for accepting the $${finalPrice}/month offer. I'm thrilled to move forward with this rental! I'm a reliable tenant ready to proceed immediately. Could you please let me know the next steps for finalizing the rental agreement? I have excellent references and can complete all necessary paperwork promptly. Looking forward to hearing from you soon!`;
            }

            if (analysis.makesCounterOffer && analysis.priceOffered) {
                console.log('💰 Generating counter-offer response');
                return await this.generateAdvancedCounterOffer(analysis, negotiation, listing);
            }

            if (analysis.sentiment === 'negative' || analysis.responseStrategy === 'clarify') {
                console.log('🔄 Generating market-based response for negative sentiment');
                return await this.generateMarketBasedResponse(negotiation, listing);
            }

            // Use AI to generate contextual response
            console.log('🤖 Generating contextual response');
            return await this.generateContextualResponse(analysis, negotiation, listing);

        } catch (error) {
            console.error('Error generating counter-response:', error);
            return "Thank you for your response. I'm very interested in moving forward with this rental and I'm flexible on terms.";
        }
    }

    // Generate advanced counter-offer with market analysis and psychological tactics
    async generateAdvancedCounterOffer(analysis, negotiation, listing) {
        const userBudget = negotiation.userBudget;
        const counterPrice = analysis.priceOffered;
        const marketData = negotiation.marketData;

        // Get or initialize state
        const state = negotiation.negotiationState || {
            offersMade: [],
            lastOffer: userBudget,
            concessionCount: 0,
            landlordCounters: []
        };

        // Track landlord's counter-offer
        if (!state.landlordCounters) state.landlordCounters = [];
        state.landlordCounters.push(counterPrice);

        // If counter is within budget, accept with enthusiasm
        if (counterPrice <= userBudget) {
            // Update state
            if (!negotiation.negotiationState) negotiation.negotiationState = state;
            negotiation.negotiationState.lastOffer = counterPrice;

            return `$${counterPrice}/month? Done. I'm ready to sign today. When can we finalize this?`;
        }

        // Calculate our counter using incremental concession strategy
        // Don't just offer 92% of their counter - make strategic increments from our last offer
        const lastOffer = state.lastOffer || userBudget;
        const increments = [50, 25, 15, 10]; // Decreasing increments show we're reaching our limit
        const increment = increments[Math.min(state.concessionCount, increments.length - 1)];

        // Our new offer: last offer + small increment, but never exceed budget or their counter
        let newOffer = Math.min(lastOffer + increment, userBudget, counterPrice);

        // Don't repeat the exact same offer
        if (state.offersMade.includes(newOffer)) {
            newOffer = Math.min(newOffer + 5, userBudget);
        }

        // Update state
        if (!negotiation.negotiationState) negotiation.negotiationState = state;
        negotiation.negotiationState.lastOffer = newOffer;
        negotiation.negotiationState.offersMade.push(newOffer);
        negotiation.negotiationState.concessionCount++;

        console.log('📊 Counter-offer strategy: Their offer $', counterPrice, '-> Our counter $', newOffer);
        console.log('📊 Concession #', negotiation.negotiationState.concessionCount, ', increments left:', increments.length - state.concessionCount);

        // Use different tactics based on concession count
        if (state.concessionCount === 0) {
            // First counter - use labeling + market data
            let response = `$${counterPrice}... I hear you.`;
            if (marketData && counterPrice > marketData.average) {
                response += ` Looking at comparable ${listing.house_type}s averaging $${marketData.average}, would $${newOffer} work?`;
            } else {
                response += ` How about we meet at $${newOffer}? I'm ready to sign immediately.`;
            }
            return response;

        } else if (state.concessionCount === 1) {
            // Second counter - use calibrated question
            return `How am I supposed to make $${counterPrice} work? I can stretch to $${newOffer} - that's genuinely my limit. What would it take?`;

        } else if (state.concessionCount === 2) {
            // Third counter - use loss aversion
            return `I can do $${newOffer}. I'm ready to sign today with references in hand. If I walk, you're back to showings and no-shows. Can we make this work?`;

        } else {
            // Final attempts - accusation audit + firm stance
            return `You probably think I'm being difficult. I get it. But $${newOffer} is genuinely where I am. A guaranteed tenant today vs. an uncertain wait - what do you say?`;
        }
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

    // Generate contextual response using AI with psychological tactics
    async generateContextualResponse(analysis, negotiation, listing) {
        try {
            // Build full conversation history
            const fullHistory = negotiation.messages.map(m => `${m.sender.toUpperCase()}: ${m.content}`).join('\n');

            // Get negotiation state
            const state = negotiation.negotiationState || {
                offersMade: [],
                lastOffer: negotiation.userBudget,
                tacticsUsed: [],
                concessionCount: 0
            };

            // Choose tactic based on phase and what's been used
            let tacticToUse = 'calibrated_question';
            if (analysis.negotiationPhase === 'opening') {
                tacticToUse = 'labeling';
            } else if (analysis.sentiment === 'neutral') {
                tacticToUse = 'loss_aversion';
            }

            // Avoid repeating tactics
            const usedTactics = state.tacticsUsed || [];
            if (usedTactics.includes(tacticToUse)) {
                const allTactics = ['mirroring', 'labeling', 'calibrated_question', 'loss_aversion', 'accusation_audit'];
                tacticToUse = allTactics.find(t => !usedTactics.includes(t)) || 'calibrated_question';
            }

            const prompt = `
            You are a MASTER negotiator using proven psychological tactics. Generate a response.

            ===== LANDLORD'S SENTIMENT: ${analysis.sentiment} =====
            ===== STRATEGY NEEDED: ${analysis.responseStrategy} =====
            ===== NEGOTIATION PHASE: ${analysis.negotiationPhase} =====

            ===== FULL CONVERSATION HISTORY =====
            ${fullHistory || 'First exchange'}

            ===== PROPERTY =====
            ${listing.title} - $${listing.price}/month (${listing.house_type})

            ===== MY POSITION =====
            Budget: $${negotiation.userBudget}/month
            Last offer: $${state.lastOffer}/month
            Offers made so far: ${state.offersMade.join(', ') || 'None yet'}

            ===== TACTIC TO USE: ${tacticToUse.toUpperCase()} =====

            TACTIC GUIDE:
            - MIRRORING: Repeat their last few words as a question to make them elaborate
            - LABELING: Name their emotion ("It seems like...", "It sounds like...")
            - CALIBRATED QUESTION: Ask "How..." or "What..." questions
            - LOSS AVERSION: Frame what they lose by not accepting
            - ACCUSATION AUDIT: Address their objection before they raise it

            RULES:
            1. Use the ${tacticToUse} tactic naturally
            2. NEVER repeat an offer that was already rejected
            3. 2-3 sentences MAX
            4. After making your point, STOP (strategic silence)
            5. Be confident but respectful

            Generate ONLY the response:
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
                    max_tokens: 150,
                    temperature: 0.7
                })
            });

            if (response.ok) {
                const data = await response.json();
                const responseText = data.choices[0].message.content.trim();

                // Track the tactic used
                if (!negotiation.negotiationState) {
                    negotiation.negotiationState = { tacticsUsed: [], offersMade: [], lastOffer: negotiation.userBudget };
                }
                negotiation.negotiationState.tacticsUsed.push(tacticToUse);

                // Track any price mentioned
                const priceMatch = responseText.match(/\$(\d+)/);
                if (priceMatch) {
                    negotiation.negotiationState.lastOffer = parseInt(priceMatch[1]);
                    negotiation.negotiationState.offersMade.push(parseInt(priceMatch[1]));
                }

                console.log('✅ Generated contextual response with tactic:', tacticToUse);
                return responseText;
            }
        } catch (error) {
            console.error('Error generating contextual response:', error);
        }

        // Fallback with calibrated question (never repeats same offer)
        const state = negotiation.negotiationState || { lastOffer: negotiation.userBudget };
        return `How can we make this work? I'm a reliable tenant ready to sign immediately. What would it take to get to $${state.lastOffer}?`;
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

            // Create negotiation tracking with enhanced state for psychological tactics
            const negotiationId = `neg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

            // Extract the initial offer from the message
            const initialOfferMatch = message.match(/\$(\d+)/);
            const initialOffer = initialOfferMatch ? parseInt(initialOfferMatch[1]) : userBudget;

            // Save budget to localStorage for recovery
            try {
                localStorage.setItem('ai_negotiation_budget', userBudget.toString());
            } catch (e) {
                console.log('Could not save budget to localStorage');
            }

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
                }],
                // Enhanced negotiation state for psychological tactics
                negotiationState: {
                    offersMade: [initialOffer], // Track all offers we've made
                    offersRejected: 0, // Count of rejections
                    lastOffer: initialOffer, // Last price we offered
                    landlordCounters: [], // Track landlord's counter-offers
                    tacticsUsed: [], // Track which tactics we've used
                    concessionCount: 0, // How many times we've increased our offer
                    maxConcessions: 4, // Don't concede more than 4 times
                    currentPhase: 'opening' // opening, bargaining, closing, final
                }
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

            // Get negotiation state for tactical decisions
            const state = negotiation.negotiationState || {
                offersMade: [],
                offersRejected: 0,
                lastOffer: null,
                concessionCount: 0,
                tacticsUsed: []
            };

            // CRITICAL: Get the highest offer we've ever made to avoid going backwards
            const highestPreviousOffer = state.offersMade.length > 0 ? Math.max(...state.offersMade) : 0;
            const lastOffer = Math.max(state.lastOffer || 0, highestPreviousOffer, negotiation.userBudget);

            console.log('📊 Negotiation state check:');
            console.log('   - All offers made:', state.offersMade);
            console.log('   - Highest previous offer:', highestPreviousOffer);
            console.log('   - Last offer baseline:', lastOffer);

            // Calculate next offer using incremental concessions
            let nextOffer = lastOffer;

            // Incremental concession logic: smaller increases each time
            // But ALWAYS increase from our highest previous offer
            const increments = [50, 25, 15, 10, 5]; // Decreasing increments
            const increment = increments[Math.min(state.concessionCount, increments.length - 1)];
            nextOffer = Math.min(lastOffer + increment, listing.price);

            // CRITICAL: Make sure we NEVER offer the same price twice
            while (state.offersMade.includes(nextOffer) && nextOffer < listing.price) {
                nextOffer += 5; // Keep incrementing by $5 until we have a new offer
            }

            console.log('   - Next offer will be:', nextOffer, '(increment:', increment, ')');

            // Select which tactic to use based on what hasn't been used yet
            const availableTactics = ['mirroring', 'labeling', 'calibrated_question', 'loss_aversion', 'accusation_audit'];
            const unusedTactics = availableTactics.filter(t => !state.tacticsUsed.includes(t));
            const tacticToUse = unusedTactics.length > 0 ? unusedTactics[0] : 'calibrated_question';

            // Build full conversation history
            const fullHistory = negotiation.messages.map(m => `${m.sender.toUpperCase()}: ${m.content}`).join('\n');

            const prompt = `
            You are a MASTER rental negotiator using FBI-level psychological tactics. Respond to this landlord who rejected your offer.

            ===== LANDLORD'S MESSAGE =====
            "${landlordMessage}"

            ===== FULL CONVERSATION HISTORY =====
            ${fullHistory || 'This is the first exchange.'}

            ===== PROPERTY DETAILS =====
            - Property: ${listing.title}
            - Asking price: $${listing.price}/month
            - Type: ${listing.house_type}, ${listing.bedrooms} bedrooms
            - Location: ${listing.city}

            ===== MARKET DATA =====
            - Average rent: $${marketData.average}/month
            - Range: $${marketData.min} - $${marketData.max}
            - Comparable properties: ${marketData.count}

            ===== NEGOTIATION STATE =====
            - My budget: $${negotiation.userBudget}/month
            - Last offer I made: $${lastOffer}/month
            - Times rejected: ${state.offersRejected}
            - Next offer to make: $${nextOffer}/month (ONLY if needed)

            ===== PSYCHOLOGICAL TACTIC TO USE: ${tacticToUse.toUpperCase()} =====

            TACTIC INSTRUCTIONS:
            ${tacticToUse === 'mirroring' ? `
            MIRRORING: Repeat the landlord's last 3-5 words as a question.
            Example: If they said "I have an offer at $1100" → respond "$1100? That's interesting..."
            This makes them elaborate and feel heard.
            ` : ''}
            ${tacticToUse === 'labeling' ? `
            LABELING: Name their emotion or situation to build rapport.
            Examples:
            - "It seems like you're weighing multiple options..."
            - "It sounds like the price is really important to you..."
            - "I sense that you've had bad experiences with tenants before..."
            This validates their feelings and opens dialogue.
            ` : ''}
            ${tacticToUse === 'calibrated_question' ? `
            CALIBRATED QUESTIONS: Ask "how" or "what" instead of arguing.
            Examples:
            - "How am I supposed to make that work with my budget?"
            - "What would it take for you to consider $${nextOffer}?"
            - "How can we bridge this gap together?"
            This puts the problem-solving on them without confrontation.
            ` : ''}
            ${tacticToUse === 'loss_aversion' ? `
            LOSS AVERSION: Frame what they might lose by not accepting.
            Examples:
            - "I'm ready to sign today. If I walk, you'll need to keep showing the place, deal with no-shows..."
            - "A guaranteed reliable tenant vs. waiting and hoping for a maybe..."
            - "The longer this sits empty, the more rent you're losing..."
            People fear loss more than they value gain.
            ` : ''}
            ${tacticToUse === 'accusation_audit' ? `
            ACCUSATION AUDIT: Preemptively address their objections.
            Examples:
            - "You probably think I'm lowballing you, and I get that..."
            - "I know this is below your asking price..."
            - "You might feel like I'm not valuing your property..."
            This disarms them by saying what they're thinking before they do.
            ` : ''}

            CRITICAL RULES:
            1. NEVER repeat the exact same offer after rejection - either increase slightly or use a different tactic
            2. Use the ${tacticToUse} tactic naturally in your response
            3. Keep response to 2-3 sentences MAX
            4. Be respectful but confident
            5. If offering a new price, use $${nextOffer}
            6. After the tactic, STOP TALKING - don't over-explain (strategic silence)

            Generate ONLY the response (no "Dear landlord" or signatures):
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

            // Update negotiation state with the tactic used and new offer
            if (!negotiation.negotiationState) {
                negotiation.negotiationState = {
                    offersMade: [],
                    offersRejected: 0,
                    lastOffer: null,
                    landlordCounters: [],
                    tacticsUsed: [],
                    concessionCount: 0,
                    maxConcessions: 4,
                    currentPhase: 'bargaining'
                };
            }

            negotiation.negotiationState.tacticsUsed.push(tacticToUse);
            negotiation.negotiationState.offersRejected++;

            // If response contains a new price offer, track it
            const priceMatch = negotiationResponse.match(/\$(\d+)/);
            if (priceMatch) {
                const offeredPrice = parseInt(priceMatch[1]);
                negotiation.negotiationState.offersMade.push(offeredPrice);
                negotiation.negotiationState.lastOffer = offeredPrice;
                negotiation.negotiationState.concessionCount++;
                console.log('📊 Tracked new offer:', offeredPrice, 'Concession count:', negotiation.negotiationState.concessionCount);
            }

            console.log('✅ Generated market-based negotiation response using tactic:', tacticToUse);
            console.log('📊 Negotiation state:', negotiation.negotiationState);
            return negotiationResponse;

        } catch (error) {
            console.error('Error generating market-based negotiation:', error);

            // Enhanced fallback with tactical response
            const marketData = negotiation.marketData || { average: negotiation.userBudget };
            const state = negotiation.negotiationState || { lastOffer: negotiation.userBudget, concessionCount: 0, offersMade: [] };

            // CRITICAL: Get highest previous offer to avoid going backwards
            const highestPrevious = state.offersMade.length > 0 ? Math.max(...state.offersMade) : negotiation.userBudget;
            const baseline = Math.max(state.lastOffer || 0, highestPrevious);

            const increment = [50, 25, 15, 10, 5][Math.min(state.concessionCount, 4)];
            let counterOffer = Math.min(baseline + increment, listing.price);

            // NEVER repeat an offer
            while (state.offersMade.includes(counterOffer) && counterOffer < listing.price) {
                counterOffer += 5;
            }

            console.log('📊 Fallback counter-offer:', counterOffer, '(baseline:', baseline, ', increment:', increment, ')');

            // Track this offer in state
            if (negotiation.negotiationState) {
                negotiation.negotiationState.offersMade.push(counterOffer);
                negotiation.negotiationState.lastOffer = counterOffer;
                negotiation.negotiationState.concessionCount++;
            }

            // Use a calibrated question as fallback tactic
            return `How can we make $${counterOffer}/month work? I'm ready to sign today with excellent references. Similar ${listing.house_type}s in ${listing.city} average $${marketData.average}/month.`;
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

}

// Export for use
window.AINegotiator = AINegotiator;