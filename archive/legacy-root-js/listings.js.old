// Listings management module
window.ListingsManager = (function() {
    let uploadedFiles = [];
    let allListings = [];

    // Fetch listings from database
    async function fetchListings() {
        console.log('Fetching listings from Supabase');
        try {
            const { data, error } = await window.AppConfig.supabase
                .from('listings')
                .select('*')
                .order('created_at', { ascending: false })
                .range(0, 19);
            console.log('Fetch result:', { data, error });
            if (error) throw error;
            return data || [];
        } catch (error) {
            console.error('Error fetching listings:', error);
            window.Utils.showError('Failed to load listings: ' + error.message);
            return [];
        }
    }

    // Display listings in the container
    async function displayListings() {
        console.log('🔄 Starting displayListings function');
        const listings = await fetchListings();
        allListings = listings;
        console.log('📋 Fetched listings:', listings);
        
        const container = document.getElementById('listingsContainer');
        if (!container) {
            console.error('Listings container not found');
            return;
        }

        container.innerHTML = '';

        if (listings.length === 0) {
            container.innerHTML = '<p class="text-gray-600 text-center mb-4">No listings available in database.</p>';
            console.log('📝 No listings found in database');
            return;
        }

        // Display each listing
        listings.forEach(listing => {
            const listingCard = createListingCard(listing);
            container.appendChild(listingCard);
        });

        // Update map with listings
        if (window.MapManager) {
            window.MapManager.updateWithListings(listings);
        }

        console.log('✅ displayListings completed successfully');
    }

    // Create listing card element
    function createListingCard(listing) {
        const cardContainer = document.createElement('div');
        cardContainer.className = 'listing-card-perspective-container';

        // Handle media display
        let mediaHtml = '';
        if (listing.media && listing.media.length > 0) {
            const firstMedia = listing.media[0];
            if (window.Utils.isImage({ type: 'image/jpeg', name: firstMedia })) {
                mediaHtml = `<img src="${firstMedia}" alt="Listing Image" class="listing-image">`;
            } else {
                mediaHtml = `<div class="listing-image bg-gray-200 flex items-center justify-content-center">
                    <span class="text-gray-500">Media</span>
                </div>`;
            }
        } else {
            mediaHtml = `<div class="listing-image bg-gray-200 flex items-center justify-content-center">
                <span class="text-gray-500">No Image</span>
            </div>`;
        }

        cardContainer.innerHTML = `
            <div class="listing-card p-6 border border-gray-200 rounded-lg">
                ${mediaHtml}
                <div class="p-4">
                    <h3 class="text-xl font-semibold text-gray-800 mb-2">${listing.title || 'Untitled'}</h3>
                    <p class="text-2xl font-bold text-blue-600 mb-2">$${listing.price || 'N/A'}/month</p>
                    <p class="text-gray-600 mb-2">${listing.street || ''}, ${listing.city || ''}</p>
                    <p class="text-gray-600 mb-2">${listing.house_type || ''} • ${listing.bedrooms || 'N/A'} bedrooms</p>
                    <p class="text-gray-700 text-sm mb-4">${(listing.description || '').substring(0, 100)}${listing.description && listing.description.length > 100 ? '...' : ''}</p>
                    <div class="flex space-x-2">
                        <button onclick="window.ListingsManager.showListingModal(${JSON.stringify(listing).replace(/"/g, '&quot;')})" 
                                class="flex-1 bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700 transition"
                            View Details
                        </button>
                        <button onclick="window.ChatManager?.startConversation('${listing.user_email}', '${listing.title}')" 
                                class="flex-1 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition"
                            Chat
                        </button>
                    </div>
                </div>
            </div>
        `;

        return cardContainer;
    }

    // Show listing modal
    function showListingModal(listing) {
        const modal = document.getElementById('listingModal');
        const modalContent = modal.querySelector('.modal-content');
        
        if (!modal || !modalContent) {
            console.error('Modal elements not found');
            return;
        }

        // Build media HTML
        let mediaHtml = '';
        if (listing.media && listing.media.length > 0) {
            mediaHtml = listing.media.map(url => {
                if (window.Utils.isImage({ type: 'image/jpeg', name: url })) {
                    return `<img src="${url}" alt="Listing Image" class="modal-media">`;
                } else {
                    return `<video src="${url}" controls class="modal-media"></video>`;
                }
            }).join('');
        }

        modalContent.innerHTML = `
            <span class="close-button">&times;</span>
            <h2 class="text-2xl font-bold mb-4">${listing.title || 'Untitled'}</h2>
            <p class="text-3xl font-bold text-blue-600 mb-4">$${listing.price || 'N/A'}/month</p>
            <p class="text-gray-700 mb-2"><strong>Location:</strong> ${listing.street || ''}, ${listing.city || ''}, ${listing.postalCode || ''}</p>
            <p class="text-gray-700 mb-2"><strong>Type:</strong> ${listing.house_type || 'N/A'}</p>
            <p class="text-gray-700 mb-2"><strong>Bedrooms:</strong> ${listing.bedrooms || 'N/A'}</p>
            <p class="text-gray-700 mb-2"><strong>Utilities:</strong> ${listing.utilities || 'N/A'}</p>
            <p class="text-gray-700 mb-4"><strong>Description:</strong> ${listing.description || 'No description provided.'}</p>
            <div class="modal-media-container mb-4">${mediaHtml}</div>
            <button onclick="window.ChatManager?.startConversation('${listing.user_email}', '${listing.title}')" 
                    class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition"
                Contact Owner
            </button>
        `;

        // Show modal
        modal.classList.add('active');

        // Close modal handlers
        const closeBtn = modalContent.querySelector('.close-button');
        closeBtn.onclick = () => modal.classList.remove('active');
        
        modal.onclick = (e) => {
            if (e.target === modal) {
                modal.classList.remove('active');
            }
        };
    }

    // Upload media files
    async function uploadMedia(files) {
        if (!files || files.length === 0) return [];

        const uploadPromises = files.map(async (file, index) => {
            console.log(`📤 Uploading file ${index + 1}/${files.length}:`, file.name);
            
            // Validate file type
            if (!window.Utils.isImage(file) && !file.type.startsWith('video/')) {
                console.warn(`Skipping non-media file: ${file.name}`);
                return null;
            }

            try {
                const fileName = `${Date.now()}_${index + 1}_${file.name}`;
                const { data, error } = await window.AppConfig.supabase.storage
                    .from('listing-media')
                    .upload(fileName, file);

                if (error) {
                    console.error(`Upload failed for ${file.name}:`, error);
                    return null;
                }

                // Get public URL
                const { data: urlData } = window.AppConfig.supabase.storage
                    .from('listing-media')
                    .getPublicUrl(fileName);

                console.log(`✅ Uploaded ${file.name} successfully`);
                return urlData.publicUrl;
            } catch (error) {
                console.error(`Error uploading ${file.name}:`, error);
                return null;
            }
        });

        const results = await Promise.all(uploadPromises);
        return results.filter(url => url !== null);
    }

    // Handle form submission
    async function handleFormSubmission(e) {
        e.preventDefault();

        // Check authentication
        if (!window.AuthManager.checkAuthForAction('add a listing')) {
            return;
        }

        const currentUser = window.AuthManager.getCurrentUser();

        try {
            // Upload media if present
            const media = uploadedFiles.length > 0 ? await uploadMedia(uploadedFiles) : [];

            // Process form data
            const listing = {
                title: window.Utils.autocorrectInput(window.Utils.sanitizeInput(document.getElementById('title').value)),
                price: parseInt(document.getElementById('price').value),
                city: window.Utils.cleanAddressInput(document.getElementById('city').value),
                country: window.Utils.sanitizeInput(document.getElementById('country').value),
                street: window.Utils.cleanAddressInput(document.getElementById('street').value),
                postalCode: document.getElementById('postalCode').value.trim().toUpperCase().replace(/\s+/g, ' '),
                house_type: document.getElementById('houseType').value,
                bedrooms: parseInt(document.getElementById('bedrooms').value),
                utilities: document.getElementById('utilities').value,
                description: window.Utils.autocorrectInput(window.Utils.sanitizeInput(document.getElementById('description').value)),
                media: media,
                user_email: currentUser.email,
                created_at: new Date().toISOString()
            };

            console.log('📋 Submitting listing:', listing);

            // Validate required fields
            if (!listing.title || !listing.price || !listing.city || !listing.street || !listing.postalCode || !listing.house_type || !listing.bedrooms) {
                window.Utils.showError('Please fill in all required fields.');
                return;
            }

            // Insert into database
            const { data, error } = await window.AppConfig.supabase
                .from('listings')
                .insert([listing])
                .select();

            if (error) {
                console.error('Error inserting listing:', error);
                window.Utils.showError('Failed to add listing: ' + error.message);
                return;
            }

            // Update local storage
            const newListing = { ...listing, id: data[0].id, media: media };
            currentUser.listings = currentUser.listings || [];
            currentUser.listings.push(newListing);
            
            window.Utils.setToStorage('currentUser', currentUser);
            
            // Update users array in storage
            let users = window.Utils.getFromStorage('users', []);
            users = users.map(u => u.email === currentUser.email ? currentUser : u);
            window.Utils.setToStorage('users', users);

            console.log('Updated localStorage with new listing:', newListing);

            // Reset form and UI
            e.target.reset();
            const mediaPreview = document.getElementById('mediaPreview');
            if (mediaPreview) {
                mediaPreview.innerHTML = '';
            }
            uploadedFiles = [];

            window.Utils.showSuccess('Listing added successfully!');
            console.log('🔄 Refreshing listings and map after new listing added');
            
            // Refresh display
            displayListings();

        } catch (error) {
            console.error('Error adding listing:', error);
            window.Utils.showError('Failed to add listing. Please try again.');
        }
    }

    // Handle file upload for media
    function handleFileUpload(files) {
        const mediaPreview = document.getElementById('mediaPreview');
        if (!mediaPreview) return;

        Array.from(files).forEach(file => {
            if (window.Utils.isImage(file) || file.type.startsWith('video/')) {
                uploadedFiles.push(file);
                
                const preview = document.createElement('div');
                preview.className = 'media-preview-item';
                
                if (window.Utils.isImage(file)) {
                    const img = document.createElement('img');
                    img.src = URL.createObjectURL(file);
                    img.className = 'media-preview';
                    preview.appendChild(img);
                } else {
                    const video = document.createElement('video');
                    video.src = URL.createObjectURL(file);
                    video.className = 'media-preview';
                    video.controls = true;
                    preview.appendChild(video);
                }
                
                // Add remove button
                const removeBtn = document.createElement('button');
                removeBtn.textContent = '×';
                removeBtn.className = 'absolute top-0 right-0 bg-red-500 text-white rounded-full w-6 h-6';
                removeBtn.onclick = () => {
                    const index = uploadedFiles.indexOf(file);
                    if (index > -1) uploadedFiles.splice(index, 1);
                    preview.remove();
                };
                
                preview.style.position = 'relative';
                preview.appendChild(removeBtn);
                mediaPreview.appendChild(preview);
            }
        });
    }

    // Initialize listings functionality
    function initialize() {
        // Set up form submission
        const listingForm = document.getElementById('listingForm');
        if (listingForm) {
            listingForm.addEventListener('submit', handleFormSubmission);
        }

        // Set up file upload
        const mediaInput = document.getElementById('media');
        if (mediaInput) {
            mediaInput.addEventListener('change', (e) => {
                handleFileUpload(e.target.files);
            });
        }

        // Display listings on page load
        displayListings();
    }

    // Filter listings based on criteria
    function filterListings(filters) {
        if (!allListings.length) return;

        let filtered = allListings;

        // Apply filters
        if (filters.location) {
            filtered = filtered.filter(listing => 
                listing.city?.toLowerCase().includes(filters.location.toLowerCase()) ||
                listing.street?.toLowerCase().includes(filters.location.toLowerCase())
            );
        }

        if (filters.minPrice) {
            filtered = filtered.filter(listing => listing.price >= filters.minPrice);
        }

        if (filters.maxPrice) {
            filtered = filtered.filter(listing => listing.price <= filters.maxPrice);
        }

        if (filters.houseType) {
            filtered = filtered.filter(listing => listing.house_type === filters.houseType);
        }

        if (filters.bedrooms) {
            filtered = filtered.filter(listing => listing.bedrooms >= filters.bedrooms);
        }

        // Update display
        const container = document.getElementById('listingsContainer');
        if (container) {
            container.innerHTML = '';
            filtered.forEach(listing => {
                const listingCard = createListingCard(listing);
                container.appendChild(listingCard);
            });
        }

        // Update map
        if (window.MapManager) {
            window.MapManager.updateWithListings(filtered);
        }
    }

    // Public API
    return {
        initialize,
        fetchListings,
        displayListings,
        showListingModal,
        filterListings,
        handleFileUpload,
        get allListings() { return allListings; }
    };
})();