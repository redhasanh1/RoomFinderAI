/**
 * Map Integration Module for RoomFinderAI
 * 
 * This module provides complete map functionality including:
 * - Leaflet map initialization and configuration
 * - Geocoding functionality for addresses
 * - Map marker management and clustering
 * - Map update functions with listings data
 * - Custom popup content and styling
 * - Location-based filtering and interactions
 * - Error handling for map operations
 * 
 * Dependencies:
 * - Leaflet.js (https://unpkg.com/leaflet@1.9.4/dist/leaflet.js)
 * - Leaflet MarkerCluster (https://unpkg.com/leaflet.markercluster@1.4.1/dist/leaflet.markercluster.js)
 * 
 * Usage:
 * const mapManager = new MapIntegration('map-container-id');
 * await mapManager.initialize();
 * await mapManager.updateWithListings(listings);
 */

class MapIntegration {
    constructor(containerId, options = {}) {
        this.containerId = containerId;
        this.options = {
            defaultCenter: [43.6532, -79.3832], // Toronto coordinates
            defaultZoom: 10,
            maxZoom: 18,
            minZoom: 2,
            clusterRadius: 50,
            geocodeDelay: 200,
            geocodeRetries: 2,
            ...options
        };
        
        // Map components
        this.map = null;
        this.markers = [];
        this.markerClusterGroup = null;
        this.isInitialized = false;
        
        // Default city coordinates for fallback geocoding
        this.cityDefaults = {
            'toronto': { lat: 43.6532, lon: -79.3832 },
            'vancouver': { lat: 49.2827, lon: -123.1207 },
            'montreal': { lat: 45.5017, lon: -73.5673 },
            'calgary': { lat: 51.0447, lon: -114.0719 },
            'ottawa': { lat: 45.4215, lon: -75.6972 },
            'london': { lat: 51.5074, lon: -0.1278 },
            'new york': { lat: 40.7128, lon: -74.0060 },
            'los angeles': { lat: 34.0522, lon: -118.2437 }
        };
        
        // Bind methods to maintain context
        this.initialize = this.initialize.bind(this);
        this.updateWithListings = this.updateWithListings.bind(this);
        this.geocodeLocation = this.geocodeLocation.bind(this);
        this.clearMarkers = this.clearMarkers.bind(this);
        this.fitToMarkers = this.fitToMarkers.bind(this);
        this.destroy = this.destroy.bind(this);
    }
    
    /**
     * Initialize the map with Leaflet and marker clustering
     * @returns {Promise<boolean>} Success status
     */
    async initialize() {
        console.log('🗺️ Initializing MapIntegration...');
        
        try {
            // Check if Leaflet is available
            if (typeof L === 'undefined') {
                throw new Error('Leaflet library is not loaded');
            }
            
            // Get map container
            const mapElement = document.getElementById(this.containerId);
            if (!mapElement) {
                throw new Error(`Map container with id "${this.containerId}" not found`);
            }
            
            // Hide error message if it exists
            const mapError = document.getElementById('map-error');
            if (mapError) {
                mapError.style.display = 'none';
            }
            
            // Initialize map
            this.map = L.map(this.containerId).setView(this.options.defaultCenter, this.options.defaultZoom);
            
            // Add tile layer
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
                maxZoom: this.options.maxZoom,
                minZoom: this.options.minZoom
            }).addTo(this.map);
            
            // Initialize marker cluster group
            this.markerClusterGroup = L.markerClusterGroup({
                maxClusterRadius: this.options.clusterRadius,
                showCoverageOnHover: false,
                zoomToBoundsOnClick: true,
                spiderfyOnMaxZoom: true,
                iconCreateFunction: (cluster) => {
                    const count = cluster.getChildCount();
                    return L.divIcon({
                        html: `<div style="background-color: #3b82f6; color: white; border-radius: 50%; width: 35px; height: 35px; display: flex; align-items: center; justify-content: center; font-weight: bold; border: 2px solid white; box-shadow: 0 2px 6px rgba(0,0,0,0.3); font-size: 12px;">${count}</div>`,
                        className: 'marker-cluster',
                        iconSize: [35, 35]
                    });
                }
            });
            
            // Add cluster group to map
            this.map.addLayer(this.markerClusterGroup);
            
