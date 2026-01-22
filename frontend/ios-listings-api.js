/**
 * iOS-Compatible Listings API for RoomFinderAI
 * 
 * This module provides iOS-compatible listings functionality that replaces all
 * fetch calls with @capacitor/http for reliable iOS networking.
 */

import { fetch } from './ios-universal-fetch.js';
import { createClient } from './ios-supabase-client.js';
import iosAuthManager from './ios-auth-manager.js';

// Supabase configuration
const SUPABASE_URL = 'https://zmxyysauqtfkvntgtjsm.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM';

class IOSListingsAPI {
    constructor() {
        this.supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        this.debug = true;
        
        if (this.debug) {
            console.log('🏠 iOS Listings API initialized');
        }
    }

    /**
     * Fetch all listings with optional filters
     */
    async fetchListings(filters = {}) {
        try {
            if (this.debug) {
                console.log('📋 Fetching listings with filters:', filters);
            }

            // Select only needed columns to reduce egress costs
            let query = this.supabase
                .from('listings')
                .select('id, title, price, city, street, postalCode, house_type, bedrooms, bathrooms, utilities, description, media, user_email, created_at, status, location, category');

            // Apply filters
            if (filters.category) {
                query = query.eq('category', filters.category);
            }
            
            if (filters.minPrice) {
                query = query.gte('price', filters.minPrice);
            }
            
            if (filters.maxPrice) {
                query = query.lte('price', filters.maxPrice);
            }
            
            if (filters.bedrooms) {
                query = query.eq('bedrooms', filters.bedrooms);
            }
            
            if (filters.bathrooms) {
                query = query.eq('bathrooms', filters.bathrooms);
            }
            
            if (filters.location) {
                query = query.like('location', `%${filters.location}%`);
            }
            
            if (filters.searchQuery) {
                query = query.or(`title.like.%${filters.searchQuery}%,description.like.%${filters.searchQuery}%`);
            }

            // Default ordering
            query = query.order('created_at', { ascending: false });

            // Apply limit
            if (filters.limit) {
                query = query.limit(filters.limit);
            }

            const listings = await query.exec();

            if (this.debug) {
                console.log(`✅ Fetched ${listings.length} listings`);
            }

            return { data: listings, error: null };
        } catch (error) {
            console.error('❌ Fetch listings error:', error);
            return { data: [], error };
        }
    }

    /**
     * Get a single listing by ID
     */
    async getListing(id) {
        try {
            if (this.debug) {
                console.log('🔍 Getting listing by ID:', id);
            }

            // Select only needed columns to reduce egress costs
            const listing = await this.supabase
                .from('listings')
                .select('id, title, price, city, street, postalCode, house_type, bedrooms, bathrooms, utilities, description, media, user_email, created_at, updated_at, status, location, category, featured')
                .eq('id', id)
                .single()
                .exec();

            if (this.debug) {
                console.log('✅ Retrieved listing:', listing?.title || 'Not found');
            }

            return { data: listing, error: null };
        } catch (error) {
            console.error('❌ Get listing error:', error);
            return { data: null, error };
        }
    }

