// Global variables for listings page
let map;
let markers = [];
let markerClusterGroup;
let currentConversationId = null;
let allListings = [];
let filteredListings = [];
let globalUserConversations = [];
let globalUnreadCount = 0;
let locallyReadConversations = new Set();

// Chat system status tracking
const chatSystemStatus = {
    isInitialized: false,
    connectionStatus: 'disconnected',
    lastActivity: null,
    databaseErrors: {
        constraintViolations: 0,
        lastConstraintError: null
    }
};

// Initialize Map with clustering
function initMap() {
    console.log('🗺️ Initializing map...');
    const mapContainer = document.getElementById('map');
    const mapError = document.getElementById('map-error');
    
    if (!mapContainer) {
        console.error('Map container not found');
        return false;
    }

    try {
        // Initialize map centered on Toronto
        map = L.map('map', {
            center: [43.6532, -79.3832], // Toronto coordinates
            zoom: 10,
            zoomControl: true,
            attributionControl: true
        });

        // Add OpenStreetMap tiles
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
            maxZoom: 18,
            minZoom: 2
        }).addTo(map);

        // Initialize marker cluster group
        markerClusterGroup = L.markerClusterGroup({
            maxClusterRadius: 50,
            showCoverageOnHover: false,
            zoomToBoundsOnClick: true,
            spiderfyOnMaxZoom: true,
            iconCreateFunction: function(cluster) {
                const count = cluster.getChildCount();
                return L.divIcon({
                    html: `<div style="background-color: #3b82f6; color: white; border-radius: 50%; width: 35px; height: 35px; display: flex; align-items: center; justify-content: center; font-weight: bold; border: 2px solid white; box-shadow: 0 2px 6px rgba(0,0,0,0.3); font-size: 12px;">${count}</div>`,
                    className: 'marker-cluster',
                    iconSize: [35, 35]
                });
            }
        });
        map.addLayer(markerClusterGroup);

        // Force map to render properly
        setTimeout(() => {
            map.invalidateSize();
            console.log('Map size invalidated and rendered');
        }, 500);

        if (mapError) mapError.style.display = 'none';
        console.log('Map initialized successfully');
        return true;
    } catch (error) {
        console.error('Failed to initialize map:', error);
        if (mapError) mapError.style.display = 'block';
        return false;
    }
}

// Geocoding function with fallback coordinates
async function geocodeLocation(location, retries = 2, delay = 1000) {
    console.log('Geocoding location:', location);
    
    // Default coordinates for common cities
    const cityDefaults = {
        'toronto': { lat: 43.6532, lon: -79.3832 },
        'vancouver': { lat: 49.2827, lon: -123.1207 },
        'montreal': { lat: 45.5017, lon: -73.5673 },
        'calgary': { lat: 51.0447, lon: -114.0719 },
        'ottawa': { lat: 45.4215, lon: -75.6972 },
        'london': { lat: 51.5074, lon: -0.1278 },
        'new york': { lat: 40.7128, lon: -74.0060 },
        'los angeles': { lat: 34.0522, lon: -118.2437 }
    };
    
    try {
        const encodedQuery = encodeURIComponent(location.trim());
        const response = await fetch(`https://nominatim.openstreetmap.org/search?q=${encodedQuery}&format=json&limit=1`, {
            headers: { 'User-Agent': 'RoomFinder/1.0' }
        });

        if (response.ok) {
            const data = await response.json();
            if (data && data.length > 0) {
                const result = data[0];
                const coords = {
                    lat: parseFloat(result.lat),
                    lon: parseFloat(result.lon),
                    display_name: result.display_name
                };
                
                if (coords.lat >= -90 && coords.lat <= 90 && coords.lon >= -180 && coords.lon <= 180) {
                    console.log('✅ Successfully geocoded:', location, '→', coords);
                    return coords;
                }
            }
        }
    } catch (error) {
        console.error('Geocoding API error:', error);
    }
    
    // Fallback to city defaults
    const cityName = location.toLowerCase().split(',')[1]?.trim() || location.toLowerCase().split(',')[0]?.trim() || '';
    
    for (const [city, coords] of Object.entries(cityDefaults)) {
        if (cityName.includes(city) || city.includes(cityName)) {
            console.log('🔄 Using fallback coordinates for', city, ':', coords);
            return {
                lat: coords.lat + (Math.random() - 0.5) * 0.01,
                lon: coords.lon + (Math.random() - 0.5) * 0.01,
                display_name: `${location} (approximate)`
            };
        }
    }
    
    // Default to Toronto area
    console.log('⚠️ Using default Toronto area for:', location);
    return {
        lat: 43.6532 + (Math.random() - 0.5) * 0.1,
        lon: -79.3832 + (Math.random() - 0.5) * 0.1,
        display_name: `${location} (default location)`
    };
}

