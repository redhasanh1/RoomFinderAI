/**
 * Listings API Module
 * Handles all Supabase API operations for listings
 */

// Global variables (will be injected by the main application)
let supabase;
let SUPABASE_URL;
let SUPABASE_ANON_KEY;

/**
 * Initialize the API module with Supabase configuration
 * @param {Object} config - Configuration object containing supabase instance and credentials
 */
export function initializeAPI(config) {
    supabase = config.supabase;
    SUPABASE_URL = config.SUPABASE_URL;
    SUPABASE_ANON_KEY = config.SUPABASE_ANON_KEY;
    console.log('📡 Listings API initialized');
}

/**
 * Fetch listings from Supabase
 * @param {Object} options - Query options (limit, offset, filters)
 * @returns {Promise<Array>} Array of listing objects
 */
export async function fetchListings(options = {}) {
    console.log('📥 Fetching listings from Supabase');
    
    if (!supabase) {
        throw new Error('Supabase not initialized. Call initializeAPI() first.');
    }

    try {
        const { limit = 20, offset = 0, filters = {} } = options;
        
        let query = supabase
            .from('listings')
            .select('*')
            .order('created_at', { ascending: false });

        // Apply filters if provided
        if (filters.city) {
            query = query.ilike('city', `%${filters.city}%`);
        }
        if (filters.maxPrice) {
            query = query.lte('price', filters.maxPrice);
        }
        if (filters.minPrice) {
            query = query.gte('price', filters.minPrice);
        }
        if (filters.house_type) {
            query = query.eq('house_type', filters.house_type);
        }
        if (filters.bedrooms) {
            query = query.eq('bedrooms', filters.bedrooms);
        }

        if (limit > 0) {
            query = query.range(offset, offset + limit - 1);
        }

        const { data, error } = await query;
        
        console.log('📥 Fetch result:', { data, error });
        
        if (error) {
            console.error('❌ Error fetching listings:', error);
            throw error;
        }
        
        return data || [];
    } catch (error) {
        console.error('💥 Exception in fetchListings:', error);
        throw error;
    }
}

/**
 * Create a new listing
 * @param {Object} listingData - Listing data object
 * @returns {Promise<Object>} Created listing object
 */
export async function createListing(listingData) {
    console.log('📝 Creating new listing:', listingData);
    
    if (!supabase) {
        throw new Error('Supabase not initialized. Call initializeAPI() first.');
    }

    try {
        // Validate required fields
        const requiredFields = ['title', 'price', 'city', 'street', 'postalCode', 'house_type', 'bedrooms', 'user_email'];
        for (const field of requiredFields) {
            if (!listingData[field]) {
                throw new Error(`Missing required field: ${field}`);
            }
        }

        const { data, error } = await supabase
            .from('listings')
            .insert([listingData])
            .select()
            .single();

        if (error) {
            console.error('❌ Error creating listing:', error);
            throw error;
        }

        console.log('✅ Listing created successfully:', data);
        return data;
    } catch (error) {
        console.error('💥 Exception in createListing:', error);
        throw error;
    }
}

/**
 * Update an existing listing
 * @param {string} listingId - ID of the listing to update
 * @param {Object} updates - Object containing fields to update
 * @returns {Promise<Object>} Updated listing object
 */
export async function updateListing(listingId, updates) {
    console.log('📝 Updating listing:', listingId, updates);
    
    if (!supabase) {
        throw new Error('Supabase not initialized. Call initializeAPI() first.');
    }

    try {
        const { data, error } = await supabase
            .from('listings')
            .update(updates)
            .eq('id', listingId)
            .select()
            .single();

        if (error) {
            console.error('❌ Error updating listing:', error);
            throw error;
        }

        console.log('✅ Listing updated successfully:', data);
        return data;
    } catch (error) {
        console.error('💥 Exception in updateListing:', error);
        throw error;
    }
}

/**
 * Delete a listing
 * @param {string} listingId - ID of the listing to delete
 * @returns {Promise<boolean>} Success status
 */
export async function deleteListing(listingId) {
    console.log('🗑️ Deleting listing:', listingId);
    
    if (!supabase) {
        throw new Error('Supabase not initialized. Call initializeAPI() first.');
    }

    try {
        const { error } = await supabase
            .from('listings')
            .delete()
            .eq('id', listingId);

        if (error) {
            console.error('❌ Error deleting listing:', error);
            throw error;
        }

        console.log('✅ Listing deleted successfully');
        return true;
    } catch (error) {
        console.error('💥 Exception in deleteListing:', error);
        throw error;
    }
}

