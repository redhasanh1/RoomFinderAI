// AI Negotiation Engine
// Handles real-time negotiation with landlords using market data and OpenAI

const AILearningSystem = require('./ai-learning');

class AINegotiationEngine {
    constructor(supabase, config) {
        this.supabase = supabase;
        this.config = config;
        this.activeNegotiations = new Map(); // Track ongoing negotiations
        this.marketData = new Map(); // Cache market data
        this.aiUserInitialized = false;
        this.conversationalMemory = new Map(); // Track used responses per negotiation
        this.responseTemplates = this.initializeResponseTemplates();
        
        // Initialize AI Learning System (optional, may not be available in browser)
        try {
            if (typeof AILearningSystem !== 'undefined') {
                this.learningSystem = new AILearningSystem(this.supabase);
                this.learningEnabled = true;
                console.log('✅ AI Learning System initialized');
            } else {
                console.log('ℹ️ AI Learning System not available (browser mode)');
                this.learningSystem = null;
                this.learningEnabled = false;
            }
        } catch (error) {
            console.warn('⚠️ AI Learning System initialization failed:', error.message);
            this.learningSystem = null;
            this.learningEnabled = false;
        }
        
        // Conversation state management
        this.conversationStates = new Map(); // Track conversation phases
        this.stateTransitions = this.initializeStateTransitions();
        
        // Landlord personality detection and adaptation
        this.landlordPersonalities = new Map(); // Track detected personalities
        this.personalityAdaptations = this.initializePersonalityAdaptations();
        
        // Initialize channel reference for cleanup
        this.messageChannel = null;
        
        this.init();
        
        // Dashboard integration
        this.dashboardIntegration = this.initializeDashboardIntegration();
    }

    // Initialize response templates for variety
    initializeResponseTemplates() {
        return {
            counterOfferAcceptance: [
                "That works perfectly for me! $${price}/month sounds excellent. What are the next steps?",
                "I accept your offer of $${price}/month. Great doing business with you! When can we finalize everything?",
                "Perfect! $${price}/month is exactly what I was hoping for. I'm excited to move forward.",
                "Excellent! I'm very happy to agree to $${price}/month. Should we discuss the lease details?",
                "Wonderful! $${price}/month works great for me. I'm ready to proceed whenever you are.",
                "That's a deal! $${price}/month it is. Thank you for being so reasonable!",
                "I'm delighted to accept $${price}/month. This property is going to be perfect for me.",
                "Outstanding! $${price}/month is perfect. I really appreciate you working with me on this.",
                "Fantastic! $${price}/month works beautifully. I'm thrilled we could reach an agreement!",
                "Amazing! I'm so happy to agree to $${price}/month. This feels like the perfect fit.",
                "Yes! $${price}/month is exactly right. I can't wait to make this place my home.",
                "Brilliant! $${price}/month sounds fair to both of us. You've been wonderful to work with.",
                "Absolutely perfect! $${price}/month it is. I'm genuinely excited about this opportunity.",
                "That's exactly what I was hoping for! $${price}/month works great. Thank you so much!",
                "I love it! $${price}/month is a deal. You've made this process so smooth and easy."
            ],
            strategicCounterOffers: [
                "I appreciate your counter-offer! How about we meet somewhere in the middle at $${price}/month?",
                "That's getting closer! Would you consider $${price}/month? I think that could work for both of us.",
                "I understand your position completely. I can do $${price}/month, and I come with excellent references.",
                "Let's find some middle ground - how does $${price}/month sound? I'm really hoping we can make this work.",
                "I'm definitely flexible here - would $${price}/month work for you? I'm excited about this place!",
                "I can stretch to $${price}/month for the right place, and this feels perfect for me.",
                "How about $${price}/month with immediate move-in? I'm ready to go as soon as possible.",
                "I could do $${price}/month if we can finalize this quickly. I'd love to get this settled!",
                "What if we tried $${price}/month? I think that's fair for both of us and I'm genuinely interested.",
                "I'm really hoping we can work something out. Would $${price}/month be acceptable?",
                "Could we possibly do $${price}/month? I've been looking for a while and this place is exactly what I need.",
                "I'd be thrilled to pay $${price}/month for this property. It's exactly what I've been searching for!",
                "Would you be open to $${price}/month? I'm a reliable tenant and I promise to take great care of the place.",
                "I'm thinking $${price}/month might work for both of us. What do you think about that?",
                "How about we try $${price}/month? I'm really excited about this opportunity and want to make it work."
            ],
            marketBasedResponses: [
                "Based on comparable properties, $${price}/month reflects fair market value.",
                "Market data shows similar places at $${price}/month - would that work?",
                "Given the current market, I can offer $${price}/month.",
                "Research indicates $${price}/month is appropriate for this type of property.",
                "Considering market rates, $${price}/month seems reasonable.",
                "Market analysis supports $${price}/month for this location."
            ],
            valuePropositions: [
                "At $${price}/month, you get an excellent tenant with pristine references.",
                "For $${price}/month, I guarantee reliable rent and property care.",
                "I offer $${price}/month plus exceptional tenant qualities.",
                "$${price}/month with a long-term, responsible tenant like me is a great deal.",
                "At $${price}/month, you're getting reliability and peace of mind."
            ],
            meetingCoordination: [
                "Perfect! Tonight works excellently for me. What time should we meet? I'll bring all necessary documentation.",
                "Fantastic! I'm available after 6 PM tonight. Should we meet at the property? I have all my paperwork ready.",
                "Wonderful! Tonight is ideal. What time works best for you? I can bring references, ID, and first month's rent.",
                "Excellent! I'm free this evening. Would you prefer to meet at the property or another location?",
                "Great! Tonight sounds perfect. I'm available anytime after 5 PM. What would be most convenient for you?",
                "Outstanding! I can meet tonight. Should I bring the first month's rent and security deposit?",
                "Perfect timing! I'm ready to finalize everything tonight. What documents do you need me to bring?",
                "Excellent! Tonight works wonderfully. I have all required paperwork ready. What time shall we meet?"
            ],
            documentPreparation: [
                "I'll bring all necessary documents including references, employment verification, and ID.",
                "I have everything ready: references, proof of income, first month's rent, and security deposit.",
                "I can provide employment verification, previous landlord references, and credit information.",
                "I'll come prepared with ID, references, financial documentation, and payment.",
                "I have all required paperwork: rental application, references, and financial proof.",
                "I'll bring comprehensive documentation including background check and employment letter."
            ],
            securityDepositResponses: [
                "Absolutely! For a $${price}/month rental, I'm prepared to provide a security deposit. The standard amount is typically one month's rent ($${price}). I can transfer this immediately along with the first month's rent.",
                "Perfect! I'm ready to provide the security deposit right away. Is one month's rent ($${price}) the amount you require? I can handle the transfer today.",
                "Of course! I have the security deposit ready. Should we do one month's rent ($${price}) as is standard? I can send it via wire transfer or certified check immediately.",
                "Excellent! I'm prepared for the security deposit. Is $${price} (one month's rent) the correct amount? I can arrange payment today along with first month's rent.",
                "Absolutely! I have the security deposit funds ready. Is the standard one month ($${price}) what you need? I can process the payment immediately.",
                "Perfect! I'm ready with the security deposit. Should I prepare $${price} for the deposit? I can transfer both first month and security deposit today."
            ],
            moveInLogistics: [
                "Great! Tomorrow night works perfectly for me. What time should I arrive? I'll have all my documents and payments ready.",
                "Wonderful! I can move in tomorrow evening. What time works best for you? Should I bring anything specific?",
                "Perfect timing! Tomorrow night is ideal. What time should we coordinate for key exchange and final walkthrough?",
                "Excellent! I'm ready to move in tomorrow night. What time would be convenient for you? I'll bring all required documentation.",
                "Outstanding! Tomorrow evening works great. What time should I plan to arrive? I have everything prepared.",
                "Fantastic! Tomorrow night is perfect for move-in. What time should we meet? I'll bring all necessary paperwork and payments."
            ],
            
            // Post-agreement conversation phases
            dealConfirmation: [
                "Excellent! So we're agreed on $${price}/month for the ${propertyType}. To confirm our agreement: monthly rent $${price}, move-in date ${moveInDate}, and security deposit of $${deposit}. Should I prepare the first month's rent and security deposit?",
                "Perfect! I'm thrilled we reached an agreement on $${price}/month. Just to recap: $${price} monthly rent, ${moveInDate} move-in, $${deposit} security deposit. When would you like me to transfer the payments?",
                "Wonderful! We have a deal at $${price}/month. Let me confirm the details: Monthly rent $${price}, move-in ${moveInDate}, security deposit $${deposit}. I can process payments today - what's your preferred method?",
                "Outstanding! $${price}/month it is! Our agreement: $${price} rent, ${moveInDate} move-in date, $${deposit} security deposit. I'm ready to proceed with payments and paperwork immediately.",
                "Fantastic! We're set at $${price}/month. Final terms: $${price} monthly rent, move-in ${moveInDate}, $${deposit} security deposit. Should I arrange payment transfer and schedule our lease signing?"
            ],
            
            leaseTermsDiscussion: [
                "Regarding the lease terms, I'm looking for a ${leaseTerm} lease. Are you flexible on the lease duration? I'm also wondering about utilities - are any included in the rent?",
                "For the lease agreement, I'd prefer ${leaseTerm}. Could we discuss what's included? Utilities, parking, pet policy if applicable? I want to ensure we cover everything.",
                "About the lease terms - I'm thinking ${leaseTerm}. What utilities are included? Also, is there assigned parking? I'd like to understand the complete package.",
                "Let's discuss lease details: I'd like ${leaseTerm} if possible. What about utilities, internet, parking space? And what's your pet policy in case I get one later?",
                "For the lease, ${leaseTerm} works best for me. Could you clarify what's included in rent? Utilities, parking, any restrictions I should know about?"
            ],
            
            paymentArrangement: [
                "For payments, I can transfer the first month's rent ($${price}) and security deposit ($${deposit}) via wire transfer, certified check, or e-transfer. What works best for you? I can process it today.",
                "I'm ready to send $${totalAmount} total - $${price} first month + $${deposit} security deposit. Do you prefer wire transfer, certified check, or another method? I can arrange it immediately.",
                "Perfect! I'll arrange payment of $${totalAmount} ($${price} + $${deposit}). Wire transfer or certified check? I can process same-day to expedite our move-in timeline.",
                "Ready to transfer the full amount: $${price} first month's rent plus $${deposit} security deposit = $${totalAmount}. What's your preferred payment method? I can send today.",
                "I can send the $${totalAmount} total ($${price} rent + $${deposit} deposit) right away. Wire transfer, certified check, or e-transfer? Just provide the details and I'll process immediately."
            ],
            
            leaseSigningCoordination: [
                "When would be convenient to sign the lease agreement? I'm available evenings and weekends. Should we meet at the property or would you prefer another location?",
                "Perfect! When can we schedule lease signing? I'm flexible on timing and location. Would you prefer to meet at the property, your office, or somewhere else convenient?",
                "Great! Let's coordinate lease signing. I'm available most evenings and weekends. Should we do this at the property so I can do a final walkthrough too?",
                "Excellent! When works for lease signing? I can meet weekday evenings or anytime on weekends. Property location or would you prefer somewhere else?",
                "Wonderful! I'm ready to sign the lease. What's your availability? I'm flexible - evenings, weekends, whatever works. At the property or another location?"
            ],
            
            keyExchangeAndWalkthrough: [
                "For move-in day, should we schedule a property walkthrough and key exchange? I'd like to document the property condition and get oriented with utilities, appliances, etc.",
                "On move-in day, could we do a walkthrough together? I want to note any existing issues and understand how everything works - appliances, heating, parking, etc.",
                "Perfect! For key exchange, should we meet at the property? I'd appreciate a quick walkthrough to check everything's working and document the move-in condition.",
                "Great! When we meet for keys, could you show me around? I'd like to understand the utilities, appliances, parking situation, and note the property's condition.",
                "Excellent! At key exchange, would it be possible to do a brief walkthrough? I want to ensure everything's in order and understand how all the systems work."
            ],
            
            finalConfirmationAndNext: [
                "Perfect! So our timeline is: payment processing today, lease signing ${signingDate}, move-in ${moveInDate}. I'll have everything ready. Is there anything else we need to coordinate?",
                "Excellent! To summarize: I'll send $${totalAmount} today, we'll sign the lease ${signingDate}, and I move in ${moveInDate}. Do you need any additional documentation from me?",
                "Outstanding! Our plan: payment transfer today, lease signing ${signingDate}, property walkthrough and move-in ${moveInDate}. Anything else you need from me?",
                "Wonderful! Final checklist: payment today ($${totalAmount}), lease signing ${signingDate}, move-in ${moveInDate}. Should I bring anything specific beyond what we discussed?",
                "Fantastic! Everything's set: payments today, lease ${signingDate}, move-in ${moveInDate}. I'm excited about the property! Any last details to coordinate?"
            ],
            
            problemResolution: [
                "I understand there might be some complexity here. Could we work together to find a solution? I'm flexible and want to make this work for both of us.",
                "No problem - let's figure this out together. I'm committed to making this rental work. What would help resolve this concern?",
                "I appreciate you bringing this up. Let's find a solution that works for everyone. I'm open to reasonable adjustments to address your concerns.",
                "Thanks for the heads up. I'm sure we can work through this. What would be the best way to handle this situation from your perspective?",
                "I understand. Let's solve this together - I really want this property and I'm flexible on finding solutions. What are your thoughts on how to proceed?"
            ]
        };
    }

    // Initialize conversation state machine
    initializeStateTransitions() {
        return {
            // Conversation phases and their possible transitions
            phases: {
                'initial_contact': {
                    next: ['price_negotiation', 'information_gathering'],
                    templates: ['strategicCounterOffers', 'marketBasedResponses', 'valuePropositions']
                },
                'price_negotiation': {
                    next: ['deal_agreement', 'negotiation_stalemate', 'counter_negotiation'],
                    templates: ['strategicCounterOffers', 'marketBasedResponses', 'counterOfferAcceptance']
                },
                'deal_agreement': {
                    next: ['deal_confirmation', 'terms_discussion'],
                    templates: ['dealConfirmation', 'counterOfferAcceptance']
                },
                'deal_confirmation': {
                    next: ['lease_terms', 'payment_arrangement'],
                    templates: ['dealConfirmation', 'leaseTermsDiscussion']
                },
                'lease_terms': {
                    next: ['payment_arrangement', 'lease_signing'],
                    templates: ['leaseTermsDiscussion', 'problemResolution']
                },
                'payment_arrangement': {
                    next: ['lease_signing', 'security_deposit_discussion'],
                    templates: ['paymentArrangement', 'securityDepositResponses']
                },
                'security_deposit_discussion': {
                    next: ['lease_signing', 'payment_processing'],
                    templates: ['securityDepositResponses', 'paymentArrangement']
                },
                'lease_signing': {
                    next: ['move_in_coordination', 'document_preparation'],
                    templates: ['leaseSigningCoordination', 'documentPreparation']
                },
                'move_in_coordination': {
                    next: ['key_exchange', 'final_walkthrough'],
                    templates: ['moveInLogistics', 'keyExchangeAndWalkthrough']
                },
                'key_exchange': {
                    next: ['rental_complete', 'final_confirmation'],
                    templates: ['keyExchangeAndWalkthrough', 'finalConfirmationAndNext']
                },
                'final_confirmation': {
                    next: ['rental_complete'],
                    templates: ['finalConfirmationAndNext', 'meetingCoordination']
                },
                'rental_complete': {
                    next: [],
                    templates: ['finalConfirmationAndNext']
                },
                // Error states
                'negotiation_stalemate': {
                    next: ['price_negotiation', 'problem_resolution'],
                    templates: ['problemResolution', 'strategicCounterOffers']
                },
                'problem_resolution': {
                    next: ['price_negotiation', 'lease_terms', 'payment_arrangement'],
                    templates: ['problemResolution', 'strategicCounterOffers', 'valuePropositions']
                }
            },
            
            // Keywords that trigger state transitions
            transitionTriggers: {
                deal_agreement: ['agree', 'deal', 'accept', 'sounds good', 'perfect', 'yes that works', 'agreed'],
                deal_confirmation: ['confirm', 'correct', 'exactly', 'that\'s right', 'recap'],
                lease_terms: ['lease', 'terms', 'duration', 'utilities', 'parking', 'pets'],
                payment_arrangement: ['payment', 'transfer', 'deposit', 'wire', 'check', 'pay'],
                security_deposit_discussion: ['security deposit', 'deposit', 'security'],
                lease_signing: ['sign', 'lease signing', 'contract', 'agreement'],
                move_in_coordination: ['move in', 'move-in', 'moving', 'keys', 'when can i'],
                key_exchange: ['keys', 'key exchange', 'walkthrough', 'final walk'],
                problem_resolution: ['problem', 'issue', 'concern', 'not sure', 'but', 'however']
            }
        };
    }

    // Get current conversation state for a negotiation
    getConversationState(negotiationId) {
        return this.conversationStates.get(negotiationId) || {
            phase: 'initial_contact',
            context: {},
            messageCount: 0,
            lastUpdate: new Date()
        };
    }

    // Update conversation state
    updateConversationState(negotiationId, newPhase, context = {}) {
        const currentState = this.getConversationState(negotiationId);
        const updatedState = {
            ...currentState,
            phase: newPhase,
            context: { ...currentState.context, ...context },
            messageCount: currentState.messageCount + 1,
            lastUpdate: new Date()
        };
        
        this.conversationStates.set(negotiationId, updatedState);
        console.log(`🔄 Conversation ${negotiationId} transitioned to: ${newPhase}`);
        return updatedState;
    }

    // Determine next conversation phase based on landlord response
    determineNextPhase(currentPhase, landlordMessage) {
        const message = landlordMessage.toLowerCase();
        const transitions = this.stateTransitions.transitionTriggers;
        
        // Check for specific triggers
        for (const [targetPhase, triggers] of Object.entries(transitions)) {
            if (triggers.some(trigger => message.includes(trigger))) {
                // Validate transition is allowed from current phase
                const allowedTransitions = this.stateTransitions.phases[currentPhase]?.next || [];
                if (allowedTransitions.includes(targetPhase)) {
                    return targetPhase;
                }
            }
        }
        
        // Default progression logic
        const phaseProgression = {
            'initial_contact': 'price_negotiation',
            'price_negotiation': message.includes('agree') || message.includes('deal') ? 'deal_agreement' : 'price_negotiation',
            'deal_agreement': 'deal_confirmation',
            'deal_confirmation': 'lease_terms',
            'lease_terms': 'payment_arrangement',
            'payment_arrangement': 'lease_signing',
            'lease_signing': 'move_in_coordination',
            'move_in_coordination': 'key_exchange',
            'key_exchange': 'final_confirmation',
            'final_confirmation': 'rental_complete'
        };
        
        return phaseProgression[currentPhase] || currentPhase;
    }

    // Get appropriate templates for current conversation phase
    getPhaseTemplates(phase) {
        return this.stateTransitions.phases[phase]?.templates || ['strategicCounterOffers'];
    }

