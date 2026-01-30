// RoomPal API Service - Simplified
// Database-driven, no mock data fallbacks

class RoommateAPIService {
    constructor() {
        this.supabase = null;
        this.initialized = false;
        this.init();
    }

    async init() {
        try {
            // Use existing Supabase client if available
            if (window.AppConfig && window.AppConfig.supabase) {
                this.supabase = window.AppConfig.supabase;
                this.initialized = true;
                console.log('RoomPal API initialized (using existing client)');
                return;
            }

            // Fallback: fetch config and create client
            const response = await fetch('/api/config');
            if (!response.ok) {
                throw new Error(`Config fetch failed: ${response.status}`);
            }

            const config = await response.json();
            const SUPABASE_URL = config.SUPABASE_URL;
            const SUPABASE_ANON_KEY = config.SUPABASE_ANON_KEY;

            if (typeof supabase !== 'undefined') {
                this.supabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
                this.initialized = true;
                console.log('RoomPal API initialized');
            }
        } catch (error) {
            console.error('Failed to initialize RoomPal API:', error);
            this.initialized = false;
        }
    }

    async ensureInitialized() {
        if (!this.initialized && typeof supabase !== 'undefined') {
            await this.init();
        }
        return this.initialized;
    }

    // ==================== ROOM POSTS (has_spot) ====================

