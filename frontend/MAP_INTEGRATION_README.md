# Map Integration Module

A comprehensive, standalone map integration module for RoomFinderAI that provides complete map functionality using Leaflet.js with marker clustering, geocoding, and responsive design.

## Features

### Core Map Functionality
- **Leaflet Map Integration**: Full Leaflet.js map implementation with OpenStreetMap tiles
- **Marker Clustering**: Automatic marker grouping for better performance and visualization
- **Geocoding**: Address-to-coordinates conversion with fallback mechanisms
- **Custom Popups**: Rich, styled popups with listing information
- **Responsive Design**: Mobile-first, responsive map interface
- **Error Handling**: Comprehensive error handling and user feedback

### Advanced Features
- **Location-based Filtering**: Filter markers based on custom criteria
- **Multiple Map Support**: Support for multiple map instances
- **Custom Markers**: Add custom markers with custom content
- **Map Events**: Full event handling for user interactions
- **Memory Management**: Proper cleanup and resource management
- **Accessibility**: Screen reader support and keyboard navigation

## Installation

### Dependencies
Make sure you have the following dependencies loaded in your HTML:

```html
<!-- Leaflet CSS -->
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" 
      integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" 
      crossorigin=""/>

<!-- Leaflet JS -->
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" 
        integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" 
        crossorigin=""></script>

<!-- Leaflet MarkerCluster CSS -->
<link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.4.1/dist/MarkerCluster.css" />
<link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.4.1/dist/MarkerCluster.Default.css" />

<!-- Leaflet MarkerCluster JS -->
<script src="https://unpkg.com/leaflet.markercluster@1.4.1/dist/leaflet.markercluster.js"></script>

<!-- Map Integration Module -->
<script src="map-integration.js"></script>
<link rel="stylesheet" href="map-integration.css">
```

### HTML Structure
Create a container element for your map:

```html
<div id="map" class="map-container"></div>
<div id="map-error" class="map-error">Failed to load map. Please check your connection.</div>
```

## Quick Start

### Basic Usage

```javascript
// Create a new map instance
const mapManager = new MapIntegration('map');

// Initialize the map
const success = await mapManager.initialize();
if (success) {
    console.log('Map initialized successfully');
}
```

### With Listings Data

```javascript
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
    }
];

// Create and initialize map
const mapManager = new MapIntegration('map');
await mapManager.initialize();

// Update map with listings
const results = await mapManager.updateWithListings(listings);
console.log('Update results:', results);
```

## API Reference

### Constructor

```javascript
new MapIntegration(containerId, options)
```

**Parameters:**
- `containerId` (string): ID of the HTML element to contain the map
- `options` (object, optional): Configuration options

**Options:**
```javascript
{
    defaultCenter: [43.6532, -79.3832],  // Default map center [lat, lng]
    defaultZoom: 10,                      // Default zoom level
    maxZoom: 18,                          // Maximum zoom level
    minZoom: 2,                           // Minimum zoom level
    clusterRadius: 50,                    // Marker clustering radius
    geocodeDelay: 200,                    // Delay between geocoding requests (ms)
    geocodeRetries: 2                     // Number of geocoding retry attempts
}
```

### Core Methods

#### `initialize()`
Initializes the map with Leaflet and sets up marker clustering.

```javascript
const success = await mapManager.initialize();
```

**Returns:** `Promise<boolean>` - Success status

#### `updateWithListings(listings)`
Updates the map with an array of listing objects.

```javascript
const results = await mapManager.updateWithListings(listings);
```

**Parameters:**
- `listings` (Array): Array of listing objects

**Returns:** `Promise<Object>` - Update results with success/failure counts

**Listing Object Structure:**
```javascript
{
    id: number,
    title: string,
    price: number,
    street: string,
    city: string,
    postalCode: string,
    bedrooms: number,
    house_type: string,
    utilities: string
}
```

#### `geocodeLocation(location, retries)`
Converts an address string to coordinates.

```javascript
const coords = await mapManager.geocodeLocation("123 Main St, Toronto, ON");
```

**Parameters:**
- `location` (string): Address or location string
- `retries` (number, optional): Number of retry attempts

