/**
 * Listings API Module
 * Handles all Supabase API operations for listings
 */

let supabase = null;
let apiInitialized = false;

/**
 * Initialize API with Supabase client
 */
function initializeAPI() {
    try {
        supabase = window.ClientConfig.getSupabaseClient();
        apiInitialized = true;
        console.log('📡 Listings API initialized');
        return true;
    } catch (error) {
        console.error('❌ Failed to initialize Listings API:', error);
        return false;
    }
}

/**
 * Fetch listings with optional filtering
 */
async function fetchListings(filters = {}) {
    if (!apiInitialized) {
        throw new Error('API not initialized');
    }
    
    try {
        let query = supabase.from('listings').select('*');
        
        // Apply filters
        if (filters.city) {
            query = query.ilike('city', `%${filters.city}%`);
        }
        
        if (filters.country) {
            query = query.ilike('country', `%${filters.country}%`);
        }
        
        if (filters.roomType) {
            query = query.eq('room_type', filters.roomType);
        }
        
        if (filters.minPrice) {
            query = query.gte('price', filters.minPrice);
        }
        
        if (filters.maxPrice) {
            query = query.lte('price', filters.maxPrice);
        }
        
        if (filters.wifi) {
            query = query.eq('wifi', true);
        }
        
        if (filters.parking) {
            query = query.eq('parking', true);
        }
        
        if (filters.kitchen) {
            query = query.eq('kitchen', true);
        }
        
        if (filters.laundry) {
            query = query.eq('laundry', true);
        }
        
        if (filters.furnished) {
            query = query.eq('furnished', true);
        }
        
        if (filters.petsAllowed) {
            query = query.eq('pets_allowed', true);
        }
        
        // Order by created_at desc
        query = query.order('created_at', { ascending: false });
        
        const { data, error } = await query;
        
        if (error) {
            throw error;
        }
        
        console.log(`📊 Fetched ${data.length} listings`);
        return data;
        
    } catch (error) {
        console.error('❌ Error fetching listings:', error);
        throw error;
    }
}

/**
 * Create a new listing
 */
async function createListing(listingData) {
    if (!apiInitialized) {
        throw new Error('API not initialized');
    }
    
    try {
        // Validate required fields
        const requiredFields = ['title', 'description', 'city', 'country', 'room_type', 'price'];
        for (const field of requiredFields) {
            if (!listingData[field]) {
                throw new Error(`Missing required field: ${field}`);
            }
        }
        
        // Get current user
        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError || !user) {
            throw new Error('User not authenticated');
        }
        
        // Add user ID to listing data
        const listingWithUser = {
            ...listingData,
            user_id: user.id,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };
        
        const { data, error } = await supabase
            .from('listings')
            .insert([listingWithUser])
            .select()
            .single();
        
        if (error) {
            throw error;
        }
        
        console.log('✅ Listing created successfully:', data.id);
        return data;
        
    } catch (error) {
        console.error('❌ Error creating listing:', error);
        throw error;
    }
}

/**
 * Update an existing listing
 */
async function updateListing(listingId, updateData) {
    if (!apiInitialized) {
        throw new Error('API not initialized');
    }
    
    try {
        // Get current user
        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError || !user) {
            throw new Error('User not authenticated');
        }
        
        // Add updated timestamp
        const dataWithTimestamp = {
            ...updateData,
            updated_at: new Date().toISOString()
        };
        
        const { data, error } = await supabase
            .from('listings')
            .update(dataWithTimestamp)
            .eq('id', listingId)
            .eq('user_id', user.id) // Ensure user owns the listing
            .select()
            .single();
        
        if (error) {
            throw error;
        }
        
        console.log('✅ Listing updated successfully:', listingId);
        return data;
        
    } catch (error) {
        console.error('❌ Error updating listing:', error);
        throw error;
    }
}

/**
 * Delete a listing
 */
async function deleteListing(listingId) {
    if (!apiInitialized) {
        throw new Error('API not initialized');
    }
    
    try {
        // Get current user
        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError || !user) {
            throw new Error('User not authenticated');
        }
        
        const { error } = await supabase
            .from('listings')
            .delete()
            .eq('id', listingId)
            .eq('user_id', user.id); // Ensure user owns the listing
        
        if (error) {
            throw error;
        }
        
        console.log('✅ Listing deleted successfully:', listingId);
        return true;
        
    } catch (error) {
        console.error('❌ Error deleting listing:', error);
        throw error;
    }
}

/**
 * Upload media files to Supabase Storage
 */
