/**
 * iOS-Compatible AI API for RoomFinderAI
 * 
 * This module provides iOS-compatible AI functionality that replaces all
 * OpenAI API calls with @capacitor/http for reliable iOS networking.
 */

import { fetch } from './ios-universal-fetch.js';
import { createClient } from './ios-supabase-client.js';
import iosAuthManager from './ios-auth-manager.js';

// API Configuration
const OPENAI_API_URL = 'https://api.openai.com/v1';
const BACKEND_API_URL = 'https://roomfinder-ai-negotiator-production.up.railway.app/api';

class IOSAIApi {
    constructor() {
        this.supabase = createClient(
            'https://zmxyysauqtfkvntgtjsm.supabase.co',
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM'
        );
        this.debug = true;
        this.apiKey = null;
        
        if (this.debug) {
            console.log('🤖 iOS AI API initialized');
        }
    }

    /**
     * Set OpenAI API key
     */
    setApiKey(apiKey) {
        this.apiKey = apiKey;
        if (this.debug) {
            console.log('🔑 OpenAI API key set');
        }
    }

    /**
     * Get API key from environment or storage
     */
    getApiKey() {
        if (this.apiKey) {
            return this.apiKey;
        }
        
        // Try to get from localStorage or other storage
        if (typeof undefined !== 'undefined') {
            const storedKey = null;
            if (storedKey) {
                this.apiKey = storedKey;
                return storedKey;
            }
        }
        
        // Fallback to environment variable or default
        return process.env.OPENAI_API_KEY || 'your-openai-api-key-here';
    }

