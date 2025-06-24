// Map Manager - Handles all map-related functionality
class MapManager {
    constructor() {
        this.map = null;
        this.markers = [];
        this.markerClusterGroup = null;
        this.isInitialized = false;
    }

    // Initialize Map with Retry Logic
    async initMap() {
        console.log('Attempting to initialize map');
        const mapElement = document.getElementById('map');
        const mapError = document.getElementById('map-error');

        if (!mapElement) {
            console.error('Map container not found');
            if (mapError) mapError.style.display = 'block';
            return false;
        }

        try {
            // Set default view to Toronto area for better initial positioning
            this.map = L.map('map').setView([43.6532, -79.3832], 10);
            
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
                maxZoom: 18,
                minZoom: 2
            }).addTo(this.map);

            // Initialize marker cluster group with simpler settings
            this.markerClusterGroup = L.markerClusterGroup({
                maxClusterRadius: 50,
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
            this.map.addLayer(this.markerClusterGroup);

            // Force map to render properly
            setTimeout(() => {
                this.map.invalidateSize();
                console.log('Map size invalidated and rendered');
            }, 500);

            if (mapError) mapError.style.display = 'none';
            console.log('Map initialized successfully with clustering at Toronto view');
            this.isInitialized = true;
            return true;
        } catch (error) {
            console.error('Failed to initialize map:', error);
            if (mapError) mapError.style.display = 'block';
            return false;
        }
    }

    // Simple and reliable geocoding with fallback coordinates
    async geocodeLocation(location, retries = 2, delay = 1000) {
        console.log('Geocoding location:', location);
        
        // Default coordinates for common cities if geocoding fails
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
        }
        
        // Fallback: try to match city name with defaults
        const cityName = location.toLowerCase().split(',')[1]?.trim() || location.toLowerCase().split(',')[0]?.trim() || '';
        console.log('Trying fallback for city:', cityName);
        
        for (const [city, coords] of Object.entries(cityDefaults)) {
            if (cityName.includes(city) || city.includes(cityName)) {
                console.log('🔄 Using fallback coordinates for', city, ':', coords);
                return {
                    lat: coords.lat + (Math.random() - 0.5) * 0.01, // Add small random offset
                    lon: coords.lon + (Math.random() - 0.5) * 0.01,
                    display_name: location + ' (approximate)'
                };
            }
        }
        
