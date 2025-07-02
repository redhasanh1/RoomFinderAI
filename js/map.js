// Map functionality module
window.MapManager = (function() {
    let map;
    let markers = [];
    let markerClusterGroup;

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

    // Initialize the map
    function initMap() {
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
            map = L.map('map').setView([43.6532, -79.3832], 10);
            
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
            console.log('Map initialized successfully with clustering at Toronto view');
            return true;
        } catch (error) {
            console.error('Failed to initialize map:', error);
            if (mapError) mapError.style.display = 'block';
            return false;
        }
    }

    // Geocode location with fallback coordinates
    async function geocodeLocation(location, retries = 2, delay = 1000) {
        console.log('Geocoding location:', location);
        
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
            console.error('Geocoding error:', error);
        }

        // Try city fallbacks
        const lowerLocation = location.toLowerCase();
        for (const [city, coords] of Object.entries(cityDefaults)) {
            if (lowerLocation.includes(city)) {
                console.log(`🎯 Using fallback coordinates for ${city}:`, coords);
                // Add small random offset to prevent exact overlap
                return {
                    lat: coords.lat + (Math.random() - 0.5) * 0.01,
                    lon: coords.lon + (Math.random() - 0.5) * 0.01,
                    display_name: location
                };
            }
        }

        // Retry if attempts remaining
        if (retries > 0) {
            console.log(`Retrying geocoding in ${delay}ms... (${retries} attempts left)`);
            await new Promise(resolve => setTimeout(resolve, delay));
            return geocodeLocation(location, retries - 1, delay);
        }

        // Final fallback to Toronto with random offset
        console.log('⚠️ Using default Toronto coordinates for:', location);
        return {
            lat: 43.6532 + (Math.random() - 0.5) * 0.1,
            lon: -79.3832 + (Math.random() - 0.5) * 0.1,
            display_name: location
        };
    }

    // Update map with listings
    async function updateMap(listings) {
        console.log('🗺️ Starting map update with', listings.length, 'listings');
        
        if (!map || !markerClusterGroup) {
            console.error('Map not initialized');
            return;
        }

        // Clear existing markers
        markerClusterGroup.clearLayers();
        markers = [];

        if (listings.length === 0) {
            console.log('No listings to display on map');
            return;
        }

        const bounds = [];

        // Process each listing
        for (let i = 0; i < listings.length; i++) {
            const listing = listings[i];
            const address = `${listing.street || ''}, ${listing.city || ''}, ${listing.postalCode || ''}`.trim();
            
            console.log(`📍 Processing listing ${i + 1}/${listings.length}: ${listing.title} at ${address}`);

            try {
                const location = await geocodeLocation(address);
                
                if (location && location.lat && location.lon) {
                    const marker = L.marker([location.lat, location.lon]);
                    
                    // Create popup content
                    const popupContent = `
                        <div style="width: 200px; padding: 5px;">
                            <h3 style="margin: 0 0 8px 0; font-size: 14px; font-weight: bold; color: #1f2937;">${listing.title || 'Property'}</h3>
                            <p style="margin: 0 0 4px 0; font-size: 16px; font-weight: bold; color: #3b82f6;">$${listing.price || 'N/A'}/month</p>
                            <p style="margin: 0 0 4px 0; font-size: 12px; color: #6b7280;">${address}</p>
                            <p style="margin: 0 0 8px 0; font-size: 12px; color: #6b7280;">${listing.bedrooms || 'N/A'} bed • ${listing.house_type || 'Property'}</p>
                            <button onclick="window.ListingsManager?.showListingModal(${JSON.stringify(listing).replace(/"/g, '&quot;')})" 
                                    style="background: #3b82f6; color: white; border: none; padding: 4px 8px; border-radius: 4px; font-size: 11px; cursor: pointer;">
                                View Details
                            </button>
                        </div>
                    `;
                    
                    marker.bindPopup(popupContent, { 
                        maxWidth: 250,
                        className: 'custom-popup'
                    });
                    
                    // Add click handler for conversations
                    marker.on('click', function() {
                        // Store listing data for potential conversation initiation
                        marker._listingData = listing;
                    });
                    
                    markerClusterGroup.addLayer(marker);
                    markers.push(marker);
                    bounds.push([location.lat, location.lon]);
                    
                    console.log(`✅ Added marker for ${listing.title} at [${location.lat}, ${location.lon}]`);
                } else {
                    console.log(`⚠️ Could not geocode address for listing: ${listing.title}`);
                }
            } catch (error) {
                console.error(`❌ Error processing listing ${listing.title}:`, error);
            }
        }

        // Adjust map view based on markers
        if (bounds.length > 0) {
            if (bounds.length === 1) {
                map.setView(bounds[0], 15);
                console.log('📍 Centered map on single marker');
            } else {
                const latLngBounds = L.latLngBounds(bounds);
                map.fitBounds(latLngBounds, { 
                    padding: [20, 20],
                    maxZoom: 15
                });
                console.log('🗺️ Fitted map to show all markers');
            }
        }

        // Force map refresh
        setTimeout(() => {
            if (map) {
                map.invalidateSize();
                console.log('🔄 Map view refreshed');
            }
        }, 100);

        console.log(`✅ Map update completed. ${markers.length} markers added.`);
    }

    // Update map with listings (alias for backward compatibility)
    function updateWithListings(listings) {
        return updateMap(listings);
    }

    // Start conversation from map marker
    function startConversationFromMap(listingJson) {
        try {
            const listing = JSON.parse(listingJson);
            if (window.ChatManager && listing.user_email) {
                window.ChatManager.startConversation(listing.user_email, listing.title);
            }
        } catch (error) {
            console.error('Error starting conversation from map:', error);
            window.Utils?.showError('Could not start conversation');
        }
    }

    // Get map bounds for filtering
    function getMapBounds() {
        if (!map) return null;
        
        const bounds = map.getBounds();
        return {
            north: bounds.getNorth(),
            south: bounds.getSouth(),
            east: bounds.getEast(),
            west: bounds.getWest()
        };
    }

    // Center map on specific coordinates
    function centerMap(lat, lon, zoom = 15) {
        if (!map) return;
        
        map.setView([lat, lon], zoom);
        console.log(`Map centered on [${lat}, ${lon}] with zoom ${zoom}`);
    }

    // Resize map (useful when container size changes)
    function resizeMap() {
        if (map) {
            map.invalidateSize();
            console.log('Map resized');
        }
    }

    // Get current map instance
    function getMapInstance() {
        return map;
    }

    // Initialize map functionality
    function initialize() {
        // Initialize map on page load
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', initMap);
        } else {
            initMap();
        }
    }

    // Public API
    return {
        initialize,
        initMap,
        geocodeLocation,
        updateMap,
        updateWithListings,
        startConversationFromMap,
        getMapBounds,
        centerMap,
        resizeMap,
        getMapInstance,
        get markers() { return markers; }
    };
})();