**Returns:** `Promise<Object>` - Coordinates object with lat, lon, and display_name

#### `clearMarkers()`
Removes all markers from the map.

```javascript
mapManager.clearMarkers();
```

#### `fitToMarkers(coordinates)`
Adjusts the map view to fit all markers.

```javascript
mapManager.fitToMarkers([[43.6532, -79.3832], [43.6600, -79.3900]]);
```

**Parameters:**
- `coordinates` (Array): Array of [lat, lng] coordinate pairs

### Advanced Methods

#### `addCustomMarker(coordinates, options, popupContent)`
Adds a custom marker to the map.

```javascript
const marker = mapManager.addCustomMarker(
    [43.6532, -79.3832],
    { title: 'Custom Location' },
    '<div><h3>Custom Marker</h3><p>Custom content</p></div>'
);
```

**Parameters:**
- `coordinates` (Array): [lat, lng] coordinates
- `options` (Object): Marker options
- `popupContent` (string): HTML content for popup

**Returns:** `Object` - Leaflet marker object

#### `removeMarker(marker)`
Removes a specific marker from the map.

```javascript
mapManager.removeMarker(marker);
```

#### `filterMarkers(filterFn)`
Filters markers based on a custom function.

```javascript
const filteredMarkers = mapManager.filterMarkers(marker => {
    return marker.options.title.includes('Apartment');
});
```

**Parameters:**
- `filterFn` (Function): Filter function that returns boolean

**Returns:** `Array` - Array of filtered markers

#### `setView(center, zoom)`
Sets the map view to specific coordinates and zoom level.

```javascript
mapManager.setView([43.6532, -79.3832], 12);
```

#### `refresh()`
Refreshes the map display (useful after container resize).

```javascript
mapManager.refresh();
```

#### `destroy()`
Destroys the map instance and cleans up resources.

```javascript
mapManager.destroy();
```

### Utility Methods

#### `getMarkers()`
Returns all markers currently on the map.

```javascript
const markers = mapManager.getMarkers();
```

#### `getBounds()`
Returns the current map bounds.

```javascript
const bounds = mapManager.getBounds();
```

#### `getMap()`
Returns the underlying Leaflet map instance.

```javascript
const leafletMap = mapManager.getMap();
```

#### `isMapInitialized()`
Checks if the map is initialized.

```javascript
const isInitialized = mapManager.isMapInitialized();
```

#### `updateOptions(newOptions)`
Updates map configuration options.

```javascript
mapManager.updateOptions({
    clusterRadius: 30,
    geocodeDelay: 100
});
```

#### `getOptions()`
Returns current map options.

```javascript
const options = mapManager.getOptions();
```

### Error Handling Methods

#### `showError(message)`
Shows an error message to the user.

```javascript
mapManager.showError('Failed to load map data');
```

#### `hideError()`
Hides the error message.

```javascript
mapManager.hideError();
```

## Integration with Existing Code

### Replacing Existing Map Code

If you're migrating from existing map code in `listings.html`, follow these steps:

1. **Replace the existing map variables and functions:**

```javascript
// OLD CODE - Remove these
let map;
let markers = [];
let markerClusterGroup;
function initMap() { ... }
function geocodeLocation() { ... }
function updateMap() { ... }

// NEW CODE - Replace with
const mapManager = new MapIntegration('map');
```

2. **Update initialization code:**

```javascript
// OLD CODE
initMap();

// NEW CODE
await mapManager.initialize();
```

3. **Update listing loading code:**

```javascript
// OLD CODE
updateMap(listings);

// NEW CODE
await mapManager.updateWithListings(listings);
```

### Event Handling

```javascript
// Get the underlying Leaflet map for advanced event handling
const leafletMap = mapManager.getMap();

// Add click event listener
leafletMap.on('click', function(e) {
    console.log('Map clicked at:', e.latlng);
});

// Add zoom event listener
leafletMap.on('zoomend', function() {
    console.log('Map zoom changed to:', leafletMap.getZoom());
});
```

## Styling

The module includes comprehensive CSS styling in `map-integration.css`. Key style classes:

