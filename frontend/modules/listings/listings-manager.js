/**
 * Listings Manager Module
 * Handles fetching, displaying, and managing property listings
 */

class ListingsManager {
    constructor() {
        this.listings = [];
        this.isLoading = false;
        this.container = null;
        this.currentFilter = null;
        this.currentSort = 'created_at';
        this.currentSortDirection = 'desc';
        this.onListingsUpdated = [];
    }

    /**
     * Initialize the listings manager
     */
    init() {
        this.container = document.getElementById('listingsContainer');
        if (!this.container) {
            console.error('Listings container not found');
            return false;
        }

        console.log('✅ Listings Manager initialized');
        return true;
    }

    /**
     * Fetch listings from Supabase
     */
    async fetchListings(limit = 20, offset = 0) {
        console.log('Fetching listings from Supabase');

        const supabase = window.configManager ? window.configManager.getSupabase() : null;
        if (!supabase) {
            console.error('Supabase client not available');
            return [];
        }

        try {
            // Select only needed columns to reduce egress costs
            let query = supabase
                .from('listings')
                .select('id, title, price, city, street, postalCode, house_type, bedrooms, utilities, description, media, user_email, created_at')
                .order(this.currentSort, { ascending: this.currentSortDirection === 'asc' });

            if (limit) {
                query = query.range(offset, offset + limit - 1);
            }

            const { data, error } = await query;
            console.log('Fetch result:', { data, error });

            if (error) throw error;
            return data || [];
        } catch (error) {
            console.error('Error fetching listings:', error);
            this.showError('Failed to load listings: ' + error.message);
            return [];
        }
    }

