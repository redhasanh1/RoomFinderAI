/**
 * Database Integration Module
 * Ensures all frontend features properly save to Supabase
 */

class DatabaseIntegration {
    constructor(supabaseClient) {
        this.supabase = supabaseClient;
        this.authManager = null;
    }

    /**
     * Initialize with auth manager
     */
    async initialize(authManager) {
        this.authManager = authManager;
        console.log('✅ Database integration initialized');
    }

    /**
     * LISTINGS MANAGEMENT
     */
    async createListing(listingData, images = []) {
        try {
            const user = this.authManager.getCurrentUser();
            if (!user) throw new Error('User not authenticated');

            // Upload images first
            const imageUrls = await this.uploadListingImages(images, user.id);

            // Create listing with proper user_id
            const { data, error } = await this.supabase
                .from('listings')
                .insert({
                    ...listingData,
                    user_id: user.id,
                    media: imageUrls,
                    status: 'active',
                    created_at: new Date().toISOString()
                })
                .select()
                .single();

            if (error) throw error;
            console.log('✅ Listing created and saved to database:', data.id);
            return data;
        } catch (error) {
            console.error('❌ Error creating listing:', error);
            throw error;
        }
    }

    async uploadListingImages(images, userId) {
        const uploadedUrls = [];
        
        for (const image of images) {
            const fileName = `${userId}/${Date.now()}_${image.name}`;
            const { data, error } = await this.supabase.storage
                .from('listing-images')
                .upload(fileName, image);

            if (!error) {
                const { data: { publicUrl } } = this.supabase.storage
                    .from('listing-images')
                    .getPublicUrl(fileName);
                uploadedUrls.push(publicUrl);
            }
        }
        
        return uploadedUrls;
    }

    /**
     * USER PROFILE MANAGEMENT
     */
    async updateUserProfile(updates) {
        try {
            const user = this.authManager.getCurrentUser();
            if (!user) throw new Error('User not authenticated');

            // Update in users table
            const { data: userData, error: userError } = await this.supabase
                .from('users')
                .update({
                    first_name: updates.firstName,
                    last_name: updates.lastName,
                    phone: updates.phone,
                    updated_at: new Date().toISOString()
                })
                .eq('id', user.id)
                .select()
                .single();

            if (userError) throw userError;

            // Update in profiles table
            const { data: profileData, error: profileError } = await this.supabase
                .from('profiles')
                .update({
                    first_name: updates.firstName,
                    last_name: updates.lastName,
                    phone: updates.phone,
                    city: updates.city,
                    street: updates.street,
                    postalcode: updates.postalCode,
                    bio: updates.bio,
                    updated_at: new Date().toISOString()
                })
                .eq('user_id', user.id)
                .select()
                .single();

            console.log('✅ Profile updated in database');
            return profileData || userData;
        } catch (error) {
            console.error('❌ Error updating profile:', error);
            throw error;
        }
    }

    async uploadProfilePicture(file) {
        try {
            const user = this.authManager.getCurrentUser();
            if (!user) throw new Error('User not authenticated');

            // Upload to Supabase Storage
            const fileName = `${user.id}/profile.${file.name.split('.').pop()}`;
            const { data: uploadData, error: uploadError } = await this.supabase.storage
                .from('profile-images')
                .upload(fileName, file, { upsert: true });

            if (uploadError) throw uploadError;

            // Get public URL
            const { data: { publicUrl } } = this.supabase.storage
                .from('profile-images')
                .getPublicUrl(fileName);

            // Update both tables with new URL
            await this.supabase
                .from('users')
                .update({ profile_image_url: publicUrl })
                .eq('id', user.id);

            await this.supabase
                .from('profiles')
                .update({ profile_image_url: publicUrl })
                .eq('user_id', user.id);

            console.log('✅ Profile picture uploaded and saved');
            return publicUrl;
        } catch (error) {
            console.error('❌ Error uploading profile picture:', error);
            throw error;
        }
    }