/**
 * Upload media files to Supabase Storage
 * @param {Array} files - Array of file objects with file, name, type properties
 * @returns {Promise<Array>} Array of uploaded media objects with URLs
 */
export async function uploadMedia(files) {
    console.log('📤 Uploading media files:', files.length);
    
    if (!supabase || !SUPABASE_URL || !SUPABASE_ANON_KEY) {
        throw new Error('Supabase not properly initialized. Missing configuration.');
    }

    const uploadedMedia = [];
    const storageApiUrl = `${SUPABASE_URL}/storage/v1/object/listing-media/Photos`;

    for (const fileObj of files) {
        try {
            const file = fileObj.file;
            const fileName = `${Date.now()}-${file.name.replace(/[^a-zA-Z0-9.-]/g, '_')}`;
            const filePath = fileName;

            // Determine content type
            const extension = file.name.split('.').pop().toLowerCase();
            let contentType;
            switch (extension) {
                case 'jpg':
                case 'jpeg':
                    contentType = 'image/jpeg';
                    break;
                case 'png':
                    contentType = 'image/png';
                    break;
                case 'mp4':
                    contentType = 'video/mp4';
                    break;
                default:
                    contentType = file.type || 'application/octet-stream';
            }

            console.log('📤 Processing file:', { 
                name: file.name, 
                detectedType: file.type, 
                assignedType: contentType 
            });

            // Handle image compression if needed
            let fileToUpload = file;
            if (contentType.startsWith('image/')) {
                fileToUpload = await compressImage(file);
            }

            // Upload to Supabase Storage
            const { data, error } = await supabase.storage
                .from('listing-media')
                .upload(`Photos/${filePath}`, fileToUpload, {
                    contentType: contentType,
                    cacheControl: '3600',
                    upsert: false
                });

            if (error) {
                console.error('❌ Upload error:', error);
                throw error;
            }

            // Get public URL
            const { data: publicUrlData } = supabase.storage
                .from('listing-media')
                .getPublicUrl(`Photos/${filePath}`);

            const publicUrl = publicUrlData.publicUrl;

            // Verify the uploaded file
            const verifyResponse = await fetch(publicUrl, { method: 'HEAD' });
            const serverContentType = verifyResponse.headers.get('Content-Type');
            
            console.log('📤 Server content type check:', { 
                file: file.name, 
                expected: contentType, 
                actual: serverContentType 
            });

            // Re-upload with correct content type if needed
            if (serverContentType !== contentType) {
                console.log('🔄 Re-uploading with correct content type...');
                
                const reUploadFormData = new FormData();
                reUploadFormData.append('file', fileToUpload);

                const reUploadResponse = await fetch(storageApiUrl + '/' + filePath, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                        'apikey': SUPABASE_ANON_KEY,
                        'Content-Type': contentType
                    },
                    body: reUploadFormData
                });

                if (!reUploadResponse.ok) {
                    const errorText = await reUploadResponse.text();
                    throw new Error(`Re-upload failed: ${reUploadResponse.status} - ${errorText}`);
                }

                // Verify again
                const verifyAgain = await fetch(publicUrl, { method: 'HEAD' });
                const finalContentType = verifyAgain.headers.get('Content-Type');
                
                if (finalContentType !== contentType) {
                    console.warn('⚠️ Content type mismatch after re-upload:', {
                        file: file.name,
                        expected: contentType,
                        actual: finalContentType
                    });
                }
            }

            uploadedMedia.push({
                name: file.name,
                type: contentType,
                url: publicUrl,
                data: fileObj.data
            });

            console.log('✅ Successfully uploaded:', { 
                name: file.name, 
                type: contentType, 
                url: publicUrl 
            });

        } catch (error) {
            console.error('❌ Upload failed for file:', file.name, error);
            throw error;
        }
    }

    return uploadedMedia;
}

/**
 * Compress an image file
 * @param {File} file - Image file to compress
 * @returns {Promise<File>} Compressed image file
 */
