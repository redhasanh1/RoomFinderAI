/**
 * Listings UI Module
 * Handles all UI rendering, display logic, modal management, and card generation
 */

// Import API functions
import { fetchListings } from './listings-api.js';

// Global UI state
let currentListings = [];
let currentModal = null;

/**
 * Initialize the UI module
 */
export function initializeUI() {
    console.log('🎨 Listings UI initialized');
    setupModalHandlers();
    setupCardInteractions();
}

/**
 * Display listings in the UI
 * @param {Array} listings - Array of listing objects (optional, will fetch if not provided)
 * @param {string} containerId - ID of the container to display listings (default: 'listingsContainer')
 */
export async function displayListings(listings = null, containerId = 'listingsContainer') {
    console.log('🔄 Starting displayListings function');
    
    try {
        // Fetch listings if not provided
        if (!listings) {
            listings = await fetchListings();
        }
        
        console.log('📋 Displaying listings:', listings.length);
        currentListings = listings;
        
        const container = document.getElementById(containerId);
        if (!container) {
            console.error('❌ Container not found:', containerId);
            return;
        }
        
        container.innerHTML = '';

        if (listings.length === 0) {
            container.innerHTML = '<p class="text-gray-600 text-center mb-4">No listings available.</p>';
            console.log('📝 No listings to display');
            return;
        }

        // Process and display each listing
        listings.forEach(listing => {
            const listingCard = createListingCard(listing);
            container.appendChild(listingCard);
        });

        // Setup card event listeners
        setupCardEventListeners();
        
        console.log('✅ Listings display complete:', listings.length, 'listings processed');
        
        // Trigger custom event for other modules to respond
        document.dispatchEvent(new CustomEvent('listingsDisplayed', { 
            detail: { listings, containerId } 
        }));
        
    } catch (error) {
        console.error('❌ Error in displayListings:', error);
        const container = document.getElementById(containerId);
        if (container) {
            container.innerHTML = '<p class="text-red-600 text-center mb-4">Error loading listings. Please refresh the page.</p>';
        }
    }
}

/**
 * Create a listing card element
 * @param {Object} listing - Listing object
 * @returns {HTMLElement} Card element
 */
export function createListingCard(listing) {
    console.log('🎨 Creating card for listing:', listing.id, listing.title);
    
    // Process media
    let media = listing.media || [];
    if (!Array.isArray(media)) {
        console.warn('⚠️ Media is not an array, resetting to empty array:', media);
        media = [];
    }

    // Fix media types
    media = media.map(item => {
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
            console.log('🔧 Corrected MIME type for', item.name, 'from', item.type, 'to', correctedType);
            return { ...item, type: correctedType };
        }
        return item;
    });

    // Determine primary image
    const isImage = (file) => {
        const byType = file.type.startsWith('image/');
        const byExtension = file.name.match(/\.(jpg|jpeg|png)$/i);
        return byType || byExtension;
    };

    const primaryImage = media.length > 0 && isImage(media[0])
        ? media[0].url
        : createPlaceholderImage();

    // Create card element
    const listingCard = document.createElement('div');
    listingCard.className = 'listing-card bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow duration-200';
    listingCard.dataset.listingId = listing.id;

    // Check if listing has owner
    const hasOwner = !!listing.user_email;
    
    // Create card HTML
    listingCard.innerHTML = `
        <div class="relative">
            <img 
                src="${primaryImage}" 
                alt="${sanitizeHtml(listing.title)}" 
                class="listing-image w-full h-48 object-cover"
                onerror="this.src='${createPlaceholderImage('error')}'">
            <div class="absolute top-2 right-2 bg-white bg-opacity-90 rounded-full px-2 py-1 text-xs font-semibold text-gray-700">
                $${listing.price.toLocaleString()}/mo
            </div>
        </div>
        <div class="p-4">
            <h3 class="listing-title text-lg font-semibold text-gray-800 truncate mb-2">${sanitizeHtml(listing.title)}</h3>
            <p class="listing-price text-xl font-bold text-blue-600 mb-2">$${listing.price.toLocaleString()}/mo</p>
            <p class="listing-location text-gray-600 text-sm mb-3">${sanitizeHtml(listing.street)}, ${sanitizeHtml(listing.city)}, ${sanitizeHtml(listing.postalCode)}</p>
            <div class="flex items-center space-x-2 text-sm text-gray-600 mb-3">
                <span class="listing-bedrooms">${listing.bedrooms} Bed${listing.bedrooms > 1 ? 's' : ''}</span>
                <span class="text-gray-400">•</span>
                <span class="listing-type">${sanitizeHtml(listing.house_type)}</span>
                <span class="text-gray-400">•</span>
                <span class="listing-utilities">${sanitizeHtml(listing.utilities)}</span>
            </div>
            <p class="listing-description text-gray-600 text-sm mb-4 line-clamp-2">${sanitizeHtml(listing.description || 'No description provided')}</p>
            <div class="flex space-x-2">
                <button 
                    class="view-details-btn flex-1 bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg transition-colors duration-200 font-semibold shadow-md hover:shadow-lg"
                    data-listing='${JSON.stringify(listing)}'
                    title="View full details">
                    View Details
                </button>
                <button 
                    class="chat-btn flex-1 ${hasOwner ? 'bg-blue-600 hover:bg-blue-700' : 'bg-gray-400 cursor-not-allowed'} text-white px-4 py-2 rounded-lg transition-colors duration-200 font-semibold shadow-md hover:shadow-lg"
                    data-listing='${JSON.stringify(listing)}'
                    ${hasOwner ? '' : 'disabled'}
                    title="${hasOwner ? 'Start conversation with owner' : 'No owner specified for this listing'}">
                    ${hasOwner ? 'Chat' : 'No Owner'}
                </button>
            </div>
        </div>
    `;

    return listingCard;
}

