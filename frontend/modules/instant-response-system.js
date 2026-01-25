/**
 * Instant Response System
 * Handles automatic 60-second response guarantee for all incoming messages
 * Extends the AI negotiation engine for instant customer engagement
 */

class InstantResponseSystem {
    constructor(supabase, config) {
        this.supabase = supabase;
        this.config = config;
        this.activeResponses = new Map(); // Track auto-responses to avoid duplicates
        this.responseTemplates = this.initializeTemplates();
        this.init();
    }

    /**
     * Initialize the instant response system
     */
    async init() {
        console.log('⚡ Initializing Instant Response System...');

        // Set up real-time listener for new conversations
        this.setupRealtimeListener();

        console.log('✅ Instant Response System initialized - 60-second guarantee active');
    }

    /**
     * Initialize response templates for common inquiries
     */
    initializeTemplates() {
        return {
            // Initial contact template
            initial: {
                delay: 800, // 800ms feels natural
                templates: [
                    `Hi! Thanks for reaching out about this property! 🏠 I'll get back to you shortly. In the meantime, feel free to ask any questions you have about the listing.`,
                    `Hey there! Thanks for your interest in this property. The landlord has been notified and will respond soon. What would you like to know about the place?`,
                    `Hi! I've received your message and the landlord will be with you shortly. While you wait, is there anything specific you'd like to know about the property?`
                ]
            },

            // Viewing request template
            viewing: {
                delay: 1000,
                templates: [
                    `Great! I've notified the landlord about your viewing request. They typically respond within an hour. What dates/times work best for you?`,
                    `Perfect! The landlord has been alerted about your viewing request. To help speed things up, could you share your preferred viewing times?`,
                    `Thanks for your viewing request! The landlord will be in touch soon. In the meantime, when would be most convenient for you to view the property?`
                ]
            },

            // Questions about property
            questions: {
                delay: 900,
                templates: [
                    `Thanks for your question! The landlord has been notified and will provide detailed information soon. Is there anything else you'd like to know?`,
                    `Good question! I've forwarded this to the landlord who can give you the most accurate answer. They'll be in touch shortly.`,
                    `I've sent your question to the landlord. They should respond within the hour with all the details you need.`
                ]
            },

            // Application inquiry
            application: {
                delay: 1200,
                templates: [
                    `Thanks for your interest in applying! The landlord will send you the application details shortly. Have you had a chance to view the property yet?`,
                    `Great! I've notified the landlord about your application interest. They'll be in touch soon with next steps. Do you have any questions about the property?`,
                    `Perfect! The landlord has been alerted and will send application information soon. In the meantime, feel free to ask any questions.`
                ]
            },

            // General inquiry
            general: {
                delay: 850,
                templates: [
                    `Hi! Thanks for reaching out. The landlord has been notified and will respond soon. What can I help you with regarding this property?`,
                    `Hey! I've forwarded your message to the landlord. They should be in touch shortly. Is there anything specific you'd like to know?`,
                    `Thanks for your message! The landlord will get back to you soon. Feel free to ask any questions you have about the listing.`
                ]
            }
        };
    }

    /**
     * Set up real-time listener for new messages
     */
    setupRealtimeListener() {
        // Listen for new messages in the messages table
        const messageChannel = this.supabase
            .channel('instant_response_messages_' + Math.random())
            .on('postgres_changes', {
                event: 'INSERT',
                schema: 'public',
                table: 'messages'
            }, async (payload) => {
                console.log('📨 New message received:', payload.new);
                await this.handleNewMessage(payload.new);
            })
            .subscribe((status) => {
                console.log('⚡ Instant Response subscription status:', status);
            });
    }

