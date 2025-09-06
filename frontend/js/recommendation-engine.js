// Property Recommendation Engine
class RecommendationEngine {
    constructor(supabase) {
        this.supabase = supabase;
        this.userProfile = null;
        this.viewHistory = [];
        this.searchHistory = [];
        this.savedProperties = [];
        
        // Machine learning weights
        this.weights = {
            location: 0.3,
            price: 0.25,
            size: 0.2,
            type: 0.15,
            recency: 0.1
        };
        
        console.log('🤖 Recommendation Engine initialized');
    }

    // Initialize with user data
    async init(user) {
        this.userProfile = user;
        await this.loadUserData();
        console.log('✅ Recommendation engine ready for user:', user.email);
    }

    // Load user behavior data
    async loadUserData() {
        // Load from localStorage and IndexedDB
        this.viewHistory = JSON.parse(null || '[]');
        this.searchHistory = JSON.parse(null || '[]');
        this.savedProperties = JSON.parse(null || '[]');
        
        // Load additional data from cache if available
        if (window.offlineCacheManager) {
            const cachedProfile = await window.offlineCacheManager.getUserData('userBehaviorProfile');
            if (cachedProfile) {
                this.mergeUserProfile(cachedProfile);
            }
        }
    }

    // Record user interaction
    async recordInteraction(type, data) {
        const interaction = {
            type: type,
            data: data,
            timestamp: new Date().toISOString(),
            location: await this.getCurrentLocation()
        };
        
        switch (type) {
            case 'view':
                this.recordView(data);
                break;
            case 'search':
                this.recordSearch(data);
                break;
            case 'save':
                this.recordSave(data);
                break;
            case 'contact':
                this.recordContact(data);
                break;
            case 'visit':
                this.recordVisit(data);
                break;
        }
        
        // Update user profile
        this.updateUserProfile();
        
        console.log('📊 Recorded interaction:', type, data);
    }

    // Record property view
    recordView(propertyData) {
        this.viewHistory.unshift({
            propertyId: propertyData.id,
            title: propertyData.title,
            price: propertyData.price,
            location: propertyData.city,
            type: propertyData.house_type,
            bedrooms: propertyData.bedrooms,
            timestamp: new Date().toISOString(),
            viewDuration: propertyData.viewDuration || 0
        });
        
        // Keep only last 100 views
        if (this.viewHistory.length > 100) {
            this.viewHistory = this.viewHistory.slice(0, 100);
        }
        
        // localStorage removed - using Supabase);
    }

    // Record search query
    recordSearch(searchData) {
        this.searchHistory.unshift({
            query: searchData.query || '',
            location: searchData.location || '',
            maxPrice: searchData.maxPrice || null,
            minPrice: searchData.minPrice || null,
            bedrooms: searchData.bedrooms || null,
            houseType: searchData.houseType || '',
            resultCount: searchData.resultCount || 0,
            timestamp: new Date().toISOString()
        });
        
        // Keep only last 50 searches
        if (this.searchHistory.length > 50) {
            this.searchHistory = this.searchHistory.slice(0, 50);
        }
        
        // localStorage removed - using Supabase);
    }

    // Record property save
    recordSave(propertyId) {
        if (!this.savedProperties.includes(propertyId)) {
            this.savedProperties.push(propertyId);
            // localStorage removed - using Supabase);
        }
    }

    // Record agent contact
    recordContact(data) {
        // Could be expanded to track communication patterns
        console.log('📞 Contact recorded:', data);
    }

    // Record property visit
    recordVisit(data) {
        // Integration with property visit tracker
        console.log('🏠 Visit recorded:', data);
    }

    // Generate personalized recommendations
    async generateRecommendations(limit = 10) {
        console.log('🔮 Generating personalized recommendations...');
        
        try {
            // Check if Supabase client is available
            if (!this.supabase || typeof this.supabase.from !== 'function') {
                console.warn('Supabase client not available, skipping recommendations');
                return [];
            }
            
            // Get all available properties
            const { data: allProperties, error } = await this.supabase
                .from('listings')
                .select('*')
                .order('created_at', { ascending: false })
                .limit(200); // Limit to recent properties for performance
            
            if (error) throw error;
            
            // Filter out already saved properties
            const unsavedProperties = allProperties.filter(
                property => !this.savedProperties.includes(property.id)
            );
            
            // Score each property
            const scoredProperties = unsavedProperties.map(property => ({
                ...property,
                score: this.calculatePropertyScore(property)
            }));
            
            // Sort by score and return top recommendations
            const recommendations = scoredProperties
                .sort((a, b) => b.score - a.score)
                .slice(0, limit)
                .map(property => ({
                    ...property,
                    reason: this.generateRecommendationReason(property)
                }));
            
            console.log(`✨ Generated ${recommendations.length} recommendations`);
            return recommendations;
            
        } catch (error) {
            console.error('Failed to generate recommendations:', error);
            return [];
        }
    }

