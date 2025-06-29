class PatternAnalyzer {
    constructor() {
        this.patterns = {
            messageLength: [],
            responseTime: [],
            priceStrategy: [],
            conversationFlow: [],
            landlordBehavior: []
        };
    }

    async initialize() {
        // Initialize any required data or connections
    }

    async analyzeConversation(conversationData) {
        const analysis = {
            success: this.determineSuccess(conversationData),
            templateUsed: this.extractTemplateUsed(conversationData),
            strategyType: this.extractStrategyType(conversationData),
            finalPrice: this.extractFinalPrice(conversationData),
            initialPrice: this.extractInitialPrice(conversationData),
            savingsAchieved: 0,
            landlordPersonality: this.analyzeLandlordPersonality(conversationData),
            marketConditions: this.analyzeMarketConditions(conversationData),
            conversationPatterns: this.extractConversationPatterns(conversationData)
        };

        analysis.savingsAchieved = analysis.initialPrice - analysis.finalPrice;

        return analysis;
    }

    async extractSuccessPatterns(conversationData) {
        const patterns = [];

        // Message length patterns
        const msgLengthPattern = this.analyzeMessageLengths(conversationData);
        if (msgLengthPattern.significance > 0.6) {
            patterns.push({
                type: 'message_length',
                data: msgLengthPattern,
                correlation: msgLengthPattern.successCorrelation,
                confidence: msgLengthPattern.significance
            });
        }

        // Response time patterns
        const responseTimePattern = this.analyzeResponseTimes(conversationData);
        if (responseTimePattern.significance > 0.6) {
            patterns.push({
                type: 'response_time',
                data: responseTimePattern,
                correlation: responseTimePattern.successCorrelation,
                confidence: responseTimePattern.significance
            });
        }

        // Price negotiation patterns
        const pricePattern = this.analyzePriceStrategy(conversationData);
        if (pricePattern.significance > 0.6) {
            patterns.push({
                type: 'price_strategy',
                data: pricePattern,
                correlation: pricePattern.successCorrelation,
                confidence: pricePattern.significance
            });
        }

        // Conversation flow patterns
        const flowPattern = this.analyzeConversationFlow(conversationData);
        if (flowPattern.significance > 0.6) {
            patterns.push({
                type: 'conversation_flow',
                data: flowPattern,
                correlation: flowPattern.successCorrelation,
                confidence: flowPattern.significance
            });
        }

        return patterns;
    }

    determineSuccess(conversationData) {
        // Check for success indicators in the conversation
        const messages = conversationData.messages || [];
        const lastMessages = messages.slice(-3); // Last 3 messages
        
        const successKeywords = [
            'deal', 'agreed', 'accept', 'sounds good', 'perfect', 'great',
            'yes', 'okay', 'alright', 'confirmed', 'moving forward'
        ];

        const failureKeywords = [
            'no', 'not interested', 'too high', 'can\'t do', 'sorry',
            'not possible', 'decline', 'pass', 'not working'
        ];

        let successScore = 0;
        let failureScore = 0;

        lastMessages.forEach(msg => {
            const content = msg.content?.toLowerCase() || '';
            successKeywords.forEach(keyword => {
                if (content.includes(keyword)) successScore++;
            });
            failureKeywords.forEach(keyword => {
                if (content.includes(keyword)) failureScore++;
            });
        });

        return successScore > failureScore;
    }

    extractTemplateUsed(conversationData) {
        // Extract which template was used based on message content
        // This would need to be enhanced based on your specific template system
        return conversationData.templateUsed || Math.floor(Math.random() * 8); // Placeholder
    }

    extractStrategyType(conversationData) {
        const messages = conversationData.messages || [];
        const botMessages = messages.filter(msg => msg.sender_type === 'bot' || msg.is_ai);
        
        // Analyze bot messages to determine strategy type
        const content = botMessages.map(msg => msg.content?.toLowerCase() || '').join(' ');
        
        if (content.includes('market') || content.includes('comparable')) {
            return 'market_based_responses';
        } else if (content.includes('deposit') || content.includes('security')) {
            return 'security_deposit';
        } else if (content.includes('counter') || content.includes('offer')) {
            return 'strategic_counter_offers';
        } else if (content.includes('accept') || content.includes('agree')) {
            return 'counter_offer_acceptance';
        } else if (content.includes('move') || content.includes('when')) {
            return 'move_in_logistics';
        } else if (content.includes('increase') || content.includes('higher')) {
            return 'increase_request';
        }
        
        return 'general_negotiation';
    }

    extractFinalPrice(conversationData) {
        const messages = conversationData.messages || [];
        const priceRegex = /\$(\d{1,3}(?:,\d{3})*)/g;
        
        // Look for prices in the last few messages
        const recentMessages = messages.slice(-5);
        let finalPrice = 0;
        
        recentMessages.reverse().forEach(msg => {
            const matches = msg.content?.match(priceRegex);
            if (matches && finalPrice === 0) {
                finalPrice = parseInt(matches[0].replace(/[$,]/g, ''));
            }
        });
        
        return finalPrice || conversationData.finalPrice || 0;
    }

    extractInitialPrice(conversationData) {
        const messages = conversationData.messages || [];
        const priceRegex = /\$(\d{1,3}(?:,\d{3})*)/g;
        
        // Look for prices in the first few messages
        const initialMessages = messages.slice(0, 3);
        let initialPrice = 0;
        
        initialMessages.forEach(msg => {
            const matches = msg.content?.match(priceRegex);
            if (matches && initialPrice === 0) {
                initialPrice = parseInt(matches[0].replace(/[$,]/g, ''));
            }
        });
        
        return initialPrice || conversationData.initialPrice || 0;
    }

    analyzeLandlordPersonality(conversationData) {
        const messages = conversationData.messages || [];
        const landlordMessages = messages.filter(msg => 
            msg.sender_type === 'landlord' || (!msg.is_ai && msg.sender_email !== conversationData.user_email)
        );
        
        if (landlordMessages.length === 0) return 'unknown';
        
        const content = landlordMessages.map(msg => msg.content?.toLowerCase() || '').join(' ');
        const responseSpeed = this.calculateAverageResponseTime(landlordMessages);
        
        // Analyze personality traits
        let cooperativeScore = 0;
        let aggressiveScore = 0;
        let professionalScore = 0;
        
        // Cooperative indicators
        ['sure', 'okay', 'sounds good', 'reasonable', 'flexible', 'understand'].forEach(word => {
            if (content.includes(word)) cooperativeScore++;
        });
        
        // Aggressive indicators
        ['no', 'firm', 'final', 'won\'t', 'can\'t', 'impossible', 'non-negotiable'].forEach(word => {
            if (content.includes(word)) aggressiveScore++;
        });
        
        // Professional indicators
        ['property', 'lease', 'terms', 'application', 'credit', 'references'].forEach(word => {
            if (content.includes(word)) professionalScore++;
        });
        
        if (cooperativeScore > aggressiveScore && cooperativeScore > professionalScore) {
            return 'cooperative';
        } else if (aggressiveScore > cooperativeScore && aggressiveScore > professionalScore) {
            return 'aggressive';
        } else if (professionalScore > 0) {
            return 'professional';
        }
        
        return 'neutral';
    }

    analyzeMarketConditions(conversationData) {
        // This would integrate with your market data
        return {
            priceRange: this.determinePriceRange(conversationData),
            marketTrend: 'stable', // Could be 'rising', 'falling', 'stable'
            competitiveness: 'medium', // Could be 'high', 'medium', 'low'
            season: this.getCurrentSeason(),
            dayOfWeek: new Date().toLocaleDateString('en-US', { weekday: 'long' })
        };
    }

    extractConversationPatterns(conversationData) {
        const messages = conversationData.messages || [];
        
        return {
            totalMessages: messages.length,
            averageMessageLength: this.calculateAverageMessageLength(messages),
            averageResponseTime: this.calculateAverageResponseTime(messages),
            conversationDuration: this.calculateConversationDuration(messages),
            messagesByHour: this.groupMessagesByHour(messages),
            topicProgression: this.analyzeTopicProgression(messages)
        };
    }

    analyzeMessageLengths(conversationData) {
        const messages = conversationData.messages || [];
        const lengths = messages.map(msg => msg.content?.length || 0);
        
        const avgLength = lengths.reduce((sum, len) => sum + len, 0) / lengths.length;
        const shortMessages = lengths.filter(len => len < 50).length;
        const longMessages = lengths.filter(len => len > 200).length;
        
        return {
            averageLength: avgLength,
            shortMessageRatio: shortMessages / lengths.length,
            longMessageRatio: longMessages / lengths.length,
            successCorrelation: this.calculateSuccessCorrelation('message_length', avgLength),
            significance: this.calculateSignificance(lengths)
        };
    }

    analyzeResponseTimes(conversationData) {
        const messages = conversationData.messages || [];
        const responseTimes = [];
        
        for (let i = 1; i < messages.length; i++) {
            const timeDiff = new Date(messages[i].created_at) - new Date(messages[i-1].created_at);
            responseTimes.push(timeDiff / 1000 / 60); // Convert to minutes
        }
        
        const avgResponseTime = responseTimes.reduce((sum, time) => sum + time, 0) / responseTimes.length;
        
        return {
            averageResponseTime: avgResponseTime,
            fastResponses: responseTimes.filter(time => time < 5).length,
            slowResponses: responseTimes.filter(time => time > 60).length,
            successCorrelation: this.calculateSuccessCorrelation('response_time', avgResponseTime),
            significance: this.calculateSignificance(responseTimes)
        };
    }

    analyzePriceStrategy(conversationData) {
        const messages = conversationData.messages || [];
        const priceRegex = /\$(\d{1,3}(?:,\d{3})*)/g;
        
        const prices = [];
        messages.forEach(msg => {
            const matches = msg.content?.match(priceRegex);
            if (matches) {
                matches.forEach(match => {
                    prices.push(parseInt(match.replace(/[$,]/g, '')));
                });
            }
        });
        
        const priceReductions = [];
        for (let i = 1; i < prices.length; i++) {
            if (prices[i] < prices[i-1]) {
                priceReductions.push(prices[i-1] - prices[i]);
            }
        }
        
        return {
            totalPricePoints: prices.length,
            averageReduction: priceReductions.length > 0 ? 
                priceReductions.reduce((sum, red) => sum + red, 0) / priceReductions.length : 0,
            numberOfReductions: priceReductions.length,
            successCorrelation: this.calculateSuccessCorrelation('price_strategy', priceReductions.length),
            significance: this.calculateSignificance(priceReductions)
        };
    }

    analyzeConversationFlow(conversationData) {
        const messages = conversationData.messages || [];
        const topics = messages.map(msg => this.extractTopics(msg.content || ''));
        
        const topicTransitions = [];
        for (let i = 1; i < topics.length; i++) {
            if (topics[i] !== topics[i-1]) {
                topicTransitions.push({
                    from: topics[i-1],
                    to: topics[i],
                    messageIndex: i
                });
            }
        }
        
        return {
            totalTopicChanges: topicTransitions.length,
            averageTopicDuration: messages.length / (topicTransitions.length + 1),
            topicProgression: topicTransitions,
            successCorrelation: this.calculateSuccessCorrelation('conversation_flow', topicTransitions.length),
            significance: this.calculateSignificance(topicTransitions.map(t => t.messageIndex))
        };
    }

    calculateAverageMessageLength(messages) {
        if (messages.length === 0) return 0;
        const totalLength = messages.reduce((sum, msg) => sum + (msg.content?.length || 0), 0);
        return totalLength / messages.length;
    }

    calculateAverageResponseTime(messages) {
        if (messages.length < 2) return 0;
        
        let totalTime = 0;
        for (let i = 1; i < messages.length; i++) {
            const timeDiff = new Date(messages[i].created_at) - new Date(messages[i-1].created_at);
            totalTime += timeDiff;
        }
        
        return totalTime / (messages.length - 1) / 1000 / 60; // Convert to minutes
    }

    calculateConversationDuration(messages) {
        if (messages.length < 2) return 0;
        
        const start = new Date(messages[0].created_at);
        const end = new Date(messages[messages.length - 1].created_at);
        
        return (end - start) / 1000 / 60 / 60; // Convert to hours
    }

    groupMessagesByHour(messages) {
        const hourGroups = {};
        messages.forEach(msg => {
            const hour = new Date(msg.created_at).getHours();
            if (!hourGroups[hour]) hourGroups[hour] = 0;
            hourGroups[hour]++;
        });
        return hourGroups;
    }

    analyzeTopicProgression(messages) {
        return messages.map(msg => this.extractTopics(msg.content || ''));
    }

    extractTopics(content) {
        const lowerContent = content.toLowerCase();
        
        if (lowerContent.includes('price') || lowerContent.includes('rent') || lowerContent.includes('$')) {
            return 'pricing';
        } else if (lowerContent.includes('deposit') || lowerContent.includes('security')) {
            return 'deposit';
        } else if (lowerContent.includes('move') || lowerContent.includes('date')) {
            return 'move_in';
        } else if (lowerContent.includes('property') || lowerContent.includes('apartment')) {
            return 'property_details';
        } else if (lowerContent.includes('application') || lowerContent.includes('lease')) {
            return 'application_process';
        }
        
        return 'general';
    }

    calculateSuccessCorrelation(patternType, value) {
        // Simplified correlation calculation
        // In a real implementation, this would use historical data
        const correlations = {
            'message_length': value > 100 ? 0.7 : 0.4,
            'response_time': value < 30 ? 0.8 : 0.5,
            'price_strategy': value > 1 ? 0.9 : 0.6,
            'conversation_flow': value < 5 ? 0.8 : 0.6
        };
        
        return correlations[patternType] || 0.5;
    }

    calculateSignificance(values) {
        if (values.length < 2) return 0;
        
        const mean = values.reduce((sum, val) => sum + val, 0) / values.length;
        const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;
        const standardDeviation = Math.sqrt(variance);
        
        // Simple significance calculation
        return Math.min(0.99, standardDeviation > 0 ? Math.abs(mean) / standardDeviation * 0.1 : 0);
    }

    determinePriceRange(conversationData) {
        const finalPrice = this.extractFinalPrice(conversationData);
        
        if (finalPrice < 1000) return 'budget';
        if (finalPrice < 2000) return 'moderate';
        if (finalPrice < 3000) return 'premium';
        return 'luxury';
    }

    getCurrentSeason() {
        const month = new Date().getMonth();
        if (month >= 2 && month <= 4) return 'spring';
        if (month >= 5 && month <= 7) return 'summer';
        if (month >= 8 && month <= 10) return 'fall';
        return 'winter';
    }
}

module.exports = PatternAnalyzer;