// Update map with listings
async function updateMap(listings) {
    console.log('🗺️ Starting updateMap with', listings.length, 'listings');
    
    if (!map || !markerClusterGroup) {
        console.log('Map not ready, initializing...');
        if (!initMap()) {
            console.error('❌ Failed to initialize map');
            return;
        }
        await new Promise(resolve => setTimeout(resolve, 1000));
    }

    // Clear existing markers
    markerClusterGroup.clearLayers();
    markers = [];
    const validCoordinates = [];
    let successfulMarkers = 0;

    for (let i = 0; i < listings.length; i++) {
        const listing = listings[i];
        const location = `${listing.street}, ${listing.city}, ${listing.postalCode}`;
        
        try {
            const coords = await geocodeLocation(location);

            if (coords && !isNaN(coords.lat) && !isNaN(coords.lon)) {
                const marker = L.marker([coords.lat, coords.lon], {
                    title: listing.title
                });

                const popupContent = `
                    <div style="min-width: 200px; font-family: Arial, sans-serif;">
                        <h3 style="margin: 0 0 8px 0; font-size: 16px; font-weight: bold; color: #1f2937;">${listing.title}</h3>
                        <div style="color: #059669; font-weight: bold; font-size: 18px; margin-bottom: 6px;">$${listing.price.toLocaleString()}/mo</div>
                        <div style="color: #6b7280; font-size: 13px; margin-bottom: 8px;">${location}</div>
                        <div style="font-size: 12px; color: #6b7280; margin-bottom: 10px;">
                            ${listing.bedrooms} Bed • ${listing.house_type} • ${listing.utilities}
                        </div>
                        <a href="/listing_details?id=${listing.id}" style="background-color: #3b82f6; color: white; padding: 6px 12px; border-radius: 4px; text-decoration: none; font-size: 12px; font-weight: 500;">View Details</a>
                    </div>
                `;

                marker.bindPopup(popupContent, { maxWidth: 250 });
                markerClusterGroup.addLayer(marker);
                markers.push(marker);
                validCoordinates.push([coords.lat, coords.lon]);
                successfulMarkers++;
            }
        } catch (error) {
            console.error('❌ Error processing listing:', listing.title, error);
        }

        if (i < listings.length - 1) {
            await new Promise(resolve => setTimeout(resolve, 200));
        }
    }

    console.log(`🎯 Map update complete! Added ${successfulMarkers} markers`);

    // Adjust map view
    if (validCoordinates.length > 0) {
        if (validCoordinates.length === 1) {
            map.setView(validCoordinates[0], 14);
        } else {
            try {
                const bounds = L.latLngBounds(validCoordinates);
                map.fitBounds(bounds, { padding: [20, 20], maxZoom: 15 });
            } catch (error) {
                map.setView([43.6532, -79.3832], 10);
            }
        }
    } else {
        map.setView([43.6532, -79.3832], 10);
    }

    setTimeout(() => {
        if (map) map.invalidateSize();
    }, 500);
}

