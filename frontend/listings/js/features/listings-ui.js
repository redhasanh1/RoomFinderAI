/**
 * Listings UI Module
 * Handles all UI rendering and display logic for listings
 */

let uiInitialized = false;
let currentListings = [];
let currentModal = null;

/**
 * Initialize UI components
 */
function initializeUI() {
    try {
        // Setup event listeners
        setupEventListeners();
        
        // Initialize components
        initializeComponents();
        
        uiInitialized = true;
        console.log('🎨 Listings UI initialized');
        return true;
    } catch (error) {
        console.error('❌ Failed to initialize Listings UI:', error);
        return false;
    }
}

/**
 * Setup event listeners
 */
function setupEventListeners() {
    // Modal close handlers
    document.addEventListener('click', (e) => {
        if (e.target.classList.contains('modal')) {
            closeListingModal();
        }
    });
    
    // Close button handlers
    document.addEventListener('click', (e) => {
        if (e.target.classList.contains('close-button')) {
            closeListingModal();
        }
    });
    
    // Escape key handler
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && currentModal) {
            closeListingModal();
        }
    });
    
    // Listing card click handlers (using event delegation)
    document.addEventListener('click', (e) => {
        const listingCard = e.target.closest('.listing-card');
        if (listingCard && !e.target.closest('.listing-actions')) {
            const listingId = listingCard.dataset.listingId;
            if (listingId) {
                const listing = currentListings.find(l => l.id === listingId);
                if (listing) {
                    showListingModal(listing);
                }
            }
        }
    });
}

/**
 * Initialize UI components
 */
function initializeComponents() {
    // Initialize any required UI components
    const listingsContainer = document.getElementById('listingsContainer');
    if (listingsContainer) {
        listingsContainer.innerHTML = '<div class="text-center py-8">Loading listings...</div>';
    }
}

/**
 * Display listings in the grid
 */
function displayListings(listings) {
    try {
        const listingsContainer = document.getElementById('listingsContainer');
        if (!listingsContainer) {
            console.error('❌ Listings container not found');
            return;
        }
        
        currentListings = listings;
        
        if (!listings || listings.length === 0) {
            listingsContainer.innerHTML = `
                <div class="col-span-full text-center py-12">
                    <div class="text-gray-500 text-lg">No listings found</div>
                    <p class="text-gray-400 mt-2">Try adjusting your search criteria</p>
                </div>
            `;
            return;
        }
        
        // Generate listing cards
        const listingCards = listings.map(listing => createListingCard(listing)).join('');
        
        listingsContainer.innerHTML = listingCards;
        
        // Trigger custom event for other modules
        document.dispatchEvent(new CustomEvent('listingsDisplayed', { 
            detail: { listings: listings } 
        }));
        
        console.log(`✅ Displayed ${listings.length} listings`);
        
    } catch (error) {
        console.error('❌ Error displaying listings:', error);
        showErrorMessage('Failed to display listings');
    }
}

/**
 * Create a listing card HTML
 */
function createListingCard(listing) {
    const imageUrl = getListingImageUrl(listing);
    const price = formatPrice(listing.price);
    const amenities = getAmenities(listing);
    const truncatedDescription = truncateText(listing.description, 100);
    
    return `
        <div class="listing-card-perspective-container">
            <div class="listing-card p-6 cursor-pointer" data-listing-id="${listing.id}">
                <div class="relative mb-4">
                    <img 
                        src="${imageUrl}" 
                        alt="${sanitizeText(listing.title)}" 
                        class="listing-image w-full h-48 object-cover rounded-lg"
                        onerror="this.src='${generatePlaceholderImage(listing.title)}'"
                    />
                    <div class="absolute top-2 right-2 bg-white bg-opacity-90 px-2 py-1 rounded-full text-sm font-semibold text-gray-700">
                        ${price}
                    </div>
                </div>
                
                <h3 class="text-xl font-bold mb-2 text-gray-900">${sanitizeText(listing.title)}</h3>
                
                <div class="flex items-center text-gray-600 mb-2">
                    <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
                    </svg>
                    <span>${sanitizeText(listing.city)}, ${sanitizeText(listing.country)}</span>
                </div>
                
                <div class="text-sm text-gray-500 mb-3">
                    <span class="inline-block bg-gray-100 px-2 py-1 rounded-full mr-2">
                        ${sanitizeText(listing.room_type)}
                    </span>
                </div>
                
                <p class="text-gray-600 mb-4 leading-relaxed">${sanitizeText(truncatedDescription)}</p>
                
                ${amenities.length > 0 ? `
                    <div class="flex flex-wrap gap-2 mb-4">
                        ${amenities.map(amenity => `
                            <span class="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full">
                                ${amenity}
                            </span>
                        `).join('')}
                    </div>
                ` : ''}
                
                <div class="flex justify-between items-center">
                    <span class="text-sm text-gray-500">
                        ${formatDate(listing.created_at)}
                    </span>
                    <button 
                        onclick="event.stopPropagation(); showListingModal(${JSON.stringify(listing).replace(/"/g, '&quot;')})"
                        class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg text-sm transition-colors"
                    >
                        View Details
                    </button>
                </div>
            </div>
        </div>
    `;
}

