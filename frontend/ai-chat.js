// AI Chat functionality for the negotiator with Supabase database integration
// This handles messaging, database search, and negotiation logic

class AIChatHandler {
    constructor(supabase, config) {
        this.supabase = supabase;
        this.config = config;
        this.currentUser = null;
        this.conversationHistory = [];
        this.userNeeds = {
            maxPrice: null,
            minPrice: null,
            preferredLocation: null,
            houseType: null,
            bedrooms: null,
            utilities: null
        };
        this.matchingListings = [];
        this.negotiationState = 'idle';
        this.activeNegotiations = new Map();
        this.lastMessageTime = 0;
        this.negotiationEngine = null;
        
        // Track active conversation contexts
        this.activeConversations = new Map();
        this.pendingUserResponse = null;

        // Requirements collection state - must collect ALL before searching
        this.requiredFields = {
            budget: null,
            bedrooms: null,
            location: null
        };
        this.requirementsComplete = false;
        this.listingSelectionMode = false;
        this.currentViewedListing = null;

        // Per-AIChat-instance memory of which conversations already had an
        // intro message sent. Without this, multiple entry paths
        // (manual Contact, startNegotiationsForAllListings, post-affirmation
        // auto-trigger) each re-fire generatePhaseMessage('INTRODUCTION')
        // and the landlord receives 2-3 near-duplicate "Hey saw your listing"
        // messages back-to-back.
        this.sentIntroConversations = new Set();
    }

    // Initialize the chat system
    async init(currentUser) {
        this.currentUser = currentUser;
        
        // Load previous conversation history
        await this.loadConversationHistory();
        
        // Setup user profile for messaging
        const setupSuccess = await this.setupAIUser();
        if (!setupSuccess) {
            this.appendMessage('AI', 'Warning: Messaging setup incomplete. Please register/login to send messages to landlords.', 'left');
        }
        
        // Only show welcome message if no previous conversation
        if (this.conversationHistory.length === 0) {
            this.showWelcomeWithChips();
        }
    }

    // Show welcome message with quick start chips
    showWelcomeWithChips() {
        const chatMessages = document.getElementById('chatMessages');
        if (!chatMessages) return;

        chatMessages.innerHTML = `
            <div class="chat-bubble ai">
                <p>I can help you find a rental and negotiate a lower price with the landlord. What are you looking for?</p>
            </div>
        `;
    }

    // Send quick message from chip
    sendQuickMessage(message) {
        const messageInput = document.getElementById('messageInput');
        if (messageInput) {
            messageInput.value = message;
        }
        this.processMessage(message);
    }

    // Set negotiation engine
    setNegotiationEngine(engine) {
        this.negotiationEngine = engine;
        console.log('🔗 Negotiation engine connected to AI chat');
        
        // Listen for negotiation completion updates
        this.listenForNegotiationUpdates();
    }

    // Listen for negotiation completion updates
    listenForNegotiationUpdates() {
        if (!this.supabase) {
            console.warn('⚠️ Supabase not available for real-time updates');
            return;
        }
        
        if (!this.currentUser?.email) {
            console.warn('⚠️ User email not available for subscription filter');
            return;
        }

        console.log('🔔 Setting up real-time subscription for user:', this.currentUser.email);

        // Unsubscribe from existing channels if any
        if (this.negotiationChannel) {
            console.log('🔄 Removing existing ai_chats subscription');
            this.supabase.removeChannel(this.negotiationChannel);
        }
        if (this.messagesChannel) {
            console.log('🔄 Removing existing messages subscription');
            this.supabase.removeChannel(this.messagesChannel);
        }

        try {
            // Channel 1: Listen to ai_chats for notifications (negotiation success, landlord reply alerts)
            this.negotiationChannel = this.supabase
                .channel(`negotiation_updates_${this.currentUser.email.replace(/[^a-zA-Z0-9]/g, '_')}`)
                .on('postgres_changes', {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'ai_chats'
                }, (payload) => {
                    console.log('📬 Received ai_chats update:', payload);
                    try {
                        const newChat = payload.new;

                        // Filter for current user
                        if (newChat.user_email !== this.currentUser.email) {
                            console.log('📭 Update not for current user, skipping');
                            return;
                        }

                        console.log('📨 Processing ai_chats update for current user:', newChat.title);

                        if (newChat.title && newChat.title.includes('Negotiation Success')) {
                            console.log('🎉 Negotiation success detected!');
                            this.displayNegotiationSuccess(newChat);
                        } else if (newChat.title && newChat.title.includes('Landlord Reply')) {
                            console.log('📧 Landlord reply detected!');
                            this.displayLandlordReply(newChat);
                        } else if (newChat.title && newChat.title.includes('New Inquiry')) {
                            console.log('📨 New inquiry detected!');
                            this.displayNewInquiry(newChat);
                        }
                    } catch (error) {
                        console.error('Error processing ai_chats update:', error);
                    }
                })
                .subscribe();

            console.log('✅ ai_chats subscription established');

            // Channel 2: Listen to messages table for real-time conversation updates
            // This catches AI negotiator responses that landlords need to see
            this.messagesChannel = this.supabase
                .channel(`messages_realtime_${this.currentUser.email.replace(/[^a-zA-Z0-9]/g, '_')}`)
                .on('postgres_changes', {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'messages'
                }, async (payload) => {
                    console.log('📬 Received messages table update:', payload);
                    try {
                        const newMessage = payload.new;

                        // Skip messages sent by the current user
                        if (newMessage.sender_email === this.currentUser.email) {
                            console.log('📭 Own message, skipping');
                            return;
                        }

                        // Get conversation to check if current user is involved
                        const { data: conversation, error: convError } = await this.supabase
                            .from('conversations')
                            .select('*')
                            .eq('id', newMessage.conversation_id)
                            .maybeSingle();

                        if (convError || !conversation) {
                            console.log('📭 Could not find conversation, skipping');
                            return;
                        }

                        // Check if current user is part of this conversation
                        const isInvolved = conversation.sender_email === this.currentUser.email ||
                                          conversation.receiver_email === this.currentUser.email;

                        if (!isInvolved) {
                            console.log('📭 User not involved in this conversation, skipping');
                            return;
                        }

                        console.log('📨 New message in user conversation:', newMessage.content?.substring(0, 50));

                        // Display the new message in chat
                        this.displayIncomingMessage(newMessage, conversation);

                    } catch (error) {
                        console.error('Error processing messages update:', error);
                    }
                })
                .subscribe();

            console.log('✅ messages subscription established');

        } catch (error) {
            console.error('❌ Failed to setup real-time subscriptions:', error);
        }
    }

    // Display incoming message from messages table
    displayIncomingMessage(message, conversation) {
        try {
            // Determine the sender label
            let senderLabel = 'Tenant';
            if (message.sender_email.includes('ai-negotiator')) {
                senderLabel = 'AI Negotiator';
            } else if (message.sender_email === conversation.receiver_email) {
                senderLabel = 'Tenant';
            } else if (message.sender_email === conversation.sender_email) {
                senderLabel = 'Tenant';
            }

            // Check if this is an AI message on behalf of tenant.
            // Detect both the new footer format ("— Sent via RoomFinder AI")
            // and the legacy header ("AI Negotiator on behalf of") so older
            // messages still classify correctly.
            if (message.content && (
                message.content.includes('Sent via RoomFinder AI') ||
                message.content.includes('AI Negotiator on behalf of')
            )) {
                senderLabel = 'AI Negotiator';
            }

            this.appendMessage(senderLabel, message.content || 'New message received', 'left');

            // Play notification sound if available
            this.playNotificationSound();

        } catch (error) {
            console.error('Error displaying incoming message:', error);
            this.appendMessage('System', 'New message received', 'left');
        }
    }

    // Play notification sound
    playNotificationSound() {
        try {
            // Create a simple notification sound
            const audioContext = new (window.AudioContext || window.webkitAudioContext)();
            const oscillator = audioContext.createOscillator();
            const gainNode = audioContext.createGain();

            oscillator.connect(gainNode);
            gainNode.connect(audioContext.destination);

            oscillator.frequency.value = 800;
            oscillator.type = 'sine';
            gainNode.gain.value = 0.1;

            oscillator.start();
            oscillator.stop(audioContext.currentTime + 0.1);
        } catch (error) {
            // Audio not supported, ignore
        }
    }

    // Display new inquiry notification
    displayNewInquiry(chatData) {
        try {
            const conversationData = JSON.parse(chatData.conversation_data);
            const message = conversationData[0]?.content || 'New inquiry received';
            const metadata = conversationData[0]?.metadata || {};

            this.appendMessage('System', `New inquiry received!\n\n${message}`, 'left');

            // Store conversation context if available
            if (metadata.conversation_id) {
                this.activeConversationId = metadata.conversation_id;
            }
        } catch (error) {
            console.error('Error displaying new inquiry:', error);
            this.appendMessage('System', 'New inquiry received', 'left');
        }
    }

    // Setup AI user profile for messaging
    async setupAIUser() {
        if (!this.currentUser?.email || !this.supabase) {
            return false;
        }

        // If user is logged in (not anonymous), assume they can message
        if (this.currentUser.email !== 'anonymous@user.com') {
            console.log('✅ User is logged in, messaging enabled:', this.currentUser.email);
            return true;
        }

        try {
            const { data: profile, error } = await this.supabase
                .from('profiles')
                .select('*')
                .eq('email', this.currentUser.email)
                .single();

            if (error) {
                console.log('⚠️ Profile not found for anonymous user');
                return false;
            }

            console.log('✅ User profile found for messaging:', profile.first_name);
            return true;
        } catch (error) {
            console.error('Error setting up AI user:', error);
            return false;
        }
    }