    /**
     * Load and display listings
     */
    async loadListings() {
        if (this.isLoading) {
            console.log('Already loading listings, skipping...');
            return;
        }

        this.isLoading = true;
        console.log('🔄 Starting loadListings function');

        try {
            // Show loading state
            this.updateListingCount(0, false, true);

            this.listings = await this.fetchListings();
            console.log('📋 Fetched listings:', this.listings);

            await this.displayListings();
            this.notifyListingsUpdated();
        } catch (error) {
            console.error('Error loading listings:', error);
            this.showError('Failed to load listings');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Display listings in the container
     */
    async displayListings() {
        if (!this.container) {
            console.error('Container not initialized');
            return;
        }

        this.container.innerHTML = '';

        // Update listing count with actual data
        this.updateListingCount(this.listings.length, false);

        if (this.listings.length === 0) {
            console.log('📝 No listings found in database');
            return; // updateListingCount already handles empty state
        }

        // Process each listing
        for (const listing of this.listings) {
            const listingCard = this.createListingCard(listing);
            this.container.appendChild(listingCard);
        }

        // Attach event listeners
        this.attachEventListeners();

        // Update map with all listings
        if (window.mapController) {
            console.log('📍 Updating map with', this.listings.length, 'listings...');
            await window.mapController.updateMap(this.listings);
        }

        console.log('✅ Listings display complete:', this.listings.length, 'listings processed');
    }

    /**
     * Create a listing card element
     */
    createListingCard(listing) {
        console.log('Processing listing:', listing.id, listing.title);

        const media = this.processListingMedia(listing.media || []);
        const primaryImage = this.getPrimaryImage(media);
        const hasOwner = !!listing.user_email;

        const listingCard = document.createElement('div');
        listingCard.className = 'listing-card bg-white rounded-lg shadow-md overflow-hidden relative';

        listingCard.innerHTML = `
            <div class="relative">
                <img src="${primaryImage}" alt="${listing.title}" class="listing-image" onerror="this.src='${this.getErrorImage()}'">
                <button class="favorite-btn absolute top-2 right-2 p-2 bg-white/90 backdrop-blur-sm rounded-full shadow-lg hover:bg-white hover:scale-110 transition-all duration-200 z-10"
                        data-listing-id="${listing.id}"
                        data-favorited="false"
                        title="Save to favorites"
                        onclick="listingsManager.toggleFavorite('${listing.id}', this)">
                    <svg class="w-5 h-5 text-gray-400 hover:text-red-500 transition-colors duration-200" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"></path>
                    </svg>
                </button>
            </div>
            <div class="p-4">
                <h3 class="text-lg font-semibold text-gray-800 truncate">${listing.title}</h3>
                <p class="text-xl font-bold text-blue-600">$${listing.price.toLocaleString()}/mo</p>
                <p class="text-gray-600 text-sm">${listing.street}, ${listing.city}, ${listing.postalCode}</p>
                <div class="flex items-center space-x-2 text-sm text-gray-600 mt-2">
                    <span>${listing.bedrooms} Bed</span>
                    <span>•</span>
                    <span>${listing.house_type}</span>
                    <span>•</span>
                    <span>${listing.utilities}</span>
                </div>
                <p class="text-gray-600 text-sm mt-2 line-clamp-2">${listing.description || 'No description provided'}</p>
                <div class="flex space-x-2 mt-4">
                    <button class="view-details-btn w-1/2 bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg transition font-semibold shadow-md hover:shadow-lg" data-listing='${JSON.stringify(listing)}'>View Details</button>
                    <button class="chat-btn w-1/2 ${hasOwner ? 'bg-blue-600 hover:bg-blue-700' : 'bg-gray-400 cursor-not-allowed'} text-white px-4 py-2 rounded-lg transition font-semibold shadow-md hover:shadow-lg" data-listing='${JSON.stringify(listing)}' ${hasOwner ? '' : 'disabled title="No owner specified for this listing"'}>Chat</button>
                </div>
            </div>
        `;

        return listingCard;
    }

    /**
     * Process listing media and correct MIME types
     */
    processListingMedia(media) {
        if (!Array.isArray(media)) {
            console.warn('Media is not an array, resetting to empty array:', media);
            return [];
        }

        return media.map(item => {
            if (item.type === 'application/json' || !item.type || item.type === 'application/octet-stream') {
                const extension = item.name.split('.').pop().toLowerCase();
                let correctedType;
                switch (extension) {
                    case 'jpg':
                    case 'jpeg':
                        correctedType = 'image/jpeg';
                        break;
                    case 'png':
                        correctedType = 'image/png';
                        break;
                    case 'mp4':
                        correctedType = 'video/mp4';
                        break;
                    default:
                        correctedType = item.type || 'application/octet-stream';
                }
                console.log('Corrected MIME type for', item.name, 'from', item.type, 'to', correctedType);
                return { ...item, type: correctedType };
            }
            return item;
        });
    }

    /**
     * Get primary image for a listing
     */
    getPrimaryImage(media) {
        const isImage = (file) => {
            if (!file || !file.type) return false;
            const byType = file.type.startsWith('image/');
            const byExtension = file.name ? file.name.match(/\.(jpg|jpeg|png)$/i) : false;
            return byType || byExtension;
        };

        return media.length > 0 && isImage(media[0])
            ? media[0].url
            : this.getPlaceholderImage();
    }

    /**
     * Get placeholder image
     */
    getPlaceholderImage() {
        return 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZjNmNGY2Ii8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZmlsbD0iIzY2NzI4MCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPk5vIEltYWdlPC90ZXh0Pjwvc3ZnPg==';
    }

    /**
     * Get error image
     */
    getErrorImage() {
        return 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZmY2Njc3Ii8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZmlsbD0iI2ZmZmZmZiIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkltYWdlIE5vdCBBdmFpbGFibGU8L3RleHQ+PC9zdmc+';
    }

    /**
     * Attach event listeners to listing cards
     */
    attachEventListeners() {
        // View details buttons
        document.querySelectorAll('.view-details-btn').forEach(button => {
            button.addEventListener('click', () => {
                const listing = JSON.parse(button.dataset.listing);
                if (window.listingModal) {
                    window.listingModal.show(listing);
                }
            });
        });

        // Chat buttons
        document.querySelectorAll('.chat-btn').forEach(button => {
            if (!button.disabled) {
                button.addEventListener('click', () => {
                    try {
                        console.log('🎯 Chat button clicked:', button.dataset.listing);
                        const listing = JSON.parse(button.dataset.listing);
                        console.log('📋 Parsed listing data:', listing);
                        if (window.chatController) {
                            window.chatController.startConversation(listing);
                        }
                    } catch (error) {
                        console.error('❌ Error parsing listing data or starting conversation:', error);
                        alert('Error opening chat. Please refresh the page and try again.');
                    }
                });
            } else {
                console.log('⚠️ Chat button is disabled - no owner email specified');
            }
        });
    }

    /**
     * Toggle favorite status
     */
    toggleFavorite(listingId, button) {
        const isCurrentlyFavorited = button.dataset.favorited === 'true';
        const newState = !isCurrentlyFavorited;

        // Update UI immediately
        button.dataset.favorited = newState.toString();
        const svg = button.querySelector('svg');
        if (newState) {
            svg.classList.add('text-red-500');
            svg.classList.remove('text-gray-400');
            button.title = 'Remove from favorites';
        } else {
            svg.classList.remove('text-red-500');
            svg.classList.add('text-gray-400');
            button.title = 'Save to favorites';
        }

        // Save to localStorage (or could be saved to backend)
        const favorites = JSON.parse(localStorage.getItem('favoriteListings') || '[]');
        if (newState) {
            if (!favorites.includes(listingId)) {
                favorites.push(listingId);
            }
        } else {
            const index = favorites.indexOf(listingId);
            if (index > -1) {
                favorites.splice(index, 1);
            }
        }
        localStorage.setItem('favoriteListings', JSON.stringify(favorites));

        console.log(`${newState ? 'Added to' : 'Removed from'} favorites:`, listingId);
    }

    /**
     * Update listing count display
     */
    updateListingCount(count, isFiltered = false, isLoading = false) {
        const countElement = document.getElementById('listingCount');
        if (!countElement) return;

        if (isLoading) {
            countElement.textContent = 'Loading listings...';
            return;
        }

        if (count === 0) {
            countElement.textContent = isFiltered ? 'No listings match your filters' : 'No listings available';
        } else {
            const filterText = isFiltered ? ' (filtered)' : '';
            countElement.textContent = `${count} listing${count !== 1 ? 's' : ''} found${filterText}`;
        }
    }

    /**
     * Add a new listing to the list
     */
    addListing(listing) {
        this.listings.unshift(listing); // Add to beginning
        this.displayListings(); // Refresh display
    }

    /**
     * Remove a listing from the list
     */
    removeListing(listingId) {
        this.listings = this.listings.filter(listing => listing.id !== listingId);
        this.displayListings(); // Refresh display
    }

    /**
     * Update an existing listing
     */
    updateListing(updatedListing) {
        const index = this.listings.findIndex(listing => listing.id === updatedListing.id);
        if (index !== -1) {
            this.listings[index] = updatedListing;
            this.displayListings(); // Refresh display
        }
    }

    /**
     * Filter listings
     */
    filterListings(filterFn) {
        this.currentFilter = filterFn;
        const filteredListings = filterFn ? this.listings.filter(filterFn) : this.listings;

        // Temporarily store original listings and display filtered
        const originalListings = this.listings;
        this.listings = filteredListings;
        this.updateListingCount(filteredListings.length, !!filterFn);
        this.displayListings();
        this.listings = originalListings; // Restore original
    }

    /**
     * Sort listings
     */
    sortListings(sortBy, direction = 'desc') {
        this.currentSort = sortBy;
        this.currentSortDirection = direction;

        this.listings.sort((a, b) => {
            let aVal = a[sortBy];
            let bVal = b[sortBy];

            // Handle different data types
            if (typeof aVal === 'string') {
                aVal = aVal.toLowerCase();
                bVal = bVal.toLowerCase();
            }

            if (direction === 'desc') {
                return bVal > aVal ? 1 : -1;
            } else {
                return aVal > bVal ? 1 : -1;
            }
        });

        this.displayListings();
    }

    /**
     * Register callback for when listings are updated
     */
    onListingsUpdateCallback(callback) {
        this.onListingsUpdated.push(callback);
    }

    /**
     * Notify that listings have been updated
     */
    notifyListingsUpdated() {
        this.onListingsUpdated.forEach(callback => {
            try {
                callback(this.listings);
            } catch (error) {
                console.error('Error in listings updated callback:', error);
            }
        });
    }

    /**
     * Get current listings
     */
    getListings() {
        return this.listings;
    }

    /**
     * Show error message
     */
    showError(message) {
        // Use notification system if available
        if (window.notifications) {
            window.notifications.showError(message);
        } else {
            alert(message);
        }
    }

    /**
     * Refresh listings
     */
    async refresh() {
        await this.loadListings();
    }
}

// Create global instance
window.listingsManager = new ListingsManager();

// Export global functions for backward compatibility
window.loadListings = () => {
    if (window.listingsManager) {
        return window.listingsManager.loadListings();
    }
};

window.displayListings = () => {
    if (window.listingsManager) {
        return window.listingsManager.displayListings();
    }
};

export default window.listingsManager;