async function uploadMedia(files, listingId) {
    if (!apiInitialized) {
        throw new Error('API not initialized');
    }
    
    try {
        const uploadedFiles = [];
        
        for (const file of files) {
            // Validate file
            if (file.size > 5 * 1024 * 1024) { // 5MB limit
                throw new Error(`File ${file.name} is too large (max 5MB)`);
            }
            
            // Generate unique filename
            const fileExt = file.name.split('.').pop();
            const fileName = `${listingId}/${Date.now()}-${Math.random().toString(36).substr(2, 9)}.${fileExt}`;
            
            // Compress image if needed
            let fileToUpload = file;
            if (file.type.startsWith('image/')) {
                fileToUpload = await compressImage(file);
            }
            
            // Upload to Supabase Storage
            const { data, error } = await supabase.storage
                .from('listing-media')
                .upload(fileName, fileToUpload, {
                    cacheControl: '3600',
                    upsert: false
                });
            
            if (error) {
                throw error;
            }
            
            // Get public URL
            const { data: { publicUrl } } = supabase.storage
                .from('listing-media')
                .getPublicUrl(fileName);
            
            uploadedFiles.push({
                name: file.name,
                url: publicUrl,
                type: file.type,
                size: fileToUpload.size
            });
        }
        
        console.log(`✅ Uploaded ${uploadedFiles.length} files`);
        return uploadedFiles;
        
    } catch (error) {
        console.error('❌ Error uploading media:', error);
        throw error;
    }
}

/**
 * Compress image file
 */
async function compressImage(file, maxWidth = 1200, quality = 0.8) {
    return new Promise((resolve) => {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        const img = new Image();
        
        img.onload = function() {
            // Calculate new dimensions
            const ratio = Math.min(maxWidth / img.width, maxWidth / img.height);
            canvas.width = img.width * ratio;
            canvas.height = img.height * ratio;
            
            // Draw and compress
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            
            canvas.toBlob(resolve, file.type, quality);
        };
        
        img.src = URL.createObjectURL(file);
    });
}

/**
 * Get listing by ID
 */
async function getListingById(listingId) {
    if (!apiInitialized) {
        throw new Error('API not initialized');
    }
    
    try {
        const { data, error } = await supabase
            .from('listings')
            .select('*')
            .eq('id', listingId)
            .single();
        
        if (error) {
            throw error;
        }
        
        return data;
        
    } catch (error) {
        console.error('❌ Error fetching listing:', error);
        throw error;
    }
}

/**
 * Get listings by user
 */
async function getListingsByUser(userId = null) {
    if (!apiInitialized) {
        throw new Error('API not initialized');
    }
    
    try {
        let targetUserId = userId;
        
        if (!targetUserId) {
            // Get current user
            const { data: { user }, error: authError } = await supabase.auth.getUser();
            if (authError || !user) {
                throw new Error('User not authenticated');
            }
            targetUserId = user.id;
        }
        
        const { data, error } = await supabase
            .from('listings')
            .select('*')
            .eq('user_id', targetUserId)
            .order('created_at', { ascending: false });
        
        if (error) {
            throw error;
        }
        
        return data;
        
    } catch (error) {
        console.error('❌ Error fetching user listings:', error);
        throw error;
    }
}

/**
 * Subscribe to real-time listings changes
 */
function subscribeToListings(callback) {
    if (!apiInitialized) {
        throw new Error('API not initialized');
    }
    
    try {
        const subscription = supabase
            .channel('listings-changes')
            .on('postgres_changes', 
                { event: '*', schema: 'public', table: 'listings' }, 
                (payload) => {
                    console.log('📡 Real-time listing update:', payload);
                    callback(payload);
                }
            )
            .subscribe();
        
        console.log('📡 Subscribed to real-time listings updates');
        return subscription;
        
    } catch (error) {
        console.error('❌ Error subscribing to listings:', error);
        throw error;
    }
}

/**
 * Unsubscribe from real-time updates
 */
function unsubscribeFromListings(subscription) {
    if (subscription) {
        supabase.removeChannel(subscription);
        console.log('📡 Unsubscribed from real-time listings updates');
    }
}

/**
 * Get API statistics
 */
async function getAPIStats() {
    if (!apiInitialized) {
        return { initialized: false };
    }
    
    try {
        const { data, error } = await supabase
            .from('listings')
            .select('count', { count: 'exact', head: true });
        
        return {
            initialized: true,
            totalListings: data || 0,
            hasError: !!error
        };
        
    } catch (error) {
        return {
            initialized: true,
            totalListings: 0,
            hasError: true,
            error: error.message
        };
    }
}

// Export functions for use in other modules
export {
    initializeAPI,
    fetchListings,
    createListing,
    updateListing,
    deleteListing,
    uploadMedia,
    compressImage,
    getListingById,
    getListingsByUser,
    subscribeToListings,
    unsubscribeFromListings,
    getAPIStats
};

// Also export to window for backward compatibility
window.ListingsAPI = {
    initializeAPI,
    fetchListings,
    createListing,
    updateListing,
    deleteListing,
    uploadMedia,
    compressImage,
    getListingById,
    getListingsByUser,
    subscribeToListings,
    unsubscribeFromListings,
    getAPIStats
};