class ContextAnalyzer {
    constructor() {
        this.initialized = false;
    }

    async initialize() {
        this.initialized = true;
    }

    async analyzeNegotiationContext(message, negotiation, listing, marketData) {
        const context = {
            // Basic conversation info
            conversationId: negotiation?.conversationId || 'unknown',
            messageCount: negotiation?.messageHistory?.length || 0,
            
            // Negotiation stage analysis
            stage: this.determineNegotiationStage(negotiation, message),
            
            // Landlord analysis
            landlordPersonality: this.analyzeLandlordPersonality(message, negotiation),
            landlordResponseSpeed: this.calculateLandlordResponseSpeed(negotiation),
            
            // Market conditions
            marketConditions: this.analyzeMarketConditions(listing, marketData),
            
            // Price analysis
            priceRange: this.determinePriceRange(listing, negotiation),
            pricePosition: this.analyzePricePosition(negotiation, listing),
            
            // Timing analysis
            timeContext: this.analyzeTimeContext(),
            
            // Strategy recommendation
            recommendedStrategy: this.recommendStrategy(message, negotiation, listing)
        };

        return context;
    }

    determineNegotiationStage(negotiation, message) {
        const messageContent = message.content?.toLowerCase() || '';
        
        // Analyze message content for stage indicators
        if (messageContent.includes('interested') || messageContent.includes('available')) {
            return 'initial_interest';
        }
        
        if (messageContent.includes('$') || messageContent.includes('price') || messageContent.includes('rent')) {
            return 'price_negotiation';
        }
        
        if (messageContent.includes('deposit') || messageContent.includes('security')) {
            return 'deposit_discussion';
        }
        
        if (messageContent.includes('move') || messageContent.includes('when') || messageContent.includes('date')) {
            return 'move_in_logistics';
        }
        
        if (messageContent.includes('deal') || messageContent.includes('agree') || messageContent.includes('yes')) {
            return 'closing';
        }
        
        if (messageContent.includes('no') || messageContent.includes('not interested') || messageContent.includes('pass')) {
            return 'rejection';
        }
        
        // Analyze negotiation history
        if (negotiation?.messageHistory) {
            const messageCount = negotiation.messageHistory.length;
            if (messageCount <= 2) return 'initial_contact';
            if (messageCount <= 5) return 'exploration';
            if (messageCount <= 10) return 'active_negotiation';
            return 'extended_negotiation';
        }
        
        return 'unknown';
    }

    analyzeLandlordPersonality(message, negotiation) {
        const messageContent = message.content?.toLowerCase() || '';
        const responseSpeed = this.calculateLandlordResponseSpeed(negotiation);
        
        let cooperativeScore = 0;
        let aggressiveScore = 0;
        let professionalScore = 0;
        let casualScore = 0;
        
        // Cooperative indicators
        const cooperativeWords = ['sure', 'okay', 'sounds good', 'reasonable', 'flexible', 'understand', 'appreciate'];
        cooperativeWords.forEach(word => {
            if (messageContent.includes(word)) cooperativeScore++;
        });
        
        // Aggressive indicators
        const aggressiveWords = ['no', 'firm', 'final', 'won\'t', 'can\'t', 'impossible', 'non-negotiable', 'take it or leave it'];
        aggressiveWords.forEach(word => {
            if (messageContent.includes(word)) aggressiveScore++;
        });
        
        // Professional indicators
        const professionalWords = ['property', 'lease', 'terms', 'application', 'credit', 'references', 'documentation'];
        professionalWords.forEach(word => {
            if (messageContent.includes(word)) professionalScore++;
        });
        
        // Casual indicators
        const casualWords = ['hey', 'cool', 'awesome', 'great', 'thanks', 'thx', '👍', '😊'];
        casualWords.forEach(word => {
            if (messageContent.includes(word)) casualScore++;
        });
        
        // Consider response speed
        if (responseSpeed < 30) { // Fast responder (under 30 minutes)
            cooperativeScore += 0.5;
        } else if (responseSpeed > 480) { // Slow responder (over 8 hours)
            professionalScore += 0.5;
        }
        
        // Consider message length and structure
        const messageLength = messageContent.length;
        if (messageLength > 200) {
            professionalScore += 0.5;
        } else if (messageLength < 50) {
            casualScore += 0.5;
        }
        
        // Determine dominant personality
        const scores = {
            cooperative: cooperativeScore,
            aggressive: aggressiveScore,
            professional: professionalScore,
            casual: casualScore
        };
        
        const maxScore = Math.max(...Object.values(scores));
        if (maxScore === 0) return 'neutral';
        
        return Object.keys(scores).find(key => scores[key] === maxScore);
    }