// Display listings in the grid
function displayListings() {
    console.log('📋 Displaying listings...');
    const container = document.getElementById('listingsContainer');
    const listingsToShow = filteredListings.length > 0 ? filteredListings : allListings;
    
    if (!container) {
        console.error('Listings container not found');
        return;
    }

    container.innerHTML = '';

    if (listingsToShow.length === 0) {
        container.innerHTML = '<p class="text-gray-600 text-center mb-4">No listings available. Try adjusting your filters.</p>';
        return;
    }

    listingsToShow.forEach(listing => {
        displayListingCard(listing, container);
    });

    updateMap(listingsToShow);
}

// Display listings in the grid
async function displayListings() {
    console.log('📋 Displaying listings...');
    
    let listings = await fetchListings();
    const container = document.getElementById('listingsContainer');
    
    if (!container) {
        console.error('Listings container not found');
        return;
    }

    container.innerHTML = '';

    if (listings.length === 0) {
        container.innerHTML = '<p class="text-gray-600 text-center mb-4">No listings available in database.</p>';
        return;
    }

    listings.forEach(listing => {
        displayListingCard(listing, container);
    });

    // Add event listeners after all cards are rendered
    setupListingEventListeners();
    
    // Update map with all listings
    await updateMap(listings);
}

// Display individual listing card with chat functionality
function displayListingCard(listing, container) {
    let media = listing.media || [];
    if (!Array.isArray(media)) {
        try {
            media = typeof listing.media === 'string' ? JSON.parse(listing.media) : [];
        } catch (e) {
            media = [];
        }
    }

    // Correct media types and find primary image
    media = media.map(item => {
        if (item.type === 'application/json' || !item.type || item.type === 'application/octet-stream') {
            const extension = item.name.split('.').pop().toLowerCase();
            switch (extension) {
                case 'jpg':
                case 'jpeg':
                    return { ...item, type: 'image/jpeg' };
                case 'png':
                    return { ...item, type: 'image/png' };
                case 'gif':
                    return { ...item, type: 'image/gif' };
                case 'webp':
                    return { ...item, type: 'image/webp' };
                case 'mp4':
                    return { ...item, type: 'video/mp4' };
                case 'webm':
                    return { ...item, type: 'video/webm' };
                default:
                    return item;
            }
        }
        return item;
    });

    // Find primary image
    const imageMedia = media.find(item => item.type && item.type.startsWith('image/'));
    const primaryImageUrl = imageMedia ? imageMedia.url : 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZTVlN2ViIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZmlsbD0iIzZiNzI4MCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPk5vIEltYWdlPC90ZXh0Pjwvc3ZnPg==';

    // Check if listing has owner for chat functionality
    const hasOwner = !!listing.user_email;

    // Create listing card with chat functionality
    const listingCardContainer = document.createElement('div');
    listingCardContainer.className = 'listing-card-perspective-container';
    
    const listingCard = document.createElement('div');
    listingCard.className = 'listing-card bg-white rounded-lg shadow-md overflow-hidden';
    
    listingCard.innerHTML = `
        <img src="${primaryImageUrl}" alt="${listing.title}" class="listing-image" onerror="this.src='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZTVlN2ViIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZmlsbD0iIzZiNzI4MCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkltYWdlIEZhaWxlZDwvdGV4dD48L3N2Zz4='">
        <div class="p-4">
            <h3 class="text-lg font-semibold text-gray-800 truncate">${listing.title}</h3>
            <p class="text-xl font-bold text-blue-600">$${listing.price.toLocaleString()}/mo</p>
            <p class="text-gray-600 text-sm">${listing.street}, ${listing.city}, ${listing.postal_code || listing.postalCode}</p>
            <div class="flex items-center space-x-2 text-sm text-gray-600 mt-2">
                <span>${listing.bedrooms} Bed</span>
                <span>•</span>
                <span>${listing.house_type}</span>
                <span>•</span>
                <span>${listing.utilities}</span>
            </div>
            <p class="text-gray-600 text-sm mt-2 line-clamp-2">${listing.description || 'No description provided'}</p>
            <div class="flex space-x-2 mt-4">
                <button class="view-details-btn w-1/2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition font-semibold shadow-md hover:shadow-lg" data-listing='${JSON.stringify(listing)}'>View Details</button>
                <button class="chat-btn w-1/2 bg-green-600 text-white px-4 py-2 rounded-lg transition ${hasOwner ? 'hover:bg-green-700' : ''} font-semibold shadow-md hover:shadow-lg" data-listing='${JSON.stringify(listing)}' ${hasOwner ? '' : 'disabled title="No owner specified for this listing"'}>Message Landlord</button>
            </div>
        </div>
    `;
    
    listingCardContainer.appendChild(listingCard);
    container.appendChild(listingCardContainer);
}

