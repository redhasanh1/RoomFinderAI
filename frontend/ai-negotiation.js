// AI Negotiation Engine for RoomFinderAI
// Handles landlord communication, negotiation strategies, and deal closing

class AINegotiationEngine {
    constructor(supabase, config) {
        this.supabase = supabase;
        this.config = config;
        this.activeNegotiations = new Map();
        this.negotiationStrategies = new Map();
        this.communicationTemplates = new Map();
        this.userPreferences = {};
        this.negotiationHistory = [];
        
        // Initialize negotiation strategies
        this.initializeStrategies();
        this.initializeCommunicationTemplates();
        
        console.log('🤝 AI Negotiation Engine initialized');
    }

    // Initialize negotiation strategies
    initializeStrategies() {
        this.negotiationStrategies.set('price_reduction', {
            name: 'Price Reduction',
            description: 'Negotiate lower rent based on market analysis',
            tactics: [
                'Market comparison analysis',
                'Highlight tenant strengths',
                'Propose longer lease for discount',
                'Point out property limitations'
            ],
            successRate: 0.65
        });

        this.negotiationStrategies.set('lease_terms', {
            name: 'Lease Terms',
            description: 'Negotiate better lease conditions',
            tactics: [
                'Pet policy adjustments',
                'Utilities inclusion',
                'Parking space inclusion',
                'Early termination clause'
            ],
            successRate: 0.75
        });

        this.negotiationStrategies.set('move_in_benefits', {
            name: 'Move-in Benefits',
            description: 'Request move-in incentives',
            tactics: [
                'Waived security deposit',
                'First month rent discount',
                'Free utilities for initial period',
                'Property improvements'
            ],
            successRate: 0.55
        });
    }

    // Initialize communication templates
    initializeCommunicationTemplates() {
        this.communicationTemplates.set('initial_inquiry', {
            subject: 'Interest in Your Property - {propertyAddress}',
            template: `Hello,

I am very interested in your property at {propertyAddress}. I am a {tenantProfile} looking for a {propertyType} in this area.

{personalizedMessage}

I would love to schedule a viewing at your convenience. Please let me know your availability.

Best regards,
{tenantName}
{tenantContact}`
        });

        this.communicationTemplates.set('price_negotiation', {
            subject: 'Rental Rate Discussion - {propertyAddress}',
            template: `Hello,

Thank you for showing me the property at {propertyAddress}. I am very interested and would like to discuss the rental terms.

{negotiationPoints}

I am prepared to move in quickly and can provide excellent references. Would you be open to discussing these terms?

Best regards,
{tenantName}`
        });

        this.communicationTemplates.set('application_submission', {
            subject: 'Rental Application - {propertyAddress}',
            template: `Hello,

I am pleased to submit my application for the property at {propertyAddress}. I have attached all required documents.

{applicationSummary}

I look forward to hearing from you soon.

Best regards,
{tenantName}`
        });
    }

    // Start a new negotiation process
    async startNegotiation(propertyId, userPreferences, negotiationGoals) {
        try {
            console.log('🎯 Starting negotiation for property:', propertyId);

            // Get property details
            const { data: property, error: propertyError } = await this.supabase
                .from('listings')
                .select('*')
                .eq('id', propertyId)
                .single();

            if (propertyError || !property) {
                throw new Error('Property not found');
            }

            // Analyze market data for this property
            const marketAnalysis = await this.analyzeMarketData(property);

            // Generate negotiation strategy
            const strategy = this.generateNegotiationStrategy(property, userPreferences, marketAnalysis);

            // Create negotiation record
            const negotiationId = `neg_${Date.now()}_${propertyId}`;
            const negotiation = {
                id: negotiationId,
                propertyId: propertyId,
                property: property,
                userPreferences: userPreferences,
                goals: negotiationGoals,
                strategy: strategy,
                status: 'active',
                createdAt: new Date().toISOString(),
                messages: [],
                milestones: []
            };

            this.activeNegotiations.set(negotiationId, negotiation);

            console.log('✅ Negotiation started successfully:', negotiationId);
            return negotiation;

        } catch (error) {
            console.error('❌ Error starting negotiation:', error);
            throw error;
        }
    }

    // Analyze market data for property
    async analyzeMarketData(property) {
        // Simulate market analysis - in real implementation, this would
        // query market data APIs and local rental database
        const analysis = {
            averageRentInArea: property.price * (0.9 + Math.random() * 0.2),
            marketTrend: Math.random() > 0.5 ? 'increasing' : 'stable',
            comparableProperties: Math.floor(Math.random() * 10) + 5,
            daysOnMarket: Math.floor(Math.random() * 30) + 7,
            seasonalFactor: this.getSeasonalFactor(),
            negotiationPotential: Math.random() * 0.4 + 0.1 // 10-50% potential savings
        };

        console.log('📊 Market analysis completed for property');
        return analysis;
    }

    // Get seasonal factor for rental market
    getSeasonalFactor() {
        const month = new Date().getMonth();
        const seasonalFactors = {
            0: 0.85,  // January - Low demand
            1: 0.90,  // February
            2: 0.95,  // March - Spring pickup
            3: 1.00,  // April
            4: 1.05,  // May - Peak season
            5: 1.10,  // June - Peak season
            6: 1.05,  // July
            7: 1.00,  // August
            8: 0.95,  // September
            9: 0.90,  // October
            10: 0.85, // November - Low demand
            11: 0.80  // December - Lowest demand
        };
        return seasonalFactors[month] || 1.0;
    }