/**
 * Show listing modal
 */
function showListingModal(listing) {
    try {
        const modal = document.getElementById('listingModal');
        if (!modal) {
            console.error('❌ Listing modal not found');
            return;
        }
        
        currentModal = modal;
        
        // Populate modal content
        populateModalContent(listing);
        
        // Show modal
        modal.classList.add('active');
        document.body.style.overflow = 'hidden';
        
        // Trigger custom event
        document.dispatchEvent(new CustomEvent('listingModalOpened', { 
            detail: { listing: listing } 
        }));
        
        console.log('✅ Listing modal opened:', listing.id);
        
    } catch (error) {
        console.error('❌ Error showing listing modal:', error);
    }
}

/**
 * Populate modal content
 */
function populateModalContent(listing) {
    const imageUrl = getListingImageUrl(listing);
    const price = formatPrice(listing.price);
    const amenities = getAmenities(listing);
    
    const modalContent = `
        <div class="flex justify-between items-start mb-6">
            <h2 class="text-2xl font-bold text-gray-900">${sanitizeText(listing.title)}</h2>
            <button class="close-button text-gray-400 hover:text-gray-600 text-2xl">×</button>
        </div>
        
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
                <img 
                    src="${imageUrl}" 
                    alt="${sanitizeText(listing.title)}" 
                    class="w-full h-64 object-cover rounded-lg mb-4 cursor-pointer"
                    onclick="openImageViewer('${imageUrl}')"
                    onerror="this.src='${generatePlaceholderImage(listing.title)}'"
                />
                
                <div class="space-y-4">
                    <div>
                        <h3 class="font-semibold text-gray-900 mb-2">Description</h3>
                        <p class="text-gray-600 leading-relaxed">${sanitizeText(listing.description)}</p>
                    </div>
                    
                    ${amenities.length > 0 ? `
                        <div>
                            <h3 class="font-semibold text-gray-900 mb-2">Amenities</h3>
                            <div class="flex flex-wrap gap-2">
                                ${amenities.map(amenity => `
                                    <span class="bg-green-100 text-green-800 text-sm px-3 py-1 rounded-full">
                                        ${amenity}
                                    </span>
                                `).join('')}
                            </div>
                        </div>
                    ` : ''}
                </div>
            </div>
            
            <div class="space-y-4">
                <div class="bg-gray-50 p-4 rounded-lg">
                    <div class="text-3xl font-bold text-blue-600 mb-2">${price}</div>
                    <div class="text-gray-600">per month</div>
                </div>
                
                <div class="space-y-3">
                    <div class="flex items-center text-gray-600">
                        <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
                        </svg>
                        <span>${sanitizeText(listing.city)}, ${sanitizeText(listing.country)}</span>
                    </div>
                    
                    <div class="flex items-center text-gray-600">
                        <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z"></path>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3a2 2 0 012-2h4a2 2 0 012 2v4"></path>
                        </svg>
                        <span>${sanitizeText(listing.room_type)}</span>
                    </div>
                    
                    ${listing.street ? `
                        <div class="flex items-center text-gray-600">
                            <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path>
                            </svg>
                            <span>${sanitizeText(listing.street)}</span>
                        </div>
                    ` : ''}
                </div>
                
                <div class="border-t pt-4">
                    <div class="text-sm text-gray-500">
                        Listed on ${formatDate(listing.created_at)}
                    </div>
                </div>
                
                <div class="flex space-x-3">
                    <button 
                        onclick="openChatModal('${listing.id}', '${sanitizeText(listing.title)}')"
                        class="flex-1 bg-blue-500 hover:bg-blue-600 text-white py-2 px-4 rounded-lg transition-colors"
                    >
                        Contact Owner
                    </button>
                    <button 
                        onclick="shareListingModal('${listing.id}')"
                        class="bg-gray-200 hover:bg-gray-300 text-gray-700 py-2 px-4 rounded-lg transition-colors"
                    >
                        Share
                    </button>
                </div>
            </div>
        </div>
    `;
    
    const modalContentElement = document.querySelector('#listingModal .modal-content');
    if (modalContentElement) {
        modalContentElement.innerHTML = modalContent;
    }
}

/**
 * Close listing modal
 */
