/**
 * Map Integration Usage Example
 * 
 * This file demonstrates how to use the MapIntegration module
 * in various scenarios for the RoomFinderAI application.
 */

// Example 1: Basic Map Initialization
async function basicMapExample() {
    console.log('=== Basic Map Example ===');
    
    // Create map instance
    const mapManager = new MapIntegration('map');
    
    // Initialize the map
    const success = await mapManager.initialize();
    if (!success) {
        console.error('Failed to initialize map');
        return;
    }
    
    console.log('Map initialized successfully');
}

// Example 2: Map with Listings Data
async function listingsMapExample() {
    console.log('=== Listings Map Example ===');
    
    // Sample listings data
    const listings = [
        {
            id: 1,
            title: "Cozy Downtown Apartment",
            price: 2500,
            street: "123 Main St",
            city: "Toronto",
            postalCode: "M5V 1A1",
            bedrooms: 1,
            house_type: "Apartment",
            utilities: "Included"
        },
        {
            id: 2,
            title: "Spacious Family Home",
            price: 3200,
            street: "456 Oak Avenue",
            city: "Toronto",
            postalCode: "M6J 2B2",
            bedrooms: 3,
            house_type: "House",
            utilities: "Separate"
        },
        {
            id: 3,
            title: "Modern Condo",
            price: 2800,
            street: "789 King Street",
            city: "Toronto",
            postalCode: "M5H 3C3",
            bedrooms: 2,
            house_type: "Condo",
            utilities: "Included"
        }
    ];
    
    // Create map instance with custom options
    const mapManager = new MapIntegration('map', {
        defaultCenter: [43.6532, -79.3832],
        defaultZoom: 12,
        clusterRadius: 30,
        geocodeDelay: 100
    });
    
    // Initialize and update with listings
    const success = await mapManager.initialize();
    if (success) {
        const results = await mapManager.updateWithListings(listings);
        console.log('Update results:', results);
    }
}

// Example 3: Custom Marker Management
async function customMarkerExample() {
    console.log('=== Custom Marker Example ===');
    
    const mapManager = new MapIntegration('map');
    await mapManager.initialize();
    
    // Add custom markers
    const customMarker1 = mapManager.addCustomMarker(
        [43.6532, -79.3832],
        { title: 'Custom Location 1' },
        '<div><h3>Custom Location 1</h3><p>This is a custom marker</p></div>'
    );
    
    const customMarker2 = mapManager.addCustomMarker(
        [43.6600, -79.3900],
        { title: 'Custom Location 2' },
        '<div><h3>Custom Location 2</h3><p>Another custom marker</p></div>'
    );
    
    // Fit view to show both markers
    mapManager.fitToMarkers([
        [43.6532, -79.3832],
        [43.6600, -79.3900]
    ]);
    
    // Remove a marker after 5 seconds
    setTimeout(() => {
        mapManager.removeMarker(customMarker1);
        console.log('Removed first custom marker');
    }, 5000);
}

// Example 4: Map Filtering
async function filteringExample() {
    console.log('=== Filtering Example ===');
    
    const mapManager = new MapIntegration('map');
    await mapManager.initialize();
    
    // Sample data with price information
    const listings = [
        { id: 1, title: "Expensive Place", price: 4000, street: "Rich St", city: "Toronto", postalCode: "M5V 1A1", bedrooms: 2, house_type: "Condo", utilities: "Included" },
        { id: 2, title: "Affordable Place", price: 1500, street: "Budget Ave", city: "Toronto", postalCode: "M6J 2B2", bedrooms: 1, house_type: "Apartment", utilities: "Separate" },
        { id: 3, title: "Mid-range Place", price: 2500, street: "Middle Rd", city: "Toronto", postalCode: "M5H 3C3", bedrooms: 2, house_type: "House", utilities: "Included" }
    ];
    
    // Update with all listings
    await mapManager.updateWithListings(listings);
    
    // Filter to show only affordable places (< $2000)
    setTimeout(() => {
        const filteredMarkers = mapManager.filterMarkers(marker => {
            const title = marker.options.title;
            return title && title.includes('Affordable');
        });
        
        console.log('Filtered to', filteredMarkers.length, 'affordable markers');
    }, 2000);
}

// Example 5: Error Handling
async function errorHandlingExample() {
    console.log('=== Error Handling Example ===');
    
    // Try to initialize with invalid container
    const mapManager = new MapIntegration('non-existent-container');
    const success = await mapManager.initialize();
    
    if (!success) {
        console.log('Map initialization failed as expected');
        mapManager.showError('Custom error message');
    }
}

// Example 6: Map Events and Interactions
async function eventsExample() {
    console.log('=== Events Example ===');
    
    const mapManager = new MapIntegration('map');
    await mapManager.initialize();
    
    // Get the underlying Leaflet map for advanced interactions
    const leafletMap = mapManager.getMap();
    
    // Add click event listener
    leafletMap.on('click', function(e) {
        console.log('Map clicked at:', e.latlng);
        
        // Add a temporary marker at click location
        const tempMarker = mapManager.addCustomMarker(
            [e.latlng.lat, e.latlng.lng],
            { title: 'Clicked Location' },
            '<div><h3>You clicked here!</h3></div>'
        );
        
        // Remove the marker after 3 seconds
        setTimeout(() => {
            mapManager.removeMarker(tempMarker);
        }, 3000);
    });
    
    // Add zoom event listener
    leafletMap.on('zoomend', function() {
        console.log('Map zoom changed to:', leafletMap.getZoom());
    });
}