    /**
     * FAVORITES MANAGEMENT
     */
    async toggleFavorite(listingId) {
        try {
            const user = this.authManager.getCurrentUser();
            if (!user) throw new Error('User not authenticated');

            // Check if already favorited
            const { data: existing } = await this.supabase
                .from('favorites')
                .select('id')
                .eq('user_id', user.id)
                .eq('listing_id', listingId)
                .single();

            if (existing) {
                // Remove favorite
                const { error } = await this.supabase
                    .from('favorites')
                    .delete()
                    .eq('id', existing.id);

                if (error) throw error;
                console.log('✅ Removed from favorites');
                return { favorited: false };
            } else {
                // Add favorite
                const { data, error } = await this.supabase
                    .from('favorites')
                    .insert({
                        user_id: user.id,
                        listing_id: listingId
                    })
                    .select()
                    .single();

                if (error) throw error;
                console.log('✅ Added to favorites');
                return { favorited: true, data };
            }
        } catch (error) {
            console.error('❌ Error toggling favorite:', error);
            throw error;
        }
    }

    async getUserFavorites() {
        try {
            const user = this.authManager.getCurrentUser();
            if (!user) return [];

            const { data, error } = await this.supabase
                .from('favorites')
                .select(`
                    *,
                    listing:listings(*)
                `)
                .eq('user_id', user.id)
                .order('created_at', { ascending: false });

            if (error) throw error;
            return data || [];
        } catch (error) {
            console.error('❌ Error fetching favorites:', error);
            return [];
        }
    }

    /**
     * CHAT/MESSAGING
     */
    async sendMessage(conversationId, content, fileAttachment = null) {
        try {
            const user = this.authManager.getCurrentUser();
            if (!user) throw new Error('User not authenticated');

            let fileUrl = null;
            let fileName = null;
            let fileType = null;
            let fileSize = null;

            // Handle file attachment
            if (fileAttachment) {
                const uploadPath = `${conversationId}/${Date.now()}_${fileAttachment.name}`;
                const { data: uploadData, error: uploadError } = await this.supabase.storage
                    .from('chat-attachments')
                    .upload(uploadPath, fileAttachment);

                if (!uploadError) {
                    const { data: { publicUrl } } = this.supabase.storage
                        .from('chat-attachments')
                        .getPublicUrl(uploadPath);
                    
                    fileUrl = publicUrl;
                    fileName = fileAttachment.name;
                    fileType = fileAttachment.type;
                    fileSize = fileAttachment.size;
                }
            }

            // Insert message
            const { data, error } = await this.supabase
                .from('messages')
                .insert({
                    conversation_id: conversationId,
                    user_id: user.id,
                    sender_email: user.email,
                    content: content,
                    message_type: fileAttachment ? 'file' : 'text',
                    file_url: fileUrl,
                    file_name: fileName,
                    file_type: fileType,
                    file_size: fileSize,
                    created_at: new Date().toISOString()
                })
                .select()
                .single();

            if (error) throw error;

            // Update conversation last message time
            await this.supabase
                .from('conversations')
                .update({ 
                    last_message_at: new Date().toISOString(),
                    updated_at: new Date().toISOString()
                })
                .eq('id', conversationId);

            console.log('✅ Message sent and saved');
            return data;
        } catch (error) {
            console.error('❌ Error sending message:', error);
            throw error;
        }
    }

    /**
     * BOOKINGS MANAGEMENT
     */
    async createBooking(bookingData) {
        try {
            const user = this.authManager.getCurrentUser();
            if (!user) throw new Error('User not authenticated');

            const { data, error } = await this.supabase
                .from('bookings')
                .insert({
                    ...bookingData,
                    user_id: user.id,
                    status: 'pending',
                    payment_status: 'unpaid',
                    created_at: new Date().toISOString()
                })
                .select()
                .single();

            if (error) throw error;

            // Create notification for landlord
            await this.createNotification(
                bookingData.landlord_id,
                'booking_request',
                'New Booking Request',
                `You have a new booking request for ${bookingData.listing_title}`,
                { booking_id: data.id }
            );

            console.log('✅ Booking created and saved');
            return data;
        } catch (error) {
            console.error('❌ Error creating booking:', error);
            throw error;
        }
    }