    calculateLandlordResponseSpeed(negotiation) {
        if (!negotiation?.messageHistory || negotiation.messageHistory.length < 2) {
            return 0;
        }
        
        const messages = negotiation.messageHistory;
        let totalResponseTime = 0;
        let responseCount = 0;
        
        for (let i = 1; i < messages.length; i++) {
            const currentMsg = messages[i];
            const previousMsg = messages[i - 1];
            
            // Only count landlord responses to AI messages
            if (currentMsg.sender_type === 'landlord' && previousMsg.sender_type === 'ai') {
                const responseTime = new Date(currentMsg.created_at) - new Date(previousMsg.created_at);
                totalResponseTime += responseTime;
                responseCount++;
            }
        }
        
        return responseCount > 0 ? Math.round(totalResponseTime / responseCount / 1000 / 60) : 0; // minutes
    }

    analyzeMarketConditions(listing, marketData) {
        const listingPrice = listing?.price || 0;
        
        // Default market conditions
        let conditions = {
            competitiveness: 'medium',
            marketTrend: 'stable',
            pricePosition: 'market_rate',
            demandLevel: 'moderate',
            seasonality: this.getCurrentSeasonality()
        };
        
        // Analyze market data if available
        if (marketData && marketData.size > 0) {
            const prices = Array.from(marketData.values()).map(data => data.price).filter(p => p > 0);
            
            if (prices.length > 0) {
                const avgPrice = prices.reduce((sum, price) => sum + price, 0) / prices.length;
                const priceVariance = this.calculateVariance(prices);
                
                // Determine competitiveness based on price variance
                if (priceVariance > avgPrice * 0.3) {
                    conditions.competitiveness = 'high';
                } else if (priceVariance < avgPrice * 0.1) {
                    conditions.competitiveness = 'low';
                }
                
                // Determine price position
                if (listingPrice > avgPrice * 1.2) {
                    conditions.pricePosition = 'above_market';
                } else if (listingPrice < avgPrice * 0.8) {
                    conditions.pricePosition = 'below_market';
                }
                
                // Analyze market trend (simplified)
                const recentPrices = prices.slice(-10); // Last 10 comparable listings
                if (recentPrices.length >= 5) {
                    const recentAvg = recentPrices.reduce((sum, price) => sum + price, 0) / recentPrices.length;
                    if (recentAvg > avgPrice * 1.05) {
                        conditions.marketTrend = 'rising';
                    } else if (recentAvg < avgPrice * 0.95) {
                        conditions.marketTrend = 'falling';
                    }
                }
            }
        }
        
        return conditions;
    }

    determinePriceRange(listing, negotiation) {
        const price = negotiation?.userBudget || listing?.price || 0;
        
        if (price < 1000) return 'budget';
        if (price < 2000) return 'moderate';
        if (price < 3000) return 'premium';
        return 'luxury';
    }