/**
 * Create a placeholder image (SVG data URL)
 * @param {string} type - Type of placeholder ('default' or 'error')
 * @returns {string} SVG data URL
 */
function createPlaceholderImage(type = 'default') {
    const color = type === 'error' ? '#ff6677' : '#f3f4f6';
    const textColor = type === 'error' ? '#ffffff' : '#6b7280';
    const text = type === 'error' ? 'Image Not Available' : 'No Image';
    
    return `data:image/svg+xml;base64,${btoa(`
        <svg width="300" height="200" xmlns="http://www.w3.org/2000/svg">
            <rect width="100%" height="100%" fill="${color}"/>
            <text x="50%" y="50%" font-family="Arial" font-size="18" fill="${textColor}" text-anchor="middle" dy=".3em">${text}</text>
        </svg>
    `)}`;
}

/**
 * Setup event listeners for listing cards
 */
function setupCardEventListeners() {
    // View Details buttons
    document.querySelectorAll('.view-details-btn').forEach(button => {
        button.addEventListener('click', handleViewDetails);
    });

    // Chat buttons
    document.querySelectorAll('.chat-btn').forEach(button => {
        if (!button.disabled) {
            button.addEventListener('click', handleChatClick);
        }
    });
}

/**
 * Handle view details button click
 * @param {Event} event - Click event
 */
function handleViewDetails(event) {
    try {
        const listing = JSON.parse(event.target.dataset.listing);
        console.log('👁️ View details clicked for:', listing.title);
        showListingModal(listing);
    } catch (error) {
        console.error('❌ Error handling view details:', error);
        alert('Error loading listing details. Please try again.');
    }
}

/**
 * Handle chat button click
 * @param {Event} event - Click event
 */
function handleChatClick(event) {
    try {
        const listing = JSON.parse(event.target.dataset.listing);
        console.log('💬 Chat clicked for:', listing.title);
        
        // Dispatch event for chat module to handle
        document.dispatchEvent(new CustomEvent('startConversation', {
            detail: { listing }
        }));
    } catch (error) {
        console.error('❌ Error handling chat click:', error);
        alert('Error opening chat. Please refresh the page and try again.');
    }
}

/**
 * Show listing modal with detailed information
 * @param {Object} listing - Listing object
 */
export function showListingModal(listing) {
    console.log('🔍 Showing modal for:', listing.title);
    
    const modal = document.getElementById('listingModal');
    if (!modal) {
        console.error('❌ Listing modal not found');
        return;
    }

    // Update modal content
    updateModalContent(listing);
    
    // Show modal
    modal.classList.add('active');
    currentModal = modal;
    
    // Prevent body scrolling
    document.body.style.overflow = 'hidden';
    
    console.log('✅ Modal shown for listing:', listing.title);
}