            // Force map to render properly
            setTimeout(() => {
                this.map.invalidateSize();
                console.log('✅ Map size invalidated and rendered');
            }, 500);
            
            this.isInitialized = true;
            console.log('✅ MapIntegration initialized successfully');
            return true;
            
        } catch (error) {
            console.error('❌ Failed to initialize MapIntegration:', error);
            this.showError('Failed to initialize map. Please check your connection or try again later.');
            return false;
        }
    }
    
    /**
     * Geocode a location string to coordinates
     * @param {string} location - Address or location string
     * @param {number} retries - Number of retry attempts
     * @returns {Promise<Object>} Coordinates object with lat, lon, and display_name
     */
    async geocodeLocation(location, retries = this.options.geocodeRetries) {
        console.log('🔍 Geocoding location:', location);
        
        try {
            const encodedQuery = encodeURIComponent(location.trim());
            console.log('Attempting to geocode:', encodedQuery);
            
            const response = await fetch(`https://nominatim.openstreetmap.org/search?q=${encodedQuery}&format=json&limit=1`, {
                headers: {
                    'User-Agent': 'RoomFinder/1.0'
                }
            });
            
            if (response.ok) {
                const data = await response.json();
                console.log('Geocode API response:', data);
                
                if (data && data.length > 0) {
                    const result = data[0];
                    const coords = {
                        lat: parseFloat(result.lat),
                        lon: parseFloat(result.lon),
                        display_name: result.display_name
                    };
                    
                    // Validate coordinates
                    if (coords.lat >= -90 && coords.lat <= 90 && coords.lon >= -180 && coords.lon <= 180) {
                        console.log('✅ Successfully geocoded:', location, '→', coords);
                        return coords;
                    }
                }
            }
        } catch (error) {
            console.error('Geocoding API error:', error);
            if (retries > 0) {
                console.log(`🔄 Retrying geocoding (${retries} attempts left)...`);
                await new Promise(resolve => setTimeout(resolve, 1000));
                return this.geocodeLocation(location, retries - 1);
            }
        }
        
        // Fallback: try to match city name with defaults
        const cityName = location.toLowerCase().split(',')[1]?.trim() || location.toLowerCase().split(',')[0]?.trim() || '';
        console.log('Trying fallback for city:', cityName);
        
        for (const [city, coords] of Object.entries(this.cityDefaults)) {
            if (cityName.includes(city) || city.includes(cityName)) {
                console.log('🔄 Using fallback coordinates for', city, ':', coords);
                return {
                    lat: coords.lat + (Math.random() - 0.5) * 0.01, // Add small random offset
                    lon: coords.lon + (Math.random() - 0.5) * 0.01,
                    display_name: `${location} (approximate)`
                };
            }
        }
        
        // Last resort: use default area with random offset
        console.log('⚠️ Using default area for:', location);
        return {
            lat: this.options.defaultCenter[0] + (Math.random() - 0.5) * 0.1,
            lon: this.options.defaultCenter[1] + (Math.random() - 0.5) * 0.1,
            display_name: `${location} (default location)`
        };
    }
    
    /**
     * Create a custom popup for a listing
     * @param {Object} listing - Listing data object
     * @returns {string} HTML string for popup content
     */
    createPopupContent(listing) {
        return `
            <div style="min-width: 200px; font-family: Arial, sans-serif;">
                <h3 style="margin: 0 0 8px 0; font-size: 16px; font-weight: bold; color: #1f2937;">${listing.title}</h3>
                <div style="color: #059669; font-weight: bold; font-size: 18px; margin-bottom: 6px;">$${listing.price.toLocaleString()}/mo</div>
                <div style="color: #6b7280; font-size: 13px; margin-bottom: 8px;">${listing.street}, ${listing.city}, ${listing.postalCode}</div>
                <div style="font-size: 12px; color: #6b7280; margin-bottom: 10px;">
                    ${listing.bedrooms} Bed • ${listing.house_type} • ${listing.utilities}
                </div>
                <a href="/listing_details?id=${listing.id}" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 6px 12px; border-radius: 4px; text-decoration: none; font-size: 12px; font-weight: 500;">View Details</a>
            </div>
        `;
    }
    
    /**
     * Update map with listings data
     * @param {Array} listings - Array of listing objects
     * @returns {Promise<Object>} Update results with success/failure counts
     */
    async updateWithListings(listings) {
        console.log('🗺️ Starting updateWithListings with', listings.length, 'listings');
        
        // Ensure map is initialized
        if (!this.isInitialized) {
            console.log('Map not initialized, initializing...');
            const success = await this.initialize();
            if (!success) {
                console.error('❌ Failed to initialize map');
                return { success: false, processed: 0, successful: 0 };
            }
            // Wait for map to be ready
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
        
        // Clear existing markers
        this.clearMarkers();
        
        const validCoordinates = [];
        let successfulMarkers = 0;
        
        console.log('Processing listings for markers...');
        
        for (let i = 0; i < listings.length; i++) {
            const listing = listings[i];
            console.log(`📍 Processing listing ${i + 1}/${listings.length}:`, listing.title);
            
            const location = `${listing.street}, ${listing.city}, ${listing.postalCode}`;
            console.log('Full address:', location);
            
            if (!listing.street || !listing.city) {
                console.warn('⚠️ Listing missing required address components:', listing);
                // Continue processing with available data
            }
            
            try {
                // Get coordinates
                const coords = await this.geocodeLocation(location);
                console.log('Got coordinates:', coords);
                
                if (coords && !isNaN(coords.lat) && !isNaN(coords.lon)) {
                    // Create marker
                    const marker = L.marker([coords.lat, coords.lon], {
                        title: listing.title
                    });
                    
                    // Create and bind popup
                    const popupContent = this.createPopupContent(listing);
                    marker.bindPopup(popupContent, { 
                        maxWidth: 250,
                        className: 'custom-popup'
                    });
                    
                    // Add to cluster group
                    this.markerClusterGroup.addLayer(marker);
                    this.markers.push(marker);
                    validCoordinates.push([coords.lat, coords.lon]);
                    successfulMarkers++;
                    
                    console.log(`✅ Added marker ${successfulMarkers} for:`, listing.title, 'at', [coords.lat, coords.lon]);
                } else {
                    console.error('❌ Invalid coordinates for:', listing.title);
                }
            } catch (error) {
                console.error('❌ Error processing listing:', listing.title, error);
            }
            
            // Small delay between geocoding requests to avoid rate limiting
            if (i < listings.length - 1) {
                await new Promise(resolve => setTimeout(resolve, this.options.geocodeDelay));
            }
        }
        
        console.log(`🎯 Map update complete! Successfully added ${successfulMarkers} markers out of ${listings.length} listings`);
        
        // Adjust map view
        this.fitToMarkers(validCoordinates);
        
        // Force map refresh
        setTimeout(() => {
            if (this.map) {
                this.map.invalidateSize();
                console.log('✅ Map refreshed and invalidated');
            }
        }, 500);
        
        // Log final state
        console.log('📊 Final map state:');
        console.log('- Total listings processed:', listings.length);
        console.log('- Successful markers:', successfulMarkers);
        console.log('- Markers in cluster group:', this.markerClusterGroup.getLayers().length);
        console.log('- Valid coordinates:', validCoordinates.length);
        
        return {
            success: true,
            processed: listings.length,
            successful: successfulMarkers,
            coordinates: validCoordinates
        };
    }
    
    /**
     * Clear all markers from the map
     */
    clearMarkers() {
        console.log('Clearing existing markers...');
        if (this.markerClusterGroup) {
            this.markerClusterGroup.clearLayers();
        }
        this.markers = [];
    }
    
    /**
     * Fit map view to markers or use default view
     * @param {Array} coordinates - Array of [lat, lng] coordinates
     */
    fitToMarkers(coordinates) {
        if (!this.map) return;
        
        if (coordinates.length > 0) {
            console.log('Setting map view for', coordinates.length, 'markers');
            
            if (coordinates.length === 1) {
                // Single marker - zoom to street level
                this.map.setView(coordinates[0], 14);
                console.log('✅ Map centered on single marker at zoom 14');
            } else {
                // Multiple markers - fit bounds
                try {
                    const bounds = L.latLngBounds(coordinates);
                    this.map.fitBounds(bounds, { 
                        padding: [20, 20],
                        maxZoom: 15
                    });
                    console.log('✅ Map fitted to bounds for', coordinates.length, 'markers');
                } catch (error) {
                    console.error('Error fitting bounds, using default view:', error);
                    this.map.setView(this.options.defaultCenter, this.options.defaultZoom);
                }
            }
        } else {
            console.log('⚠️ No markers to display, keeping default view');
            this.map.setView(this.options.defaultCenter, this.options.defaultZoom);
        }
    }
    
    /**
     * Filter markers based on criteria
     * @param {Function} filterFn - Function to filter markers
     * @returns {Array} Filtered markers
     */
    filterMarkers(filterFn) {
        if (!this.markerClusterGroup) return [];
        
        const allMarkers = this.markerClusterGroup.getLayers();
        const filteredMarkers = allMarkers.filter(filterFn);
        
        // Clear all markers and add only filtered ones
        this.markerClusterGroup.clearLayers();
        filteredMarkers.forEach(marker => {
            this.markerClusterGroup.addLayer(marker);
        });
        
        return filteredMarkers;
    }
    
    /**
     * Get all markers currently on the map
     * @returns {Array} Array of marker objects
     */
    getMarkers() {
        return this.markers;
    }
    
    /**
     * Get map bounds
     * @returns {Object} Map bounds object
     */
    getBounds() {
        if (!this.map) return null;
        return this.map.getBounds();
    }
    
    /**
     * Set map view to specific coordinates
     * @param {Array} center - [lat, lng] coordinates
     * @param {number} zoom - Zoom level
     */
    setView(center, zoom = this.options.defaultZoom) {
        if (!this.map) return;
        this.map.setView(center, zoom);
    }
    
    /**
     * Add a custom marker to the map
     * @param {Array} coordinates - [lat, lng] coordinates
     * @param {Object} options - Marker options
     * @param {string} popupContent - HTML content for popup
     * @returns {Object} Leaflet marker object
     */
    addCustomMarker(coordinates, options = {}, popupContent = '') {
        if (!this.map || !this.markerClusterGroup) return null;
        
        const marker = L.marker(coordinates, options);
        
        if (popupContent) {
            marker.bindPopup(popupContent, { 
                maxWidth: 250,
                className: 'custom-popup'
            });
        }
        
        this.markerClusterGroup.addLayer(marker);
        this.markers.push(marker);
        
        return marker;
    }
    
    /**
     * Remove a specific marker from the map
     * @param {Object} marker - Leaflet marker object
     */
    removeMarker(marker) {
        if (!this.markerClusterGroup) return;
        
        this.markerClusterGroup.removeLayer(marker);
        this.markers = this.markers.filter(m => m !== marker);
    }
    
    /**
     * Show error message
     * @param {string} message - Error message to display
     */
    showError(message) {
        console.error('Map Error:', message);
        const mapError = document.getElementById('map-error');
        if (mapError) {
            mapError.textContent = message;
            mapError.style.display = 'block';
        }
    }
    
    /**
     * Hide error message
     */
    hideError() {
        const mapError = document.getElementById('map-error');
        if (mapError) {
            mapError.style.display = 'none';
        }
    }
    
    /**
     * Refresh the map display
     */
    refresh() {
        if (this.map) {
            this.map.invalidateSize();
            console.log('🔄 Map refreshed');
        }
    }
    
    /**
     * Destroy the map instance and clean up resources
     */
    destroy() {
        console.log('🗑️ Destroying MapIntegration...');
        
        if (this.map) {
            this.map.remove();
            this.map = null;
        }
        
        this.markers = [];
        this.markerClusterGroup = null;
        this.isInitialized = false;
        
        console.log('✅ MapIntegration destroyed');
    }
    
    /**
     * Get the current map instance
     * @returns {Object} Leaflet map object
     */
    getMap() {
        return this.map;
    }
    
    /**
     * Check if the map is initialized
     * @returns {boolean} Initialization status
     */
    isMapInitialized() {
        return this.isInitialized;
    }
    
    /**
     * Update map options
     * @param {Object} newOptions - New options to merge
     */
    updateOptions(newOptions) {
        this.options = { ...this.options, ...newOptions };
        console.log('🔧 Map options updated:', this.options);
    }
    
    /**
     * Get current map options
     * @returns {Object} Current options
     */
    getOptions() {
        return { ...this.options };
    }
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = MapIntegration;
}

// Global export for browser usage
if (typeof window !== 'undefined') {
    window.MapIntegration = MapIntegration;
}

// Default export for ES6 modules
export default MapIntegration;