    // Calculate property recommendation score
    calculatePropertyScore(property) {
        let score = 0;
        
        // Location preference score
        score += this.calculateLocationScore(property) * this.weights.location;
        
        // Price preference score
        score += this.calculatePriceScore(property) * this.weights.price;
        
        // Size preference score
        score += this.calculateSizeScore(property) * this.weights.size;
        
        // Type preference score
        score += this.calculateTypeScore(property) * this.weights.type;
        
        // Recency bonus
        score += this.calculateRecencyScore(property) * this.weights.recency;
        
        return Math.round(score * 100) / 100; // Round to 2 decimal places
    }

    // Calculate location preference score
    calculateLocationScore(property) {
        const locationPreferences = this.getLocationPreferences();
        const propertyLocation = property.city.toLowerCase();
        
        // Check if property is in preferred locations
        for (const [location, frequency] of Object.entries(locationPreferences)) {
            if (propertyLocation.includes(location.toLowerCase())) {
                return Math.min(frequency / 10, 1); // Normalize to 0-1
            }
        }
        
        return 0.1; // Base score for non-preferred locations
    }

    // Calculate price preference score
    calculatePriceScore(property) {
        const pricePreferences = this.getPricePreferences();
        
        if (!pricePreferences.min || !pricePreferences.max) {
            return 0.5; // Neutral score if no price history
        }
        
        const propertyPrice = property.price;
        const preferredMin = pricePreferences.min;
        const preferredMax = pricePreferences.max;
        const preferredRange = preferredMax - preferredMin;
        
        if (propertyPrice >= preferredMin && propertyPrice <= preferredMax) {
            return 1; // Perfect match
        } else if (propertyPrice < preferredMin) {
            // Below range - still good but not perfect
            const distance = preferredMin - propertyPrice;
            return Math.max(0.5, 1 - (distance / preferredRange));
        } else {
            // Above range - penalize more heavily
            const distance = propertyPrice - preferredMax;
            return Math.max(0.1, 0.5 - (distance / preferredRange));
        }
    }

    // Calculate size preference score
    calculateSizeScore(property) {
        const sizePreferences = this.getSizePreferences();
        const propertyBedrooms = property.bedrooms;
        
        if (sizePreferences[propertyBedrooms]) {
            return sizePreferences[propertyBedrooms] / 10; // Normalize
        }
        
        // Penalize properties that are too different from preferences
        const preferredSizes = Object.keys(sizePreferences).map(Number);
        if (preferredSizes.length === 0) return 0.5;
        
        const closest = preferredSizes.reduce((prev, curr) => 
            Math.abs(curr - propertyBedrooms) < Math.abs(prev - propertyBedrooms) ? curr : prev
        );
        
        const difference = Math.abs(closest - propertyBedrooms);
        return Math.max(0.1, 1 - (difference * 0.2));
    }

    // Calculate property type preference score
    calculateTypeScore(property) {
        const typePreferences = this.getTypePreferences();
        const propertyType = property.house_type;
        
        if (typePreferences[propertyType]) {
            return typePreferences[propertyType] / 10; // Normalize
        }
        
        return 0.3; // Base score for non-preferred types
    }

    // Calculate recency bonus
    calculateRecencyScore(property) {
        const daysSinceCreated = (Date.now() - new Date(property.created_at).getTime()) / (1000 * 60 * 60 * 24);
        
        if (daysSinceCreated <= 1) return 1; // New today
        if (daysSinceCreated <= 7) return 0.8; // This week
        if (daysSinceCreated <= 30) return 0.5; // This month
        return 0.2; // Older
    }

    // Get location preferences from history
    getLocationPreferences() {
        const locations = {};
        
        // Analyze search history
        this.searchHistory.forEach(search => {
            if (search.location) {
                const location = search.location.toLowerCase();
                locations[location] = (locations[location] || 0) + 2; // Searches are weighted higher
            }
        });
        
        // Analyze view history
        this.viewHistory.forEach(view => {
            if (view.location) {
                const location = view.location.toLowerCase();
                locations[location] = (locations[location] || 0) + 1;
            }
        });
        
        return locations;
    }