- `.map-container`: Main map container
- `.custom-popup`: Custom popup styling
- `.popup-content`: Popup content styling
- `.custom-marker-icon`: Custom marker styling
- `.marker-cluster`: Marker cluster styling
- `.map-error`: Error message styling
- `.map-loading`: Loading indicator styling

### Custom Styling

You can override the default styles by adding your own CSS:

```css
/* Custom map height */
.map-container {
    height: 500px;
}

/* Custom popup styling */
.custom-popup .leaflet-popup-content-wrapper {
    background: #f8f9fa;
    border: 2px solid #3b82f6;
}

/* Custom marker colors */
.custom-marker-icon {
    background: #059669;
}
```

## Responsive Design

The module includes responsive design for different screen sizes:

- **Mobile (≤768px)**: Smaller map height, compact popups
- **Tablet (769px-1024px)**: Medium map height
- **Desktop (≥1025px)**: Full map height

### Responsive Handling

```javascript
// Handle window resize
window.addEventListener('resize', () => {
    mapManager.refresh();
});

// Handle container resize with ResizeObserver
if (window.ResizeObserver) {
    const mapContainer = document.getElementById('map');
    const resizeObserver = new ResizeObserver(() => {
        mapManager.refresh();
    });
    resizeObserver.observe(mapContainer);
}
```

## Error Handling

The module provides comprehensive error handling:

### Automatic Error Handling
- **Initialization failures**: Automatically shows error message
- **Geocoding failures**: Falls back to city defaults or default coordinates
- **Network errors**: Graceful degradation with retry mechanisms

### Custom Error Handling

```javascript
try {
    const success = await mapManager.initialize();
    if (!success) {
        // Handle initialization failure
        console.error('Map initialization failed');
    }
} catch (error) {
    // Handle exceptions
    console.error('Map error:', error);
    mapManager.showError('Custom error message');
}
```

## Performance Optimization

### Marker Clustering
- Automatically groups nearby markers for better performance
- Configurable cluster radius
- Custom cluster icons with counts

### Geocoding Optimization
- Configurable delays between requests to avoid rate limiting
- Fallback coordinates for common cities
- Retry mechanism for failed requests

### Memory Management
- Proper cleanup of map resources
- Marker removal and addition optimization
- Event listener cleanup

## Browser Support

- **Modern Browsers**: Chrome, Firefox, Safari, Edge (latest versions)
- **Mobile Browsers**: iOS Safari, Chrome Mobile, Samsung Internet
- **Minimum Requirements**: ES6 support, Leaflet.js compatibility

## Accessibility

### Keyboard Navigation
- Full keyboard support for map controls
- Focus indicators for interactive elements
- Screen reader compatibility

### High Contrast Mode
- Support for high contrast display preferences
- Enhanced border and color contrast

### Reduced Motion
- Respects user's reduced motion preferences
- Disables animations when requested

## Troubleshooting

### Common Issues

1. **Map not displaying:**
   - Check if container element exists
   - Verify Leaflet dependencies are loaded
   - Check browser console for errors

2. **Markers not appearing:**
   - Verify listing data has required fields (street, city)
   - Check geocoding responses in console
   - Ensure coordinates are valid

3. **Geocoding failures:**
   - Check network connectivity
   - Verify Nominatim API is accessible
   - Review fallback city coordinates

### Debug Mode

Enable debug logging:

```javascript
// Add to browser console
localStorage.setItem('mapDebug', 'true');

// The module will log detailed information about:
// - Initialization process
// - Geocoding requests and responses
// - Marker creation and management
// - Error conditions
```

## License

This module is part of the RoomFinderAI project and follows the same licensing terms.

## Contributing

To contribute to this module:

1. Follow the existing code style
2. Add comprehensive error handling
3. Include unit tests for new features
4. Update documentation
5. Ensure browser compatibility

## Changelog

### Version 1.0.0
- Initial release with core map functionality
- Leaflet integration with marker clustering
- Geocoding with fallback mechanisms
- Responsive design and accessibility features
- Comprehensive error handling
- Custom popup styling and content