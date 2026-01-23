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

    // Get combined tactic for each negotiation round
    getTacticForRound(round) {
        const tactics = [
            'mirroring_phantom',      // Round 1: Mirror + Phantom Authority
            'labeling_loss',          // Round 2: Label + Loss Aversion
            'calibrated_no',          // Round 3: Calibrated Question + "No" Technique
            'accusation_ackerman',    // Round 4: Accusation Audit + Ackerman Math
            'phantom_pressure'        // Round 5: Phantom + Time Pressure
        ];
        return tactics[round % tactics.length];
    }

    // Generate Ackerman-style precise number (looks calculated, not arbitrary)
    getAckermanPrice(basePrice) {
        // Add random variation (-15 to +15) to seem precisely calculated
        const variation = Math.floor(Math.random() * 30) - 15;
        return basePrice + variation;
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

    // Generate strategic initial negotiation message - ELITE NEGOTIATOR STYLE
    async generateNegotiationMessage(listing, userBudget, marketData) {
        try {
            console.log('🤖 Generating elite negotiation message for:', listing.title);

            // STRATEGIC PRICING: Start at 65-70% of listing, but never below market minimum
            // This gives room to negotiate UP while staying credible
            const strategicStart = Math.max(
                Math.round(listing.price * 0.65),  // 65% of asking
                marketData.min || Math.round(listing.price * 0.5),  // Never below market min
                Math.round(userBudget * 0.7)  // Start below user's max to have room
            );

            // Apply Ackerman pricing - precise number feels calculated
            const initialOffer = this.getAckermanPrice(strategicStart);

            // Check if market data supports our position
            const marketSupportsUs = marketData.average && marketData.average < listing.price;

            const prompt = `
You are an ELITE NEGOTIATOR making first contact. Confident, direct, professional. No fluff.

===== PROPERTY =====
- ${listing.title} in ${listing.city}
- Asking: $${listing.price}/month
- Type: ${listing.house_type}, ${listing.bedrooms} bedrooms

===== YOUR OPENING OFFER =====
$${initialOffer}/month (strategic anchor - room to negotiate up)

===== MARKET INTELLIGENCE =====
${marketSupportsUs ? `Market average: $${marketData.average}/month - USE THIS to justify your offer!` : 'No useful market data - focus on your value as a tenant'}

===== ELITE OPENING TACTICS =====
1. Express genuine interest (1 sentence max)
2. State your offer as a CONSTRAINT: "My budget allows $${initialOffer}" (Phantom Authority - subtle)
3. Mention you're ready to sign immediately (creates urgency for them)
4. Keep it SHORT - 2 sentences MAX. Long messages = desperation.

===== NLP TRIGGERS =====
✅ USE: "I need", "The goal is", "Fair"
❌ AVOID: "I think", "Maybe", "Would you consider", "Please"

===== EXAMPLE FORMAT =====
"Interested in [property]. My budget allows $${initialOffer}/month - I'm a reliable tenant ready to sign today."

Generate ONLY the message. No greetings, no signatures.
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
                    max_tokens: 100,
                    temperature: 0.7
                })
            });

            if (!response.ok) {
                throw new Error(`OpenAI API error: ${response.status}`);
            }

            const data = await response.json();
            const message = data.choices[0].message.content.trim();

            console.log('✅ Generated elite negotiation message with offer:', initialOffer);
            return message;

        } catch (error) {
            console.warn('⚠️ OpenAI unavailable, using elite fallback');

            // Strategic fallback - still uses elite style
            const strategicStart = Math.max(
                Math.round(listing.price * 0.65),
                Math.round(userBudget * 0.7)
            );
            const initialOffer = this.getAckermanPrice(strategicStart);

            return `Interested in ${listing.title}. My budget allows $${initialOffer}/month - I'm a reliable tenant ready to sign today.`;
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

    // Detect off-topic messages and generate witty redirects
    getOffTopicResponse(content, negotiation) {
        const lower = content.toLowerCase().trim();
        const state = negotiation.negotiationState || { lastOffer: negotiation.userBudget };
        const currentOffer = state.lastOffer || negotiation.userBudget;

        // DON'T catch legitimate negotiation responses - let them go to normal analysis
        // "no", "nah", "nope" = rejections (handle in negotiation logic)
        // Messages with prices = counter-offers
        // Messages about "offer" = competing offers
        if (/\b(no|nah|nope|yes|yeah|ok|okay|offer|price|\$|\d{3,4})\b/i.test(lower)) {
            return null; // Let normal negotiation handle these
        }

        // Inappropriate/sexual content - deflect with humor
        const inappropriatePatterns = [
            /\b(sex|sexual|blowjob|bj|bjs|handjob|fuck|dick|cock|pussy|naked|nude|xxx)\b/i,
            /\b(prostitut|escort|hooker|whore)\b/i,
            /\bwhat (sexual|services)\b/i
        ];

        for (const pattern of inappropriatePatterns) {
            if (pattern.test(lower)) {
                // Calculate next offer (increment from current)
                const nextOffer = this.getAckermanPrice(currentOffer + 50);
                const wittyResponses = [
                    `Ha! I appreciate the creativity, but I'm here for the apartment, not a date. 😄 So... $${nextOffer}/month - we doing this or what?`,
                    `Smooth. But the only thing I'm trying to get into is that apartment. $${nextOffer}/month work for you?`,
                    `Lol nice try. I'm flattered, but let's keep this professional. Back to business - $${nextOffer}/month?`,
                    `😂 You're funny. But seriously though, I need a place to live, not a Tinder match. Can we do $${nextOffer}?`
                ];
                return wittyResponses[Math.floor(Math.random() * wittyResponses.length)];
            }
        }

        // Only catch truly random/test messages (not negotiation responses)
        if (/^(lol|lmao|haha|bruh|test|testing|asdf|hello|hi|hey|yo|sup|wassup|how are you)$/i.test(lower)) {
            const nextOffer = this.getAckermanPrice(currentOffer + 25);
            const playfulResponses = [
                `Haha, I feel you. But real talk - $${nextOffer}/month, can we make it happen?`,
                `Lol. Anyway... about that apartment? $${nextOffer}/month sound fair?`,
                `😄 Alright alright. So we doing this deal or what? $${nextOffer}/month.`
            ];
            return playfulResponses[Math.floor(Math.random() * playfulResponses.length)];
        }

        return null; // Not off-topic, continue normal processing
    }

    // Detect and handle "competing offer" scenarios - CRITICAL for negotiation
    detectCompetingOffer(content) {
        const lower = content.toLowerCase();

        // Patterns for competing offers
        const competingOfferPatterns = [
            /(?:got|have|received|already have|someone|another).+?(?:offer|offering).+?\$?(\d+)/i,
            /offer(?:ing|ed)?\s+(?:of\s+)?\$?(\d+)/i,
            /\$(\d+)\s+(?:offer|from|already)/i
        ];

        for (const pattern of competingOfferPatterns) {
            const match = content.match(pattern);
            if (match) {
                const competingPrice = parseInt(match[1]);
                if (competingPrice > 0) {
                    console.log('🎯 COMPETING OFFER DETECTED:', competingPrice);
                    return { hasCompetingOffer: true, competingPrice };
                }
            }
        }

        return { hasCompetingOffer: false };
    }

    // Analyze landlord's reply
    async analyzeReply(replyContent, negotiation, listing) {
        console.log('🔍 Starting reply analysis for:', replyContent);

        // FIRST: Check for off-topic/inappropriate content - respond with personality!
        const wittyRedirect = this.getOffTopicResponse(replyContent, negotiation);
        if (wittyRedirect) {
            console.log('😄 Off-topic detected, using witty redirect');
            return {
                sentiment: 'off_topic',
                shouldRespond: true,
                isFinalized: false,
                suggestedResponse: wittyRedirect,
                responseStrategy: 'redirect'
            };
        }

        // Check for simple acceptance patterns IMMEDIATELY
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

        // Check for COMPETING OFFER - this is critical to handle properly
        const competingOfferCheck = this.detectCompetingOffer(replyContent);
        if (competingOfferCheck.hasCompetingOffer) {
            const state = negotiation.negotiationState || { lastOffer: negotiation.userBudget, offersMade: [] };
            const competingPrice = competingOfferCheck.competingPrice;

            // Calculate our counter: match or slightly beat the competing offer if within budget
            const maxOffer = Math.round(listing.price * 0.90);
            let ourCounter;

            if (competingPrice <= negotiation.userBudget) {
                // We can match or beat it - offer slightly more
                ourCounter = Math.min(competingPrice + this.getAckermanPrice(10), maxOffer);
            } else if (competingPrice <= maxOffer) {
                // Competing offer is above our budget but within reason - try to match
                ourCounter = Math.min(competingPrice, maxOffer);
            } else {
                // Competing offer is too high - offer our max with explanation
                ourCounter = maxOffer;
            }

            // Make sure we don't repeat offers
            while (state.offersMade.includes(ourCounter) && ourCounter < maxOffer) {
                ourCounter += 5;
            }

            const ackermanCounter = this.getAckermanPrice(ourCounter);

            console.log('💰 COMPETING OFFER RESPONSE: Their offer $', competingPrice, '-> Our counter $', ackermanCounter);

            return {
                sentiment: 'neutral',
                priceOffered: competingPrice,
                acceptsOffer: false,
                makesCounterOffer: true,
                shouldRespond: true,
                isFinalized: false,
                responseStrategy: 'competing_offer',
                competingPrice: competingPrice,
                suggestedResponse: `$${competingPrice}? That's strong. My budget is capped at $${ackermanCounter}. Help me bridge that gap?`,
                negotiationPhase: 'bargaining'
            };
        }

        // Check for simple rejections - handle locally without AI for speed
        const isSimpleRejection = /^(no|nah|nope|too low|can't do that|not possible)$/i.test(simpleReply);
        if (isSimpleRejection) {
            console.log('❌ REJECTION DETECTED:', simpleReply);
            const state = negotiation.negotiationState || { lastOffer: negotiation.userBudget, offersMade: [], concessionCount: 0 };
            const maxOffer = Math.round(listing.price * 0.90);

            // Calculate next offer - ALWAYS increment after rejection
            const increments = [75, 50, 35, 25, 15];
            const increment = increments[Math.min(state.concessionCount || 0, increments.length - 1)];
            let nextOffer = Math.min((state.lastOffer || negotiation.userBudget) + increment, maxOffer);

            // Never repeat an offer
            while (state.offersMade.includes(nextOffer) && nextOffer < maxOffer) {
                nextOffer += 10;
            }

            const ackermanOffer = this.getAckermanPrice(nextOffer);

            return {
                sentiment: 'negative',
                priceOffered: null,
                acceptsOffer: false,
                makesCounterOffer: false,
                shouldRespond: true,
                isFinalized: false,
                responseStrategy: 'rejection_counter',
                nextOffer: ackermanOffer,
                suggestedResponse: `It sounds like that doesn't work. What would make $${ackermanOffer} work today?`,
                negotiationPhase: 'bargaining'
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
            // Handle witty redirects for off-topic messages
            if (analysis.responseStrategy === 'redirect' && analysis.suggestedResponse) {
                console.log('😄 Using witty redirect response');
                return analysis.suggestedResponse;
            }

            // Handle COMPETING OFFER - use elite Mirror + Phantom Authority tactic
            if (analysis.responseStrategy === 'competing_offer') {
                console.log('🎯 Handling competing offer with elite tactics');
                const state = negotiation.negotiationState || { lastOffer: negotiation.userBudget, offersMade: [], concessionCount: 0 };
                const competingPrice = analysis.competingPrice || analysis.priceOffered;
                const maxOffer = Math.round(listing.price * 0.90);

                // Calculate counter - try to match/beat competing offer if possible
                let ourCounter = competingPrice <= negotiation.userBudget
                    ? Math.min(competingPrice + 25, maxOffer)
                    : Math.min(Math.round(negotiation.userBudget * 1.1), maxOffer);

                // Never repeat an offer
                while (state.offersMade.includes(ourCounter) && ourCounter < maxOffer) {
                    ourCounter += 10;
                }

                const ackermanCounter = this.getAckermanPrice(ourCounter);

                // Update state
                if (!negotiation.negotiationState) negotiation.negotiationState = state;
                negotiation.negotiationState.offersMade.push(ackermanCounter);
                negotiation.negotiationState.lastOffer = ackermanCounter;
                negotiation.negotiationState.concessionCount++;

                // Elite response: Mirror + Phantom Authority
                const competingOfferResponses = [
                    `$${competingPrice}? That's strong. My budget is capped at $${ackermanCounter}. Help me bridge that gap?`,
                    `$${competingPrice}... I hear you. The best I can authorize is $${ackermanCounter}. I'm ready to sign today.`,
                    `$${competingPrice}? Respect. I can do $${ackermanCounter} and close immediately. A sure thing vs. a maybe?`,
                    `Competing offer at $${competingPrice}? I can match at $${ackermanCounter} and sign today. What do you say?`
                ];
                return competingOfferResponses[Math.floor(Math.random() * competingOfferResponses.length)];
            }

            // Handle REJECTION - increment offer and try new tactic
            if (analysis.responseStrategy === 'rejection_counter') {
                console.log('❌ Handling rejection with offer increment');
                const state = negotiation.negotiationState || { lastOffer: negotiation.userBudget, offersMade: [], concessionCount: 0 };
                const nextOffer = analysis.nextOffer;

                // Update state
                if (!negotiation.negotiationState) negotiation.negotiationState = state;
                negotiation.negotiationState.offersMade.push(nextOffer);
                negotiation.negotiationState.lastOffer = nextOffer;
                negotiation.negotiationState.concessionCount++;
                negotiation.negotiationState.offersRejected = (negotiation.negotiationState.offersRejected || 0) + 1;

                // Vary response based on rejection count
                const rejectionCount = negotiation.negotiationState.offersRejected;
                const weeklyVacancyCost = Math.round(listing.price / 4);

                const rejectionResponses = [
                    `It sounds like that doesn't work. What would make $${nextOffer} work today?`,
                    `I hear you. Let me stretch to $${nextOffer}. That's genuinely my limit. Can we close?`,
                    `Every week vacant costs you $${weeklyVacancyCost}. I'm at $${nextOffer} and ready to sign now.`,
                    `Would it be unreasonable to consider $${nextOffer}? I need to make a decision today.`,
                    `You probably think I'm being difficult. I get it. $${nextOffer} is every dollar I have.`
                ];
                return rejectionResponses[Math.min(rejectionCount - 1, rejectionResponses.length - 1)];
            }

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

        // Get negotiation state
        const state = negotiation.negotiationState || {
            offersMade: [],
            lastOffer: negotiation.userBudget,
            concessionCount: 0
        };

        // Calculate reasonable starting point - never more than 85% of listing price
        const maxReasonableOffer = Math.round(listing.price * 0.90); // Cap at 90% of asking
        const startingPoint = Math.min(negotiation.userBudget || Math.round(listing.price * 0.70), maxReasonableOffer);

        // Get highest previous offer, but cap it at 90% of listing
        const highestPrevious = state.offersMade.length > 0
            ? Math.min(Math.max(...state.offersMade), maxReasonableOffer)
            : startingPoint;
        const baseline = Math.max(state.lastOffer || startingPoint, highestPrevious);

        // Calculate next offer with increment
        const increments = [50, 25, 15, 10, 5];
        const increment = increments[Math.min(state.concessionCount, increments.length - 1)];

        // CRITICAL: Never offer more than 90% of listing price - leave room to negotiate
        let suggestion = Math.min(baseline + increment, maxReasonableOffer);

        // NEVER repeat an offer
        while (state.offersMade.includes(suggestion) && suggestion < maxReasonableOffer) {
            suggestion += 5;
        }

        // If we've hit max, vary the response to avoid repetition
        if (suggestion >= maxReasonableOffer) {
            const maxOfferVariations = [
                `$${maxReasonableOffer}/month is genuinely my max. I'm a reliable tenant ready to sign today. Can we make this work?`,
                `Look, $${maxReasonableOffer} is every dollar I have. A guaranteed tenant today vs. more showings and uncertainty. What do you say?`,
                `I can't go higher than $${maxReasonableOffer}. But I'm ready to sign right now with references in hand. Deal?`,
                `$${maxReasonableOffer} - that's my ceiling. I know it's below asking, but I'm a sure thing. Let's close this.`,
                `Would it be unreasonable to lock this in at $${maxReasonableOffer}? I can move fast and I won't waste your time.`
            ];
            // Pick based on rejection count to ensure variety
            const variationIndex = (state.offersRejected || 0) % maxOfferVariations.length;
            return maxOfferVariations[variationIndex];
        }

        console.log('📊 generateMarketBasedResponse: baseline:', baseline, '-> suggestion:', suggestion, '(max:', maxReasonableOffer, ')');

        // Track this offer
        if (negotiation.negotiationState) {
            negotiation.negotiationState.offersMade.push(suggestion);
            negotiation.negotiationState.lastOffer = suggestion;
            negotiation.negotiationState.concessionCount++;
        }

        // Only mention market data if it's actually useful (different from listing price)
        const hasUsefulMarketData = marketData.average && Math.abs(marketData.average - listing.price) > 50;

        if (hasUsefulMarketData && marketData.average < listing.price) {
            return `$${suggestion}/month - similar ${listing.house_type}s nearby average $${marketData.average}. I'm ready to sign today. What do you say?`;
        } else {
            return `$${suggestion}/month. I'm a reliable tenant with great references, ready to move in immediately. Can we make this work?`;
        }
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

    // Generate market-based negotiation response to rejections - ELITE FBI-STYLE NEGOTIATOR
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

            // CRITICAL: Never offer more than 90% of listing price - always leave negotiation room
            const maxOffer = Math.round(listing.price * 0.90);
            const startingPoint = negotiation.userBudget || Math.round(listing.price * 0.70);

            // Get the highest offer we've ever made, capped at 90%
            const highestPreviousOffer = state.offersMade.length > 0
                ? Math.min(Math.max(...state.offersMade), maxOffer)
                : startingPoint;
            const lastOffer = Math.min(Math.max(state.lastOffer || startingPoint, highestPreviousOffer), maxOffer);

            console.log('📊 Negotiation state check:');
            console.log('   - All offers made:', state.offersMade);
            console.log('   - Highest previous offer:', highestPreviousOffer);
            console.log('   - Last offer baseline:', lastOffer);
            console.log('   - Max offer cap (90%):', maxOffer);

            // Calculate next offer using incremental concessions
            let nextOffer = lastOffer;

            // Incremental concession logic: smaller increases each time
            const increments = [50, 25, 15, 10, 5]; // Decreasing increments
            const increment = increments[Math.min(state.concessionCount, increments.length - 1)];
            nextOffer = Math.min(lastOffer + increment, maxOffer); // Cap at 90%, not 100%

            // CRITICAL: Make sure we NEVER offer the same price twice
            while (state.offersMade.includes(nextOffer) && nextOffer < maxOffer) {
                nextOffer += 5;
            }

            // Apply Ackerman pricing - precise numbers feel calculated, not arbitrary
            const ackermanOffer = this.getAckermanPrice(nextOffer);

            console.log('   - Next offer will be:', nextOffer, '(Ackerman:', ackermanOffer, ', increment:', increment, ')');

            // Select combined tactic based on round
            const tacticToUse = this.getTacticForRound(state.offersRejected);

            // Build full conversation history
            const fullHistory = negotiation.messages.map(m => `${m.sender.toUpperCase()}: ${m.content}`).join('\n');

            // Check if market data is actually useful (different from listing price)
            const hasUsefulMarketData = marketData.average && Math.abs(marketData.average - listing.price) > 50;

            // Calculate vacancy cost for loss aversion
            const weeklyVacancyCost = Math.round(listing.price / 4);

            const prompt = `
You are an ELITE NEGOTIATOR. Ruthless but professional. Direct, no fluff, but not rude. Your goal is to secure the property at the target price.

===== LANDLORD'S MESSAGE =====
"${landlordMessage}"

===== CONVERSATION HISTORY =====
${fullHistory || 'First exchange'}

===== PROPERTY & CONSTRAINTS =====
- Property: ${listing.title} in ${listing.city}
- Asking: $${listing.price}/month
- Your offer: $${ackermanOffer}/month
- Hard ceiling: $${maxOffer}/month (NEVER exceed)

===== PSYCHOLOGICAL WEAPONS =====

**PHANTOM AUTHORITY** - Subtle hints at external constraints (use sparingly, ~30% of responses):
- "My budget is capped at $${ackermanOffer}" (implies external limit)
- "I can't authorize above $${ackermanOffer}" (sounds like someone else controls it)
- Only occasionally mention "advisor" or "partner" - keep it subtle
- Makes it: "You + Me vs. The Budget" instead of "You vs. Me"

**ACKERMAN FRAMING** - Use precise numbers:
- Offer $${ackermanOffer} (not round numbers like $${Math.round(nextOffer / 100) * 100})
- "This is my calculated maximum after expenses"
- Precise numbers feel like real limits, not arbitrary guesses

**NLP TRIGGERS**:
✅ USE: "Correct", "Fair", "The goal is", "Let's resolve", "I need"
❌ AVOID: "I think", "Maybe", "Can we", "Please", "How about"

**"NO" TECHNIQUE**:
- Ask: "Would it be unreasonable to consider $${ackermanOffer}?"
- Gets psychological commitment when they say "No, it's not unreasonable"
- Then: "Great, so $${ackermanOffer} works?"

**LOSS AVERSION WITH MATH**:
- Weekly vacancy cost: $${weeklyVacancyCost}
- Say: "Every week vacant costs you $${weeklyVacancyCost}. My offer today stops the bleeding."

===== TACTIC FOR THIS ROUND: ${tacticToUse.toUpperCase()} =====

TACTIC COMBINATIONS:
${tacticToUse === 'mirroring_phantom' ? `
**MIRRORING + PHANTOM AUTHORITY**
1. Mirror their last 3-5 words as a question
2. Then hint at budget constraint (without naming "advisor" every time)
Example: "$1100? My budget is capped at $${ackermanOffer}. Help me bridge that gap?"
` : ''}
${tacticToUse === 'labeling_loss' ? `
**LABELING + LOSS AVERSION**
1. Label their emotion/situation: "It sounds like...", "It seems like..."
2. Then frame the cost of waiting: vacancy = $${weeklyVacancyCost}/week lost
Example: "It sounds like you're weighing options. Every week vacant is $${weeklyVacancyCost} lost. I'm ready at $${ackermanOffer} today."
` : ''}
${tacticToUse === 'calibrated_no' ? `
**CALIBRATED QUESTION + "NO" TECHNIQUE**
1. Ask "How..." or "What..." to make them problem-solve
2. Use "Would it be unreasonable..." to get their "no"
Example: "What would it take to make $${ackermanOffer} work? Would it be unreasonable to close at that today?"
` : ''}
${tacticToUse === 'accusation_ackerman' ? `
**ACCUSATION AUDIT + ACKERMAN MATH**
1. Preempt their objection: "You probably think..."
2. Counter with precise calculated number
Example: "You probably think I'm being difficult. I get it. After calculating my exact expenses, $${ackermanOffer} is every dollar I have."
` : ''}
${tacticToUse === 'phantom_pressure' ? `
**PHANTOM AUTHORITY + TIME PRESSURE**
1. Hint at external constraint on budget
2. Add urgency without desperation
Example: "I can't authorize above $${ackermanOffer}. I need to make a decision today - what do you say?"
` : ''}

===== RESPONSE TEMPLATES FOR COMMON SCENARIOS =====

IF landlord mentions "competing offer at $X":
→ Mirror + Phantom: "$X? That's strong. My budget is capped at $${ackermanOffer}. Help me bridge that gap?"

IF landlord says "no" or rejects:
→ Label + Calibrated: "It sounds like that doesn't work. What would make $${ackermanOffer} work today?"

IF landlord says "price is firm":
→ Phantom + Flexibility: "I understand. I can't authorize above $${ackermanOffer}. Any flexibility on move-in or lease terms?"

===== CRITICAL RULES =====
1. MAX 2 sentences - Long text = desperation
2. Use ${tacticToUse} tactic IMMEDIATELY in your response
3. State offer as CONSTRAINT not REQUEST ("The best I can authorize is $${ackermanOffer}" not "Can we do $${ackermanOffer}?")
4. End with offer or question, then STOP (strategic silence)
5. NEVER exceed $${maxOffer}
6. ${hasUsefulMarketData ? `USE market data: Average is $${marketData.average}` : 'NO market data - pivot to reliability and ready-to-sign'}
7. NEVER repeat an offer already in: ${state.offersMade.join(', ') || 'none'}

Generate ONLY the response. No fluff. No signatures.
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

            // Enhanced fallback with elite negotiator tactics
            const marketData = negotiation.marketData || { average: negotiation.userBudget };
            const state = negotiation.negotiationState || { lastOffer: negotiation.userBudget, concessionCount: 0, offersMade: [] };

            // CRITICAL: Get highest previous offer to avoid going backwards
            const highestPrevious = state.offersMade.length > 0 ? Math.max(...state.offersMade) : negotiation.userBudget;
            const baseline = Math.max(state.lastOffer || 0, highestPrevious);
            const maxOffer = Math.round(listing.price * 0.90);

            const increment = [50, 25, 15, 10, 5][Math.min(state.concessionCount, 4)];
            let counterOffer = Math.min(baseline + increment, maxOffer);

            // NEVER repeat an offer
            while (state.offersMade.includes(counterOffer) && counterOffer < maxOffer) {
                counterOffer += 5;
            }

            // Apply Ackerman pricing - precise numbers feel calculated
            const ackermanOffer = this.getAckermanPrice(counterOffer);

            console.log('📊 Fallback counter-offer:', ackermanOffer, '(base:', counterOffer, ', baseline:', baseline, ')');

            // Track this offer in state
            if (negotiation.negotiationState) {
                negotiation.negotiationState.offersMade.push(ackermanOffer);
                negotiation.negotiationState.lastOffer = ackermanOffer;
                negotiation.negotiationState.concessionCount++;
            }

            // Use elite negotiator fallback tactics based on round
            const tacticRound = state.offersRejected || 0;
            const weeklyVacancyCost = Math.round(listing.price / 4);

            const fallbackResponses = [
                // Round 0: Phantom Authority
                `My budget is capped at $${ackermanOffer}. I'm ready to sign today. What would it take?`,
                // Round 1: Loss Aversion
                `Every week vacant costs you $${weeklyVacancyCost}. The best I can authorize is $${ackermanOffer}.`,
                // Round 2: Calibrated Question + No Technique
                `Would it be unreasonable to consider $${ackermanOffer}? I need to make a decision today.`,
                // Round 3: Accusation Audit
                `You probably think I'm being difficult. After calculating my expenses, $${ackermanOffer} is genuinely my limit.`,
                // Round 4+: Final offer
                `$${ackermanOffer} is every dollar I have. A guaranteed tenant today vs. uncertain waiting. What do you say?`
            ];

            return fallbackResponses[Math.min(tacticRound, fallbackResponses.length - 1)];
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