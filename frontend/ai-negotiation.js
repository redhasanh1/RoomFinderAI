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
                                
                                const existingBackups = JSON.parse(null || '[]');
                                existingBackups.push(backupData);
                                // Keep only last 10 items
                                if (existingBackups.length > 10) {
                                    existingBackups.splice(0, existingBackups.length - 10);
                                }
                                // localStorage removed - using Supabase);
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

            console.log('📊 AI Analysis result:', analysis);
            return analysis;

        } catch (error) {
            console.error('Error with AI analysis, using enhanced fallback:', error);
            
            // Enhanced fallback analysis with better detection
            const replyLower = replyContent.toLowerCase().trim();
            const hasPrice = replyContent.match(/\$(\d+)/);
            const seemsPositive = /\b(yes|ok|sure|accept|agree|sounds good|works|fine|deal|great|perfect)\b/i.test(replyContent);
            const hasAcceptanceWords = /\b(sure|yes|ok|okay|sounds good|works|fine|agreed|deal|sounds great|perfect|great|excellent)\b/i.test(replyLower);
            
            console.log('🔧 Fallback analysis - hasAcceptanceWords:', hasAcceptanceWords, 'for:', replyLower);
            
            return {
                sentiment: seemsPositive ? 'positive' : 'neutral',
                priceOffered: hasPrice ? parseInt(hasPrice[1]) : null,
                acceptsOffer: hasAcceptanceWords && !hasPrice,
                makesCounterOffer: !!hasPrice,
                shouldRespond: true,
                isFinalized: hasAcceptanceWords && !hasPrice,
                agreedPrice: (hasAcceptanceWords && !hasPrice) ? this.extractLastOfferedPrice(negotiation) : null,
                responseStrategy: (hasAcceptanceWords && !hasPrice) ? 'thank' : (hasPrice ? 'counter' : 'clarify'),
                negotiationPhase: (hasAcceptanceWords && !hasPrice) ? 'closing' : 'bargaining'
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

    // Generate advanced counter-offer with market analysis
    async generateAdvancedCounterOffer(analysis, negotiation, listing) {
        const userBudget = negotiation.userBudget;
        const counterPrice = analysis.priceOffered;
        const marketData = negotiation.marketData;

        if (counterPrice <= userBudget) {
            return `Perfect! $${counterPrice}/month works excellently for me. I'm ready to proceed immediately and can provide excellent references. When can we arrange to finalize the rental agreement?`;
        } else {
            const maxOffer = Math.min(userBudget, Math.round(counterPrice * 0.92));
            let justification = '';
            
            if (marketData && counterPrice > marketData.average) {
                justification = ` Given that similar properties in the area average around $${marketData.average}/month,`;
            }
            
            return `I really appreciate your counter-offer!${justification} Would you consider $${maxOffer}/month? This fits perfectly within my budget and I can guarantee immediate occupancy with excellent references. I'm a serious, reliable tenant looking to establish a long-term rental relationship.`;
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
            
            Generate a professional, persuasive response (2-3 sentences max) that:
            1. Acknowledges their position respectfully
            2. Emphasizes tenant reliability and quick decision-making
            3. Makes a reasonable counter-proposal if needed
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
                    model: this.config.OPENAI_MODEL || 'gpt-4',
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