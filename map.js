let map;
let markers = [];

function initMap() {
    console.log('Initializing Leaflet map');
    const mapElement = document.getElementById('map');
    if (!mapElement) {
        console.error('Map element not found');
        showMapError('Map container not found. Please check the HTML.');
        return;
    }

    try {
        // Initialize map with a global view
        map = L.map('map').setView([0, 0], 2); // Center on equator, zoom level 2 for global view
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
            maxZoom: 18,
            minZoom: 2
        }).addTo(map);

        // Ensure map renders correctly
        setTimeout(() => {
            map.invalidateSize();
            console.log('Map size invalidated for proper rendering');
        }, 100);
    } catch (error) {
        console.error('Failed to initialize map:', error);
        showMapError('Failed to load map. Please check your connection or try again later.');
    }
}

async function geocodeLocation(street, city, postalCode, retries = 3, delay = 1000) {
    console.log('Geocoding address:', { street, city, postalCode });
    for (let attempt = 1; attempt <= retries; attempt++) {
        try {
            const queryParts = [];
            if (street) queryParts.push(street);
            if (city) queryParts.push(city);
            if (postalCode) queryParts.push(postalCode);
            const query = encodeURIComponent(queryParts.join(', '));
            console.log(`Geocoding query (attempt ${attempt}):`, query);

            const response = await fetch(`https://nominatim.openstreetmap.org/search?q=${query}&format=json&limit=1`, {
                headers: {
                    'User-Agent': 'RoomFinder/1.0 (contact: support@roomfinder.com)'
                }
            });

            if (!response.ok) {
                throw new Error(`Geocoding request failed with status ${response.status}`);
            }

            const data = await response.json();
            console.log('Geocode response for', query, ':', data);

            if (data && data.length > 0) {
                const coords = {
                    lat: parseFloat(data[0].lat),
                    lon: parseFloat(data[0].lon)
                };
                console.log('Geocoded coordinates:', coords);
                return coords;
            }
            console.warn(`No coordinates found for address (attempt ${attempt}):`, query);
        } catch (error) {
            console.error(`Error geocoding address (attempt ${attempt}):`, query, error);
        }

        if (attempt < retries) {
            console.log(`Retrying geocode after ${delay}ms`);
            await new Promise(resolve => setTimeout(resolve, delay));
        }
    }
    console.error('Geocoding failed after all retries:', street, city, postalCode);
    return null;
}

async function updateMap(listings) {
    console.log('Updating map with listings:', listings.length);

    // Clear existing markers
    markers.forEach(marker => map.removeLayer(marker));
    markers = [];

    const validCoordinates = [];
    let geocodeRequests = 0;

    for (const listing of listings) {
        if (!listing.street || !listing.city || !listing.postalCode) {
            console.warn('Listing missing address components:', listing);
            continue;
        }

        // Rate limit geocoding requests
        if (geocodeRequests > 0) {
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
        geocodeRequests++;

        const coords = await geocodeLocation(listing.street, listing.city, listing.postalCode);
        if (coords && !isNaN(coords.lat) && !isNaN(coords.lon)) {
            const marker = L.marker([coords.lat, coords.lon], {
                title: listing.title
            })
                .addTo(map)
                .bindPopup(`
                    <b>${listing.title}</b><br>
                    $${listing.price.toLocaleString()}/mo<br>
                    ${listing.street}, ${listing.city}, ${listing.postalCode}<br>
                    <a href="/listing_details?id=${listing.id}" class="text-blue-600 hover:underline">View Details</a>
                `);
            markers.push(marker);
            validCoordinates.push([coords.lat, coords.lon]);
            console.log('Added marker for', `${listing.street}, ${listing.city}, ${listing.postalCode}`, 'at', coords);
        } else {
            console.warn('Failed to geocode listing:', listing.title, listing.street, listing.city, listing.postalCode);
        }
    }

    // Adjust map view to show all markers
    if (validCoordinates.length > 0) {
        const bounds = L.latLngBounds(validCoordinates);
        map.fitBounds(bounds, { padding: [50, 50], maxZoom: 15 });
        console.log('Map zoomed to bounds:', validCoordinates);
    } else {
        console.log('No valid coordinates, setting to global view');
        map.setView([0, 0], 2); // Global view
    }

    // Ensure map renders correctly after adding markers
    setTimeout(() => {
        map.invalidateSize();
        console.log('Map size invalidated after update');
    }, 100);

    console.log('Map updated with', markers.length, 'markers');
}

// Helper function to show map error message
function showMapError(message) {
    const errorElement = document.getElementById('map-error');
    if (errorElement) {
        errorElement.textContent = message;
        errorElement.style.display = 'block';
    }
    const mapElement = document.getElementById('map');
    if (mapElement) {
        mapElement.style.display = 'none';
    }
}

export { initMap, updateMap };