async function compressImage(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = (e) => {
            const img = new Image();
            img.onload = () => {
                const canvas = document.createElement('canvas');
                const ctx = canvas.getContext('2d');
                
                // Set maximum dimensions
                const maxWidth = 1200;
                const maxHeight = 800;
                
                let { width, height } = img;
                
                // Calculate new dimensions
                if (width > height) {
                    if (width > maxWidth) {
                        height = (height * maxWidth) / width;
                        width = maxWidth;
                    }
                } else {
                    if (height > maxHeight) {
                        width = (width * maxHeight) / height;
                        height = maxHeight;
                    }
                }
                
                canvas.width = width;
                canvas.height = height;
                
                // Draw and compress
                ctx.drawImage(img, 0, 0, width, height);
                
                canvas.toBlob((blob) => {
                    if (blob) {
                        const compressedFile = new File([blob], file.name, {
                            type: file.type,
                            lastModified: Date.now()
                        });
                        resolve(compressedFile);
                    } else {
                        reject(new Error('Failed to compress image'));
                    }
                }, file.type, 0.85); // 85% quality
            };
            img.src = e.target.result;
        };
        reader.onerror = reject;
        reader.readAsDataURL(file);
    });
}

/**
 * Get a single listing by ID
 * @param {string} listingId - ID of the listing to fetch
 * @returns {Promise<Object>} Listing object
 */
export async function getListingById(listingId) {
    console.log('📥 Fetching listing by ID:', listingId);
    
    if (!supabase) {
        throw new Error('Supabase not initialized. Call initializeAPI() first.');
    }

    try {
        const { data, error } = await supabase
            .from('listings')
            .select('*')
            .eq('id', listingId)
            .single();

        if (error) {
            console.error('❌ Error fetching listing:', error);
            throw error;
        }

        console.log('✅ Listing fetched successfully:', data);
        return data;
    } catch (error) {
        console.error('💥 Exception in getListingById:', error);
        throw error;
    }
}

/**
 * Get listings by user email
 * @param {string} userEmail - Email of the user
 * @returns {Promise<Array>} Array of listing objects
 */
export async function getListingsByUser(userEmail) {
    console.log('📥 Fetching listings by user:', userEmail);
    
    if (!supabase) {
        throw new Error('Supabase not initialized. Call initializeAPI() first.');
    }

    try {
        const { data, error } = await supabase
            .from('listings')
            .select('*')
            .eq('user_email', userEmail)
            .order('created_at', { ascending: false });

        if (error) {
            console.error('❌ Error fetching user listings:', error);
            throw error;
        }

        console.log('✅ User listings fetched successfully:', data?.length || 0);
        return data || [];
    } catch (error) {
        console.error('💥 Exception in getListingsByUser:', error);
        throw error;
    }
}

/**
 * Subscribe to real-time listing changes
 * @param {Function} callback - Callback function to handle changes
 * @returns {Object} Subscription object
 */
export function subscribeToListings(callback) {
    console.log('📡 Setting up real-time listings subscription');
    
    if (!supabase) {
        throw new Error('Supabase not initialized. Call initializeAPI() first.');
    }

    try {
        const subscription = supabase
            .channel('public:listings')
            .on('postgres_changes', { 
                event: 'INSERT', 
                schema: 'public', 
                table: 'listings' 
            }, (payload) => {
                console.log('📨 New listing added:', payload.new);
                callback('INSERT', payload.new);
            })
            .on('postgres_changes', { 
                event: 'UPDATE', 
                schema: 'public', 
                table: 'listings' 
            }, (payload) => {
                console.log('📝 Listing updated:', payload.new);
                callback('UPDATE', payload.new);
            })
            .on('postgres_changes', { 
                event: 'DELETE', 
                schema: 'public', 
                table: 'listings' 
            }, (payload) => {
                console.log('🗑️ Listing deleted:', payload.old);
                callback('DELETE', payload.old);
            })
            .subscribe((status) => {
                console.log('📡 Listings subscription status:', status);
            });

        return subscription;
    } catch (error) {
        console.error('💥 Exception in subscribeToListings:', error);
        throw error;
    }
}

// Export all functions
export default {
    initializeAPI,
    fetchListings,
    createListing,
    updateListing,
    deleteListing,
    uploadMedia,
    getListingById,
    getListingsByUser,
    subscribeToListings
};