        // Last resort: use Toronto area with random offset
        console.log('⚠️ Using default Toronto area for:', location);
        return {
            lat: 43.6532 + (Math.random() - 0.5) * 0.1,
            lon: -79.3832 + (Math.random() - 0.5) * 0.1,
            display_name: location + ' (default location)'
        };
    }

    // Update Map with Listings
    async updateMap(listings) {
        console.log('🗺️ Starting updateMap with', listings.length, 'listings');
        
        // Ensure map is initialized
        if (!this.map || !this.markerClusterGroup) {
            console.log('Map not ready, initializing...');
            if (!await this.initMap()) {
                console.error('❌ Failed to initialize map');
                return;
            }
            // Wait for map to be ready
            await new Promise(resolve => setTimeout(resolve, 1000));
        }

        // Clear existing markers
        console.log('Clearing existing markers...');
        this.markerClusterGroup.clearLayers();
        this.markers = [];
        const validCoordinates = [];
        let successfulMarkers = 0;

        console.log('Processing listings for markers...');
        
        for (let i = 0; i < listings.length; i++) {
            const listing = listings[i];
            console.log(`\n📍 Processing listing ${i + 1}/${listings.length}:`, listing.title);
            
            const location = `${listing.street}, ${listing.city}, ${listing.postalCode}`;
            console.log('Full address:', location);
            
            if (!listing.street || !listing.city) {
                console.warn('⚠️ Listing missing required address components:', listing);
            }

            try {
                // Get coordinates (this function now always returns coordinates)
                const coords = await this.geocodeLocation(location);
                console.log('Got coordinates:', coords);

                if (coords && !isNaN(coords.lat) && !isNaN(coords.lon)) {
                    // Create simple, reliable marker
                    const marker = L.marker([coords.lat, coords.lon], {
                        title: listing.title
                    });

                    // Create simple popup
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
                    
                    // Add to cluster group
                    this.markerClusterGroup.addLayer(marker);
                    this.markers.push(marker);
                    validCoordinates.push([coords.lat, coords.lon]);
                    successfulMarkers++;
                    
                    console.log('✅ Added marker', successfulMarkers, 'for:', listing.title, 'at', [coords.lat, coords.lon]);
                } else {
                    console.error('❌ Invalid coordinates for:', listing.title);
                }
            } catch (error) {
                console.error('❌ Error processing listing:', listing.title, error);
            }

            // Small delay between geocoding requests
            if (i < listings.length - 1) {
                await new Promise(resolve => setTimeout(resolve, 200));
            }
        }

        console.log(`\n🎯 Map update complete! Successfully added ${successfulMarkers} markers out of ${listings.length} listings`);

        // Adjust map view - simplified and reliable
        if (validCoordinates.length > 0) {
            console.log('Setting map view for', validCoordinates.length, 'markers');
            
            if (validCoordinates.length === 1) {
                // Single marker - zoom to street level
                this.map.setView(validCoordinates[0], 14);
                console.log('✅ Map centered on single marker at zoom 14');
            } else {
                // Multiple markers - fit bounds
                try {
                    const bounds = L.latLngBounds(validCoordinates);
                    this.map.fitBounds(bounds, { 
                        padding: [20, 20],
                        maxZoom: 15
                    });
                    console.log('✅ Map fitted to bounds for', validCoordinates.length, 'markers');
                } catch (error) {
                    console.error('Error fitting bounds, using default view:', error);
                    this.map.setView([43.6532, -79.3832], 10);
                }
            }
        } else {
            console.log('⚠️ No markers to display, keeping default view');
            this.map.setView([43.6532, -79.3832], 10);
        }

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
    }

    // Function to center map on user's current location
    async centerMapOnUser() {
        console.log('📍 Trying to center map on user location...');
        
        if (!navigator.geolocation) {
            alert('Geolocation is not supported by this browser.');
            return;
        }

        navigator.geolocation.getCurrentPosition(
            (position) => {
                const lat = position.coords.latitude;
                const lon = position.coords.longitude;
                console.log('✅ Got user location:', lat, lon);
                
                if (this.map) {
                    this.map.setView([lat, lon], 14);
                    
                    // Add a marker for user location
                    const userMarker = L.marker([lat, lon], {
                        icon: L.divIcon({
                            html: `<div style="background-color: #ef4444; color: white; border-radius: 50%; width: 20px; height: 20px; display: flex; align-items: center; justify-content: center; font-weight: bold; border: 2px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3);">📍</div>`,
                            className: 'user-location-marker',
                            iconSize: [20, 20]
                        })
                    }).addTo(this.map);
                    
                    userMarker.bindPopup('Your Current Location').openPopup();
                    console.log('✅ Map centered on user location');
                }
            },
            (error) => {
                console.error('❌ Error getting user location:', error);
                switch(error.code) {
                    case error.PERMISSION_DENIED:
                        alert('Location access denied by user.');
                        break;
                    case error.POSITION_UNAVAILABLE:
                        alert('Location information is unavailable.');
                        break;
                    case error.TIMEOUT:
                        alert('Location request timed out.');
                        break;
                    default:
                        alert('An unknown error occurred while retrieving location.');
                        break;
                }
            },
            {
                enableHighAccuracy: true,
                timeout: 10000,
                maximumAge: 300000 // 5 minutes
            }
        );
    }

    // Refresh map only
    async refreshMapOnly(currentListings = []) {
        console.log('🔄 Refreshing map only...');
        
        if (currentListings.length === 0) {
            // Get current listings from the page if not provided
            const listingCards = document.querySelectorAll('.listing-card');
            listingCards.forEach(card => {
                const button = card.querySelector('.view-details-btn');
                if (button && button.dataset.listing) {
                    try {
                        const listing = JSON.parse(button.dataset.listing);
                        currentListings.push(listing);
                    } catch (e) {
                        console.warn('Failed to parse listing data:', e);
                    }
                }
            });
        }
        
        console.log('Found', currentListings.length, 'listings for map refresh');
        
        if (currentListings.length > 0) {
            await this.updateMap(currentListings);
            console.log('✅ Map refreshed with existing listings');
        } else {
            console.log('⚠️ No listings found for map refresh');
        }
    }
}

// Export for global use
window.MapManager = MapManager;