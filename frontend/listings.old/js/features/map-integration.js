/**
 * Map Integration Module
 * Handles all map-related functionality using Leaflet.js
 */

class MapIntegration {
    constructor(containerId, options = {}) {
        this.containerId = containerId;
        this.map = null;
        this.markers = [];
        this.markerClusterGroup = null;
        this.currentListings = [];
        this.isInitialized = false;
        
        // Configuration options
        this.options = {
            defaultZoom: 12,
            maxZoom: 18,
            minZoom: 2,
            attribution: '© OpenStreetMap contributors',
            tileLayer: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            clusterOptions: {
                chunkedLoading: true,
                chunkInterval: 200,
                chunkDelay: 50
            },
            geocodingRetries: 3,
            geocodingTimeout: 5000,
            fallbackCoordinates: {
                'New York': [40.7128, -74.0060],
                'London': [51.5074, -0.1278],
                'Paris': [48.8566, 2.3522],
                'Tokyo': [35.6762, 139.6503],
                'Sydney': [-33.8688, 151.2093],
                'Toronto': [43.6532, -79.3832],
                'Berlin': [52.5200, 13.4050],
                'Amsterdam': [52.3676, 4.9041],
                'Barcelona': [41.3851, 2.1734],
                'Rome': [41.9028, 12.4964]
            },
            ...options
        };
        
        console.log('🗺️ Map Integration initialized for container:', containerId);
    }
    
    /**
     * Initialize the map
     */
    async initialize() {
        try {
            const container = document.getElementById(this.containerId);
            if (!container) {
                throw new Error(`Map container '${this.containerId}' not found`);
            }
            
            // Check if Leaflet is available
            if (typeof L === 'undefined') {
                throw new Error('Leaflet library not loaded');
            }
            
            // Create map instance
            this.map = L.map(this.containerId, {
                zoom: this.options.defaultZoom,
                maxZoom: this.options.maxZoom,
                minZoom: this.options.minZoom,
                zoomControl: true,
                attributionControl: true
            });
            
            // Add tile layer
            L.tileLayer(this.options.tileLayer, {
                attribution: this.options.attribution,
                maxZoom: this.options.maxZoom
            }).addTo(this.map);
            
            // Initialize marker cluster group
            if (L.markerClusterGroup) {
                this.markerClusterGroup = L.markerClusterGroup(this.options.clusterOptions);
                this.map.addLayer(this.markerClusterGroup);
            } else {
                console.warn('⚠️ Marker clustering not available');
            }
            
            // Set default view (center on world)
            this.map.setView([20, 0], 2);
            
            // Setup event listeners
            this.setupEventListeners();
            
            // Hide error message if visible
            this.hideError();
            
            this.isInitialized = true;
            console.log('✅ Map initialized successfully');
            
            return true;
            
        } catch (error) {
            console.error('❌ Map initialization failed:', error);
            this.showError('Map failed to load. Please refresh the page.');
            return false;
        }
    }
    
    /**
     * Setup map event listeners
     */
    setupEventListeners() {
        if (!this.map) return;
        
        // Map ready event
        this.map.whenReady(() => {
            console.log('🗺️ Map ready');
            this.invalidateSize();
        });
        
        // Map click event
        this.map.on('click', (e) => {
            console.log('🗺️ Map clicked at:', e.latlng);
        });
        
        // Zoom event
        this.map.on('zoomend', () => {
            console.log('🗺️ Map zoom level:', this.map.getZoom());
        });
        
        // Error handling
        this.map.on('tileerror', (error) => {
            console.warn('⚠️ Tile loading error:', error);
        });
    }
    
