 // AI Negotiation Engine
// Handles real-time negotiation with landlords using market data and OpenAI

class AINegotiator {
    constructor(supabase, config) {
        this.supabase = supabase;
        this.config = config;
        this.activeNegotiations = new Map(); // Track ongoing negotiations
        this.marketData = new Map(); // Cache market data
        this.aiUserInitialized = false;
        this.rentcastApiKey = null; // RentCast calls now proxied through backend
        this.rentcastCache = new Map(); // Cache RentCast results per negotiation
        this.conversationStates = new Map(); // Track conversation phases per negotiation
        this.init();
    }

    // ========================================
    // HUMAN-LIKE CONVERSATION PHASE SYSTEM
    // ========================================

    // Single source of truth for closing signals. Used by both
    // detectPhaseTransition (landlord-side detection) and the post-response
    // check (AI-side detection: if the AI itself just said "YES. Deal." we
    // lock CLOSING so the next turn doesn't drift back into discovery
    // questions). Expanding this regex was the fix for the "ok deal → AI
    // asked about the neighborhood" bug.
    CLOSING_SIGNALS_RE = /\b(meet|deposit|sign|lease|tomorrow|address|move in|done deal|call it (a )?day|when can you|let.?s do it|i.?ll take it|we.?ll take it|deal|agreed|sold|sounds good|works for me|that works|fine by me|happy with that)\b/i;

    // Conversation phases - mimics natural human-to-landlord flow
    CONVERSATION_PHASES = {
        INTRODUCTION: {
            name: 'INTRODUCTION',
            order: 1,
            minMessages: 1,
            maxMessages: 1,
            description: 'First contact - greeting and interest',
            noPricing: true
        },
        RAPPORT_BUILDING: {
            name: 'RAPPORT_BUILDING',
            order: 2,
            minMessages: 1,
            maxMessages: 2,
            description: 'Ask about property, show interest',
            noPricing: true
        },
        QUALIFICATION: {
            name: 'QUALIFICATION',
            order: 3,
            minMessages: 1,
            maxMessages: 2,
            description: 'Share tenant background naturally',
            noPricing: true
        },
        AVAILABILITY_DISCUSSION: {
            name: 'AVAILABILITY_DISCUSSION',
            order: 4,
            minMessages: 1,
            maxMessages: 1,
            description: 'Discuss move-in, lease terms',
            noPricing: false // Can mention if asked
        },
        PRICE_INTRODUCTION: {
            name: 'PRICE_INTRODUCTION',
            order: 5,
            minMessages: 1,
            maxMessages: 1,
            description: 'Bring up budget naturally',
            noPricing: false
        },
        ACTIVE_NEGOTIATION: {
            name: 'ACTIVE_NEGOTIATION',
            order: 6,
            minMessages: 1,
            maxMessages: 10,
            description: 'Actual price negotiation',
            noPricing: false
        },
        // Terminal lock. Entered when the landlord signals readiness to close
        // ("meet", "deposit", "sign", "tomorrow"...). Once here, the AI is
        // forbidden from asking new discovery questions or pitching credentials
        // again — see detectPhaseTransition + validateAndRepair.
        CLOSING: {
            name: 'CLOSING',
            order: 7,
            minMessages: 1,
            maxMessages: 99,
            description: 'Landlord ready to sign — confirm/schedule only',
            noPricing: false
        }
    };

    // Initialize conversation state for a new negotiation
    initConversationState(negotiationId, listing, userBudget, userEmail) {
        const state = {
            negotiationId: negotiationId,
            currentPhase: 'INTRODUCTION',
            phaseMessageCount: 0,
            totalMessageCount: 0,
            listing: listing,
            userBudget: userBudget,
            userEmail: userEmail,
            userName: null, // Will be set from user profile
            messageHistory: [],
            phaseHistory: ['INTRODUCTION'],
            landlordResponses: [],
            lastLandlordMessage: null,
            currentOffer: null,
            landlordCounterOffer: null,
            agreedPrice: null,
            propertyFeature: this.extractPropertyFeature(listing),
            // --- Phase-locked emotional engine state ---
            // Tone tracks the landlord's mood. NEUTRAL by default. Goes
            // FRUSTRATED on hostility keywords and is STICKY (doesn't unset
            // just because the landlord typed one calm word in between).
            tone: 'NEUTRAL',
            // facts: monotonically-growing structured memory. Once we set a
            // field from a landlord answer, we never overwrite it back to null,
            // so the AI literally cannot "forget" and re-ask.
            facts: {
                listing_held_months: null,    // e.g. "4 months" -> 4
                deposit_amount: null,         // numeric
                proposed_meet_date: null,     // "tomorrow", "saturday", etc.
                has_laundry: null,            // null = unknown, true/false = answered
                has_parking: null,
                pets_allowed: null,
                landlord_said_yes_to_meet: false,
                landlord_offered_closing: false,
                landlord_last_named_price: null,  // most recent $X landlord mentioned
                agreed_price: null               // set on numeric convergence
            },
            // alreadyAsked: simple set of topic keys we've already asked about.
            // The system prompt sees this and is instructed to NOT repeat.
            alreadyAsked: new Set(),
            // alreadySharedCredentials: once we've pitched "stable job,
            // landlord can vouch" once, never again.
            alreadySharedCredentials: false
        };
        this.conversationStates.set(negotiationId, state);
        return state;
    }

    // ===== Phase-locked emotional engine helpers =====

    // Pure local extraction (no LLM call). Reads a landlord message and
    // monotonically updates the facts object. Once a fact is set, this never
    // overwrites it back to null — so the AI can't undo what it already knows.
    extractFactsFromLandlordMessage(text, facts) {
        if (!text || !facts) return;
        const t = String(text).toLowerCase();

        // Duration: "4 months", "for 6 months", "4 mionths" (typo-tolerant via simple digit+word)
        const monthsMatch = t.match(/(\d+)\s*m[io]+nth/);
        if (monthsMatch && facts.listing_held_months == null) {
            facts.listing_held_months = parseInt(monthsMatch[1], 10);
        }

        // Laundry: explicit yes/no signals
        if (facts.has_laundry == null) {
            if (/(laundry|washer|wash[\/ ]?dry|dryer)\b.*(yes|available|in[- ]?unit|on site|onsite|there is|we have)/i.test(text)
                || /(yes|available|in[- ]?unit|on site|onsite|there is|we have).*(laundry|washer)/i.test(text)
                || /\blaundry\b/i.test(t) && /\b(is|available|yes|yep|yeah|sure)\b/i.test(t)) {
                facts.has_laundry = true;
            } else if (/no\s+laundry|laundry.*not|don.?t have laundry/i.test(t)) {
                facts.has_laundry = false;
            }
        }

        // Parking
        if (facts.has_parking == null) {
            if (/\b(parking|garage|spot)\b.*\b(yes|available|included|free|on[- ]?site|yep|yeah)\b/i.test(t)) {
                facts.has_parking = true;
            } else if (/no\s+parking|parking.*not|don.?t have parking/i.test(t)) {
                facts.has_parking = false;
            }
        }

        // Pets
        if (facts.pets_allowed == null) {
            if (/\b(pet|dog|cat)s?\s+(are\s+)?(ok|fine|allowed|welcome|yes)\b/i.test(t)) {
                facts.pets_allowed = true;
            } else if (/no\s+pets?|pets?.*not allowed/i.test(t)) {
                facts.pets_allowed = false;
            }
        }

        // Closing signals — landlord proposes meet/deposit/etc.
        const meetDate = t.match(/\b(tomorrow|today|tonight|monday|tuesday|wednesday|thursday|friday|saturday|sunday|next week|this week|this weekend)\b/);
        if (meetDate && !facts.proposed_meet_date) {
            facts.proposed_meet_date = meetDate[1];
        }
        if (/\b(meet|see you|come by|stop by|swing by)\b/i.test(t)) {
            facts.landlord_offered_closing = true;
        }
        if (/\b(deposit|sign|lease|done deal|call it (a )?day|when can you|move in)\b/i.test(t)) {
            facts.landlord_offered_closing = true;
        }

        // Deposit amount
        const dep = t.match(/\$(\d{2,5})/);
        if (dep && /deposit/.test(t) && !facts.deposit_amount) {
            facts.deposit_amount = parseInt(dep[1], 10);
        }

        // Landlord's most recent named price (for numeric convergence on close).
        // Captures "$5600", "5,600", "5600 a month", etc. Bounded to plausible
        // monthly rent range so we don't trip on "I've lived here 4 months".
        const priceMatches = text.match(/\$?\s*(\d{1,3}(?:[,]\d{3})+|\d{3,5})(?:\.\d{1,2})?/g);
        if (priceMatches) {
            for (const raw of priceMatches) {
                const n = parseFloat(raw.replace(/[$,\s]/g, ''));
                if (n >= 500 && n <= 50000) {
                    facts.landlord_last_named_price = n;
                    break; // first plausible number wins
                }
            }
        }
    }

    // Returns flags for tone classification + closing detection. Independent
    // of facts so the prompt builder can switch shape on these without
    // needing to inspect facts.
    extractIntentFromLandlordMessage(text) {
        const t = String(text || '').toLowerCase();
        const closing = this.CLOSING_SIGNALS_RE.test(t);
        const frustrated = /(idgaf|wtf|stop|yes or no|just (say|tell)|\bfuck|done with|annoying|stop asking)/i.test(t);
        return { closing, frustrated };
    }

    // Post-OpenAI safety net. The prompt does the heavy lifting; this validator
    // catches model violations (trailing questions in CLOSING, emojis when
    // landlord is hostile) and either trims or hard-replaces with a sane fallback.
    validateAndRepair(rawResponse, { phase, tone, facts }) {
        if (!rawResponse) return rawResponse;
        let out = String(rawResponse).trim();

        if (phase === 'CLOSING') {
            const hasQuestion = /\?/.test(out);
            if (hasQuestion) {
                console.warn('🛡️ Validator: AI emitted question(s) in CLOSING. Replacing with fallback.');
                return facts?.proposed_meet_date
                    ? `Yes, that works. See you ${facts.proposed_meet_date}.`
                    : `Yes, that works. See you then.`;
            }
            const words = out.split(/\s+/);
            if (words.length > 15) {
                console.warn('🛡️ Validator: AI exceeded 15-word cap in CLOSING. Truncating.');
                return words.slice(0, 12).join(' ').replace(/[.!?,]*$/, '') + '.';
            }
        }

        if (tone === 'FRUSTRATED') {
            // Strip all emoji ranges
            out = out.replace(/[\u{1F300}-\u{1FAFF}\u{1F600}-\u{1F64F}\u{1F900}-\u{1F9FF}]/gu, '').trim();
            const words = out.split(/\s+/);
            if (words.length > 15 || /\?/.test(out)) {
                console.warn('🛡️ Validator: AI rambled or asked questions during FRUSTRATED tone. Replacing with damage-control fallback.');
                return `Sorry about that. I'm in — let's meet.`;
            }
        }

        return out;
    }

    // Get conversation state
    getConversationState(negotiationId) {
        return this.conversationStates.get(negotiationId);
    }

    // Update conversation state
    updateConversationState(negotiationId, updates) {
        const state = this.conversationStates.get(negotiationId);
        if (state) {
            Object.assign(state, updates);
            this.conversationStates.set(negotiationId, state);
        }
        return state;
    }

    // Extract a notable feature from listing for personalization
    extractPropertyFeature(listing) {
        const features = [];

        // Check title for keywords
        const title = (listing.title || '').toLowerCase();
        if (title.includes('renovated')) features.push('the recent renovations');
        if (title.includes('view')) features.push('the views');
        if (title.includes('modern')) features.push('the modern design');
        if (title.includes('spacious')) features.push('how spacious it looks');
        if (title.includes('bright')) features.push('the natural light');
        if (title.includes('quiet')) features.push('the quiet location');
        if (title.includes('downtown')) features.push('the downtown location');
        if (title.includes('parking')) features.push('the parking');

        // Add based on property attributes
        if (listing.bedrooms >= 3) features.push(`all ${listing.bedrooms} bedrooms`);
        if (listing.house_type === 'Apartment') features.push('the apartment layout');
        if (listing.house_type === 'Condo') features.push('the condo amenities');
        if (listing.house_type === 'House') features.push('the whole house setup');
        if (listing.house_type === 'Townhouse') features.push('the townhouse style');

        // Generic fallbacks
        features.push('the layout', 'the location', 'how it looks');

        return features[Math.floor(Math.random() * Math.min(features.length, 5))];
    }

    // Detect when to transition to next phase based on landlord's response.
    // CLOSING is a TERMINAL LOCK — once entered, can never downgrade. The
    // closing-signal regex below (meet, deposit, sign, tomorrow, address,
    // "let's do it", "I'll take it"...) trumps every other phase rule. This
    // is the single most important behavior fix: it stops the AI from asking
    // discovery questions after the landlord has offered to close the deal.
    detectPhaseTransition(landlordMessage, currentPhase, conversationState) {
        const message = (landlordMessage || '').toLowerCase();
        const messageCount = conversationState.phaseMessageCount || 0;
        const phaseConfig = this.CONVERSATION_PHASES[currentPhase];

        // FORWARD-ONLY: once locked into CLOSING, stay there.
        if (currentPhase === 'CLOSING') {
            return 'CLOSING';
        }

        // CLOSING signal trumps everything — landlord wants to wrap up.
        if (this.CLOSING_SIGNALS_RE.test(message)) {
            console.log('🔒 LANDLORD SIGNALED CLOSING — locking phase to CLOSING (terminal).');
            return 'CLOSING';
        }

        // Skip to PRICE_INTRODUCTION if landlord brings up price/money
        const priceKeywords = /\$\d+|price|rent|budget|cost|afford|monthly|per month|how much|offer/i;
        if (priceKeywords.test(message) && currentPhase !== 'ACTIVE_NEGOTIATION' && currentPhase !== 'PRICE_INTRODUCTION') {
            console.log('⏩ Landlord mentioned price - skipping to PRICE_INTRODUCTION');
            return 'PRICE_INTRODUCTION';
        }

        // Skip to QUALIFICATION if landlord asks about tenant
        const qualificationKeywords = /job|work|employ|income|credit|reference|background|who are you|tell me about|what do you do/i;
        if (qualificationKeywords.test(message) && (currentPhase === 'INTRODUCTION' || currentPhase === 'RAPPORT_BUILDING')) {
            console.log('⏩ Landlord asked about tenant - moving to QUALIFICATION');
            return 'QUALIFICATION';
        }

        // Phase-specific transitions
        const transitions = {
            INTRODUCTION: {
                // Any response from landlord after intro = move to rapport
                nextPhase: 'RAPPORT_BUILDING',
                conditions: () => message.length > 0
            },
            RAPPORT_BUILDING: {
                nextPhase: 'QUALIFICATION',
                conditions: () => {
                    const positiveResponse = /yes|available|sure|great|sounds|interested|tell me|love to/i.test(message);
                    return messageCount >= 1 || positiveResponse;
                }
            },
            QUALIFICATION: {
                nextPhase: 'AVAILABILITY_DISCUSSION',
                conditions: () => {
                    const positiveResponse = /sounds good|great|perfect|stable|reliable|good tenant/i.test(message);
                    return messageCount >= 1 || positiveResponse;
                }
            },
            AVAILABILITY_DISCUSSION: {
                nextPhase: 'PRICE_INTRODUCTION',
                conditions: () => {
                    const discussedAvailability = /available|move.?in|when|date|lease|month/i.test(message);
                    return messageCount >= 1 || discussedAvailability;
                }
            },
            PRICE_INTRODUCTION: {
                nextPhase: 'ACTIVE_NEGOTIATION',
                conditions: () => {
                    const priceDiscussion = /\$\d+|counter|offer|agree|deal|accept|firm|flexible|negotiate/i.test(message);
                    return priceDiscussion;
                }
            },
            ACTIVE_NEGOTIATION: {
                nextPhase: null, // Terminal phase (until deal or rejection)
                conditions: () => false
            }
        };

        const rule = transitions[currentPhase];
        if (rule && rule.conditions()) {
            console.log(`➡️ Advancing from ${currentPhase} to ${rule.nextPhase}`);
            return rule.nextPhase;
        }

        return currentPhase; // Stay in current phase
    }