    // Build a deterministic markdown list of the user's locked-in negotiation
    // goals. Used by the intent-intercept in processMessage so questions like
    // "what parameters do we have set" always get a reliable list-back,
    // independent of LLM whims.
    formatLockedGoalsForChat() {
        const g = (typeof window !== 'undefined' && typeof window.getTenantGoals === 'function')
            ? window.getTenantGoals()
            : {};
        if (!g || Object.keys(g).length === 0) {
            return "You haven't locked in any negotiation goals yet. Open the **🎯 Your Negotiation Goals** panel above, set what matters to you, then click **🔒 Lock in negotiation goals** to activate them.";
        }
        const lines = ['Here are your locked-in negotiation goals:'];
        if (g.available_days?.length) lines.push(`• Meeting days: ${g.available_days.map(d => d[0].toUpperCase() + d.slice(1)).join(', ')}`);
        if (g.available_time?.length) lines.push(`• Time of day: ${g.available_time.join(', ')}`);
        if (g.meeting_format?.length) lines.push(`• Meeting format: ${g.meeting_format.map(f => f.replace('_', ' ')).join(', ')}`);
        if (g.movein_date) lines.push(`• Move-in date: ${g.movein_date}${g.movein_flexibility ? ' (' + g.movein_flexibility + ')' : ''}`);
        if (g.lease_length) lines.push(`• Lease length: ${g.lease_length}`);
        if (g.monthly_budget) lines.push(`• Monthly budget: $${g.monthly_budget}/mo`);
        if (g.target_reduction) lines.push(`• Target reduction: $${g.target_reduction}/month off asking`);
        const concessions = [g.ask_utilities_included && 'utilities included', g.ask_lower_deposit && 'lower deposit', g.ask_first_month_free && 'first month free'].filter(Boolean);
        if (concessions.length) lines.push(`• Concessions to ask for: ${concessions.join(', ')}`);
        if (g.employment) lines.push(`• Employment: ${g.employment.replace('_', ' ')}`);
        if (g.income_confidence) lines.push(`• Income: ${g.income_confidence}`);
        if (g.pets) lines.push(`• Pets: ${g.pets === 'none' ? 'none' : g.pets}`);
        if (g.non_smoker) lines.push('• Non-smoker: yes');
        if (g.occupants) lines.push(`• Occupants: ${g.occupants}`);
        if (g.must_haves?.length) lines.push(`• Must-haves: ${g.must_haves.map(m => m.replace(/_/g, ' ')).join(', ')}`);
        if (g.tone) lines.push(`• Tone: ${g.tone}`);
        if (g.assertiveness) lines.push(`• Assertiveness: ${g.assertiveness}`);
        lines.push('');
        lines.push('Edit anything in the panel above; the lock automatically clears when you change something, so re-click **🔒 Lock in** to re-activate.');
        return lines.join('\n');
    }

    // Process user message
    async processMessage(message) {
        console.log('🔄 Processing user message:', message);

        // Store user message
        this.appendMessage('You', message, 'right');
        this.conversationHistory.push({ role: 'user', content: message });
        this.saveConversationHistory();

        // Reset negotiation state for new requests
        this.negotiationState = 'idle';

        // Check if this is a negotiation response first
        if (this.checkForNegotiationResponse(message)) {
            return;
        }

        // Pre-fill maxPrice from locked-in monthly_budget so the chat doesn't
        // ask "what's your budget?" when the user already set one in the panel.
        try {
            const _g = (typeof window.getTenantGoals === 'function') ? window.getTenantGoals() : {};
            if (_g.monthly_budget && !this.userNeeds.maxPrice) {
                this.userNeeds.maxPrice = Number(_g.monthly_budget);
                this.requiredFields.budget = Number(_g.monthly_budget);
                console.log('💰 Prefilled max price from locked goals:', _g.monthly_budget);
            }
        } catch (_) { /* non-fatal */ }

        // Intent intercept: any reference to parameters/goals/preferences/
        // settings — even a STATEMENT like "I locked in parameters" — counts
        // as wanting to see or work with the goals. Broadened from earlier
        // (which required BOTH a goal keyword AND a question word) because
        // statements without question words were falling through to the LLM
        // and getting generic "what city?" replies.
        const goalKeyword = /\b(parameter|goal|preference|setting|criteria|negotiation goal|lock(ed)?[\s-]?in)s?\b/i;
        if (goalKeyword.test(message)) {
            console.log('🎯 Goals intent intercepted — replying with locked-in goals locally.');
            const reply = this.formatLockedGoalsForChat();
            this.appendMessage('AI', reply, 'left');
            this.conversationHistory.push({ role: 'assistant', content: reply });
            this.saveConversationHistory();
            return;
        }

        // When the user names a specific listing (common when testing from a
        // second account), resolve it directly instead of falling through to a
        // generic "what city?" loop or an empty Supabase search.
        if (this.looksLikeListingReference(message)) {
            try {
                const hints = await this.findListingsByTextHint(message);
                if (hints.length > 0) {
                    const hit = hints[0];
                    if (!this.userNeeds.preferredLocation && hit.city) {
                        this.userNeeds.preferredLocation = hit.city;
                        this.requiredFields.location = hit.city;
                    }
                    if (!this.userNeeds.maxPrice && hit.price) {
                        this.userNeeds.maxPrice = Number(hit.price);
                        this.requiredFields.budget = Number(hit.price);
                    }
                    this.requirementsComplete = true;
                    this._lastSearchOwnMatch = null;

                    if (hints.length === 1) {
                        const intro = `I found **"${hit.title || 'this listing'}"** in ${hit.city || 'your area'}${hit.price ? ` at $${hit.price}/mo` : ''}. Would you like me to negotiate with the landlord?`;
                        this.appendMessage('AI', intro, 'left');
                        this.conversationHistory.push({ role: 'assistant', content: intro });
                        this.saveConversationHistory();
                        await this.presentListingResults(hints, { skipIntro: true });
                        return;
                    }

                    const intro = `I found ${hints.length} listings that match what you described:`;
                    this.appendMessage('AI', intro, 'left');
                    this.conversationHistory.push({ role: 'assistant', content: intro });
                    this.saveConversationHistory();
                    await this.presentListingResults(hints, { skipIntro: true });
                    return;
                }
            } catch (hintErr) {
                console.warn('Listing hint resolution failed (non-fatal):', hintErr?.message || hintErr);
            }
        }

        try {
            // Call the AI chat endpoint for intelligent conversation
            console.log('🤖 Calling AI chat endpoint...');
            const chatResponse = await this.callAIChatEndpoint(message);

            if (chatResponse.fallback) {
                // API unavailable, fall back to manual extraction
                console.log('⚠️ Falling back to manual extraction');
                const extractedData = this.extractManually(message);
                this.handleExtractedData(extractedData, null);
                return;
            }

            console.log('📊 AI Response:', chatResponse.response?.substring(0, 100));
            console.log('📊 Extracted criteria:', chatResponse.criteria);

            // Display the AI's conversational response
            if (chatResponse.response) {
                this.appendMessage('AI', chatResponse.response, 'left');
                this.conversationHistory.push({ role: 'assistant', content: chatResponse.response });
                this.saveConversationHistory();
            }

            // Handle extracted criteria. Augment OpenAI's price with a local range-aware
            // pass — OpenAI often grabs just the lower bound of a range like "6k to 7k"
            // and we want to search up to the MAX the user is willing to pay.
            if (chatResponse.criteria) {
                const localMax = this.extractPriceFromMessage(message);
                if (localMax && (!chatResponse.criteria.price || localMax > chatResponse.criteria.price)) {
                    console.log('💰 Augmenting OpenAI budget with local range max:', localMax, '(OpenAI had:', chatResponse.criteria.price, ')');
                    chatResponse.criteria.price = localMax;
                }
                this.handleExtractedData(chatResponse.criteria, chatResponse.response);
            }

        } catch (error) {
            console.error('Error processing message:', error);
            // Fall back to manual extraction on error
            const extractedData = this.extractManually(message);
            this.handleExtractedData(extractedData, null);
        }
    }