    /**
     * Update map with listings data
     */
    async updateWithListings(listings = []) {
        if (!this.isInitialized) {
            console.warn('⚠️ Map not initialized, skipping update');
            return { success: false, processed: 0, errors: 0 };
        }
        
        try {
            console.log(`🗺️ Updating map with ${listings.length} listings`);
            
            // Clear existing markers
            this.clearMarkers();
            
            // Store current listings
            this.currentListings = listings;
            
            if (listings.length === 0) {
                console.log('ℹ️ No listings to display on map');
                return { success: true, processed: 0, errors: 0 };
            }
            
            const results = { success: true, processed: 0, errors: 0 };
            const bounds = L.latLngBounds();
            let hasValidCoordinates = false;
            
            // Process listings in chunks for better performance
            const chunkSize = 10;
            for (let i = 0; i < listings.length; i += chunkSize) {
                const chunk = listings.slice(i, i + chunkSize);
                
                await Promise.all(chunk.map(async (listing) => {
                    try {
                        const coordinates = await this.geocodeListing(listing);
                        if (coordinates) {
                            const marker = this.createListingMarker(listing, coordinates);
                            this.markers.push(marker);
                            
                            if (this.markerClusterGroup) {
                                this.markerClusterGroup.addLayer(marker);
                            } else {
                                marker.addTo(this.map);
                            }
                            
                            bounds.extend(coordinates);
                            hasValidCoordinates = true;
                            results.processed++;
                        } else {
                            results.errors++;
                        }
                    } catch (error) {
                        console.error('❌ Error processing listing:', listing.id, error);
                        results.errors++;
                    }
                }));
                
                // Add small delay between chunks
                if (i + chunkSize < listings.length) {
                    await new Promise(resolve => setTimeout(resolve, 50));
                }
            }
            
            // Fit map to markers if we have valid coordinates
            if (hasValidCoordinates && bounds.isValid()) {
                this.map.fitBounds(bounds, { padding: [20, 20] });
            }
            
            console.log(`✅ Map update completed: ${results.processed} markers added, ${results.errors} errors`);
            return results;
            
        } catch (error) {
            console.error('❌ Error updating map with listings:', error);
            this.showError('Failed to update map. Please try again.');
            return { success: false, processed: 0, errors: 1 };
        }
    }
    
    /**
     * Geocode a listing to get coordinates
     */
    async geocodeListing(listing) {
        try {
            // Check if listing already has coordinates
            if (listing.latitude && listing.longitude) {
                return [parseFloat(listing.latitude), parseFloat(listing.longitude)];
            }
            
            // Build address string
            const addressParts = [
                listing.street,
                listing.city,
                listing.country
            ].filter(part => part && part.trim());
            
            if (addressParts.length === 0) {
                console.warn('⚠️ No address information for listing:', listing.id);
                return null;
            }
            
            const address = addressParts.join(', ');
            
            // Try geocoding
            const coordinates = await this.geocodeAddress(address);
            if (coordinates) {
                return coordinates;
            }
            
            // Fallback to city-only geocoding
            if (listing.city) {
                const cityCoords = await this.geocodeAddress(listing.city + ', ' + (listing.country || ''));
                if (cityCoords) {
                    return cityCoords;
                }
                
                // Check fallback coordinates
                const fallbackCoords = this.options.fallbackCoordinates[listing.city];
                if (fallbackCoords) {
                    console.log('📍 Using fallback coordinates for:', listing.city);
                    return fallbackCoords;
                }
            }
            
            console.warn('❌ Could not geocode listing:', listing.id, address);
            return null;
            
        } catch (error) {
            console.error('❌ Geocoding error for listing:', listing.id, error);
            return null;
        }
    }
    
    /**
     * Geocode an address using Nominatim API
     */
    async geocodeAddress(address) {
        for (let attempt = 1; attempt <= this.options.geocodingRetries; attempt++) {
            try {
                const controller = new AbortController();
                const timeoutId = setTimeout(() => controller.abort(), this.options.geocodingTimeout);
                
                const response = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(address)}&limit=1`, {
                    signal: controller.signal,
                    headers: {
                        'User-Agent': 'RoomFinderAI/1.0'
                    }
                });
                
                clearTimeout(timeoutId);
                
                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}`);
                }
                
                const data = await response.json();
                
                if (data.length > 0) {
                    const result = data[0];
                    const coordinates = [parseFloat(result.lat), parseFloat(result.lon)];
                    console.log('📍 Geocoded:', address, '->', coordinates);
                    return coordinates;
                }
                