    // Generate negotiation strategy based on property and market data
    generateNegotiationStrategy(property, userPreferences, marketAnalysis) {
        const strategies = [];

        // Price negotiation strategy
        if (marketAnalysis.negotiationPotential > 0.2) {
            strategies.push({
                type: 'price_reduction',
                priority: 'high',
                arguments: [
                    `Market analysis shows similar properties average $${Math.round(marketAnalysis.averageRentInArea)}/month`,
                    `Property has been on market for ${marketAnalysis.daysOnMarket} days`,
                    `Seasonal factor suggests ${(1 - marketAnalysis.seasonalFactor) * 100}% lower demand`
                ],
                targetReduction: Math.round(property.price * marketAnalysis.negotiationPotential)
            });
        }

        // Lease terms strategy
        if (userPreferences.flexibleTerms) {
            strategies.push({
                type: 'lease_terms',
                priority: 'medium',
                requests: [
                    'Include utilities in rent',
                    'Allow pets with reduced deposit',
                    'Flexible lease start date'
                ]
            });
        }

        // Move-in benefits strategy
        strategies.push({
            type: 'move_in_benefits',
            priority: 'low',
            requests: [
                'Waive application fee',
                'Reduced security deposit',
                'First month pro-rated rent'
            ]
        });

        return {
            primaryStrategy: strategies[0],
            alternativeStrategies: strategies.slice(1),
            estimatedTimeline: '3-7 days',
            successProbability: this.calculateSuccessProbability(strategies, marketAnalysis)
        };
    }

    // Calculate success probability for negotiation
    calculateSuccessProbability(strategies, marketAnalysis) {
        let baseProbability = 0.5;
        
        // Adjust based on market conditions
        if (marketAnalysis.marketTrend === 'increasing') {
            baseProbability -= 0.1;
        }
        
        // Adjust based on days on market
        if (marketAnalysis.daysOnMarket > 20) {
            baseProbability += 0.2;
        }
        
        // Adjust based on seasonal factor
        baseProbability += (1 - marketAnalysis.seasonalFactor) * 0.3;
        
        return Math.min(Math.max(baseProbability, 0.1), 0.9);
    }

    // Generate personalized message for landlord
    generateMessage(templateKey, propertyData, userProfile, customization = {}) {
        const template = this.communicationTemplates.get(templateKey);
        if (!template) {
            throw new Error(`Template not found: ${templateKey}`);
        }

        let message = template.template;
        
        // Replace placeholders
        message = message.replace(/{propertyAddress}/g, propertyData.address || propertyData.location || 'the property');
        message = message.replace(/{propertyType}/g, propertyData.property_type || 'rental property');
        message = message.replace(/{tenantName}/g, userProfile.name || 'Prospective Tenant');
        message = message.replace(/{tenantContact}/g, userProfile.email || '');
        message = message.replace(/{tenantProfile}/g, this.generateTenantProfile(userProfile));
        
        // Add customized content
        if (customization.personalizedMessage) {
            message = message.replace(/{personalizedMessage}/g, customization.personalizedMessage);
        }
        
        if (customization.negotiationPoints) {
            message = message.replace(/{negotiationPoints}/g, customization.negotiationPoints);
        }
        
        if (customization.applicationSummary) {
            message = message.replace(/{applicationSummary}/g, customization.applicationSummary);
        }

        return {
            subject: template.subject.replace(/{propertyAddress}/g, propertyData.address || propertyData.location || 'Property'),
            body: message
        };
    }

    // Generate tenant profile description
    generateTenantProfile(userProfile) {
        const profiles = [
            'reliable professional',
            'responsible tenant',
            'long-term renter',
            'working professional',
            'graduate student',
            'young professional'
        ];
        
        return profiles[Math.floor(Math.random() * profiles.length)];
    }

    // Update negotiation status
    updateNegotiationStatus(negotiationId, status, notes = '') {
        const negotiation = this.activeNegotiations.get(negotiationId);
        if (negotiation) {
            negotiation.status = status;
            negotiation.lastUpdated = new Date().toISOString();
            if (notes) {
                negotiation.notes = (negotiation.notes || '') + '\n' + notes;
            }
            
            console.log(`📝 Updated negotiation ${negotiationId} status to: ${status}`);
        }
    }

    // Get negotiation by ID
    getNegotiation(negotiationId) {
        return this.activeNegotiations.get(negotiationId);
    }

    // Get all active negotiations
    getActiveNegotiations() {
        return Array.from(this.activeNegotiations.values())
            .filter(neg => neg.status === 'active');
    }

    // End negotiation
    endNegotiation(negotiationId, outcome, finalTerms = null) {
        const negotiation = this.activeNegotiations.get(negotiationId);
        if (negotiation) {
            negotiation.status = 'completed';
            negotiation.outcome = outcome;
            negotiation.finalTerms = finalTerms;
            negotiation.completedAt = new Date().toISOString();
            
            // Move to history
            this.negotiationHistory.push(negotiation);
            this.activeNegotiations.delete(negotiationId);
            
            console.log(`🏁 Negotiation ${negotiationId} completed with outcome: ${outcome}`);
        }
    }
}

// Make the class globally available
window.AINegotiationEngine = AINegotiationEngine;