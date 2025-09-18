/**
 * Map Utilities Module
 * Utility functions for map operations, geocoding, and location services
 */

class MapUtils {
    constructor() {
        this.cityDefaults = {
            'toronto': { lat: 43.6532, lon: -79.3832 },
            'vancouver': { lat: 49.2827, lon: -123.1207 },
            'montreal': { lat: 45.5017, lon: -73.5673 },
            'calgary': { lat: 51.0447, lon: -114.0719 },
            'ottawa': { lat: 45.4215, lon: -75.6972 },
            'london': { lat: 51.5074, lon: -0.1278 },
            'new york': { lat: 40.7128, lon: -74.0060 },
            'los angeles': { lat: 34.0522, lon: -118.2437 },
            'chicago': { lat: 41.8781, lon: -87.6298 },
            'miami': { lat: 25.7617, lon: -80.1918 },
            'seattle': { lat: 47.6062, lon: -122.3321 },
            'boston': { lat: 42.3601, lon: -71.0589 },
            'san francisco': { lat: 37.7749, lon: -122.4194 },
            'washington': { lat: 38.9072, lon: -77.0369 },
            'atlanta': { lat: 33.7490, lon: -84.3880 },
            'denver': { lat: 39.7392, lon: -104.9903 },
            'indianapolis': { lat: 39.7684, lon: -86.1581 }
        };
        this.geocodeCache = new Map();
        this.rateLimitDelay = 200; // ms between requests
    }

    /**
     * Simple and reliable geocoding with fallback coordinates
     */
    async geocodeLocation(location, retries = 2, delay = 1000) {
        console.log('Geocoding location:', location);

        // Check cache first
        const cacheKey = location.toLowerCase().trim();
        if (this.geocodeCache.has(cacheKey)) {
            console.log('Using cached coordinates for:', location);
            return this.geocodeCache.get(cacheKey);
        }

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
                    if (this.validateCoordinates(coords)) {
                        console.log('✅ Successfully geocoded:', location, '→', coords);
                        // Cache the result
                        this.geocodeCache.set(cacheKey, coords);
                        return coords;
                    }
                }
            }
        } catch (error) {
            console.error('Geocoding API error:', error);
        }

        // Fallback: try to match city name with defaults
        const fallbackCoords = this.getFallbackCoordinates(location);
        if (fallbackCoords) {
            // Cache the fallback result
            this.geocodeCache.set(cacheKey, fallbackCoords);
            return fallbackCoords;
        }

        // Last resort: use Toronto area with random offset
        const defaultCoords = this.getDefaultCoordinates(location);
        this.geocodeCache.set(cacheKey, defaultCoords);
        return defaultCoords;
    }

    /**
     * Validate coordinates are within valid ranges
     */
    validateCoordinates(coords) {
        return coords.lat >= -90 && coords.lat <= 90 &&
               coords.lon >= -180 && coords.lon <= 180;
    }

    /**
     * Get fallback coordinates for known cities
     */
    getFallbackCoordinates(location) {
        const cityName = location.toLowerCase().split(',')[1]?.trim() ||
                        location.toLowerCase().split(',')[0]?.trim() || '';
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

        return null;
    }

    /**
     * Get default coordinates (Toronto area)
     */
    getDefaultCoordinates(location) {
        console.log('⚠️ Using default Toronto area for:', location);
        return {
            lat: 43.6532 + (Math.random() - 0.5) * 0.1,
            lon: -79.3832 + (Math.random() - 0.5) * 0.1,
            display_name: `${location} (default location)`
        };
    }

    /**
     * Batch geocode multiple locations with rate limiting
     */
    async batchGeocode(locations, progressCallback = null) {
        const results = [];

        for (let i = 0; i < locations.length; i++) {
            const location = locations[i];

            try {
                const coords = await this.geocodeLocation(location);
                results.push({ location, coords, success: true });

                if (progressCallback) {
                    progressCallback(i + 1, locations.length, location, coords);
                }
            } catch (error) {
                console.error('Error geocoding:', location, error);
                results.push({ location, coords: null, success: false, error });
            }

            // Rate limiting delay
            if (i < locations.length - 1) {
                await new Promise(resolve => setTimeout(resolve, this.rateLimitDelay));
            }
        }

        return results;
    }

    /**
     * Calculate distance between two coordinates (in km)
     */
    calculateDistance(lat1, lon1, lat2, lon2) {
        const R = 6371; // Radius of the Earth in km
        const dLat = this.deg2rad(lat2 - lat1);
        const dLon = this.deg2rad(lon2 - lon1);
        const a =
            Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(this.deg2rad(lat1)) * Math.cos(this.deg2rad(lat2)) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        const d = R * c; // Distance in km
        return d;
    }

    /**
     * Convert degrees to radians
     */
    deg2rad(deg) {
        return deg * (Math.PI/180);
    }

    /**
     * Get bounds for a set of coordinates
     */
    getBounds(coordinates) {
        if (!coordinates || coordinates.length === 0) {
            return null;
        }

        let minLat = coordinates[0][0];
        let maxLat = coordinates[0][0];
        let minLon = coordinates[0][1];
        let maxLon = coordinates[0][1];

        coordinates.forEach(coord => {
            minLat = Math.min(minLat, coord[0]);
            maxLat = Math.max(maxLat, coord[0]);
            minLon = Math.min(minLon, coord[1]);
            maxLon = Math.max(maxLon, coord[1]);
        });

        return {
            southwest: [minLat, minLon],
            northeast: [maxLat, maxLon]
        };
    }

    /**
     * Find closest location to given coordinates
     */
    findClosestLocation(targetLat, targetLon, locations) {
        if (!locations || locations.length === 0) {
            return null;
        }

        let closest = null;
        let minDistance = Infinity;

        locations.forEach(location => {
            if (location.coordinates) {
                const distance = this.calculateDistance(
                    targetLat, targetLon,
                    location.coordinates.lat, location.coordinates.lon
                );

                if (distance < minDistance) {
                    minDistance = distance;
                    closest = { ...location, distance };
                }
            }
        });

        return closest;
    }

    /**
     * Check if coordinates are within a bounding box
     */
    isWithinBounds(lat, lon, bounds) {
        return lat >= bounds.southwest[0] && lat <= bounds.northeast[0] &&
               lon >= bounds.southwest[1] && lon <= bounds.northeast[1];
    }

    /**
     * Format coordinates for display
     */
    formatCoordinates(lat, lon, precision = 4) {
        return {
            lat: parseFloat(lat.toFixed(precision)),
            lon: parseFloat(lon.toFixed(precision)),
            display: `${lat.toFixed(precision)}, ${lon.toFixed(precision)}`
        };
    }

    /**
     * Clear geocoding cache
     */
    clearCache() {
        this.geocodeCache.clear();
        console.log('Geocoding cache cleared');
    }

    /**
     * Get cache size
     */
    getCacheSize() {
        return this.geocodeCache.size;
    }

    /**
     * Get cached locations
     */
    getCachedLocations() {
        return Array.from(this.geocodeCache.keys());
    }

    /**
     * Export cache for debugging
     */
    exportCache() {
        const cacheData = {};
        this.geocodeCache.forEach((value, key) => {
            cacheData[key] = value;
        });
        return cacheData;
    }

    /**
     * Import cache data
     */
    importCache(cacheData) {
        Object.entries(cacheData).forEach(([key, value]) => {
            this.geocodeCache.set(key, value);
        });
        console.log(`Imported ${Object.keys(cacheData).length} cached locations`);
    }
}

// Create global instance
window.mapUtils = new MapUtils();

export default window.mapUtils;