    /**
     * Send chat completion request to OpenAI
     */
    async sendChatCompletion(messages, options = {}) {
        try {
            const apiKey = this.getApiKey();
            if (!apiKey || apiKey === 'your-openai-api-key-here') {
                throw new Error('OpenAI API key not configured');
            }

            if (this.debug) {
                console.log('🤖 Sending chat completion request with', messages.length, 'messages');
            }

            const requestData = {
                model: options.model || 'gpt-3.5-turbo',
                messages: messages,
                max_tokens: options.maxTokens || 1000,
                temperature: options.temperature || 0.7,
                stream: false
            };

            const response = await fetch(`${OPENAI_API_URL}/chat/completions`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${apiKey}`,
                    'Content-Type': 'application/json',
                    'OpenAI-Organization': options.organization || ''
                },
                body: JSON.stringify(requestData)
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`OpenAI API error: ${errorData.error?.message || response.statusText}`);
            }

            const data = await response.json();

            if (this.debug) {
                console.log('✅ OpenAI chat completion successful');
            }

            return { data, error: null };
        } catch (error) {
            console.error('❌ OpenAI chat completion error:', error);
            return { data: null, error };
        }
    }

    /**
     * AI-powered property search
     */
    async searchProperties(query, userPreferences = {}) {
        try {
            if (this.debug) {
                console.log('🔍 AI property search for:', query);
            }

            // Get listings from database
            const listings = await this.supabase
                .from('listings')
                .select('*')
                .eq('status', 'active')
                .limit(50)
                .exec();

            // Create AI prompt for property matching
            const systemPrompt = `You are a real estate AI assistant. Help users find properties that match their needs. 
            Analyze the user's query and preferences, then recommend the most suitable properties from the available listings.
            
            User preferences: ${JSON.stringify(userPreferences)}
            
            Available properties: ${JSON.stringify(listings.slice(0, 10))}
            
            Respond with:
            1. A brief explanation of what you understood from their query
            2. Top 3-5 property recommendations with specific reasons why each matches
            3. Any questions to help refine their search
            
            Be conversational and helpful.`;

            const messages = [
                { role: 'system', content: systemPrompt },
                { role: 'user', content: query }
            ];

            const aiResponse = await this.sendChatCompletion(messages, {
                model: 'gpt-3.5-turbo',
                maxTokens: 800,
                temperature: 0.7
            });

            if (aiResponse.error) {
                throw aiResponse.error;
            }

            const aiRecommendation = aiResponse.data.choices[0].message.content;

            if (this.debug) {
                console.log('✅ AI property search completed');
            }

            return { 
                data: {
                    recommendation: aiRecommendation,
                    listings: listings.slice(0, 10),
                    searchQuery: query
                }, 
                error: null 
            };
        } catch (error) {
            console.error('❌ AI property search error:', error);
            return { data: null, error };
        }
    }

    /**
     * AI-powered rental negotiation
     */
    async negotiateRental(listingId, userMessage, negotiationContext = {}) {
        try {
            if (this.debug) {
                console.log('💰 AI rental negotiation for listing:', listingId);
            }

            // Get listing details
            const listing = await this.supabase
                .from('listings')
                .select('*')
                .eq('id', listingId)
                .single()
                .exec();

            if (!listing) {
                throw new Error('Listing not found');
            }

            // Create negotiation prompt
            const systemPrompt = `You are a professional rental negotiation assistant. Help users negotiate rental terms tactfully and professionally.
            
            Property details: ${JSON.stringify(listing)}
            Negotiation context: ${JSON.stringify(negotiationContext)}
            
            Guidelines:
            1. Be professional and respectful
            2. Provide specific, data-driven arguments
            3. Suggest reasonable counter-offers
            4. Consider market conditions and property value
            5. Maintain a collaborative tone
            
            Respond with negotiation strategy and suggested talking points.`;

            const messages = [
                { role: 'system', content: systemPrompt },
                { role: 'user', content: userMessage }
            ];

            const aiResponse = await this.sendChatCompletion(messages, {
                model: 'gpt-3.5-turbo',
                maxTokens: 600,
                temperature: 0.8
            });

            if (aiResponse.error) {
                throw aiResponse.error;
            }

            const negotiationAdvice = aiResponse.data.choices[0].message.content;

            if (this.debug) {
                console.log('✅ AI rental negotiation completed');
            }

            return { 
                data: {
                    advice: negotiationAdvice,
                    listing: listing,
                    context: negotiationContext
                }, 
                error: null 
            };
        } catch (error) {
            console.error('❌ AI rental negotiation error:', error);
            return { data: null, error };
        }
    }

    /**
     * AI-powered chat responses
     */
    async generateChatResponse(conversationHistory, currentMessage, context = {}) {
        try {
            if (this.debug) {
                console.log('💬 Generating AI chat response');
            }

            const systemPrompt = `You are a helpful real estate assistant for RoomFinderAI. Help users with property-related questions, provide information about listings, and assist with rental decisions.
            
            Context: ${JSON.stringify(context)}
            
            Guidelines:
            1. Be helpful and informative
            2. Stay focused on real estate topics
            3. Provide accurate information about properties
            4. Suggest next steps when appropriate
            5. Be friendly but professional
            
            Conversation history: ${JSON.stringify(conversationHistory.slice(-10))}`;

            const messages = [
                { role: 'system', content: systemPrompt },
                ...conversationHistory.slice(-5),
                { role: 'user', content: currentMessage }
            ];

            const aiResponse = await this.sendChatCompletion(messages, {
                model: 'gpt-3.5-turbo',
                maxTokens: 500,
                temperature: 0.7
            });

            if (aiResponse.error) {
                throw aiResponse.error;
            }

            const response = aiResponse.data.choices[0].message.content;

            if (this.debug) {
                console.log('✅ AI chat response generated');
            }

            return { data: response, error: null };
        } catch (error) {
            console.error('❌ AI chat response error:', error);
            return { data: null, error };
        }
    }

    /**
     * AI-powered property analysis
     */
    async analyzeProperty(listingId, analysisType = 'general') {
        try {
            if (this.debug) {
                console.log('🏠 AI property analysis for listing:', listingId);
            }

            // Get listing details
            const listing = await this.supabase
                .from('listings')
                .select('*')
                .eq('id', listingId)
                .single()
                .exec();

            if (!listing) {
                throw new Error('Listing not found');
            }

            let systemPrompt = '';
            
            switch (analysisType) {
                case 'investment':
                    systemPrompt = `You are a real estate investment advisor. Analyze this property for investment potential.
                    
                    Property: ${JSON.stringify(listing)}
                    
                    Provide analysis on:
                    1. Investment potential and ROI estimates
                    2. Market trends in the area
                    3. Rental yield potential
                    4. Risk factors to consider
                    5. Recommendations for investors`;
                    break;
                    
                case 'valuation':
                    systemPrompt = `You are a property valuation expert. Analyze this property's market value.
                    
                    Property: ${JSON.stringify(listing)}
                    
                    Provide analysis on:
                    1. Current market value assessment
                    2. Comparable properties in the area
                    3. Factors affecting value
                    4. Price trend predictions
                    5. Fair market rent estimate`;
                    break;
                    
                default:
                    systemPrompt = `You are a real estate expert. Provide a comprehensive analysis of this property.
                    
                    Property: ${JSON.stringify(listing)}
                    
                    Provide analysis on:
                    1. Property highlights and features
                    2. Location advantages and disadvantages
                    3. Market positioning
                    4. Target tenant profile
                    5. Overall assessment and recommendations`;
            }

            const messages = [
                { role: 'system', content: systemPrompt },
                { role: 'user', content: `Please analyze this property: ${listing.title}` }
            ];

            const aiResponse = await this.sendChatCompletion(messages, {
                model: 'gpt-3.5-turbo',
                maxTokens: 800,
                temperature: 0.6
            });

            if (aiResponse.error) {
                throw aiResponse.error;
            }

            const analysis = aiResponse.data.choices[0].message.content;

            if (this.debug) {
                console.log('✅ AI property analysis completed');
            }

            return { 
                data: {
                    analysis: analysis,
                    listing: listing,
                    analysisType: analysisType
                }, 
                error: null 
            };
        } catch (error) {
            console.error('❌ AI property analysis error:', error);
            return { data: null, error };
        }
    }

    /**
     * AI-powered listing enhancement
     */
    async enhanceListing(listingData, enhancementType = 'description') {
        try {
            if (this.debug) {
                console.log('✨ AI listing enhancement:', enhancementType);
            }

            let systemPrompt = '';
            
            switch (enhancementType) {
                case 'description':
                    systemPrompt = `You are a professional real estate copywriter. Create an engaging property description.
                    
                    Property details: ${JSON.stringify(listingData)}
                    
                    Create a compelling description that:
                    1. Highlights key features and benefits
                    2. Appeals to the target audience
                    3. Uses persuasive language
                    4. Includes lifestyle benefits
                    5. Maintains professional tone
                    
                    Keep it concise but impactful.`;
                    break;
                    
                case 'title':
                    systemPrompt = `You are a real estate marketing expert. Create an attention-grabbing property title.
                    
                    Property details: ${JSON.stringify(listingData)}
                    
                    Create a title that:
                    1. Captures attention immediately
                    2. Highlights the main selling points
                    3. Is SEO-friendly
                    4. Appeals to target renters
                    5. Is under 60 characters
                    
                    Provide 3-5 title options.`;
                    break;
                    
                case 'pricing':
                    systemPrompt = `You are a real estate pricing strategist. Analyze and suggest optimal pricing.
                    
                    Property details: ${JSON.stringify(listingData)}
                    
                    Provide pricing analysis:
                    1. Market rate analysis
                    2. Competitive pricing strategy
                    3. Pricing recommendations
                    4. Seasonal considerations
                    5. Value-add opportunities`;
                    break;
                    
                default:
                    systemPrompt = `You are a real estate enhancement expert. Improve this property listing.
                    
                    Property details: ${JSON.stringify(listingData)}
                    
                    Provide suggestions for:
                    1. Improved description
                    2. Better title options
                    3. Feature highlights
                    4. Marketing angles
                    5. Presentation improvements`;
            }

            const messages = [
                { role: 'system', content: systemPrompt },
                { role: 'user', content: `Please enhance this listing: ${listingData.title || 'Property listing'}` }
            ];

            const aiResponse = await this.sendChatCompletion(messages, {
                model: 'gpt-3.5-turbo',
                maxTokens: 600,
                temperature: 0.8
            });

            if (aiResponse.error) {
                throw aiResponse.error;
            }

            const enhancement = aiResponse.data.choices[0].message.content;

            if (this.debug) {
                console.log('✅ AI listing enhancement completed');
            }

            return { 
                data: {
                    enhancement: enhancement,
                    enhancementType: enhancementType,
                    originalListing: listingData
                }, 
                error: null 
            };
        } catch (error) {
            console.error('❌ AI listing enhancement error:', error);
            return { data: null, error };
        }
    }

    /**
     * AI-powered market insights
     */
    async getMarketInsights(location, propertyType = 'apartment') {
        try {
            if (this.debug) {
                console.log('📊 AI market insights for:', location);
            }

            // Get recent listings in the area
            const recentListings = await this.supabase
                .from('listings')
                .select('*')
                .like('location', `%${location}%`)
                .eq('category', propertyType)
                .order('created_at', { ascending: false })
                .limit(20)
                .exec();

            const systemPrompt = `You are a real estate market analyst. Provide market insights for this location.
            
            Location: ${location}
            Property type: ${propertyType}
            Recent listings: ${JSON.stringify(recentListings.slice(0, 10))}
            
            Provide insights on:
            1. Current market conditions
            2. Average rental prices
            3. Supply and demand trends
            4. Seasonal patterns
            5. Investment opportunities
            6. Future market predictions
            
            Base your analysis on the provided data and general market knowledge.`;

            const messages = [
                { role: 'system', content: systemPrompt },
                { role: 'user', content: `Please provide market insights for ${propertyType} rentals in ${location}` }
            ];

            const aiResponse = await this.sendChatCompletion(messages, {
                model: 'gpt-3.5-turbo',
                maxTokens: 700,
                temperature: 0.6
            });

            if (aiResponse.error) {
                throw aiResponse.error;
            }

            const insights = aiResponse.data.choices[0].message.content;

            if (this.debug) {
                console.log('✅ AI market insights completed');
            }

            return { 
                data: {
                    insights: insights,
                    location: location,
                    propertyType: propertyType,
                    listingCount: recentListings.length
                }, 
                error: null 
            };
        } catch (error) {
            console.error('❌ AI market insights error:', error);
            return { data: null, error };
        }
    }

    /**
     * Use backend AI service for complex operations
     */
    async useBackendAI(endpoint, data) {
        try {
            if (this.debug) {
                console.log('🔄 Using backend AI service:', endpoint);
            }

            const response = await fetch(`${BACKEND_API_URL}/${endpoint}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.getApiKey()}`
                },
                body: JSON.stringify(data)
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(`Backend AI error: ${errorData.error || response.statusText}`);
            }

            const result = await response.json();

            if (this.debug) {
                console.log('✅ Backend AI service completed');
            }

            return { data: result, error: null };
        } catch (error) {
            console.error('❌ Backend AI service error:', error);
            return { data: null, error };
        }
    }
}

// Create singleton instance
const iosAIApi = new IOSAIApi();

/**
 * Export singleton instance
 */
export default iosAIApi;

/**
 * Export AI functions for convenience
 */
export const {
    setApiKey,
    sendChatCompletion,
    searchProperties,
    negotiateRental,
    generateChatResponse,
    analyzeProperty,
    enhanceListing,
    getMarketInsights,
    useBackendAI
} = iosAIApi;

console.log('✅ iOS AI API module loaded successfully');