// RoomPal API Service for Database Integration
// Handles all roommate profile and matching API calls

class RoommateAPIService {
    constructor() {
        this.supabase = null;
        this.initialized = false;
        this.init();
    }

    async init() {
        try {
            // Load configuration from Railway API (same pattern as listings.html)
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
                console.log('✅ RoomPal API Service initialized successfully');
            } else {
                console.error('❌ Supabase client not available');
            }
        } catch (error) {
            console.error('❌ Failed to initialize RoomPal API Service:', error);
            // Fallback to mock data if API fails
            this.initialized = false;
        }
    }

    // Ensure the service is initialized before making calls
    async ensureInitialized() {
        if (!this.initialized && typeof supabase !== 'undefined') {
            await this.init();
        }
        return this.initialized;
    }

    // ==================== PROFILE MANAGEMENT ====================

    /**
     * Get all active roommate profiles for matching
     * @param {Object} filters - Filtering options (age, location, etc.)
     * @returns {Array} Array of roommate profiles
     */
    async getRoommateProfiles(filters = {}) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                console.log('📝 Using mock data - database not available');
                return this.getMockProfiles();
            }

            let query = this.supabase
                .from('roommate_profiles')
                .select(`
                    id,
                    name,
                    last_name,
                    age,
                    occupation,
                    company,
                    location,
                    bio,
                    avatar_url,
                    photos,
                    personal_info,
                    lifestyle,
                    hobbies,
                    compatibility_scores,
                    is_active,
                    is_verified,
                    created_at,
                    last_active
                `)
                .eq('is_active', true)
                .order('last_active', { ascending: false });

            // Apply filters
            if (filters.ageMin) {
                query = query.gte('age', filters.ageMin);
            }
            if (filters.ageMax) {
                query = query.lte('age', filters.ageMax);
            }
            if (filters.location) {
                query = query.ilike('location', `%${filters.location}%`);
            }

            const { data, error } = await query.limit(20);

            if (error) {
                console.error('❌ Error fetching profiles:', error);
                return this.getMockProfiles();
            }

            console.log(`✅ Fetched ${data.length} roommate profiles from database`);
            return this.formatProfilesForUI(data);

        } catch (error) {
            console.error('❌ Error in getRoommateProfiles:', error);
            return this.getMockProfiles();
        }
    }

    /**
     * Get a specific roommate profile by ID
     * @param {string} profileId - The profile ID
     * @returns {Object} Profile data
     */
    async getProfile(profileId) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                return this.getMockProfile(profileId);
            }

            const { data, error } = await this.supabase
                .from('roommate_profiles')
                .select('*')
                .eq('id', profileId)
                .single();

            if (error) {
                console.error('❌ Error fetching profile:', error);
                return null;
            }

            return this.formatProfileForUI(data);

        } catch (error) {
            console.error('❌ Error in getProfile:', error);
            return null;
        }
    }

    /**
     * Create or update a user's roommate profile
     * @param {Object} profileData - Profile information
     * @returns {Object} Created/updated profile
     */
    async saveProfile(profileData) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                console.log('📝 Mock save - profile data:', profileData);
                return { success: true, data: profileData };
            }

            // Get current user
            const { data: { user } } = await this.supabase.auth.getUser();
            if (!user) {
                throw new Error('User not authenticated');
            }

            const profilePayload = {
                user_id: user.id,
                name: profileData.name,
                last_name: profileData.lastName,
                age: profileData.age,
                occupation: profileData.occupation,
                company: profileData.company,
                location: profileData.location,
                bio: profileData.bio,
                avatar_url: profileData.avatarUrl,
                photos: profileData.photos || [],
                personal_info: profileData.personalInfo || {},
                lifestyle: profileData.lifestyle || {},
                hobbies: profileData.hobbies || [],
                compatibility_scores: profileData.compatibilityScores || {},
                updated_at: new Date().toISOString()
            };

            // Check if profile exists
            const { data: existingProfile } = await this.supabase
                .from('roommate_profiles')
                .select('id')
                .eq('user_id', user.id)
                .single();

            let result;
            if (existingProfile) {
                // Update existing profile
                result = await this.supabase
                    .from('roommate_profiles')
                    .update(profilePayload)
                    .eq('user_id', user.id)
                    .select()
                    .single();
            } else {
                // Create new profile
                result = await this.supabase
                    .from('roommate_profiles')
                    .insert(profilePayload)
                    .select()
                    .single();
            }

            if (result.error) {
                throw result.error;
            }

            console.log('✅ Profile saved successfully');
            return { success: true, data: this.formatProfileForUI(result.data) };

        } catch (error) {
            console.error('❌ Error saving profile:', error);
            return { success: false, error: error.message };
        }
    }

    // ==================== ROOM POSTS (has_spot users) ====================

    /**
     * Get all room posts
     * @param {Object} filters - Filtering options
     * @returns {Array} Array of room posts
     */
    async getRoomPosts(filters = {}) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                console.log('📝 Using mock room data');
                return [];
            }

            let query = this.supabase
                .from('roommate_profiles')
                .select('*')
                .eq('user_type', 'has_spot')
                .eq('is_active', true)
                .order('created_at', { ascending: false });

            // Apply filters
            if (filters.maxRent) {
                query = query.lte('room_rent', filters.maxRent);
            }
            if (filters.minRent) {
                query = query.gte('room_rent', filters.minRent);
            }
            if (filters.roomType) {
                query = query.eq('room_type', filters.roomType);
            }
            if (filters.location) {
                query = query.ilike('room_location', `%${filters.location}%`);
            }

            const limit = filters.limit || 20;
            const { data, error } = await query.limit(limit);

            if (error) {
                console.error('❌ Error fetching room posts:', error);
                return [];
            }

            console.log(`✅ Fetched ${data.length} room posts`);
            return data;

        } catch (error) {
            console.error('❌ Error in getRoomPosts:', error);
            return [];
        }
    }

    /**
     * Save a room post
     * @param {Object} roomData - Room information
     * @returns {Object} Created/updated room post
     */
    async saveRoomPost(roomData) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                console.log('📝 Mock save room post');
                return { success: true, data: roomData };
            }

            const { data: { user } } = await this.supabase.auth.getUser();
            if (!user) {
                throw new Error('User not authenticated');
            }

            const payload = {
                user_id: user.id,
                user_type: 'has_spot',
                name: roomData.name || 'Host',
                room_rent: roomData.room_rent,
                room_location: roomData.room_location,
                room_type: roomData.room_type,
                room_available_date: roomData.room_available_date,
                room_description: roomData.room_description,
                room_photos: roomData.room_photos || [],
                is_active: true,
                updated_at: new Date().toISOString()
            };

            // Check for existing room post
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

            if (result.error) throw result.error;

            console.log('✅ Room post saved');
            return { success: true, data: result.data };

        } catch (error) {
            console.error('❌ Error saving room post:', error);
            return { success: false, error: error.message };
        }
    }

    // ==================== SEEKER PROFILES ====================

    /**
     * Get seeker profiles
     * @param {Object} filters - Filtering options
     * @returns {Array} Array of seeker profiles
     */
    async getSeekerProfiles(filters = {}) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                console.log('📝 Using mock seeker data');
                return [];
            }

            let query = this.supabase
                .from('roommate_profiles')
                .select('*')
                .eq('user_type', 'seeking')
                .eq('is_active', true)
                .order('last_active', { ascending: false });

            // Apply filters
            if (filters.maxBudget) {
                query = query.lte('budget_max', filters.maxBudget);
            }
            if (filters.minBudget) {
                query = query.gte('budget_min', filters.minBudget);
            }

            const limit = filters.limit || 20;
            const { data, error } = await query.limit(limit);

            if (error) {
                console.error('❌ Error fetching seeker profiles:', error);
                return [];
            }

            console.log(`✅ Fetched ${data.length} seeker profiles`);
            return data;

        } catch (error) {
            console.error('❌ Error in getSeekerProfiles:', error);
            return [];
        }
    }

    /**
     * Save a seeker profile
     * @param {Object} profileData - Seeker profile information
     * @returns {Object} Created/updated profile
     */
    async saveSeekerProfile(profileData) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                console.log('📝 Mock save seeker profile');
                return { success: true, data: profileData };
            }

            const { data: { user } } = await this.supabase.auth.getUser();
            if (!user) {
                throw new Error('User not authenticated');
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
                is_active: true,
                last_active: new Date().toISOString(),
                updated_at: new Date().toISOString()
            };

            // Check for existing seeker profile
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

            if (result.error) throw result.error;

            console.log('✅ Seeker profile saved');
            return { success: true, data: result.data };

        } catch (error) {
            console.error('❌ Error saving seeker profile:', error);
            return { success: false, error: error.message };
        }
    }

    // ==================== GROUP MANAGEMENT ====================

    /**
     * Create a roommate group
     * @param {Object} groupData - Group information
     * @returns {Object} Created group
     */
    async createGroup(groupData) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                console.log('📝 Mock create group');
                return { success: true, data: { id: 'mock_group_' + Date.now(), ...groupData } };
            }

            const { data: { user } } = await this.supabase.auth.getUser();
            if (!user) {
                throw new Error('User not authenticated');
            }

            // Create the group
            const { data: group, error: groupError } = await this.supabase
                .from('roommate_groups')
                .insert({
                    name: groupData.name || 'Roommate Group',
                    description: groupData.description,
                    creator_id: user.id,
                    target_budget_min: groupData.budget_min,
                    target_budget_max: groupData.budget_max,
                    target_move_in_date: groupData.move_in_date,
                    preferred_areas: groupData.preferred_areas || [],
                    max_members: groupData.max_members || 4,
                    status: 'forming'
                })
                .select()
                .single();

            if (groupError) throw groupError;

            // Add creator as first member
            const { error: memberError } = await this.supabase
                .from('roommate_group_members')
                .insert({
                    group_id: group.id,
                    user_id: user.id,
                    role: 'creator',
                    status: 'accepted'
                });

            if (memberError) throw memberError;

            console.log('✅ Group created');
            return { success: true, data: group };

        } catch (error) {
            console.error('❌ Error creating group:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Invite a user to a group
     * @param {string} groupId - Group ID
     * @param {string} userId - User to invite
     * @returns {Object} Invitation result
     */
    async inviteToGroup(groupId, userId) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                console.log('📝 Mock invite to group');
                return { success: true };
            }

            const { error } = await this.supabase
                .from('roommate_group_members')
                .insert({
                    group_id: groupId,
                    user_id: userId,
                    role: 'member',
                    status: 'pending'
                });

            if (error) throw error;

            console.log('✅ Invitation sent');
            return { success: true };

        } catch (error) {
            console.error('❌ Error inviting to group:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Get user's group
     * @returns {Object} Group data with members
     */
    async getMyGroup() {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                return null;
            }

            const { data: { user } } = await this.supabase.auth.getUser();
            if (!user) return null;

            // Find group where user is a member
            const { data: membership } = await this.supabase
                .from('roommate_group_members')
                .select('group_id')
                .eq('user_id', user.id)
                .eq('status', 'accepted')
                .single();

            if (!membership) return null;

            // Get group details with members
            const { data: group, error } = await this.supabase
                .from('roommate_groups')
                .select(`
                    *,
                    roommate_group_members (
                        user_id,
                        role,
                        status,
                        joined_at
                    )
                `)
                .eq('id', membership.group_id)
                .single();

            if (error) throw error;

            return group;

        } catch (error) {
            console.error('❌ Error fetching group:', error);
            return null;
        }
    }

    // ==================== MESSAGING ====================

    /**
     * Send a message
     * @param {string} recipientId - Recipient user ID
     * @param {string} content - Message content
     * @returns {Object} Message result
     */
    async sendMessage(recipientId, content) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                console.log('📝 Mock send message');
                return { success: true };
            }

            const { data: { user } } = await this.supabase.auth.getUser();
            if (!user) {
                throw new Error('User not authenticated');
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

                if (convError) throw convError;
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

            if (msgError) throw msgError;

            // Update conversation last message time
            await this.supabase
                .from('roommate_conversations')
                .update({ last_message_at: new Date().toISOString() })
                .eq('id', conversation.id);

            console.log('✅ Message sent');
            return { success: true };

        } catch (error) {
            console.error('❌ Error sending message:', error);
            return { success: false, error: error.message };
        }
    }

    // ==================== MATCHING SYSTEM ====================

    /**
     * Record a match action (like, pass, super_like)
     * @param {string} targetProfileId - The profile being acted upon
     * @param {string} action - 'like', 'pass', 'super_like'
     * @returns {Object} Match result
     */
    async recordMatch(targetProfileId, action) {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                console.log(`📝 Mock match action: ${action} on profile ${targetProfileId}`);
                return { success: true, isMutual: Math.random() > 0.7 };
            }

            const { data: { user } } = await this.supabase.auth.getUser();
            if (!user) {
                throw new Error('User not authenticated');
            }

            // Calculate compatibility score
            const compatibilityScore = await this.calculateCompatibility(user.id, targetProfileId);

            const matchData = {
                user_id: user.id,
                target_profile_id: targetProfileId,
                action: action,
                compatibility_score: compatibilityScore
            };

            // Insert match record (will update if exists due to unique constraint)
            const { data, error } = await this.supabase
                .from('roommate_matches')
                .upsert(matchData)
                .select()
                .single();

            if (error) {
                throw error;
            }

            // Check for mutual match if this was a 'like'
            let isMutual = false;
            if (action === 'like' || action === 'super_like') {
                const { data: mutualMatch } = await this.supabase
                    .from('roommate_matches')
                    .select('*')
                    .eq('user_id', targetProfileId)
                    .eq('target_profile_id', user.id)
                    .in('action', ['like', 'super_like'])
                    .single();

                if (mutualMatch) {
                    isMutual = true;
                    // Update both records to mark as mutual
                    await this.supabase
                        .from('roommate_matches')
                        .update({ is_mutual: true })
                        .in('id', [data.id, mutualMatch.id]);

                    // Create conversation for mutual match
                    await this.createConversation(user.id, targetProfileId);
                }
            }

            console.log(`✅ Match recorded: ${action} ${isMutual ? '(MUTUAL!)' : ''}`);
            return { success: true, isMutual, matchId: data.id };

        } catch (error) {
            console.error('❌ Error recording match:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Calculate compatibility score between two users
     * @param {string} userId1 - First user ID
     * @param {string} userId2 - Second user ID
     * @returns {number} Compatibility score (0-100)
     */
    async calculateCompatibility(userId1, userId2) {
        try {
            if (!this.supabase) {
                return Math.floor(Math.random() * 40) + 60; // Mock score 60-100
            }

            // Use the database function if available
            const { data, error } = await this.supabase
                .rpc('calculate_compatibility_score', {
                    profile1_id: userId1,
                    profile2_id: userId2
                });

            if (error) {
                console.error('❌ Error calculating compatibility:', error);
                return Math.floor(Math.random() * 40) + 60;
            }

            return parseFloat(data) || 70;

        } catch (error) {
            console.error('❌ Error in calculateCompatibility:', error);
            return 70; // Default score
        }
    }

    // ==================== PHOTO MANAGEMENT ====================

    /**
     * Upload a photo for a user's profile
     * @param {File} file - The image file
     * @param {string} type - Photo type ('main', 'hobby', 'lifestyle', etc.)
     * @returns {Object} Upload result with URL
     */
    async uploadPhoto(file, type = 'main') {
        try {
            await this.ensureInitialized();

            if (!this.supabase) {
                console.log('📝 Mock photo upload');
                return {
                    success: true,
                    url: 'https://images.unsplash.com/photo-1494790108755-2616b612b5bc?w=400&h=600&fit=crop&crop=face',
                    type
                };
            }

            const { data: { user } } = await this.supabase.auth.getUser();
            if (!user) {
                throw new Error('User not authenticated');
            }

            // Generate unique filename
            const fileExt = file.name.split('.').pop();
            const fileName = `${user.id}/${type}_${Date.now()}.${fileExt}`;

            // Upload to Supabase Storage
            const { data, error } = await this.supabase.storage
                .from('roommate-photos')
                .upload(fileName, file, {
                    cacheControl: '3600',
                    upsert: false
                });

            if (error) {
                throw error;
            }

            // Get public URL
            const { data: { publicUrl } } = this.supabase.storage
                .from('roommate-photos')
                .getPublicUrl(fileName);

            console.log('✅ Photo uploaded successfully');
            return { success: true, url: publicUrl, type, fileName };

        } catch (error) {
            console.error('❌ Error uploading photo:', error);
            return { success: false, error: error.message };
        }
    }

    // ==================== HELPER METHODS ====================

    /**
     * Format database profiles for UI display
     * @param {Array} profiles - Raw database profiles
     * @returns {Array} Formatted profiles
     */
    formatProfilesForUI(profiles) {
        return profiles.map(profile => this.formatProfileForUI(profile));
    }

    /**
     * Format a single database profile for UI display
     * @param {Object} profile - Raw database profile
     * @returns {Object} Formatted profile
     */
    formatProfileForUI(profile) {
        return {
            id: profile.id,
            name: profile.name,
            lastName: profile.last_name,
            age: profile.age,
            occupation: profile.occupation || 'Student',
            company: profile.company || 'Local University',
            location: profile.location || 'San Francisco, CA',
            distance: this.calculateDistance(profile.location),
            avatar: {
                gradient: 'from-blue-400 via-purple-500 to-pink-600',
                icon: this.getRandomIcon(),
                photos: profile.photos || []
            },
            personalInfo: profile.personal_info || {},
            lifestyle: profile.lifestyle || {},
            hobbies: profile.hobbies || [],
            compatibility: profile.compatibility_scores || {},
            topCompatibilityFactors: this.generateTopFactors(profile.compatibility_scores),
            quickFacts: this.generateQuickFacts(profile),
            verified: profile.is_verified || false,
            lastActive: this.formatLastActive(profile.last_active),
            bio: profile.bio || 'Looking for a great roommate to share adventures and create memories together!',
            overall: this.calculateOverallScore(profile.compatibility_scores)
        };
    }

    /**
     * Generate mock profiles for development/fallback
     * @returns {Array} Mock profile data
     */
    getMockProfiles() {
        return [
            {
                id: 'mock-1',
                name: 'Sarah',
                lastName: 'Chen',
                age: 22,
                occupation: 'Computer Science Student',
                company: 'UC Berkeley',
                location: 'Berkeley, CA',
                distance: '2.3 miles away',
                avatar: {
                    gradient: 'from-pink-400 via-purple-500 to-indigo-600',
                    icon: '👩‍💻',
                    photos: [
                        {
                            url: 'https://images.unsplash.com/photo-1494790108755-2616b612b5bc?w=400&h=600&fit=crop&crop=face',
                            type: 'main',
                            caption: 'Sarah in her favorite coding setup'
                        },
                        {
                            url: 'https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=400&h=600&fit=crop',
                            type: 'hobby',
                            caption: 'Gaming and study space'
                        }
                    ]
                },
                hobbies: [
                    { name: 'Gaming', icon: '🎮', category: 'entertainment' },
                    { name: 'Coding', icon: '💻', category: 'professional' },
                    { name: 'Anime', icon: '🎭', category: 'entertainment' }
                ],
                topCompatibilityFactors: [
                    { name: 'Sleep Schedule', score: 95 },
                    { name: 'Cleanliness', score: 92 },
                    { name: 'Study Habits', score: 88 }
                ],
                quickFacts: [
                    { icon: '🎓', text: 'CS Student' },
                    { icon: '🌙', text: 'Night Owl' },
                    { icon: '🧹', text: 'Very Clean' }
                ],
                verified: true,
                lastActive: '2 hours ago',
                bio: 'CS student who codes by night and games by day. Looking for a clean, quiet study buddy!',
                overall: 92
            }
        ];
    }

    // Utility methods
    calculateDistance(location) {
        const distances = ['1.2 miles away', '2.3 miles away', '3.1 miles away', '4.5 miles away'];
        return distances[Math.floor(Math.random() * distances.length)];
    }

    getRandomIcon() {
        const icons = ['👨‍💻', '👩‍💻', '👨‍🎨', '👩‍🎨', '👨‍💼', '👩‍💼', '👨‍🎓', '👩‍🎓'];
        return icons[Math.floor(Math.random() * icons.length)];
    }

    generateTopFactors(compatibilityScores) {
        const factors = [
            { name: 'Sleep Schedule', score: Math.floor(Math.random() * 20) + 80 },
            { name: 'Cleanliness', score: Math.floor(Math.random() * 20) + 80 },
            { name: 'Social Level', score: Math.floor(Math.random() * 20) + 80 }
        ];
        return factors.sort((a, b) => b.score - a.score);
    }

    generateQuickFacts(profile) {
        const facts = [
            { icon: '🎓', text: 'Student' },
            { icon: '🌙', text: 'Night Owl' },
            { icon: '🧹', text: 'Clean' },
            { icon: '👥', text: 'Social' },
            { icon: '🍳', text: 'Loves Cooking' }
        ];
        return facts.slice(0, 5);
    }

    formatLastActive(lastActive) {
        if (!lastActive) return 'Recently active';
        const now = new Date();
        const active = new Date(lastActive);
        const diffHours = Math.floor((now - active) / (1000 * 60 * 60));

        if (diffHours < 1) return 'Active now';
        if (diffHours < 24) return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
        const diffDays = Math.floor(diffHours / 24);
        return `${diffDays} day${diffDays > 1 ? 's' : ''} ago`;
    }

    calculateOverallScore(compatibilityScores) {
        if (!compatibilityScores) return Math.floor(Math.random() * 20) + 80;

        const scores = Object.values(compatibilityScores).filter(score => typeof score === 'number');
        if (scores.length === 0) return Math.floor(Math.random() * 20) + 80;

        const average = scores.reduce((sum, score) => sum + score, 0) / scores.length;
        return Math.floor(average * 10); // Convert to percentage
    }

    async createConversation(user1Id, user2Id) {
        try {
            const { data, error } = await this.supabase
                .from('roommate_conversations')
                .insert({
                    user1_id: user1Id,
                    user2_id: user2Id
                })
                .select()
                .single();

            if (error) throw error;

            console.log('✅ Conversation created for mutual match');
            return data;
        } catch (error) {
            console.error('❌ Error creating conversation:', error);
            return null;
        }
    }
}

// Global instance
window.roommateAPI = new RoommateAPIService();