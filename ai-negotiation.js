// AI Negotiation Engine
// Handles real-time negotiation with landlords using market data and OpenAI

class AINegotatior {
    constructor(supabase, config) {
        this.supabase = supabase;
        this.config = config;
        this.activeNegotiations = new Map(); // Track ongoing negotiations
        this.marketData = new Map(); // Cache market data
        this.setupMessageListener();
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
            console.log('💬 Handling negotiation reply:', message.content);

            const negotiation = this.activeNegotiations.get(conversationId);
            if (!negotiation) {
                console.log('⚠️ No active negotiation found for conversation:', conversationId);
                return;
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

            // Generate response if needed
            if (analysis.shouldRespond) {
                const response = await this.generateCounterResponse(analysis, negotiation, listing);
                
                if (response) {
                    // Send the response
                    await this.sendNegotiationMessage(conversationId, response, negotiation.userEmail);
                    
                    // Update negotiation state
                    negotiation.messages.push({
                        sender: 'ai',
                        content: response,
                        timestamp: new Date()
                    });

                    if (analysis.isFinalized) {
                        negotiation.status = 'finalized';
                        negotiation.finalPrice = analysis.agreedPrice;
                        console.log('✅ Negotiation finalized at $', analysis.agreedPrice);
                    }
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
        try {
            const prompt = `
            Analyze this landlord reply in a rental negotiation:

            LANDLORD REPLY: "${replyContent}"
            
            NEGOTIATION CONTEXT:
            - Original price: $${listing.price}
            - Current negotiation status: ${negotiation.status}
            - Previous offers: ${negotiation.messages.map(m => m.content).join('; ')}

            Analyze the reply and return JSON:
            {
                "sentiment": "positive/neutral/negative",
                "priceOffered": null or number,
                "acceptsOffer": true/false,
                "makesCounterOffer": true/false,
                "shouldRespond": true/false,
                "isFinalized": true/false,
                "agreedPrice": null or number,
                "responseStrategy": "accept/counter/thank/clarify",
                "suggestedResponse": "brief response if shouldRespond is true"
            }

            ANALYSIS RULES:
            - If they accept your offer: isFinalized=true, agreedPrice=offered price
            - If they counter-offer: extract the price, shouldRespond=true
            - If they reject completely: shouldRespond=false
            - Be conservative with price extraction
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
            return JSON.parse(data.choices[0].message.content.trim());

        } catch (error) {
            console.error('Error analyzing reply:', error);
            
            // Basic fallback analysis
            const hasPrice = replyContent.match(/\$(\d+)/);
            const seemsPositive = /yes|ok|sure|accept|agree/i.test(replyContent);
            
            return {
                sentiment: seemsPositive ? 'positive' : 'neutral',
                priceOffered: hasPrice ? parseInt(hasPrice[1]) : null,
                acceptsOffer: seemsPositive && !hasPrice,
                makesCounterOffer: !!hasPrice,
                shouldRespond: seemsPositive || hasPrice,
                isFinalized: seemsPositive && !hasPrice,
                responseStrategy: hasPrice ? 'counter' : 'accept'
            };
        }
    }

    // Generate counter-response
    async generateCounterResponse(analysis, negotiation, listing) {
        if (!analysis.shouldRespond) return null;

        try {
            if (analysis.isFinalized) {
                return "Perfect! Thank you for accepting. I'm ready to move forward with the rental process. When can we arrange the next steps?";
            }

            if (analysis.makesCounterOffer && analysis.priceOffered) {
                // Evaluate the counter-offer
                const userBudget = negotiation.userBudget;
                const counterPrice = analysis.priceOffered;

                if (counterPrice <= userBudget) {
                    return `That works perfectly! I'm happy to proceed at $${counterPrice}/month. I'm ready to move quickly - when can we finalize this?`;
                } else {
                    // Try to negotiate down slightly
                    const suggestion = Math.min(userBudget, Math.round(counterPrice * 0.95));
                    return `I appreciate your flexibility! Would you be able to do $${suggestion}/month? That would work perfectly with my budget and I can commit immediately.`;
                }
            }

            return analysis.suggestedResponse || "Thank you for your response. I'm very interested in moving forward with this rental.";

        } catch (error) {
            console.error('Error generating counter-response:', error);
            return "Thank you for your response. I'm interested in discussing this further.";
        }
    }

    // Send negotiation message
    async sendNegotiationMessage(conversationId, message, userEmail) {
        try {
            const { error } = await this.supabase
                .from('messages')
                .insert({
                    conversation_id: conversationId,
                    sender_email: 'ai-negotiator@roomfinder.com',
                    content: `🤖 AI Negotiator on behalf of ${userEmail}:\n\n${message}`
                });

            if (error) {
                console.error('Error sending negotiation message:', error);
                return false;
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
            this.supabase
                .channel('negotiation_messages')
                .on('postgres_changes', {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'messages'
                }, async (payload) => {
                    const newMessage = payload.new;
                    
                    // Check if this is a reply to an AI negotiation
                    if (newMessage.sender_email !== 'ai-negotiator@roomfinder.com') {
                        const { data: conversation } = await this.supabase
                            .from('conversations')
                            .select('*')
                            .eq('id', newMessage.conversation_id)
                            .eq('sender_email', 'ai-negotiator@roomfinder.com')
                            .single();

                        if (conversation) {
                            // Get listing details
                            const { data: listing } = await this.supabase
                                .from('listings')
                                .select('*')
                                .eq('id', conversation.listing_id)
                                .single();

                            if (listing) {
                                await this.handleNegotiationReply(newMessage, conversation.id, listing);
                            }
                        }
                    }
                })
                .subscribe();

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
}

// Export for use
window.AINegotatior = AINegotatior;