    // Initialize landlord personality adaptations
    initializePersonalityAdaptations() {
        return {
            personalities: {
                'professional': {
                    traits: ['business-like', 'formal', 'data-driven', 'efficient'],
                    keywords: ['terms', 'contract', 'references', 'application', 'documentation'],
                    responseStyle: 'formal_businesslike',
                    negotiationApproach: 'data_driven',
                    preferredTemplates: ['marketBasedResponses', 'valuePropositions', 'documentPreparation'],
                    communicationTone: 'professional',
                    timePreference: 'business_hours'
                },
                'friendly': {
                    traits: ['casual', 'personal', 'accommodating', 'conversational'],
                    keywords: ['great', 'wonderful', 'love', 'happy', 'excited', 'nice'],
                    responseStyle: 'warm_personal',
                    negotiationApproach: 'relationship_building',
                    preferredTemplates: ['strategicCounterOffers', 'meetingCoordination', 'moveInLogistics'],
                    communicationTone: 'friendly',
                    timePreference: 'flexible'
                },
                'price_focused': {
                    traits: ['cost-conscious', 'value-oriented', 'negotiation-ready'],
                    keywords: ['price', 'rent', 'cost', 'budget', 'affordable', 'deal'],
                    responseStyle: 'value_oriented',
                    negotiationApproach: 'price_focused',
                    preferredTemplates: ['marketBasedResponses', 'strategicCounterOffers', 'paymentArrangement'],
                    communicationTone: 'direct',
                    timePreference: 'quick_decision'
                },
                'cautious': {
                    traits: ['careful', 'thorough', 'risk-averse', 'detailed'],
                    keywords: ['careful', 'sure', 'think', 'consider', 'check', 'verify'],
                    responseStyle: 'detailed_reassuring',
                    negotiationApproach: 'trust_building',
                    preferredTemplates: ['valuePropositions', 'documentPreparation', 'problemResolution'],
                    communicationTone: 'reassuring',
                    timePreference: 'thoughtful_process'
                },
                'quick_decision': {
                    traits: ['decisive', 'fast-paced', 'time-conscious', 'efficient'],
                    keywords: ['quickly', 'asap', 'today', 'immediately', 'fast', 'urgent'],
                    responseStyle: 'efficient_decisive',
                    negotiationApproach: 'speed_focused',
                    preferredTemplates: ['counterOfferAcceptance', 'paymentArrangement', 'moveInLogistics'],
                    communicationTone: 'efficient',
                    timePreference: 'immediate'
                },
                'experienced': {
                    traits: ['knowledgeable', 'market-aware', 'established'],
                    keywords: ['market', 'experience', 'properties', 'tenants', 'years'],
                    responseStyle: 'knowledgeable_peer',
                    negotiationApproach: 'expertise_based',
                    preferredTemplates: ['marketBasedResponses', 'valuePropositions', 'leaseTermsDiscussion'],
                    communicationTone: 'respectful',
                    timePreference: 'standard_process'
                }
            },
            
            adaptationStrategies: {
                'professional': {
                    emphasize: ['credentials', 'references', 'documentation', 'formal_process'],
                    avoid: ['casual_language', 'personal_stories', 'pressure_tactics'],
                    tone_adjustments: 'formal_respectful'
                },
                'friendly': {
                    emphasize: ['personal_connection', 'enthusiasm', 'flexibility', 'mutual_benefit'],
                    avoid: ['overly_formal', 'aggressive_negotiation', 'impersonal_language'],
                    tone_adjustments: 'warm_personable'
                },
                'price_focused': {
                    emphasize: ['market_data', 'value_proposition', 'cost_benefits', 'savings'],
                    avoid: ['ignoring_budget', 'luxury_features', 'emotional_appeals'],
                    tone_adjustments: 'direct_value_focused'
                },
                'cautious': {
                    emphasize: ['reliability', 'security', 'guarantees', 'detailed_explanations'],
                    avoid: ['rushed_decisions', 'vague_terms', 'pressure'],
                    tone_adjustments: 'patient_thorough'
                },
                'quick_decision': {
                    emphasize: ['efficiency', 'immediate_availability', 'quick_response', 'decisiveness'],
                    avoid: ['lengthy_discussions', 'delays', 'over_analysis'],
                    tone_adjustments: 'concise_action_oriented'
                },
                'experienced': {
                    emphasize: ['market_knowledge', 'professional_respect', 'industry_understanding'],
                    avoid: ['explaining_basics', 'condescension', 'amateur_approach'],
                    tone_adjustments: 'peer_to_peer_professional'
                }
            }
        };
    }

    // Detect landlord personality from messages
    detectLandlordPersonality(messages, landlordId = null) {
        if (!messages || messages.length === 0) return 'professional'; // Default
        
        // Check if we already have a detected personality for this landlord
        if (landlordId && this.landlordPersonalities.has(landlordId)) {
            return this.landlordPersonalities.get(landlordId);
        }
        
        const allMessages = Array.isArray(messages) ? messages.join(' ') : messages;
        const messageText = allMessages.toLowerCase();
        
        const personalityScores = {};
        const personalities = this.personalityAdaptations.personalities;
        
        // Score each personality based on keyword matches
        for (const [personality, traits] of Object.entries(personalities)) {
            let score = 0;
            
            // Check keyword matches
            traits.keywords.forEach(keyword => {
                const regex = new RegExp(`\\b${keyword}\\b`, 'gi');
                const matches = messageText.match(regex) || [];
                score += matches.length * 2; // Keywords worth 2 points each
            });
            
            // Check trait indicators
            traits.traits.forEach(trait => {
                if (this.checkTraitIndicators(messageText, trait)) {
                    score += 1;
                }
            });
            
            personalityScores[personality] = score;
        }
        
        // Additional heuristics
        personalityScores.professional += this.countPatterns(messageText, [
            'application', 'documentation', 'references', 'lease', 'terms'
        ]);
        
        personalityScores.friendly += this.countPatterns(messageText, [
            'great!', 'wonderful!', 'love', 'excited', 'happy to'
        ]);
        
        personalityScores.price_focused += this.countPatterns(messageText, [
            '$', 'price', 'rent', 'cost', 'budget', 'afford'
        ]);
        
        personalityScores.cautious += this.countPatterns(messageText, [
            'need to check', 'let me think', 'want to make sure', 'careful'
        ]);
        
        personalityScores.quick_decision += this.countPatterns(messageText, [
            'today', 'asap', 'right away', 'immediately', 'quickly'
        ]);
        
        // Find highest scoring personality
        const detectedPersonality = Object.keys(personalityScores).reduce((a, b) => 
            personalityScores[a] > personalityScores[b] ? a : b
        );
        
        // Cache the result if we have a landlord ID
        if (landlordId) {
            this.landlordPersonalities.set(landlordId, detectedPersonality);
        }
        
        console.log(`🎭 Detected landlord personality: ${detectedPersonality} (scores:`, personalityScores, ')');
        return detectedPersonality;
    }

    // Check for trait indicators in text
    checkTraitIndicators(text, trait) {
        const traitPatterns = {
            'business-like': ['business', 'professional', 'formal', 'standard'],
            'formal': ['please', 'thank you', 'sir', 'madam', 'regards'],
            'data-driven': ['market', 'data', 'analysis', 'comparison', 'statistics'],
            'casual': ['hey', 'yeah', 'sure', 'sounds good', 'no problem'],
            'personal': ['i love', 'i think', 'my experience', 'personally'],
            'accommodating': ['flexible', 'work with you', 'accommodate', 'adjust'],
            'cost-conscious': ['budget', 'affordable', 'reasonable', 'cost-effective'],
            'careful': ['want to make sure', 'need to verify', 'double check'],
            'decisive': ['let\'s do it', 'sounds good', 'i\'ll take it', 'decided'],
            'knowledgeable': ['in my experience', 'market shows', 'typically', 'usually']
        };
        
        const patterns = traitPatterns[trait] || [];
        return patterns.some(pattern => text.includes(pattern));
    }

    // Count pattern matches in text
    countPatterns(text, patterns) {
        return patterns.reduce((count, pattern) => {
            const matches = text.match(new RegExp(pattern, 'gi')) || [];
            return count + matches.length;
        }, 0);
    }

    // Get personality-adapted response strategies
    getPersonalityAdaptation(personality) {
        return this.personalityAdaptations.adaptationStrategies[personality] || 
               this.personalityAdaptations.adaptationStrategies['professional'];
    }

    // Get personality-specific templates
    getPersonalityTemplates(personality, phase) {
        const personalityTraits = this.personalityAdaptations.personalities[personality];
        const phaseTemplates = this.getPhaseTemplates(phase);
        
        if (personalityTraits) {
            // Prioritize templates that match personality preferences
            const preferredTemplates = personalityTraits.preferredTemplates.filter(template => 
                phaseTemplates.includes(template)
            );
            
            return preferredTemplates.length > 0 ? preferredTemplates : phaseTemplates;
        }
        
        return phaseTemplates;
    }

    // Adapt message tone based on personality
    adaptMessageTone(message, personality) {
        const adaptation = this.getPersonalityAdaptation(personality);
        
        // Apply tone adjustments based on personality
        switch (adaptation.tone_adjustments) {
            case 'formal_respectful':
                return this.makeFormalTone(message);
            case 'warm_personable':
                return this.makeWarmTone(message);
            case 'direct_value_focused':
                return this.makeDirectTone(message);
            case 'patient_thorough':
                return this.makePatientTone(message);
            case 'concise_action_oriented':
                return this.makeConciseTone(message);
            case 'peer_to_peer_professional':
                return this.makePeerTone(message);
            default:
                return message;
        }
    }

    // Tone adaptation helper methods
    makeFormalTone(message) {
        return message
            .replace(/hey/gi, 'Hello')
            .replace(/yeah/gi, 'Yes')
            .replace(/sure thing/gi, 'Certainly')
            .replace(/!/g, '.');
    }

    makeWarmTone(message) {
        if (!message.includes('!') && Math.random() > 0.5) {
            message = message.replace(/\.$/, '!');
        }
        return message;
    }

    makeDirectTone(message) {
        // Keep message concise and value-focused
        return message;
    }

    makePatientTone(message) {
        // Add reassuring language
        if (Math.random() > 0.7) {
            message = 'I completely understand. ' + message;
        }
        return message;
    }

    makeConciseTone(message) {
        // Remove unnecessary words, keep action-oriented
        return message
            .replace(/I think that/gi, '')
            .replace(/perhaps/gi, '')
            .replace(/maybe/gi, '');
    }

    makePeerTone(message) {
        // Professional but not condescending
        return message;
    }

    // Get AI learning insights for personalized negotiation
    async getLearningInsights(listing, userBudget) {
        try {
            // Query successful negotiations from database
            const { data: successfulNegotiations, error } = await this.supabase
                .from('ai_chats')
                .select('*')
                .eq('metadata->success', true)
                .ilike('listing_type', `%${listing.house_type}%`)
                .limit(20);

            if (error) {
                console.log('Learning insights query failed, using defaults');
                return this.getDefaultLearningInsights();
            }

            // Analyze successful patterns
            const insights = {
                successfulStrategies: this.analyzeSuccessfulStrategies(successfulNegotiations),
                optimalTiming: this.analyzeOptimalTiming(successfulNegotiations),
                valueProps: this.analyzeValuePropositions(successfulNegotiations),
                landlordBehavior: this.analyzeLandlordBehavior(successfulNegotiations)
            };

            return insights;
        } catch (error) {
            console.error('Error getting learning insights:', error);
            return this.getDefaultLearningInsights();
        }
    }

    // Get contextual learning from similar properties
    async getContextualLearning(propertyType, city) {
        try {
            const { data: contextData, error } = await this.supabase
                .from('ai_chats')
                .select('conversation_data, metadata')
                .eq('metadata->dealClosed', true)
                .ilike('listing_type', `%${propertyType}%`)
                .ilike('listing_location', `%${city}%`)
                .limit(15);

            if (error) {
                return this.getDefaultContextualLearning();
            }

            return {
                similarNegotiations: `${contextData?.length || 0} successful deals in similar properties`,
                locationStrategies: this.extractLocationStrategies(contextData),
                propertyTypeStrategies: this.extractPropertyTypeStrategies(contextData)
            };
        } catch (error) {
            console.error('Error getting contextual learning:', error);
            return this.getDefaultContextualLearning();
        }
    }

    // Analyze successful negotiation strategies
    analyzeSuccessfulStrategies(negotiations) {
        if (!negotiations || negotiations.length === 0) {
            return 'Market-based pricing with value emphasis';
        }

        const strategies = negotiations.map(n => n.metadata?.strategy || 'market_based');
        const mostSuccessful = this.getMostCommon(strategies);
        
        return `${mostSuccessful} approach with ${Math.round((strategies.filter(s => s === mostSuccessful).length / strategies.length) * 100)}% success rate`;
    }

    // Analyze optimal timing patterns
    analyzeOptimalTiming(negotiations) {
        if (!negotiations || negotiations.length === 0) {
            return 'Quick response within 2-4 hours';
        }

        // Analyze response times from successful negotiations
        const avgResponseTime = negotiations.reduce((sum, n) => {
            const responseTime = n.metadata?.avgResponseTime || 180; // minutes
            return sum + responseTime;
        }, 0) / negotiations.length;

        if (avgResponseTime < 60) return 'Immediate response within 1 hour';
        if (avgResponseTime < 240) return 'Quick response within 2-4 hours';
        return 'Same-day response preferred';
    }

    // Analyze effective value propositions
    analyzeValuePropositions(negotiations) {
        if (!negotiations || negotiations.length === 0) {
            return 'Reliable tenant with references';
        }

        const valueProps = negotiations.map(n => n.metadata?.valueProposition || 'reliability');
        const topValue = this.getMostCommon(valueProps);
        
        return `${topValue} emphasis with quick decision capability`;
    }

    // Analyze landlord behavior patterns
    analyzeLandlordBehavior(negotiations) {
        if (!negotiations || negotiations.length === 0) {
            return 'Professional, price-conscious, values reliability';
        }

        const behaviors = negotiations.map(n => n.metadata?.landlordStyle || 'professional');
        const commonBehavior = this.getMostCommon(behaviors);
        
        return `Typically ${commonBehavior}, responds well to ${commonBehavior === 'professional' ? 'data-driven' : 'personal'} approaches`;
    }

    // Extract location-specific strategies
    extractLocationStrategies(contextData) {
        if (!contextData || contextData.length === 0) {
            return 'Standard market approach';
        }

        const strategies = contextData.map(d => d.metadata?.locationStrategy || 'market_comparison');
        const topStrategy = this.getMostCommon(strategies);
        
        return `${topStrategy} works best in this area`;
    }

    // Extract property type strategies
    extractPropertyTypeStrategies(contextData) {
        if (!contextData || contextData.length === 0) {
            return 'Value-based negotiation';
        }

        const strategies = contextData.map(d => d.metadata?.propertyStrategy || 'value_focus');
        const topStrategy = this.getMostCommon(strategies);
        
        return `${topStrategy} approach for this property type`;
    }

    // Get most common element in array
    getMostCommon(arr) {
        if (!arr || arr.length === 0) return 'standard';
        
        const counts = {};
        arr.forEach(item => counts[item] = (counts[item] || 0) + 1);
        
        return Object.keys(counts).reduce((a, b) => counts[a] > counts[b] ? a : b);
    }

    // Default learning insights fallback
    getDefaultLearningInsights() {
        return {
            successfulStrategies: 'Market-based pricing with value emphasis',
            optimalTiming: 'Quick response within 2-4 hours',
            valueProps: 'Reliable tenant with excellent references',
            landlordBehavior: 'Professional, responds to data-driven approaches'
        };
    }

    // Default contextual learning fallback
    getDefaultContextualLearning() {
        return {
            similarNegotiations: 'Standard market analysis',
            locationStrategies: 'Market comparison approach',
            propertyTypeStrategies: 'Value-focused negotiation'
        };
    }

    // Initialize the negotiation engine
    async init() {
        try {
            // Validate environment variables first
            const envCheck = this.validateEnvironmentVariables();
            if (!envCheck.valid) {
                console.error('❌ Environment validation failed - AI negotiation engine cannot start');
                return;
            }
            
            await this.ensureAIUserExists();
            this.setupMessageListener();
        } catch (error) {
            console.error('Error initializing AI negotiation engine:', error);
        }
    }

    // Ensure AI user exists in database
    async ensureAIUserExists() {
        if (this.aiUserInitialized) {
            console.log('✅ AI user already initialized, skipping check');
            return true;
        }
        
        try {
            const aiEmail = 'ai-negotiator@roomfinder.com';
            
            console.log('🔍 Checking if AI user exists...');
            
            // Check if AI user exists - use maybeSingle to avoid 406 errors
            const { data: existingUser, error: checkError } = await this.supabase
                .from('users')
                .select('id, email, first_name, last_name')
                .eq('email', aiEmail)
                .maybeSingle();

            if (checkError && !checkError.message.includes('No rows')) {
                console.log('⚠️ Error checking for existing AI user:', checkError.message);
                // Mark as initialized to avoid infinite retry
                this.aiUserInitialized = true;
                return true;
            }

            if (existingUser) {
                console.log('✅ AI user already exists:', existingUser.first_name, existingUser.last_name);
                this.aiUserInitialized = true;
                return true;
            }
            
            console.log('❌ AI user not found, but skipping creation to avoid errors');
            console.log('⚠️ Please manually create AI user with email:', aiEmail);
            this.aiUserInitialized = true;
            return true;

        } catch (error) {
            console.error('Error ensuring AI user exists:', error);
            // Don't fail completely - continue with existing functionality
            this.aiUserInitialized = true;
            return true;
        }
    }

    // Enhanced market data analysis with external intelligence
    async getMarketData(location, houseType, bedrooms) {
        const cacheKey = `${location}-${houseType}-${bedrooms}`;
        
        // Check cache first
        if (this.marketData.has(cacheKey)) {
            console.log('📊 Using cached market data for:', cacheKey);
            return this.marketData.get(cacheKey);
        }

        try {
            console.log('🔍 Gathering enhanced market data for:', { location, houseType, bedrooms });

            // Get internal database data
            const internalData = await this.getInternalMarketData(location, houseType, bedrooms);
            
            // Get AI-powered market analysis
            const aiData = await this.getAIMarketData(location, houseType, bedrooms);
            
            // Combine data sources for comprehensive analysis
            const enhancedStats = this.combineMarketSources(internalData, aiData, location);
            
            // Cache the result
            this.marketData.set(cacheKey, enhancedStats);
            console.log('📊 Enhanced market data calculated:', enhancedStats);
            
            return enhancedStats;

        } catch (error) {
            console.error('Error getting enhanced market data:', error);
            return this.getAIMarketData(location, houseType, bedrooms);
        }
    }