/**
 * Update modal content with listing information
 * @param {Object} listing - Listing object
 */
function updateModalContent(listing) {
    // Update text content
    const titleElement = document.getElementById('modalTitle');
    const priceElement = document.getElementById('modalPrice');
    const locationElement = document.getElementById('modalLocation');
    const detailsElement = document.getElementById('modalDetails');
    const descriptionElement = document.getElementById('modalDescription');
    const imageElement = document.getElementById('modalImage');
    const mediaElement = document.getElementById('modalMedia');
    const viewDetailsElement = document.getElementById('modalViewDetails');

    if (titleElement) titleElement.textContent = listing.title;
    if (priceElement) priceElement.textContent = `$${listing.price.toLocaleString()}/mo`;
    if (locationElement) locationElement.textContent = `${listing.street}, ${listing.city}, ${listing.postalCode}`;
    
    if (detailsElement) {
        detailsElement.innerHTML = `
            <span>${listing.bedrooms} Bed${listing.bedrooms > 1 ? 's' : ''}</span> • 
            <span>${sanitizeHtml(listing.house_type)}</span> • 
            <span>${sanitizeHtml(listing.utilities)}</span>
        `;
    }
    
    if (descriptionElement) {
        descriptionElement.textContent = listing.description || 'No description provided';
    }
    
    // Update main image
    if (imageElement) {
        const primaryImage = listing.media && listing.media.length > 0 && listing.media[0].type.startsWith('image/')
            ? listing.media[0].url
            : createPlaceholderImage();
        imageElement.src = primaryImage;
        imageElement.alt = listing.title;
    }
    
    // Update media gallery
    if (mediaElement) {
        mediaElement.innerHTML = listing.media && listing.media.length > 0
            ? listing.media.map(file => 
                file.type.startsWith('image/')
                    ? `<img src="${file.url}" alt="${sanitizeHtml(file.name)}" class="w-full h-32 object-cover rounded-lg cursor-pointer hover:opacity-80 transition-opacity" onclick="showImageFullscreen('${file.url}', '${sanitizeHtml(file.name)}')">`
                    : `<video src="${file.url}" controls class="w-full h-32 object-cover rounded-lg"></video>`
            ).join('')
            : '<p class="text-gray-500 text-sm">No media available</p>';
    }
    
    // Update view details link
    if (viewDetailsElement) {
        viewDetailsElement.href = `/listing_details?id=${listing.id}`;
    }
}

/**
 * Close the listing modal
 */
export function closeListingModal() {
    if (currentModal) {
        currentModal.classList.remove('active');
        currentModal = null;
        
        // Restore body scrolling
        document.body.style.overflow = '';
        
        console.log('✅ Modal closed');
    }
}

/**
 * Setup modal event handlers
 */
function setupModalHandlers() {
    // Close button
    const closeButton = document.querySelector('.close-button');
    if (closeButton) {
        closeButton.addEventListener('click', closeListingModal);
    }

    // Click outside modal
    window.addEventListener('click', (event) => {
        if (currentModal && event.target === currentModal) {
            closeListingModal();
        }
    });

    // Escape key
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && currentModal) {
            closeListingModal();
        }
    });
}

/**
 * Setup card interaction handlers
 */
function setupCardInteractions() {
    // Add hover effects and other interactions
    document.addEventListener('mouseenter', (event) => {
        if (event.target.classList.contains('listing-card')) {
            event.target.style.transform = 'translateY(-2px)';
        }
    }, true);

    document.addEventListener('mouseleave', (event) => {
        if (event.target.classList.contains('listing-card')) {
            event.target.style.transform = 'translateY(0)';
        }
    }, true);
}

/**
 * Show image in fullscreen
 * @param {string} imageUrl - URL of the image
 * @param {string} imageName - Name of the image
 */
