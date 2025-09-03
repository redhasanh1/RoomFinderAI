// Offline Data Caching Manager
class OfflineCacheManager {
    constructor(supabase) {
        this.supabase = supabase;
        this.dbName = 'RoomFinderOfflineDB';
        this.version = 1;
        this.db = null;
        this.cacheSize = 50; // Maximum cached listings
        this.maxAge = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
        
        console.log('💾 Offline Cache Manager initialized');
    }

    // Initialize IndexedDB
    async init() {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open(this.dbName, this.version);
            
            request.onerror = () => {
                console.error('Failed to open IndexedDB:', request.error);
                reject(request.error);
            };
            
            request.onsuccess = () => {
                this.db = request.result;
                console.log('✅ IndexedDB initialized');
                resolve(true);
            };
            
            request.onupgradeneeded = (event) => {
                const db = event.target.result;
                
                // Create object stores
                if (!db.objectStoreNames.contains('listings')) {
                    const listingsStore = db.createObjectStore('listings', { keyPath: 'id' });
                    listingsStore.createIndex('cachedAt', 'cachedAt', { unique: false });
                    listingsStore.createIndex('city', 'city', { unique: false });
                    listingsStore.createIndex('price', 'price', { unique: false });
                }
                
                if (!db.objectStoreNames.contains('searches')) {
                    const searchStore = db.createObjectStore('searches', { keyPath: 'id' });
                    searchStore.createIndex('timestamp', 'timestamp', { unique: false });
                }
                
                if (!db.objectStoreNames.contains('images')) {
                    const imageStore = db.createObjectStore('images', { keyPath: 'url' });
                    imageStore.createIndex('cachedAt', 'cachedAt', { unique: false });
                }
                
                if (!db.objectStoreNames.contains('userdata')) {
                    db.createObjectStore('userdata', { keyPath: 'key' });
                }
                
                console.log('📦 IndexedDB stores created');
            };
        });
    }

    // Cache listings with metadata
    async cacheListings(listings, searchCriteria = null) {
        if (!this.db || !Array.isArray(listings)) return false;
        
        try {
            const transaction = this.db.transaction(['listings'], 'readwrite');
            const store = transaction.objectStore('listings');
            const now = new Date().toISOString();
            
            // Add cache metadata to each listing
            const cachedListings = listings.map(listing => ({
                ...listing,
                cachedAt: now,
                searchCriteria: searchCriteria
            }));
            
            // Store listings
            for (const listing of cachedListings) {
                await this.putInStore(store, listing);
            }
            
            // Clean up old cache if size limit exceeded
            await this.cleanupListingsCache();
            
            console.log(`💾 Cached ${listings.length} listings`);
            return true;
            
        } catch (error) {
            console.error('Failed to cache listings:', error);
            return false;
        }
    }

    // Get cached listings
    async getCachedListings(searchCriteria = null) {
        if (!this.db) return [];
        
        try {
            const transaction = this.db.transaction(['listings'], 'readonly');
            const store = transaction.objectStore('listings');
            const allListings = await this.getAllFromStore(store);
            
            // Filter out expired cache
            const validListings = allListings.filter(listing => {
                const cacheAge = Date.now() - new Date(listing.cachedAt).getTime();
                return cacheAge < this.maxAge;
            });
            
            // Apply search criteria if provided
            let filteredListings = validListings;
            if (searchCriteria) {
                filteredListings = this.filterListingsBySearch(validListings, searchCriteria);
            }
            
            console.log(`📱 Retrieved ${filteredListings.length} cached listings`);
            return filteredListings;
            
        } catch (error) {
            console.error('Failed to get cached listings:', error);
            return [];
        }
    }

    // Cache individual listing
    async cacheListing(listing) {
        if (!this.db || !listing) return false;
        
        try {
            const transaction = this.db.transaction(['listings'], 'readwrite');
            const store = transaction.objectStore('listings');
            
            const cachedListing = {
                ...listing,
                cachedAt: new Date().toISOString()
            };
            
            await this.putInStore(store, cachedListing);
            console.log(`💾 Cached listing: ${listing.id}`);
            return true;
            
        } catch (error) {
            console.error('Failed to cache listing:', error);
            return false;
        }
    }

    // Get cached listing by ID
    async getCachedListing(id) {
        if (!this.db) return null;
        
        try {
            const transaction = this.db.transaction(['listings'], 'readonly');
            const store = transaction.objectStore('listings');
            const listing = await this.getFromStore(store, id);
            
            if (listing) {
                const cacheAge = Date.now() - new Date(listing.cachedAt).getTime();
                if (cacheAge < this.maxAge) {
                    console.log(`📱 Retrieved cached listing: ${id}`);
                    return listing;
                } else {
                    // Remove expired listing
                    await this.removeCachedListing(id);
                }
            }
            
            return null;
            
        } catch (error) {
            console.error('Failed to get cached listing:', error);
            return null;
        }
    }

    // Cache search results
    async cacheSearch(searchCriteria, results) {
        if (!this.db) return false;
        
        try {
            const transaction = this.db.transaction(['searches'], 'readwrite');
            const store = transaction.objectStore('searches');
            
            const searchCache = {
                id: this.generateSearchId(searchCriteria),
                criteria: searchCriteria,
                results: results.map(r => r.id), // Store only IDs
                timestamp: new Date().toISOString(),
                count: results.length
            };
            
            await this.putInStore(store, searchCache);
            
            // Also cache the listings themselves
            await this.cacheListings(results, searchCriteria);
            
            console.log(`💾 Cached search with ${results.length} results`);
            return true;
            
        } catch (error) {
            console.error('Failed to cache search:', error);
            return false;
        }
    }

    // Get cached search results
    async getCachedSearch(searchCriteria) {
        if (!this.db) return null;
        
        try {
            const searchId = this.generateSearchId(searchCriteria);
            const transaction = this.db.transaction(['searches'], 'readonly');
            const store = transaction.objectStore('searches');
            const searchCache = await this.getFromStore(store, searchId);
            
            if (searchCache) {
                const cacheAge = Date.now() - new Date(searchCache.timestamp).getTime();
                if (cacheAge < this.maxAge) {
                    // Get the actual listings
                    const listings = await Promise.all(
                        searchCache.results.map(id => this.getCachedListing(id))
                    );
                    
                    const validListings = listings.filter(l => l !== null);
                    
                    if (validListings.length > 0) {
                        console.log(`📱 Retrieved ${validListings.length} listings from cached search`);
                        return validListings;
                    }
                }
            }
            
            return null;
            
        } catch (error) {
            console.error('Failed to get cached search:', error);
            return null;
        }
    }

    // Cache images for offline viewing
    async cacheImage(url) {
        if (!this.db || !url) return false;
        
        try {
            // Check if already cached
            const cached = await this.getCachedImage(url);
            if (cached) return true;
            
            // Fetch and cache the image
            const response = await fetch(url);
            if (!response.ok) throw new Error('Failed to fetch image');
            
            const blob = await response.blob();
            const transaction = this.db.transaction(['images'], 'readwrite');
            const store = transaction.objectStore('images');
            
            const imageCache = {
                url: url,
                blob: blob,
                cachedAt: new Date().toISOString(),
                size: blob.size
            };
            
            await this.putInStore(store, imageCache);
            console.log(`📷 Cached image: ${url}`);
            return true;
            
        } catch (error) {
            console.error('Failed to cache image:', error);
            return false;
        }
    }

    // Get cached image
    async getCachedImage(url) {
        if (!this.db) return null;
        
        try {
            const transaction = this.db.transaction(['images'], 'readonly');
            const store = transaction.objectStore('images');
            const imageCache = await this.getFromStore(store, url);
            
            if (imageCache) {
                const cacheAge = Date.now() - new Date(imageCache.cachedAt).getTime();
                if (cacheAge < this.maxAge) {
                    return URL.createObjectURL(imageCache.blob);
                } else {
                    // Remove expired image
                    await this.removeCachedImage(url);
                }
            }
            
            return null;
            
        } catch (error) {
            console.error('Failed to get cached image:', error);
            return null;
        }
    }

    // Store user data for offline access
    async storeUserData(key, data) {
        if (!this.db) return false;
        
        try {
            const transaction = this.db.transaction(['userdata'], 'readwrite');
            const store = transaction.objectStore('userdata');
            
            const userData = {
                key: key,
                data: data,
                timestamp: new Date().toISOString()
            };
            
            await this.putInStore(store, userData);
            console.log(`💾 Stored user data: ${key}`);
            return true;
            
        } catch (error) {
            console.error('Failed to store user data:', error);
            return false;
        }
    }

    // Get user data
    async getUserData(key) {
        if (!this.db) return null;
        
        try {
            const transaction = this.db.transaction(['userdata'], 'readonly');
            const store = transaction.objectStore('userdata');
            const userData = await this.getFromStore(store, key);
            
            return userData ? userData.data : null;
            
        } catch (error) {
            console.error('Failed to get user data:', error);
            return null;
        }
    }

    // Cleanup old cache entries
    async cleanupListingsCache() {
        if (!this.db) return;
        
        try {
            const transaction = this.db.transaction(['listings'], 'readwrite');
            const store = transaction.objectStore('listings');
            const index = store.index('cachedAt');
            
            const allListings = await this.getAllFromStore(store);
            
            // Remove expired listings
            const now = Date.now();
            const expiredListings = allListings.filter(listing => {
                const cacheAge = now - new Date(listing.cachedAt).getTime();
                return cacheAge > this.maxAge;
            });
            
            for (const listing of expiredListings) {
                await this.deleteFromStore(store, listing.id);
            }
            
            // If still over limit, remove oldest
            const validListings = allListings.filter(listing => {
                const cacheAge = now - new Date(listing.cachedAt).getTime();
                return cacheAge <= this.maxAge;
            });
            
            if (validListings.length > this.cacheSize) {
                const sorted = validListings.sort((a, b) => 
                    new Date(a.cachedAt) - new Date(b.cachedAt)
                );
                
                const toRemove = sorted.slice(0, validListings.length - this.cacheSize);
                for (const listing of toRemove) {
                    await this.deleteFromStore(store, listing.id);
                }
            }
            
            console.log(`🧹 Cache cleanup completed`);
            
        } catch (error) {
            console.error('Cache cleanup failed:', error);
        }
    }

    // Remove cached listing
    async removeCachedListing(id) {
        if (!this.db) return;
        
        try {
            const transaction = this.db.transaction(['listings'], 'readwrite');
            const store = transaction.objectStore('listings');
            await this.deleteFromStore(store, id);
            
        } catch (error) {
            console.error('Failed to remove cached listing:', error);
        }
    }

    // Remove cached image
    async removeCachedImage(url) {
        if (!this.db) return;
        
        try {
            const transaction = this.db.transaction(['images'], 'readwrite');
            const store = transaction.objectStore('images');
            await this.deleteFromStore(store, url);
            
        } catch (error) {
            console.error('Failed to remove cached image:', error);
        }
    }

    // Clear all cache
    async clearAllCache() {
        if (!this.db) return;
        
        try {
            const stores = ['listings', 'searches', 'images', 'userdata'];
            const transaction = this.db.transaction(stores, 'readwrite');
            
            for (const storeName of stores) {
                const store = transaction.objectStore(storeName);
                await this.clearStore(store);
            }
            
            console.log('🗑️ All cache cleared');
            
        } catch (error) {
            console.error('Failed to clear cache:', error);
        }
    }

    // Get cache statistics
    async getCacheStats() {
        if (!this.db) return null;
        
        try {
            const listingsCount = await this.getStoreCount('listings');
            const searchesCount = await this.getStoreCount('searches');
            const imagesCount = await this.getStoreCount('images');
            const userdataCount = await this.getStoreCount('userdata');
            
            return {
                listings: listingsCount,
                searches: searchesCount,
                images: imagesCount,
                userdata: userdataCount,
                lastCleanup: null,
                maxAge: this.maxAge,
                cacheSize: this.cacheSize
            };
            
        } catch (error) {
            console.error('Failed to get cache stats:', error);
            return null;
        }
    }

    // Utility functions
    generateSearchId(criteria) {
        const normalized = {
            location: criteria.location || '',
            maxPrice: criteria.maxPrice || '',
            minPrice: criteria.minPrice || '',
            bedrooms: criteria.bedrooms || '',
            houseType: criteria.houseType || ''
        };
        
        return btoa(JSON.stringify(normalized)).replace(/[/+=]/g, '');
    }

    filterListingsBySearch(listings, criteria) {
        return listings.filter(listing => {
            if (criteria.location && !listing.city.toLowerCase().includes(criteria.location.toLowerCase())) {
                return false;
            }
            if (criteria.maxPrice && listing.price > criteria.maxPrice) {
                return false;
            }
            if (criteria.minPrice && listing.price < criteria.minPrice) {
                return false;
            }
            if (criteria.bedrooms && listing.bedrooms < criteria.bedrooms) {
                return false;
            }
            if (criteria.houseType && listing.house_type !== criteria.houseType) {
                return false;
            }
            return true;
        });
    }

    // IndexedDB helper functions
    putInStore(store, data) {
        return new Promise((resolve, reject) => {
            const request = store.put(data);
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }

    getFromStore(store, key) {
        return new Promise((resolve, reject) => {
            const request = store.get(key);
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }

    getAllFromStore(store) {
        return new Promise((resolve, reject) => {
            const request = store.getAll();
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }

    deleteFromStore(store, key) {
        return new Promise((resolve, reject) => {
            const request = store.delete(key);
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }

    clearStore(store) {
        return new Promise((resolve, reject) => {
            const request = store.clear();
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }

    getStoreCount(storeName) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction([storeName], 'readonly');
            const store = transaction.objectStore(storeName);
            const request = store.count();
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }

    // Check if device is online
    isOnline() {
        return navigator.onLine;
    }

    // Get offline status indicator
    getOfflineStatus() {
        return {
            isOnline: this.isOnline(),
            hasCachedData: this.db !== null,
            cacheAge: this.maxAge,
            lastSync: null
        };
    }
}

// Initialize offline cache manager
window.offlineCacheManager = new OfflineCacheManager(window.supabase);