    // Get context for generating phase-specific message
    buildPhaseContext(conversationState) {
        return {
            userName: conversationState.userName || 'there',
            propertyTitle: conversationState.listing?.title || 'your place',
            propertyFeature: conversationState.propertyFeature || 'the layout',
            city: conversationState.listing?.city || 'the area',
            userBudget: conversationState.userBudget,
            listingPrice: conversationState.listing?.price,
            lastLandlordMessage: conversationState.lastLandlordMessage || '',
            currentOffer: conversationState.currentOffer,
            landlordCounterOffer: conversationState.landlordCounterOffer,
            agreedPrice: conversationState.agreedPrice,
            messageHistory: conversationState.messageHistory
        };
    }

    // Add natural human variations to messages
    addHumanVariations(message) {
        let result = message;

        // 25% chance to add casual filler at start
        if (Math.random() < 0.25) {
            const fillers = ['Actually, ', 'Oh, ', 'So, ', 'Yeah, ', 'Honestly, ', 'Just '];
            const filler = fillers[Math.floor(Math.random() * fillers.length)];
            result = filler + result.charAt(0).toLowerCase() + result.slice(1);
        }

        // 20% chance to add casual closer
        if (Math.random() < 0.20) {
            const closers = [' Thanks!', ' Let me know!', ' Appreciate it!', ' :)', ''];
            const closer = closers[Math.floor(Math.random() * closers.length)];
            result = result.replace(/[.!?]$/, '') + closer;
        }

        // 15% chance to remove trailing period (casual texting style)
        if (Math.random() < 0.15) {
            result = result.replace(/\.$/, '');
        }

        return result;
    }