    // Get price preferences from history
    getPricePreferences() {
        const prices = [];
        
        // Collect prices from searches
        this.searchHistory.forEach(search => {
            if (search.maxPrice) prices.push(search.maxPrice);
            if (search.minPrice) prices.push(search.minPrice);
        });
        
        // Collect prices from views
        this.viewHistory.forEach(view => {
            if (view.price) prices.push(view.price);
        });
        
        if (prices.length === 0) return {};
        
        prices.sort((a, b) => a - b);
        const q1 = prices[Math.floor(prices.length * 0.25)];
        const q3 = prices[Math.floor(prices.length * 0.75)];
        
        return {
            min: q1,
            max: q3,
            median: prices[Math.floor(prices.length * 0.5)]
        };
    }

    // Get size preferences
    getSizePreferences() {
        const sizes = {};
        
        this.searchHistory.forEach(search => {
            if (search.bedrooms) {
                sizes[search.bedrooms] = (sizes[search.bedrooms] || 0) + 2;
            }
        });
        
        this.viewHistory.forEach(view => {
            if (view.bedrooms) {
                sizes[view.bedrooms] = (sizes[view.bedrooms] || 0) + 1;
            }
        });
        
        return sizes;
    }

    // Get property type preferences
    getTypePreferences() {
        const types = {};
        
        this.searchHistory.forEach(search => {
            if (search.houseType) {
                types[search.houseType] = (types[search.houseType] || 0) + 2;
            }
        });
        
        this.viewHistory.forEach(view => {
            if (view.type) {
                types[view.type] = (types[view.type] || 0) + 1;
            }
        });
        
        return types;
    }

    // Generate human-readable recommendation reason
    generateRecommendationReason(property) {
        const reasons = [];
        const locationPrefs = this.getLocationPreferences();
        const pricePrefs = this.getPricePreferences();
        const typePrefs = this.getTypePreferences();
        
        // Location reason
        const propertyLocation = property.city.toLowerCase();
        for (const [location, frequency] of Object.entries(locationPrefs)) {
            if (propertyLocation.includes(location.toLowerCase()) && frequency > 3) {
                reasons.push(`Popular location: ${property.city}`);
                break;
            }
        }
        
        // Price reason
        if (pricePrefs.min && pricePrefs.max) {
            if (property.price >= pricePrefs.min && property.price <= pricePrefs.max) {
                reasons.push('Within your price range');
            } else if (property.price < pricePrefs.min) {
                reasons.push('Great value');
            }
        }
        
        // Type reason
        if (typePrefs[property.house_type] && typePrefs[property.house_type] > 2) {
            reasons.push(`Matches your ${property.house_type.toLowerCase()} preference`);
        }
        
        // Recency reason
        const daysSinceCreated = (Date.now() - new Date(property.created_at).getTime()) / (1000 * 60 * 60 * 24);
        if (daysSinceCreated <= 1) {
            reasons.push('New listing');
        }
        
        return reasons.length > 0 ? reasons.join(' • ') : 'Based on your activity';
    }

    // Get location-based recommendations
    async getLocationBasedRecommendations(userLocation, radius = 10) {
        if (!userLocation) return [];
        
        console.log('📍 Generating location-based recommendations...');
        
        try {
            // Get all properties (in production, this would be optimized with spatial queries)
            const { data: allProperties, error } = await this.supabase
                .from('listings')
                .select('*')
                .order('created_at', { ascending: false })
                .limit(200);
            
            if (error) throw error;
            
            // Calculate distances and filter by radius
            const nearbyProperties = allProperties
                .map(property => {
                    // For demo purposes, using approximate coordinates
                    const distance = this.calculateDistance(
                        userLocation.latitude,
                        userLocation.longitude,
                        property.latitude || 43.6532, // Default to Toronto
                        property.longitude || -79.3832
                    );
                    
                    return {
                        ...property,
                        distance: distance
                    };
                })
                .filter(property => property.distance <= radius)
                .sort((a, b) => a.distance - b.distance);
            
            // Apply user preferences to nearby properties
            const scoredProperties = nearbyProperties.map(property => ({
                ...property,
                score: this.calculatePropertyScore(property),
                reason: `${property.distance.toFixed(1)} km away • ${this.generateRecommendationReason(property)}`
            }));
            
            console.log(`📍 Found ${scoredProperties.length} properties within ${radius}km`);
            return scoredProperties.slice(0, 10); // Return top 10
            
        } catch (error) {
            console.error('Failed to get location-based recommendations:', error);
            return [];
        }
    }