    // Call the backend AI chat endpoint
    async callAIChatEndpoint(message) {
        try {
            // Forward the user's locked-in negotiation goals so the AI can
            // answer follow-up questions like "do I have pets listed?" or
            // "what's my tone set to?" naturally. The deterministic
            // list-back is handled by the intent-intercept in processMessage;
            // this covers natural-language follow-ups the regex misses.
            const tenantGoals = (typeof window !== 'undefined' && typeof window.getTenantGoals === 'function')
                ? window.getTenantGoals()
                : {};

            const response = await fetch('/api/chat', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    message: message,
                    conversationHistory: this.conversationHistory.slice(-10),
                    userEmail: this.currentUser?.email,
                    tenantGoals
                })
            });

            if (!response.ok) {
                const errorData = await response.json().catch(() => ({}));
                console.error('❌ Chat API error:', response.status, errorData);
                return { fallback: true, error: errorData };
            }

            return await response.json();
        } catch (error) {
            console.error('❌ Error calling chat API:', error);
            return { fallback: true, error: error.message };
        }
    }

    // Handle extracted rental criteria - NEW: Collect ALL requirements before searching
    handleExtractedData(extractedData, aiResponse) {
        // Update user needs from extracted data
        this.updateUserNeeds(extractedData);

        // Update required fields from extracted data
        if (extractedData.price) {
            this.requiredFields.budget = extractedData.price;
            console.log('📝 Captured budget:', extractedData.price);
        }
        if (extractedData.bedrooms) {
            this.requiredFields.bedrooms = extractedData.bedrooms;
            console.log('📝 Captured bedrooms:', extractedData.bedrooms);
        }
        if (extractedData.city) {
            this.requiredFields.location = extractedData.city;
            console.log('📝 Captured location:', extractedData.city);
        }

        // Check if this looks like a rental search intent
        const hasSearchIntent = extractedData.intent === 'search' ||
            extractedData.price || extractedData.city || extractedData.bedrooms ||
            extractedData.house_type;

        if (!hasSearchIntent) {
            // Not a rental search - let the AI response handle it
            console.log('ℹ️ No rental search intent detected');
            return;
        }

        // Check if all requirements are complete
        const status = this.checkRequirementsComplete();
        console.log('🔍 Requirements status:', status);

        if (!status.complete) {
            // The backend AI (/api/chat) already drives the conversation and asks
            // for whatever's missing in natural language. Only emit the scripted
            // fallback question when there is NO AI response (API down / manual
            // extraction) — otherwise we double-message and re-ask for info the
            // user already gave (e.g. repeating "What area or city?" after "toronto").
            if (!aiResponse) {
                this.appendMessage('AI', status.question, 'left');
            }
            console.log(`⏳ Missing requirement: ${status.missing}`);
            return;
        }

        // All requirements complete - now search!
        this.requirementsComplete = true;
        console.log('✅ All requirements collected, starting search...');

        const bedText = this.requiredFields.bedrooms ? `${this.requiredFields.bedrooms}-bedroom ` : '';
        const summary = `Got it! Searching for ${bedText}places in ${this.requiredFields.location} under $${this.requiredFields.budget}/month...`;
        this.appendMessage('AI', summary, 'left');

        setTimeout(() => this.searchAndMessage(), 1000);
    }

    // Extract rental information - now primarily uses API, with manual fallback
    async extractRentalInfo(message) {
        // Try API first, fall back to manual extraction
        const chatResponse = await this.callAIChatEndpoint(message);
        if (chatResponse.fallback || !chatResponse.criteria) {
            console.log('🔍 Using manual extraction for rental criteria...');
            return this.extractManually(message);
        }
        return chatResponse.criteria;
    }

    // Range-aware budget extractor. Returns the MAX of any range expressed in the
    // message, with `k` suffix support. Returns null if no plausible number found.
    // Handles: "6k to 7k", "6000-7000", "$6,000 to $7,500", "between 5 and 7k",
    //          "around 1500", "$6k", "max 7500". For ranges we use MAX because
    //          when a user says "5 to 7k" they mean "willing to pay up to 7k".
    extractPriceFromMessage(message) {
        if (!message) return null;
        const normalized = String(message).replace(/[$,]/g, '').toLowerCase();

        // Range: two numbers connected by to/-/–/—/or/and/until/through, optional k on either
        const range = normalized.match(/(\d+(?:\.\d+)?)\s*(k)?\s*(?:to|-|–|—|or|and|until|through)\s*(\d+(?:\.\d+)?)\s*(k)?/);
        if (range) {
            const useK = range[2] === 'k' || range[4] === 'k';
            const a = parseFloat(range[1]) * (useK ? 1000 : 1);
            const b = parseFloat(range[3]) * (useK ? 1000 : 1);
            const max = Math.max(a, b);
            if (max > 100) return max;
        }

        // Single value with optional intent prefix and optional k suffix
        const single = normalized.match(/(?:under|below|max|up\s*to|for|at|around|about|near|roughly)?\s*(\d+(?:\.\d+)?)\s*(k)?/);
        if (single) {
            const value = parseFloat(single[1]) * (single[2] === 'k' ? 1000 : 1);
            if (value > 100) return value;
        }

        return null;
    }

    // Manual extraction fallback
    extractManually(message) {
        console.log('Using manual extraction for:', message);
        const result = {};

        // Extract price (range-aware, k-suffix-aware)
        const extracted = this.extractPriceFromMessage(message);
        if (extracted) {
            result.price = extracted;
            console.log('💰 Extracted price:', extracted);
        }
        
        // Extract city - international cities
        const cityMatch = message.match(/\b(hong kong|karachi|paris|tehran|toronto|moscow|sydney|vancouver|montreal|calgary|ottawa|edmonton|winnipeg|hamilton|quebec|saskatoon|regina|halifax|london|kitchener|waterloo|windsor|markham|mississauga|brampton|islamabad|lahore|rawalpindi|faisalabad|multan|hyderabad|peshawar|quetta|new york|los angeles|chicago|miami|boston)\b/i);
        if (cityMatch) {
            result.city = cityMatch[1].toLowerCase().trim();
            console.log('🏙️ Extracted city:', result.city);
        }

        // Extract country names as location fallback
        const countryMatch = message.match(/\b(pakistan|canada|usa|united states|uk|united kingdom|australia|france|germany|india|china|japan|iran|russia)\b/i);
        if (countryMatch && !result.city) {
            result.city = countryMatch[1].toLowerCase().trim();
            console.log('🌍 Extracted country as location:', result.city);
        }

        // Flexible "in [location]" pattern - captures any word after "in"
        const inLocationMatch = message.match(/\bin\s+([a-zA-Z\s]+?)(?:\s+for|\s+under|\s+with|\s*$|\s*,|\s*\.)/i);
        if (inLocationMatch && !result.city) {
            const location = inLocationMatch[1].trim().toLowerCase();
            // Only use if it looks like a place name (not common words)
            const skipWords = ['a', 'an', 'the', 'my', 'your', 'this', 'that', 'good', 'nice', 'great'];
            if (!skipWords.includes(location) && location.length > 1) {
                result.city = location;
                console.log('📍 Extracted location from "in" pattern:', result.city);
            }
        }
        
        // Extract house type (fallback only - OpenAI handles this primarily)
        const msg = message.toLowerCase();
        if (msg.includes('apartment')) {
            result.house_type = 'Apartment';
        } else if (msg.includes('condo')) {
            result.house_type = 'Condo';
        } else if (msg.includes('townhouse') || msg.includes('town house')) {
            result.house_type = 'Townhouse';
        } else if (msg.includes('house')) {
            result.house_type = 'House';
        } else if (msg.includes('studio')) {
            result.house_type = 'Studio';
        } else if (msg.includes('basement')) {
            result.house_type = 'Basement';
        } else if (msg.includes('room')) {
            result.house_type = 'Room';
        }
        
        // Extract bedrooms
        const bedroomMatch = message.match(/(\d+)[\s-]?bedroom/i);
        if (bedroomMatch) {
            result.bedrooms = Number(bedroomMatch[1]);
        }
        
        // Set intent
        if (message.toLowerCase().includes('looking for') || 
            message.toLowerCase().includes('need') || 
            message.toLowerCase().includes('want') ||
            message.toLowerCase().includes('find') ||
            message.toLowerCase().includes('search')) {
            result.intent = 'search';
        }
        
        // Backup logic: if we extracted rental criteria, assume search intent
        if ((result.price || result.city) && !result.intent) {
            console.log('🎯 BACKUP LOGIC: Found rental criteria without intent, setting to search');
            result.intent = 'search';
        }
        
        return result;
    }

    // Update user needs from extracted data
    updateUserNeeds(extractedData) {
        console.log('🎯 Updating user needs with:', extractedData);
        
        if (extractedData.price) {
            this.userNeeds.maxPrice = extractedData.price;
            console.log('✅ Set max price:', extractedData.price);
        }
        
        if (extractedData.city) {
            let cleanCity = extractedData.city.toString().trim().toLowerCase();
            cleanCity = cleanCity.split(',')[0].trim();
            cleanCity = cleanCity.replace(/\s+(fr|france|canada|ca|usa|us|australia|au)$/i, '');
            this.userNeeds.preferredLocation = cleanCity;
            console.log('✅ Set location:', cleanCity);
        }
        
        if (extractedData.house_type) {
            this.userNeeds.houseType = extractedData.house_type;
            console.log('✅ Set house type:', extractedData.house_type);
        }
        
        if (extractedData.bedrooms) {
            this.userNeeds.bedrooms = extractedData.bedrooms;
            console.log('✅ Set bedrooms:', extractedData.bedrooms);
        }
        
        if (extractedData.utilities) {
            this.userNeeds.utilities = extractedData.utilities;
            console.log('✅ Set utilities:', extractedData.utilities);
        }
        
        console.log('🔧 Final user needs:', this.userNeeds);
    }

    // Check if all required fields are collected before searching
    checkRequirementsComplete() {
        const { budget, bedrooms, location } = this.requiredFields;
        console.log('🔍 Checking requirements:', { budget, bedrooms, location });

        // Check in priority order: location, budget, bedrooms
        if (!location) {
            return {
                complete: false,
                missing: 'location',
                question: "What area or city are you looking to rent in?"
            };
        }
        if (!budget) {
            return {
                complete: false,
                missing: 'budget',
                question: "What's your monthly budget for rent?"
            };
        }
        // Bedrooms is OPTIONAL. Requiring it made the assistant loop forever when
        // the user said "no preferences" — it never collected a bedroom count, so
        // it never searched (and findMatchingListings doesn't even filter on
        // bedrooms). Once we have location + budget, search; bedrooms only refines
        // the summary line if it happens to be known.
        console.log('✅ Core requirements complete (location + budget)!');
        return { complete: true };
    }

    // Fetch listings via backend API (service role) so every logged-in account
    // sees the same public inventory. Direct Supabase anon queries can return
    // empty under RLS and made the negotiator look "random" on new accounts.
    async fetchListingsFromApi() {
        try {
            const res = await fetch('/api/listings', { credentials: 'same-origin' });
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            const payload = await res.json();
            const raw = payload.data || payload.listings || [];
            if (!Array.isArray(raw)) return [];
            return raw.map(l => this.normalizeListingRecord(l));
        } catch (err) {
            console.warn('⚠️ API listing fetch failed, falling back to Supabase direct:', err.message);
            const { data, error } = await this.supabase
                .from('listings')
                .select('*')
                .order('created_at', { ascending: false })
                .limit(100);
            if (error) throw error;
            return (data || []).map(l => this.normalizeListingRecord(l));
        }
    }

    normalizeListingRecord(l) {
        if (!l) return l;
        return {
            ...l,
            user_email: l.user_email || l.userEmail || l.owner_email || '',
            postal_code: l.postal_code || l.postalCode || '',
            postalCode: l.postalCode || l.postal_code || '',
            house_type: l.house_type || l.houseType || '',
            created_at: l.created_at || l.createdAt,
            updated_at: l.updated_at || l.updatedAt
        };
    }

    filterListingsByNeeds(listings, needs, { excludeOwnEmail = true, relaxPricePct = 0 } = {}) {
        let results = listings || [];
        const ownEmail = (excludeOwnEmail && this.currentUser?.email || '').toLowerCase();
        if (ownEmail) {
            results = results.filter(l => (l.user_email || '').toLowerCase() !== ownEmail);
        }
        if (needs?.preferredLocation) {
            const loc = needs.preferredLocation.trim().toLowerCase();
            results = results.filter(l => {
                const hay = `${l.city || ''} ${l.street || ''} ${l.title || ''} ${l.country || ''} ${l.location || ''}`.toLowerCase();
                return hay.includes(loc);
            });
        }
        if (needs?.houseType) {
            const type = needs.houseType.toLowerCase();
            results = results.filter(l => (l.house_type || '').toLowerCase() === type);
        }
        if (needs?.maxPrice) {
            const maxP = relaxPricePct > 0
                ? Math.round(Number(needs.maxPrice) * (1 + relaxPricePct))
                : Number(needs.maxPrice);
            results = results.filter(l => !l.price || Number(l.price) <= maxP);
        }
        return results;
    }

    filterOwnListingsByNeeds(listings, needs) {
        const email = (this.currentUser?.email || '').toLowerCase();
        if (!email) return [];
        const own = (listings || []).filter(l => (l.user_email || '').toLowerCase() === email);
        return this.filterListingsByNeeds(own, needs, { excludeOwnEmail: false, relaxPricePct: 0 });
    }

    looksLikeListingReference(message) {
        if (!message || message.length < 8) return false;
        return /\b(listing|property|post(ed)?|advert|place|apartment|condo|unit|house)\b/i.test(message)
            || /\b(negotiat|message|contact)\b.*\b(landlord|owner|host)\b/i.test(message)
            || /\babout\b.+\b(listing|property|place|room)\b/i.test(message);
    }

    async findListingsByTextHint(message) {
        if (!message || message.length < 4) return [];
        const all = await this.fetchListingsFromApi();
        const stopWords = new Set([
            'about', 'this', 'that', 'listing', 'property', 'please', 'negotiate',
            'interested', 'looking', 'rent', 'rental', 'house', 'room', 'apartment',
            'would', 'like', 'help', 'with', 'from', 'account', 'want', 'find'
        ]);
        const words = message.toLowerCase()
            .replace(/[^\w\s]/g, ' ')
            .split(/\s+/)
            .filter(w => w.length > 2 && !stopWords.has(w));
        if (words.length === 0) return [];

        const msgLower = message.toLowerCase();
        const scored = all
            .filter(l => (l.user_email || '').toLowerCase() !== (this.currentUser?.email || '').toLowerCase())
            .map(l => {
                const hay = `${l.title || ''} ${l.description || ''} ${l.city || ''} ${l.street || ''}`.toLowerCase();
                let score = words.reduce((s, w) => s + (hay.includes(w) ? 1 : 0), 0);
                const titleLower = (l.title || '').toLowerCase();
                if (titleLower.length > 4 && msgLower.includes(titleLower)) score += 5;
                return { listing: l, score };
            })
            .filter(x => x.score >= Math.min(2, words.length))
            .sort((a, b) => b.score - a.score);

        return scored.map(x => x.listing).slice(0, 10);
    }

    // Run the same filters as findMatchingListings but scoped to the
    // current user's own listings. Used to surface "your own listing matched
    // but is hidden" instead of a confusing silent "no matches" — the search
    // self-excludes own listings (you can't negotiate with yourself), but
    // the user has a right to know when their own inventory matched.
    // Returns { count, firstHit:{title, price, city, house_type, bedrooms, id} } or null.
    async _checkUserOwnedMatches(prefetchedListings) {
        if (!this.currentUser?.email) return null;
        const needs = this.userNeeds || {};
        if (!needs.preferredLocation && !needs.maxPrice && !needs.houseType) return null;
        try {
            const all = prefetchedListings || await this.fetchListingsFromApi();
            const own = this.filterOwnListingsByNeeds(all, needs);
            if (!own.length) return null;
            return { count: own.length, firstHit: own[0] };
        } catch (e) {
            console.warn('⚠️ own-match check threw (non-fatal):', e?.message || e);
            return null;
        }
    }

    // Search for matching listings (via backend API for consistent cross-account results)
    async findMatchingListings() {
        console.log('🔍 Starting search with criteria:', this.userNeeds);

        const allListings = await this.fetchListingsFromApi();
        console.log(`📦 Loaded ${allListings.length} listings from API`);

        this._lastSearchOwnMatch = await this._checkUserOwnedMatches(allListings);

        const needs = this.userNeeds;
        const hasSpecificCriteria = !!(needs.preferredLocation || needs.houseType || needs.maxPrice);
        if (!hasSpecificCriteria) {
            throw new Error('Please provide specific criteria (location, price, etc.)');
        }

        let listings = this.filterListingsByNeeds(allListings, needs);
        listings = listings
            .sort((a, b) => new Date(b.updated_at || b.created_at || 0) - new Date(a.updated_at || a.created_at || 0))
            .slice(0, 20);

        console.log('📊 Query results:', listings.length, 'listings found');
        if (listings.length > 0) {
            listings.forEach((listing, i) => {
                console.log(`  ${i + 1}. ${listing.title || 'Untitled'} — ${listing.city || '?'} — $${listing.price || '?'}`);
            });
        } else {
            console.log('❌ No listings matched filters; sample from API:', allListings.slice(0, 3).map(l => l.title));
        }

        // Post-search filter: drop listings whose title+description text
        // EXPLICITLY excludes a locked-in must-have or the user's pets.
        // Best-effort because listings have no structured amenity columns;
        // we only drop on negative language (e.g. "no pets", "no parking",
        // "unfurnished") — never on absence of positive mention. So
        // listings with thin descriptions just pass through.
        const goalsForFilter = (typeof window !== 'undefined' && typeof window.getTenantGoals === 'function')
            ? window.getTenantGoals()
            : {};
        const filterResult = this._filterByGoals(listings || [], goalsForFilter);
        if (filterResult.droppedCount > 0) {
            console.log(`🎯 Goals post-filter: dropped ${filterResult.droppedCount} listings (${filterResult.reasons.join(', ')})`);
        }
        this._lastSearchGoalsApplied = { goals: goalsForFilter, droppedCount: filterResult.droppedCount, reasons: filterResult.reasons };
        return filterResult.kept;
    }

    // Build exclusion regexes from the user's locked-in goals. Each entry is
    // { re, reason } — if `re` matches a listing's title+description, the
    // listing is dropped (we treat it as an explicit incompatibility with
    // the user's must-haves / pets).
    _buildGoalExclusions(goals) {
        const ex = [];
        const m = new Set(Array.isArray(goals?.must_haves) ? goals.must_haves : []);
        if (m.has('in_unit_laundry')) ex.push({ re: /no\s+(in.?unit\s+)?(laundry|washer)\b/i, reason: 'excludes in-unit laundry' });
        if (m.has('parking'))         ex.push({ re: /no\s+parking\b|street parking only\b/i, reason: 'excludes parking' });
        if (m.has('pet_friendly') || (goals?.pets && goals.pets !== 'none')) {
            ex.push({ re: /no\s+pets?\b|no\s+dogs?\b|no\s+cats?\b|pet[- ]?free\b/i, reason: 'no pets allowed' });
        }
        if (m.has('furnished'))       ex.push({ re: /unfurnished\b/i, reason: 'unfurnished' });
        if (m.has('dishwasher'))      ex.push({ re: /no\s+dishwasher\b/i, reason: 'no dishwasher' });
        return ex;
    }

    _filterByGoals(listings, goals) {
        const exclusions = this._buildGoalExclusions(goals || {});
        if (!exclusions.length) return { kept: listings, droppedCount: 0, reasons: [] };
        const reasons = new Set();
        const kept = listings.filter(l => {
            const t = `${l.title || ''} ${l.description || ''}`.toLowerCase();
            for (const ex of exclusions) {
                if (ex.re.test(t)) { reasons.add(ex.reason); return false; }
            }
            return true;
        });
        return { kept, droppedCount: listings.length - kept.length, reasons: [...reasons] };
    }

    // Update left sidebar with matching listings
    updateSidebarWithListings(listings) {
        const activeNegotiations = document.getElementById('activeNegotiations');
        if (!activeNegotiations) {
            console.warn('⚠️ activeNegotiations element not found');
            return;
        }

        if (!listings || listings.length === 0) {
            activeNegotiations.innerHTML = '<p class="text-gray-500 text-sm">No matching listings found. Try adjusting your search criteria.</p>';
            return;
        }

        // Create HTML for the listings
        let listingsHTML = '<h4 class="text-sm font-semibold text-gray-700 mb-3">🏠 Matching Listings</h4>';
        
        listings.slice(0, 5).forEach((listing) => {
            const titleText = listing.title || 'Untitled Property';
            const cityText = listing.city || 'City not specified';
            const streetText = listing.street ? ` - ${listing.street}` : '';
            const priceText = listing.price ? `$${listing.price}` : 'Price not listed';
            const typeText = listing.house_type || 'Type not specified';
            
            listingsHTML += `
                <div class="bg-gray-50 rounded-lg p-3 mb-3 border border-gray-200 hover:bg-gray-100 transition-colors">
                    <div class="flex items-start justify-between">
                        <div class="flex-1">
                            <p class="text-sm font-medium text-gray-800">🏠 ${titleText}</p>
                            <p class="text-xs text-gray-600 mt-1">📍 ${cityText}${streetText}</p>
                            <p class="text-xs text-blue-600 font-medium">💰 ${priceText} • ${typeText}</p>
                            <p class="text-xs text-gray-400 mt-1">ID: ${listing.id}</p>
                        </div>
                        <button onclick="window.aiChat?.contactLandlord('${listing.id}')" 
                                class="text-xs bg-blue-500 text-white px-2 py-1 rounded hover:bg-blue-600 transition-colors">
                            Contact
                        </button>
                    </div>
                </div>
            `;
        });

        if (listings.length > 5) {
            listingsHTML += `<p class="text-xs text-gray-500 mt-2">... and ${listings.length - 5} more listings</p>`;
        }

        activeNegotiations.innerHTML = listingsHTML;
        console.log(`✅ Updated sidebar with ${listings.length} listings`);
    }

    // Handle contact landlord button clicks from sidebar
    contactLandlord(listingId) {
        const listing = this.matchingListings.find(l => l.id === listingId);
        if (!listing) {
            console.error('❌ Listing not found:', listingId);
            return;
        }

        this.appendMessage('AI', `📧 Initiating contact with landlord for listing ${listingId}...`, 'left');

        // Use the proper method to start negotiation
        this.startNegotiationForListing(listing);
    }

    // Handle viewing a specific listing by number - Opens popup modal
    handleListingView(listingNumber) {
        console.log('👁️ User wants to view listing #', listingNumber);

        // Validate the selection
        if (!this.matchingListings || this.matchingListings.length === 0) {
            this.appendMessage('AI', 'No listings available. Please search for listings first.', 'left');
            return;
        }

        const index = listingNumber - 1; // Convert to 0-based index
        if (index < 0 || index >= this.matchingListings.length) {
            this.appendMessage('AI', `Invalid selection. Please choose a number between 1 and ${Math.min(this.matchingListings.length, 5)}.`, 'left');
            return;
        }

        const listing = this.matchingListings[index];
        this.currentViewedListing = listing;

        // Open the popup modal to show listing details
        if (typeof window.openListingPopup === 'function') {
            window.openListingPopup(listing);
        } else {
            // Fallback: Show details as text if popup not available
            console.warn('Popup function not available, showing text details');
            this.appendMessage('AI', `📋 **${listing.title || 'Property Details'}**`, 'left');
            this.appendMessage('AI', `📍 Location: ${listing.city || 'Not specified'}${listing.street ? `, ${listing.street}` : ''}`, 'left');
            this.appendMessage('AI', `💰 Price: $${listing.price || 'Not listed'}/month`, 'left');
            this.appendMessage('AI', `🛏️ Bedrooms: ${listing.bedrooms || 'Not specified'}`, 'left');
            this.appendMessage('AI', `🏠 Type: ${listing.house_type || 'Not specified'}`, 'left');
            this.appendMessage('AI', 'Would you like me to message this landlord on your behalf?', 'left');
            this.pendingUserResponse = 'contact_landlord';
        }
    }

    // Render listing cards in chat (shared by searchAndMessage and title-hint flow)
    async presentListingResults(listings, { skipIntro = false } = {}) {
        this.matchingListings = listings || [];

        if (!skipIntro) {
            this.appendMessage('AI', `Found ${this.matchingListings.length} matching listing(s)!`, 'left');
        }

        try {
            const appliedGoals = this._lastSearchGoalsApplied?.goals || {};
            if (Object.keys(appliedGoals).length > 0) {
                const searchFilters = [];
                if (this.userNeeds.preferredLocation) searchFilters.push(this.userNeeds.preferredLocation);
                if (this.userNeeds.houseType) searchFilters.push(this.userNeeds.houseType.toLowerCase());
                if (this.userNeeds.maxPrice) searchFilters.push(`under $${this.userNeeds.maxPrice}/mo`);
                if (this.userNeeds.bedrooms) searchFilters.push(`${this.userNeeds.bedrooms}BR`);

                const goalsForSearch = [];
                if (appliedGoals.must_haves?.length) goalsForSearch.push(`must-haves: ${appliedGoals.must_haves.map(m => m.replace(/_/g, ' ')).join(', ')}`);
                if (appliedGoals.pets && appliedGoals.pets !== 'none') goalsForSearch.push(`pet-friendly (${appliedGoals.pets})`);

                const goalsForNegotiation = [];
                if (appliedGoals.target_reduction) goalsForNegotiation.push(`target $${appliedGoals.target_reduction}/mo reduction`);
                if (appliedGoals.lease_length) goalsForNegotiation.push(`${appliedGoals.lease_length} lease`);
                if (appliedGoals.available_days?.length) goalsForNegotiation.push('meeting days');
                if (appliedGoals.tone || appliedGoals.assertiveness) goalsForNegotiation.push('tone / assertiveness');
                if (appliedGoals.ask_utilities_included || appliedGoals.ask_lower_deposit || appliedGoals.ask_first_month_free) goalsForNegotiation.push('concession asks');

                const lines = [];
                if (searchFilters.length) lines.push(`🔎 Search filters applied: ${searchFilters.join(' · ')}`);
                if (goalsForSearch.length) {
                    const dropped = this._lastSearchGoalsApplied?.droppedCount || 0;
                    const droppedNote = dropped > 0 ? ` (dropped ${dropped} listing${dropped > 1 ? 's' : ''} that explicitly excluded them)` : '';
                    lines.push(`🎯 Filtered out listings that explicitly exclude: ${goalsForSearch.join(', ')}${droppedNote}`);
                }
                if (goalsForNegotiation.length) {
                    lines.push(`💬 The AI will also leverage these during landlord negotiation: ${goalsForNegotiation.join(', ')}`);
                }
                if (lines.length) this.appendMessage('AI', lines.join('\n'), 'left');
            }
        } catch (e) {
            console.warn('Goals transparency message failed (non-fatal):', e?.message || e);
        }

        this.updateSidebarWithListings(this.matchingListings);

        const listingsToShow = this.matchingListings.slice(0, 5);
        for (let i = 0; i < listingsToShow.length; i++) {
            const listing = listingsToShow[i];
            const titleText = listing.title || 'Untitled Property';
            const cityText = listing.city || 'City not specified';
            const priceText = listing.price ? `$${listing.price}/month` : 'Price not listed';
            const bedroomText = listing.bedrooms ? `${listing.bedrooms}BR` : '';
            const typeText = listing.house_type || '';
            const details = [bedroomText, typeText].filter(Boolean).join(' ');

            const listingCardHTML = `
                <div class="listing-card-chat">
                    <div class="listing-card-chat-title">${i + 1}. ${titleText}</div>
                    <div class="listing-card-chat-details">
                        📍 ${cityText} • 💰 ${priceText}${details ? ` • ${details}` : ''}
                    </div>
                    <button class="listing-view-btn" onclick="window.aiChat.handleListingView(${i + 1})">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                            <circle cx="12" cy="12" r="3"/>
                        </svg>
                        View Details
                    </button>
                </div>
            `;
            this.appendMessageHTML('AI', listingCardHTML, 'left');
        }

        if (this.matchingListings.length > 5) {
            this.appendMessage('AI', `...and ${this.matchingListings.length - 5} more listings available.`, 'left');
        }

        if (this._lastSearchOwnMatch && this._lastSearchOwnMatch.count > 0) {
            const ct = this._lastSearchOwnMatch.count;
            this.appendMessage('AI', `📌 Note: ${ct} of your own listing${ct > 1 ? 's' : ''} also matched and ${ct > 1 ? 'were' : 'was'} hidden (you can't negotiate with yourself).`, 'left');
        }

        this.appendMessage('AI', 'Click "View Details" on any listing to see more information.', 'left');
        this.listingSelectionMode = true;
        this.pendingUserResponse = 'listing_selection';
        this.negotiationState = 'awaiting_selection';
    }

    // Main search and messaging function
    async searchAndMessage() {
        try {
            this.negotiationState = 'searching';
            this.appendMessage('AI', 'Searching for matching listings...', 'left', true);
            
            this.matchingListings = await this.findMatchingListings();
            this.removeTypingIndicator();
            
            if (this.matchingListings.length === 0) {
                await this.handleNoMatches();
                return;
            }
            
            await this.presentListingResults(this.matchingListings);
            
        } catch (error) {
            this.removeTypingIndicator();
            console.error('Search error:', error);
            this.appendMessage('AI', `Search failed: ${error.message}`, 'left');
            this.negotiationState = 'idle';
        }
    }

    // Handle when no matches are found
    async handleNoMatches() {
        const extracted = [];
        if (this.userNeeds.preferredLocation) extracted.push(`Location: ${this.userNeeds.preferredLocation}`);
        if (this.userNeeds.maxPrice) extracted.push(`Max Price: $${this.userNeeds.maxPrice}`);
        if (this.userNeeds.houseType) extracted.push(`Type: ${this.userNeeds.houseType}`);

        this.appendMessage('AI', `❌ No exact matches found. I searched for: ${extracted.join(', ')}`, 'left');

        // Special case: the user's OWN listings actually matched the criteria,
        // but were hidden by the self-exclusion filter. Tell them — this is
        // the bug fix for "I have this listing already, why doesn't it show up".
        if (this._lastSearchOwnMatch && this._lastSearchOwnMatch.count > 0) {
            const ct = this._lastSearchOwnMatch.count;
            const own = this._lastSearchOwnMatch.firstHit || {};
            const ownTitle = own.title || 'Your listing';
            const ownPrice = own.price ? ` ($${own.price}/mo)` : '';
            const otherN = ct - 1;
            const others = otherN > 0 ? ` (and ${otherN} other${otherN > 1 ? 's' : ''})` : '';
            this.appendMessage('AI', `📌 Your own listing **"${ownTitle}"**${ownPrice}${others} matches your search — but it's hidden here because you can't negotiate with yourself.`, 'left');
            this.appendMessage('AI', `💡 To work with it, search from a different account, or open it directly from your dashboard / My Listings.`, 'left');
            this.negotiationState = 'idle';
            return;
        }

        // No own-listing match either. Try similar listings via API with relaxed price.
        let similarListings = [];
        try {
            const allListings = await this.fetchListingsFromApi();
            similarListings = this.filterListingsByNeeds(allListings, this.userNeeds, { relaxPricePct: 0.2 })
                .sort((a, b) => new Date(b.updated_at || b.created_at || 0) - new Date(a.updated_at || a.created_at || 0))
                .slice(0, 10);
        } catch (e) {
            console.warn('Similar listings fetch failed:', e?.message || e);
        }

        if (similarListings?.length > 0) {
            const criteria = [];
            if (this.userNeeds.houseType) criteria.push(this.userNeeds.houseType.toLowerCase());
            if (this.userNeeds.preferredLocation) criteria.push(`in ${this.userNeeds.preferredLocation}`);
            if (this.userNeeds.maxPrice) criteria.push(`up to ~$${Math.round(this.userNeeds.maxPrice * 1.2)}`);

            this.appendMessage('AI', `Here are similar listings (${criteria.join(' + ')}):`, 'left');

            let shownCount = 0;
            for (const listing of similarListings.slice(0, 5)) {
                const titleText = listing.title || 'Untitled Property';
                const cityText = listing.city || 'City not specified';
                const streetText = listing.street ? ` - ${listing.street}` : '';
                const priceText = listing.price ? ` - $${listing.price}` : '';
                const typeText = listing.house_type ? ` (${listing.house_type})` : '';
                this.appendMessage('AI', `📋 ${titleText} - ${cityText}${streetText}${priceText}${typeText}`, 'left');
                shownCount++;
                if (shownCount >= 3) break;
            }

            const suggestions = [];
            if (this.userNeeds.maxPrice) suggestions.push(`increase your budget above $${this.userNeeds.maxPrice}`);
            if (this.userNeeds.preferredLocation) suggestions.push(`try nearby areas or relax the location filter`);
            if (suggestions.length > 0) {
                this.appendMessage('AI', `💡 Suggestions: ${suggestions.join(' or ')}.`, 'left');
            }
        } else {
            this.appendMessage('AI', 'No matching listings in the database — try a different city, a higher budget, or a different property type.', 'left');
        }

        this.negotiationState = 'idle';
    }

    // Check if the message is a response to pending questions (listing selection, contact, etc.)
    checkForNegotiationResponse(message) {
        console.log('🔍 [RESPONSE CHECK] Checking message:', message, 'Pending:', this.pendingUserResponse);
        const cleanMessage = message.toLowerCase().trim();

        // Define common responses
        const affirmativeResponses = ['yes', 'sure', 'ok', 'okay', 'please', 'go ahead', 'proceed', 'yep', 'yeah', 'definitely', 'absolutely'];
        const negativeResponses = ['no', 'nope', 'not yet', 'pass', 'skip', 'nah', 'maybe later'];
        const isAffirmative = affirmativeResponses.some(r => cleanMessage.includes(r));
        const isNegative = negativeResponses.some(r => cleanMessage.includes(r));

        // Handle listing selection (user says "1", "2", "view 2", etc.)
        if (this.pendingUserResponse === 'listing_selection') {
            // Check for number in message
            const numberMatch = cleanMessage.match(/(\d+)/);
            if (numberMatch) {
                const listingNum = parseInt(numberMatch[1]);
                console.log('✅ User selected listing #', listingNum);
                this.handleListingView(listingNum);
                return true;
            }

            // FIX 1: Auto-select if affirmative and only 1 listing
            if (isAffirmative && this.matchingListings && this.matchingListings.length === 1) {
                console.log('✅ Auto-selecting only listing (single match + affirmative)');
                this.handleListingView(1);
                return true;
            }

            // Handle "view" or "view this" without number when only 1 listing
            if ((cleanMessage.includes('view') || cleanMessage.includes('this') || cleanMessage.includes('that'))
                && this.matchingListings && this.matchingListings.length === 1) {
                console.log('✅ Auto-selecting only listing (view keyword + single match)');
                this.handleListingView(1);
                return true;
            }

            // Check if user wants to see all or contact all
            if (cleanMessage.includes('all') || cleanMessage.includes('contact') || cleanMessage.includes('message')) {
                this.appendMessage('AI', 'Which listing number would you like to view first? (1, 2, 3...)', 'left');
                return true;
            }
        }

        // Handle contact landlord response (after viewing a listing)
        if (this.pendingUserResponse === 'contact_landlord') {
            // FIX 2: Better keyword detection for "msg landlord", "message the landlord", "I like it contact", etc.
            const wantsToMessage = cleanMessage.includes('msg') ||
                                   cleanMessage.includes('message') ||
                                   cleanMessage.includes('contact') ||
                                   cleanMessage.includes('reach out') ||
                                   cleanMessage.includes('landlord');
            const likesIt = cleanMessage.includes('like') ||
                            cleanMessage.includes('good') ||
                            cleanMessage.includes('great') ||
                            cleanMessage.includes('perfect') ||
                            cleanMessage.includes('love') ||
                            cleanMessage.includes('interested');

            // Check affirmative OR explicit message intent OR likes it + has listing
            if ((isAffirmative || wantsToMessage || likesIt) && this.currentViewedListing) {
                console.log('✅ User wants to contact landlord (affirmative/keyword match)');
                this.appendMessage('AI', `Great! I'll reach out to the landlord for "${this.currentViewedListing.title}"...`, 'left');
                this.pendingUserResponse = null;
                setTimeout(() => this.startNegotiationForListing(this.currentViewedListing), 1000);
                return true;
            } else if (isNegative) {
                console.log('❌ User declined to contact landlord');
                this.pendingUserResponse = 'continue_browsing';
                this.appendMessage('AI', 'No problem! Would you like to view another listing, or is there anything else I can help with?', 'left');
                return true;
            }
        }

        // Handle continue browsing response
        if (this.pendingUserResponse === 'continue_browsing') {
            // Check if they want to view another listing
            const numberMatch = cleanMessage.match(/(\d+)/);
            if (numberMatch) {
                const listingNum = parseInt(numberMatch[1]);
                console.log('✅ User wants to view another listing #', listingNum);
                this.handleListingView(listingNum);
                return true;
            }

            if (cleanMessage.includes('another') || cleanMessage.includes('other') || cleanMessage.includes('different')) {
                this.appendMessage('AI', 'Sure! Which listing number would you like to view?', 'left');
                this.pendingUserResponse = 'listing_selection';
                return true;
            }

            if (isNegative || cleanMessage.includes('nothing') || cleanMessage.includes('done') || cleanMessage.includes('that\'s all')) {
                this.appendMessage('AI', 'Alright! Feel free to search again if you need anything else. Good luck with your rental search!', 'left');
                this.pendingUserResponse = null;
                this.listingSelectionMode = false;
                return true;
            }
        }

        // Legacy: Handle old negotiate_offer response type
        if (this.pendingUserResponse === 'negotiate_offer' && isAffirmative && this.matchingListings.length > 0) {
            console.log('✅ Legacy negotiate_offer - redirecting to listing selection');
            this.appendMessage('AI', 'Which listing would you like me to contact the landlord for? Just say the number.', 'left');
            this.pendingUserResponse = 'listing_selection';
            return true;
        }

        // Check for direct negotiation requests
        const negotiationKeywords = ['negotiate', 'contact landlord', 'message landlord', 'talk to landlord', 'reach out'];
        const hasNegotiationKeyword = negotiationKeywords.some(keyword => cleanMessage.includes(keyword));

        if (hasNegotiationKeyword && this.matchingListings.length > 0) {
            console.log('✅ Direct negotiation request - asking which listing');
            this.appendMessage('AI', 'Which listing would you like me to contact the landlord for? Just say the number (e.g., "1").', 'left');
            this.pendingUserResponse = 'listing_selection';
            return true;
        }

        // FIX 3: CRITICAL - Prevent fall-through to AI API when pending response exists
        // If we have a pending response but didn't match above, ask for clarification instead of calling AI
        if (this.pendingUserResponse && ['listing_selection', 'contact_landlord', 'continue_browsing'].includes(this.pendingUserResponse)) {
            console.log('⚠️ Pending response not matched, asking for clarification instead of calling AI');
            if (this.pendingUserResponse === 'listing_selection') {
                this.appendMessage('AI', 'Please enter a listing number to view its details (e.g., "1" or "2").', 'left');
            } else if (this.pendingUserResponse === 'contact_landlord') {
                this.appendMessage('AI', 'Would you like me to message this landlord? Just say "yes" or "no".', 'left');
            } else if (this.pendingUserResponse === 'continue_browsing') {
                this.appendMessage('AI', 'Would you like to view another listing, or is there anything else I can help with?', 'left');
            }
            return true; // CRITICAL: This prevents the AI API call which would trigger a new search
        }

        console.log('❌ [RESPONSE CHECK] No matching response detected');
        return false;
    }

    // Start negotiations for all matching listings
    async startNegotiationsForAllListings() {
        if (!this.matchingListings || this.matchingListings.length === 0) {
            this.appendMessage('AI', 'No listings available for negotiation. Please search for properties first.', 'left');
            return;
        }

        this.appendMessage('AI', `📧 Contacting landlords for ${this.matchingListings.length} listing(s)...`, 'left');

        for (const listing of this.matchingListings) {
            if (listing.user_email && listing.user_email !== this.currentUser?.email) {
                setTimeout(() => this.startNegotiationForListing(listing), 500);
            }
        }
    }

    // Out-of-band landlord notification after the AI's intro lands. Fires
    // two channels in parallel — in-app notification row (so the landlord
    // sees it in their notifications panel next time they open the site)
    // and a Brevo email (so they get pinged even when offline). Both
    // fire-and-forget; failures only log warnings.
    _notifyLandlordOfIntro(listing, message) {
        const landlordEmail = listing?.user_email;
        if (!landlordEmail || !this.currentUser?.email) return;
        const userName = this.currentUser.firstName || this.currentUser.email.split('@')[0];
        const listingTitle = listing.title || 'your listing';
        const truncated = String(message || '').slice(0, 120);

        // Fire and forget — don't block the chat UI.
        (async () => {
            // 1. In-app notification row via the SECURITY DEFINER RPC.
            try {
                const { error } = await this.supabase.rpc('create_notification', {
                    recipient_email: landlordEmail,
                    notification_title: `New inquiry: ${listingTitle}`,
                    notification_content: `New message from ${userName} (${this.currentUser.email})\n\nProperty: ${listingTitle}\n\nMessage: "${truncated}"\n\nReply in the chat to continue the conversation.`
                });
                if (error) console.warn('⚠️ create_notification RPC failed (non-fatal):', error.message);
                else console.log('🔔 In-app notification created for landlord:', landlordEmail);
            } catch (e) {
                console.warn('⚠️ create_notification threw (non-fatal):', e?.message || e);
            }

            // 2. Brevo email (works even when landlord is offline).
            try {
                const r = await fetch('/api/message-landlord', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        listingId: listing.id,
                        landlordEmail,
                        message,
                        userEmail: this.currentUser.email,
                        userName
                    })
                });
                if (!r.ok) console.warn('⚠️ /api/message-landlord returned', r.status);
                else console.log('📧 Landlord email queued for listing:', listing.id);
            } catch (e) {
                console.warn('⚠️ /api/message-landlord threw (non-fatal):', e?.message || e);
            }
        })();
    }

    // Start negotiation for a specific listing - HUMAN-LIKE PHASED APPROACH
    async startNegotiationForListing(listing) {
        // DEBUG: log the call stack so we can pin down WHICH caller is firing
        // the duplicate intro path. Three intros ~60s apart were still
        // appearing after the earlier idempotency fix; this trace identifies
        // the leaking caller in production. Remove once root cause is fixed.
        console.log('📍 startNegotiationForListing called for listing', listing?.id, '— stack:\n', new Error().stack);
        try {
            this.appendMessage('AI', `Starting conversation with landlord for "${listing.title}"...`, 'left');

            if (!this.currentUser?.email) {
                this.appendMessage('AI', 'You need to be logged in to contact landlords.', 'left');
                return;
            }

            if (!listing.user_email) {
                this.appendMessage('AI', 'This listing has no landlord contact information.', 'left');
                return;
            }

            // Step 1: Check if conversation already exists (BIDIRECTIONAL)
            console.log('🔍 Checking for existing conversation (bidirectional)...');

            let conversationId = null;
            const userA = this.currentUser.email;
            const userB = listing.user_email;

            // Check direction 1: tenant as original sender
            const { data: conv1, error: err1 } = await this.supabase
                .from('conversations')
                .select('id')
                .eq('listing_id', listing.id)
                .eq('sender_email', userA)
                .eq('receiver_email', userB)
                .maybeSingle();

            if (err1 && err1.code !== 'PGRST116') {
                console.error('❌ Error in conversation lookup (direction 1):', err1);
            }

            if (conv1) {
                conversationId = conv1.id;
                console.log('✅ Found existing conversation (tenant->landlord):', conversationId);
            }

            // Check direction 2: landlord as original sender (if not found)
            if (!conversationId) {
                const { data: conv2, error: err2 } = await this.supabase
                    .from('conversations')
                    .select('id')
                    .eq('listing_id', listing.id)
                    .eq('sender_email', userB)
                    .eq('receiver_email', userA)
                    .maybeSingle();

                if (err2 && err2.code !== 'PGRST116') {
                    console.error('❌ Error in conversation lookup (direction 2):', err2);
                }

                if (conv2) {
                    conversationId = conv2.id;
                    console.log('✅ Found existing conversation (landlord->tenant):', conversationId);
                }
            }

            // Step 2: Create conversation if it doesn't exist
            if (!conversationId) {
                console.log('📝 Creating new conversation...');
                const { data: newConversation, error: createError } = await this.supabase
                    .from('conversations')
                    .insert({
                        listing_id: listing.id,
                        sender_email: this.currentUser.email,
                        receiver_email: listing.user_email
                    })
                    .select('id')
                    .single();

                if (createError) {
                    console.error('❌ Error creating conversation:', createError);
                    this.appendMessage('AI', `Failed to create conversation: ${createError.message}`, 'left');
                    return;
                }

                conversationId = newConversation.id;
                console.log('✅ Created new conversation with ID:', conversationId);
            }

            // Idempotency guard — don't re-send an intro for a conversation
            // that already has one. Two checks:
            //   1. In-memory Set: catches re-entry within the same page session
            //      (e.g. user clicks Contact twice, or post-affirmation handler
            //      re-fires for an already-introduced listing).
            //   2. DB history scan: catches re-entry across page reloads —
            //      if an AI-authored message already exists in this conversation,
            //      we're rejoining an existing chat and must not send a fresh intro.
            if (this.sentIntroConversations.has(conversationId)) {
                console.log('🛡️ Intro already sent for conversation', conversationId, '— skipping generation, just ensuring auto-reply listener is up.');
                this.activeConversationId = conversationId;
                this.activeListing = listing;
                this.setupConversationAutoReply(conversationId, this.activeNegotiationId, listing);
                return;
            }
            try {
                // BUGFIX: the earlier version of this guard filtered by
                // `sender_email = this.currentUser.email` (the tenant), but
                // AI messages are inserted with sender_email
                // 'ai-negotiator@roomfinder.com' — so the filter never matched
                // an existing AI intro and the guard NEVER triggered. We now
                // match either the AI sender OR the disclosure footer/legacy
                // header in the message body, so any prior AI-authored message
                // in this conversation blocks re-introduction.
                const { data: existingAiMessages } = await this.supabase
                    .from('messages')
                    .select('id, sender_email, content')
                    .eq('conversation_id', conversationId)
                    .or('sender_email.eq.ai-negotiator@roomfinder.com,content.ilike.%Sent via RoomFinder AI%,content.ilike.%AI Negotiator on behalf%')
                    .limit(1);
                if (existingAiMessages && existingAiMessages.length > 0) {
                    console.log('🛡️ Conversation', conversationId, 'already has an AI-authored message — skipping intro generation (likely a page reload or re-entry).');
                    this.sentIntroConversations.add(conversationId);
                    this.activeConversationId = conversationId;
                    this.activeListing = listing;
                    this.setupConversationAutoReply(conversationId, this.activeNegotiationId, listing);
                    return;
                }
            } catch (historyCheckErr) {
                // Non-fatal — if the history check itself fails we fall through
                // to the normal path. Better to risk a rare dup than a missing intro.
                console.warn('⚠️ History check before intro failed (non-fatal):', historyCheckErr?.message || historyCheckErr);
            }

            // Step 3: Use HUMAN-LIKE phased conversation approach
            if (this.negotiationEngine) {
                console.log('🎭 [NEW CODE v2] Starting human-like phased conversation - NO PRICING IN FIRST MESSAGE');

                const budget = this.userNeeds.maxPrice || listing.price * 0.85; // Default to 85% of listing price
                const userName = this.currentUser.firstName || this.currentUser.email.split('@')[0];

                // Start with introduction phase (NO pricing). Pass conversationId
                // so the engine can run its own DB-level dedup check as a
                // belt-and-suspenders guard.
                const conversationData = await this.negotiationEngine.startHumanLikeConversation(
                    listing,
                    budget,
                    this.currentUser.email,
                    userName,
                    conversationId
                );

                // If the engine determined an AI message already exists in this
                // conversation, treat it as a re-entry: set up the auto-reply
                // listener but skip the intro send.
                if (conversationData && conversationData.skipped) {
                    console.log('🛡️ Engine skipped intro generation (already exists). Setting up listener only.');
                    this.sentIntroConversations.add(conversationId);
                    this.activeConversationId = conversationId;
                    this.activeListing = listing;
                    this.setupConversationAutoReply(conversationId, this.activeNegotiationId, listing);
                    return;
                }

                if (conversationData && conversationData.message) {
                    // Store the negotiation ID for tracking
                    this.activeNegotiationId = conversationData.negotiationId;
                    this.activeConversationId = conversationId;
                    this.activeListing = listing;

                    // Send the introduction message
                    console.log('📤 Sending introduction message (no pricing):', conversationData.message);
                    const sent = await this.negotiationEngine.sendNegotiationMessage(
                        conversationId,
                        conversationData.message,
                        this.currentUser.email,
                        listing.user_email,
                        listing.title
                    );

                    if (sent) {
                        // Mark as sent BEFORE the UI messages so a re-entry that
                        // races with this branch sees the flag immediately.
                        this.sentIntroConversations.add(conversationId);

                        this.appendMessage('AI', `Reached out to the landlord for "${listing.title}"`, 'left');
                        this.appendMessage('AI', `Sent: "${conversationData.message}"`, 'left');
                        this.appendMessage('AI', `I'll continue the conversation naturally when they reply - building rapport before discussing price.`, 'left');

                        // Set up auto-reply listener for this conversation
                        this.setupConversationAutoReply(conversationId, conversationData.negotiationId, listing);

                        // Fan out landlord notifications so they actually know
                        // someone reached out — the real-time message listener
                        // only fires while the landlord is on the site. Both
                        // channels are fire-and-forget; failures don't block.
                        this._notifyLandlordOfIntro(listing, conversationData.message);
                    } else {
                        this.appendMessage('AI', `Failed to send message to landlord`, 'left');
                    }
                } else {
                    this.appendMessage('AI', 'Failed to start conversation', 'left');
                }
            } else {
                // Fallback: Send basic human-like message without full AI engine
                console.log('📤 Sending basic introduction (no AI engine available)...');
                const message = `Hey! I saw your listing for "${listing.title}" and it caught my eye. Is it still available?`;

                const { error: sendError } = await this.supabase
                    .from('messages')
                    .insert({
                        conversation_id: conversationId,
                        sender_email: this.currentUser.email,
                        content: message
                    });

                if (sendError) {
                    console.error('❌ Error sending message:', sendError);
                    this.appendMessage('AI', `Failed to send message: ${sendError.message}`, 'left');
                    return;
                }

                this.sentIntroConversations.add(conversationId);
                this.appendMessage('AI', `Sent message to landlord for "${listing.title}"`, 'left');
                this.appendMessage('AI', `Message: "${message}"`, 'left');
                this._notifyLandlordOfIntro(listing, message);
            }
        } catch (error) {
            console.error('Conversation error:', error);
            this.appendMessage('AI', `Error contacting landlord: ${error.message}`, 'left');
        }
    }

    // Set up auto-reply for landlord responses
    setupConversationAutoReply(conversationId, negotiationId, listing) {
        // Idempotency: Supabase's Realtime client tracks channels globally by name. If
        // we call .channel('conversation_X') a second time, we get back the ALREADY
        // SUBSCRIBED instance — calling .on('postgres_changes', ...) on it then throws
        // "cannot add postgres_changes callbacks ... after subscribe()". Bail early
        // when we've already wired this conversation. The autoReplyChannels Map is
        // populated below at the same time the subscription is created, so it's the
        // authoritative "already subscribed" signal.
        if (!this.autoReplyChannels) this.autoReplyChannels = new Map();
        if (this.autoReplyChannels.has(conversationId)) {
            console.log('🔔 Auto-reply already set up for', conversationId, '— skipping duplicate subscription');
            return;
        }

        console.log('🔔 Setting up auto-reply listener for conversation:', conversationId);

        // Subscribe to new messages in this conversation
        const channel = this.supabase
            .channel(`conversation_${conversationId}`)
            .on(
                'postgres_changes',
                {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'messages',
                    filter: `conversation_id=eq.${conversationId}`
                },
                async (payload) => {
                    const newMessage = payload.new;

                    // Only respond to landlord messages (not our own)
                    if (newMessage.sender_email === listing.user_email) {
                        console.log('📩 Landlord replied:', newMessage.content);

                        // Process the reply and generate phased response
                        await this.handleLandlordAutoReply(newMessage, conversationId, negotiationId, listing);
                    }
                }
            )
            .subscribe((status) => {
                console.log('🔔 Auto-reply subscription status:', status);
            });

        // Store channel for cleanup
        if (!this.autoReplyChannels) {
            this.autoReplyChannels = new Map();
        }
        this.autoReplyChannels.set(conversationId, channel);
    }

    // Handle landlord reply and auto-respond with next phase
    async handleLandlordAutoReply(landlordMessage, conversationId, negotiationId, listing) {
        try {
            console.log('🤖 Auto-replying to landlord message...');

            if (!this.negotiationEngine) {
                console.error('No negotiation engine available');
                return;
            }

            // Get phased response from negotiation engine
            const response = await this.negotiationEngine.handleLandlordReplyWithPhases(
                landlordMessage.content,
                negotiationId,
                listing
            );

            if (response && response.message) {
                // Apply human-like delay before responding
                const delay = response.delay || 2000;
                console.log(`⏳ Waiting ${delay}ms before responding (human-like delay)...`);

                await new Promise(resolve => setTimeout(resolve, delay));

                // Send the response. Pass landlordMessage.id as respondsToMessageId so
                // sendNegotiationMessage uses the deterministic UUID for the INSERT.
                // Without this, the parallel setupMessageListener path computes the
                // dedup UUID but this path uses a random one, so both paths' INSERTs
                // succeed — user sees duplicates. With it, both paths collide on the
                // same primary key and Postgres rejects the slower one with 23505.
                const userName = this.currentUser?.firstName || this.currentUser?.email?.split('@')[0] || 'Tenant';
                const sent = await this.negotiationEngine.sendNegotiationMessage(
                    conversationId,
                    response.message,
                    this.currentUser.email,
                    listing.user_email,
                    listing.title,
                    landlordMessage.id
                );

                if (sent) {
                    console.log(`✅ Sent ${response.phase} response:`, response.message);

                    // Notify user about the exchange
                    this.appendMessage('AI', `Landlord replied: "${landlordMessage.content}"`, 'left');
                    this.appendMessage('AI', `I responded (${response.phase.replace(/_/g, ' ').toLowerCase()}): "${response.message}"`, 'left');
                } else {
                    console.error('Failed to send auto-reply');
                }
            }
        } catch (error) {
            console.error('Error handling landlord auto-reply:', error);
        }
    }

    // Load conversation history from Supabase on page init. Fetches the user's
    // single row from public.ai_chat_history and replays each message into the
    // chat panel using displayMessage (UI-only — no history push, no save
    // round-trip). The _replaying flag suppresses saveConversationHistory()
    // calls while we're restoring, so we don't re-upsert the messages we just
    // loaded back to Supabase.
    async loadConversationHistory() {
        if (!this.currentUser?.email || !this.supabase) return;
        try {
            const { data, error } = await this.supabase
                .from('ai_chat_history')
                .select('messages')
                .eq('user_email', this.currentUser.email)
                .maybeSingle();
            if (error) {
                console.warn('loadConversationHistory query error:', error.message);
                return;
            }
            if (!data || !Array.isArray(data.messages) || data.messages.length === 0) return;

            this._replaying = true;
            for (const msg of data.messages) {
                if (!msg || typeof msg.content !== 'string') continue;
                const sender = msg.role === 'assistant' ? 'AI'
                             : msg.role === 'user'      ? 'You'
                             : (msg.role || 'AI');
                const align  = msg.role === 'user' ? 'right' : 'left';
                this.displayMessage(sender, msg.content, align);
                this.conversationHistory.push({ role: msg.role, content: msg.content });
            }
            this._replaying = false;
            console.log(`✅ Restored ${data.messages.length} message(s) from history for ${this.currentUser.email}`);
        } catch (e) {
            console.warn('loadConversationHistory exception:', e.message);
            this._replaying = false;
        }
    }

    // Save conversation history to Supabase. Throttled (500ms debounce) because
    // appendMessage fires save on every message; without the throttle a quick
    // burst (e.g. system showing five welcome messages on page load) would
    // produce N upserts. Capped at the last 200 messages so the row can't grow
    // unbounded. No-op if the user isn't logged in.
    async saveConversationHistory() {
        if (!this.currentUser?.email || !this.supabase) return;
        clearTimeout(this._saveTimer);
        this._saveTimer = setTimeout(async () => {
            try {
                const payload = {
                    user_email: this.currentUser.email,
                    messages: (this.conversationHistory || []).slice(-200),
                    updated_at: new Date().toISOString()
                };
                const { error } = await this.supabase
                    .from('ai_chat_history')
                    .upsert(payload, { onConflict: 'user_email' });
                if (error) console.warn('saveConversationHistory upsert failed:', error.message);
            } catch (e) {
                console.warn('saveConversationHistory exception:', e.message);
            }
        }, 500);
    }

    // Clear conversation history
    async clearConversationHistory() {
        this.conversationHistory = [];

        if (this.currentUser?.email && this.supabase) {
            try {
                const { error } = await this.supabase
                    .from('ai_chat_history')
                    .delete()
                    .eq('user_email', this.currentUser.email);

                if (error) {
                    console.error('Error clearing chat history:', error.message);
                }
            } catch (error) {
                console.error('Error clearing conversation history:', error);
            }
        }

        // Clear UI
        const messages = document.getElementById('chatMessages');
        if (messages) {
            messages.innerHTML = '';
        }
    }

    // Display message to chat (without saving to history)
    displayMessage(sender, message, align, isTypingIndicator = false) {
        const messages = document.getElementById('chatMessages');
        if (!messages) {
            console.error('Error: #chatMessages element not found');
            return;
        }

        const messageDiv = document.createElement('div');
        // Use align parameter: 'right' = sent (user), 'left' = received (other)
        const alignClass = align === 'right' ? 'sent' : 'received';
        messageDiv.className = `message ${alignClass}`;

        // Determine display name
        let displayName = sender;
        if (sender.toLowerCase() === 'you') displayName = 'You';
        else if (sender.toLowerCase() === 'ai') displayName = 'AI Assistant';
        else if (sender.toLowerCase() === 'ai negotiator') displayName = 'AI Negotiator';
        else if (sender.toLowerCase() === 'landlord') displayName = 'Landlord';
        else if (sender.toLowerCase() === 'system') displayName = 'System';

        const labelClass = align === 'right' ? 'text-indigo-200' : 'text-gray-500';

        messageDiv.innerHTML = `
            <div class="font-semibold text-xs ${labelClass} mb-1">${displayName}</div>
            <p>${message}</p>
        `;

        messages.appendChild(messageDiv);
        messages.scrollTop = messages.scrollHeight;
    }

    // Append message to chat and save to history
    appendMessage(sender, message, align, isTypingIndicator = false) {
        // Display the message
        this.displayMessage(sender, message, align, isTypingIndicator);

        // Save to history (skip typing indicators).
        if (!isTypingIndicator) {
            // Map display names to OpenAI-compatible roles
            const role = sender.toLowerCase() === 'you' ? 'user' :
                        sender.toLowerCase() === 'ai' ? 'assistant' :
                        sender.toLowerCase();
            this.conversationHistory.push({ role: role, content: message });
            // Don't fire save while we're restoring messages from Supabase —
            // loadConversationHistory pushed them already and an echo upsert
            // is pure waste + an unnecessary throttled write.
            if (!this._replaying) this.saveConversationHistory();
        }
    }

    // Append HTML message to chat (for cards, buttons, etc.) - doesn't save to history
    appendMessageHTML(sender, htmlContent, align) {
        const messages = document.getElementById('chatMessages');
        if (!messages) {
            console.error('Error: #chatMessages element not found');
            return;
        }

        const messageDiv = document.createElement('div');
        const alignClass = align === 'right' ? 'sent' : 'received';
        messageDiv.className = `message ${alignClass}`;

        // Determine display name
        let displayName = sender;
        if (sender.toLowerCase() === 'you') displayName = 'You';
        else if (sender.toLowerCase() === 'ai') displayName = 'AI Assistant';

        const labelClass = align === 'right' ? 'text-indigo-200' : 'text-gray-500';

        messageDiv.innerHTML = `
            <div class="font-semibold text-xs ${labelClass} mb-1">${displayName}</div>
            ${htmlContent}
        `;

        messages.appendChild(messageDiv);
        messages.scrollTop = messages.scrollHeight;
    }

    // Remove typing indicator
    removeTypingIndicator() {
        const typingIndicator = document.getElementById('typing-indicator');
        if (typingIndicator) typingIndicator.remove();
    }

    // Display negotiation success notification
    displayNegotiationSuccess(chatData) {
        try {
            const conversationData = JSON.parse(chatData.conversation_data);
            const message = conversationData[0]?.content || 'Negotiation successful!';

            this.appendMessage('AI', message, 'left');

            // Visual celebration effect
            this.celebrateSuccess();
        } catch (error) {
            console.error('Error displaying negotiation success:', error);
            this.appendMessage('AI', '🎉 Negotiation completed successfully!', 'left');
        }
    }

    // Display landlord reply notification
    displayLandlordReply(chatData) {
        try {
            const conversationData = JSON.parse(chatData.conversation_data);
            const message = conversationData[0]?.content || 'Received reply from landlord';

            this.appendMessage('AI', message, 'left');
        } catch (error) {
            console.error('Error displaying landlord reply:', error);
            this.appendMessage('AI', '💬 Received a reply from the landlord', 'left');
        }
    }

    // Celebrate negotiation success with visual effects
    celebrateSuccess() {
        const messages = document.getElementById('chatMessages');
        if (!messages) return;

        // Add celebration animation
        const celebration = document.createElement('div');
        celebration.className = 'celebration-animation';
        celebration.innerHTML = '🎉🎊✨';
        celebration.style.cssText = `
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 4rem;
            animation: celebrate 2s ease-out;
            pointer-events: none;
            z-index: 1000;
        `;

        messages.style.position = 'relative';
        messages.appendChild(celebration);

        // Remove after animation
        setTimeout(() => celebration.remove(), 2000);
    }
}

// Make the class globally available
window.AIChatHandler = AIChatHandler;