    async getRoomPosts(filters = {}) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                console.log('Database not available');
                return [];
            }

            let query = this.supabase
                .from('roommate_profiles')
                .select('*')
                .eq('user_type', 'has_spot')
                .eq('is_active', true)
                .order('created_at', { ascending: false });

            if (filters.maxRent) {
                query = query.lte('room_rent', filters.maxRent);
            }
            if (filters.minRent) {
                query = query.gte('room_rent', filters.minRent);
            }
            if (filters.location) {
                query = query.ilike('room_location', `%${filters.location}%`);
            }

            const limit = filters.limit || 50;
            const { data, error } = await query.limit(limit);

            if (error) {
                console.error('Error fetching rooms:', error);
                return [];
            }

            console.log(`Fetched ${data.length} rooms`);
            return data;

        } catch (error) {
            console.error('Error in getRoomPosts:', error);
            return [];
        }
    }

    async saveRoomPost(roomData) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                return { success: false, error: 'Database not available' };
            }

            // Get user from localStorage (app uses Railway backend auth, not Supabase auth)
            const storedUser = localStorage.getItem('currentUser');
            if (!storedUser) {
                return { success: false, error: 'Not authenticated. Please log in.' };
            }
            const user = JSON.parse(storedUser);
            if (!user || !user.id) {
                return { success: false, error: 'Invalid user session. Please log in again.' };
            }

            const payload = {
                user_id: user.id,
                user_type: 'has_spot',
                name: roomData.name || 'Host',
                room_rent: roomData.room_rent,
                room_location: roomData.room_location,
                room_available_date: roomData.room_available_date,
                room_description: roomData.room_description,
                room_photos: roomData.room_photos || [],
                is_active: true,
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            };

            // Check for existing
            const { data: existing } = await this.supabase
                .from('roommate_profiles')
                .select('id')
                .eq('user_id', user.id)
                .eq('user_type', 'has_spot')
                .single();

            let result;
            if (existing) {
                result = await this.supabase
                    .from('roommate_profiles')
                    .update(payload)
                    .eq('id', existing.id)
                    .select()
                    .single();
            } else {
                result = await this.supabase
                    .from('roommate_profiles')
                    .insert(payload)
                    .select()
                    .single();
            }

            if (result.error) {
                return { success: false, error: result.error.message };
            }

            console.log('Room post saved');
            return { success: true, data: result.data };

        } catch (error) {
            console.error('Error saving room:', error);
            return { success: false, error: error.message };
        }
    }

    // ==================== SEEKER PROFILES ====================

    async getSeekerProfiles(filters = {}) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                return [];
            }

            let query = this.supabase
                .from('roommate_profiles')
                .select('*')
                .eq('user_type', 'seeking')
                .eq('is_active', true)
                .order('created_at', { ascending: false });

            if (filters.maxBudget) {
                query = query.lte('budget_max', filters.maxBudget);
            }
            if (filters.minBudget) {
                query = query.gte('budget_min', filters.minBudget);
            }

            const limit = filters.limit || 50;
            const { data, error } = await query.limit(limit);

            if (error) {
                console.error('Error fetching seekers:', error);
                return [];
            }

            return data;

        } catch (error) {
            console.error('Error in getSeekerProfiles:', error);
            return [];
        }
    }

    async saveSeekerProfile(profileData) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                return { success: false, error: 'Database not available' };
            }

            // Get user from localStorage (app uses Railway backend auth, not Supabase auth)
            const storedUser = localStorage.getItem('currentUser');
            if (!storedUser) {
                return { success: false, error: 'Not authenticated. Please log in.' };
            }
            const user = JSON.parse(storedUser);
            if (!user || !user.id) {
                return { success: false, error: 'Invalid user session. Please log in again.' };
            }

            const payload = {
                user_id: user.id,
                user_type: 'seeking',
                name: profileData.name || 'Anonymous',
                budget_min: profileData.budget_min,
                budget_max: profileData.budget_max,
                preferred_areas: profileData.preferred_areas || [],
                move_in_date: profileData.move_in_date,
                bio: profileData.bio,
                avatar_url: profileData.avatar_url,
                lifestyle: profileData.lifestyle || {},
                compatibility_scores: profileData.compatibility_scores || {},
                is_active: true,
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            };

            // Check for existing
            const { data: existing } = await this.supabase
                .from('roommate_profiles')
                .select('id')
                .eq('user_id', user.id)
                .eq('user_type', 'seeking')
                .single();

            let result;
            if (existing) {
                result = await this.supabase
                    .from('roommate_profiles')
                    .update(payload)
                    .eq('id', existing.id)
                    .select()
                    .single();
            } else {
                result = await this.supabase
                    .from('roommate_profiles')
                    .insert(payload)
                    .select()
                    .single();
            }

            if (result.error) {
                return { success: false, error: result.error.message };
            }

            return { success: true, data: result.data };

        } catch (error) {
            console.error('Error saving seeker:', error);
            return { success: false, error: error.message };
        }
    }

    // ==================== MESSAGING ====================

    async sendMessage(recipientId, content) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                console.log('Message not sent - database unavailable');
                return { success: false, error: 'Database not available. Please try again later.' };
            }

            // Get user from localStorage (app uses Railway backend auth, not Supabase auth)
            const storedUser = localStorage.getItem('currentUser');
            if (!storedUser) {
                return { success: false, error: 'Not authenticated. Please log in.' };
            }
            const user = JSON.parse(storedUser);
            if (!user || !user.id) {
                return { success: false, error: 'Invalid user session. Please log in again.' };
            }

            // Find or create conversation
            let { data: conversation } = await this.supabase
                .from('roommate_conversations')
                .select('id')
                .or(`and(user1_id.eq.${user.id},user2_id.eq.${recipientId}),and(user1_id.eq.${recipientId},user2_id.eq.${user.id})`)
                .single();

            if (!conversation) {
                const { data: newConv, error: convError } = await this.supabase
                    .from('roommate_conversations')
                    .insert({
                        user1_id: user.id,
                        user2_id: recipientId
                    })
                    .select()
                    .single();

                if (convError) {
                    console.error('Error creating conversation:', convError);
                    return { success: false, error: 'Failed to start conversation. Please try again.' };
                }
                conversation = newConv;
            }

            // Send message
            const { error: msgError } = await this.supabase
                .from('roommate_messages')
                .insert({
                    conversation_id: conversation.id,
                    sender_id: user.id,
                    content: content,
                    message_type: 'text'
                });

            if (msgError) {
                console.error('Error sending message:', msgError);
                return { success: false, error: 'Failed to send message. Please try again.' };
            }

            // Update last message time
            await this.supabase
                .from('roommate_conversations')
                .update({ last_message_at: new Date().toISOString() })
                .eq('id', conversation.id);

            return { success: true };

        } catch (error) {
            console.error('Error in sendMessage:', error);
            return { success: false, error: error.message || 'Failed to send message. Please try again.' };
        }
    }
}

// Global instance
window.roommateAPI = new RoommateAPIService();