// Example 7: Integration with Existing Application
async function integrationExample() {
    console.log('=== Integration Example ===');
    
    // This is how you would integrate with the existing listings.html
    const mapManager = new MapIntegration('map', {
        defaultCenter: [43.6532, -79.3832], // Toronto
        defaultZoom: 10,
        clusterRadius: 50,
        geocodeDelay: 200
    });
    
    // Initialize map
    const success = await mapManager.initialize();
    if (!success) {
        console.error('Failed to initialize map');
        return;
    }
    
    // Function to load and display listings (replace with actual data loading)
    async function loadAndDisplayListings() {
        try {
            // In real application, this would fetch from Supabase
            const listings = await fetchListingsFromDatabase();
            
            // Update map with listings
            const results = await mapManager.updateWithListings(listings);
            
            console.log('Map updated with listings:', results);
            
            // You can also get map bounds for further processing
            const bounds = mapManager.getBounds();
            console.log('Current map bounds:', bounds);
            
        } catch (error) {
            console.error('Error loading listings:', error);
            mapManager.showError('Failed to load listings');
        }
    }
    
    // Mock function - replace with actual database call
    async function fetchListingsFromDatabase() {
        // This would be replaced with actual Supabase query
        return [
            {
                id: 1,
                title: "Sample Listing",
                price: 2000,
                street: "123 Sample St",
                city: "Toronto",
                postalCode: "M5V 1A1",
                bedrooms: 1,
                house_type: "Apartment",
                utilities: "Included"
            }
        ];
    }
    
    // Load listings
    await loadAndDisplayListings();
    
    // Example of updating options dynamically
    mapManager.updateOptions({
        clusterRadius: 30,
        geocodeDelay: 100
    });
    
    // Example of refreshing the map
    mapManager.refresh();
}

// Example 8: Responsive Design Handling
async function responsiveExample() {
    console.log('=== Responsive Example ===');
    
    const mapManager = new MapIntegration('map');
    await mapManager.initialize();
    
    // Handle window resize
    window.addEventListener('resize', () => {
        console.log('Window resized, refreshing map');
        mapManager.refresh();
    });
    
    // Handle container size changes (if using ResizeObserver)
    if (window.ResizeObserver) {
        const mapContainer = document.getElementById('map');
        const resizeObserver = new ResizeObserver(() => {
            console.log('Map container resized, refreshing map');
            mapManager.refresh();
        });
        resizeObserver.observe(mapContainer);
    }
}

// Example 9: Memory Management
async function memoryManagementExample() {
    console.log('=== Memory Management Example ===');
    
    const mapManager = new MapIntegration('map');
    await mapManager.initialize();
    
    // Use the map for some operations
    await mapManager.updateWithListings([
        {
            id: 1,
            title: "Test Listing",
            price: 2000,
            street: "Test St",
            city: "Toronto",
            postalCode: "M5V 1A1",
            bedrooms: 1,
            house_type: "Apartment",
            utilities: "Included"
        }
    ]);
    
    // Clean up when done (e.g., when navigating to another page)
    setTimeout(() => {
        console.log('Cleaning up map resources...');
        mapManager.destroy();
    }, 10000);
}

// Example 10: Multiple Map Instances
async function multipleMapExample() {
    console.log('=== Multiple Map Example ===');
    
    // Create multiple map instances for different containers
    const mainMapManager = new MapIntegration('main-map');
    const overviewMapManager = new MapIntegration('overview-map', {
        defaultZoom: 8,
        clusterRadius: 80
    });
    
    // Initialize both maps
    await Promise.all([
        mainMapManager.initialize(),
        overviewMapManager.initialize()
    ]);
    
    // Update both with the same data
    const listings = [
        {
            id: 1,
            title: "Shared Listing",
            price: 2000,
            street: "Shared St",
            city: "Toronto",
            postalCode: "M5V 1A1",
            bedrooms: 1,
            house_type: "Apartment",
            utilities: "Included"
        }
    ];
    
    await Promise.all([
        mainMapManager.updateWithListings(listings),
        overviewMapManager.updateWithListings(listings)
    ]);
    
    console.log('Both maps updated with listings');
}

// Export examples for use in other files
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        basicMapExample,
        listingsMapExample,
        customMarkerExample,
        filteringExample,
        errorHandlingExample,
        eventsExample,
        integrationExample,
        responsiveExample,
        memoryManagementExample,
        multipleMapExample
    };
}

// Global export for browser usage
if (typeof window !== 'undefined') {
    window.MapIntegrationExamples = {
        basicMapExample,
        listingsMapExample,
        customMarkerExample,
        filteringExample,
        errorHandlingExample,
        eventsExample,
        integrationExample,
        responsiveExample,
        memoryManagementExample,
        multipleMapExample
    };
}