    analyzePricePosition(negotiation, listing) {
        const userBudget = negotiation?.userBudget || 0;
        const listingPrice = listing?.price || 0;
        
        if (userBudget === 0 || listingPrice === 0) {
            return 'unknown';
        }
        
        const ratio = userBudget / listingPrice;
        
        if (ratio >= 1.0) return 'at_or_above_asking';
        if (ratio >= 0.9) return 'slightly_below';
        if (ratio >= 0.8) return 'moderately_below';
        return 'significantly_below';
    }

    analyzeTimeContext() {
        const now = new Date();
        const hour = now.getHours();
        const day = now.getDay(); // 0 = Sunday, 6 = Saturday
        const dayOfWeek = now.toLocaleDateString('en-US', { weekday: 'long' });
        
        let timeSlot;
        if (hour >= 6 && hour < 12) timeSlot = 'morning';
        else if (hour >= 12 && hour < 17) timeSlot = 'afternoon';
        else if (hour >= 17 && hour < 21) timeSlot = 'evening';
        else timeSlot = 'night';
        
        const isWeekend = day === 0 || day === 6;
        const isBusinessHours = hour >= 9 && hour <= 17 && !isWeekend;
        
        return {
            hour,
            timeSlot,
            dayOfWeek,
            isWeekend,
            isBusinessHours,
            urgency: this.calculateTimeUrgency(hour, isWeekend)
        };
    }

    getCurrentSeasonality() {
        const month = new Date().getMonth();
        
        // Peak rental season analysis
        if (month >= 4 && month <= 7) { // May-August
            return 'peak_season';
        } else if (month >= 8 && month <= 10) { // Sep-Nov
            return 'shoulder_season';
        } else { // Dec-Apr
            return 'off_season';
        }
    }

    calculateTimeUrgency(hour, isWeekend) {
        // Higher urgency during business hours
        if (hour >= 9 && hour <= 17 && !isWeekend) {
            return 'high';
        }
        
        // Medium urgency during extended business hours
        if (hour >= 8 && hour <= 19 && !isWeekend) {
            return 'medium';
        }
        
        // Low urgency otherwise
        return 'low';
    }

    recommendStrategy(message, negotiation, listing) {
        const messageContent = message.content?.toLowerCase() || '';
        const stage = this.determineNegotiationStage(negotiation, message);
        
        // Strategy recommendations based on content analysis
        if (messageContent.includes('deposit') || messageContent.includes('security')) {
            return 'security_deposit';
        }
        
        if (messageContent.includes('move') || messageContent.includes('when') || messageContent.includes('date')) {
            return 'move_in_logistics';
        }
        
        if (messageContent.includes('increase') || messageContent.includes('higher') || messageContent.includes('more')) {
            return 'increase_request';
        }
        
        // Check for acceptance indicators
        const acceptanceWords = ['deal', 'agreed', 'accept', 'sounds good', 'perfect', 'yes', 'okay'];
        if (acceptanceWords.some(word => messageContent.includes(word))) {
            return 'counter_offer_acceptance';
        }
        
        // Check for counter-offer indicators
        const counterOfferWords = ['but', 'however', 'what about', 'how about', 'could you do'];
        if (counterOfferWords.some(word => messageContent.includes(word)) || messageContent.includes('$')) {
            return 'strategic_counter_offers';
        }
        
        // Default to market-based responses for general inquiries
        return 'market_based_responses';
    }

    calculateVariance(numbers) {
        if (numbers.length === 0) return 0;
        
        const mean = numbers.reduce((sum, num) => sum + num, 0) / numbers.length;
        const squaredDiffs = numbers.map(num => Math.pow(num - mean, 2));
        return squaredDiffs.reduce((sum, diff) => sum + diff, 0) / numbers.length;
    }

