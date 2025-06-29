class OpenAIHelper {
    constructor() {
        // Try to get OpenAI API key from various sources
        this.apiKey = (typeof window !== 'undefined' && window.config?.OPENAI_API_KEY) || 
                      (typeof process !== 'undefined' && process.env?.OPENAI_API_KEY) ||
                      null;
        this.baseUrl = 'https://api.openai.com/v1';
    }

    async analyzeNegotiationOutcome(conversationData) {
        try {
            const prompt = this.buildAnalysisPrompt(conversationData);
            
            const response = await fetch(`${this.baseUrl}/chat/completions`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    model: 'gpt-3.5-turbo',
                    messages: [
                        {
                            role: 'system',
                            content: 'You are an expert negotiation analyst. Analyze conversations and extract key success patterns.'
                        },
                        {
                            role: 'user',
                            content: prompt
                        }
                    ],
                    max_tokens: 500,
                    temperature: 0.3
                })
            });

            const data = await response.json();
            
            if (data.choices && data.choices[0]) {
                return this.parseAnalysisResponse(data.choices[0].message.content);
            }
            
            return null;
        } catch (error) {
            console.error('OpenAI analysis failed:', error);
            return null;
        }
    }

    buildAnalysisPrompt(conversationData) {
        const messages = conversationData.messages || [];
        const conversationText = messages.map(msg => 
            `${msg.sender_type || 'unknown'}: ${msg.content || ''}`
        ).join('\n');

        return `
Analyze this rental negotiation conversation and identify key success factors:

CONVERSATION:
${conversationText}

OUTCOME: ${conversationData.success ? 'SUCCESS' : 'FAILURE'}
FINAL PRICE: $${conversationData.finalPrice || 'unknown'}
INITIAL PRICE: $${conversationData.initialPrice || 'unknown'}

Please analyze:
1. What communication patterns led to this outcome?
2. What was the landlord's personality/style?
3. What negotiation tactics were effective/ineffective?
4. What timing factors influenced the outcome?
5. How did price positioning affect the result?

Respond in JSON format:
{
    "landlord_personality": "cooperative|aggressive|professional|casual",
    "effective_tactics": ["tactic1", "tactic2"],
    "communication_style": "formal|casual|direct|diplomatic",
    "timing_factor": "good|poor|neutral",
    "price_strategy": "aggressive|moderate|conservative",
    "success_factors": ["factor1", "factor2"],
    "improvement_suggestions": ["suggestion1", "suggestion2"]
}
        `;
    }

    parseAnalysisResponse(response) {
        try {
            // Try to extract JSON from the response
            const jsonMatch = response.match(/\{[\s\S]*\}/);
            if (jsonMatch) {
                return JSON.parse(jsonMatch[0]);
            }
            
            // Fallback parsing if JSON format isn't perfect
            return this.fallbackParse(response);
        } catch (error) {
            console.error('Failed to parse OpenAI response:', error);
            return this.getDefaultAnalysis();
        }
    }

    fallbackParse(response) {
        // Simple text-based parsing as fallback
        const analysis = this.getDefaultAnalysis();
        
        const lowerResponse = response.toLowerCase();
        
        // Extract personality
        if (lowerResponse.includes('cooperative')) analysis.landlord_personality = 'cooperative';
        else if (lowerResponse.includes('aggressive')) analysis.landlord_personality = 'aggressive';
        else if (lowerResponse.includes('professional')) analysis.landlord_personality = 'professional';
        else if (lowerResponse.includes('casual')) analysis.landlord_personality = 'casual';
        
        // Extract communication style
        if (lowerResponse.includes('formal')) analysis.communication_style = 'formal';
        else if (lowerResponse.includes('casual')) analysis.communication_style = 'casual';
        else if (lowerResponse.includes('direct')) analysis.communication_style = 'direct';
        else if (lowerResponse.includes('diplomatic')) analysis.communication_style = 'diplomatic';
        
        return analysis;
    }

    getDefaultAnalysis() {
        return {
            landlord_personality: 'neutral',
            effective_tactics: ['direct_communication'],
            communication_style: 'neutral',
            timing_factor: 'neutral',
            price_strategy: 'moderate',
            success_factors: ['clear_communication'],
            improvement_suggestions: ['maintain_professionalism']
        };
    }

    async generateImprovedResponse(context, unsuccessfulAttempts) {
        try {
            const prompt = this.buildImprovementPrompt(context, unsuccessfulAttempts);
            
            const response = await fetch(`${this.baseUrl}/chat/completions`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    model: 'gpt-3.5-turbo',
                    messages: [
                        {
                            role: 'system',
                            content: 'You are an expert negotiation coach. Generate improved negotiation responses based on context and past failures.'
                        },
                        {
                            role: 'user',
                            content: prompt
                        }
                    ],
                    max_tokens: 200,
                    temperature: 0.7
                })
            });

            const data = await response.json();
            
            if (data.choices && data.choices[0]) {
                return data.choices[0].message.content.trim();
            }
            
            return null;
        } catch (error) {
            console.error('OpenAI response generation failed:', error);
            return null;
        }
    }

    buildImprovementPrompt(context, unsuccessfulAttempts) {
        return `
Generate an improved rental negotiation response based on this context:

STRATEGY: ${context.strategyType}
LANDLORD PERSONALITY: ${context.landlordPersonality}
MARKET CONDITIONS: ${JSON.stringify(context.marketConditions)}
PRICE RANGE: ${context.priceRange}

PREVIOUS UNSUCCESSFUL ATTEMPTS:
${unsuccessfulAttempts.map(attempt => `- ${attempt}`).join('\n')}

Generate a new response that:
1. Avoids the issues from previous attempts
2. Matches the landlord's communication style
3. Adapts to the market conditions
4. Uses appropriate strategy for the price range

Keep the response under 150 words and natural/conversational.
        `;
    }

    async extractConversationInsights(conversations) {
        try {
            const prompt = this.buildInsightsPrompt(conversations);
            
            const response = await fetch(`${this.baseUrl}/chat/completions`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    model: 'gpt-3.5-turbo',
                    messages: [
                        {
                            role: 'system',
                            content: 'You are a data analyst specializing in negotiation patterns. Extract actionable insights from conversation data.'
                        },
                        {
                            role: 'user',
                            content: prompt
                        }
                    ],
                    max_tokens: 600,
                    temperature: 0.2
                })
            });

            const data = await response.json();
            
            if (data.choices && data.choices[0]) {
                return this.parseInsightsResponse(data.choices[0].message.content);
            }
            
            return null;
        } catch (error) {
            console.error('OpenAI insights extraction failed:', error);
            return null;
        }
    }

    buildInsightsPrompt(conversations) {
        const summaries = conversations.map(conv => ({
            success: conv.success,
            template: conv.templateUsed,
            strategy: conv.strategyType,
            savings: conv.finalPrice - conv.initialPrice,
            messageCount: conv.messages?.length || 0
        }));

        return `
Analyze these rental negotiation outcomes and extract key insights:

DATA:
${JSON.stringify(summaries, null, 2)}

Please identify:
1. Which templates/strategies have highest success rates
2. What patterns correlate with better savings
3. How message count affects outcomes
4. Any other significant patterns

Respond in JSON format:
{
    "best_templates": [{"template": 0, "success_rate": 0.8, "avg_savings": 100}],
    "best_strategies": [{"strategy": "market_based", "success_rate": 0.75}],
    "optimal_message_count": 5,
    "key_insights": ["insight1", "insight2"],
    "recommendations": ["rec1", "rec2"]
}
        `;
    }

    parseInsightsResponse(response) {
        try {
            const jsonMatch = response.match(/\{[\s\S]*\}/);
            if (jsonMatch) {
                return JSON.parse(jsonMatch[0]);
            }
            
            return {
                best_templates: [],
                best_strategies: [],
                optimal_message_count: 5,
                key_insights: ['Maintain consistent communication'],
                recommendations: ['Focus on clear value propositions']
            };
        } catch (error) {
            console.error('Failed to parse insights response:', error);
            return null;
        }
    }
}

module.exports = OpenAIHelper;