    /**
     * Handle new incoming message
     */
    async handleNewMessage(message) {
        try {
            // Skip if this is an AI response (prevent infinite loop)
            if (message.sender_email === 'ai-assistant@roomfinderai.com') {
                console.log('⏭️ Skipping AI message');
                return;
            }

            // Skip if we've already responded to this conversation recently
            const conversationId = message.conversation_id;
            if (this.activeResponses.has(conversationId)) {
                const lastResponse = this.activeResponses.get(conversationId);
                const timeSinceLastResponse = Date.now() - lastResponse;

                // Only auto-respond once every 5 minutes per conversation
                if (timeSinceLastResponse < 5 * 60 * 1000) {
                    console.log('⏭️ Already responded to this conversation recently');
                    return;
                }
            }

            // Get conversation details
            const conversation = await this.getConversationDetails(conversationId);
            if (!conversation) {
                console.error('❌ Could not find conversation');
                return;
            }

            // Determine if this is the first message in the conversation
            const messageCount = await this.getMessageCount(conversationId);
            const isFirstMessage = messageCount === 1;

            // Only auto-respond to the first message from a potential renter
            if (!isFirstMessage) {
                console.log('⏭️ Not first message, skipping auto-response');
                return;
            }

            // Determine message intent and select appropriate template
            const template = this.selectTemplate(message.message_text);

            // Generate and send instant response
            await this.sendInstantResponse(conversation, message, template);

            // Notify landlord about new inquiry
            await this.notifyLandlord(conversation, message);

            // Track response
            this.activeResponses.set(conversationId, Date.now());

        } catch (error) {
            console.error('❌ Error in handleNewMessage:', error);
        }
    }

    /**
     * Get conversation details
     */
    async getConversationDetails(conversationId) {
        try {
            const { data, error } = await this.supabase
                .from('conversations')
                .select(`
                    id,
                    listing_id,
                    sender_email,
                    receiver_email,
                    created_at,
                    listings!inner(
                        title,
                        user_email,
                        price,
                        city,
                        bedrooms
                    )
                `)
                .eq('id', conversationId)
                .single();

            if (error) throw error;
            return data;
        } catch (error) {
            console.error('❌ Error getting conversation:', error);
            return null;
        }
    }

    /**
     * Get message count for conversation
     */
    async getMessageCount(conversationId) {
        try {
            const { count, error } = await this.supabase
                .from('messages')
                .select('*', { count: 'exact', head: true })
                .eq('conversation_id', conversationId);

            if (error) throw error;
            return count || 0;
        } catch (error) {
            console.error('❌ Error counting messages:', error);
            return 0;
        }
    }

    /**
     * Select appropriate template based on message content
     */
    selectTemplate(messageText) {
        const text = messageText.toLowerCase();

        // Viewing/tour request
        if (text.includes('viewing') || text.includes('tour') || text.includes('see') ||
            text.includes('visit') || text.includes('look at') || text.includes('show')) {
            return this.responseTemplates.viewing;
        }

        // Application inquiry
        if (text.includes('apply') || text.includes('application') || text.includes('rent') ||
            text.includes('move in') || text.includes('available')) {
            return this.responseTemplates.application;
        }

        // Questions
        if (text.includes('?') || text.includes('question') || text.includes('wondering') ||
            text.includes('tell me') || text.includes('know more')) {
            return this.responseTemplates.questions;
        }

        // Default to initial contact template for general messages
        return this.responseTemplates.initial;
    }