    // Enhanced context for learning system integration
    async getEnhancedContext(message, negotiation, listing, marketData) {
        const basicContext = await this.analyzeNegotiationContext(message, negotiation, listing, marketData);
        
        return {
            ...basicContext,
            
            // Additional learning-specific context
            negotiationHistory: this.extractNegotiationHistory(negotiation),
            messagePatterns: this.analyzeMessagePatterns(message, negotiation),
            successIndicators: this.identifySuccessIndicators(message, negotiation),
            riskFactors: this.identifyRiskFactors(message, negotiation),
            
            // Template selection context
            templateContext: {
                strategyType: basicContext.recommendedStrategy,
                landlordPersonality: basicContext.landlordPersonality,
                marketConditions: basicContext.marketConditions,
                priceRange: basicContext.priceRange,
                negotiationStage: basicContext.stage,
                timeContext: basicContext.timeContext
            }
        };
    }

    extractNegotiationHistory(negotiation) {
        if (!negotiation?.messageHistory) return [];
        
        return negotiation.messageHistory.map(msg => ({
            sender: msg.sender_type,
            content_length: msg.content?.length || 0,
            contains_price: /\$\d+/.test(msg.content || ''),
            timestamp: msg.created_at,
            sentiment: this.analyzeSentiment(msg.content || '')
        }));
    }

    analyzeMessagePatterns(message, negotiation) {
        const content = message.content || '';
        
        return {
            length: content.length,
            word_count: content.split(' ').length,
            contains_emoji: /[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]/u.test(content),
            contains_caps: /[A-Z]{3,}/.test(content),
            question_marks: (content.match(/\?/g) || []).length,
            exclamation_marks: (content.match(/!/g) || []).length,
            politeness_indicators: this.countPolitenessIndicators(content)
        };
    }

    identifySuccessIndicators(message, negotiation) {
        const content = message.content?.toLowerCase() || '';
        
        const positiveWords = ['great', 'perfect', 'excellent', 'sounds good', 'agreed', 'deal', 'yes', 'okay'];
        const engagementWords = ['when', 'how', 'what', 'tell me more', 'interested'];
        
        return {
            positive_language: positiveWords.filter(word => content.includes(word)).length,
            engagement_level: engagementWords.filter(word => content.includes(word)).length,
            quick_response: this.isQuickResponse(message, negotiation),
            detailed_response: content.length > 100
        };
    }

    identifyRiskFactors(message, negotiation) {
        const content = message.content?.toLowerCase() || '';
        
        const negativeWords = ['no', 'not interested', 'too high', 'expensive', 'sorry', 'pass'];
        const delayIndicators = ['think about it', 'get back to you', 'need time', 'maybe later'];
        
        return {
            negative_language: negativeWords.filter(word => content.includes(word)).length,
            delay_indicators: delayIndicators.filter(phrase => content.includes(phrase)).length,
            short_response: content.length < 20,
            slow_response: !this.isQuickResponse(message, negotiation)
        };
    }

    analyzeSentiment(content) {
        const positiveWords = ['great', 'good', 'excellent', 'perfect', 'happy', 'pleased', 'wonderful'];
        const negativeWords = ['bad', 'terrible', 'awful', 'disappointed', 'frustrated', 'annoyed'];
        
        const positive = positiveWords.filter(word => content.toLowerCase().includes(word)).length;
        const negative = negativeWords.filter(word => content.toLowerCase().includes(word)).length;
        
        if (positive > negative) return 'positive';
        if (negative > positive) return 'negative';
        return 'neutral';
    }

    countPolitenessIndicators(content) {
        const politenessWords = ['please', 'thank you', 'thanks', 'appreciate', 'grateful', 'kindly'];
        return politenessWords.filter(word => content.toLowerCase().includes(word)).length;
    }

    isQuickResponse(message, negotiation) {
        if (!negotiation?.messageHistory || negotiation.messageHistory.length === 0) return false;
        
        const lastMessage = negotiation.messageHistory[negotiation.messageHistory.length - 1];
        const responseTime = new Date(message.created_at) - new Date(lastMessage.created_at);
        
        return responseTime < 30 * 60 * 1000; // Less than 30 minutes
    }
}

module.exports = ContextAnalyzer;