    async postJSON(path, body) {
        const response = await fetch(path, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body || {})
        });

        if (!response.ok) {
            const errorText = await response.text().catch(() => '');
            throw new Error(`Request failed (${response.status}) ${errorText}`.trim());
        }

        return await response.json();
    }

    // Generate phase-specific message using OpenAI
    async generatePhaseMessage(conversationState, phase = null) {
        const currentPhase = phase || conversationState.currentPhase;
        const context = this.buildPhaseContext(conversationState);

        console.log(`🎭 Generating ${currentPhase} phase message (tone: ${conversationState.tone || 'NEUTRAL'})`);

        // Pull tenant goals from the page panel (if present). When this script
        // runs on a page without the goals panel (e.g. embedded usage), the
        // helper is undefined and we ship an empty object — backend treats it
        // as "no goals set" and uses the legacy behavior.
        const tenantGoals = (typeof window !== 'undefined' && typeof window.getTenantGoals === 'function')
            ? window.getTenantGoals()
            : {};

        try {
            const data = await this.postJSON('/api/negotiate/phase-message', {
                phase: currentPhase,
                context,
                // Phase-locked engine fields. Backend builds a tighter prompt
                // off these instead of relying on raw history. Sent alongside
                // messageHistory for backwards compat — backend will prefer
                // the structured fields when present.
                tone: conversationState.tone || 'NEUTRAL',
                facts: conversationState.facts || {},
                alreadyAsked: [...(conversationState.alreadyAsked || [])],
                alreadySharedCredentials: !!conversationState.alreadySharedCredentials,
                tenantGoals,
                messageHistory: conversationState.messageHistory || []
            });

            let message = (data.response || '').trim();
            if (!message) throw new Error('Empty phase-message response');

            // Skip "human variations" (random cheerful fillers, ":)", "Thanks!")
            // when we're closing or repairing — they read as gaslighting on top
            // of an angry/finalizing landlord.
            const suppressVariations = currentPhase === 'CLOSING' || conversationState.tone === 'FRUSTRATED';
            if (!suppressVariations) {
                message = this.addHumanVariations(message);
            }

            console.log(`✅ Generated ${currentPhase} message:`, message);
            return message;

        } catch (error) {
            console.warn('⚠️ AI phase-message unavailable, using fallback template');
            return this.getFallbackMessage(currentPhase, context);
        }
    }

    // Build system prompt for specific phase (client-side version)
    buildPhaseSystemPrompt(phase, context) {
        const userName = context.userName || 'there';
        const propertyTitle = context.propertyTitle || 'your place';
        const propertyFeature = context.propertyFeature || 'the layout';
        const city = context.city || 'the area';
        const userBudget = context.userBudget || 1500;
        const listingPrice = context.listingPrice || userBudget;
        const lastLandlordMessage = context.lastLandlordMessage || '';

        const basePersonality = `You are a REAL PERSON - a working professional looking for a rental. NOT an AI.

CRITICAL RULES:
- Write like texting, NOT formal letters
- Use contractions (I'm, don't, can't, it's)
- Keep messages SHORT: 2-4 sentences max
- Include occasional fillers: "Actually", "Oh", "So", "Honestly"
- NEVER use bullet points or lists
- NEVER say "I'm here to help" or mention being AI
- NEVER use formal phrases like "I am writing to" or "Kind regards"
- Sound like texting a potential landlord

YOUR PERSONA: Working professional, stable income, reliable, been renting for years.`;

        const phasePrompts = {
            INTRODUCTION: `${basePersonality}

PHASE: FIRST CONTACT

GOAL: Casual greeting, show interest in ONE property detail, ask if available.
DO NOT mention price or qualifications yet.

PROPERTY: ${propertyTitle} in ${city}
FEATURE TO MENTION: ${propertyFeature}

Write 2-3 sentences max. Example: "Hey! Saw your listing and it caught my eye. Is it still available?"`,

            RAPPORT_BUILDING: `${basePersonality}

PHASE: BUILDING CONNECTION

LANDLORD SAID: "${lastLandlordMessage}"

GOAL: Ask 1-2 questions about property/neighborhood. Show genuine interest.
Still NO pricing discussion.

Good questions: What's the neighborhood like? Is it quiet? How's parking?

Write 2-3 sentences responding to them and asking a question.`,

            QUALIFICATION: `${basePersonality}

PHASE: SHARING BACKGROUND

LANDLORD SAID: "${lastLandlordMessage}"

GOAL: Naturally share why you'd be a great tenant (don't list everything).
Mention: stable job, good rental history, responsible.

Write 2-3 sentences. Be humble, not salesy.`,

            AVAILABILITY_DISCUSSION: `${basePersonality}

PHASE: LOGISTICS

LANDLORD SAID: "${lastLandlordMessage}"

GOAL: Discuss move-in timing, lease terms, maybe suggest viewing.

Write 2-3 sentences about timing/availability.`,

            PRICE_INTRODUCTION: `${basePersonality}

PHASE: BUDGET DISCUSSION

LANDLORD SAID: "${lastLandlordMessage}"

YOUR BUDGET: ~$${userBudget}/month
LISTING PRICE: $${listingPrice}/month

GOAL: Bring up budget casually, ask if flexible. Be honest, not demanding.

Example: "So I wanted to be upfront - my budget is around $${userBudget}. Any flexibility on rent?"

Write 2-3 sentences introducing your budget.`,

            ACTIVE_NEGOTIATION: `${basePersonality}

PHASE: NEGOTIATING

LANDLORD SAID: "${lastLandlordMessage}"

YOUR BUDGET: $${userBudget}/month
LISTING: $${listingPrice}/month
${context.currentOffer ? `YOUR LAST OFFER: $${context.currentOffer}` : ''}

GOAL: Work toward agreement. Acknowledge their position, make reasonable counters.

Write 2-3 sentences negotiating naturally.`
        };

        return phasePrompts[phase] || phasePrompts.INTRODUCTION;
    }

    // Fallback messages when OpenAI is unavailable
    getFallbackMessage(phase, context) {
        const templates = {
            INTRODUCTION: [
                `Hey! Just came across your listing for ${context.propertyTitle} and it caught my eye. Is it still available?`,
                `Hi there! Saw your place on RoomFinder - love ${context.propertyFeature}. Still looking for a tenant?`,
                `Hey! I'm apartment hunting in ${context.city} and your place stood out. Would love to know more!`
            ],
            RAPPORT_BUILDING: [
                `Awesome, glad it's still available! Quick question - what's the neighborhood like?`,
                `Great! Is it pretty quiet around there? I work from home so that's important for me.`,
                `Nice! How long have you had the place? Any issues I should know about?`
            ],
            QUALIFICATION: [
                `Sounds great. A bit about me - I work in tech, stable income, been at my current place for 3 years. My landlord can vouch for me.`,
                `Perfect. I should mention - I'm a working professional, pretty low-maintenance as a tenant. Never missed a rent payment.`,
                `Good to know! I work from home, very quiet, and take good care of places I live. Been renting for years with great references.`
            ],
            AVAILABILITY_DISCUSSION: [
                `When would move-in work for you? I'm looking at next month but I'm flexible.`,
                `Is the lease 12 months? I'm open to longer if that helps. When could I see the place?`,
                `I'm pretty flexible on the exact move-in date. Would love to schedule a viewing if possible.`
            ],
            PRICE_INTRODUCTION: [
                `So I wanted to be upfront about budget - I'm working with around $${context.userBudget}/month. Is there any flexibility on the rent?`,
                `I really like the place. Just being honest, my comfortable range is around $${context.userBudget}. Any wiggle room?`,
                `Everything looks perfect. The only thing is budget - I'm at around $${context.userBudget}. What do you think?`
            ],
            ACTIVE_NEGOTIATION: [
                `I hear you. Would $${context.currentOffer || context.userBudget} work? I can commit to a longer lease if that helps.`,
                `That's a bit above what I was hoping, but I really want this place. Could you do $${context.currentOffer || context.userBudget}?`,
                `I understand. What if we met somewhere in the middle?`
            ]
        };

        const phaseTemplates = templates[phase] || templates.INTRODUCTION;
        return phaseTemplates[Math.floor(Math.random() * phaseTemplates.length)];
    }

    // Start conversation with introduction (new human-like flow) - v2
    async startHumanLikeConversation(listing, userBudget, userEmail, userName = null) {
        try {
            console.log('🚀 [HUMAN-LIKE v2] Starting phased conversation for:', listing.title);

            // Create negotiation ID
            const negotiationId = `neg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

            // Initialize conversation state
            const conversationState = this.initConversationState(negotiationId, listing, userBudget, userEmail);
            if (userName) conversationState.userName = userName;

            // Generate introduction message (NO pricing)
            const introMessage = await this.generatePhaseMessage(conversationState, 'INTRODUCTION');

            // Record the message
            conversationState.messageHistory.push({
                sender: 'ai',
                content: introMessage,
                timestamp: new Date(),
                phase: 'INTRODUCTION'
            });
            conversationState.phaseMessageCount = 1;
            conversationState.totalMessageCount = 1;

            // Also track in activeNegotiations for compatibility
            this.activeNegotiations.set(negotiationId, {
                listingId: listing.id,
                listingTitle: listing.title,
                originalPrice: listing.price,
                userBudget: userBudget,
                userEmail: userEmail,
                landlordEmail: listing.user_email,
                marketData: null, // Will be fetched when needed
                status: 'active',
                startTime: new Date(),
                conversationPhase: 'INTRODUCTION',
                messages: [{
                    sender: 'ai',
                    content: introMessage,
                    timestamp: new Date()
                }],
                negotiationState: {
                    currentPhase: 'INTRODUCTION',
                    offersMade: [],
                    offersRejected: 0,
                    lastOffer: null,
                    concessionCount: 0
                },
                landlordProfile: this.getDefaultLandlordProfile(),
                memory: {
                    landlordConcerns: [],
                    effectivePhrases: [],
                    rapportLevel: 50,
                    topicsDiscussed: []
                }
            });

            console.log('✅ Started conversation with introduction (no pricing)');

            return {
                message: introMessage,
                negotiationId: negotiationId,
                phase: 'INTRODUCTION',
                conversationState: conversationState
            };

        } catch (error) {
            console.error('Error starting human-like conversation:', error);
            throw error;
        }
    }

    // Handle landlord reply and generate next phase response
    async handleLandlordReplyWithPhases(landlordMessage, negotiationId, listing) {
        try {
            console.log('💬 Processing landlord reply for phased conversation');

            // Get conversation state
            let conversationState = this.getConversationState(negotiationId);

            if (!conversationState) {
                // Try to reconstruct from activeNegotiations
                const negotiation = this.activeNegotiations.get(negotiationId);
                if (negotiation) {
                    conversationState = this.initConversationState(negotiationId, listing, negotiation.userBudget, negotiation.userEmail);
                    conversationState.currentPhase = negotiation.conversationPhase || 'RAPPORT_BUILDING';
                    conversationState.messageHistory = negotiation.messages || [];
                } else {
                    console.error('No conversation state found for:', negotiationId);
                    return null;
                }
            }

            // Record landlord's message
            conversationState.lastLandlordMessage = landlordMessage;
            conversationState.landlordResponses.push({
                content: landlordMessage,
                timestamp: new Date()
            });
            conversationState.messageHistory.push({
                sender: 'landlord',
                content: landlordMessage,
                timestamp: new Date()
            });

            // Backfill phase-locked state for negotiations that were created
            // before this engine existed (e.g. reconstructed from activeNegotiations).
            if (!conversationState.facts) conversationState.facts = {
                listing_held_months: null, deposit_amount: null, proposed_meet_date: null,
                has_laundry: null, has_parking: null, pets_allowed: null,
                landlord_said_yes_to_meet: false, landlord_offered_closing: false
            };
            if (!conversationState.alreadyAsked) conversationState.alreadyAsked = new Set();
            if (conversationState.alreadySharedCredentials == null) conversationState.alreadySharedCredentials = false;
            if (!conversationState.tone) conversationState.tone = 'NEUTRAL';

            // Pre-filter pass over the landlord message — extracts structured
            // facts (laundry available, duration, meet date...) and detects
            // tone signals. This runs BEFORE any LLM call so the prompt
            // builder downstream can switch shape based on the result.
            this.extractFactsFromLandlordMessage(landlordMessage, conversationState.facts);
            const intent = this.extractIntentFromLandlordMessage(landlordMessage);
            // Tone is STICKY on frustration: once the landlord swore at us, we
            // stay in damage-control mode even if their next message is calm.
            if (intent.frustrated) {
                conversationState.tone = 'FRUSTRATED';
                console.log('😡 Landlord frustration detected — tone locked to FRUSTRATED.');
            } else if (intent.closing && conversationState.tone !== 'FRUSTRATED') {
                conversationState.tone = 'ENGAGED';
            }
            // Best-effort: record what the landlord just answered so the AI
            // doesn't re-ask. Topics align with the facts fields we extract.
            if (conversationState.facts.has_laundry != null) conversationState.alreadyAsked.add('laundry');
            if (conversationState.facts.has_parking != null) conversationState.alreadyAsked.add('parking');
            if (conversationState.facts.pets_allowed != null) conversationState.alreadyAsked.add('pets');
            if (conversationState.facts.listing_held_months != null) conversationState.alreadyAsked.add('duration');

            // Numeric convergence check: if the landlord just named a price
            // that matches a price the AI offered in its prior turn (within
            // $50 tolerance), the deal is mutually accepted in numbers even
            // if neither side wrote the word "deal". Locks CLOSING.
            if (conversationState.facts.landlord_last_named_price && conversationState.currentPhase !== 'CLOSING') {
                const lastAi = (conversationState.messageHistory || []).slice().reverse().find(m => m.sender === 'ai');
                if (lastAi) {
                    const aiPriceMatch = String(lastAi.content || '').match(/\$?\s*(\d{1,3}(?:,\d{3})+|\d{3,5})(?:\.\d{1,2})?/);
                    if (aiPriceMatch) {
                        const aiPrice = parseFloat(aiPriceMatch[1].replace(/,/g, ''));
                        const landlordPrice = conversationState.facts.landlord_last_named_price;
                        if (aiPrice >= 500 && Math.abs(aiPrice - landlordPrice) < 50) {
                            console.log(`🤝 Numeric convergence at ~$${landlordPrice} (AI prior: $${aiPrice}). Locking CLOSING.`);
                            conversationState.currentPhase = 'CLOSING';
                            conversationState.facts.agreed_price = landlordPrice;
                            conversationState.phaseHistory.push('CLOSING');
                        }
                    }
                }
            }

            // Detect phase transition
            const newPhase = this.detectPhaseTransition(
                landlordMessage,
                conversationState.currentPhase,
                conversationState
            );

            // Update phase if changed
            if (newPhase !== conversationState.currentPhase) {
                console.log(`📍 Phase transition: ${conversationState.currentPhase} → ${newPhase}`);
                conversationState.currentPhase = newPhase;
                conversationState.phaseMessageCount = 0;
                conversationState.phaseHistory.push(newPhase);
            }

            // If entering ACTIVE_NEGOTIATION, get market data
            if (newPhase === 'ACTIVE_NEGOTIATION' || newPhase === 'PRICE_INTRODUCTION') {
                const negotiation = this.activeNegotiations.get(negotiationId);
                if (negotiation && !negotiation.marketData) {
                    negotiation.marketData = await this.getMarketData(
                        listing.city, listing.house_type, listing.bedrooms, listing
                    );
                }
            }

            // Generate response for current phase
            const rawResponse = await this.generatePhaseMessage(conversationState);

            // Post-OpenAI validator: hard-replaces violations even if the LLM
            // ignored the prompt rules (questions in CLOSING, emojis when
            // FRUSTRATED, etc.). Cheap safety net behind the prompt itself.
            const responseMessage = this.validateAndRepair(rawResponse, {
                phase: conversationState.currentPhase,
                tone: conversationState.tone,
                facts: conversationState.facts
            });

            // Once we've actually shipped a phase response (especially in
            // QUALIFICATION which is the credentials pitch), mark credentials
            // as shared so future prompts know not to repeat them.
            if (conversationState.currentPhase === 'QUALIFICATION') {
                conversationState.alreadySharedCredentials = true;
            }

            // Closing detection on the AI's OWN response. The bug we just hit:
            // AI said "YES. Deal." but the next landlord message ("ok deal")
            // came in while phase was still ACTIVE_NEGOTIATION, so the AI
            // produced a rapport-style reply ("what's the neighborhood like?").
            // By inspecting our own output for closing intent right after
            // validateAndRepair, we lock CLOSING *before* the next inbound
            // message arrives — its handler then renders a calm confirmation
            // instead of restarting discovery.
            if (this.CLOSING_SIGNALS_RE.test(responseMessage) && conversationState.currentPhase !== 'CLOSING') {
                console.log('🔒 AI itself signaled acceptance — locking phase to CLOSING.');
                conversationState.currentPhase = 'CLOSING';
                conversationState.phaseHistory.push('CLOSING');
                conversationState.facts.landlord_said_yes_to_meet = true;
            }

            // Record our response
            conversationState.messageHistory.push({
                sender: 'ai',
                content: responseMessage,
                timestamp: new Date(),
                phase: conversationState.currentPhase
            });
            conversationState.phaseMessageCount++;
            conversationState.totalMessageCount++;

            // Update active negotiation tracking
            const negotiation = this.activeNegotiations.get(negotiationId);
            if (negotiation) {
                negotiation.conversationPhase = conversationState.currentPhase;
                negotiation.messages.push({
                    sender: 'landlord',
                    content: landlordMessage,
                    timestamp: new Date()
                });
                negotiation.messages.push({
                    sender: 'ai',
                    content: responseMessage,
                    timestamp: new Date()
                });
            }

            // Calculate human-like response delay
            const delay = this.calculateResponseDelay({
                messageLength: landlordMessage.length,
                responseLength: responseMessage.length,
                emotionalContent: /!|\?{2,}|urgent|asap|hurry/i.test(landlordMessage),
                isComplexDecision: conversationState.currentPhase === 'ACTIVE_NEGOTIATION'
            });

            console.log(`✅ Generated ${conversationState.currentPhase} response (delay: ${delay}ms)`);

            return {
                message: responseMessage,
                phase: conversationState.currentPhase,
                delay: delay,
                conversationState: conversationState
            };

        } catch (error) {
            console.error('Error handling landlord reply with phases:', error);
            throw error;
        }
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

    // Calculate percentage-based increment that scales with property value
    calculatePercentageIncrement(listingPrice, concessionRound) {
        // Percentage ranges that decrease with each concession (balanced 2-4% strategy)
        const percentageRanges = [
            { min: 0.03, max: 0.04 },   // Round 1: 3-4%
            { min: 0.025, max: 0.035 }, // Round 2: 2.5-3.5%
            { min: 0.02, max: 0.03 },   // Round 3: 2-3%
            { min: 0.015, max: 0.025 }, // Round 4: 1.5-2.5%
            { min: 0.01, max: 0.02 }    // Round 5+: 1-2%
        ];

        const roundIndex = Math.min(concessionRound, percentageRanges.length - 1);
        const range = percentageRanges[roundIndex];

        // Random percentage within range for this round
        const randomPct = range.min + (Math.random() * (range.max - range.min));

        // Calculate dollar increment
        let increment = Math.round(listingPrice * randomPct);

        // Apply minimum floor based on price tier
        const minIncrement = listingPrice < 2000 ? 25 : (listingPrice < 5000 ? 50 : 75);
        increment = Math.max(increment, minIncrement);

        // Add authenticity variation (±10 dollars)
        const authenticVariation = Math.floor(Math.random() * 20) - 10;
        increment += authenticVariation;

        // Ensure we never go below the floor
        return Math.max(minIncrement, increment);
    }

    // ========================================
    // PHASE 1: NATURAL RESPONSE TIMING
    // ========================================

    // Calculate human-like response delay based on context
    calculateResponseDelay(context) {
        const { messageLength = 0, responseLength = 0, emotionalContent = false, isComplexDecision = false } = context;

        let delay = 800; // Base delay (800ms minimum)

        // Reading time: ~50ms per word (average 5 chars per word)
        delay += Math.min((messageLength / 5) * 50, 1500);

        // Composing time: ~20ms per character of response
        delay += Math.min(responseLength * 20, 1200);

        // Thinking time for emotional or complex content
        if (emotionalContent) delay += 800;
        if (isComplexDecision) delay += 600;

        // Add natural variance (±20%)
        const variance = delay * 0.2 * (Math.random() * 2 - 1);
        delay += variance;

        // Clamp between 500ms and 4500ms
        return Math.max(500, Math.min(4500, Math.round(delay)));
    }

    // ========================================
    // PHASE 2: THREE VOICES SYSTEM (Chris Voss)
    // ========================================

    // Voice profiles for different negotiation contexts
    voiceProfiles = {
        playful: {
            name: 'playful',
            description: 'Warm, light humor, builds rapport',
            triggers: ['default', 'rapport_building', 'positive_momentum'],
            style: 'Upbeat and friendly, uses phrases like "I hear you!", "Let\'s figure this out", "Fair enough"',
            tone: 'warm but confident'
        },
        late_night_dj: {
            name: 'late_night_dj',
            description: 'Calm, reassuring, de-escalates tension',
            triggers: ['frustrated', 'anxious', 'aggressive', 'multiple_rejections'],
            style: 'Slow, calming, uses "I completely understand...", "Take your time", "No pressure"',
            tone: 'soothing and patient'
        },
        direct: {
            name: 'direct',
            description: 'Firm, assertive, for closing moments',
            triggers: ['closing', 'final_offer', 'deadline'],
            style: 'Confident and decisive, uses "I need to make a decision today", "This is my final position"',
            tone: 'assertive but respectful'
        }
    };

    // Select appropriate voice based on context
    getVoiceForContext(landlordProfile, phase, rejectionCount = 0) {
        // Late Night DJ voice for frustrated landlords or multiple rejections
        if (landlordProfile?.emotionalState === 'frustrated' ||
            landlordProfile?.emotionalState === 'aggressive' ||
            rejectionCount >= 3) {
            return this.voiceProfiles.late_night_dj;
        }

        // Direct voice for closing phase or final offers
        if (phase === 'closing' || phase === 'final' || rejectionCount >= 4) {
            return this.voiceProfiles.direct;
        }

        // Default to playful voice (80% of interactions)
        return this.voiceProfiles.playful;
    }

    // Get voice instructions for prompt
    getVoiceInstructions(voice) {
        const instructions = {
            playful: `
VOICE: PLAYFUL/POSITIVE (Default)
- Warm and approachable, like talking to a friendly neighbor
- Light humor where appropriate ("Ha! Fair enough")
- Phrases: "I hear you!", "Let's figure this out", "That makes sense"
- Energy: Upbeat but not pushy
- Goal: Build rapport while negotiating`,

            late_night_dj: `
VOICE: LATE-NIGHT DJ (De-escalation)
- Calm, slow, measured pace
- Soothing and patient, never rushed
- Phrases: "I completely understand...", "Take your time", "No pressure at all"
- Lower the temperature of the conversation
- Goal: Reduce tension, rebuild trust`,

            direct: `
VOICE: DIRECT/ASSERTIVE (Closing)
- Confident and decisive, no hedging
- Clear and straightforward
- Phrases: "I need to decide today", "This is where I am", "Let's close this"
- Energy: Firm but respectful
- Goal: Drive toward decision`
        };

        return instructions[voice.name] || instructions.playful;
    }

    // ========================================
    // PHASE 3: INTELLIGENT TACTIC SELECTION
    // ========================================

    // Context-aware tactic selection (replaces round-based)
    selectTacticForContext(context) {
        const {
            messageContent = '',
            emotionalContent = false,
            rejectionCount = 0,
            priceObjection = false,
            recentTactics = [],
            landlordProfile = {},
            phase = 'bargaining'
        } = context;

        // Score each tactic based on context
        const scores = {
            mirroring: 0,
            labeling: 0,
            calibrated_question: 0,
            loss_aversion: 0,
            phantom_authority: 0,
            accusation_audit: 0,
            no_technique: 0
        };

        // Short responses benefit from mirroring (get them talking)
        if (messageContent.length < 50) scores.mirroring += 30;

        // Emotional content benefits from labeling
        if (emotionalContent) scores.labeling += 40;

        // Multiple rejections benefit from loss aversion
        if (rejectionCount >= 2) scores.loss_aversion += 35;

        // Price objections benefit from phantom authority
        if (priceObjection) scores.phantom_authority += 35;

        // Frustrated landlords benefit from accusation audit
        if (landlordProfile.emotionalState === 'frustrated') scores.accusation_audit += 40;

        // Closing phase benefits from "no" technique
        if (phase === 'closing') scores.no_technique += 30;

        // Opening phase benefits from calibrated questions
        if (phase === 'opening') scores.calibrated_question += 25;

        // Penalize recently used tactics heavily (avoid repetition)
        for (const tactic of recentTactics.slice(-2)) {
            if (scores[tactic] !== undefined) {
                scores[tactic] -= 50;
            }
        }

        // Find highest scoring tactic
        let bestTactic = 'calibrated_question';
        let bestScore = -Infinity;

        for (const [tactic, score] of Object.entries(scores)) {
            if (score > bestScore) {
                bestScore = score;
                bestTactic = tactic;
            }
        }

        return bestTactic;
    }

    // Get tactic instructions for prompt
    getTacticInstructions(tactic) {
        const instructions = {
            mirroring: `**MIRRORING**: Repeat their last 3-5 words as a question to make them elaborate.
Example: They say "I need more than that" → You say "$X? I need more than that?"`,

            labeling: `**LABELING**: Name their emotion to show understanding.
Phrases: "It sounds like...", "It seems like...", "I sense that..."
Example: "It sounds like you're weighing multiple options here."`,

            calibrated_question: `**CALIBRATED QUESTION**: Ask "How..." or "What..." questions to make them problem-solve WITH you.
Examples: "How am I supposed to make that work?", "What would it take to close today?"`,

            loss_aversion: `**LOSS AVERSION**: Frame what they LOSE by not accepting, not what they gain.
Focus on: vacancy costs, time wasted, uncertainty
Example: "Every week vacant is $X lost. I'm ready to sign today."`,

            phantom_authority: `**PHANTOM AUTHORITY**: Hint at external constraints controlling your budget.
Phrases: "My budget is capped at...", "I can't authorize above...", "The numbers don't allow..."
Makes it: "You + Me vs. The Budget" instead of "You vs. Me"`,

            accusation_audit: `**ACCUSATION AUDIT**: Preempt their objection before they raise it.
Phrases: "You probably think...", "I know it might seem like..."
Example: "You probably think I'm being difficult. I get it. $X is genuinely my limit."`,

            no_technique: `**"NO" TECHNIQUE**: Ask questions designed to get a "no" response (which psychologically commits them).
Example: "Would it be unreasonable to consider $X?" (They say "No, not unreasonable" = commitment)`
        };

        return instructions[tactic] || instructions.calibrated_question;
    }

    // ========================================
    // PHASE 4: RESPONSE VARIATION ENGINE
    // ========================================

    // Track used responses to prevent repetition
    usedResponses = new Map(); // conversationId -> Set of used response hashes

    // Response templates for various scenarios (8+ per scenario)
    responseTemplates = {
        rejection_counters: [
            "It sounds like that doesn't work. What would make ${offer} work today?",
            "I hear you. Let me stretch to ${offer}. That's genuinely my limit.",
            "Would ${offer} be unreasonable? I need to decide today.",
            "${offer} is where I'm at. Help me understand what would close this.",
            "Fair enough. ${offer} and a guaranteed tenant today vs. more showings?",
            "Got it. After running my numbers, ${offer} is every dollar I have.",
            "Understood. What if I do ${offer} and sign immediately?",
            "I appreciate you being direct. ${offer} - can we make this happen?",
            "Respect. ${offer} with references in hand. What do you say?",
            "${offer}. I'm ready to move fast. Can we close this today?",

            // Additional 15 variants for better variation
            "I respect that. ${offer} is where my budget lands - can we work with that?",
            "Fair. ${offer} and I can move in this weekend. Does that help?",
            "Understood. What if I offered ${offer} on a longer lease for stability?",
            "Got it. ${offer} - plus I'm flexible on move-in date. Thoughts?",
            "I hear you. ${offer} is genuinely where I am. Open to discussing terms?",
            "${offer} feels right given the market. Can we align on that?",
            "Makes sense. ${offer} with a 13-month lease to cover you year-round?",
            "Cool. ${offer} - I'm pre-approved and ready. What do you need from me?",
            "Alright. ${offer} and I can provide first/last/security upfront. Deal?",
            "Right. ${offer} - quiet tenant, no pets, excellent credit. Works?",
            "${offer} - I work from home so property care is a priority. Consider it?",
            "Okay. ${offer} and I'm happy to meet in person to discuss. Available?",
            "Noted. ${offer} - similar units nearby are going for that. Make sense?",
            "${offer} is my comfort zone. Happy to share references now. Interested?",
            "Appreciate the honesty. ${offer} - let's not let a great match slip away."
        ],

        competing_offer_responses: [
            "${competing}? That's strong. My budget is capped at ${offer}. Help me bridge that gap?",
            "${competing}... I hear you. The best I can authorize is ${offer}. Ready to sign today.",
            "${competing}? Respect. I can do ${offer} and close immediately. A sure thing vs. a maybe?",
            "Competing offer at ${competing}? I'll match at ${offer} and sign today. What do you say?",
            "${competing} is tough to beat. ${offer} is my ceiling, but I'm a guaranteed close.",
            "I get it, ${competing} is higher. ${offer} + reliability. What's worth more to you?",
            "${competing}? Fair. ${offer} is my limit, but zero risk of no-shows or backing out.",
            "At ${competing}, I'd have to walk. But ${offer} and done today - can we make it work?"
        ],

        acceptance_responses: [
            "Done! I'm ready to sign today. What are the next steps?",
            "Excellent! Thank you. I can complete all paperwork immediately.",
            "That works! I have references ready. When can we finalize?",
            "Perfect. I appreciate you working with me. Let's make this happen.",
            "Thank you! I'm a reliable tenant ready to proceed right now.",
            "Great! I won't waste your time. What do you need from me?"
        ],

        max_offer_responses: [
            "${offer}/month is genuinely my max. I'm a reliable tenant ready to sign today. Can we make this work?",
            "Look, ${offer} is every dollar I have. A guaranteed tenant today vs. more showings and uncertainty. What do you say?",
            "I can't go higher than ${offer}. But I'm ready to sign right now with references in hand. Deal?",
            "${offer} - that's my ceiling. I know it's below asking, but I'm a sure thing. Let's close this.",
            "Would it be unreasonable to lock this in at ${offer}? I can move fast and I won't waste your time.",
            "${offer} is where the numbers stop working for me. But I'm committed and ready today.",
            "After calculating everything, ${offer} is my absolute limit. Reliable tenant, immediate signing. Your call.",
            "${offer}. That's it. But you get certainty today instead of gambling on the next showing."
        ],

        witty_redirects: [
            "Ha! I appreciate the creativity, but I'm here for the apartment, not a date. So... ${offer}/month - we doing this or what?",
            "Smooth. But the only thing I'm trying to get into is that apartment. ${offer}/month work for you?",
            "Lol nice try. I'm flattered, but let's keep this professional. Back to business - ${offer}/month?",
            "You're funny. But seriously though, I need a place to live, not a Tinder match. Can we do ${offer}?",
            "Ha! You've got jokes. Let's save those for the housewarming party. ${offer}/month?",
            "I like the energy, but I'm just here for the apartment! ${offer} - what do you say?"
        ],

        playful_redirects: [
            "Haha, I feel you. But real talk - ${offer}/month, can we make it happen?",
            "Lol. Anyway... about that apartment? ${offer}/month sound fair?",
            "Alright alright. So we doing this deal or what? ${offer}/month.",
            "Ha! Okay okay. Back to business - ${offer}/month work for you?",
            "I like your style! But about that rent... ${offer}?"
        ],

        // Softening phrases to show empathy (especially for frustrated landlords)
        softening_phrases: [
            "I totally get where you're coming from.",
            "I appreciate you being straight with me.",
            "Fair point.",
            "Makes sense from your perspective.",
            "I respect that position.",
            "Completely understand.",
            "That's reasonable to say.",
            "I hear what you're saying.",
            "You make a valid point.",
            "I can see that."
        ],

        // Value propositions to demonstrate tenant quality
        value_propositions: [
            "I'm handy - happy to help with minor repairs",
            "I work remotely so I can receive deliveries/contractors",
            "I've rented from the same landlord for 5+ years",
            "My current landlord can vouch for me",
            "I keep places spotless - it's a thing",
            "Zero late payments in my rental history",
            "I'm quiet, no parties, respect neighbors",
            "Happy to do a longer lease for mutual stability",
            "I have excellent credit and strong references",
            "I'm financially stable with steady employment"
        ]
    };

    // Get a unique response that hasn't been used in this conversation
    getUniqueResponse(conversationId, templateType, variables) {
        // Initialize tracking for this conversation
        if (!this.usedResponses.has(conversationId)) {
            this.usedResponses.set(conversationId, new Set());
        }

        const usedSet = this.usedResponses.get(conversationId);
        const templates = this.responseTemplates[templateType] || [];

        // Try to find an unused template
        const availableTemplates = templates.filter(t => !usedSet.has(t));

        // If all used, reset and start over
        const templatePool = availableTemplates.length > 0 ? availableTemplates : templates;

        if (templatePool.length === 0) {
            return null; // No templates available
        }

        // Pick random from available
        const template = templatePool[Math.floor(Math.random() * templatePool.length)];

        // Mark as used
        usedSet.add(template);

        // Apply variables
        let response = template;
        for (const [key, value] of Object.entries(variables)) {
            response = response.replace(new RegExp(`\\$\\{${key}\\}`, 'g'), value);
        }

        return response;
    }

    // Construct dynamic message with contextual elements for authenticity
    constructDynamicMessage(templateType, variables, landlordProfile, negotiation) {
        // Get base template using the variation engine
        let message = this.getUniqueResponse(
            negotiation.listingId || 'default',
            templateType,
            variables
        );

        if (!message) return null;

        // 30% chance to add softening phrase if landlord is frustrated
        if (Math.random() < 0.3 && landlordProfile?.emotionalState === 'frustrated') {
            const soften = this.responseTemplates.softening_phrases[
                Math.floor(Math.random() * this.responseTemplates.softening_phrases.length)
            ];
            message = `${soften} ${message}`;
        }

        // 25% chance to add value proposition after 2+ concessions
        const concessionCount = negotiation.negotiationState?.concessionCount || 0;
        if (Math.random() < 0.25 && concessionCount >= 2) {
            const value = this.responseTemplates.value_propositions[
                Math.floor(Math.random() * this.responseTemplates.value_propositions.length)
            ];
            message += ` ${value}.`;
        }

        // Randomly vary sentence structure for authenticity
        message = this.varyStructure(message);

        return message;
    }

    // Helper to vary sentence structure for more natural messages
    varyStructure(text) {
        // Randomly convert some statements to questions (15% chance)
        if (Math.random() < 0.15 && !text.includes('?')) {
            return text.replace(/\.$/, '?');
        }

        // Randomly add conversational fillers (20% chance)
        const fillers = ['', 'Look, ', 'Listen, ', 'Honestly, ', 'Real talk - '];
        if (Math.random() < 0.2 && !text.match(/^(Look|Listen|Honestly|Real talk)/)) {
            const filler = fillers[Math.floor(Math.random() * fillers.length)];
            return filler + text;
        }

        return text;
    }

    // ========================================
    // PHASE 5: CIALDINI PRINCIPLES
    // ========================================

    cialdiniPrinciples = {
        reciprocity: {
            name: 'Reciprocity',
            description: 'Give something first to encourage giving back',
            examples: [
                "I can be flexible on move-in date if that helps",
                "Happy to do a longer lease for stability",
                "I can provide references upfront to make things easier"
            ]
        },
        commitment: {
            name: 'Commitment/Consistency',
            description: 'Build on their previous statements',
            examples: [
                "You mentioned wanting a reliable tenant...",
                "Earlier you said timing was important...",
                "Since stability matters to you..."
            ]
        },
        social_proof: {
            name: 'Social Proof',
            description: 'Reference what others have done',
            examples: [
                "Similar units in the area have gone for around ${marketAvg}",
                "Other landlords I've worked with appreciated...",
                "Properties like this typically rent for..."
            ]
        },
        liking: {
            name: 'Liking',
            description: 'Build rapport through genuine appreciation',
            examples: [
                "I love the natural light in this place",
                "The location is perfect for my commute",
                "You've clearly taken good care of this property"
            ]
        },
        authority: {
            name: 'Authority',
            description: 'Reference credible data or expertise',
            examples: [
                "Based on comparable rentals in the area...",
                "Looking at current market rates...",
                "The rental market data suggests..."
            ]
        },
        scarcity: {
            name: 'Scarcity',
            description: 'Highlight your own constraints/urgency',
            examples: [
                "I need to make a decision by end of week",
                "This is the last property in my budget range",
                "I'm choosing between this and one other place today"
            ]
        },
        unity: {
            name: 'Unity',
            description: 'Create shared identity/goals',
            examples: [
                "How can WE make this work?",
                "What do we need to bridge this gap?",
                "We're so close - let's figure this out together"
            ]
        }
    };

    // Select appropriate Cialdini principle based on context
    selectCialdiniPrinciple(context) {
        const {
            phase = 'bargaining',
            rejectionCount = 0,
            landlordProfile = {},
            hasMarketData = false
        } = context;

        // Opening phase: use liking to build rapport
        if (phase === 'opening') {
            return Math.random() > 0.5 ? 'liking' : 'reciprocity';
        }

        // If landlord mentioned something specific, use commitment
        if (landlordProfile.concerns?.length > 0) {
            return 'commitment';
        }

        // Multiple rejections: use scarcity or unity
        if (rejectionCount >= 2) {
            return Math.random() > 0.5 ? 'scarcity' : 'unity';
        }

        // If we have market data, use authority/social proof
        if (hasMarketData) {
            return Math.random() > 0.5 ? 'authority' : 'social_proof';
        }

        // Default: reciprocity
        return 'reciprocity';
    }

    // ========================================
    // PHASE 6: PERSONALITY ENGINE
    // ========================================

    // Analyze landlord's communication style
    analyzeLandlordPersonality(messages) {
        const landlordMessages = messages.filter(m => m.sender === 'landlord');

        if (landlordMessages.length === 0) {
            return this.getDefaultLandlordProfile();
        }

        // Analyze patterns
        const allText = landlordMessages.map(m => m.content).join(' ');
        const avgLength = allText.length / landlordMessages.length;

        // Detect style indicators
        const hasEmoji = /[\u{1F300}-\u{1F9FF}]/u.test(allText);
        const isFormal = /dear|regards|sincerely|thank you|please/i.test(allText);
        const isShort = avgLength < 50;
        const isLong = avgLength > 200;
        const hasExclamation = /!/.test(allText);
        const hasQuestion = /\?/.test(allText);

        // Detect emotional state
        const frustrationWords = /no|can't|won't|firm|final|not possible|impossible/gi;
        const positiveWords = /great|perfect|sounds good|interested|yes|okay|sure/gi;
        const neutralWords = /let me|I'll think|consider|maybe|perhaps/gi;

        const frustrationCount = (allText.match(frustrationWords) || []).length;
        const positiveCount = (allText.match(positiveWords) || []).length;

        // Calculate warmth level (0-100)
        let warmthLevel = 50;
        if (hasEmoji) warmthLevel += 15;
        if (hasExclamation && !frustrationCount) warmthLevel += 10;
        if (positiveCount > 0) warmthLevel += positiveCount * 10;
        if (frustrationCount > 0) warmthLevel -= frustrationCount * 15;
        if (isFormal) warmthLevel -= 10;
        warmthLevel = Math.max(0, Math.min(100, warmthLevel));

        // Determine style
        let style = 'neutral';
        if (warmthLevel >= 70) style = 'friendly';
        else if (warmthLevel >= 50) style = 'warm';
        else if (warmthLevel >= 30) style = 'business-like';
        else style = 'skeptical';

        // Determine emotional state
        let emotionalState = 'neutral';
        if (frustrationCount > positiveCount) emotionalState = 'frustrated';
        else if (positiveCount > 0) emotionalState = 'interested';
        else if (hasQuestion) emotionalState = 'engaged';

        // Extract concerns
        const concerns = [];
        if (/price|budget|cost|money|afford/i.test(allText)) concerns.push('price');
        if (/reliable|trust|reference|credit|background/i.test(allText)) concerns.push('tenant_quality');
        if (/soon|quick|when|timing|move.?in/i.test(allText)) concerns.push('timing');
        if (/lease|term|duration|months/i.test(allText)) concerns.push('lease_terms');

        return {
            style,
            emotionalState,
            warmthLevel,
            concerns,
            responsePatterns: {
                averageLength: avgLength,
                usesEmoji: hasEmoji,
                formalityLevel: isFormal ? 'formal' : (hasEmoji || hasExclamation ? 'casual' : 'neutral')
            },
            messageCount: landlordMessages.length
        };
    }

    // Default profile for new conversations
    getDefaultLandlordProfile() {
        return {
            style: 'neutral',
            emotionalState: 'neutral',
            warmthLevel: 50,
            concerns: [],
            responsePatterns: {
                averageLength: 0,
                usesEmoji: false,
                formalityLevel: 'neutral'
            },
            messageCount: 0
        };
    }

    // ========================================
    // PHASE 7: CONVERSATION MEMORY
    // ========================================

    // Initialize or update conversation memory
    updateConversationMemory(negotiation, landlordMessage, aiResponse, analysis) {
        if (!negotiation.memory) {
            negotiation.memory = {
                landlordConcerns: [],
                effectivePhrases: [],
                ineffectivePhrases: [],
                rapportLevel: 50, // Start neutral (0-100)
                topicsDiscussed: [],
                sentimentTrend: [] // Track sentiment over time
            };
        }

        const memory = negotiation.memory;

        // Track landlord concerns mentioned
        const concernPatterns = {
            price: /price|budget|cost|money|afford|expensive|cheap/i,
            reliability: /reliable|trust|reference|credit|background|secure/i,
            timing: /soon|quick|when|timing|move.?in|available/i,
            maintenance: /condition|repair|fix|maintain|clean/i,
            noise: /quiet|noise|neighbor|peaceful/i
        };

        for (const [concern, pattern] of Object.entries(concernPatterns)) {
            if (pattern.test(landlordMessage) && !memory.landlordConcerns.includes(concern)) {
                memory.landlordConcerns.push(concern);
            }
        }

        // Track sentiment trend
        const sentiment = analysis?.sentiment || 'neutral';
        memory.sentimentTrend.push({
            sentiment,
            timestamp: Date.now()
        });

        // Keep only last 10 sentiment records
        if (memory.sentimentTrend.length > 10) {
            memory.sentimentTrend.shift();
        }

        // Update rapport level based on sentiment
        if (sentiment === 'positive') {
            memory.rapportLevel = Math.min(100, memory.rapportLevel + 10);
        } else if (sentiment === 'negative') {
            memory.rapportLevel = Math.max(0, memory.rapportLevel - 15);
        }

        // Track topics discussed
        const topicPatterns = {
            price: /\$\d+|price|offer|budget/i,
            lease: /lease|term|month|year/i,
            moveIn: /move.?in|start|begin|available/i,
            references: /reference|credit|background/i,
            property: /apartment|unit|place|room|bedroom/i
        };

        for (const [topic, pattern] of Object.entries(topicPatterns)) {
            if (pattern.test(landlordMessage) && !memory.topicsDiscussed.includes(topic)) {
                memory.topicsDiscussed.push(topic);
            }
        }

        return memory;
    }

    // ========================================
    // PHASE 8: ESCALATION DETECTION
    // ========================================

    // Detect if landlord is warming up or cooling off
    detectEscalation(negotiation) {
        const memory = negotiation.memory;

        if (!memory || !memory.sentimentTrend || memory.sentimentTrend.length < 2) {
            return { direction: 'stable', recommendation: 'maintain_momentum' };
        }

        // Calculate recent sentiment trend
        const recentSentiments = memory.sentimentTrend.slice(-5);
        const sentimentValues = recentSentiments.map(s => {
            switch (s.sentiment) {
                case 'positive': return 1;
                case 'neutral': return 0;
                case 'negative': return -1;
                default: return 0;
            }
        });

        const avgSentiment = sentimentValues.reduce((a, b) => a + b, 0) / sentimentValues.length;

        // Detect trend direction
        const firstHalf = sentimentValues.slice(0, Math.floor(sentimentValues.length / 2));
        const secondHalf = sentimentValues.slice(Math.floor(sentimentValues.length / 2));
        const firstAvg = firstHalf.length > 0 ? firstHalf.reduce((a, b) => a + b, 0) / firstHalf.length : 0;
        const secondAvg = secondHalf.length > 0 ? secondHalf.reduce((a, b) => a + b, 0) / secondHalf.length : 0;

        const trend = secondAvg - firstAvg;

        // Determine recommendation
        let direction = 'stable';
        let recommendation = 'maintain_momentum';

        if (avgSentiment > 0.3 || trend > 0.3) {
            direction = 'warming';
            recommendation = 'push_for_close';
        } else if (avgSentiment < -0.3 || trend < -0.3) {
            direction = 'cooling';
            recommendation = 'de_escalate';
        } else if (memory.rapportLevel < 30) {
            direction = 'at_risk';
            recommendation = 'rebuild_rapport';
        }

        return {
            direction,
            recommendation,
            rapportLevel: memory.rapportLevel,
            avgSentiment,
            trend
        };
    }

    // ========================================
    // PHASE 9: WALK-AWAY INTELLIGENCE
    // ========================================

    // Assess if the negotiation is still viable
    assessViability(negotiation, listing) {
        const state = negotiation.negotiationState || {};
        const memory = negotiation.memory || {};

        // Death signals that indicate we should walk away
        const deathSignals = {
            hardNo: false,
            priceGapTooLarge: false,
            rejectionLimit: false,
            rapportDead: false
        };

        // Check for hard rejection language in recent messages
        const recentLandlordMessages = negotiation.messages
            .filter(m => m.sender === 'landlord')
            .slice(-3)
            .map(m => m.content.toLowerCase())
            .join(' ');

        if (/absolutely not|never|no way|not negotiable|don't bother|waste.?of.?time/i.test(recentLandlordMessages)) {
            deathSignals.hardNo = true;
        }

        // Check if price gap is too large (they want >110% of our max)
        const landlordCounters = state.landlordCounters || [];
        if (landlordCounters.length > 0) {
            const theirMin = Math.min(...landlordCounters);
            const ourMax = Math.round(listing.price * 0.90);
            if (theirMin > ourMax * 1.15) {
                deathSignals.priceGapTooLarge = true;
            }
        }

        // Check rejection limit
        if ((state.offersRejected || 0) >= 6) {
            deathSignals.rejectionLimit = true;
        }

        // Check rapport level
        if (memory.rapportLevel !== undefined && memory.rapportLevel < 20) {
            deathSignals.rapportDead = true;
        }

        // Calculate viability score (0-100)
        let viability = 100;
        if (deathSignals.hardNo) viability -= 50;
        if (deathSignals.priceGapTooLarge) viability -= 30;
        if (deathSignals.rejectionLimit) viability -= 25;
        if (deathSignals.rapportDead) viability -= 20;
        viability = Math.max(0, viability);

        // Determine recommendation
        let recommendation = 'continue';
        if (viability <= 0) {
            recommendation = 'walk_away';
        } else if (viability <= 30) {
            recommendation = 'final_offer';
        } else if (viability <= 50) {
            recommendation = 'change_approach';
        }

        return {
            viable: viability > 30,
            viability,
            deathSignals,
            recommendation,
            reason: this.getViabilityReason(deathSignals, viability)
        };
    }

    // Get human-readable reason for viability assessment
    getViabilityReason(deathSignals, viability) {
        const reasons = [];

        if (deathSignals.hardNo) {
            reasons.push('landlord gave hard rejection');
        }
        if (deathSignals.priceGapTooLarge) {
            reasons.push('price gap too large to bridge');
        }
        if (deathSignals.rejectionLimit) {
            reasons.push('exceeded maximum rejection attempts');
        }
        if (deathSignals.rapportDead) {
            reasons.push('rapport has deteriorated significantly');
        }

        if (reasons.length === 0) {
            return viability >= 70 ? 'negotiation progressing normally' : 'negotiation challenging but viable';
        }

        return reasons.join('; ');
    }

    // Generate graceful walk-away message
    generateWalkAwayMessage(negotiation, listing) {
        const messages = [
            `I appreciate your time. It seems we're too far apart on price. If anything changes, I'm still interested in ${listing.title}. Best of luck!`,
            `Thank you for considering my offer. We couldn't quite make the numbers work, but I wish you the best in finding the right tenant.`,
            `I understand we couldn't come to terms. If your situation changes, I'd still love to rent this place. Thanks for the conversation.`,
            `It looks like we're not going to be able to make this work, and I respect that. If things change on your end, feel free to reach out. Take care!`,
            `I've really enjoyed this place, but the numbers just don't work for me. I hope you find a great tenant. Best wishes!`
        ];

        return messages[Math.floor(Math.random() * messages.length)];
    }

    // ========================================
    // ADVANCED CONTEXTUAL INTELLIGENCE
    // ========================================

    // Extract specific points landlord makes for intelligent acknowledgment
    extractLandlordKeyPoints(landlordMessage) {
        const message = landlordMessage.toLowerCase();
        const keyPoints = {
            propertyFeatures: [],
            concerns: [],
            justifications: [],
            flexibilitySignals: []
        };

        // Property features mentioned
        const featurePatterns = {
            'big house': /big house|large house|spacious|huge place/i,
            'renovated': /renovated|updated|new|modern/i,
            'location': /great location|prime location|good area|nice neighborhood/i,
            'amenities': /amenities|pool|gym|parking|utilities included/i,
            'yard': /yard|garden|outdoor space|patio/i,
            'bedrooms': /\d+ bedrooms?|bedroom/i
        };

        for (const [feature, pattern] of Object.entries(featurePatterns)) {
            if (pattern.test(message)) {
                keyPoints.propertyFeatures.push(feature);
            }
        }

        // Landlord concerns
        const concernPatterns = {
            'vacancy cost': /vacant|empty|sitting empty|need to fill/i,
            'quality tenant': /reliable|good tenant|responsible|references/i,
            'market rate': /market rate|what others pay|going rate/i,
            'expenses': /mortgage|taxes|expenses|costs/i
        };

        for (const [concern, pattern] of Object.entries(concernPatterns)) {
            if (pattern.test(message)) {
                keyPoints.concerns.push(concern);
            }
        }

        // Justifications for price
        const justificationPatterns = {
            'minimum needed': /minimum|lowest|cant go lower|need at least/i,
            'other offers': /other offers?|someone else|another person/i,
            'worth more': /worth more|valued at|priced fairly/i
        };

        for (const [justification, pattern] of Object.entries(justificationPatterns)) {
            if (pattern.test(message)) {
                keyPoints.justifications.push(justification);
            }
        }

        // Flexibility signals
        const flexibilityPatterns = {
            'maybe': /maybe|might|could consider|let me think/i,
            'depends': /depends|if you|as long as/i,
            'counter-offer': /how about|what about|could you do/i
        };

        for (const [signal, pattern] of Object.entries(flexibilityPatterns)) {
            if (pattern.test(message)) {
                keyPoints.flexibilitySignals.push(signal);
            }
        }

        return keyPoints;
    }

    // Detect positive/negative signals in negotiation
    detectNegotiationSignals(currentMessage, previousMessages, negotiation) {
        const signals = {
            priceMovement: 'none', // 'dropped', 'raised', 'held_firm', 'none'
            tone: 'neutral', // 'warming', 'cooling', 'neutral'
            urgency: 'none', // 'high', 'medium', 'low', 'none'
            willingness: 'uncertain' // 'high', 'medium', 'low', 'uncertain'
        };

        const message = currentMessage.toLowerCase();
        const state = negotiation.negotiationState || {};

        // Detect price movement (CRITICAL for strategy)
        if (state.landlordCounters && state.landlordCounters.length >= 2) {
            const lastCounter = state.landlordCounters[state.landlordCounters.length - 1];
            const prevCounter = state.landlordCounters[state.landlordCounters.length - 2];

            if (lastCounter < prevCounter) {
                signals.priceMovement = 'dropped'; // LANDLORD IS NEGOTIATING - VERY POSITIVE!
            } else if (lastCounter > prevCounter) {
                signals.priceMovement = 'raised'; // Getting worse
            } else {
                signals.priceMovement = 'held_firm';
            }
        }

        // Detect tone
        const warmPhrases = /appreciate|understand|fair|reasonable|let me think|maybe|consider/i;
        const coolPhrases = /no way|impossible|not interested|too low|waste of time/i;

        if (warmPhrases.test(message)) {
            signals.tone = 'warming';
        } else if (coolPhrases.test(message)) {
            signals.tone = 'cooling';
        }

        // Detect urgency
        const urgentPhrases = /need to fill|vacant|asap|immediately|this week|running out/i;
        if (urgentPhrases.test(message)) {
            signals.urgency = 'high';
        }

        // Detect willingness to negotiate
        const willingPhrases = /how about|what if|could you|maybe|let me think|depends/i;
        const unwillingPhrases = /final|take it or leave it|not negotiable|firm on/i;

        if (willingPhrases.test(message)) {
            signals.willingness = 'high';
        } else if (unwillingPhrases.test(message)) {
            signals.willingness = 'low';
        }

        return signals;
    }

    // Craft contextual response that acknowledges landlord's specific points
    craftContextualAcknowledgment(keyPoints, signals, listing) {
        const acknowledgments = [];

        // Acknowledge property features mentioned
        if (keyPoints.propertyFeatures.length > 0) {
            const feature = keyPoints.propertyFeatures[0];
            const featureResponses = {
                'big house': "I totally get that it's a big house - that's exactly what I need",
                'renovated': "I appreciate that it's been renovated, that definitely adds value",
                'location': "The location is definitely a plus, I agree",
                'amenities': "The amenities are great, I see the value",
                'yard': "The outdoor space is a big draw for me"
            };
            acknowledgments.push(featureResponses[feature] || "I appreciate that point");
        }

        // Respond to flexibility signals
        if (signals.priceMovement === 'dropped') {
            acknowledgments.push("I appreciate you working with me on this");
        }

        // Respond to urgency
        if (signals.urgency === 'high') {
            acknowledgments.push("I can move fast - ready to sign this week if we align");
        }

        // Respond to tone
        if (signals.tone === 'warming') {
            acknowledgments.push("I feel like we're getting close here");
        }

        return acknowledgments.length > 0
            ? acknowledgments[Math.floor(Math.random() * acknowledgments.length)]
            : null;
    }

    // ========================================
    // PHASE 10: PROPERTY PERSONALIZATION
    // ========================================

    // Generate property-specific personalization context
    getPropertyPersonalization(listing) {
        const personalizations = [];

        // Location-based
        if (listing.city) {
            personalizations.push(`I like that it's in ${listing.city}`);
        }

        // Room configuration
        if (listing.bedrooms) {
            if (listing.bedrooms === 1) {
                personalizations.push("The one-bedroom setup is perfect for me");
            } else if (listing.bedrooms === 2) {
                personalizations.push("The second bedroom would make a great home office");
            } else if (listing.bedrooms >= 3) {
                personalizations.push(`The ${listing.bedrooms} bedrooms give me the space I need`);
            }
        }

        // Property type
        if (listing.house_type) {
            const typeComments = {
                'apartment': "I've been specifically looking for an apartment like this",
                'house': "A house gives me the space and privacy I'm looking for",
                'condo': "A condo is perfect - I like the balance of space and amenities",
                'studio': "A studio is exactly what I need - efficient and cozy",
                'room': "This room setup works well for my situation"
            };
            if (typeComments[listing.house_type.toLowerCase()]) {
                personalizations.push(typeComments[listing.house_type.toLowerCase()]);
            }
        }

        // Title-based (extract features)
        if (listing.title) {
            const titleLower = listing.title.toLowerCase();
            if (/modern|renovated|updated|new/i.test(titleLower)) {
                personalizations.push("I love that it's been updated");
            }
            if (/view|scenic|overlooking/i.test(titleLower)) {
                personalizations.push("The view is incredible");
            }
            if (/spacious|large|big/i.test(titleLower)) {
                personalizations.push("The spacious layout is exactly what I wanted");
            }
            if (/quiet|peaceful|serene/i.test(titleLower)) {
                personalizations.push("I really value a quiet environment");
            }
            if (/pet|dog|cat/i.test(titleLower)) {
                personalizations.push("Pet-friendly is a must for me");
            }
        }

        // Return 1-2 random personalizations
        if (personalizations.length === 0) {
            return `I really like ${listing.title || 'this property'}`;
        }

        const shuffled = personalizations.sort(() => Math.random() - 0.5);
        return shuffled.slice(0, Math.min(2, shuffled.length)).join('. ');
    }

    // ========================================
    // PROPERTY JUSTIFICATION SYSTEM
    // ========================================

    // Analyze property to build negotiation justifications with data-backed reasoning
    analyzePropertyJustifications(listing, marketData, userBudget) {
        const justifications = {
            trueCostFactors: [],
            marketComparisons: [],
            propertyFactors: [],
            valuePropositions: []
        };

        // 1. TRUE COST ANALYSIS - Calculate all additional costs
        let additionalCosts = 0;

        if (listing.utilities_cost && listing.utilities_cost > 0) {
            additionalCosts += listing.utilities_cost;
            justifications.trueCostFactors.push({
                type: 'utilities',
                amount: listing.utilities_cost,
                description: `Utilities add $${listing.utilities_cost}/month (not included in base rent)`
            });
        }

        if (listing.parking_fee && listing.parking_fee > 0) {
            additionalCosts += listing.parking_fee;
            justifications.trueCostFactors.push({
                type: 'parking',
                amount: listing.parking_fee,
                description: `Parking is $${listing.parking_fee}/month extra`
            });
        }

        if (listing.internet_cost && listing.internet_cost > 0) {
            additionalCosts += listing.internet_cost;
            justifications.trueCostFactors.push({
                type: 'internet',
                amount: listing.internet_cost,
                description: `Internet adds $${listing.internet_cost}/month`
            });
        }

        if (listing.pet_fee && listing.pet_fee > 0) {
            additionalCosts += listing.pet_fee;
            justifications.trueCostFactors.push({
                type: 'pet_fee',
                amount: listing.pet_fee,
                description: `Pet fee adds $${listing.pet_fee}/month`
            });
        }

        if (listing.amenity_fees && listing.amenity_fees > 0) {
            additionalCosts += listing.amenity_fees;
            justifications.trueCostFactors.push({
                type: 'amenity_fees',
                amount: listing.amenity_fees,
                description: `Amenity fees add $${listing.amenity_fees}/month`
            });
        }

        // Calculate true total cost
        if (additionalCosts > 0) {
            const trueCost = listing.price + additionalCosts;
            justifications.trueCostFactors.push({
                type: 'total',
                amount: trueCost,
                description: `True monthly cost is $${trueCost} (${listing.price} + $${additionalCosts} in fees)`,
                savings: trueCost - userBudget,
                additionalCosts: additionalCosts
            });
        }

        // 2. MARKET COMPARISON - Compare to similar properties
        if (marketData && marketData.average) {
            const difference = listing.price - marketData.average;
            if (difference > 100) {
                justifications.marketComparisons.push({
                    type: 'above_market',
                    marketAvg: marketData.average,
                    difference: difference,
                    description: `Similar ${listing.bedrooms}BR ${listing.house_type}s in ${listing.city} average $${marketData.average}/month`,
                    percentage: Math.round((difference / marketData.average) * 100)
                });
            }
        }

        // 3. PROPERTY-SPECIFIC FACTORS

        // Time on market (if listing is old)
        if (listing.created_at) {
            const daysOnMarket = Math.floor((Date.now() - new Date(listing.created_at).getTime()) / (1000 * 60 * 60 * 24));
            if (daysOnMarket > 30) {
                justifications.propertyFactors.push({
                    type: 'time_on_market',
                    days: daysOnMarket,
                    weeks: Math.floor(daysOnMarket / 7),
                    description: `Property has been listed for ${Math.floor(daysOnMarket / 7)} weeks - demand may be softer`
                });
            }
        }

        // Utilities not included
        if (listing.utilities === 'Not included' || (!listing.utilities && additionalCosts > 0)) {
            justifications.propertyFactors.push({
                type: 'no_utilities',
                description: 'Utilities not included means higher total cost for tenant'
            });
        }

        // Extract property issues from description
        const description = (listing.description || '').toLowerCase();

        if (description.includes('ground floor') || description.includes('first floor') || description.includes('1st floor')) {
            justifications.propertyFactors.push({
                type: 'ground_floor',
                description: 'Ground floor units typically rent for 5-10% less than upper floors'
            });
        }

        if (description.includes('corner unit')) {
            justifications.propertyFactors.push({
                type: 'corner_unit',
                description: 'Corner units often have less privacy and more exterior walls (higher heating/cooling costs)'
            });
        }

        if (description.includes('basement') || description.includes('lower level')) {
            justifications.propertyFactors.push({
                type: 'basement',
                description: 'Basement units typically rent for 10-15% less than above-ground units'
            });
        }

        // 4. VALUE PROPOSITIONS (what tenant offers)
        justifications.valuePropositions = [
            'do immediate signing with no delays',
            'commit to a long-term lease (12-18 months available)',
            'provide excellent credit and rental history',
            'offer strong references from previous landlords',
            'be flexible on move-in date to fit your schedule',
            'handle all utilities and maintenance responsibly',
            'provide first and last month\'s rent upfront'
        ];

        return justifications;
    }

    // Craft persuasive message with specific justifications and data
    craftJustifiedOffer(offer, listing, marketData, justifications, keyPoints) {
        const messages = [];

        // 1. ACKNOWLEDGE landlord's specific point first (builds rapport)
        if (keyPoints && keyPoints.propertyFeatures && keyPoints.propertyFeatures.length > 0) {
            const feature = keyPoints.propertyFeatures[0];
            const acknowledgments = {
                'big house': "I get that it's a big house - that's exactly what I'm looking for",
                'renovated': "The renovations definitely add value, I appreciate that",
                'location': "The location is great, I agree",
                'amenities': "The amenities are nice",
                'spacious': "I love the spacious layout",
                'yard': "The outdoor space is a huge plus"
            };
            if (acknowledgments[feature]) {
                messages.push(acknowledgments[feature]);
            }
        }

        // 2. BUILD THE JUSTIFICATION (pick strongest 1-2 points)
        const justificationParts = [];

        // True cost justification (STRONGEST - concrete numbers)
        const trueCostTotal = justifications.trueCostFactors.find(j => j.type === 'total');
        if (trueCostTotal && trueCostTotal.additionalCosts > 150) {
            justificationParts.push(
                `when I factor in the additional costs (utilities, parking, etc. = $${trueCostTotal.additionalCosts}/month), the true monthly cost becomes $${trueCostTotal.amount}`
            );
        } else if (trueCostTotal && trueCostTotal.additionalCosts > 0) {
            justificationParts.push(
                `with $${trueCostTotal.additionalCosts}/month in additional fees, the total comes to $${trueCostTotal.amount}`
            );
        }

        // Market comparison (STRONG - social proof)
        const marketComp = justifications.marketComparisons[0];
        if (marketComp && marketComp.difference > 300) {
            justificationParts.push(
                `similar ${listing.bedrooms}BR ${listing.house_type}s in ${listing.city} are averaging $${marketComp.marketAvg}/month`
            );
        }

        // Property factor (SUPPORTING - logical reasoning)
        const propertyFactor = justifications.propertyFactors[0];
        if (propertyFactor && justificationParts.length < 2) {
            const factorPhrases = {
                'time_on_market': `I noticed it's been on the market for ${propertyFactor.weeks} weeks`,
                'no_utilities': 'utilities being separate adds significantly to monthly costs',
                'ground_floor': 'ground floor units typically go for a bit less due to noise and privacy',
                'corner_unit': 'corner units usually rent for 5-10% below interior units',
                'basement': 'basement units typically rent below above-ground units'
            };
            if (factorPhrases[propertyFactor.type]) {
                justificationParts.push(factorPhrases[propertyFactor.type]);
            }
        }

        // 3. CONSTRUCT THE MESSAGE
        let message = '';

        // Start with acknowledgment if we have one
        if (messages.length > 0) {
            message = messages[0] + '. ';
        }

        // Add justifications
        if (justificationParts.length > 0) {
            message += 'But ' + justificationParts.join(', and ') + '. ';
        }

        // 4. STATE THE OFFER with VALUE-ADD
        const valueAddIndex = Math.floor(Math.random() * Math.min(3, justifications.valuePropositions.length));
        const valueAdd = justifications.valuePropositions[valueAddIndex];

        message += `I'm genuinely at $${offer}, and I can ${valueAdd}. Can we make this work?`;

        return message;
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
            const aiUserId = '00000000-0000-0000-0000-000000000001'; // Fixed UUID for AI user

            // Use upsert to create or update AI user - avoids 409 conflicts
            const { error: upsertError } = await this.supabase
                .from('users')
                .upsert({
                    id: aiUserId,
                    email: aiEmail,
                    first_name: 'AI',
                    last_name: 'Negotiator',
                    is_verified: true,
                    created_at: new Date().toISOString()
                }, {
                    onConflict: 'email',
                    ignoreDuplicates: true
                });

            if (upsertError) {
                console.log('AI user upsert note:', upsertError.message);
                // Not a critical error - user may already exist
            } else {
                console.log('✅ AI user ready');
            }

            this.aiUserInitialized = true;
            return true;

        } catch (error) {
            console.error('Error ensuring AI user exists:', error);
            // Don't fail completely - continue with existing functionality
            this.aiUserInitialized = true;
            return true;
        }
    }

    // Get RentCast API market data (real-time market data)
    async getRentCastMarketData(listing) {
        try {
            console.log('🏠 Fetching RentCast market data for:', listing.city);

            // Prepare request parameters
            const params = new URLSearchParams({
                city: listing.city || '',
                state: listing.state || listing.province || 'ON', // Default to Ontario if not specified
                bedrooms: listing.bedrooms || '',
                propertyType: this.mapHouseTypeToRentCast(listing.house_type)
            });

            // Add postal code if available
            if (listing.postal_code) {
                params.append('zipCode', listing.postal_code);
            }

            const response = await fetch(`https://api.rentcast.io/v1/avm/rent/long-term?${params}`, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json',
                    'X-Api-Key': this.rentcastApiKey
                }
            });

            if (!response.ok) {
                console.log('⚠️ RentCast API error:', response.status);
                return null;
            }

            const data = await response.json();
            console.log('✅ RentCast data received:', data);

            // Format RentCast response to match our structure
            const stats = {
                average: Math.round(data.rent || data.rentEstimate || 0),
                median: Math.round(data.rent || data.rentEstimate || 0),
                min: Math.round((data.rent || data.rentEstimate || 0) * 0.85), // Estimate -15%
                max: Math.round((data.rent || data.rentEstimate || 0) * 1.15), // Estimate +15%
                count: 1,
                confidence: data.confidence || 'medium',
                priceRange: data.priceRange || null,
                source: 'rentcast'
            };

            return stats;

        } catch (error) {
            console.error('❌ Error fetching RentCast data:', error);
            return null;
        }
    }

    // Map our house types to RentCast property types
    mapHouseTypeToRentCast(houseType) {
        const mapping = {
            'Apartment': 'Apartment',
            'House': 'Single Family',
            'Condo': 'Condo',
            'Townhouse': 'Townhouse',
            'Duplex': 'Multi Family',
            'Studio': 'Apartment',
            'Loft': 'Apartment',
            'Basement': 'Single Family'
        };
        return mapping[houseType] || 'Apartment';
    }

    // Get real market data for pricing analysis
    async getMarketData(location, houseType, bedrooms, listing = null) {
        const cacheKey = `${location}-${houseType}-${bedrooms}`;

        // Check cache first
        if (this.marketData.has(cacheKey)) {
            console.log('📊 Using cached market data for:', cacheKey);
            return this.marketData.get(cacheKey);
        }

        try {
            console.log('🔍 Gathering market data for:', { location, houseType, bedrooms });

            // PRIORITY 1: Try RentCast API if we have listing details (limited to 1 call per negotiation)
            if (listing && this.rentcastApiKey) {
                const negotiationId = listing.id;

                // Check if we already used RentCast for this negotiation
                if (!this.rentcastCache.has(negotiationId)) {
                    console.log('🎯 Using RentCast API (1st call for this negotiation)');
                    const rentcastData = await this.getRentCastMarketData(listing);

                    if (rentcastData) {
                        // Cache for this specific negotiation
                        this.rentcastCache.set(negotiationId, rentcastData);
                        this.marketData.set(cacheKey, rentcastData);
                        console.log('📊 RentCast market data:', rentcastData);
                        return rentcastData;
                    }
                } else {
                    console.log('♻️ Using cached RentCast data for this negotiation');
                    return this.rentcastCache.get(negotiationId);
                }
            }

            // PRIORITY 2: Query database for similar properties
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
            const data = await this.postJSON('/api/negotiate/market-estimate', { location, houseType, bedrooms });
            const marketData = data.marketData || {};

            return { ...marketData, count: marketData.count ?? 0, source: marketData.source || 'ai_estimate' };

        } catch (error) {
            console.warn('⚠️ AI market analysis unavailable, using estimates');

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

            // STRATEGIC PRICING: Start at 65-75% of listing price
            // CRITICAL: Never offer MORE than the listing price - that's absurd
            // Cap at listing price, then apply discount
            const maxOffer = listing.price; // Never go above asking price
            const budgetBasedStart = Math.round(Math.min(userBudget, maxOffer) * 0.75);
            const priceBasedStart = Math.round(listing.price * 0.70);

            // Use the lower of the two, but cap at listing price
            const strategicStart = Math.min(
                Math.max(budgetBasedStart, priceBasedStart),
                maxOffer
            );

            // Apply Ackerman pricing - precise number feels calculated
            const initialOffer = Math.min(this.getAckermanPrice(strategicStart), maxOffer);

            // Check if market data supports our position
            const marketSupportsUs = marketData.average && marketData.average < listing.price;

            // PHASE 10: Get property personalization for opening
            const propertyPersonalization = this.getPropertyPersonalization(listing);

            // PHASE 2: Default to playful voice for opening
            const voice = this.voiceProfiles.playful;
            const voiceInstructions = this.getVoiceInstructions(voice);

            // PHASE 5: Select opening Cialdini principle (liking for rapport)
            const openingPrinciple = this.cialdiniPrinciples.liking;

            const prompt = `
You are an ELITE NEGOTIATOR making first contact. Confident, direct, professional. No fluff.

===== VOICE: PLAYFUL/POSITIVE =====
${voiceInstructions}

===== PROPERTY =====
- ${listing.title} in ${listing.city}
- Asking: $${listing.price}/month
- Type: ${listing.house_type}, ${listing.bedrooms} bedrooms

===== PROPERTY PERSONALIZATION =====
Express genuine interest by referencing: "${propertyPersonalization}"

===== YOUR OPENING OFFER =====
$${initialOffer}/month (strategic anchor - room to negotiate up)

===== MARKET INTELLIGENCE =====
${marketSupportsUs ? `Market average: $${marketData.average}/month - USE THIS to justify your offer!` : 'No useful market data - focus on your value as a tenant'}

===== CIALDINI PRINCIPLE: LIKING =====
${openingPrinciple.description}
Build rapport through genuine appreciation of the property.

===== ELITE OPENING TACTICS =====
1. Express genuine interest using property personalization (1 sentence max)
2. State your offer as a CONSTRAINT: "My budget allows $${initialOffer}" (Phantom Authority - subtle)
3. Mention you're ready to sign immediately (creates urgency for them)
4. Keep it SHORT - 2 sentences MAX. Long messages = desperation.

===== NLP TRIGGERS =====
✅ USE: "I need", "The goal is", "Fair", "I like"
❌ AVOID: "I think", "Maybe", "Would you consider", "Please"

===== EXAMPLE FORMAT =====
"[Property detail that caught your eye]. My budget allows $${initialOffer}/month - I'm a reliable tenant ready to sign today."

Generate ONLY the message. No greetings, no signatures.
`;

            const data = await this.postJSON('/api/negotiate/contextual-response', { prompt });
            const message = (data.response || '').trim();
            if (!message) throw new Error('Empty negotiation message');

            console.log('✅ Generated elite negotiation message with offer:', initialOffer);
            return message;

        } catch (error) {
            console.warn('⚠️ AI unavailable, using elite fallback');

            // Strategic fallback - still uses elite style
            // CRITICAL: Never offer more than the listing price
            const maxOffer = listing.price;
            const strategicStart = Math.min(
                Math.round(listing.price * 0.70),
                maxOffer
            );
            const initialOffer = Math.min(this.getAckermanPrice(strategicStart), maxOffer);

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

            // PHASE 6: Update landlord personality profile
            negotiation.landlordProfile = this.analyzeLandlordPersonality(negotiation.messages.concat([{
                sender: 'landlord',
                content: message.content
            }]));
            console.log('👤 Updated landlord profile:', negotiation.landlordProfile);

            // PHASE 7: Update conversation memory
            this.updateConversationMemory(negotiation, message.content, null, analysis);
            console.log('🧠 Updated conversation memory:', negotiation.memory);

            // PHASE 8: Detect escalation
            const escalation = this.detectEscalation(negotiation);
            console.log('📈 Escalation status:', escalation);

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
                    window.aiNegotiator.appendMessage('Landlord', `💬 "${message.content}"`, 'left');
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

                    // Calculate natural response delay based on context
                    const responseDelay = this.calculateResponseDelay({
                        messageLength: message.content?.length || 0,
                        responseLength: response.length,
                        emotionalContent: analysis.sentiment === 'negative' || analysis.sentiment === 'positive',
                        isComplexDecision: analysis.makesCounterOffer || analysis.isFinalized
                    });
                    console.log('⏱️ Using natural delay:', responseDelay, 'ms');
                    await new Promise(resolve => setTimeout(resolve, responseDelay));

                    // Send the response
                    console.log('📤 Sending response to conversation:', conversationId);
                    const sentSuccessfully = await this.sendNegotiationMessage(
                        conversationId,
                        response,
                        negotiation.userEmail,
                        negotiation.landlordEmail,
                        negotiation.listingTitle
                    );
                    
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
                                    window.aiNegotiator.appendMessage('Landlord', `💬 "${message.content}"`, 'left');
                                    window.aiNegotiator.appendMessage('AI Negotiator', `🤖 "${response}"`, 'right');
                                    window.aiNegotiator.appendMessage('System', successMessage, 'left');
                                    window.aiNegotiator.celebrateSuccess();
                                    console.log('✅ Direct UI update successful!');
                                } else {
                                    console.log('⚠️ Window AI negotiator not available for direct update');
                                }
                            } catch (error) {
                                console.log('❌ Direct UI update failed:', error.message);
                            }
                            
                            // PRIORITY 2: Try database notification
                            try {
                                console.log('💾 [NEGOTIATION] Attempting to notify tenant of deal acceptance...');
                                await this.notifyNegotiationComplete(negotiation, message.content);
                                console.log('✅ [NEGOTIATION] Tenant notification sent successfully');
                            } catch (dbError) {
                                console.error('❌ [NEGOTIATION] Database notification failed:', dbError);
                                console.error('❌ [NEGOTIATION] Error details:', {
                                    message: dbError.message,
                                    code: dbError.code,
                                    details: dbError.details,
                                    hint: dbError.hint
                                });
                                // Try alternative notification via direct message
                                console.log('🔄 [NEGOTIATION] Attempting fallback notification method...');
                                try {
                                    await this.sendDirectNotification(negotiation, message.content);
                                } catch (fallbackError) {
                                    console.error('❌ [NEGOTIATION] Fallback notification also failed:', fallbackError);
                                }
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
                                    window.aiNegotiator.appendMessage('AI Negotiator', `🤖 "${response}"`, 'right');
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
                    // Calculate natural delay for market-based response
                    const marketDelay = this.calculateResponseDelay({
                        messageLength: message.content?.length || 0,
                        responseLength: marketResponse.length,
                        emotionalContent: true, // Rejections are emotional
                        isComplexDecision: true
                    });
                    console.log('⏱️ Using market response delay:', marketDelay, 'ms');
                    await new Promise(resolve => setTimeout(resolve, marketDelay));
                    await this.sendNegotiationMessage(
                        conversationId,
                        marketResponse,
                        negotiation.userEmail,
                        negotiation.landlordEmail,
                        negotiation.listingTitle
                    );
                    
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
                            window.aiNegotiator.appendMessage('Landlord', `❌ "${message.content}"`, 'left');
                            window.aiNegotiator.appendMessage('AI Negotiator', `🤖 Counter-offer sent: "${marketResponse}"`, 'right');
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

                // PHASE 4: Use response variation engine for witty redirects
                const conversationId = negotiation?.listingId || 'default';
                const uniqueResponse = this.getUniqueResponse(conversationId, 'witty_redirects', {
                    offer: nextOffer
                });

                if (uniqueResponse) {
                    return uniqueResponse;
                }

                // Fallback
                return `Ha! I appreciate the creativity, but I'm here for the apartment, not a date. So... $${nextOffer}/month - we doing this or what?`;
            }
        }

        // Only catch truly random/test messages (not negotiation responses)
        if (/^(lol|lmao|haha|bruh|test|testing|asdf|hello|hi|hey|yo|sup|wassup|how are you)$/i.test(lower)) {
            const nextOffer = this.getAckermanPrice(currentOffer + 25);

            // PHASE 4: Use response variation engine for playful redirects
            const conversationId = negotiation?.listingId || 'default';
            const uniqueResponse = this.getUniqueResponse(conversationId, 'playful_redirects', {
                offer: nextOffer
            });

            if (uniqueResponse) {
                return uniqueResponse;
            }

            // Fallback
            return `Haha, I feel you. But real talk - $${nextOffer}/month, can we make it happen?`;
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
        // Remove punctuation and trim
        const simpleReply = replyContent.trim().toLowerCase().replace(/[!.,?]+$/g, '');

        // Enhanced acceptance detection - catches more variations of positive responses
        const isSimpleAcceptance = /^(sure|yes|ok|okay|sounds good|works|fine|agreed|deal|sounds great|yep|yeah|absolutely|lets do it|im in|done|accept|perfect|great|excellent)(\s+(that|it|this))?\s*(works|sounds good|sounds great|for me|lets do it)?[!.?]*$/i.test(simpleReply) ||
                                   /^(i|we|that|it|this)?\s*(accept|agree|sounds good|works for me|that works|lets do this|im down)$/i.test(simpleReply) ||
                                   /\b(you got it|you have a deal|deal|sold|im in)\b/i.test(simpleReply);

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
            const lastOffer = state.lastOffer || negotiation.userBudget;

            // Calculate our counter: try to match competing offer, but NEVER go below our last offer
            const maxOffer = Math.round(listing.price * 0.90);
            let ourCounter;

            if (competingPrice <= maxOffer) {
                // We can potentially match the competing offer
                ourCounter = Math.min(competingPrice, maxOffer);
            } else {
                // Competing offer is above our max - offer our maximum
                ourCounter = maxOffer;
            }

            // CRITICAL: Never go BELOW what we already offered - that's backwards negotiation!
            ourCounter = Math.max(ourCounter, lastOffer + 25);
            ourCounter = Math.min(ourCounter, maxOffer); // Still respect max cap

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
            // Use percentage-based increment that scales with property value
            const increment = this.calculatePercentageIncrement(listing.price, state.concessionCount || 0);
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

            const data = await this.postJSON('/api/negotiate/analyze-reply', {
                replyContent,
                negotiationState: negotiation?.negotiationState,
                listing
            });

            const analysis = data.analysis;
            if (!analysis) throw new Error('Empty analysis');

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
                const lastOffer = state.lastOffer || negotiation.userBudget;

                // CRITICAL: Never go BELOW what we already offered!
                // When landlord claims competing offer, we should increase from our last offer
                // or match the competing price if we can afford it - NEVER decrease
                let ourCounter;

                if (competingPrice <= maxOffer) {
                    // We can potentially match - offer our max or match, whichever is lower
                    ourCounter = Math.min(competingPrice, maxOffer);
                } else {
                    // Competing offer is above our max - offer our maximum
                    ourCounter = maxOffer;
                }

                // NEVER go below our last offer - that's terrible negotiation
                ourCounter = Math.max(ourCounter, lastOffer + 25);

                // Cap at maxOffer
                ourCounter = Math.min(ourCounter, maxOffer);

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

                // PHASE 4: Use dynamic message constructor for competing offer responses
                const landlordProfile = negotiation.landlordProfile || { emotionalState: 'neutral' };
                const dynamicResponse = this.constructDynamicMessage(
                    'competing_offer_responses',
                    { competing: competingPrice, offer: ackermanCounter },
                    landlordProfile,
                    negotiation
                );

                if (dynamicResponse) {
                    return dynamicResponse;
                }

                // Fallback if all responses used
                return `$${competingPrice}? That's strong. My budget is capped at $${ackermanCounter}. Help me bridge that gap?`;
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

                // PHASE 4: Use dynamic message constructor for authentic rejection responses
                const landlordProfile = negotiation.landlordProfile || { emotionalState: 'neutral' };
                const dynamicResponse = this.constructDynamicMessage(
                    'rejection_counters',
                    { offer: nextOffer },
                    landlordProfile,
                    negotiation
                );

                if (dynamicResponse) {
                    return dynamicResponse;
                }

                // Fallback if all responses used
                return `It sounds like that doesn't work. What would make $${nextOffer} work today?`;
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
        // Use percentage-based increment that scales with property value
        const increment = this.calculatePercentageIncrement(listing.price, state.concessionCount);

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
        console.log('📊 Concession #', negotiation.negotiationState.concessionCount);

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
            listing.city, listing.house_type, listing.bedrooms, listing
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

        // Calculate next offer with percentage-based increment
        const increment = this.calculatePercentageIncrement(listing.price, state.concessionCount);

        // CRITICAL: Never offer more than 90% of listing price - leave room to negotiate
        let suggestion = Math.min(baseline + increment, maxReasonableOffer);

        // NEVER repeat an offer
        while (state.offersMade.includes(suggestion) && suggestion < maxReasonableOffer) {
            suggestion += 5;
        }

        // If we've hit max, use dynamic message constructor for max offer responses
        if (suggestion >= maxReasonableOffer) {
            // PHASE 4: Use dynamic message constructor for authentic max offer responses
            const landlordProfile = negotiation?.landlordProfile || { emotionalState: 'neutral' };
            const dynamicResponse = this.constructDynamicMessage(
                'max_offer_responses',
                { offer: maxReasonableOffer },
                landlordProfile,
                negotiation
            );

            if (dynamicResponse) {
                return dynamicResponse;
            }

            // Fallback if all responses used
            return `$${maxReasonableOffer}/month is genuinely my max. I'm a reliable tenant ready to sign today. Can we make this work?`;
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

            const data = await this.postJSON('/api/negotiate/contextual-response', { prompt });
            const responseText = (data.response || '').trim();
            if (!responseText) throw new Error('Empty contextual response');

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
        } catch (error) {
            console.error('Error generating contextual response:', error);
        }

        // Fallback with calibrated question (never repeats same offer)
        const state = negotiation.negotiationState || { lastOffer: negotiation.userBudget };
        return `How can we make this work? I'm a reliable tenant ready to sign immediately. What would it take to get to $${state.lastOffer}?`;
    }

    // Send negotiation message and notify landlord
    // Build a deterministic UUID v5 from a string. Two browsers/tabs computing this
    // with the same input produce the EXACT same UUID — used below as the AI
    // response's primary key so Postgres' uniqueness constraint hard-stops races.
    async _deterministicUUID(input) {
        const data = new TextEncoder().encode(`roomfinder-ai-response:${input}`);
        const hashBuf = await crypto.subtle.digest('SHA-1', data);
        const bytes = new Uint8Array(hashBuf);
        bytes[6] = (bytes[6] & 0x0f) | 0x50;  // version 5
        bytes[8] = (bytes[8] & 0x3f) | 0x80;  // RFC 4122 variant
        const hex = Array.from(bytes.slice(0, 16)).map(b => b.toString(16).padStart(2, '0')).join('');
        return `${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20,32)}`;
    }

    async sendNegotiationMessage(conversationId, message, userEmail, landlordEmail = null, listingTitle = null, respondsToMessageId = null) {
        try {
            // Ensure AI user exists first
            await this.ensureAIUserExists();

            const senderEmail = 'ai-negotiator@roomfinder.com';
            const fullContent = `🤖 AI Negotiator on behalf of ${userEmail}:\n\n${message}`;
            const createdAt = new Date().toISOString();
            let finalSenderEmail = senderEmail;
            let finalContent = fullContent;

            // If we know which landlord message we're responding to, derive a deterministic
            // primary key for THIS AI reply. Two tabs/sessions racing the same OpenAI call
            // will both compute the same uuid; Postgres' PK uniqueness ensures only one
            // INSERT wins. The loser gets 23505 and bails — never a duplicate user-visible
            // message, no matter how many sessions raced.
            const insertPayload = {
                conversation_id: conversationId,
                sender_email: senderEmail,
                content: fullContent,
                created_at: createdAt
            };
            if (respondsToMessageId) {
                try {
                    insertPayload.id = await this._deterministicUUID(respondsToMessageId);
                } catch (e) {
                    console.warn('Could not derive deterministic id (proceeding without dedup):', e.message);
                }
            }

            const { error } = await this.supabase
                .from('messages')
                .insert(insertPayload);

            // 23505 = unique_violation = another session already inserted the same AI
            // response for this landlord message. We've definitively lost the race. Bail.
            if (error?.code === '23505') {
                console.log('📨 Lost dedup race — another session already responded to this landlord message. Skipping.');
                return false;
            }

            if (error) {
                console.error('Error sending negotiation message with AI email:', error);

                // Fallback: try using the user's email instead
                console.log('Retrying with user email...');
                finalSenderEmail = userEmail;
                finalContent = `🤖 AI Negotiator:\n\n${message}`;
                const { error: retryError } = await this.supabase
                    .from('messages')
                    .insert({
                        conversation_id: conversationId,
                        sender_email: finalSenderEmail,
                        content: finalContent,
                        created_at: createdAt
                    });

                if (retryError) {
                    console.error('Error sending negotiation message with user email:', retryError);
                    return false;
                }
            }

            console.log('✅ Sent negotiation message');

            // Live broadcast on the same chat-{conversationId} channel the docked chat
            // subscribes to in listings.html. Without this the landlord's screen has to
            // wait for the postgres_changes path (500ms-2s) to surface the AI's reply.
            // Fire-and-forget; the DB INSERT above is the source of truth.
            try {
                const ch = this.supabase.channel(`chat-${conversationId}`);
                ch.subscribe((status) => {
                    if (status !== 'SUBSCRIBED') return;
                    ch.send({
                        type: 'broadcast',
                        event: 'new_message',
                        payload: {
                            conversation_id: conversationId,
                            sender_email: finalSenderEmail,
                            content: finalContent,
                            message_type: 'text',
                            created_at: createdAt
                        }
                    }).finally(() => {
                        // Short-lived channel; clean up after the send so we don't leak.
                        setTimeout(() => { try { ch.unsubscribe(); } catch (e) {} }, 500);
                    });
                });
            } catch (broadcastErr) {
                console.warn('AI broadcast send failed (non-fatal):', broadcastErr);
            }

            // Create notification for landlord in ai_chats table
            if (landlordEmail) {
                try {
                    console.log('🔔 Creating notification for landlord:', landlordEmail);

                    // Include conversation metadata for reply functionality
                    const notificationContent = [{
                        role: 'assistant',
                        content: `📬 New inquiry from ${userEmail}:\n\n"${message.substring(0, 200)}${message.length > 200 ? '...' : ''}"`,
                        metadata: {
                            conversation_id: conversationId,
                            tenant_email: userEmail,
                            listing_title: listingTitle
                        }
                    }];

                    const { error: notifError } = await this.supabase
                        .from('ai_chats')
                        .insert({
                            user_email: landlordEmail,
                            conversation_data: JSON.stringify(notificationContent),
                            title: `New Inquiry: ${listingTitle || 'Your Property'}`
                        });

                    if (notifError) {
                        console.error('⚠️ Failed to create landlord notification:', notifError);
                    } else {
                        console.log('✅ Created notification for landlord with conversation_id:', conversationId);
                    }
                } catch (notifError) {
                    console.error('⚠️ Error creating landlord notification:', notifError);
                }
            }

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

                        // Dedup: only the TENANT'S browser should generate the AI's next
                        // reply. Without this gate, every browser/tab subscribed to this
                        // conversation (tenant tab + landlord tab + any duplicate session)
                        // fires its own OpenAI call against the same landlord message →
                        // N near-identical AI responses get spammed into the chat.
                        // The AI Negotiator works on behalf of the tenant, so we ground
                        // the gate on conversation.sender_email (the tenant).
                        const meEmail = JSON.parse(localStorage.getItem('currentUser') || '{}')?.email?.toLowerCase();
                        const tenantEmail = conversation?.sender_email?.toLowerCase();
                        if (!meEmail || !tenantEmail || meEmail !== tenantEmail) {
                            console.log('📨 Skipping AI response — this session is not the tenant for this negotiation', { me: meEmail, tenant: tenantEmail });
                            return;
                        }

                        // Per-message lock: if we already started processing this exact
                        // landlord message, skip. Cheap in-memory guard against the same
                        // INSTANCE firing twice for any reason (re-subscribe, duplicate
                        // INSERT events, etc.).
                        if (!this._processedLandlordMessages) this._processedLandlordMessages = new Set();
                        if (this._processedLandlordMessages.has(newMessage.id)) {
                            console.log('📨 Already processed landlord message', newMessage.id, '— skipping duplicate');
                            return;
                        }
                        this._processedLandlordMessages.add(newMessage.id);

                        // DB-level lock across instances: another AINegotiator instance
                        // (different tab, different page in the same browser, etc.) has
                        // its own _processedLandlordMessages Set, so the in-memory gate
                        // can't catch cross-instance duplicates. Check Postgres for an
                        // existing AI reply timestamped after this landlord message — if
                        // any session already responded, we don't generate another.
                        try {
                            const { data: alreadyResponded } = await this.supabase
                                .from('messages')
                                .select('id')
                                .eq('conversation_id', newMessage.conversation_id)
                                .eq('sender_email', 'ai-negotiator@roomfinder.com')
                                .gt('created_at', newMessage.created_at)
                                .limit(1);
                            if (alreadyResponded && alreadyResponded.length > 0) {
                                console.log('📨 AI already responded in DB for this landlord message — another session won the race, skipping');
                                return;
                            }
                        } catch (lockErr) {
                            console.warn('⚠️ DB dedup check failed (proceeding anyway):', lockErr.message);
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
                                console.log('🚀 [PHASED v2] Starting human-like reply handler...');

                                // Try to find existing negotiation state, or create one
                                let negotiationId = null;
                                for (const [id, neg] of this.activeNegotiations.entries()) {
                                    if (neg.listingId === listing.id) {
                                        negotiationId = id;
                                        break;
                                    }
                                }

                                // If no existing negotiation, create a new conversation state
                                if (!negotiationId) {
                                    negotiationId = `neg_conv_${conversation.id}`;
                                    // Get user budget from localStorage or use default
                                    const savedBudget = localStorage.getItem('ai_negotiation_budget');
                                    const userBudget = savedBudget ? parseInt(savedBudget) : listing.price * 0.85;
                                    this.initConversationState(negotiationId, listing, userBudget, conversation.sender_email);
                                    // Set phase based on message count (if we already sent intro, move to next phase)
                                    const state = this.getConversationState(negotiationId);
                                    if (state) {
                                        state.currentPhase = 'RAPPORT_BUILDING'; // Landlord replied, so we're past intro
                                    }
                                }

                                // Use the NEW phased reply handler
                                const response = await this.handleLandlordReplyWithPhases(
                                    newMessage.content,
                                    negotiationId,
                                    listing
                                );

                                if (response && response.message) {
                                    // Apply human-like delay
                                    const delay = response.delay || 2000;
                                    console.log(`⏳ Waiting ${delay}ms before responding...`);
                                    await new Promise(resolve => setTimeout(resolve, delay));

                                    // Send the phased response. Pass newMessage.id as the
                                    // dedup key — the AI's INSERT will use a deterministic
                                    // UUID derived from it, and the DB enforces uniqueness.
                                    await this.sendNegotiationMessage(
                                        conversation.id,
                                        response.message,
                                        conversation.sender_email,
                                        listing.user_email,
                                        listing.title,
                                        newMessage.id
                                    );
                                    console.log(`✅ [PHASED v2] Sent ${response.phase} response`);
                                }
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
            const marketData = await this.getMarketData(cleanCity, listing.house_type, listing.bedrooms, listing);

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
                },
                // PHASE 6: Landlord personality profile
                landlordProfile: this.getDefaultLandlordProfile(),
                // PHASE 7: Conversation memory
                memory: {
                    landlordConcerns: [],
                    effectivePhrases: [],
                    ineffectivePhrases: [],
                    rapportLevel: 50, // Start neutral (0-100)
                    topicsDiscussed: [],
                    sentimentTrend: []
                },
                // PHASE 10: Property personalization
                propertyPersonalization: this.getPropertyPersonalization(listing)
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
                listing.city, listing.house_type, listing.bedrooms, listing
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

            // PHASE 6: Analyze landlord personality from message history
            const landlordProfile = this.analyzeLandlordPersonality(negotiation.messages);
            negotiation.landlordProfile = landlordProfile;
            console.log('👤 Landlord profile:', landlordProfile);

            // ADVANCED: Extract landlord's specific points for intelligent acknowledgment
            const keyPoints = this.extractLandlordKeyPoints(landlordMessage);
            console.log('🔍 Landlord key points:', keyPoints);

            // ADVANCED: Detect negotiation signals (price movement, tone, willingness)
            const signals = this.detectNegotiationSignals(landlordMessage, negotiation.messages, negotiation);
            console.log('🚦 Negotiation signals:', signals);

            // JUSTIFICATION SYSTEM: Analyze property to build data-backed reasoning
            const justifications = this.analyzePropertyJustifications(listing, marketData, negotiation.userBudget);
            console.log('📊 Property justifications:', justifications);

            // PHASE 7: Update conversation memory
            this.updateConversationMemory(negotiation, landlordMessage, null, analysis);
            const memory = negotiation.memory || {};
            console.log('🧠 Conversation memory:', memory);

            // PHASE 8: Detect escalation direction
            const escalation = this.detectEscalation(negotiation);
            console.log('📈 Escalation detection:', escalation);

            // PHASE 9: Assess deal viability
            const viability = this.assessViability(negotiation, listing);
            console.log('💡 Deal viability:', viability);

            // If deal is dead, generate walk-away message
            if (viability.recommendation === 'walk_away') {
                console.log('🚶 Generating walk-away message - deal no longer viable');
                return this.generateWalkAwayMessage(negotiation, listing);
            }

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

            // Incremental concession logic: percentage-based increases that scale with property value
            const increment = this.calculatePercentageIncrement(listing.price, state.concessionCount);
            nextOffer = Math.min(lastOffer + increment, maxOffer); // Cap at 90%, not 100%

            // CRITICAL: Make sure we NEVER offer the same price twice
            while (state.offersMade.includes(nextOffer) && nextOffer < maxOffer) {
                nextOffer += 5;
            }

            // Apply Ackerman pricing - precise numbers feel calculated, not arbitrary
            const ackermanOffer = this.getAckermanPrice(nextOffer);

            console.log('   - Next offer will be:', nextOffer, '(Ackerman:', ackermanOffer, ', increment:', increment, ')');

            // PHASE 2: Select voice based on context
            const voice = this.getVoiceForContext(landlordProfile, state.currentPhase, state.offersRejected);
            const voiceInstructions = this.getVoiceInstructions(voice);
            console.log('🎙️ Selected voice:', voice.name);

            // PHASE 3: Select tactic intelligently based on context
            const tacticContext = {
                messageContent: landlordMessage,
                emotionalContent: analysis?.sentiment === 'negative' || landlordProfile.emotionalState === 'frustrated',
                rejectionCount: state.offersRejected,
                priceObjection: /price|too low|can't accept|firm/i.test(landlordMessage),
                recentTactics: state.tacticsUsed,
                landlordProfile: landlordProfile,
                phase: state.currentPhase
            };
            const intelligentTactic = this.selectTacticForContext(tacticContext);
            const tacticInstructions = this.getTacticInstructions(intelligentTactic);
            console.log('🎯 Selected tactic:', intelligentTactic);

            // PHASE 5: Select Cialdini principle
            const cialdiniContext = {
                phase: state.currentPhase,
                rejectionCount: state.offersRejected,
                landlordProfile: landlordProfile,
                hasMarketData: marketData.average && Math.abs(marketData.average - listing.price) > 50
            };
            const selectedPrinciple = this.selectCialdiniPrinciple(cialdiniContext);
            const principleInfo = this.cialdiniPrinciples[selectedPrinciple];
            console.log('🔮 Selected Cialdini principle:', selectedPrinciple);

            // Build full conversation history
            const fullHistory = negotiation.messages.map(m => `${m.sender.toUpperCase()}: ${m.content}`).join('\n');

            // Check if market data is actually useful (different from listing price)
            const hasUsefulMarketData = marketData.average && Math.abs(marketData.average - listing.price) > 50;

            // Calculate vacancy cost for loss aversion
            const weeklyVacancyCost = Math.round(listing.price / 4);

            // PHASE 10: Get property personalization
            const propertyContext = negotiation.propertyPersonalization || this.getPropertyPersonalization(listing);

            // Craft contextual acknowledgment based on key points and signals
            const contextualAck = this.craftContextualAcknowledgment(keyPoints, signals, listing);

            const prompt = `
You are an ELITE NEGOTIATOR with tactical empathy. You sound like a REAL PERSON having a genuine conversation, not a robot.

===== VOICE FOR THIS MESSAGE: ${voice.name.toUpperCase()} =====
${voiceInstructions}

===== LANDLORD PROFILE =====
- Style: ${landlordProfile.style}
- Emotional State: ${landlordProfile.emotionalState}
- Warmth Level: ${landlordProfile.warmthLevel}/100
- Concerns: ${landlordProfile.concerns.join(', ') || 'none detected yet'}

===== CONVERSATION MEMORY =====
- Rapport Level: ${memory.rapportLevel || 50}/100
- Escalation: ${escalation.direction} (${escalation.recommendation})
- Their Concerns: ${memory.landlordConcerns?.join(', ') || 'none yet'}
- Topics Discussed: ${memory.topicsDiscussed?.join(', ') || 'none yet'}

===== LANDLORD'S MESSAGE =====
"${landlordMessage}"

===== INTELLIGENT CONTEXT ANALYSIS =====
**Property Features They Mentioned:** ${keyPoints.propertyFeatures.length > 0 ? keyPoints.propertyFeatures.join(', ') : 'none'}
**Their Concerns:** ${keyPoints.concerns.length > 0 ? keyPoints.concerns.join(', ') : 'none'}
**Their Justifications:** ${keyPoints.justifications.length > 0 ? keyPoints.justifications.join(', ') : 'none'}
**Flexibility Signals:** ${keyPoints.flexibilitySignals.length > 0 ? keyPoints.flexibilitySignals.join(', ') : 'none'}

**CRITICAL SIGNALS DETECTED:**
- Price Movement: ${signals.priceMovement} ${signals.priceMovement === 'dropped' ? '⚠️ THEY ARE NEGOTIATING DOWN - VERY POSITIVE!' : ''}
- Tone: ${signals.tone}
- Urgency: ${signals.urgency}
- Willingness to Negotiate: ${signals.willingness}

${contextualAck ? `**SUGGESTED ACKNOWLEDGMENT:** "${contextualAck}" (weave this in naturally if it fits)` : ''}

===== CONVERSATION HISTORY =====
${fullHistory || 'First exchange'}

===== PROPERTY & CONSTRAINTS =====
- Property: ${listing.title} in ${listing.city}
- Asking: $${listing.price}/month
- Your offer: $${ackermanOffer}/month
- Hard ceiling: $${maxOffer}/month (NEVER exceed)

===== TACTIC FOR THIS RESPONSE: ${intelligentTactic.toUpperCase()} =====
${tacticInstructions}

===== CIALDINI PRINCIPLE TO WEAVE IN: ${principleInfo.name.toUpperCase()} =====
${principleInfo.description}
Examples: ${principleInfo.examples.slice(0, 2).join('; ')}

===== PROPERTY JUSTIFICATIONS (USE THESE TO BUILD YOUR CASE!) =====
${justifications.trueCostFactors.length > 0 ? `
**TRUE COST ANALYSIS:**
${justifications.trueCostFactors.map(j => `- ${j.description}`).join('\n')}
${justifications.trueCostFactors.find(j => j.type === 'total') ? `\n⚠️ CRITICAL: Show landlord the math! Base rent + fees = TRUE COST` : ''}
` : ''}
${justifications.marketComparisons.length > 0 ? `
**MARKET DATA:**
${justifications.marketComparisons.map(j => `- ${j.description} (${j.percentage}% above market)`).join('\n')}
` : ''}
${justifications.propertyFactors.length > 0 ? `
**PROPERTY FACTORS:**
${justifications.propertyFactors.map(j => `- ${j.description}`).join('\n')}
` : ''}

**SUGGESTED JUSTIFIED RESPONSE:**
"${this.craftJustifiedOffer(ackermanOffer, listing, marketData, justifications, keyPoints)}"
(Use this as inspiration - make it YOUR OWN with natural language)

===== PROPERTY PERSONALIZATION =====
Reference if natural: "${propertyContext}"

===== PSYCHOLOGICAL WEAPONS =====

**ACKERMAN FRAMING** - Use precise numbers:
- Offer $${ackermanOffer} (not round numbers like $${Math.round(nextOffer / 100) * 100})
- Precise numbers feel like real limits, not arbitrary guesses

**NLP TRIGGERS**:
✅ USE: "Correct", "Fair", "The goal is", "Let's resolve", "I need"
❌ AVOID: "I think", "Maybe", "Can we", "Please", "How about"

**LOSS AVERSION WITH MATH**:
- Weekly vacancy cost: $${weeklyVacancyCost}
- Use sparingly: "Every week vacant costs you $${weeklyVacancyCost}."

===== CRITICAL RULES =====
1. **JUSTIFY YOUR OFFER WITH DATA** - Don't just state a price! Use the justifications above:
   - If utilities/fees aren't included → Show the TRUE COST math
   - If above market average → Reference comparable properties
   - If property has been on market long → Mention it tactfully
   Example: "I get it's a big house. But with $250/month in utilities, the true cost is $6,625, and similar 4BR houses here average $6,200..."
2. **ACKNOWLEDGE THEIR SPECIFIC POINTS FIRST** - If they mentioned "big house" or other features, acknowledge it naturally before pivoting to price
3. **READ THE SIGNALS** - If price movement is "dropped", they're negotiating! Say something like "I appreciate you working with me"
4. **VARY YOUR LANGUAGE** - Don't repeat phrases like "my budget is capped" or "I'm a reliable tenant" - be creative and natural
5. **MAX 2-3 sentences** - Be concise but human-sounding. Long text = desperation
6. Use ${voice.name} voice tone throughout
7. Apply ${intelligentTactic} tactic naturally (don't announce it, just DO it)
8. Weave in ${principleInfo.name} principle subtly
9. State offer as CONSTRAINT not REQUEST ("I'm at $X" not "Can you do $X?")
10. End with strategic question or offer, then STOP
11. NEVER exceed $${maxOffer}
12. ${hasUsefulMarketData ? `USE market data strategically: Average is $${marketData.average}` : 'NO market data - pivot to tenant quality and certainty'}
13. NEVER repeat an offer already made: ${state.offersMade.join(', ') || 'none'}
14. **SOUND HUMAN** - Use conversational language, contractions, natural flow. You're a person, not a chatbot!

Generate ONLY the response message. No explanations. No "As an AI". Just the human-sounding negotiation message.
`;

            const data = await this.postJSON('/api/negotiate/counter-offer', {
                prompt,
                conversationHistory: []
            });
            const negotiationResponse = (data.response || '').trim();
            if (!negotiationResponse) throw new Error('Empty market-based response');

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
            // Smarter price extraction - look for offer context first, then fall back to LAST price
            let extractedPrice = null;

            // Method 1: Look for offer-context patterns (most reliable)
            const offerPatterns = [
                /(?:I can do|I offer|my offer is|how about|I'll go|let's do|I'm at|stretch to|cap at|best I can do is)\s*\$(\d+)/i,
                /\$(\d+)\s*(?:is my|is where I|that's my|that's where|works for me)/i
            ];

            for (const pattern of offerPatterns) {
                const match = negotiationResponse.match(pattern);
                if (match) {
                    extractedPrice = parseInt(match[1]);
                    console.log('📊 Found offer via context pattern:', extractedPrice);
                    break;
                }
            }

            // Method 2: Fall back to LAST price mentioned (not first) - offers typically come at end
            if (!extractedPrice) {
                const allPrices = negotiationResponse.match(/\$(\d+)/g);
                if (allPrices && allPrices.length > 0) {
                    const lastPrice = allPrices[allPrices.length - 1];
                    extractedPrice = parseInt(lastPrice.replace('$', ''));
                    console.log('📊 Using last price mentioned:', extractedPrice, 'from', allPrices.length, 'prices found');
                }
            }

            // Method 3: Validate price is within expected bounds before tracking
            if (extractedPrice) {
                const minExpected = (negotiation.userBudget || startingPoint) * 0.8; // 80% of user budget
                const maxExpected = maxOffer + 10; // Slightly above max offer for tolerance

                if (extractedPrice >= minExpected && extractedPrice <= maxExpected) {
                    negotiation.negotiationState.offersMade.push(extractedPrice);
                    negotiation.negotiationState.lastOffer = extractedPrice;
                    negotiation.negotiationState.concessionCount++;
                    console.log('📊 Tracked new offer:', extractedPrice, 'Concession count:', negotiation.negotiationState.concessionCount);
                } else {
                    console.warn('⚠️ Extracted price out of bounds:', extractedPrice,
                        'Expected range:', minExpected, '-', maxExpected, '- NOT tracking this price');
                }
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
            console.log('🎉 Sending enhanced negotiation completion notification for user:', negotiation.userEmail);

            // Calculate savings and percentage
            const savings = negotiation.originalPrice - negotiation.finalPrice;
            const savingsPercent = Math.round((savings / negotiation.originalPrice) * 100);
            const landlordReply = landlordMessage ? `\n\n**Landlord's Response:** "${landlordMessage}"` : '';

            // Enhanced next steps guidance
            const nextSteps = [
                'Contact landlord to schedule viewing/signing',
                'Prepare required documents (ID, references, pay stubs)',
                'Review and sign lease agreement',
                'Arrange security deposit and first month rent'
            ];

            const notificationData = {
                user_email: negotiation.userEmail,
                conversation_data: JSON.stringify([{
                    role: 'assistant',
                    content: `🎉 **NEGOTIATION SUCCESSFUL!**\n\nProperty: ${negotiation.listingTitle}\nFinal Price: $${negotiation.finalPrice}/month\nOriginal Price: $${negotiation.originalPrice}/month\nYou Saved: $${savings}/month (${savingsPercent}%)${landlordReply}\n\n**Next Steps:**\n${nextSteps.map((step, i) => `${i + 1}. ${step}`).join('\n')}\n\n✅ Your AI negotiator will continue to assist with the next phase.`,
                    timestamp: new Date().toISOString()
                }]),
                title: `Deal Accepted: ${negotiation.listingTitle}`
            };

            console.log('📝 Enhanced notification data:', notificationData);

            // Store in-app notification
            const { data, error } = await this.supabase
                .from('ai_chats')
                .insert(notificationData);

            if (error) {
                console.error('❌ Database error:', error);
                throw error;
            }

            console.log('✅ In-app notification sent successfully');

            // Send browser push notification if supported and permitted
            if (typeof window !== 'undefined' && 'Notification' in window) {
                if (Notification.permission === 'granted') {
                    try {
                        new Notification('Rental Deal Accepted! 🎉', {
                            body: `${negotiation.listingTitle} - $${negotiation.finalPrice}/month (Saved $${savings}!)`,
                            icon: '/assets/success-icon.png',
                            badge: '/assets/badge-icon.png',
                            tag: `negotiation-success-${negotiation.listingId}`,
                            requireInteraction: true,
                            vibrate: [200, 100, 200]
                        });
                        console.log('✅ Browser push notification sent');
                    } catch (notifError) {
                        console.warn('Browser notification failed:', notifError);
                    }
                } else if (Notification.permission === 'default') {
                    // Request permission for future notifications
                    Notification.requestPermission().then(permission => {
                        console.log('Notification permission:', permission);
                    });
                }
            }

            console.log('✅ Negotiation completion notification process complete');

        } catch (error) {
            console.error('Error notifying negotiation complete:', error);
            throw error; // Re-throw to allow fallback handling
        }
    }

    // Fallback notification method using direct message to conversation
    async sendDirectNotification(negotiation, landlordMessage) {
        try {
            console.log('📤 [FALLBACK] Sending direct notification via messages table');

            const successMessage = `🎉 DEAL ACCEPTED!\n\nThe landlord has accepted your offer for ${negotiation.listingTitle}!\n\nFinal Price: $${negotiation.finalPrice}/month\nOriginal Price: $${negotiation.originalPrice}/month\n\nLandlord's response: "${landlordMessage}"\n\n✅ Next steps: Contact the landlord to finalize the rental agreement.`;

            // Send as a message in the conversation
            const { error } = await this.supabase
                .from('messages')
                .insert({
                    conversation_id: negotiation.conversationId,
                    sender_email: 'ai-negotiator@roomfinder.com',
                    message_text: successMessage,
                    created_at: new Date().toISOString()
                });

            if (error) {
                console.error('❌ [FALLBACK] Direct notification failed:', error);
                throw error;
            }

            console.log('✅ [FALLBACK] Direct notification sent successfully');
        } catch (error) {
            console.error('❌ [FALLBACK] sendDirectNotification error:', error);
            throw error;
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