    /**
     * REVIEWS MANAGEMENT
     */
    async createReview(reviewData) {
        try {
            const user = this.authManager.getCurrentUser();
            if (!user) throw new Error('User not authenticated');

            const { data, error } = await this.supabase
                .from('reviews')
                .insert({
                    ...reviewData,
                    user_id: user.id,
                    created_at: new Date().toISOString()
                })
                .select()
                .single();

            if (error) throw error;
            console.log('✅ Review created and saved');
            return data;
        } catch (error) {
            console.error('❌ Error creating review:', error);
            throw error;
        }
    }

    /**
     * SEARCH & PREFERENCES
     */
    async saveSearchHistory(searchQuery, filters, resultsCount) {
        try {
            const user = this.authManager.getCurrentUser();
            
            const { data, error } = await this.supabase
                .from('search_history')
                .insert({
                    user_id: user?.id || null,
                    search_query: searchQuery,
                    filters: filters,
                    results_count: resultsCount,
                    session_id: this.getSessionId(),
                    created_at: new Date().toISOString()
                })
                .select()
                .single();

            if (!error) {
                console.log('✅ Search history saved');
            }
            return data;
        } catch (error) {
            console.error('⚠️ Error saving search history:', error);
            // Don't throw - search history is non-critical
        }
    }

    async updateUserPreferences(preferences) {
        try {
            const user = this.authManager.getCurrentUser();
            if (!user) return;

            const { data, error } = await this.supabase
                .from('user_preferences')
                .upsert({
                    user_id: user.id,
                    ...preferences,
                    updated_at: new Date().toISOString()
                })
                .select()
                .single();

            if (!error) {
                console.log('✅ User preferences updated');
            }
            return data;
        } catch (error) {
            console.error('⚠️ Error updating preferences:', error);
        }
    }

    /**
     * LISTING VIEWS TRACKING
     */
    async trackListingView(listingId) {
        try {
            const user = this.authManager.getCurrentUser();
            
            const { data, error } = await this.supabase
                .from('listing_views')
                .insert({
                    listing_id: listingId,
                    user_id: user?.id || null,
                    session_id: this.getSessionId(),
                    viewed_at: new Date().toISOString()
                })
                .select()
                .single();

            if (!error) {
                console.log('✅ Listing view tracked');
            }
            return data;
        } catch (error) {
            console.error('⚠️ Error tracking listing view:', error);
        }
    }

    /**
     * NOTIFICATIONS
     */
    async createNotification(userId, type, title, message, data = {}) {
        try {
            const { error } = await this.supabase
                .from('notifications')
                .insert({
                    user_id: userId,
                    type: type,
                    title: title,
                    message: message,
                    data: data,
                    created_at: new Date().toISOString()
                });

            if (!error) {
                console.log('✅ Notification created');
            }
        } catch (error) {
            console.error('⚠️ Error creating notification:', error);
        }
    }

    async getUnreadNotifications() {
        try {
            const user = this.authManager.getCurrentUser();
            if (!user) return [];

            const { data, error } = await this.supabase
                .from('notifications')
                .select('*')
                .eq('user_id', user.id)
                .eq('is_read', false)
                .order('created_at', { ascending: false });

            if (error) throw error;
            return data || [];
        } catch (error) {
            console.error('❌ Error fetching notifications:', error);
            return [];
        }
    }

    /**
     * HELPER METHODS
     */
    getSessionId() {
        let sessionId = sessionStorage.getItem('session_id');
        if (!sessionId) {
            sessionId = `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
            sessionStorage.setItem('session_id', sessionId);
        }
        return sessionId;
    }
}

// Export for use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = DatabaseIntegration;
} else {
    window.DatabaseIntegration = DatabaseIntegration;
}