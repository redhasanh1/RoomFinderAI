/**
 * Map Integration Migration Guide
 * 
 * This file provides a step-by-step migration guide and helper functions
 * to transition from the existing map code in listings.html to the new
 * MapIntegration module.
 */

/**
 * STEP 1: Add Dependencies
 * 
 * Make sure these are included in your HTML file:
 * 
 * <!-- Leaflet CSS -->
 * <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
 * 
 * <!-- Leaflet JS -->
 * <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
 * 
 * <!-- Leaflet MarkerCluster CSS -->
 * <link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.4.1/dist/MarkerCluster.css" />
 * <link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.4.1/dist/MarkerCluster.Default.css" />
 * 
 * <!-- Leaflet MarkerCluster JS -->
 * <script src="https://unpkg.com/leaflet.markercluster@1.4.1/dist/leaflet.markercluster.js"></script>
 * 
 * <!-- Map Integration Module -->
 * <script src="map-integration.js"></script>
 * <link rel="stylesheet" href="map-integration.css">
 */

/**
 * STEP 2: Replace Global Variables
 * 
 * OLD CODE (Remove these):
 * let map;
 * let markers = [];
 * let markerClusterGroup;
 * 
 * NEW CODE (Replace with):
 */
let mapManager; // Single instance to manage the map

/**
 * STEP 3: Migration Helper Functions
 * 
 * These functions help transition from the old code structure to the new module
 */

/**
 * Initialize the new map integration
 * Replaces the old initMap() function
 */
async function migrateInitMap() {
    console.log('🔄 Migrating to new MapIntegration module...');
    
    try {
        // Create new map instance
        mapManager = new MapIntegration('map', {
            defaultCenter: [43.6532, -79.3832], // Toronto coordinates
            defaultZoom: 10,
            clusterRadius: 50,
            geocodeDelay: 200
        });
        
        // Initialize the map
        const success = await mapManager.initialize();
        
        if (success) {
            console.log('✅ Map migration completed successfully');
            return true;
        } else {
            console.error('❌ Map migration failed');
            return false;
        }
    } catch (error) {
        console.error('❌ Map migration error:', error);
        return false;
    }
}

/**
 * Update map with listings data
 * Replaces the old updateMap() function
 */
async function migrateUpdateMap(listings) {
    console.log('🔄 Migrating updateMap with', listings.length, 'listings');
    
    if (!mapManager) {
        console.log('Map not initialized, initializing first...');
        const success = await migrateInitMap();
        if (!success) {
            console.error('❌ Failed to initialize map for update');
            return;
        }
    }
    
    try {
        // Update map with listings using the new module
        const results = await mapManager.updateWithListings(listings);
        
        console.log('✅ Map update migration completed:', results);
        return results;
    } catch (error) {
        console.error('❌ Map update migration error:', error);
        return null;
    }
}

/**
 * Geocode location function
 * Replaces the old geocodeLocation() function
 */
async function migrateGeocodeLocation(location) {
    console.log('🔄 Migrating geocode for:', location);
    
    if (!mapManager) {
        console.error('❌ Map not initialized for geocoding');
        return null;
    }
    
    try {
        const coords = await mapManager.geocodeLocation(location);
        console.log('✅ Geocoding migration completed:', coords);
        return coords;
    } catch (error) {
        console.error('❌ Geocoding migration error:', error);
        return null;
    }
}

/**
 * STEP 4: Complete Migration Function
 * 
 * This function performs the complete migration from old to new code
 */
async function performCompleteMigration() {
    console.log('🚀 Starting complete map migration...');
    
    try {
        // Step 1: Initialize the new map
        const initSuccess = await migrateInitMap();
        if (!initSuccess) {
            throw new Error('Failed to initialize new map');
        }
        
        // Step 2: If you have existing listings, update the map
        // This would typically come from your existing data loading logic
        const existingListings = await getExistingListings();
        if (existingListings && existingListings.length > 0) {
            await migrateUpdateMap(existingListings);
        }
        
        // Step 3: Set up event listeners (if needed)
        setupMigratedEventListeners();
        
        console.log('✅ Complete migration successful!');
        return true;
        
    } catch (error) {
        console.error('❌ Complete migration failed:', error);
        return false;
    }
}

/**
 * Helper function to get existing listings
 * Replace this with your actual data loading logic
 */
async function getExistingListings() {
    // This should be replaced with your actual data loading logic
    // For example, if you have a global loadListings function:
    
    try {
        // Example: return await loadListings();
        // For now, return empty array
        return [];
    } catch (error) {
        console.error('Error loading existing listings:', error);
        return [];
    }
}

/**
 * Setup event listeners for the migrated map
 */
function setupMigratedEventListeners() {
    if (!mapManager) return;
    
    // Get the underlying Leaflet map for advanced event handling
    const leafletMap = mapManager.getMap();
    
    // Add click event listener
    leafletMap.on('click', function(e) {
        console.log('Map clicked at:', e.latlng);
        // Add your custom click handling logic here
    });
    
    // Add zoom event listener
    leafletMap.on('zoomend', function() {
        console.log('Map zoom changed to:', leafletMap.getZoom());
        // Add your custom zoom handling logic here
    });
    
    // Handle window resize
    window.addEventListener('resize', () => {
        console.log('Window resized, refreshing map');
        mapManager.refresh();
    });
}

/**
 * STEP 5: Code Replacement Examples
 * 
 * Here are examples of how to replace specific code patterns:
 */