    /**
     * Send instant response
     */
    async sendInstantResponse(conversation, originalMessage, template) {
        try {
            // Select random template message for variety
            const templateMessages = template.templates;
            const responseText = templateMessages[Math.floor(Math.random() * templateMessages.length)];

            // Calculate human-like delay
            const delay = template.delay + (Math.random() * 400 - 200); // ±200ms variance

            // Wait for human-like delay
            await new Promise(resolve => setTimeout(resolve, delay));

            // Send auto-response
            const { data, error } = await this.supabase
                .from('messages')
                .insert({
                    conversation_id: conversation.id,
                    sender_email: 'ai-assistant@roomfinderai.com',
                    message_text: responseText,
                    created_at: new Date().toISOString(),
                    is_auto_response: true // Flag for tracking
                });

            if (error) throw error;

            console.log('✅ Instant response sent:', {
                conversationId: conversation.id,
                delay: Math.round(delay) + 'ms',
                template: template === this.responseTemplates.viewing ? 'viewing' :
                         template === this.responseTemplates.application ? 'application' :
                         template === this.responseTemplates.questions ? 'questions' : 'initial'
            });

            // Track response time analytics
            await this.trackResponseTime(conversation.id, delay);

        } catch (error) {
            console.error('❌ Error sending instant response:', error);
        }
    }

    /**
     * Notify landlord about new inquiry
     */
    async notifyLandlord(conversation, message) {
        try {
            const landlordEmail = conversation.listings.user_email;
            const listingTitle = conversation.listings.title;
            const renterEmail = message.sender_email;

            console.log('📧 Notifying landlord:', {
                landlord: landlordEmail,
                listing: listingTitle,
                from: renterEmail
            });

            // TODO: Integrate with email notification system
            // This could use Brevo API or in-app notifications

            // For now, we'll create an in-app notification
            const notification = {
                user_email: landlordEmail,
                type: 'new_inquiry',
                title: 'New Inquiry Received',
                message: `You have a new inquiry about "${listingTitle}" from ${renterEmail}`,
                listing_id: conversation.listing_id,
                conversation_id: conversation.id,
                created_at: new Date().toISOString(),
                read: false
            };

            // Insert notification (assuming a notifications table exists)
            // If not, this will fail silently and landlord will see message in chat
            await this.supabase
                .from('notifications')
                .insert(notification)
                .then(() => console.log('✅ In-app notification created'))
                .catch(err => console.log('⚠️ Could not create notification:', err.message));

        } catch (error) {
            console.error('❌ Error notifying landlord:', error);
        }
    }

    /**
     * Track response time analytics
     */
    async trackResponseTime(conversationId, responseTime) {
        try {
            const analytics = {
                conversation_id: conversationId,
                response_time_ms: Math.round(responseTime),
                responded_at: new Date().toISOString(),
                response_type: 'auto'
            };

            // Insert into analytics table (create if doesn't exist)
            await this.supabase
                .from('response_analytics')
                .insert(analytics)
                .then(() => console.log('📊 Response time tracked'))
                .catch(err => console.log('⚠️ Could not track analytics:', err.message));

        } catch (error) {
            console.error('❌ Error tracking response time:', error);
        }
    }

    /**
     * Get average response time stats
     */
    async getResponseTimeStats() {
        try {
            const { data, error } = await this.supabase
                .from('response_analytics')
                .select('response_time_ms')
                .eq('response_type', 'auto')
                .order('responded_at', { ascending: false })
                .limit(100);

            if (error) throw error;

            if (!data || data.length === 0) {
                return { average: 0, count: 0 };
            }

            const sum = data.reduce((acc, curr) => acc + curr.response_time_ms, 0);
            const average = Math.round(sum / data.length);

            return {
                average: average,
                count: data.length,
                averageSeconds: (average / 1000).toFixed(1)
            };
        } catch (error) {
            console.error('❌ Error getting stats:', error);
            return { average: 0, count: 0 };
        }
    }

    /**
     * Destroy the instant response system
     */
    destroy() {
        this.activeResponses.clear();
        console.log('🗑️ Instant Response System destroyed');
    }
}

// Create global instance
window.instantResponseSystem = null;

// Initialize function to be called after auth
window.initializeInstantResponseSystem = (supabase, config) => {
    if (window.instantResponseSystem) {
        window.instantResponseSystem.destroy();
    }

    window.instantResponseSystem = new InstantResponseSystem(supabase, config);
    return window.instantResponseSystem;
};

export default InstantResponseSystem;