    // Get internal database market data
    async getInternalMarketData(location, houseType, bedrooms) {
        try {
            // Query database for similar properties
            let query = this.supabase.from('listings').select('price, title, city, bedrooms, house_type, created_at');
            
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
                console.log('⚠️ No internal market data found');
                return null;
            }

            // Calculate market statistics
            const prices = listings.map(l => l.price).filter(p => p > 0 && p < 15000);
            
            if (prices.length === 0) return null;
            
            return {
                average: Math.round(prices.reduce((a, b) => a + b, 0) / prices.length),
                median: this.calculateMedian(prices),
                min: Math.min(...prices),
                max: Math.max(...prices),
                count: prices.length,
                listings: listings.slice(0, 5), // Sample listings
                source: 'internal_database',
                freshness: this.calculateDataFreshness(listings),
                prices: prices
            };

        } catch (error) {
            console.error('Error getting internal market data:', error);
            return null;
        }
    }

    // Combine multiple market data sources
    combineMarketSources(internalData, aiData, location) {
        console.log('🔄 Combining market data sources for comprehensive analysis...');
        
        if (internalData && aiData) {
            // Both sources available - create enhanced analysis
            const combinedAverage = Math.round((internalData.average + aiData.average) / 2);
            const variance = Math.abs(internalData.average - aiData.average);
            const confidenceScore = variance < (internalData.average * 0.1) ? 'high' : 'medium';
            
            return {
                average: combinedAverage,
                median: internalData.median,
                min: Math.min(internalData.min, aiData.min || internalData.min),
                max: Math.max(internalData.max, aiData.max || internalData.max),
                count: internalData.count,
                listings: internalData.listings,
                source: 'combined_analysis',
                analysis: this.generateCombinedMarketAnalysis(internalData, aiData, variance),
                negotiationTips: this.generateEnhancedNegotiationTips(internalData, aiData),
                confidence: confidenceScore,
                dataFreshness: internalData.freshness,
                aiInsights: aiData.insights,
                marketTrend: aiData.trend || 'stable',
                competitiveness: aiData.competitiveness || 'medium'
            };
        }
        
        if (internalData) {
            // Only internal data - enhance with basic analysis
            return {
                ...internalData,
                analysis: this.generateMarketAnalysis(internalData.prices),
                negotiationTips: this.generateNegotiationTips(internalData.prices),
                confidence: 'medium'
            };
        }
        
        if (aiData) {
            // Only AI data - return with appropriate confidence
            return {
                ...aiData,
                confidence: 'ai_estimated'
            };
        }
        
        // Fallback if no data available
        return this.getFallbackMarketData();
    }

    // Generate combined market analysis
    generateCombinedMarketAnalysis(internalData, aiData, variance) {
        const variancePercent = Math.round((variance / internalData.average) * 100);
        
        let analysis = `Market analysis based on ${internalData.count} database listings and AI market intelligence. `;
        
        if (variancePercent < 5) {
            analysis += `Data sources are highly consistent (${variancePercent}% variance), indicating stable market conditions.`;
        } else if (variancePercent < 15) {
            analysis += `Sources show moderate variance (${variancePercent}%), typical for dynamic markets.`;
        } else {
            analysis += `Significant variance detected (${variancePercent}%), suggesting market volatility or limited data.`;
        }
        
        if (aiData.trend) {
            analysis += ` Market trend: ${aiData.trend}.`;
        }
        
        if (aiData.competitiveness) {
            analysis += ` Competition level: ${aiData.competitiveness}.`;
        }
        
        return analysis;
    }

    // Generate enhanced negotiation tips
    generateEnhancedNegotiationTips(internalData, aiData) {
        const tips = [];
        
        // Data-driven tips
        if (internalData.count >= 10) {
            tips.push(`Strong data confidence with ${internalData.count} comparable properties`);
        } else {
            tips.push(`Limited local data (${internalData.count} properties) - emphasize unique value`);
        }
        
        // Freshness-based tips
        if (internalData.freshness === 'fresh') {
            tips.push('Recent market data supports current pricing');
        } else if (internalData.freshness === 'stale') {
            tips.push('Market data is older - current conditions may differ');
        }
        
        // AI insights
        if (aiData.trend === 'rising') {
            tips.push('Market trending upward - negotiate quickly');
        } else if (aiData.trend === 'declining') {
            tips.push('Market cooling - good opportunity for price reduction');
        }
        
        if (aiData.competitiveness === 'high') {
            tips.push('Competitive market - highlight tenant reliability and quick decision');
        } else if (aiData.competitiveness === 'low') {
            tips.push('Less competitive market - more room for price negotiation');
        }
        
        // Price positioning tips
        const spread = internalData.max - internalData.min;
        if (spread > internalData.average * 0.3) {
            tips.push('Wide price range indicates negotiation flexibility');
        }
        
        return tips.join('. ') + '.';
    }

    // Calculate data freshness
    calculateDataFreshness(listings) {
        if (!listings || listings.length === 0) return 'unknown';
        
        const now = new Date();
        const dates = listings
            .map(l => new Date(l.created_at))
            .filter(d => !isNaN(d));
        
        if (dates.length === 0) return 'unknown';
        
        const avgAge = dates.reduce((sum, date) => sum + (now - date), 0) / dates.length;
        const daysOld = Math.round(avgAge / (1000 * 60 * 60 * 24));
        
        if (daysOld < 7) return 'fresh';
        if (daysOld < 30) return 'recent';
        if (daysOld < 90) return 'aging';
        return 'stale';
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

    // Enhanced negotiation message generation with conversation state awareness and personality adaptation
    async generateContextualNegotiationMessage(listing, userBudget, marketData, conversationHistory = [], negotiationId = null, landlordMessage = '', landlordId = null) {
        try {
            console.log('🤖 Generating state-aware negotiation message for:', listing.title);
            
            // Get or initialize conversation state
            let conversationState = negotiationId ? this.getConversationState(negotiationId) : {
                phase: 'initial_contact',
                context: {},
                messageCount: 0
            };
            
            // Detect landlord personality if we have messages
            let landlordPersonality = 'professional'; // Default
            if (landlordMessage || conversationHistory.length > 0) {
                const allLandlordMessages = [landlordMessage, ...conversationHistory.filter(msg => msg.role === 'landlord').map(msg => msg.content)].filter(Boolean);
                landlordPersonality = this.detectLandlordPersonality(allLandlordMessages, landlordId);
            }
            
            console.log(`🎭 Adapting to ${landlordPersonality} landlord personality`);
            
            // Determine next phase if landlord responded
            if (landlordMessage && negotiationId) {
                const nextPhase = this.determineNextPhase(conversationState.phase, landlordMessage);
                conversationState = this.updateConversationState(negotiationId, nextPhase, {
                    landlordMessage: landlordMessage,
                    agreedPrice: this.extractPriceFromMessage(landlordMessage) || conversationState.context.agreedPrice,
                    landlordPersonality: landlordPersonality
                });
            }
            
            console.log(`🎯 Conversation phase: ${conversationState.phase}`);
            
            // Get personality-adapted templates
            const personalityTemplates = this.getPersonalityTemplates(landlordPersonality, conversationState.phase);
            const phaseTemplates = this.getPhaseTemplates(conversationState.phase);
            
            // Enhanced context based on conversation phase
            const phaseContext = this.getPhaseContext(conversationState.phase, listing, userBudget, conversationState.context);
            
            // Get personality adaptation strategies
            const personalityAdaptation = this.getPersonalityAdaptation(landlordPersonality);
            
            // Get AI learning insights
            const learningInsights = await this.getLearningInsights(listing, userBudget);
            const contextualLearning = await this.getContextualLearning(listing.house_type, listing.city);

            const enhancedPrompt = `
            You are an advanced AI negotiation expert with conversation state awareness and personality adaptation. Generate a message appropriate for the current negotiation phase and landlord personality:

            CONVERSATION CONTEXT:
            - Current Phase: ${conversationState.phase}
            - Message Count: ${conversationState.messageCount}
            - Available Templates: ${phaseTemplates.join(', ')}
            ${landlordMessage ? `- Landlord's Last Message: "${landlordMessage}"` : ''}
            
            LANDLORD PERSONALITY ADAPTATION:
            - Detected Personality: ${landlordPersonality}
            - Preferred Templates: ${personalityTemplates.join(', ')}
            - Communication Style: ${personalityAdaptation.tone_adjustments}
            - Emphasize: ${personalityAdaptation.emphasize.join(', ')}
            - Avoid: ${personalityAdaptation.avoid.join(', ')}
            
            PHASE-SPECIFIC CONTEXT:
            ${phaseContext}

            LISTING DETAILS:
            - Title: ${listing.title}
            - Current Price: $${listing.price}/month
            - Type: ${listing.house_type}
            - Bedrooms: ${listing.bedrooms}
            - Location: ${listing.city || 'Not specified'}
            - Utilities: ${listing.utilities}

            USER PREFERENCES:
            - Budget: $${userBudget}
            - Looking for: ${listing.house_type}
            - Negotiation History: ${conversationHistory.length} previous conversations

            MARKET INTELLIGENCE:
            - Average market price: $${marketData.average}
            - Market range: $${marketData.min} - $${marketData.max}
            - Market analysis: ${marketData.analysis || 'Standard market conditions'}

            AI LEARNING INSIGHTS:
            - Successful strategies: ${learningInsights.successfulStrategies}
            - Optimal timing: ${learningInsights.optimalTiming}
            - Value propositions: ${learningInsights.valueProps}
            - Landlord behavior: ${learningInsights.landlordBehavior}

            CONVERSATION MEMORY:
            ${conversationHistory.length > 0 ? `Previous context: ${conversationHistory.slice(-3).map(msg => `${msg.role}: ${msg.content}`).join(' | ')}` : 'Initial contact'}

            Generate a message that:
            1. Is appropriate for the ${conversationState.phase} phase
            2. Adapts to the ${landlordPersonality} personality (${personalityAdaptation.tone_adjustments} tone)
            3. Uses templates from: ${personalityTemplates.join(', ')}
            4. Emphasizes: ${personalityAdaptation.emphasize.join(', ')}
            5. Avoids: ${personalityAdaptation.avoid.join(', ')}
            6. Responds appropriately to the landlord's message if provided
            7. Moves the conversation toward rental completion
            8. Maintains the appropriate tone for this landlord personality

            Message (be specific and actionable):
            `;

            let response = await this.callOpenAI(enhancedPrompt, {
                max_tokens: 200,
                temperature: 0.7,
                top_p: 0.9
            });

            // Apply personality-specific tone adaptation
            response = this.adaptMessageTone(response, landlordPersonality);

            // Log the generated message with state context
            if (negotiationId) {
                await this.logStateAwareConversation(negotiationId, conversationState, response, {
                    landlordPersonality: landlordPersonality,
                    personalityAdaptation: personalityAdaptation
                });
            }

            console.log(`✅ Generated ${landlordPersonality}-adapted message for ${conversationState.phase} phase`);
            return response;
        } catch (error) {
            console.error('Error generating state-aware message:', error);
            // Fallback to original method
            return await this.generateNegotiationMessage(listing, userBudget, marketData, conversationHistory);
        }
    }

    // Get context information based on conversation phase
    getPhaseContext(phase, listing, userBudget, conversationContext) {
        const agreedPrice = conversationContext.agreedPrice || userBudget;
        const deposit = Math.round(agreedPrice); // Standard: one month rent
        const totalAmount = agreedPrice + deposit;
        const moveInDate = this.getPreferredMoveInDate();
        const signingDate = this.getPreferredSigningDate();
        
        const contexts = {
            'initial_contact': `
                - Goal: Express interest and begin price negotiation
                - Strategy: Show enthusiasm while establishing budget expectations
                - Key elements: Introduce yourself as qualified tenant, express interest`,
            
            'price_negotiation': `
                - Goal: Negotiate favorable rental price
                - Current offer consideration: Around $${userBudget}
                - Market positioning: Use $${listing.price} vs market average $${userBudget}
                - Strategy: Data-driven negotiation with value emphasis`,
            
            'deal_agreement': `
                - Goal: Confirm price agreement and transition to terms
                - Agreed price: $${agreedPrice}/month
                - Next steps: Confirm terms and move to logistics`,
            
            'deal_confirmation': `
                - Agreed price: $${agreedPrice}/month
                - Security deposit: $${deposit}
                - Move-in date: ${moveInDate}
                - Goal: Confirm all terms and transition to formal arrangements`,
            
            'lease_terms': `
                - Monthly rent: $${agreedPrice}
                - Goal: Discuss lease duration, utilities, parking, pets
                - Focus: Clarify what's included and any restrictions`,
            
            'payment_arrangement': `
                - First month rent: $${agreedPrice}
                - Security deposit: $${deposit}
                - Total required: $${totalAmount}
                - Goal: Arrange payment method and timing`,
            
            'security_deposit_discussion': `
                - Security deposit amount: $${deposit}
                - Standard: One month's rent
                - Goal: Confirm amount and payment method`,
            
            'lease_signing': `
                - Goal: Schedule lease signing appointment
                - Preferred date: ${signingDate}
                - Location preference: At property or landlord's office`,
            
            'move_in_coordination': `
                - Move-in date: ${moveInDate}
                - Goal: Coordinate logistics and walkthrough
                - Requirements: Key exchange, final inspection`,
            
            'key_exchange': `
                - Goal: Schedule key exchange and property walkthrough
                - Documents needed: ID, signed lease, payment confirmations`,
            
            'final_confirmation': `
                - Goal: Confirm all arrangements and finalize rental
                - Timeline summary: Payment → Lease signing → Move-in`,
            
            'rental_complete': `
                - Goal: Express satisfaction and maintain positive relationship
                - Status: All arrangements completed successfully`
        };
        
        return contexts[phase] || contexts['initial_contact'];
    }

    // Utility methods for phase context
    getPreferredMoveInDate() {
        const date = new Date();
        date.setDate(date.getDate() + 7); // One week from now
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    getPreferredSigningDate() {
        const date = new Date();
        date.setDate(date.getDate() + 3); // Three days from now
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    // Extract price from message text
    extractPriceFromMessage(message) {
        if (!message) return null;
        
        // Look for various price formats
        const pricePatterns = [
            /\$(\d+,?\d*)/g,  // $1500 or $1,500
            /(\d+,?\d*)\s*dollars?/gi,  // 1500 dollars
            /(\d+,?\d*)\s*per month/gi,  // 1500 per month
            /rent.*?(\d+,?\d*)/gi  // rent of 1500
        ];
        
        for (const pattern of pricePatterns) {
            const matches = message.match(pattern);
            if (matches) {
                const numbers = matches.map(match => {
                    const num = match.replace(/[^0-9]/g, '');
                    return parseInt(num);
                }).filter(num => num >= 500 && num <= 10000); // Reasonable rent range
                
                if (numbers.length > 0) {
                    return Math.max(...numbers); // Return highest price found
                }
            }
        }
        
        return null;
    }

    // Validate environment variables before API calls
    validateEnvironmentVariables() {
        const requiredVars = {
            OPENAI_API_KEY: this.config.OPENAI_API_KEY,
            SUPABASE_URL: this.config.SUPABASE_URL,
            SUPABASE_ANON_KEY: this.config.SUPABASE_ANON_KEY
        };

        const missing = [];
        const present = [];

        for (const [varName, value] of Object.entries(requiredVars)) {
            if (!value || value.trim() === '') {
                missing.push(varName);
            } else {
                present.push(varName);
            }
        }

        if (missing.length > 0) {
            console.error('❌ Missing environment variables:', missing);
            console.log('✅ Present environment variables:', present);
            return {
                valid: false,
                missing: missing,
                present: present
            };
        }

        console.log('✅ All required environment variables present');
        return {
            valid: true,
            missing: [],
            present: present
        };
    }

    // Enhanced OpenAI API call with environment validation
    async callOpenAI(prompt, options = {}) {
        // Validate environment variables first
        const envCheck = this.validateEnvironmentVariables();
        if (!envCheck.valid) {
            throw new Error(`Missing environment variables: ${envCheck.missing.join(', ')}. Please configure these in Railway.`);
        }

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
                max_tokens: options.max_tokens || 150,
                temperature: options.temperature || 0.7,
                top_p: options.top_p || 1.0,
                frequency_penalty: options.frequency_penalty || 0,
                presence_penalty: options.presence_penalty || 0
            })
        });

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));
            const errorMessage = `OpenAI API Error: ${response.status} - ${errorData.error?.message || 'Unknown error'}`;
            console.error('❌ OpenAI API call failed:', errorMessage);
            
            // Return human-like fallback response instead of throwing
            return this.getFallbackResponse(prompt, options);
        }

        const data = await response.json();
        if (!data.choices || !data.choices[0] || !data.choices[0].message) {
            console.error('❌ Invalid OpenAI response structure');
            return this.getFallbackResponse(prompt, options);
        }

        return data.choices[0].message.content.trim();
    }

    // Generate fallback response when OpenAI API fails
    getFallbackResponse(prompt, options = {}) {
        console.log('🔄 Generating fallback response due to API failure');
        
        // Analyze the prompt to determine appropriate fallback
        const promptLower = prompt.toLowerCase();
        
        if (promptLower.includes('acceptance') || promptLower.includes('accept')) {
            return "Perfect! I'm excited to move forward with this rental. What are the next steps for finalizing everything?";
        }
        
        if (promptLower.includes('security deposit') || promptLower.includes('deposit')) {
            return "Absolutely! I'm ready to handle the security deposit. What's the amount and what's your preferred payment method?";
        }
        
        if (promptLower.includes('meeting') || promptLower.includes('logistics')) {
            return "Great! I'm flexible with timing. What works best for you? I can meet anytime that's convenient.";
        }
        
        if (promptLower.includes('counter') || promptLower.includes('negotiation')) {
            return "I appreciate you getting back to me. I'm definitely interested in working something out that works for both of us.";
        }
        
        if (promptLower.includes('clarif') || promptLower.includes('vague')) {
            return "Thanks for your response! Could you help me understand what you're thinking? I want to make sure we're on the same page.";
        }
        
        // Default professional fallback
        return "Thanks for your response! I'm really interested in this property and I'm hoping we can work something out. What are your thoughts?";
    }

    // Emergency response when everything else fails
    getEmergencyResponse(landlordMessage) {
        console.log('🚨 Generating emergency response for:', landlordMessage);
        
        const messageLower = landlordMessage.toLowerCase();
        
        // Handle common simple responses
        if (messageLower.includes('yes') || messageLower.includes('sure') || messageLower.includes('ok')) {
            return "Perfect! I'm excited to move forward. What should we do next to finalize everything?";
        }
        
        if (messageLower.includes('no') || messageLower.includes('sorry')) {
            return "I understand. Thank you for letting me know. If anything changes, please don't hesitate to reach out!";
        }
        
        if (messageLower.includes('price') || messageLower.includes('rent') || messageLower.includes('$')) {
            return "Thanks for getting back to me about the pricing. I'm definitely interested in working something out that makes sense for both of us.";
        }
        
        if (messageLower.includes('meet') || messageLower.includes('time') || messageLower.includes('when')) {
            return "Great! I'm flexible with timing and would love to meet when it's convenient for you. Just let me know what works best!";
        }
        
        // Generic friendly response
        return "Thanks for your message! I'm really interested in this property and would love to discuss it further. What would be the best next step?";
    }

    // Log state-aware conversation to Supabase
    async logStateAwareConversation(negotiationId, conversationState, generatedMessage, additionalContext = {}) {
        try {
            if (!this.supabase) return;
            
            const logData = {
                user_email: 'ai_negotiator',
                conversation_data: JSON.stringify([{
                    role: 'assistant',
                    content: generatedMessage,
                    timestamp: new Date().toISOString(),
                    conversationPhase: conversationState.phase,
                    messageCount: conversationState.messageCount,
                    landlordPersonality: additionalContext.landlordPersonality
                }]),
                title: `AI Message: ${conversationState.phase} (${additionalContext.landlordPersonality || 'unknown'} personality)`,
                metadata: {
                    negotiationId: negotiationId,
                    conversationPhase: conversationState.phase,
                    messageCount: conversationState.messageCount,
                    context: conversationState.context,
                    landlordPersonality: additionalContext.landlordPersonality,
                    personalityAdaptation: additionalContext.personalityAdaptation,
                    source: 'personality_aware_negotiation'
                }
            };

            const { error } = await this.supabase
                .from('ai_chats')
                .insert(logData);

            if (error) {
                console.error('Error logging state-aware conversation:', error);
            } else {
                console.log(`✅ Personality-aware conversation logged: ${conversationState.phase} (${additionalContext.landlordPersonality})`);
            }
        } catch (error) {
            console.error('Error in logStateAwareConversation:', error);
        }
    }

    // Enhanced negotiation message generation with conversation memory and learning
    async generateNegotiationMessage(listing, userBudget, marketData, conversationHistory = []) {
        try {
            console.log('🤖 Generating enhanced negotiation message for:', listing.title);

            // Get AI learning insights for this user and property type
            const learningInsights = await this.getLearningInsights(listing, userBudget);
            
            // Build conversation context from previous successful negotiations
            const contextualLearning = await this.getContextualLearning(listing.house_type, listing.city);

            const enhancedPrompt = `
            You are an advanced AI negotiation expert with access to learning data from successful negotiations. Generate a highly optimized negotiation message:

            LISTING DETAILS:
            - Title: ${listing.title}
            - Current Price: $${listing.price}/month
            - Type: ${listing.house_type}
            - Bedrooms: ${listing.bedrooms}
            - Location: ${listing.city || 'Not specified'}
            - Utilities: ${listing.utilities}

            USER PROFILE & PREFERENCES:
            - Budget: $${userBudget}
            - Looking for: ${listing.house_type}
            - Negotiation History: ${conversationHistory.length} previous conversations

            ENHANCED MARKET INTELLIGENCE:
            - Average market price: $${marketData.average}
            - Market range: $${marketData.min} - $${marketData.max}
            - Data source: ${marketData.source}
            - Market analysis: ${marketData.analysis || 'Standard market conditions'}
            - Comparable properties: ${marketData.negotiationTips || 'Standard pricing'}

            AI LEARNING INSIGHTS:
            - Successful price reduction patterns: ${learningInsights.successfulStrategies}
            - Optimal timing for offers: ${learningInsights.optimalTiming}
            - Effective value propositions: ${learningInsights.valueProps}
            - Landlord response patterns: ${learningInsights.landlordBehavior}

            CONTEXTUAL LEARNING DATA:
            - Similar property negotiations: ${contextualLearning.similarNegotiations}
            - Successful strategies in ${listing.city}: ${contextualLearning.locationStrategies}
            - ${listing.house_type} specific tactics: ${contextualLearning.propertyTypeStrategies}

            ADVANCED NEGOTIATION STRATEGY:
            1. Personalize approach based on successful patterns
            2. Use data-driven market justification
            3. Emphasize qualified tenant status with speed to close
            4. Apply psychological principles from successful cases
            5. Incorporate location-specific insights
            6. Optimize message length based on success data
            7. Use proven language patterns that convert

            DYNAMIC PRICING STRATEGY:
            - Apply learned discount ranges for this property type
            - Consider market momentum and seasonal factors
            - Use successful negotiation anchoring techniques
            - Optimize offer based on conversion probability

            CONVERSATION MEMORY:
            ${conversationHistory.length > 0 ? `Previous context: ${conversationHistory.slice(-3).map(msg => `${msg.role}: ${msg.content}`).join(' | ')}` : 'Initial contact'}

            Generate a message that maximizes negotiation success probability based on learned patterns. Be specific, data-driven, and compelling:
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
                    messages: [
                        { 
                            role: 'system', 
                            content: enhancedPrompt 
                        },
                        {
                            role: 'user',
                            content: `Generate an optimized negotiation message for this ${listing.house_type} in ${listing.city} priced at $${listing.price}. My budget is $${userBudget}. Use your learning data to maximize success probability.`
                        }
                    ],
                    max_tokens: 150,
                    temperature: 0.7,
                    top_p: 0.9,
                    frequency_penalty: 0.3,
                    presence_penalty: 0.2
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
                
                // Extract user budget from conversation history
                // Start with a realistic default based on listing price (85% of asking price - 15% discount max)
                let userBudget = listing.price ? Math.round(listing.price * 0.85) : 1500;
                try {
                    // Get conversation messages to find AI's initial offer
                    const { data: messages, error: msgError } = await this.supabase
                        .from('messages')
                        .select('content, sender_email')
                        .eq('conversation_id', conversationId)
                        .order('created_at', { ascending: true });
                    
                    if (!msgError && messages) {
                        // Look for AI messages with price mentions
                        for (const msg of messages) {
                            if (msg.sender_email === 'ai-negotiator@roomfinder.com' && msg.content) {
                                const extractedPrice = this.extractPriceFromMessage(msg.content);
                                if (extractedPrice && extractedPrice > 0) {
                                    userBudget = extractedPrice;
                                    console.log(`✅ Extracted userBudget from AI message: $${userBudget}`);
                                    break;
                                }
                            }
                        }
                    }
                } catch (error) {
                    console.log('Could not extract budget from conversation history, using default');
                }
                
                // Ensure budget is never less than 85% of listing price (15% discount max)
                if (listing.price && listing.price > 0) {
                    const minBudget = Math.round(listing.price * 0.85);
                    if (userBudget < minBudget) {
                        userBudget = minBudget;
                        console.log(`✅ Adjusted userBudget to minimum 85% of listing price: $${userBudget}`);
                    }
                }
                
                // Create new negotiation state from this reply
                negotiation = {
                    listingId: listing.id,
                    listingTitle: listing.title,
                    originalPrice: listing.price,
                    userBudget: userBudget,
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
                    
                    // Check for duplicates before sending
                    if (this.isRecentDuplicate(response, negotiation)) {
                        console.log('🚫 Duplicate response detected, generating alternative...');
                        // Generate alternative response with different strategy
                        response = await this.generateAlternativeResponse(analysis, negotiation, listing);
                    }
                    
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
                            let finalPrice = analysis.agreedPrice || this.extractLastOfferedPrice(negotiation);
                            
                            // CRITICAL: Ensure finalPrice is never null/undefined/0
                            if (!finalPrice || finalPrice <= 0) {
                                console.error('❌ CRITICAL: Invalid finalPrice in finalization, using fallback');
                                finalPrice = negotiation.userBudget || negotiation.originalPrice || 1500;
                                console.log('✅ Using fallback price for finalization:', finalPrice);
                            }
                            
                            negotiation.finalPrice = finalPrice;
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
                            
                            // PRIORITY 4: Track negotiation outcome for learning
                            try {
                                console.log('📊 Tracking successful negotiation outcome');
                                await this.trackNegotiationOutcome(negotiation, 'success', negotiation.finalPrice);
                            } catch (trackingError) {
                                console.log('Learning tracking failed:', trackingError.message);
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
            console.error('❌ Error handling negotiation reply:', error);
            
            // Emergency fallback - always respond with something human-like
            try {
                const emergencyResponse = this.getEmergencyResponse(message.content);
                await this.sendToLandlord(listing, emergencyResponse, 'emergency_fallback');
                console.log('🚨 Emergency response sent:', emergencyResponse);
            } catch (emergencyError) {
                console.error('❌ Emergency response also failed:', emergencyError);
            }
        }
    }

    // Analyze landlord's reply with advanced intelligence
    async analyzeReply(replyContent, negotiation, listing) {
        console.log('🔍 Starting advanced reply analysis for:', replyContent);
        
        // Check for specific meeting coordination first
        const meetingPatterns = /(?:meet|tonight|today|at\s+\d|pm|am|cafe|restaurant|office|property)/i;
        const hasMeetingDetails = meetingPatterns.test(replyContent);
        
        // Check for already finalized negotiation by looking at recent messages
        const recentMessages = negotiation.messages?.slice(-5) || [];
        const hasRecentAgreement = recentMessages.some(msg => 
            msg.sender === 'ai' && (
                msg.content.includes('accept') || 
                msg.content.includes('deal') ||
                msg.content.includes('perfect') ||
                msg.content.includes('excellent')
            )
        );
        
        if (hasMeetingDetails && hasRecentAgreement) {
            console.log('📅 MEETING COORDINATION DETECTED after agreement:', replyContent);
            return {
                sentiment: 'positive',
                priceOffered: null,
                acceptsOffer: false,
                makesCounterOffer: false,
                shouldRespond: true,
                isFinalized: false,
                agreedPrice: this.extractLastOfferedPrice(negotiation),
                responseStrategy: 'meeting_coordination',
                suggestedResponse: 'Meeting coordination needed',
                negotiationPhase: 'logistics',
                originalReply: replyContent,
                landlordPersonality: this.detectLandlordPersonality(replyContent, negotiation),
                negotiationContext: this.analyzeNegotiationContext(negotiation)
            };
        }

        // Check for security deposit requests - PRIORITY DETECTION (works anytime)
        const securityDepositPatterns = /\b(security deposit|deposit|first month|payment|money|transfer|funds|rent upfront|i need|need.*deposit)\b/i;
        const hasSecurityDepositMention = securityDepositPatterns.test(replyContent);
        
        if (hasSecurityDepositMention) {
            console.log('💰 SECURITY DEPOSIT REQUEST DETECTED:', replyContent);
            return {
                sentiment: 'positive',
                priceOffered: null,
                acceptsOffer: false,
                makesCounterOffer: false,
                shouldRespond: true,
                isFinalized: false,
                agreedPrice: this.extractLastOfferedPrice(negotiation),
                responseStrategy: 'security_deposit',
                suggestedResponse: 'Security deposit discussion needed',
                negotiationPhase: 'logistics',
                originalReply: replyContent,
                landlordPersonality: this.detectLandlordPersonality(replyContent, negotiation),
                negotiationContext: this.analyzeNegotiationContext(negotiation)
            };
        }

        // Check for move-in logistics (only after agreement)
        const moveInPatterns = /\b(move.?in|tomorrow|tonight|today|when can you|available|ready)\b/i;
        const hasMoveInMention = moveInPatterns.test(replyContent);
        
        if (hasMoveInMention && hasRecentAgreement) {
            console.log('🏠 MOVE-IN LOGISTICS DETECTED:', replyContent);
            return {
                sentiment: 'positive',
                priceOffered: null,
                acceptsOffer: false,
                makesCounterOffer: false,
                shouldRespond: true,
                isFinalized: false,
                agreedPrice: this.extractLastOfferedPrice(negotiation),
                responseStrategy: 'move_in_logistics',
                suggestedResponse: 'Move-in logistics needed',
                negotiationPhase: 'logistics',
                originalReply: replyContent,
                landlordPersonality: this.detectLandlordPersonality(replyContent, negotiation),
                negotiationContext: this.analyzeNegotiationContext(negotiation)
            };
        }
        
        // Check for vague responses that need clarification (PRIORITY CHECK)
        const simpleReply = replyContent.trim().toLowerCase();
        const vageResponsePatterns = /\b(sure but|maybe|i guess|i mean|kinda|sorta|a little|somewhat|perhaps|slight adjustment|small adjustment|little adjustment|minor change)\b/i;
        const isVagueResponse = vageResponsePatterns.test(replyContent);
        
        if (isVagueResponse) {
            console.log('❓ VAGUE RESPONSE DETECTED - needs clarification:', replyContent);
            return {
                sentiment: 'neutral',
                priceOffered: null,
                acceptsOffer: false,
                makesCounterOffer: false,
                shouldRespond: true,
                isFinalized: false,
                agreedPrice: null,
                responseStrategy: 'clarify_vague',
                suggestedResponse: 'Need clarification on vague response',
                negotiationPhase: 'clarification',
                originalReply: replyContent,
                landlordPersonality: this.detectLandlordPersonality(replyContent, negotiation),
                negotiationContext: this.analyzeNegotiationContext(negotiation)
            };
        }
        
        // First check for simple acceptance patterns IMMEDIATELY - Enhanced to handle multi-word responses
        const acceptancePatterns = [
            /^(sure|yes|ok|okay|sounds good|works|fine|agreed|deal|sounds great|yep|yeah|absolutely)$/i,
            /^(yes\s+(sure|absolutely|definitely|of course|certainly))/i,
            /^(sure\s+(thing|yes|absolutely|definitely))/i,
            /^(yeah\s+(sure|that works|sounds good|okay))/i,
            /^(absolutely\s+(yes|sure)?)/i,
            /^(definitely\s+(yes|sure)?)/i,
            /^(of course\s+(yes|sure)?)/i,
            /^(that\s+(works|sounds good|sounds great))/i,
            /^(sounds\s+(good|great|perfect|fine))/i,
            /^(works\s+for me)/i,
            /^(i accept)/i,
            /^(lets do it|let's do it)/i,
            /^(perfect)/i
        ];
        
        const isSimpleAcceptance = acceptancePatterns.some(pattern => pattern.test(simpleReply));
        
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
                negotiationPhase: 'closing',
                landlordPersonality: this.detectLandlordPersonality(replyContent, negotiation),
                negotiationContext: this.analyzeNegotiationContext(negotiation)
            };
        }

        // Advanced personality and sentiment detection
        const personalityProfile = this.detectLandlordPersonality(replyContent, negotiation);
        const emotionalState = this.detectEmotionalState(replyContent);
        const negotiationContext = this.analyzeNegotiationContext(negotiation);

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
                "responseStrategy": "accept/counter/negotiate/thank/clarify/increase_request/security_deposit",
                "suggestedResponse": "brief response if shouldRespond is true",
                "negotiationPhase": "initial/bargaining/closing/rejected"
            }

            ENHANCED ANALYSIS RULES:
            - "sure", "yes", "ok", "sounds good", "fine", "agreed", "deal" = acceptance of last offer
            - "I might consider X", "how about X", "what about X", "I could do X" = counter-offer
            - "too low", "too high", "not enough" = rejection requiring counter
            - "X is my best", "final offer X", "can't go lower than X" = firm counter-offer
            - "can you raise it", "can you increase", "bump it up", "go higher" = responseStrategy: "increase_request"
            - "i need deposit", "security deposit", "deposit required" = responseStrategy: "security_deposit"
            - "sure but", "maybe", "i guess", "a little", "kinda" = VAGUE responses, shouldRespond=true but isFinalized=false
            - Extract ALL numbers: $790, 790, "seven ninety", "790/month", "790 per month"
            - Look for conditional acceptance: "maybe X", "possibly X", "perhaps X"
            - If they accept: isFinalized=true, agreedPrice=last offered price
            - If they counter with price: extract exact number, shouldRespond=true
            - NEVER finalize on vague responses - require explicit price agreement
            - If they show flexibility ("might consider"): makesCounterOffer=true
            - Consider context: if discussing price and mention number, likely counter-offer
            
            MEETING COORDINATION DETECTION:
            - "let's meet", "we can do it tonight", "sounds great", "tonight", "today" = meeting logistics phase
            - "when can we", "what time", "where should", "I'm available" = scheduling discussion
            - If price already agreed and they mention timing = responseStrategy should be "meeting_coordination"
            - After acceptance, logistics phrases should trigger meeting planning responses
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
            
            // Enhanced fallback analysis with better detection
            const replyLower = replyContent.toLowerCase().trim();
            const hasPrice = replyContent.match(/\$(\d+)/);
            const seemsPositive = /\b(yes|ok|sure|accept|agree|sounds good|works|fine|deal|great|perfect)\b/i.test(replyContent);
            const hasAcceptanceWords = /\b(sure|yes|ok|okay|sounds good|works|fine|agreed|deal|sounds great|perfect|great|excellent)\b/i.test(replyLower);
            
            // Check for increase requests like "can you raise it"
            const isAskingForIncrease = /\b(can you|could you|would you).*(raise|increase|go up|higher)/i.test(replyContent) ||
                                      /\b(raise it|increase it|go higher|bump it up)/i.test(replyContent);
            
            console.log('🔧 Fallback analysis - hasAcceptanceWords:', hasAcceptanceWords, 'isAskingForIncrease:', isAskingForIncrease, 'for:', replyLower);
            
            return {
                sentiment: seemsPositive || isAskingForIncrease ? 'positive' : 'neutral',
                priceOffered: hasPrice ? parseInt(hasPrice[1]) : null,
                acceptsOffer: hasAcceptanceWords && !hasPrice && !isAskingForIncrease,
                makesCounterOffer: !!hasPrice || isAskingForIncrease,
                shouldRespond: true,
                isFinalized: hasAcceptanceWords && !hasPrice && !isAskingForIncrease,
                agreedPrice: (hasAcceptanceWords && !hasPrice && !isAskingForIncrease) ? this.extractLastOfferedPrice(negotiation) : null,
                responseStrategy: (hasAcceptanceWords && !hasPrice && !isAskingForIncrease) ? 'thank' : 
                                 (isAskingForIncrease ? 'increase_request' : 
                                 (hasPrice ? 'counter' : 'clarify')),
                negotiationPhase: (hasAcceptanceWords && !hasPrice && !isAskingForIncrease) ? 'closing' : 'bargaining',
                originalReply: replyContent
            };
        }
    }

    // Generate counter-response
    async generateCounterResponse(analysis, negotiation, listing) {
        if (!analysis.shouldRespond) return null;

        try {
            const negotiationId = this.getNegotiationId(negotiation);
            const roundNumber = negotiation.messages?.length || 1;
            
            console.log(`🎯 Generating response for round ${roundNumber}, sentiment: ${analysis.sentiment}`);

            if (analysis.isFinalized && analysis.acceptsOffer) {
                let finalPrice = analysis.agreedPrice || this.extractLastOfferedPrice(negotiation);
                
                // CRITICAL: Ensure finalPrice is never null/undefined/0
                if (!finalPrice || finalPrice <= 0) {
                    console.error('❌ CRITICAL: No valid price found, using fallback');
                    finalPrice = negotiation.userBudget || listing?.price || 1500;
                    console.log('✅ Using fallback price:', finalPrice);
                }
                
                console.log('🎉 GENERATING FINAL ACCEPTANCE RESPONSE - Price:', finalPrice);
                return this.generateVariedAcceptanceResponse(finalPrice, negotiationId, roundNumber);
            }

            if (analysis.makesCounterOffer && analysis.priceOffered) {
                console.log('💰 Generating sophisticated counter-offer response');
                return await this.generateSophisticatedCounterOffer(analysis, negotiation, listing, roundNumber);
            }

            if (analysis.responseStrategy === 'meeting_coordination') {
                console.log('📅 Generating meeting coordination response');
                // Pass the original reply for context
                analysis.originalReply = analysis.originalReply || analysis.suggestedResponse || '';
                return this.generateMeetingCoordinationResponse(analysis, negotiation, roundNumber);
            }

            if (analysis.responseStrategy === 'security_deposit') {
                console.log('💰 Generating security deposit response');
                let finalPrice = analysis.agreedPrice || this.extractLastOfferedPrice(negotiation);
                
                // CRITICAL: Ensure finalPrice is never null/undefined/0
                if (!finalPrice || finalPrice <= 0) {
                    console.error('❌ CRITICAL: No valid price for security deposit, using fallback');
                    finalPrice = negotiation.userBudget || listing?.price || 1500;
                    console.log('✅ Using fallback price for security deposit:', finalPrice);
                }
                
                return this.generateSecurityDepositResponse(finalPrice, negotiationId, roundNumber);
            }

            if (analysis.responseStrategy === 'move_in_logistics') {
                console.log('🏠 Generating move-in logistics response');
                return this.generateMoveInLogisticsResponse(negotiationId, roundNumber);
            }

            if (analysis.responseStrategy === 'increase_request') {
                console.log('⬆️ Generating increase request response');
                return this.generateIncreaseRequestResponse(negotiation, listing, negotiationId, roundNumber);
            }

            if (analysis.responseStrategy === 'clarify_vague') {
                console.log('❓ Generating clarification request for vague response');
                return this.generateVagueClarificationResponse(negotiation, listing, negotiationId, roundNumber);
            }

            if (analysis.sentiment === 'negative' || analysis.responseStrategy === 'clarify') {
                console.log('🔄 Generating strategic response for negative sentiment');
                return await this.generateStrategicResponse(negotiation, listing, roundNumber);
            }

            // Use progressive negotiation tactics
            console.log('🧠 Generating progressive contextual response');
            return await this.generateProgressiveResponse(analysis, negotiation, listing, roundNumber);

        } catch (error) {
            console.error('Error generating counter-response:', error);
            return this.getFallbackResponse(negotiation.messages?.length || 1);
        }
    }

    // Get unique negotiation ID for memory tracking
    getNegotiationId(negotiation) {
        return negotiation.negotiationId || negotiation.listingId || 'default';
    }

    // Generate varied acceptance response to prevent repetition
    generateVariedAcceptanceResponse(finalPrice, negotiationId, roundNumber) {
        // CRITICAL: Ensure finalPrice is never null/undefined/0
        if (!finalPrice || finalPrice <= 0) {
            console.error('❌ CRITICAL: Invalid finalPrice detected:', finalPrice);
            // Get negotiation to access fallback prices
            const negotiation = this.activeNegotiations.get(negotiationId);
            const listing = Array.from(this.activeNegotiations.values()).find(n => n.id === negotiationId)?.listing;
            // Use 85% of listing price as fallback (15% discount max)
            finalPrice = negotiation?.userBudget || (listing?.price ? Math.round(listing.price * 0.85) : 1500);
            console.log('✅ Using fallback price:', finalPrice);
        }
        
        const templates = this.responseTemplates.counterOfferAcceptance;
        const usedResponses = this.conversationalMemory.get(negotiationId) || new Set();
        
        let selectedTemplate;
        let templateIndex;
        
        // Use AI Learning System for intelligent template selection
        if (this.learningEnabled && this.learningSystem) {
            try {
                const context = await this.buildLearningContext('counter_offer_acceptance', negotiation, listing);
                const optimalTemplate = await this.learningSystem.getOptimalTemplate(context);
                
                if (optimalTemplate && optimalTemplate.templateId) {
                    templateIndex = optimalTemplate.templateId;
                    selectedTemplate = templates[templateIndex];
                }
                
                console.log('🧠 AI Learning selected template:', templateIndex, 'Reason:', optimalTemplate.reason);
            } catch (error) {
                console.error('❌ Learning system failed, falling back to random selection:', error);
                // Fallback to original logic
                const availableTemplates = templates.filter((_, index) => !usedResponses.has(`acceptance_${index}`));
                
                if (availableTemplates.length > 0) {
                    selectedTemplate = availableTemplates[Math.floor(Math.random() * availableTemplates.length)];
                } else {
                    usedResponses.clear();
                    selectedTemplate = templates[Math.floor(Math.random() * templates.length)];
                }
                templateIndex = templates.indexOf(selectedTemplate);
            }
        } else {
            // Original random selection logic
            const availableTemplates = templates.filter((_, index) => !usedResponses.has(`acceptance_${index}`));
            
            if (availableTemplates.length > 0) {
                selectedTemplate = availableTemplates[Math.floor(Math.random() * availableTemplates.length)];
            } else {
                usedResponses.clear();
                selectedTemplate = templates[Math.floor(Math.random() * templates.length)];
            }
            templateIndex = templates.indexOf(selectedTemplate);
        }
        
        // Mark this template as used
        usedResponses.add(`acceptance_${templateIndex}`);
        this.conversationalMemory.set(negotiationId, usedResponses);
        
        // Add price confirmation and closing details with variation
        const confirmationVariations = [
            `Just to confirm - we're agreeing on $${finalPrice}/month for the rental, correct?`,
            `Perfect! So we're set at $${finalPrice}/month - is that confirmed?`,
            `Excellent! To make sure we're on the same page - $${finalPrice}/month works for both of us?`,
            `Great! Just want to double-check - $${finalPrice}/month is our agreed price?`,
            `Wonderful! Confirming the final rent amount - $${finalPrice}/month, right?`
        ];
        
        const closingVariations = [
            " I'm ready to proceed immediately with all necessary documentation.",
            " I can provide excellent references and complete paperwork right away.",
            " I'm excited to finalize this! I have all my documents ready.",
            " I'm prepared to move quickly with references and paperwork.",
            " I can handle all the paperwork immediately."
        ];
        
        const confirmationIndex = roundNumber % confirmationVariations.length;
        const closingIndex = roundNumber % closingVariations.length;
        const baseResponse = selectedTemplate.replace(/\$\$\{price\}/g, finalPrice);
        
        return `${baseResponse} ${confirmationVariations[confirmationIndex]}${closingVariations[closingIndex]}`;
    }

    // Generate sophisticated counter-offer with progressive tactics
    async generateSophisticatedCounterOffer(analysis, negotiation, listing, roundNumber) {
        const landlordPrice = analysis.priceOffered;
        const userBudget = negotiation.userBudget;
        const negotiationId = this.getNegotiationId(negotiation);
        const lastOffer = this.extractLastOfferedPrice(negotiation);
        
        // SMART DIRECTION: Check if we should go UP or DOWN
        let targetPrice;
        let strategy;
        
        if (landlordPrice > lastOffer) {
            // Landlord wants MORE money - we should consider going UP from our last offer
            if (roundNumber <= 2) {
                // Early rounds: Meet them partway
                targetPrice = Math.min(userBudget, lastOffer + Math.round((landlordPrice - lastOffer) * 0.5));
                strategy = 'meeting_halfway';
            } else if (roundNumber <= 4) {
                // Middle rounds: Go closer to their price
                targetPrice = Math.min(userBudget, lastOffer + Math.round((landlordPrice - lastOffer) * 0.7));
                strategy = 'value_added';
            } else {
                // Later rounds: Get very close to their price
                targetPrice = Math.min(userBudget, lastOffer + Math.round((landlordPrice - lastOffer) * 0.85));
                strategy = 'closing_focus';
            }
            console.log(`⬆️ GOING UP: Landlord wants $${landlordPrice}, last offer was $${lastOffer}, increasing to $${targetPrice}`);
        } else {
            // Use original logic when landlord wants less or equal
            if (roundNumber <= 2) {
                targetPrice = Math.min(userBudget, Math.round(landlordPrice * 0.95));
                strategy = 'market_informed';
            } else if (roundNumber <= 4) {
                targetPrice = Math.min(userBudget, Math.round(landlordPrice * 0.97));
                strategy = 'value_added';
            } else {
                targetPrice = Math.min(userBudget, Math.round(landlordPrice * 0.985));
                strategy = 'closing_focus';
            }
        }
        
        // Ensure we don't exceed budget
        targetPrice = Math.min(targetPrice, userBudget);
        
        // CRITICAL: Ensure we never offer below 85% of listing price (15% discount max)
        if (listing.price && listing.price > 0) {
            const minOffer = Math.round(listing.price * 0.85);
            if (targetPrice < minOffer) {
                targetPrice = minOffer;
                console.log(`✅ Adjusted offer to minimum 85% of listing price: $${targetPrice}`);
            }
        }
        
        console.log(`🎯 Round ${roundNumber} strategy: ${strategy}, offering: $${targetPrice}`);
        
        return this.generateVariedCounterOffer(targetPrice, landlordPrice, strategy, negotiationId, roundNumber, listing);
    }

    // Generate varied counter-offer responses
    generateVariedCounterOffer(targetPrice, landlordPrice, strategy, negotiationId, roundNumber, listing) {
        const usedResponses = this.conversationalMemory.get(negotiationId) || new Set();
        
        let baseTemplate;
        let additionalContext = '';
        
        switch (strategy) {
            case 'market_informed':
                const marketTemplates = this.responseTemplates.marketBasedResponses;
                baseTemplate = this.selectUnusedTemplate(marketTemplates, usedResponses, 'market', negotiationId);
                additionalContext = " I've researched comparable properties to ensure fair pricing.";
                break;
                
            case 'value_added':
                const valueTemplates = this.responseTemplates.valuePropositions;
                baseTemplate = this.selectUnusedTemplate(valueTemplates, usedResponses, 'value', negotiationId);
                additionalContext = this.getValueAddOns(roundNumber);
                break;
                
            case 'closing_focus':
                const strategicTemplates = this.responseTemplates.strategicCounterOffers;
                baseTemplate = this.selectUnusedTemplate(strategicTemplates, usedResponses, 'strategic', negotiationId);
                additionalContext = " I'm ready to finalize this today if we can agree on terms.";
                break;
                
            default:
                const defaultTemplates = this.responseTemplates.strategicCounterOffers;
                baseTemplate = this.selectUnusedTemplate(defaultTemplates, usedResponses, 'default', negotiationId);
        }
        
        // CRITICAL: Ensure targetPrice is never null/undefined/0
        if (!targetPrice || targetPrice <= 0) {
            console.error('❌ CRITICAL: Invalid targetPrice detected:', targetPrice);
            const negotiation = this.activeNegotiations.get(negotiationId);
            // Use 85% of listing price as fallback (15% discount max)
            targetPrice = negotiation?.userBudget || (listing.price ? Math.round(listing.price * 0.85) : 1500);
            console.log('✅ Using fallback targetPrice:', targetPrice);
        }
        
        const response = baseTemplate.replace(/\$\$\{price\}/g, targetPrice) + additionalContext;
        
        console.log(`💬 Generated varied response (round ${roundNumber}): ${response.substring(0, 50)}...`);
        return this.formatMessage(response);
    }

    // Select unused template with fallback
    selectUnusedTemplate(templates, usedResponses, category, negotiationId) {
        const availableTemplates = templates.filter((_, index) => !usedResponses.has(`${category}_${index}`));
        
        let selectedTemplate;
        if (availableTemplates.length > 0) {
            selectedTemplate = availableTemplates[Math.floor(Math.random() * availableTemplates.length)];
        } else {
            // Reset category if all used
            for (let key of usedResponses) {
                if (key.startsWith(`${category}_`)) {
                    usedResponses.delete(key);
                }
            }
            selectedTemplate = templates[Math.floor(Math.random() * templates.length)];
        }
        
        // Mark as used
        const templateIndex = templates.indexOf(selectedTemplate);
        usedResponses.add(`${category}_${templateIndex}`);
        this.conversationalMemory.set(negotiationId, usedResponses);
        
        return selectedTemplate;
    }

    // Get value-added propositions based on round
    getValueAddOns(roundNumber) {
        const valueAdds = [
            " Plus, I can offer a longer lease commitment for stability.",
            " I'm also willing to handle minor maintenance to keep the property in excellent condition.",
            " Additionally, I can provide first and last month upfront for your security.",
            " I'm flexible on move-in dates to work with your schedule.",
            " I can also provide additional security deposit if that helps."
        ];
        
        return valueAdds[roundNumber % valueAdds.length];
    }

    // Generate strategic response for negative sentiment
    async generateStrategicResponse(negotiation, listing, roundNumber) {
        const userBudget = negotiation.userBudget;
        const dynamicMarketData = await this.getDynamicMarketData(
            listing.city, 
            listing.house_type, 
            listing.bedrooms
        );
        
        const adjustedOffer = Math.min(
            userBudget, 
            Math.round((dynamicMarketData?.adjustedAverage || listing.price) * 0.96)
        );
        
        const strategicResponses = [
            `I understand your position. Let me present a comprehensive offer: $${adjustedOffer}/month with excellent references, immediate occupancy, and long-term reliability. This reflects both market conditions and my value as a tenant.`,
            `I appreciate your feedback. Based on current market analysis, I can offer $${adjustedOffer}/month. This represents fair value while ensuring you have a responsible, verified tenant who takes excellent care of properties.`,
            `I respect your perspective. My research shows comparable properties at around $${adjustedOffer}/month. I'm offering this rate plus the peace of mind that comes with a reliable, long-term tenant with pristine references.`,
            `I hear you. Let me propose $${adjustedOffer}/month, which aligns with market data for similar properties. I bring exceptional tenant qualities including financial stability, property care, and communication.`
        ];
        
        const responseIndex = roundNumber % strategicResponses.length;
        return this.formatMessage(strategicResponses[responseIndex]);
    }

    // Generate progressive response using advanced tactics
    async generateProgressiveResponse(analysis, negotiation, listing, roundNumber) {
        const personality = analysis.landlordPersonality || this.detectLandlordPersonality(analysis.originalReply || '', negotiation);
        const userBudget = negotiation.userBudget;
        
        // SMART NEGOTIATION DIRECTION: Check what landlord actually wants
        let offerPrice;
        const lastOffer = this.extractLastOfferedPrice(negotiation);
        const landlordMessage = analysis.originalReply || '';
        
        // Check if landlord is asking for higher price
        const requestedPrice = this.extractPriceFromMessage(landlordMessage);
        const isAskingForMore = /\b(want|need|require)\s*\$?(\d+)/i.test(landlordMessage) ||
                               /\b(can you|could you).*(raise|increase|go up|higher)/i.test(landlordMessage);
        
        if (requestedPrice && isAskingForMore && requestedPrice > lastOffer) {
            // Landlord wants MORE - tenant should consider going UP (not down!)
            const increaseAmount = Math.min(
                userBudget - lastOffer, 
                Math.round((requestedPrice - lastOffer) * 0.7) // Meet them 70% of the way
            );
            offerPrice = Math.min(userBudget, lastOffer + increaseAmount);
            console.log(`🔄 CORRECTED DIRECTION: Landlord wants $${requestedPrice}, increasing from $${lastOffer} to $${offerPrice}`);
        } else {
            // Realistic progressive pricing based on rounds (15% max discount)
            const basePrice = listing.price;
            if (roundNumber === 1) {
                offerPrice = Math.min(userBudget, Math.round(basePrice * 0.85)); // Start at 15% below (minimum)
            } else if (roundNumber <= 3) {
                offerPrice = Math.min(userBudget, Math.round(basePrice * 0.90)); // Move to 10% below
            } else if (roundNumber <= 5) {
                offerPrice = Math.min(userBudget, Math.round(basePrice * 0.95)); // Move to 5% below
            } else {
                offerPrice = Math.min(userBudget, Math.round(basePrice * 0.97)); // Get very close to asking
            }
        }
        
        // Personality-adapted responses
        if (personality.communicationStyle === 'casual') {
            return this.generateCasualProgressiveResponse(offerPrice, roundNumber, listing);
        } else if (personality.traits?.includes('professional')) {
            return this.generateProfessionalProgressiveResponse(offerPrice, roundNumber, listing);
        } else {
            return this.generateBalancedProgressiveResponse(offerPrice, roundNumber, listing);
        }
    }

    // Generate casual progressive responses
    generateCasualProgressiveResponse(price, round, listing) {
        const casualResponses = [
            `Hey! Thanks for getting back to me. I'm really interested in the ${listing.house_type}. How about $${price}/month? I'm a great tenant - clean, quiet, and always on time with rent.`,
            `I appreciate you considering my offer! Would $${price}/month work? I'm flexible and really love the place. Plus, I'm super reliable and take great care of properties.`,
            `Thanks for the response! How about we settle on $${price}/month? I'm ready to move fast and I think you'll find I'm exactly the kind of tenant you want.`,
            `I hear you! What if we do $${price}/month? I'm really excited about this place and I guarantee you won't have any issues with me as a tenant.`
        ];
        
        return this.formatMessage(casualResponses[round % casualResponses.length]);
    }

    // Generate professional progressive responses
    generateProfessionalProgressiveResponse(price, round, listing) {
        const professionalResponses = [
            `Thank you for your consideration. I would like to propose $${price}/month for the ${listing.house_type}. I am a qualified professional tenant with excellent credit and references.`,
            `I appreciate your response. My offer is $${price}/month, reflecting both market conditions and my credentials as a reliable, long-term tenant with verifiable income and references.`,
            `Thank you for continuing our discussion. I can offer $${price}/month and provide comprehensive documentation including employment verification, credit report, and landlord references.`,
            `I value your time and consideration. My proposal of $${price}/month represents fair market value while ensuring you receive a dependable tenant with proven financial stability.`
        ];
        
        return this.formatMessage(professionalResponses[round % professionalResponses.length]);
    }

    // Generate balanced progressive responses
    generateBalancedProgressiveResponse(price, round, listing) {
        const balancedResponses = [
            `Thank you for your reply. I'd like to offer $${price}/month for this ${listing.house_type}. I'm a responsible tenant with excellent references and I'm ready to move forward quickly.`,
            `I appreciate your consideration. Would $${price}/month work for you? I can provide strong references and I'm committed to maintaining the property in excellent condition.`,
            `Thanks for getting back to me. I can offer $${price}/month and I'm prepared to provide all necessary documentation. I believe this represents good value for both of us.`,
            `I understand your position. My offer is $${price}/month, and I want to emphasize that you'll be getting a reliable, communicative tenant who respects both the property and landlord relationship.`
        ];
        
        return this.formatMessage(balancedResponses[round % balancedResponses.length]);
    }

    // Generate meeting coordination response
    generateMeetingCoordinationResponse(analysis, negotiation, roundNumber) {
        const negotiationId = this.getNegotiationId(negotiation);
        const usedResponses = this.conversationalMemory.get(negotiationId) || new Set();
        
        // Check if this is a follow-up to an already accepted offer
        const recentMessages = negotiation.messages?.slice(-3) || [];
        const hasRecentAcceptance = recentMessages.some(msg => 
            msg.sender === 'ai' && (
                msg.content.includes('accept') || 
                msg.content.includes('works excellently') ||
                msg.content.includes('Perfect') ||
                msg.content.includes('Excellent')
            )
        );
        
        if (hasRecentAcceptance) {
            // This is follow-up logistics, not initial acceptance
            return this.generateLogisticsFollowUp(analysis, roundNumber, negotiationId);
        } else {
            // This is initial meeting acceptance
            return this.generateInitialMeetingResponse(analysis, roundNumber, negotiationId);
        }
    }
    
    // Generate logistics follow-up (when we already accepted, now discussing meeting)
    generateLogisticsFollowUp(analysis, roundNumber, negotiationId) {
        const landlordMessage = analysis.originalReply || '';
        
        // Check if landlord provided specific meeting details
        const hasVenue = /(?:at\s+\w+|cafe|restaurant|office|property)/i.test(landlordMessage);
        const hasTime = /(?:\d{1,2}\s*(?:pm|am)|tonight|today|this evening)/i.test(landlordMessage);
        
        if (hasVenue || hasTime) {
            // Landlord provided specific details, confirm them
            const confirmationResponses = [
                "Perfect! That works excellently for me. I'll be there with all necessary documents and payment ready.",
                "Excellent! I can definitely make that work. I'll bring all required paperwork and be on time.",
                "Great! That sounds perfect. I'll come prepared with references, ID, and first month's rent.",
                "Wonderful! I'll see you there. I have all documentation ready and I'm excited to finalize everything.",
                "Outstanding! That timing works perfectly for me. I'll bring everything needed to complete the rental.",
                "Perfect! I'll be there with all necessary paperwork. Looking forward to finalizing our agreement!",
                "Fantastic! That works great for me. I'll come prepared with all documents and payment ready.",
                "Excellent! I can be there on time with all required documentation. See you then!"
            ];
            
            const responseIndex = roundNumber % confirmationResponses.length;
            return this.formatMessage(confirmationResponses[responseIndex]);
        } else {
            // General logistics coordination
            const logisticsResponses = [
                "Fantastic! I'm excited to finalize everything. What time works best for you? I'm available after 6 PM.",
                "Perfect! Should we meet at the property? I have all my documents ready including references and payment.",
                "Wonderful! What time should we arrange to meet? I can bring everything needed to complete the rental agreement.",
                "Excellent! I'm free this evening. Would you prefer to meet at 7 PM or later? I'll bring all necessary paperwork.",
                "Great! I'm ready to proceed tonight. What location would be most convenient for you?",
                "Outstanding! What time works for your schedule? I'll come prepared with all required documentation.",
                "Perfect! I'm available anytime after 5:30 PM. Should I bring the first month's rent and security deposit?",
                "Fantastic! What would be the best time and place to meet? I have everything organized and ready to go."
            ];
            
            const responseIndex = roundNumber % logisticsResponses.length;
            return this.formatMessage(logisticsResponses[responseIndex]);
        }
    }
    
    // Generate initial meeting response (when accepting and coordinating simultaneously)
    generateInitialMeetingResponse(analysis, roundNumber, negotiationId) {
        const meetingTemplates = this.responseTemplates.meetingCoordination;
        const documentTemplates = this.responseTemplates.documentPreparation;
        
        const meetingResponse = this.selectUnusedTemplate(meetingTemplates, this.conversationalMemory.get(negotiationId) || new Set(), 'meeting', negotiationId);
        const documentResponse = documentTemplates[roundNumber % documentTemplates.length];
        
        const combinedResponse = `${meetingResponse} ${documentResponse}`;
        return this.formatMessage(combinedResponse);
    }
    
    // Format message with proper punctuation and spacing
    formatMessage(message) {
        let formatted = message
            // Add space after periods if missing
            .replace(/\.([A-Z])/g, '. $1')
            // Add space after commas if missing
            .replace(/,([A-Z])/g, ', $1')
            // Add space after question marks if missing
            .replace(/\?([A-Z])/g, '? $1')
            // Add space after exclamation marks if missing
            .replace(/!([A-Z])/g, '! $1')
            // Fix multiple spaces
            .replace(/\s+/g, ' ')
            // Trim whitespace
            .trim();
        
        // Ensure proper capitalization after sentence endings
        formatted = formatted.replace(/([.!?]\s*)([a-z])/g, (match, punctuation, letter) => {
            return punctuation + letter.toUpperCase();
        });
        
        return formatted;
    }
    
    // Enhanced duplicate prevention
    isRecentDuplicate(message, negotiation) {
        if (!negotiation.messages || negotiation.messages.length === 0) return false;
        
        // Check last 3 AI messages for similarity
        const recentAIMessages = negotiation.messages
            .filter(m => m.sender === 'ai')
            .slice(-3)
            .map(m => m.content.toLowerCase().replace(/[^\w\s]/g, ''));
        
        const cleanCurrentMessage = message.toLowerCase().replace(/[^\w\s]/g, '');
        
        // Calculate similarity threshold (80% similar = duplicate)
        return recentAIMessages.some(prevMessage => {
            const similarity = this.calculateMessageSimilarity(cleanCurrentMessage, prevMessage);
            return similarity > 0.8;
        });
    }
    
    // Calculate message similarity (simple word overlap)
    calculateMessageSimilarity(message1, message2) {
        const words1 = new Set(message1.split(/\s+/));
        const words2 = new Set(message2.split(/\s+/));
        
        const intersection = new Set([...words1].filter(word => words2.has(word)));
        const union = new Set([...words1, ...words2]);
        
        return intersection.size / union.size;
    }

    // Generate alternative response when duplicate detected
    async generateAlternativeResponse(analysis, negotiation, listing) {
        console.log('🔄 Generating alternative response to avoid duplication');
        
        const roundNumber = negotiation.messages?.length || 1;
        const alternativeStrategies = [
            'casual_approach',
            'professional_approach', 
            'value_focused',
            'time_sensitive',
            'document_focused'
        ];
        
        const strategy = alternativeStrategies[roundNumber % alternativeStrategies.length];
        
        switch (strategy) {
            case 'casual_approach':
                return this.formatMessage("Awesome! I'm really excited about this place. When would be a good time to meet up? I've got everything ready to go!");
                
            case 'professional_approach':
                return this.formatMessage("Excellent. I appreciate your prompt response. Shall we arrange a meeting to finalize the rental agreement? I have all documentation prepared.");
                
            case 'value_focused':
                return this.formatMessage("Perfect! I'm confident you'll find me to be an ideal tenant. What's the best way to proceed with finalizing everything?");
                
            case 'time_sensitive':
                return this.formatMessage("Great! I'm ready to move forward immediately. What time works best for you today or this evening?");
                
            case 'document_focused':
                return this.formatMessage("Wonderful! I have all necessary paperwork including references and financial verification ready. How should we arrange to complete the process?");
                
            default:
                return this.formatMessage("Thank you! I'm looking forward to moving forward. What would be the next step?");
        }
    }

    // Get fallback response with variety
    getFallbackResponse(roundNumber) {
        const fallbacks = [
            "Thank you for your response. I'm very interested in moving forward with this rental and I'm flexible on terms.",
            "I appreciate your time. I'm committed to finding a mutually beneficial arrangement for this property.",
            "Thanks for continuing our discussion. I'm confident we can reach an agreement that works for both of us.",
            "I value your consideration. I'm a serious tenant looking to establish a positive rental relationship."
        ];
        
        return this.formatMessage(fallbacks[roundNumber % fallbacks.length]);
    }

    // Generate advanced counter-offer with sophisticated tactics (legacy method - keeping for compatibility)
    async generateAdvancedCounterOffer(analysis, negotiation, listing) {
        const userBudget = negotiation.userBudget;
        const counterPrice = analysis.priceOffered;
        const marketData = negotiation.marketData;
        const personality = analysis.landlordPersonality || this.detectLandlordPersonality(analysis.originalReply || '', negotiation);
        const context = analysis.negotiationContext || this.analyzeNegotiationContext(negotiation);

        console.log('🎯 Generating advanced counter-offer with personality:', personality.type);

        if (counterPrice <= userBudget) {
            return await this.generateAcceptanceResponse(counterPrice, personality, context);
        } else {
            return await this.generateCounterOfferWithStrategy(counterPrice, userBudget, marketData, personality, context, listing);
        }
    }

    // Generate acceptance response tailored to landlord personality
    async generateAcceptanceResponse(agreedPrice, personality, context) {
        if (personality.communicationStyle === 'casual') {
            return `Perfect! $${agreedPrice}/month works great for me. I'm ready to move fast and can provide solid references. When can we make this official?`;
        } else if (personality.traits.includes('professional')) {
            return `Excellent. I accept your offer of $${agreedPrice}/month. I'm prepared to proceed immediately with all necessary documentation and can provide comprehensive references and financial verification. Please advise on the next steps for finalizing our rental agreement.`;
        } else {
            return `Perfect! $${agreedPrice}/month works excellently for me. I'm ready to proceed immediately and can provide excellent references. When can we arrange to finalize the rental agreement?`;
        }
    }

    // Generate counter-offer with advanced strategy
    async generateCounterOfferWithStrategy(counterPrice, userBudget, marketData, personality, context, listing) {
        // Determine negotiation strategy based on personality and context
        const strategy = this.selectNegotiationStrategy(personality, context, marketData);
        console.log('🧠 Selected negotiation strategy:', strategy);

        let baseOffer = Math.min(userBudget, Math.round(counterPrice * 0.92));
        let response = '';

        switch (strategy) {
            case 'value_proposition':
                response = await this.generateValuePropositionResponse(baseOffer, counterPrice, personality, listing);
                break;
            case 'market_data':
                response = await this.generateMarketDataResponse(baseOffer, counterPrice, marketData, personality);
                break;
            case 'emotional_appeal':
                response = await this.generateEmotionalResponse(baseOffer, counterPrice, personality, context);
                break;
            case 'compromise_creative':
                response = await this.generateCreativeCompromise(baseOffer, counterPrice, personality, listing);
                break;
            case 'final_attempt':
                response = await this.generateFinalAttemptResponse(baseOffer, counterPrice, personality);
                break;
            default:
                response = await this.generateStandardResponse(baseOffer, counterPrice, marketData, personality);
        }

        return response;
    }

    // Select the best negotiation strategy
    selectNegotiationStrategy(personality, context, marketData) {
        // If landlord is frustrated/skeptical, use value proposition
        if (personality.emotionalState === 'frustrated' || personality.traits.includes('skeptical')) {
            return 'value_proposition';
        }
        
        // If landlord is experienced, use market data
        if (personality.traits.includes('experienced')) {
            return 'market_data';
        }
        
        // If landlord is casual/informal, use emotional appeal
        if (personality.communicationStyle === 'casual') {
            return 'emotional_appeal';
        }
        
        // If we're in later rounds, try creative compromise
        if (context.roundsOfNegotiation >= 3) {
            return 'compromise_creative';
        }
        
        // If significant price reduction already made, final attempt
        if (context.priceReductions.significant) {
            return 'final_attempt';
        }
        
        return 'market_data'; // Default to data-driven approach
    }

    // Generate value proposition response (for skeptical landlords)
    async generateValuePropositionResponse(offer, counterPrice, personality, listing) {
        const valueProp = this.generateValuePropositions(listing);
        
        if (personality.communicationStyle === 'casual') {
            return `I hear you! Look, I get that you've heard it all before. Here's the real deal - I can do $${offer}/month, and here's what you get: ${valueProp.casual}. I'm not just another tenant making promises.`;
        } else {
            return `I understand your position and appreciate your directness. I can offer $${offer}/month, and I'd like to present some concrete value: ${valueProp.formal}. I believe this creates a win-win situation for both of us.`;
        }
    }

    // Generate market data response (for experienced landlords)
    async generateMarketDataResponse(offer, counterPrice, marketData, personality) {
        if (!marketData) {
            return `I appreciate your counter-offer. Based on my research of comparable properties, I can offer $${offer}/month. This reflects current market conditions while ensuring fair value for both parties.`;
        }

        const marketJustification = counterPrice > marketData.average ? 
            `current market data shows similar properties averaging $${marketData.average}/month` :
            `this aligns well with current market rates of around $${marketData.average}/month`;

        if (personality.communicationStyle === 'formal') {
            return `Thank you for your counter-offer. Based on comprehensive market analysis, ${marketJustification}. I can offer $${offer}/month, which represents fair market value while recognizing the quality of your property.`;
        } else {
            return `I appreciate the counter! Looking at ${marketJustification}, I can do $${offer}/month. Fair deal for both of us based on what's out there right now.`;
        }
    }

    // Generate emotional appeal response (for casual landlords)
    async generateEmotionalResponse(offer, counterPrice, personality, context) {
        if (personality.communicationStyle === 'casual') {
            return `I really love this place and can see myself living here long-term. I can stretch to $${offer}/month - that's honestly my max but I'd rather pay it for the right spot with a cool landlord. What do you think?`;
        } else {
            return `I'm genuinely excited about this property and can envision making it my home. I can offer $${offer}/month, which represents my maximum budget. I'm committed to being an exemplary tenant who takes excellent care of the property.`;
        }
    }

    // Generate creative compromise (for extended negotiations)
    async generateCreativeCompromise(offer, counterPrice, personality, listing) {
        const compromises = [
            `$${offer}/month with a 18-month lease commitment`,
            `$${offer}/month plus I'll handle minor maintenance and upkeep`,
            `$${offer}/month with first and last month paid upfront`,
            `$${offer}/month and I'll help with property improvements`
        ];

        const selectedCompromise = compromises[Math.floor(Math.random() * compromises.length)];

        if (personality.communicationStyle === 'casual') {
            return `How about we get creative here? I can do ${selectedCompromise}. That way we both win - you get a reliable tenant and I get a fair deal. Sound good?`;
        } else {
            return `I'd like to propose a mutually beneficial arrangement: ${selectedCompromise}. This provides additional value and security for you while working within my budget constraints.`;
        }
    }

    // Generate final attempt response
    async generateFinalAttemptResponse(offer, counterPrice, personality) {
        if (personality.communicationStyle === 'casual') {
            return `Alright, final offer: $${offer}/month. That's genuinely my absolute max. If it works, awesome! If not, no hard feelings and thanks for your time.`;
        } else {
            return `I appreciate your time and consideration. My final offer is $${offer}/month - this represents my absolute maximum budget. If this works for you, I'm ready to proceed immediately. If not, I completely understand and thank you for the opportunity.`;
        }
    }

    // Generate standard response
    async generateStandardResponse(offer, counterPrice, marketData, personality) {
        let justification = '';
        if (marketData && counterPrice > marketData.average) {
            justification = ` Given that similar properties in the area average around $${marketData.average}/month,`;
        }
        
        return `I really appreciate your counter-offer!${justification} Would you consider $${offer}/month? This fits perfectly within my budget and I can guarantee immediate occupancy with excellent references. I'm a serious, reliable tenant looking to establish a long-term rental relationship.`;
    }

    // Generate value propositions
    generateValuePropositions(listing) {
        return {
            casual: "long-term lease (I'm not going anywhere), excellent credit, no parties, and I actually take care of places better than most owners",
            formal: "a minimum 12-month lease commitment, verifiable excellent credit history, comprehensive renters insurance, and meticulous property care with regular maintenance updates"
        };
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
            
            IMPORTANT PRICING RULES:
            - NEVER offer less than 85% of the listing price ($${Math.round(listing.price * 0.85)}/month minimum)
            - Start negotiations at 85% and gradually increase (85% → 90% → 95% → 97%)
            - Maximum discount is 15% below listing price
            
            Generate a professional, persuasive response (2-3 sentences max) that:
            1. Acknowledges their position respectfully
            2. Emphasizes tenant reliability and quick decision-making
            3. Makes a reasonable counter-proposal if needed (respecting pricing rules above)
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
                    model: this.config.OPENAI_MODEL || 'gpt-3.5-turbo',
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
        if (!this.supabase) {
            console.error('❌ Supabase client not initialized - cannot setup message listener');
            return;
        }
        
        try {
            console.log('🔗 Setting up real-time message listener...');
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
                        
                        if (!conversation) {
                            console.log('📭 No conversation found for message');
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

            // Store channel reference for cleanup
            this.messageChannel = messageChannel;
            console.log('🔔 Negotiation message listener setup complete');

        } catch (error) {
            console.error('Error setting up message listener:', error);
        }
    }

    // Start a new negotiation
    async startNegotiation(listing, userBudget, userEmail) {
        try {
            console.log('🚀 Starting negotiation for:', listing.title);
            
            // Prevent duplicate negotiations for the same listing
            const existingNegotiation = Array.from(this.activeNegotiations.values())
                .find(neg => neg.listingId === listing.id && neg.userEmail === userEmail);
            
            if (existingNegotiation) {
                console.log('⚠️ Negotiation already exists for this listing, skipping duplicate');
                return {
                    success: false,
                    message: 'Negotiation already in progress for this listing',
                    marketData: existingNegotiation.marketData
                };
            }

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
            console.log('🔍 Extracting last offered price from negotiation...');
            
            // First, check if there's an explicitly stored final price
            if (negotiation.finalPrice) {
                console.log('✅ Found stored final price:', negotiation.finalPrice);
                return negotiation.finalPrice;
            }
            
            // Look through all recent messages (AI and landlord) for price mentions
            const recentMessages = negotiation.messages?.slice(-5) || [];
            
            for (let i = recentMessages.length - 1; i >= 0; i--) {
                const message = recentMessages[i].content;
                
                // Enhanced price matching patterns
                const priceMatches = [
                    /\$(\d+)\/month/gi,
                    /\$(\d+)\s*per\s*month/gi,
                    /\$(\d+)\s*monthly/gi,
                    /(\d+)\/month/gi,
                    /(\d+)\s*per\s*month/gi,
                    /(\d+)\s*monthly/gi,
                    // Also match simple number patterns when context is about price
                    /(?:accept|agreed?|deal|works?|sounds?\s+good).*?(\d{3,4})(?!\d)/gi,
                    /(\d{3,4})(?!\d).*?(?:accept|agreed?|deal|works?|sounds?\s+good)/gi
                ];
                
                for (const pattern of priceMatches) {
                    const matches = [...message.matchAll(pattern)];
                    if (matches.length > 0) {
                        const price = parseInt(matches[0][1]);
                        if (price >= 100 && price <= 5000) { // Reasonable rent range
                            console.log(`✅ Found price ${price} in message: "${message.substring(0, 50)}..."`);
                            return price;
                        }
                    }
                }
            }
            
            // Fallback to user budget if no specific price found
            const fallbackPrice = negotiation.userBudget || negotiation.originalPrice || 1500;
            console.log('⚠️ No price found, using fallback:', fallbackPrice);
            return fallbackPrice;
        } catch (error) {
            console.error('Error extracting last offered price:', error);
            const fallbackPrice = negotiation.userBudget || negotiation.originalPrice || 1500;
            console.log('✅ Error fallback price:', fallbackPrice);
            return fallbackPrice;
        }
    }

    // Generate market-based negotiation response to rejections
    // Enhanced dynamic pricing model with market intelligence
    async getDynamicMarketData(location, houseType, bedrooms, seasonality = null) {
        const cacheKey = `dynamic_${location}-${houseType}-${bedrooms}-${seasonality || 'default'}`;
        
        if (this.marketData.has(cacheKey)) {
            console.log('📊 Using cached dynamic market data for:', cacheKey);
            return this.marketData.get(cacheKey);
        }

        try {
            // Get base market data
            const baseMarketData = await this.getMarketData(location, houseType, bedrooms);
            
            // Apply dynamic adjustments
            const adjustments = await this.calculateMarketAdjustments(location, houseType, bedrooms);
            
            const dynamicData = {
                ...baseMarketData,
                adjustedAverage: Math.round(baseMarketData.average * adjustments.priceMultiplier),
                adjustedMedian: Math.round(baseMarketData.median * adjustments.priceMultiplier),
                seasonalFactor: adjustments.seasonalFactor,
                demandLevel: adjustments.demandLevel,
                competitiveIndex: adjustments.competitiveIndex,
                locationDesirability: adjustments.locationDesirability,
                negotiationLeverage: this.calculateNegotiationLeverage(adjustments),
                pricingStrategy: this.determinePricingStrategy(adjustments),
                adjustmentFactors: adjustments
            };
            
            this.marketData.set(cacheKey, dynamicData);
            console.log('📊 Dynamic market data calculated:', dynamicData);
            
            return dynamicData;
        } catch (error) {
            console.error('Error getting dynamic market data:', error);
            return await this.getMarketData(location, houseType, bedrooms);
        }
    }

    // Calculate market adjustment factors for dynamic pricing
    async calculateMarketAdjustments(location, houseType, bedrooms) {
        try {
            const currentMonth = new Date().getMonth() + 1;
            const currentYear = new Date().getFullYear();
            
            // Seasonal adjustment (rental market seasonality)
            const seasonalFactor = this.getSeasonalAdjustment(currentMonth);
            
            // Property age and condition adjustment
            const propertyAgeAdjustment = this.getPropertyAgeAdjustment(houseType);
            
            // Location desirability scoring
            const locationDesirability = await this.calculateLocationDesirability(location);
            
            // Demand vs supply analysis
            const demandLevel = await this.analyzeDemandLevel(location, houseType, bedrooms);
            
            // Competitive pricing analysis
            const competitiveIndex = await this.calculateCompetitiveIndex(location, houseType, bedrooms);
            
            // Calculate overall price multiplier
            const priceMultiplier = (
                seasonalFactor * 
                propertyAgeAdjustment * 
                locationDesirability * 
                demandLevel * 
                competitiveIndex
            );
            
            return {
                seasonalFactor,
                propertyAgeAdjustment,
                locationDesirability,
                demandLevel,
                competitiveIndex,
                priceMultiplier: Math.max(0.7, Math.min(1.4, priceMultiplier)) // Cap between 70% and 140%
            };
        } catch (error) {
            console.error('Error calculating market adjustments:', error);
            return {
                seasonalFactor: 1.0,
                propertyAgeAdjustment: 1.0,
                locationDesirability: 1.0,
                demandLevel: 1.0,
                competitiveIndex: 1.0,
                priceMultiplier: 1.0
            };
        }
    }

    // Seasonal adjustment based on rental market patterns
    getSeasonalAdjustment(month) {
        // Peak season: May-September (higher prices)
        // Off-season: November-March (lower prices)
        const seasonalMap = {
            1: 0.92,   // January - low demand
            2: 0.90,   // February - lowest demand
            3: 0.95,   // March - starting to pick up
            4: 1.02,   // April - spring demand
            5: 1.08,   // May - peak season starts
            6: 1.10,   // June - peak demand
            7: 1.12,   // July - highest demand
            8: 1.10,   // August - still high
            9: 1.05,   // September - demand cooling
            10: 0.98,  // October - moderate
            11: 0.94,  // November - slowing down
            12: 0.92   // December - holiday slowdown
        };
        return seasonalMap[month] || 1.0;
    }

    // Property age and condition factor
    getPropertyAgeAdjustment(houseType) {
        // Newer properties command higher rents
        const typeAdjustments = {
            'apartment': 1.0,
            'house': 1.05,     // Houses typically rent for more
            'condo': 1.02,
            'townhouse': 1.03,
            'studio': 0.95,
            'room': 0.85       // Rooms rent for less
        };
        return typeAdjustments[houseType?.toLowerCase()] || 1.0;
    }

    // Calculate location desirability score
    async calculateLocationDesirability(location) {
        if (!location) return 1.0;
        
        const locationLower = location.toLowerCase();
        
        // Major city centers get higher scores
        const cityScores = {
            'paris': 1.20,
            'toronto': 1.15,
            'vancouver': 1.18,
            'montreal': 1.10,
            'london': 1.22,
            'new york': 1.25,
            'san francisco': 1.30,
            'los angeles': 1.18,
            'chicago': 1.12,
            'boston': 1.15,
            'seattle': 1.20,
            'washington': 1.17,
            'miami': 1.14,
            'berlin': 1.10,
            'amsterdam': 1.16,
            'sydney': 1.18,
            'melbourne': 1.15
        };
        
        for (const [city, score] of Object.entries(cityScores)) {
            if (locationLower.includes(city)) {
                return score;
            }
        }
        
        // Default for other locations
        return 1.0;
    }

    // Analyze demand level for specific market segment
    async analyzeDemandLevel(location, houseType, bedrooms) {
        try {
            // Query recent listing activity
            const { data: recentListings } = await this.supabase
                .from('listings')
                .select('price, created_at')
                .gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
                .ilike('city', `%${location}%`)
                .eq('house_type', houseType)
                .eq('bedrooms', bedrooms)
                .limit(20);
            
            if (!recentListings?.length) return 1.0;
            
            // High activity = high demand = higher prices
            const activityLevel = recentListings.length;
            
            if (activityLevel >= 15) return 1.08;      // Very high demand
            if (activityLevel >= 10) return 1.05;      // High demand
            if (activityLevel >= 5) return 1.02;       // Moderate demand
            return 0.98;                               // Lower demand
            
        } catch (error) {
            console.error('Error analyzing demand level:', error);
            return 1.0;
        }
    }

    // Calculate competitive index based on similar listings
    async calculateCompetitiveIndex(location, houseType, bedrooms) {
        try {
            // Get similar active listings
            const { data: competitors } = await this.supabase
                .from('listings')
                .select('price')
                .ilike('city', `%${location}%`)
                .eq('house_type', houseType)
                .eq('bedrooms', bedrooms)
                .gte('price', 1) // Only listings with valid prices
                .limit(30);
            
            if (!competitors?.length) return 1.0;
            
            const prices = competitors.map(c => c.price);
            const priceVariation = (Math.max(...prices) - Math.min(...prices)) / Math.max(...prices);
            
            // High price variation = more negotiation room
            if (priceVariation > 0.3) return 0.95;     // High variation, lower baseline
            if (priceVariation > 0.2) return 0.98;     // Moderate variation
            return 1.02;                               // Low variation, premium market
            
        } catch (error) {
            console.error('Error calculating competitive index:', error);
            return 1.0;
        }
    }

    // Calculate negotiation leverage based on market conditions
    calculateNegotiationLeverage(adjustments) {
        const leverageScore = (
            (1 - adjustments.demandLevel) * 0.3 + // Lower demand = more leverage
            (1 - adjustments.competitiveIndex) * 0.3 + // Less competition = more leverage
            (1 - adjustments.seasonalFactor) * 0.2 + // Off-season = more leverage
            (1 - adjustments.locationDesirability) * 0.2 // Less desirable = more leverage
        );
        
        if (leverageScore > 0.15) return 'high';
        if (leverageScore > 0.05) return 'medium';
        return 'low';
    }

    // Determine optimal pricing strategy
    determinePricingStrategy(adjustments) {
        const priceMultiplier = adjustments.priceMultiplier;
        
        if (priceMultiplier > 1.1) return 'premium_market';
        if (priceMultiplier < 0.9) return 'aggressive_pricing';
        return 'balanced_approach';
    }

    // Select advanced negotiation strategy based on context
    selectAdvancedNegotiationStrategy(analysis, negotiation, dynamicMarketData) {
        const personality = analysis.landlordPersonality;
        const leverage = dynamicMarketData?.negotiationLeverage || 'medium';
        const pricingStrategy = dynamicMarketData?.pricingStrategy || 'balanced_approach';
        
        if (personality?.emotionalState === 'frustrated' || personality?.traits.includes('skeptical')) {
            return "VALUE PROPOSITION STRATEGY: Focus on tenant quality, reliability, and non-monetary benefits. Emphasize quick decision-making and long-term tenancy.";
        }
        
        if (personality?.traits.includes('experienced') || personality?.communicationStyle === 'business') {
            return "MARKET DATA STRATEGY: Present comprehensive market analysis with specific comparables and pricing justification. Use data-driven arguments.";
        }
        
        if (leverage === 'high' && pricingStrategy === 'aggressive_pricing') {
            return "MARKET LEVERAGE STRATEGY: Highlight current market conditions favoring tenants. Present alternative options and competitive pricing.";
        }
        
        if (personality?.traits.includes('flexible') && negotiation.messages?.length <= 2) {
            return "CREATIVE COMPROMISE STRATEGY: Offer package deals including longer lease terms, utilities, maintenance responsibilities, or other value-adds.";
        }
        
        if (negotiation.messages?.length >= 3) {
            return "FINAL ATTEMPT STRATEGY: Present best and final offer with clear reasoning and deadline for response. Show respect for their position while maintaining firm stance.";
        }
        
        return "BALANCED PERSUASION STRATEGY: Combine market data with personal tenant qualities and reasonable compromise offers.";
    }

    // Extract price from message content
    extractPriceFromMessage(content) {
        const priceMatch = content.match(/\$([0-9,]+)/);
        return priceMatch ? parseInt(priceMatch[1].replace(/,/g, '')) : null;
    }

    async generateMarketBasedNegotiation(negotiation, listing, landlordMessage, analysis) {
        try {
            console.log('🏢 Generating advanced market-based response with dynamic pricing');
            
            // Get enhanced market data with dynamic pricing
            const dynamicMarketData = await this.getDynamicMarketData(
                listing.city, 
                listing.house_type, 
                listing.bedrooms
            );
            
            console.log('🏠 Using enhanced market data for negotiation:', dynamicMarketData);
            
            const prompt = `
            You are an expert rental negotiator with advanced market intelligence responding to a landlord's rejection.

            LANDLORD'S RESPONSE: "${landlordMessage}"
            SENTIMENT: ${analysis.sentiment}
            LANDLORD PERSONALITY: ${analysis.landlordPersonality?.type || 'unknown'}
            
            PROPERTY DETAILS:
            - ${listing.title}
            - Current Price: $${listing.price}/month
            - Type: ${listing.house_type}
            - Bedrooms: ${listing.bedrooms}
            - Location: ${listing.city}
            
            ADVANCED MARKET INTELLIGENCE:
            - Base Market Average: $${negotiation.marketData?.average || 'Unknown'}
            - Dynamic Adjusted Average: $${dynamicMarketData?.adjustedAverage || dynamicMarketData?.average || 'Unknown'}
            - Seasonal Factor: ${((dynamicMarketData?.seasonalFactor || 1) * 100 - 100).toFixed(1)}% ${(dynamicMarketData?.seasonalFactor || 1) > 1 ? 'premium' : 'discount'}
            - Location Desirability: ${(((dynamicMarketData?.locationDesirability || 1) * 100) - 100).toFixed(1)}% adjustment
            - Market Demand Level: ${(dynamicMarketData?.demandLevel || 1) > 1.05 ? 'High' : (dynamicMarketData?.demandLevel || 1) > 0.98 ? 'Moderate' : 'Low'}
            - Negotiation Leverage: ${dynamicMarketData?.negotiationLeverage || 'medium'}
            - Pricing Strategy: ${dynamicMarketData?.pricingStrategy || 'balanced_approach'}
            - Competitive Index: ${(((dynamicMarketData?.competitiveIndex || 1) * 100) - 100).toFixed(1)}% vs market
            
            NEGOTIATION CONTEXT:
            - Original ask: $${listing.price}
            - User budget: $${negotiation.userBudget}
            - Messages exchanged: ${negotiation.messages?.length || 0}
            - Previous offers: ${negotiation.messages?.filter(m => m.sender === 'ai').map(m => this.extractPriceFromMessage(m.content)).filter(p => p).join(', ') || 'None'}
            
            ADVANCED STRATEGY SELECTION:
            ${this.selectAdvancedNegotiationStrategy(analysis, negotiation, dynamicMarketData)}
            
            Generate a sophisticated response that:
            1. Acknowledges their position with emotional intelligence
            2. Presents compelling market-based evidence using dynamic data
            3. Offers value-added proposals beyond just price (lease terms, utilities, maintenance, etc.)
            4. Demonstrates tenant quality and reliability
            5. Provides a specific counter-offer with multi-factor justification
            6. Adapts tone to landlord's personality and communication style
            
            Keep response professional, persuasive, and appropriately detailed (2-4 sentences):
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

    // Advanced negotiation success tracking and learning system
    async trackNegotiationOutcome(negotiation, outcome, finalPrice = null) {
        try {
            console.log('📊 Tracking negotiation outcome:', outcome, 'for listing:', negotiation.listingTitle);
            
            const outcomeData = {
                negotiation_id: negotiation.negotiationId || `neg_${Date.now()}`,
                listing_id: negotiation.listingId,
                user_email: negotiation.userEmail,
                landlord_email: negotiation.landlordEmail,
                original_price: negotiation.originalPrice,
                user_budget: negotiation.userBudget,
                final_price: finalPrice || negotiation.finalPrice,
                outcome: outcome, // 'success', 'failure', 'abandoned'
                negotiation_duration: negotiation.startTime ? (Date.now() - new Date(negotiation.startTime).getTime()) / 1000 : null,
                message_count: negotiation.messages?.length || 0,
                market_data: negotiation.marketData,
                dynamic_market_data: negotiation.dynamicMarketData,
                landlord_personality: negotiation.landlordPersonality,
                strategies_used: negotiation.strategiesUsed || [],
                success_factors: this.analyzeSuccessFactors(negotiation, outcome, finalPrice),
                created_at: new Date().toISOString()
            };
            
            // Enhanced conversation logging to Supabase
            await this.logConversationToSupabase(outcomeData, negotiation);
            
            // Store in localStorage as backup
            this.storeOutcomeLocally(outcomeData);
            console.log('✅ Negotiation outcome tracked successfully');
            
            // Update learning model
            await this.updateLearningModel(outcomeData);
            
        } catch (error) {
            console.error('Error tracking negotiation outcome:', error);
            // Fallback to local storage
            try {
                this.storeOutcomeLocally({
                    outcome,
                    finalPrice,
                    timestamp: new Date().toISOString(),
                    listingTitle: negotiation.listingTitle
                });
            } catch (storageError) {
                console.error('Failed to store outcome locally:', storageError);
            }
        }
    }

    // Enhanced conversation logging to Supabase for learning system
    async logConversationToSupabase(outcomeData, negotiation) {
        try {
            console.log('📊 Logging comprehensive conversation data to Supabase');
            
            // Prepare enhanced conversation data with learning insights
            const conversationData = {
                user_email: negotiation.userEmail,
                conversation_data: JSON.stringify([
                    {
                        role: 'system',
                        content: `Negotiation completed: ${outcomeData.outcome}`,
                        timestamp: new Date().toISOString()
                    },
                    {
                        role: 'assistant', 
                        content: `Property: ${negotiation.listingTitle}\nOriginal Price: $${negotiation.originalPrice}\nFinal Price: $${outcomeData.final_price}\nSavings: $${negotiation.originalPrice - outcomeData.final_price}\nDuration: ${Math.round(outcomeData.negotiation_duration / 60)} minutes\nMessages: ${outcomeData.message_count}`,
                        timestamp: new Date().toISOString()
                    }
                ]),
                title: `Negotiation ${outcomeData.outcome}: ${negotiation.listingTitle}`,
                created_at: new Date().toISOString(),
                // Enhanced metadata for learning system
                metadata: {
                    // Core negotiation data
                    negotiationId: outcomeData.negotiation_id,
                    listingId: outcomeData.listing_id,
                    outcome: outcomeData.outcome,
                    success: outcomeData.outcome === 'success',
                    dealClosed: outcomeData.outcome === 'success',
                    
                    // Financial data  
                    originalPrice: outcomeData.original_price,
                    finalPrice: outcomeData.final_price,
                    userBudget: outcomeData.user_budget,
                    savings: outcomeData.original_price - outcomeData.final_price,
                    savingsPercentage: Math.round(((outcomeData.original_price - outcomeData.final_price) / outcomeData.original_price) * 100),
                    
                    // Negotiation metrics
                    duration: outcomeData.negotiation_duration,
                    messageCount: outcomeData.message_count,
                    avgResponseTime: outcomeData.negotiation_duration / Math.max(outcomeData.message_count, 1),
                    
                    // Market context
                    marketData: outcomeData.market_data,
                    dynamicMarketData: outcomeData.dynamic_market_data,
                    
                    // Learning insights
                    landlordPersonality: outcomeData.landlord_personality,
                    strategiesUsed: outcomeData.strategies_used,
                    successFactors: outcomeData.success_factors,
                    
                    // Property context for learning
                    propertyType: negotiation.listingType || 'unknown',
                    location: negotiation.listingLocation || 'unknown',
                    priceRange: this.categorizePriceRange(outcomeData.original_price),
                    
                    // Conversation patterns
                    conversationFlow: this.analyzeConversationFlow(negotiation),
                    keyTurningPoints: this.identifyTurningPoints(negotiation),
                    
                    // AI performance metrics
                    aiResponseQuality: this.assessAIResponseQuality(negotiation),
                    promptOptimization: this.assessPromptPerformance(negotiation),
                    
                    // Learning optimization data
                    learningCategory: this.categorizeLearningData(outcomeData, negotiation),
                    trainingValue: this.calculateTrainingValue(outcomeData),
                    
                    // Timestamp for trend analysis
                    timestamp: new Date().toISOString(),
                    sessionId: negotiation.sessionId || `session_${Date.now()}`
                }
            };

            // Insert comprehensive conversation log
            const { data, error } = await this.supabase
                .from('ai_chats')
                .insert(conversationData);

            if (error) {
                console.error('❌ Error logging conversation to Supabase:', error);
                throw error;
            }

            console.log('✅ Comprehensive conversation logged to Supabase with learning metadata');
            
            // Also log individual messages for detailed analysis
            await this.logDetailedMessageHistory(negotiation, outcomeData.negotiation_id);
            
        } catch (error) {
            console.error('Error in comprehensive conversation logging:', error);
            // Don't throw - fallback to localStorage will handle it
        }
    }

    // Log detailed message history for analysis
    async logDetailedMessageHistory(negotiation, negotiationId) {
        try {
            if (!negotiation.messages || negotiation.messages.length === 0) return;

            console.log('📝 Logging detailed message history for analysis');
            
            // Create individual entries for each message exchange
            for (let i = 0; i < negotiation.messages.length; i++) {
                const message = negotiation.messages[i];
                const messageData = {
                    user_email: negotiation.userEmail,
                    conversation_data: JSON.stringify([{
                        role: message.sender === 'ai' ? 'assistant' : 'user',
                        content: message.content,
                        timestamp: message.timestamp || new Date().toISOString(),
                        messageIndex: i,
                        sender: message.sender
                    }]),
                    title: `Message ${i + 1}: ${negotiation.listingTitle}`,
                    metadata: {
                        negotiationId: negotiationId,
                        messageIndex: i,
                        sender: message.sender,
                        messageType: this.classifyMessageType(message.content),
                        priceOffered: this.extractPriceFromMessage(message.content),
                        sentiment: this.analyzeMessageSentiment(message.content),
                        strategy: this.identifyMessageStrategy(message.content),
                        timestamp: message.timestamp || new Date().toISOString()
                    }
                };

                await this.supabase.from('ai_chats').insert(messageData);
            }

            console.log('✅ Detailed message history logged');
        } catch (error) {
            console.error('Error logging detailed message history:', error);
        }
    }

    // Analyze conversation flow patterns
    analyzeConversationFlow(negotiation) {
        if (!negotiation.messages) return 'simple';
        
        const messageCount = negotiation.messages.length;
        const aiMessages = negotiation.messages.filter(m => m.sender === 'ai').length;
        const landlordMessages = negotiation.messages.filter(m => m.sender === 'landlord').length;
        
        if (messageCount <= 2) return 'quick_resolution';
        if (messageCount <= 5) return 'standard_negotiation';
        if (messageCount <= 10) return 'complex_negotiation';
        return 'extended_negotiation';
    }

    // Identify key turning points in conversation
    identifyTurningPoints(negotiation) {
        const turningPoints = [];
        
        if (!negotiation.messages) return turningPoints;
        
        negotiation.messages.forEach((message, index) => {
            const price = this.extractPriceFromMessage(message.content);
            if (price) {
                turningPoints.push({
                    messageIndex: index,
                    type: 'price_mention',
                    value: price,
                    sender: message.sender
                });
            }
            
            // Detect sentiment changes
            const sentiment = this.analyzeMessageSentiment(message.content);
            if (sentiment === 'positive' && index > 0) {
                turningPoints.push({
                    messageIndex: index,
                    type: 'sentiment_positive',
                    sender: message.sender
                });
            }
        });
        
        return turningPoints;
    }

    // Assess AI response quality for learning
    assessAIResponseQuality(negotiation) {
        if (!negotiation.messages) return 'unknown';
        
        const aiMessages = negotiation.messages.filter(m => m.sender === 'ai');
        if (aiMessages.length === 0) return 'no_ai_messages';
        
        // Simple quality assessment based on response patterns
        const hasVariety = new Set(aiMessages.map(m => m.content.substring(0, 20))).size > 1;
        const appropriateLength = aiMessages.every(m => m.content.length > 20 && m.content.length < 500);
        
        if (hasVariety && appropriateLength) return 'high';
        if (hasVariety || appropriateLength) return 'medium';
        return 'low';
    }

    // Assess prompt performance
    assessPromptPerformance(negotiation) {
        // This would analyze how well the AI prompts performed
        return {
            responseRelevance: 'high',
            contextAwareness: 'medium', 
            goalAlignment: 'high',
            creativityLevel: 'medium'
        };
    }

    // Categorize learning data
    categorizeLearningData(outcomeData, negotiation) {
        if (outcomeData.outcome === 'success') {
            if (outcomeData.message_count <= 3) return 'quick_success';
            if (outcomeData.final_price < outcomeData.original_price * 0.9) return 'high_savings_success';
            return 'standard_success';
        } else {
            if (outcomeData.message_count <= 2) return 'quick_rejection';
            if (outcomeData.message_count >= 5) return 'prolonged_failure';
            return 'standard_failure';
        }
    }

    // Calculate training value of this conversation
    calculateTrainingValue(outcomeData) {
        let value = 1;
        
        // Higher value for successful negotiations
        if (outcomeData.outcome === 'success') value *= 2;
        
        // Higher value for complex negotiations
        if (outcomeData.message_count >= 5) value *= 1.5;
        
        // Higher value if significant savings achieved
        const savingsPercent = ((outcomeData.original_price - outcomeData.final_price) / outcomeData.original_price) * 100;
        if (savingsPercent > 10) value *= 1.3;
        
        return Math.round(value * 10) / 10; // Round to 1 decimal
    }

    // Classify message type for analysis
    classifyMessageType(content) {
        const lower = content.toLowerCase();
        
        if (this.extractPriceFromMessage(content)) return 'price_offer';
        if (/accept|agree|deal|sure|yes|ok/i.test(lower)) return 'acceptance';
        if (/reject|no|too|expensive/i.test(lower)) return 'rejection';
        if (/counter|how about|what about/i.test(lower)) return 'counter_offer';
        if (/meet|when|time|tonight/i.test(lower)) return 'logistics';
        if (/deposit|payment|document/i.test(lower)) return 'financial_details';
        
        return 'general_communication';
    }

    // Analyze message sentiment
    analyzeMessageSentiment(content) {
        const lower = content.toLowerCase();
        
        const positiveWords = ['great', 'excellent', 'perfect', 'wonderful', 'agree', 'accept', 'yes', 'sure'];
        const negativeWords = ['no', 'reject', 'too', 'expensive', 'cannot', 'impossible'];
        
        const positiveScore = positiveWords.filter(word => lower.includes(word)).length;
        const negativeScore = negativeWords.filter(word => lower.includes(word)).length;
        
        if (positiveScore > negativeScore) return 'positive';
        if (negativeScore > positiveScore) return 'negative';
        return 'neutral';
    }

    // Identify message strategy
    identifyMessageStrategy(content) {
        const lower = content.toLowerCase();
        
        if (/market|comparable|average|data/i.test(lower)) return 'market_based';
        if (/reliable|tenant|references|quality/i.test(lower)) return 'value_proposition';
        if (/quick|immediate|today|asap/i.test(lower)) return 'urgency';
        if (/budget|afford|maximum/i.test(lower)) return 'budget_constraint';
        if (/final|last|best/i.test(lower)) return 'final_offer';
        
        return 'standard';
    }

    // Store negotiation outcome in localStorage as backup
    storeOutcomeLocally(outcomeData) {
        try {
            const existingOutcomes = JSON.parse(localStorage.getItem('negotiation_outcomes') || '[]');
            existingOutcomes.push(outcomeData);
            
            // Keep only last 50 outcomes
            if (existingOutcomes.length > 50) {
                existingOutcomes.splice(0, existingOutcomes.length - 50);
            }
            
            localStorage.setItem('negotiation_outcomes', JSON.stringify(existingOutcomes));
            console.log('💾 Outcome stored locally as backup');
        } catch (error) {
            console.error('Error storing outcome locally:', error);
        }
    }

    // Analyze factors that contributed to success or failure
    analyzeSuccessFactors(negotiation, outcome, finalPrice) {
        const factors = {
            price_reduction_achieved: null,
            percentage_saved: null,
            market_leverage_utilized: false,
            personality_adaptation: false,
            timing_factors: [],
            strategy_effectiveness: {},
            communication_style: null
        };
        
        if (outcome === 'success' && finalPrice && negotiation.originalPrice) {
            factors.price_reduction_achieved = negotiation.originalPrice - finalPrice;
            factors.percentage_saved = ((negotiation.originalPrice - finalPrice) / negotiation.originalPrice * 100).toFixed(2);
        }
        
        // Analyze market leverage usage
        if (negotiation.dynamicMarketData?.negotiationLeverage === 'high') {
            factors.market_leverage_utilized = true;
            factors.timing_factors.push('favorable_market_conditions');
        }
        
        // Check if seasonal timing was beneficial
        const seasonalFactor = negotiation.dynamicMarketData?.seasonalFactor || 1;
        if (seasonalFactor < 1.0) {
            factors.timing_factors.push('off_season_advantage');
        }
        
        // Analyze personality adaptation
        if (negotiation.landlordPersonality && negotiation.strategiesUsed?.length > 0) {
            factors.personality_adaptation = true;
            factors.communication_style = negotiation.landlordPersonality.communicationStyle;
        }
        
        // Strategy effectiveness analysis
        if (negotiation.strategiesUsed) {
            negotiation.strategiesUsed.forEach(strategy => {
                factors.strategy_effectiveness[strategy] = outcome === 'success' ? 'effective' : 'ineffective';
            });
        }
        
        return factors;
    }

    // Update the learning model based on negotiation outcomes
    async updateLearningModel(outcomeData) {
        try {
            console.log('🧠 Updating learning model with new outcome data');
            
            // Get recent outcomes for pattern analysis
            const recentOutcomes = await this.getRecentNegotiationOutcomes();
            
            // Analyze patterns and update strategies
            const patterns = this.analyzeNegotiationPatterns(recentOutcomes);
            
            // Store learning insights
            const learningUpdate = {
                timestamp: new Date().toISOString(),
                patterns_analyzed: patterns,
                sample_size: recentOutcomes.length,
                success_rate: this.calculateSuccessRate(recentOutcomes),
                most_effective_strategies: this.identifyEffectiveStrategies(recentOutcomes),
                market_insights: this.extractMarketInsights(recentOutcomes),
                personality_insights: this.extractPersonalityInsights(recentOutcomes)
            };
            
            // Store learning data
            localStorage.setItem('negotiation_learning_model', JSON.stringify(learningUpdate));
            console.log('✅ Learning model updated');
            
        } catch (error) {
            console.error('Error updating learning model:', error);
        }
    }

    // Get recent negotiation outcomes for analysis
    async getRecentNegotiationOutcomes() {
        try {
            // Database disabled - use localStorage only
            // const { data: dbOutcomes } = await this.supabase
            //     .from('negotiation_outcomes')
            //     .select('*')
            //     .gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
            //     .order('created_at', { ascending: false })
            //     .limit(100);
            
            // Use localStorage data
            const localOutcomes = JSON.parse(localStorage.getItem('negotiation_outcomes') || '[]');
            return localOutcomes.slice(-30); // Last 30 outcomes
            
        } catch (error) {
            console.error('Error getting recent outcomes:', error);
            return [];
        }
    }

    // Analyze patterns in negotiation outcomes
    analyzeNegotiationPatterns(outcomes) {
        const patterns = {
            success_by_property_type: {},
            success_by_price_range: {},
            success_by_season: {},
            success_by_message_count: {},
            average_negotiation_duration: 0,
            most_effective_strategies: []
        };
        
        if (!outcomes.length) return patterns;
        
        outcomes.forEach(outcome => {
            // Property type analysis
            const propType = outcome.listing_type || 'unknown';
            if (!patterns.success_by_property_type[propType]) {
                patterns.success_by_property_type[propType] = { success: 0, total: 0 };
            }
            patterns.success_by_property_type[propType].total++;
            if (outcome.outcome === 'success') {
                patterns.success_by_property_type[propType].success++;
            }
            
            // Price range analysis
            const priceRange = this.categorizePriceRange(outcome.original_price);
            if (!patterns.success_by_price_range[priceRange]) {
                patterns.success_by_price_range[priceRange] = { success: 0, total: 0 };
            }
            patterns.success_by_price_range[priceRange].total++;
            if (outcome.outcome === 'success') {
                patterns.success_by_price_range[priceRange].success++;
            }
            
            // Duration analysis
            if (outcome.negotiation_duration) {
                patterns.average_negotiation_duration += outcome.negotiation_duration;
            }
        });
        
        patterns.average_negotiation_duration /= outcomes.length;
        
        return patterns;
    }

    // Calculate overall success rate
    calculateSuccessRate(outcomes) {
        if (!outcomes.length) return 0;
        const successCount = outcomes.filter(o => o.outcome === 'success').length;
        return ((successCount / outcomes.length) * 100).toFixed(2);
    }

    // Identify most effective negotiation strategies
    identifyEffectiveStrategies(outcomes) {
        const strategySuccess = {};
        
        outcomes.forEach(outcome => {
            if (outcome.strategies_used && Array.isArray(outcome.strategies_used)) {
                outcome.strategies_used.forEach(strategy => {
                    if (!strategySuccess[strategy]) {
                        strategySuccess[strategy] = { success: 0, total: 0 };
                    }
                    strategySuccess[strategy].total++;
                    if (outcome.outcome === 'success') {
                        strategySuccess[strategy].success++;
                    }
                });
            }
        });
        
        // Calculate success rates and sort
        return Object.entries(strategySuccess)
            .map(([strategy, stats]) => ({
                strategy,
                success_rate: (stats.success / stats.total * 100).toFixed(2),
                sample_size: stats.total
            }))
            .sort((a, b) => parseFloat(b.success_rate) - parseFloat(a.success_rate))
            .slice(0, 5); // Top 5 strategies
    }

    // Extract market insights from outcomes
    extractMarketInsights(outcomes) {
        const insights = {
            best_negotiation_months: [],
            price_flexibility_by_location: {},
            demand_correlation: {}
        };
        
        outcomes.forEach(outcome => {
            if (outcome.created_at && outcome.outcome === 'success') {
                const month = new Date(outcome.created_at).getMonth() + 1;
                insights.best_negotiation_months.push(month);
            }
        });
        
        return insights;
    }

    // Extract personality-based insights
    extractPersonalityInsights(outcomes) {
        const insights = {
            most_responsive_personalities: [],
            communication_preferences: {},
            success_by_personality_type: {}
        };
        
        outcomes.forEach(outcome => {
            if (outcome.landlord_personality) {
                const personalityType = outcome.landlord_personality.type;
                if (!insights.success_by_personality_type[personalityType]) {
                    insights.success_by_personality_type[personalityType] = { success: 0, total: 0 };
                }
                insights.success_by_personality_type[personalityType].total++;
                if (outcome.outcome === 'success') {
                    insights.success_by_personality_type[personalityType].success++;
                }
            }
        });
        
        return insights;
    }

    // Categorize price range for analysis
    categorizePriceRange(price) {
        if (price < 800) return 'budget';
        if (price < 1200) return 'mid_range';
        if (price < 1800) return 'premium';
        return 'luxury';
    }

    // Get learning-based strategy recommendations
    async getStrategyRecommendations(listing, userBudget, marketData) {
        try {
            const learningModel = JSON.parse(localStorage.getItem('negotiation_learning_model') || '{}');
            
            if (!learningModel.most_effective_strategies) {
                return ['balanced_persuasion', 'market_data', 'value_proposition'];
            }
            
            // Filter strategies based on current context
            const priceRange = this.categorizePriceRange(listing.price);
            const recommendations = learningModel.most_effective_strategies
                .filter(strategy => parseFloat(strategy.success_rate) > 60)
                .map(strategy => strategy.strategy)
                .slice(0, 3);
            
            return recommendations.length > 0 ? recommendations : ['balanced_persuasion', 'market_data'];
            
        } catch (error) {
            console.error('Error getting strategy recommendations:', error);
            return ['balanced_persuasion', 'market_data'];
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

    // Detect landlord personality from communication patterns
    detectLandlordPersonality(replyContent, negotiation) {
        const reply = replyContent.toLowerCase();
        const allMessages = negotiation.messages.filter(m => m.sender === 'landlord').map(m => m.content.toLowerCase());
        const fullConversation = allMessages.join(' ') + ' ' + reply;
        
        let personality = {
            type: 'neutral',
            traits: [],
            communicationStyle: 'formal',
            flexibility: 'medium',
            emotionalState: 'neutral'
        };
        
        // Analyze communication style
        if (/lol|haha|😂|😄|casual|btw|omg/i.test(fullConversation)) {
            personality.communicationStyle = 'casual';
            personality.traits.push('informal');
        } else if (/sir|madam|please|thank you|regards|sincerely/i.test(fullConversation)) {
            personality.communicationStyle = 'formal';
            personality.traits.push('professional');
        }
        
        // Analyze flexibility
        if (/not flexible|no negotiation|firm|final|non-negotiable|take it or leave it/i.test(fullConversation)) {
            personality.flexibility = 'low';
            personality.type = 'rigid';
            personality.traits.push('inflexible');
        } else if (/flexible|negotiable|discuss|consider|maybe|depends/i.test(fullConversation)) {
            personality.flexibility = 'high';
            personality.type = 'collaborative';
            personality.traits.push('accommodating');
        }
        
        // Analyze emotional state
        if (/annoyed|frustrated|tired|everyone says that|heard it all/i.test(reply)) {
            personality.emotionalState = 'frustrated';
            personality.traits.push('skeptical');
        } else if (/interested|sounds good|like that|appreciate/i.test(reply)) {
            personality.emotionalState = 'positive';
            personality.traits.push('receptive');
        }
        
        // Detect negotiation experience
        if (/everyone says|heard that before|typical|usual|standard/i.test(reply)) {
            personality.traits.push('experienced');
        }
        
        console.log('🧠 Detected landlord personality:', personality);
        return personality;
    }
    
    // Detect emotional state from recent message
    detectEmotionalState(replyContent) {
        const reply = replyContent.toLowerCase();
        
        if (/lol|haha|great|excellent|perfect|love it/i.test(reply)) {
            return 'positive';
        } else if (/frustrated|annoyed|tired|sick of|enough/i.test(reply)) {
            return 'negative';
        } else if (/maybe|consider|think about|possibly/i.test(reply)) {
            return 'contemplative';
        } else if (/busy|quick|hurry|time/i.test(reply)) {
            return 'rushed';
        }
        
        return 'neutral';
    }
    
    // Analyze negotiation context and history
    analyzeNegotiationContext(negotiation) {
        return {
            roundsOfNegotiation: negotiation.messages.filter(m => m.sender === 'ai').length,
            priceReductions: this.calculatePriceReductions(negotiation),
            timeElapsed: Date.now() - new Date(negotiation.startTime).getTime(),
            marketPosition: this.assessMarketPosition(negotiation),
            userFlexibility: this.assessUserFlexibility(negotiation)
        };
    }
    
    // Calculate how much the price has been reduced
    calculatePriceReductions(negotiation) {
        const originalPrice = negotiation.originalPrice;
        const currentOffer = this.extractLastOfferedPrice(negotiation);
        const reduction = originalPrice - currentOffer;
        const percentageReduction = (reduction / originalPrice) * 100;
        
        return {
            absolute: reduction,
            percentage: Math.round(percentageReduction * 100) / 100,
            significant: percentageReduction > 10
        };
    }
    
    // Assess market position
    assessMarketPosition(negotiation) {
        if (!negotiation.marketData) return 'unknown';
        
        const originalPrice = negotiation.originalPrice;
        const marketAverage = negotiation.marketData.average;
        
        if (originalPrice > marketAverage * 1.2) return 'overpriced';
        if (originalPrice < marketAverage * 0.8) return 'underpriced';
        return 'market_rate';
    }
    
    // Assess user's flexibility
    assessUserFlexibility(negotiation) {
        const budgetFlexibility = (negotiation.userBudget / negotiation.originalPrice) * 100;
        
        if (budgetFlexibility > 90) return 'high';
        if (budgetFlexibility > 70) return 'medium';
        return 'low';
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

    // Generate security deposit response
    generateSecurityDepositResponse(finalPrice, negotiationId, roundNumber) {
        // CRITICAL: Ensure finalPrice is never null/undefined/0
        if (!finalPrice || finalPrice <= 0) {
            console.error('❌ CRITICAL: Invalid finalPrice in security deposit:', finalPrice);
            // Get negotiation to access fallback prices
            const negotiation = this.activeNegotiations.get(negotiationId);
            finalPrice = negotiation?.userBudget || 1500; // Safe fallback
            console.log('✅ Using fallback price for security deposit:', finalPrice);
        }
        
        const templates = this.responseTemplates.securityDepositResponses;
        const responseIndex = roundNumber % templates.length;
        let response = templates[responseIndex];
        
        // Replace price placeholder
        response = response.replace(/\$\$\{price\}/g, finalPrice);
        
        return this.formatMessage(response);
    }

    // Generate move-in logistics response  
    generateMoveInLogisticsResponse(negotiationId, roundNumber) {
        const templates = this.responseTemplates.moveInLogistics;
        const responseIndex = roundNumber % templates.length;
        
        return this.formatMessage(templates[responseIndex]);
    }

    // Generate response to increase requests like "can you raise it"
    generateIncreaseRequestResponse(negotiation, listing, negotiationId, roundNumber) {
        let lastOffer = this.extractLastOfferedPrice(negotiation);
        
        // CRITICAL: Ensure lastOffer is never null/undefined/0
        if (!lastOffer || lastOffer <= 0) {
            console.error('❌ CRITICAL: Invalid lastOffer in increase request, using fallback');
            lastOffer = negotiation.userBudget || listing?.price || 1500;
            console.log('✅ Using fallback price for increase request:', lastOffer);
        }
        
        const userBudget = negotiation.userBudget;
        
        // Calculate a reasonable increase
        const increaseAmount = Math.min(
            userBudget - lastOffer,
            Math.round(lastOffer * 0.03) // 3% increase
        );
        const newOffer = Math.min(userBudget, lastOffer + increaseAmount);
        
        const increaseResponses = [
            `Of course! I can go up to $${newOffer}/month. Would that work for you?`,
            `Absolutely! I can increase my offer to $${newOffer}/month. Is that more in line with what you're looking for?`,
            `Sure thing! How about $${newOffer}/month? I'm flexible and want to make this work.`,
            `Yes, I can do $${newOffer}/month. That's getting close to my maximum but I really like the place.`,
            `I can bump it up to $${newOffer}/month. Would that be acceptable?`,
            `Definitely! I can raise it to $${newOffer}/month. I'm committed to making this work.`
        ];
        
        const responseIndex = roundNumber % increaseResponses.length;
        return this.formatMessage(increaseResponses[responseIndex]);
    }

    // Generate clarification request for vague responses
    generateVagueClarificationResponse(negotiation, listing, negotiationId, roundNumber) {
        let lastOffer = this.extractLastOfferedPrice(negotiation);
        
        // CRITICAL: Ensure lastOffer is never null/undefined/0
        if (!lastOffer || lastOffer <= 0) {
            console.error('❌ CRITICAL: Invalid lastOffer in vague clarification, using fallback');
            lastOffer = negotiation.userBudget || listing?.price || 1500;
            console.log('✅ Using fallback price for vague clarification:', lastOffer);
        }
        
        const clarificationResponses = [
            `I appreciate your response! Just to clarify - what specific price would work for you? I offered $${lastOffer}/month.`,
            `Thanks for considering it! Could you let me know what amount you'd be comfortable with? My last offer was $${lastOffer}/month.`,
            `I want to make sure I understand correctly - are you open to my $${lastOffer}/month offer, or did you have a different amount in mind?`,
            `I'd love to work something out! What price range were you thinking? I proposed $${lastOffer}/month.`,
            `Great to hear you're interested! Could you specify what rent amount would work for you? I suggested $${lastOffer}/month.`,
            `I'm glad you're considering it! What would be a good monthly rent from your perspective? I offered $${lastOffer}/month.`
        ];
        
        const responseIndex = roundNumber % clarificationResponses.length;
        return this.formatMessage(clarificationResponses[responseIndex]);
    }

    // Extract price from any message format
    extractPriceFromMessage(message) {
        const pricePatterns = [
            /\$(\d+)/,           // $1340
            /(\d+)\s*dollars?/i, // 1340 dollars
            /(\d+)\s*\/month/i,  // 1340/month
            /(\d+)\s*per month/i, // 1340 per month
            /(\d+)month/i,       // 3000month (no space)
            /(\d+)\s*month/i     // 3000 month (with space)
        ];
        
        for (const pattern of pricePatterns) {
            const match = message.match(pattern);
            if (match) {
                return parseInt(match[1]);
            }
        }
        return null;
    }

    // AI Learning System Integration Methods
    async buildLearningContext(strategyType, negotiation, listing) {
        try {
            const context = {
                strategyType: strategyType,
                landlordPersonality: negotiation?.landlordPersonality || 'unknown',
                marketConditions: {
                    competitiveness: 'medium',
                    marketTrend: 'stable',
                    pricePosition: 'market_rate'
                },
                priceRange: this.determinePriceRange(listing, negotiation),
                negotiationStage: this.determineNegotiationStage(negotiation),
                timeContext: this.getTimeContext()
            };

            // Enhance with market data if available
            if (this.marketData.has(listing?.id)) {
                const marketInfo = this.marketData.get(listing.id);
                context.marketConditions = this.analyzeMarketConditions(listing, marketInfo);
            }

            return context;
        } catch (error) {
            console.error('Failed to build learning context:', error);
            // Return basic context as fallback
            return {
                strategyType: strategyType,
                landlordPersonality: 'unknown',
                marketConditions: { competitiveness: 'medium' },
                priceRange: 'moderate'
            };
        }
    }

    async recordNegotiationOutcome(conversationId, success, finalPrice, templateUsed, strategyType) {
        if (!this.learningEnabled) return;

        try {
            const negotiation = this.activeNegotiations.get(conversationId);
            if (!negotiation) return;

            const conversationData = {
                id: conversationId,
                messages: negotiation.messageHistory || [],
                success: success,
                finalPrice: finalPrice,
                initialPrice: negotiation.userBudget || 0,
                templateUsed: templateUsed,
                strategyType: strategyType,
                created_at: new Date().toISOString()
            };

            if (this.learningSystem) {
                await this.learningSystem.processConversation(conversationData);
                console.log('✅ Recorded negotiation outcome for learning system');
            }
        } catch (error) {
            console.error('❌ Failed to record negotiation outcome:', error);
        }
    }

    determinePriceRange(listing, negotiation) {
        const price = negotiation?.userBudget || listing?.price || 0;
        
        if (price < 1000) return 'budget';
        if (price < 2000) return 'moderate';
        if (price < 3000) return 'premium';
        return 'luxury';
    }

    determineNegotiationStage(negotiation) {
        if (!negotiation?.messageHistory) return 'initial';
        
        const messageCount = negotiation.messageHistory.length;
        if (messageCount <= 2) return 'initial_contact';
        if (messageCount <= 5) return 'exploration';
        if (messageCount <= 10) return 'active_negotiation';
        return 'closing';
    }

    analyzeMarketConditions(listing, marketInfo) {
        const listingPrice = listing?.price || 0;
        const marketAvg = marketInfo?.averagePrice || listingPrice;
        
        let competitiveness = 'medium';
        if (listingPrice > marketAvg * 1.2) {
            competitiveness = 'low'; // Overpriced, less competitive
        } else if (listingPrice < marketAvg * 0.8) {
            competitiveness = 'high'; // Underpriced, very competitive
        }

        return {
            competitiveness: competitiveness,
            marketTrend: marketInfo?.trend || 'stable',
            pricePosition: listingPrice > marketAvg ? 'above_market' : 'below_market'
        };
    }

    getTimeContext() {
        const now = new Date();
        const hour = now.getHours();
        const isWeekend = now.getDay() === 0 || now.getDay() === 6;
        
        return {
            hour: hour,
            isWeekend: isWeekend,
            isBusinessHours: hour >= 9 && hour <= 17 && !isWeekend
        };
    }

    // Enhanced template selection for other strategies
    async selectTemplateWithLearning(strategyType, templates, negotiation, listing) {
        if (!this.learningEnabled) {
            // Fallback to random selection
            return templates[Math.floor(Math.random() * templates.length)];
        }

        try {
            if (this.learningSystem) {
                const context = await this.buildLearningContext(strategyType, negotiation, listing);
                const optimalTemplate = await this.learningSystem.getOptimalTemplate(context);
                
                if (optimalTemplate && optimalTemplate.templateId) {
                    console.log(`🧠 Learning system selected template ${optimalTemplate.templateId} for ${strategyType}: ${optimalTemplate.reason}`);
                    return templates[optimalTemplate.templateId] || templates[0];
                }
            }
            
            // Fallback to random selection if learning system not available
            return templates[Math.floor(Math.random() * templates.length)];
        } catch (error) {
            console.error(`❌ Template selection failed for ${strategyType}, using random:`, error);
            return templates[Math.floor(Math.random() * templates.length)];
        }
    }

    // Method to get learning system performance metrics
    async getLearningMetrics() {
        if (!this.learningEnabled) return null;

        try {
            if (this.learningSystem) {
                return await this.learningSystem.getPerformanceMetrics();
            } else {
                return { enabled: false, message: 'Learning system not available' };
            }
        } catch (error) {
            console.error('Failed to get learning metrics:', error);
            return null;
        }
    }

    // Method to trigger learning system optimization
    async optimizeLearningSystem() {
        if (!this.learningEnabled) return;

        try {
            if (this.learningSystem) {
                const result = await this.learningSystem.updateLearning();
                console.log('🔄 Learning system optimization completed:', result);
                return result;
            } else {
                console.log('ℹ️ Learning system not available for optimization');
                return { enabled: false };
            }
        } catch (error) {
            console.error('Learning system optimization failed:', error);
        }
    }

    // Toggle learning system on/off
    toggleLearningSystem(enabled) {
        this.learningEnabled = enabled;
        console.log(`🧠 Learning system ${enabled ? 'ENABLED' : 'DISABLED'}`);
    }

    // Initialize dashboard integration capabilities
    initializeDashboardIntegration() {
        return {
            analyticsEndpoints: {
                negotiationMetrics: '/api/negotiations/metrics',
                personalityAnalysis: '/api/negotiations/personalities',
                conversionRates: '/api/negotiations/conversions',
                marketInsights: '/api/negotiations/market-insights'
            },
            dashboardWidgets: {
                activeNegotiations: this.getActiveNegotiationsWidget.bind(this),
                personalityBreakdown: this.getPersonalityBreakdownWidget.bind(this),
                conversionFunnel: this.getConversionFunnelWidget.bind(this),
                marketTrends: this.getMarketTrendsWidget.bind(this)
            },
            realTimeUpdates: true
        };
    }

    // Get active negotiations widget data
    async getActiveNegotiationsWidget() {
        try {
            const activeNegotiations = Array.from(this.activeNegotiations.values());
            const conversationStates = Array.from(this.conversationStates.values());
            
            return {
                title: 'Active Negotiations',
                type: 'metric_cards',
                data: {
                    total: activeNegotiations.length,
                    byPhase: this.groupByPhase(conversationStates),
                    recentActivity: await this.getRecentNegotiationActivity(),
                    successRate: await this.calculateCurrentSuccessRate()
                }
            };
        } catch (error) {
            console.error('Error getting active negotiations widget:', error);
            return { title: 'Active Negotiations', type: 'error', data: null };
        }
    }

    // Dashboard API endpoint for getting widget data
    async getDashboardData(widgetType) {
        const widgets = this.dashboardIntegration.dashboardWidgets;
        
        if (widgets[widgetType]) {
            return await widgets[widgetType]();
        }
        
        throw new Error(`Unknown widget type: ${widgetType}`);
    }

    // Helper method to group conversation states by phase
    groupByPhase(conversationStates) {
        const phaseGroups = {};
        conversationStates.forEach(state => {
            const phase = state.phase || 'unknown';
            phaseGroups[phase] = (phaseGroups[phase] || 0) + 1;
        });
        return phaseGroups;
    }

    // Get recent negotiation activity for dashboard
    async getRecentNegotiationActivity() {
        try {
            if (!this.supabase) return [];
            
            const { data, error } = await this.supabase
                .from('ai_chats')
                .select('title, created_at, metadata')
                .contains('metadata', { source: 'personality_aware_negotiation' })
                .order('created_at', { ascending: false })
                .limit(5);
                
            if (error) return [];
            
            return data.map(chat => ({
                title: chat.title,
                timestamp: chat.created_at,
                phase: chat.metadata?.conversationPhase || 'unknown',
                personality: chat.metadata?.landlordPersonality || 'unknown'
            }));
        } catch (error) {
            console.error('Error getting recent activity:', error);
            return [];
        }
    }

    // Calculate current success rate for dashboard
    async calculateCurrentSuccessRate() {
        try {
            if (!this.supabase) return 0;
            
            const { data, error } = await this.supabase
                .from('ai_chats')
                .select('metadata')
                .contains('metadata', { source: 'personality_aware_negotiation' })
                .gte('created_at', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString());
                
            if (error || !data) return 0;
            
            const completed = data.filter(chat => 
                chat.metadata?.conversationPhase === 'rental_complete'
            ).length;
            
            return data.length > 0 ? Math.round((completed / data.length) * 100) : 0;
        } catch (error) {
            console.error('Error calculating success rate:', error);
            return 0;
        }
    }

    // Real-time updates for dashboard integration
    async broadcastNegotiationUpdate(negotiationId, update) {
        try {
            const updateData = {
                type: 'negotiation_update',
                negotiationId: negotiationId,
                timestamp: new Date().toISOString(),
                data: update
            };
            
            console.log('📡 Broadcasting dashboard update:', updateData);
            
            // In production, this would integrate with WebSockets or SSE
            if (typeof window !== 'undefined' && window.dashboardUpdateCallback) {
                window.dashboardUpdateCallback(updateData);
            }
        } catch (error) {
            console.error('Error broadcasting dashboard update:', error);
        }
    }
}

// Export for use
window.AINegotiationEngine = AINegotiationEngine;