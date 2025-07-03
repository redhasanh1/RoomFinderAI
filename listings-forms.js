// Form handling and validation functions

// Upload media files to Supabase storage
async function uploadMedia(files) {
    console.log('📤 Starting media upload for', files.length, 'files');
    const uploadedFiles = [];
    
    for (const file of files) {
        try {
            const fileExtension = file.name.split('.').pop();
            const fileName = `${Date.now()}_${Math.random().toString(36).substring(7)}.${fileExtension}`;
            
            console.log(`⬆️ Uploading ${file.name} as ${fileName}`);
            
            const { data, error } = await supabase.storage
                .from('listings')
                .upload(fileName, file);
            
            if (error) {
                console.error(`❌ Upload failed for ${file.name}:`, error);
                throw error;
            }
            
            const { data: urlData } = supabase.storage
                .from('listings')
                .getPublicUrl(fileName);
            
            uploadedFiles.push({
                name: file.name,
                url: urlData.publicUrl,
                type: file.type,
                size: file.size
            });
            
            console.log(`✅ Successfully uploaded ${file.name}`);
            
        } catch (error) {
            console.error(`❌ Error uploading ${file.name}:`, error);
            throw new Error(`Failed to upload ${file.name}: ${error.message}`);
        }
    }
    
    console.log(`🎉 All ${uploadedFiles.length} files uploaded successfully`);
    return uploadedFiles;
}