    // Get similar properties
    async getSimilarProperties(propertyId, limit = 5) {
        try {
            // Get the reference property
            const { data: referenceProperty, error } = await this.supabase
                .from('listings')
                .select('*')
                .eq('id', propertyId)
                .single();
            
            if (error) throw error;
            
            // Get properties with similar characteristics
            const { data: allProperties, error: allError } = await this.supabase
                .from('listings')
                .select('*')
                .neq('id', propertyId) // Exclude the reference property
                .limit(100);
            
            if (allError) throw allError;
            
            // Calculate similarity scores
            const similarProperties = allProperties
                .map(property => ({
                    ...property,
                    similarity: this.calculateSimilarity(referenceProperty, property)
                }))
                .filter(property => property.similarity > 0.3) // Minimum similarity threshold
                .sort((a, b) => b.similarity - a.similarity)
                .slice(0, limit);
            
            console.log(`🔗 Found ${similarProperties.length} similar properties`);
            return similarProperties;
            
        } catch (error) {
            console.error('Failed to get similar properties:', error);
            return [];
        }
    }

    // Calculate similarity between two properties
    calculateSimilarity(property1, property2) {
        let similarity = 0;
        
        // Location similarity (same city)
        if (property1.city.toLowerCase() === property2.city.toLowerCase()) {
            similarity += 0.3;
        }
        
        // Price similarity (within 20% range)
        const priceDiff = Math.abs(property1.price - property2.price) / property1.price;
        if (priceDiff <= 0.2) {
            similarity += 0.3 * (1 - priceDiff / 0.2);
        }
        
        // Size similarity (same bedrooms)
        if (property1.bedrooms === property2.bedrooms) {
            similarity += 0.2;
        }
        
        // Type similarity
        if (property1.house_type === property2.house_type) {
            similarity += 0.2;
        }
        
        return similarity;
    }

    // Calculate distance between coordinates
    calculateDistance(lat1, lon1, lat2, lon2) {
        const R = 6371; // Earth's radius in kilometers
        const dLat = (lat2 - lat1) * Math.PI / 180;
        const dLon = (lon2 - lon1) * Math.PI / 180;
        const a = 
            Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
            Math.sin(dLon/2) * Math.sin(dLon/2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        return R * c;
    }

    // Get current location
    async getCurrentLocation() {
        if (window.userLocation) {
            return window.userLocation;
        }
        
        return new Promise((resolve) => {
            if (navigator.geolocation) {
                navigator.geolocation.getCurrentPosition(
                    (position) => {
                        resolve({
                            latitude: position.coords.latitude,
                            longitude: position.coords.longitude
                        });
                    },
                    () => resolve(null)
                );
            } else {
                resolve(null);
            }
        });
    }

    // Update user profile
    updateUserProfile() {
        const profile = {
            searchHistory: this.searchHistory.slice(0, 20), // Keep recent data
            viewHistory: this.viewHistory.slice(0, 50),
            savedProperties: this.savedProperties,
            lastUpdated: new Date().toISOString()
        };
        
        // Store in cache for offline access
        if (window.offlineCacheManager) {
            window.offlineCacheManager.storeUserData('userBehaviorProfile', profile);
        }
    }

    // Merge user profile data
    mergeUserProfile(cachedProfile) {
        if (cachedProfile.searchHistory) {
            this.searchHistory = [...this.searchHistory, ...cachedProfile.searchHistory]
                .filter((item, index, self) => 
                    index === self.findIndex(t => t.timestamp === item.timestamp)
                )
                .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
                .slice(0, 50);
        }
        
        if (cachedProfile.viewHistory) {
            this.viewHistory = [...this.viewHistory, ...cachedProfile.viewHistory]
                .filter((item, index, self) => 
                    index === self.findIndex(t => t.timestamp === item.timestamp)
                )
                .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
                .slice(0, 100);
        }
    }

    // Get user insights
    getUserInsights() {
        const locationPrefs = this.getLocationPreferences();
        const pricePrefs = this.getPricePreferences();
        const typePrefs = this.getTypePreferences();
        const sizePrefs = this.getSizePreferences();
        
        return {
            favoriteLocations: Object.entries(locationPrefs)
                .sort(([,a], [,b]) => b - a)
                .slice(0, 3)
                .map(([location]) => location),
            priceRange: pricePrefs,
            preferredTypes: Object.entries(typePrefs)
                .sort(([,a], [,b]) => b - a)
                .slice(0, 2)
                .map(([type]) => type),
            preferredSizes: Object.entries(sizePrefs)
                .sort(([,a], [,b]) => b - a)
                .slice(0, 2)
                .map(([size]) => `${size} bedroom${size > 1 ? 's' : ''}`),
            activityLevel: this.viewHistory.length + this.searchHistory.length,
            lastActivity: this.viewHistory.length > 0 ? this.viewHistory[0].timestamp : null
        };
    }
}

// Initialize recommendation engine
window.recommendationEngine = new RecommendationEngine(window.supabase);