                console.warn('❌ No geocoding results for:', address);
                return null;
                
            } catch (error) {
                if (error.name === 'AbortError') {
                    console.warn(`⏰ Geocoding timeout for: ${address} (attempt ${attempt})`);
                } else {
                    console.warn(`❌ Geocoding failed for: ${address} (attempt ${attempt}):`, error.message);
                }
                
                if (attempt < this.options.geocodingRetries) {
                    // Wait before retry with exponential backoff
                    const delay = Math.min(1000 * Math.pow(2, attempt - 1), 5000);
                    await new Promise(resolve => setTimeout(resolve, delay));
                }
            }
        }
        
        return null;
    }
    
    /**
     * Create a marker for a listing
     */
    createListingMarker(listing, coordinates) {
        try {
            // Create custom icon
            const icon = L.divIcon({
                className: 'custom-marker',
                html: `
                    <div class="marker-pin">
                        <div class="marker-price">$${this.formatPrice(listing.price)}</div>
                    </div>
                `,
                iconSize: [40, 40],
                iconAnchor: [20, 40],
                popupAnchor: [0, -40]
            });
            
            // Create marker
            const marker = L.marker(coordinates, { icon });
            
            // Create popup content
            const popupContent = this.createPopupContent(listing);
            marker.bindPopup(popupContent, {
                maxWidth: 300,
                className: 'custom-popup'
            });
            
            // Store listing data in marker
            marker.listingData = listing;
            
            // Add event listeners
            marker.on('click', () => {
                console.log('🗺️ Marker clicked for listing:', listing.id);
                
                // Trigger custom event
                document.dispatchEvent(new CustomEvent('markerClicked', {
                    detail: { listing, coordinates }
                }));
            });
            
            return marker;
            
        } catch (error) {
            console.error('❌ Error creating marker for listing:', listing.id, error);
            return null;
        }
    }
    
    /**
     * Create popup content for a listing
     */
    createPopupContent(listing) {
        const imageUrl = this.getListingImageUrl(listing);
        const amenities = this.getAmenities(listing);
        
        return `
            <div class="listing-popup">
                <div class="popup-image">
                    <img src="${imageUrl}" alt="${this.escapeHtml(listing.title)}" />
                </div>
                <div class="popup-content">
                    <h3 class="popup-title">${this.escapeHtml(listing.title)}</h3>
                    <p class="popup-location">
                        <i class="location-icon">📍</i>
                        ${this.escapeHtml(listing.city)}, ${this.escapeHtml(listing.country)}
                    </p>
                    <p class="popup-price">$${this.formatPrice(listing.price)}/month</p>
                    <p class="popup-type">${this.escapeHtml(listing.room_type)}</p>
                    ${amenities.length > 0 ? `
                        <div class="popup-amenities">
                            ${amenities.slice(0, 3).map(amenity => `<span class="amenity-tag">${amenity}</span>`).join('')}
                            ${amenities.length > 3 ? `<span class="amenity-more">+${amenities.length - 3} more</span>` : ''}
                        </div>
                    ` : ''}
                    <div class="popup-actions">
                        <button onclick="showListingModal('${listing.id}')" class="popup-btn primary">
                            View Details
                        </button>
                        <button onclick="openChatModal('${listing.id}')" class="popup-btn secondary">
                            Contact
                        </button>
                    </div>
                </div>
            </div>
        `;
    }
    
    /**
     * Clear all markers from the map
     */
    clearMarkers() {
        try {
            if (this.markerClusterGroup) {
                this.markerClusterGroup.clearLayers();
            } else {
                this.markers.forEach(marker => {
                    if (this.map && this.map.hasLayer(marker)) {
                        this.map.removeLayer(marker);
                    }
                });
            }
            
            this.markers = [];
            console.log('🗺️ Map markers cleared');
            
        } catch (error) {
            console.error('❌ Error clearing markers:', error);
        }
    }
    
    /**
     * Center map on a specific location
     */
    async centerOnLocation(location, zoom = null) {
        try {
            if (!this.isInitialized) {
                console.warn('⚠️ Map not initialized');
                return false;
            }
            
            const coordinates = await this.geocodeAddress(location);
            if (coordinates) {
                const zoomLevel = zoom || this.options.defaultZoom;
                this.map.setView(coordinates, zoomLevel);
                console.log('🗺️ Map centered on:', location, coordinates);
                return true;
            } else {
                console.warn('❌ Could not center map on:', location);
                return false;
            }
            
        } catch (error) {
            console.error('❌ Error centering map:', error);
            return false;
        }
    }
    
    /**
     * Fit map to show all current markers
     */
    fitToMarkers() {
        try {
            if (!this.isInitialized || this.markers.length === 0) {
                return false;
            }
            
            const group = new L.featureGroup(this.markers);
            this.map.fitBounds(group.getBounds(), { padding: [20, 20] });
            
            console.log('🗺️ Map fitted to markers');
            return true;
            
        } catch (error) {
            console.error('❌ Error fitting map to markers:', error);
            return false;
        }
    }
    
    /**
     * Get map bounds
     */
    getBounds() {
        if (!this.isInitialized) return null;
        return this.map.getBounds();
    }
    
    /**
     * Get map center
     */
    getCenter() {
        if (!this.isInitialized) return null;
        return this.map.getCenter();
    }
    
    /**
     * Get map zoom level
     */
    getZoom() {
        if (!this.isInitialized) return null;
        return this.map.getZoom();
    }
    
    /**
     * Invalidate map size (useful for responsive layouts)
     */
    invalidateSize() {
        if (this.isInitialized) {
            setTimeout(() => {
                this.map.invalidateSize();
            }, 100);
        }
    }
    
    /**
     * Show error message
     */
    showError(message) {
        const container = document.getElementById(this.containerId);
        if (container) {
            let errorElement = container.querySelector('.map-error');
            if (!errorElement) {
                errorElement = document.createElement('div');
                errorElement.className = 'map-error';
                container.appendChild(errorElement);
            }
            errorElement.textContent = message;
            errorElement.style.display = 'block';
        }
        console.error('🗺️ Map Error:', message);
    }
    
    /**
     * Hide error message
     */
    hideError() {
        const container = document.getElementById(this.containerId);
        if (container) {
            const errorElement = container.querySelector('.map-error');
            if (errorElement) {
                errorElement.style.display = 'none';
            }
        }
    }
    
    /**
     * Destroy the map instance
     */
    destroy() {
        try {
            if (this.map) {
                this.clearMarkers();
                this.map.remove();
                this.map = null;
                this.isInitialized = false;
                console.log('🗺️ Map instance destroyed');
            }
        } catch (error) {
            console.error('❌ Error destroying map:', error);
        }
    }
    
    /**
     * Utility functions
     */
    getListingImageUrl(listing) {
        if (listing.media && listing.media.length > 0) {
            return listing.media[0].url;
        }
        return this.generatePlaceholderImage(listing.title);
    }
    
    generatePlaceholderImage(title) {
        const hash = btoa(title || 'listing').replace(/[^a-zA-Z0-9]/g, '').substring(0, 10);
        return `https://api.dicebear.com/6.x/shapes/svg?seed=${hash}&backgroundColor=e5e7eb&size=200`;
    }
    
    formatPrice(price) {
        return parseInt(price).toLocaleString();
    }
    
    getAmenities(listing) {
        const amenities = [];
        if (listing.wifi) amenities.push('WiFi');
        if (listing.parking) amenities.push('Parking');
        if (listing.kitchen) amenities.push('Kitchen');
        if (listing.laundry) amenities.push('Laundry');
        if (listing.furnished) amenities.push('Furnished');
        if (listing.pets_allowed) amenities.push('Pets OK');
        return amenities;
    }
    
    escapeHtml(text) {
        if (!text) return '';
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Global map instance for backward compatibility
let globalMapInstance = null;

/**
 * Initialize map (backward compatibility)
 */
async function initMap() {
    try {
        globalMapInstance = new MapIntegration('map');
        const success = await globalMapInstance.initialize();
        
        if (success) {
            console.log('✅ Global map initialized');
            // Trigger custom event
            document.dispatchEvent(new CustomEvent('mapInitialized', {
                detail: { mapInstance: globalMapInstance }
            }));
        }
        
        return success;
    } catch (error) {
        console.error('❌ Global map initialization failed:', error);
        return false;
    }
}

/**
 * Update map with listings (backward compatibility)
 */
async function updateMap(listings = []) {
    if (globalMapInstance) {
        return await globalMapInstance.updateWithListings(listings);
    } else {
        console.warn('⚠️ Global map instance not initialized');
        return { success: false, processed: 0, errors: 1 };
    }
}

/**
 * Geocode location (backward compatibility)
 */
async function geocodeLocation(address) {
    if (globalMapInstance) {
        return await globalMapInstance.geocodeAddress(address);
    } else {
        console.warn('⚠️ Global map instance not initialized');
        return null;
    }
}

// Export for ES6 modules
export {
    MapIntegration,
    initMap,
    updateMap,
    geocodeLocation
};

// Export to window for backward compatibility
window.MapIntegration = MapIntegration;
window.initMap = initMap;
window.updateMap = updateMap;
window.geocodeLocation = geocodeLocation;
window.globalMapInstance = () => globalMapInstance;