// Clean and validate address input
function cleanAddressInput(input) {
    if (!input) return '';
    return input.trim()
        .replace(/[<>\"'&]/g, '') // Remove dangerous characters
        .substring(0, 100); // Limit length
}

// Sanitize general input
function sanitizeInput(input) {
    if (!input) return '';
    return input.toString().trim()
        .replace(/[<>\"'&]/g, '')
        .substring(0, 500);
}

// Autocorrect input using Typo.js
function autocorrectInput(text) {
    try {
        if (window.Typo && text) {
            const dictionary = new window.Typo('en_US');
            const words = text.split(' ');
            const correctedWords = words.map(word => {
                const cleanWord = word.replace(/[^\w]/g, '');
                if (cleanWord.length > 2 && !dictionary.check(cleanWord)) {
                    const suggestions = dictionary.suggest(cleanWord);
                    return suggestions.length > 0 ? word.replace(cleanWord, suggestions[0]) : word;
                }
                return word;
            });
            return correctedWords.join(' ');
        }
    } catch (error) {
        console.warn('Autocorrect failed:', error);
    }
    return text;
}

// Setup form submission handler
function setupFormSubmission() {
    const listingForm = document.getElementById('listingForm');
    if (!listingForm) return;

    listingForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const submitButton = listingForm.querySelector('button[type="submit"]');
        const originalText = submitButton.textContent;
        
        try {
            submitButton.disabled = true;
            submitButton.textContent = 'Adding Listing...';
            
            const currentUser = JSON.parse(localStorage.getItem('currentUser'));
            if (!currentUser) {
                throw new Error('Please log in to add a listing');
            }

            // Get form data
            const formData = new FormData(listingForm);
            const mediaFiles = document.getElementById('media').files;
            
            // Validate required fields
            const requiredFields = ['city', 'street', 'postalCode', 'title', 'price', 'houseType', 'bedrooms'];
            for (const field of requiredFields) {
                if (!formData.get(field)) {
                    throw new Error(`${field} is required`);
                }
            }

            // Clean and validate inputs
            const listingData = {
                user_email: currentUser.email,
                city: cleanAddressInput(formData.get('city')),
                country: cleanAddressInput(formData.get('country')) || 'Unknown',
                street: cleanAddressInput(formData.get('street')),
                postal_code: cleanAddressInput(formData.get('postalCode')),
                title: sanitizeInput(formData.get('title')),
                price: parseInt(formData.get('price')),
                house_type: sanitizeInput(formData.get('houseType')),
                bedrooms: parseInt(formData.get('bedrooms')),
                utilities: sanitizeInput(formData.get('utilities')),
                description: autocorrectInput(sanitizeInput(formData.get('description')))
            };

            // Validate numeric fields
            if (isNaN(listingData.price) || listingData.price <= 0) {
                throw new Error('Price must be a positive number');
            }
            if (isNaN(listingData.bedrooms) || listingData.bedrooms < 0) {
                throw new Error('Bedrooms must be a non-negative number');
            }

            // Upload media files if any
            let uploadedMedia = [];
            if (mediaFiles.length > 0) {
                const maxFileSize = 10 * 1024 * 1024; // 10MB
                for (const file of mediaFiles) {
                    if (file.size > maxFileSize) {
                        throw new Error(`File ${file.name} is too large. Maximum size is 10MB.`);
                    }
                }
                
                uploadedMedia = await uploadMedia(Array.from(mediaFiles));
            }

            // Add media to listing data
            if (uploadedMedia.length > 0) {
                listingData.media = uploadedMedia;
            }

            console.log('📝 Submitting listing:', listingData);

            // Insert into database
            const { data, error } = await supabase
                .from('listings')
                .insert([listingData])
                .select('id')
                .single();

            if (error) {
                console.error('Database error:', error);
                throw error;
            }

            console.log('✅ Listing created with ID:', data.id);
            
            // Reset form and show success
            listingForm.reset();
            document.getElementById('mediaPreview').innerHTML = '';
            alert('Listing added successfully!');
            
            // Refresh listings display
            if (typeof displayListings === 'function') {
                displayListings();
            }

        } catch (error) {
            console.error('❌ Error adding listing:', error);
            alert('Error adding listing: ' + error.message);
        } finally {
            submitButton.disabled = false;
            submitButton.textContent = originalText;
        }
    });

    console.log('✅ Form submission handler setup complete');
}

// Setup media preview
function setupMediaPreview() {
    const mediaInput = document.getElementById('media');
    const mediaPreview = document.getElementById('mediaPreview');
    
    if (!mediaInput || !mediaPreview) return;

    mediaInput.addEventListener('change', (e) => {
        const files = e.target.files;
        mediaPreview.innerHTML = '';
        
        Array.from(files).forEach(file => {
            const reader = new FileReader();
            reader.onload = (e) => {
                const mediaElement = file.type.startsWith('image/') 
                    ? `<img src="${e.target.result}" alt="${file.name}" style="max-width: 100px; max-height: 100px; object-fit: cover; margin: 0.5rem; border-radius: 0.25rem;">`
                    : `<video src="${e.target.result}" controls style="max-width: 100px; max-height: 100px; margin: 0.5rem; border-radius: 0.25rem;"></video>`;
                
                mediaPreview.innerHTML += `
                    <div class="media-preview-item">
                        ${mediaElement}
                        <div class="text-xs text-gray-600 mt-1 text-center">${file.name}</div>
                    </div>
                `;
            };
            reader.readAsDataURL(file);
        });
    });

    console.log('✅ Media preview setup complete');
}

// Fetch and display all listings
async function fetchListings() {
    console.log('📋 Fetching listings from database...');
    
    try {
        const { data: listings, error } = await supabase
            .from('listings')
            .select('*')
            .order('created_at', { ascending: false });
        
        if (error) {
            console.error('Database error:', error);
            throw error;
        }
        
        console.log(`✅ Fetched ${listings.length} listings`);
        allListings = listings;
        window.allListings = listings; // Make available globally
        return listings;
        
    } catch (error) {
        console.error('❌ Error fetching listings:', error);
        showError('Failed to load listings: ' + error.message);
        return [];
    }
}

// Initialize form functionality
function initializeForms() {
    setupFormSubmission();
    setupMediaPreview();
    console.log('✅ Forms initialized');
}