// OLD CODE PATTERN 1: Map initialization
/*
function initMap() {
    map = L.map('map').setView([43.6532, -79.3832], 10);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
    }).addTo(map);
    markerClusterGroup = L.markerClusterGroup();
    map.addLayer(markerClusterGroup);
}
*/

// NEW CODE PATTERN 1: Map initialization
async function newInitMap() {
    mapManager = new MapIntegration('map');
    return await mapManager.initialize();
}

// OLD CODE PATTERN 2: Adding markers
/*
const marker = L.marker([lat, lng]).bindPopup(popupContent);
markerClusterGroup.addLayer(marker);
markers.push(marker);
*/

// NEW CODE PATTERN 2: Adding markers (handled automatically by updateWithListings)
async function newAddMarkers(listings) {
    return await mapManager.updateWithListings(listings);
}

// OLD CODE PATTERN 3: Clearing markers
/*
markerClusterGroup.clearLayers();
markers = [];
*/

// NEW CODE PATTERN 3: Clearing markers
function newClearMarkers() {
    mapManager.clearMarkers();
}

// OLD CODE PATTERN 4: Geocoding
/*
const response = await fetch(`https://nominatim.openstreetmap.org/search?q=${query}&format=json&limit=1`);
const data = await response.json();
// ... manual processing
*/

// NEW CODE PATTERN 4: Geocoding
async function newGeocode(location) {
    return await mapManager.geocodeLocation(location);
}

/**
 * STEP 6: Integration with Existing initializeListingsPage Function
 * 
 * Replace the map-related code in your existing initializeListingsPage function
 */
async function integrateWithExistingCode() {
    console.log('🔄 Integrating with existing code...');
    
    // Find your existing initializeListingsPage function and replace the map initialization:
    
    // OLD CODE in initializeListingsPage:
    // initMap();
    // ... later in the function ...
    // updateMap(listings);
    
    // NEW CODE in initializeListingsPage:
    try {
        // Initialize the new map
        const success = await migrateInitMap();
        if (!success) {
            console.error('Failed to initialize map');
            return;
        }
        
        // ... your existing code for loading listings ...
        
        // Update map with listings (replace updateMap(listings) with this)
        await migrateUpdateMap(listings);
        
    } catch (error) {
        console.error('Error integrating map with existing code:', error);
    }
}

/**
 * STEP 7: Testing the Migration
 * 
 * Functions to test that the migration worked correctly
 */
function testMigration() {
    console.log('🧪 Testing migration...');
    
    // Test 1: Check if map manager exists
    if (!mapManager) {
        console.error('❌ Test failed: mapManager not initialized');
        return false;
    }
    
    // Test 2: Check if map is initialized
    if (!mapManager.isMapInitialized()) {
        console.error('❌ Test failed: map not initialized');
        return false;
    }
    
    // Test 3: Check if we can get the map instance
    const leafletMap = mapManager.getMap();
    if (!leafletMap) {
        console.error('❌ Test failed: cannot get Leaflet map instance');
        return false;
    }
    
    // Test 4: Check if we can get map options
    const options = mapManager.getOptions();
    if (!options) {
        console.error('❌ Test failed: cannot get map options');
        return false;
    }
    
    console.log('✅ All migration tests passed!');
    return true;
}

/**
 * STEP 8: Cleanup Old Code
 * 
 * After successful migration, you can remove these old functions and variables:
 */
function cleanupOldCode() {
    console.log('🧹 Cleaning up old code...');
    
    // Remove these global variables from your code:
    // let map;
    // let markers = [];
    // let markerClusterGroup;
    
    // Remove these functions from your code:
    // function initMap() { ... }
    // function geocodeLocation() { ... }
    // function updateMap() { ... }
    
    // Replace all calls to these functions with the new equivalents
    console.log('✅ Old code cleanup completed');
}

/**
 * STEP 9: Export Functions for Global Use
 */
if (typeof window !== 'undefined') {
    window.MapMigration = {
        migrateInitMap,
        migrateUpdateMap,
        migrateGeocodeLocation,
        performCompleteMigration,
        testMigration,
        integrateWithExistingCode,
        cleanupOldCode,
        
        // Getter for the map manager instance
        getMapManager: () => mapManager
    };
}

/**
 * STEP 10: Quick Migration Script
 * 
 * Run this in your browser console to perform the migration
 */
async function quickMigration() {
    console.log('🚀 Starting quick migration...');
    
    try {
        // Perform the migration
        const success = await performCompleteMigration();
        
        if (success) {
            // Test the migration
            const testSuccess = testMigration();
            
            if (testSuccess) {
                console.log('✅ Quick migration completed successfully!');
                console.log('ℹ️  You can now remove the old map code from your HTML file.');
                console.log('ℹ️  The new MapIntegration module is ready to use.');
            } else {
                console.error('❌ Migration completed but tests failed');
            }
        } else {
            console.error('❌ Quick migration failed');
        }
    } catch (error) {
        console.error('❌ Quick migration error:', error);
    }
}

// Auto-run quick migration if in browser and not in production
if (typeof window !== 'undefined' && window.location.hostname === 'localhost') {
    console.log('🔄 Auto-running quick migration for localhost...');
    setTimeout(quickMigration, 1000);
}

// Module exports
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        migrateInitMap,
        migrateUpdateMap,
        migrateGeocodeLocation,
        performCompleteMigration,
        testMigration,
        integrateWithExistingCode,
        cleanupOldCode,
        quickMigration
    };
}