    /**
     * Create a new listing
     */
    async createListing(listingData) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to create listings');
            }

            if (this.debug) {
                console.log('📝 Creating new listing:', listingData.title);
            }

            // Prepare listing data
            const listing = {
                ...listingData,
                user_email: currentUser.email,
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString(),
                status: 'active'
            };

            const { data, error } = await this.supabase
                .from('listings')
                .insert([listing]);

            if (error) {
                throw error;
            }

            if (this.debug) {
                console.log('✅ Listing created successfully:', data?.[0]?.id);
            }

            return { data: data?.[0], error: null };
        } catch (error) {
            console.error('❌ Create listing error:', error);
            return { data: null, error };
        }
    }

    /**
     * Update an existing listing
     */
    async updateListing(id, updates) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to update listings');
            }

            if (this.debug) {
                console.log('✏️ Updating listing:', id);
            }

            // Add updated timestamp
            const updatedData = {
                ...updates,
                updated_at: new Date().toISOString()
            };

            const { data, error } = await this.supabase
                .from('listings')
                .update(updatedData)
                .eq('id', id)
                .eq('user_email', currentUser.email); // Ensure user can only update their own listings

            if (error) {
                throw error;
            }

            if (this.debug) {
                console.log('✅ Listing updated successfully');
            }

            return { data: data?.[0], error: null };
        } catch (error) {
            console.error('❌ Update listing error:', error);
            return { data: null, error };
        }
    }

    /**
     * Delete a listing
     */
    async deleteListing(id) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to delete listings');
            }

            if (this.debug) {
                console.log('🗑️ Deleting listing:', id);
            }

            const { error } = await this.supabase
                .from('listings')
                .delete()
                .eq('id', id)
                .eq('user_email', currentUser.email); // Ensure user can only delete their own listings

            if (error) {
                throw error;
            }

            if (this.debug) {
                console.log('✅ Listing deleted successfully');
            }

            return { error: null };
        } catch (error) {
            console.error('❌ Delete listing error:', error);
            return { error };
        }
    }

    /**
     * Get user's listings
     */
    async getUserListings() {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to view their listings');
            }

            if (this.debug) {
                console.log('📋 Getting user listings for:', currentUser.email);
            }

            // Select only needed columns to reduce egress costs
            const listings = await this.supabase
                .from('listings')
                .select('id, title, price, city, street, postalCode, house_type, bedrooms, bathrooms, utilities, description, media, user_email, created_at, status, location, category')
                .eq('user_email', currentUser.email)
                .order('created_at', { ascending: false })
                .exec();

            if (this.debug) {
                console.log(`✅ Retrieved ${listings.length} user listings`);
            }

            return { data: listings, error: null };
        } catch (error) {
            console.error('❌ Get user listings error:', error);
            return { data: [], error };
        }
    }

    /**
     * Search listings
     */
    async searchListings(searchQuery, filters = {}) {
        try {
            if (this.debug) {
                console.log('🔍 Searching listings for:', searchQuery);
            }

            // Select only needed columns to reduce egress costs
            let query = this.supabase
                .from('listings')
                .select('id, title, price, city, street, postalCode, house_type, bedrooms, bathrooms, utilities, description, media, user_email, created_at, status, location, category');

            // Apply search query
            if (searchQuery) {
                query = query.or(`title.like.%${searchQuery}%,description.like.%${searchQuery}%,location.like.%${searchQuery}%`);
            }

            // Apply additional filters
            if (filters.category) {
                query = query.eq('category', filters.category);
            }
            
            if (filters.minPrice) {
                query = query.gte('price', filters.minPrice);
            }
            
            if (filters.maxPrice) {
                query = query.lte('price', filters.maxPrice);
            }

            // Order by relevance (created_at for now)
            query = query.order('created_at', { ascending: false });

            // Apply limit
            if (filters.limit) {
                query = query.limit(filters.limit);
            }

            const listings = await query.exec();

            if (this.debug) {
                console.log(`✅ Found ${listings.length} listings for search`);
            }

            return { data: listings, error: null };
        } catch (error) {
            console.error('❌ Search listings error:', error);
            return { data: [], error };
        }
    }

    /**
     * Get featured listings
     */
    async getFeaturedListings(limit = 10) {
        try {
            if (this.debug) {
                console.log('⭐ Getting featured listings');
            }

            // Select only needed columns to reduce egress costs
            const listings = await this.supabase
                .from('listings')
                .select('id, title, price, city, street, postalCode, house_type, bedrooms, bathrooms, utilities, description, media, user_email, created_at, status, location, category, featured')
                .eq('featured', true)
                .eq('status', 'active')
                .order('created_at', { ascending: false })
                .limit(limit)
                .exec();

            if (this.debug) {
                console.log(`✅ Retrieved ${listings.length} featured listings`);
            }

            return { data: listings, error: null };
        } catch (error) {
            console.error('❌ Get featured listings error:', error);
            return { data: [], error };
        }
    }

    /**
     * Get recent listings
     */
    async getRecentListings(limit = 20) {
        try {
            if (this.debug) {
                console.log('📅 Getting recent listings');
            }

            // Select only needed columns to reduce egress costs
            const listings = await this.supabase
                .from('listings')
                .select('id, title, price, city, street, postalCode, house_type, bedrooms, bathrooms, utilities, description, media, user_email, created_at, status, location, category')
                .eq('status', 'active')
                .order('created_at', { ascending: false })
                .limit(limit)
                .exec();

            if (this.debug) {
                console.log(`✅ Retrieved ${listings.length} recent listings`);
            }

            return { data: listings, error: null };
        } catch (error) {
            console.error('❌ Get recent listings error:', error);
            return { data: [], error };
        }
    }

    /**
     * Upload media for listing
     */
    async uploadListingMedia(listingId, file, mediaType = 'image') {
        try {
            if (this.debug) {
                console.log('📸 Uploading media for listing:', listingId);
            }

            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to upload media');
            }

            // Create unique filename
            const timestamp = Date.now();
            const fileExtension = file.name.split('.').pop();
            const fileName = `${listingId}_${timestamp}.${fileExtension}`;
            const filePath = `listings/${fileName}`;

            // Upload to Supabase Storage
            const { data, error } = await this.supabase.storage
                .from('listing-media')
                .upload(filePath, file, {
                    cacheControl: '3600',
                    upsert: false
                });

            if (error) {
                throw error;
            }

            // Get public URL
            const { data: urlData } = this.supabase.storage
                .from('listing-media')
                .getPublicUrl(filePath);

            if (this.debug) {
                console.log('✅ Media uploaded successfully:', urlData.publicUrl);
            }

            return { 
                data: { 
                    url: urlData.publicUrl, 
                    path: filePath,
                    type: mediaType 
                }, 
                error: null 
            };
        } catch (error) {
            console.error('❌ Upload media error:', error);
            return { data: null, error };
        }
    }

    /**
     * Delete media from listing
     */
    async deleteListingMedia(filePath) {
        try {
            if (this.debug) {
                console.log('🗑️ Deleting media:', filePath);
            }

            const { error } = await this.supabase.storage
                .from('listing-media')
                .remove([filePath]);

            if (error) {
                throw error;
            }

            if (this.debug) {
                console.log('✅ Media deleted successfully');
            }

            return { error: null };
        } catch (error) {
            console.error('❌ Delete media error:', error);
            return { error };
        }
    }

    /**
     * Get listings by category
     */
    async getListingsByCategory(category, limit = 20) {
        try {
            if (this.debug) {
                console.log('🏷️ Getting listings by category:', category);
            }

            // Select only needed columns to reduce egress costs
            const listings = await this.supabase
                .from('listings')
                .select('id, title, price, city, street, postalCode, house_type, bedrooms, bathrooms, utilities, description, media, user_email, created_at, status, location, category')
                .eq('category', category)
                .eq('status', 'active')
                .order('created_at', { ascending: false })
                .limit(limit)
                .exec();

            if (this.debug) {
                console.log(`✅ Retrieved ${listings.length} listings for category: ${category}`);
            }

            return { data: listings, error: null };
        } catch (error) {
            console.error('❌ Get listings by category error:', error);
            return { data: [], error };
        }
    }

    /**
     * Get listings near location
     */
    async getListingsNearLocation(location, radius = 10, limit = 20) {
        try {
            if (this.debug) {
                console.log('📍 Getting listings near:', location);
            }

            // For now, use simple text search
            // In production, you'd use PostGIS for proper geographic queries
            // Select only needed columns to reduce egress costs
            const listings = await this.supabase
                .from('listings')
                .select('id, title, price, city, street, postalCode, house_type, bedrooms, bathrooms, utilities, description, media, user_email, created_at, status, location, category')
                .like('location', `%${location}%`)
                .eq('status', 'active')
                .order('created_at', { ascending: false })
                .limit(limit)
                .exec();

            if (this.debug) {
                console.log(`✅ Retrieved ${listings.length} listings near: ${location}`);
            }

            return { data: listings, error: null };
        } catch (error) {
            console.error('❌ Get listings near location error:', error);
            return { data: [], error };
        }
    }

    /**
     * Toggle listing favorite status
     */
    async toggleFavorite(listingId) {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to favorite listings');
            }

            if (this.debug) {
                console.log('❤️ Toggling favorite for listing:', listingId);
            }

            // Check if already favorited - select only id to reduce egress
            const existingFavorite = await this.supabase
                .from('favorites')
                .select('id')
                .eq('user_email', currentUser.email)
                .eq('listing_id', listingId)
                .single()
                .exec();

            if (existingFavorite) {
                // Remove from favorites
                await this.supabase
                    .from('favorites')
                    .delete()
                    .eq('user_email', currentUser.email)
                    .eq('listing_id', listingId);
                
                if (this.debug) {
                    console.log('✅ Removed from favorites');
                }
                
                return { data: { favorited: false }, error: null };
            } else {
                // Add to favorites
                const { data, error } = await this.supabase
                    .from('favorites')
                    .insert([{
                        user_email: currentUser.email,
                        listing_id: listingId,
                        created_at: new Date().toISOString()
                    }]);

                if (error) {
                    throw error;
                }

                if (this.debug) {
                    console.log('✅ Added to favorites');
                }

                return { data: { favorited: true }, error: null };
            }
        } catch (error) {
            console.error('❌ Toggle favorite error:', error);
            return { data: null, error };
        }
    }

    /**
     * Get user's favorite listings
     */
    async getUserFavorites() {
        try {
            const currentUser = iosAuthManager.getCurrentUser();
            if (!currentUser) {
                throw new Error('User must be authenticated to view favorites');
            }

            if (this.debug) {
                console.log('❤️ Getting user favorites');
            }

            const favorites = await this.supabase
                .from('favorites')
                .select(`
                    *,
                    listings (*)
                `)
                .eq('user_email', currentUser.email)
                .order('created_at', { ascending: false })
                .exec();

            const listings = favorites.map(fav => fav.listings);

            if (this.debug) {
                console.log(`✅ Retrieved ${listings.length} favorite listings`);
            }

            return { data: listings, error: null };
        } catch (error) {
            console.error('❌ Get user favorites error:', error);
            return { data: [], error };
        }
    }
}

// Create singleton instance
const iosListingsAPI = new IOSListingsAPI();

/**
 * Export singleton instance
 */
export default iosListingsAPI;

/**
 * Export API functions for convenience
 */
export const {
    fetchListings,
    getListing,
    createListing,
    updateListing,
    deleteListing,
    getUserListings,
    searchListings,
    getFeaturedListings,
    getRecentListings,
    uploadListingMedia,
    deleteListingMedia,
    getListingsByCategory,
    getListingsNearLocation,
    toggleFavorite,
    getUserFavorites
} = iosListingsAPI;

console.log('✅ iOS Listings API module loaded successfully');