function closeListingModal() {
    try {
        const modal = document.getElementById('listingModal');
        if (modal) {
            modal.classList.remove('active');
            document.body.style.overflow = '';
            currentModal = null;
            
            // Trigger custom event
            document.dispatchEvent(new CustomEvent('listingModalClosed'));
            
            console.log('✅ Listing modal closed');
        }
    } catch (error) {
        console.error('❌ Error closing listing modal:', error);
    }
}

/**
 * Filter displayed listings (client-side)
 */
function filterDisplayedListings(filterFn) {
    try {
        const filteredListings = currentListings.filter(filterFn);
        displayListings(filteredListings);
        
        console.log(`✅ Filtered to ${filteredListings.length} listings`);
        return filteredListings;
    } catch (error) {
        console.error('❌ Error filtering listings:', error);
        return currentListings;
    }
}

/**
 * Update a specific listing card
 */
function updateListingCard(listingId, updatedListing) {
    try {
        const card = document.querySelector(`[data-listing-id="${listingId}"]`);
        if (card) {
            const newCard = createListingCard(updatedListing);
            const tempDiv = document.createElement('div');
            tempDiv.innerHTML = newCard;
            card.parentNode.replaceChild(tempDiv.firstElementChild, card);
            
            // Update current listings array
            const index = currentListings.findIndex(l => l.id === listingId);
            if (index !== -1) {
                currentListings[index] = updatedListing;
            }
            
            console.log('✅ Updated listing card:', listingId);
        }
    } catch (error) {
        console.error('❌ Error updating listing card:', error);
    }
}

/**
 * Remove a listing card
 */
function removeListingCard(listingId) {
    try {
        const card = document.querySelector(`[data-listing-id="${listingId}"]`);
        if (card) {
            card.closest('.listing-card-perspective-container').remove();
            
            // Update current listings array
            currentListings = currentListings.filter(l => l.id !== listingId);
            
            console.log('✅ Removed listing card:', listingId);
        }
    } catch (error) {
        console.error('❌ Error removing listing card:', error);
    }
}

/**
 * Utility functions
 */
function getListingImageUrl(listing) {
    if (listing.media && listing.media.length > 0) {
        return listing.media[0].url;
    }
    return generatePlaceholderImage(listing.title);
}

function generatePlaceholderImage(title) {
    const hash = btoa(title || 'listing').replace(/[^a-zA-Z0-9]/g, '').substring(0, 10);
    return `https://api.dicebear.com/6.x/shapes/svg?seed=${hash}&backgroundColor=f0f0f0&size=400`;
}

function formatPrice(price) {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD'
    }).format(price);
}

function getAmenities(listing) {
    const amenities = [];
    if (listing.wifi) amenities.push('WiFi');
    if (listing.parking) amenities.push('Parking');
    if (listing.kitchen) amenities.push('Kitchen');
    if (listing.laundry) amenities.push('Laundry');
    if (listing.furnished) amenities.push('Furnished');
    if (listing.pets_allowed) amenities.push('Pets Allowed');
    return amenities;
}

function truncateText(text, maxLength) {
    if (!text) return '';
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
}

function sanitizeText(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

function showErrorMessage(message) {
    const listingsContainer = document.getElementById('listingsContainer');
    if (listingsContainer) {
        listingsContainer.innerHTML = `
            <div class="col-span-full text-center py-12">
                <div class="text-red-500 text-lg">${message}</div>
                <button onclick="window.location.reload()" class="mt-4 bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg">
                    Retry
                </button>
            </div>
        `;
    }
}

function openImageViewer(imageUrl) {
    // Create fullscreen image viewer
    const viewer = document.createElement('div');
    viewer.className = 'fixed inset-0 bg-black bg-opacity-90 flex items-center justify-center z-50';
    viewer.innerHTML = `
        <img src="${imageUrl}" class="max-w-full max-h-full object-contain">
        <button class="absolute top-4 right-4 text-white text-2xl hover:text-gray-300">×</button>
    `;
    
    viewer.addEventListener('click', () => {
        document.body.removeChild(viewer);
    });
    
    document.body.appendChild(viewer);
}

// Export functions for use in other modules
export {
    initializeUI,
    displayListings,
    createListingCard,
    showListingModal,
    closeListingModal,
    filterDisplayedListings,
    updateListingCard,
    removeListingCard,
    getListingImageUrl,
    generatePlaceholderImage,
    formatPrice,
    getAmenities,
    truncateText,
    sanitizeText,
    formatDate,
    showErrorMessage,
    openImageViewer
};

// Also export to window for backward compatibility
window.ListingsUI = {
    initializeUI,
    displayListings,
    createListingCard,
    showListingModal,
    closeListingModal,
    filterDisplayedListings,
    updateListingCard,
    removeListingCard,
    getListingImageUrl,
    generatePlaceholderImage,
    formatPrice,
    getAmenities,
    truncateText,
    sanitizeText,
    formatDate,
    showErrorMessage,
    openImageViewer
};