// Setup event listeners for listing cards
function setupListingEventListeners() {
    // View Details buttons
    document.querySelectorAll('.view-details-btn').forEach(button => {
        button.addEventListener('click', (e) => {
            e.stopPropagation();
            try {
                const listing = JSON.parse(button.dataset.listing);
                openListingModal(listing.id);
            } catch (error) {
                console.error('Error opening listing modal:', error);
            }
        });
    });

    // Chat buttons  
    document.querySelectorAll('.chat-btn').forEach(button => {
        if (!button.disabled) {
            button.addEventListener('click', (e) => {
                e.stopPropagation();
                try {
                    const listing = JSON.parse(button.dataset.listing);
                    startConversationWithListing(listing);
                } catch (error) {
                    console.error('Error starting conversation:', error);
                    alert('Error opening chat. Please refresh the page and try again.');
                }
            });
        }
    });
}

// Search and filter functions
async function applySearchFilters() {
    console.log('🔍 Applying search filters...');
    
    const location = document.getElementById('searchLocation').value.toLowerCase().trim();
    const maxPrice = parseInt(document.getElementById('searchMaxPrice').value);
    const roomType = document.getElementById('searchRoomType').value;
    const bedrooms = document.getElementById('searchBedrooms').value;
    
    let query = supabase
        .from('listings')
        .select('*')
        .order('created_at', { ascending: false });
    
    if (location) {
        query = query.or(`city.ilike.%${location}%,street.ilike.%${location}%,postal_code.ilike.%${location}%`);
    }
    
    if (maxPrice && !isNaN(maxPrice)) {
        query = query.lte('price', maxPrice);
    }
    
    if (roomType) {
        query = query.eq('house_type', roomType);
    }
    
    if (bedrooms) {
        query = query.eq('bedrooms', parseInt(bedrooms));
    }
    
    try {
        const { data: results, error } = await query;
        
        if (error) {
            console.error('Search error:', error);
            alert('Search failed: ' + error.message);
            return;
        }
        
        console.log(`✅ Found ${results.length} listings matching criteria`);
        
        const container = document.getElementById('listingsContainer');
        container.innerHTML = '';

        if (results.length === 0) {
            container.innerHTML = '<p class="text-gray-600 text-center mb-4">No listings match your search criteria.</p>';
            if (markerClusterGroup) markerClusterGroup.clearLayers();
            return;
        }

        results.forEach(listing => {
            displayListingCard(listing, container);
        });
        
        await updateMap(results);
        
    } catch (error) {
        console.error('Search error:', error);
        alert('Search failed: ' + error.message);
    }
}

function clearSearchFilters() {
    console.log('🧹 Clearing search filters...');
    
    document.getElementById('searchLocation').value = '';
    document.getElementById('searchMaxPrice').value = '';
    document.getElementById('searchRoomType').value = '';
    document.getElementById('searchBedrooms').value = '';
    
    filteredListings = [];
    displayListings();
}

// Error handling
function showError(message) {
    console.error('Error:', message);
    alert(message);
}