window.showImageFullscreen = function(imageUrl, imageName) {
    const fullscreenOverlay = document.createElement('div');
    fullscreenOverlay.className = 'fixed inset-0 bg-black bg-opacity-90 flex items-center justify-center z-50';
    fullscreenOverlay.innerHTML = `
        <div class="relative max-w-4xl max-h-full p-4">
            <button class="absolute top-2 right-2 text-white hover:text-gray-300 text-2xl z-10" onclick="this.parentElement.parentElement.remove()">×</button>
            <img src="${imageUrl}" alt="${imageName}" class="max-w-full max-h-full object-contain">
        </div>
    `;
    
    fullscreenOverlay.addEventListener('click', (e) => {
        if (e.target === fullscreenOverlay) {
            fullscreenOverlay.remove();
        }
    });
    
    document.body.appendChild(fullscreenOverlay);
};

/**
 * Sanitize HTML content
 * @param {string} str - String to sanitize
 * @returns {string} Sanitized string
 */
function sanitizeHtml(str) {
    if (typeof str !== 'string') return '';
    return str.replace(/[<>&"']/g, (char) => {
        const map = {
            '<': '&lt;',
            '>': '&gt;',
            '&': '&amp;',
            '"': '&quot;',
            "'": '&#39;'
        };
        return map[char];
    });
}

/**
 * Filter displayed listings based on criteria
 * @param {Object} filters - Filter criteria
 */
export function filterDisplayedListings(filters) {
    console.log('🔍 Filtering displayed listings:', filters);
    
    const listingCards = document.querySelectorAll('.listing-card');
    let visibleCount = 0;
    
    listingCards.forEach(card => {
        let matches = true;
        
        // Apply filters
        if (filters.location && matches) {
            const locationElement = card.querySelector('.listing-location');
            if (locationElement && !locationElement.textContent.toLowerCase().includes(filters.location.toLowerCase())) {
                matches = false;
            }
        }
        
        if (filters.maxPrice && matches) {
            const priceElement = card.querySelector('.listing-price');
            if (priceElement) {
                const price = parseInt(priceElement.textContent.replace(/[^\d]/g, ''));
                if (price > filters.maxPrice) {
                    matches = false;
                }
            }
        }
        
        if (filters.roomType && matches) {
            const typeElement = card.querySelector('.listing-type');
            if (typeElement && typeElement.textContent !== filters.roomType) {
                matches = false;
            }
        }
        
        if (filters.bedrooms && matches) {
            const bedroomsElement = card.querySelector('.listing-bedrooms');
            if (bedroomsElement && !bedroomsElement.textContent.includes(filters.bedrooms)) {
                matches = false;
            }
        }
        
        // Show/hide card
        if (matches) {
            card.style.display = 'block';
            visibleCount++;
        } else {
            card.style.display = 'none';
        }
    });
    
    // Update results count
    const resultsElement = document.querySelector('.search-results-count');
    if (resultsElement) {
        resultsElement.textContent = `${visibleCount} listings found`;
    }
    
    console.log('📊 Filter results:', visibleCount, 'listings visible');
    return visibleCount;
}

/**
 * Get currently displayed listings
 * @returns {Array} Array of currently displayed listings
 */
export function getCurrentListings() {
    return currentListings;
}

/**
 * Update a specific listing card
 * @param {Object} updatedListing - Updated listing object
 */
export function updateListingCard(updatedListing) {
    const card = document.querySelector(`[data-listing-id="${updatedListing.id}"]`);
    if (card) {
        const newCard = createListingCard(updatedListing);
        card.parentNode.replaceChild(newCard, card);
        
        // Update current listings array
        const index = currentListings.findIndex(l => l.id === updatedListing.id);
        if (index !== -1) {
            currentListings[index] = updatedListing;
        }
        
        // Re-setup event listeners for the new card
        setupCardEventListeners();
        
        console.log('✅ Listing card updated:', updatedListing.id);
    }
}

/**
 * Remove a listing card
 * @param {string} listingId - ID of the listing to remove
 */
export function removeListingCard(listingId) {
    const card = document.querySelector(`[data-listing-id="${listingId}"]`);
    if (card) {
        card.remove();
        
        // Update current listings array
        currentListings = currentListings.filter(l => l.id !== listingId);
        
        console.log('🗑️ Listing card removed:', listingId);
    }
}

// Export all functions
export default {
    initializeUI,
    displayListings,
    createListingCard,
    showListingModal,
    closeListingModal,
    filterDisplayedListings,
    getCurrentListings,
    updateListingCard,
    removeListingCard
};