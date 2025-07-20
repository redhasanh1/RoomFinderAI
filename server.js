const express = require('express');
const cors = require('cors');
const axios = require('axios');
const app = express();
const port = 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Google Maps API key (replace with your own)
const GOOGLE_API_KEY = 'AIzaSyBzE8cPfeO5YkmpJFc8SLtVsz_eGB-wYYM'; // Replace with your API key from https://console.cloud.google.com/

// Override map for problematic North American cities
const locationOverrides = {
    'los angeles': 'la',
    'los angeles, ca': 'la',
    'new york': 'nyc',
    'new york, ny': 'nyc',
    'saint john': 'saint-john',
    'saint john, nb': 'saint-john',
    'mexico city': 'mexico-city',
    'mexico city, mexico': 'mexico-city',
    'saint louis': 'stlouis',
    'saint louis, mo': 'stlouis',
    'quebec city': 'quebec',
    'quebec city, qc': 'quebec',
    'washington': 'dc',
    'washington, dc': 'dc'
};

// Helper function to normalize city name to Marketplace slug
function normalizeCityToSlug(city) {
    if (!city) return '';
    const lowerCity = city.toLowerCase();
    return locationOverrides[lowerCity] || lowerCity
        .replace(/[^a-z0-9\s]/g, '') // Remove special characters
        .replace(/\s+/g, ''); // Remove spaces
}

// Helper function to get city slug via Google Maps Geocoding API
async function getCitySlug(location) {
    try {
        // Restrict to North America using components filter
        const response = await axios.get(
            `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(location)}&components=continent:North%20America&key=${GOOGLE_API_KEY}`
        );
        const cityComponent = response.data.results[0]?.address_components.find(c => c.types.includes('locality'));
        const city = cityComponent ? cityComponent.short_name : null;
        const slug = city ? normalizeCityToSlug(city) : '';
        console.log(`Geocoded location: ${location} -> City: ${city || 'none'}, Slug: ${slug || 'none'}`);
        return slug;
    } catch (error) {
        console.error('Geocoding error:', error.message);
        return ''; // Fallback to locationless URL
    }
}

// Helper function to predict and generate Marketplace URL
async function generateMarketplaceUrl({ location, price, size, amenities }) {
    // Get Marketplace slug via Google Maps API
    const normalizedLocation = await getCitySlug(location);
    console.log(`Input location: ${location}, Normalized: ${normalizedLocation || 'none'}`); // Debug log

    // Encode for URL
    const encodedLocation = encodeURIComponent(normalizedLocation);

    const priceNum = parseInt(price);
    const sizeNum = parseInt(size);

    // Predict price range (±10% of input price)
    const minPrice = Math.floor(priceNum * 0.9);
    const maxPrice = Math.ceil(priceNum * 1.1);

    // Convert amenities to Marketplace keywords
    const amenityKeywords = amenities
        ? amenities.split(',').map(a => encodeURIComponent(a.trim())).join('%20')
        : '';

    // Construct Marketplace search URL
    let query = 'apartment'; // Base query for rooms/apartments
    if (amenityKeywords) query += `%20${amenityKeywords}`;
    if (!normalizedLocation) query += `%20${encodeURIComponent(location)}`; // Add location to query if no slug

    const baseUrl = 'https://www.facebook.com/marketplace';
    const locationPath = normalizedLocation ? `/${encodedLocation}` : '';
    const searchUrl = `${baseUrl}${locationPath}/search?minPrice=${minPrice}&maxPrice=${maxPrice}&query=${query}`;

    return searchUrl;
}

// API Endpoint to predict and generate URL
app.post('/api/predict', async (req, res) => {
    try {
        console.log('Received request:', req.body); // Debug log
        const { location, price, size, amenities } = req.body;
        if (!location || !price || !size) {
            return res.status(400).json({ error: 'Location, price, and size are required' });
        }

        const marketplaceUrl = await generateMarketplaceUrl({ location, price, size, amenities });
        console.log('Generated URL:', marketplaceUrl); // Debug log
        res.json({ url: marketplaceUrl });
    } catch (error) {
        console.error('Error in /api/predict:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// API Endpoint for chat functionality
app.post('/api/chat', async (req, res) => {
    try {
        console.log('Received chat request:', req.body);
        const { message, userId } = req.body;
        if (!message) {
            return res.status(400).json({ error: 'Message is required' });
        }

        // Simple chat responses (would integrate with OpenAI API in production)
        let response = generateChatResponse(message);
        
        console.log('Generated chat response:', response);
        res.json({ response: response });
    } catch (error) {
        console.error('Error in /api/chat:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// API Endpoint to get listings
app.get('/api/listings', async (req, res) => {
    try {
        console.log('Fetching listings...');
        
        // Fetch real listings from your website or database
        const listings = await fetchRealListings();
        
        console.log(`Returning ${listings.length} listings`);
        res.json({ listings: listings });
    } catch (error) {
        console.error('Error in /api/listings:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// Function to fetch real listings from your website/database
async function fetchRealListings() {
    try {
        // Try to fetch from your website first
        const response = await axios.get('https://roomfinderai.com/api/listings');
        return response.data.listings || response.data;
    } catch (error) {
        console.log('Could not fetch from website, returning empty array');
        // Return empty array instead of mock data
        return [];
    }
}

// API Endpoint to search listings
app.post('/api/listings/search', async (req, res) => {
    try {
        console.log('Search request:', req.body);
        const { query } = req.body;
        
        // Get all listings first
        const allListings = await fetchRealListings();
        let filteredListings = allListings;
        
        if (query) {
            const lowerQuery = query.toLowerCase();
            filteredListings = allListings.filter(listing => 
                listing.title.toLowerCase().includes(lowerQuery) ||
                listing.location.toLowerCase().includes(lowerQuery) ||
                listing.description.toLowerCase().includes(lowerQuery) ||
                listing.propertyType.toLowerCase().includes(lowerQuery)
            );
        }
        
        console.log(`Found ${filteredListings.length} matching listings`);
        res.json({ listings: filteredListings });
    } catch (error) {
        console.error('Error in /api/listings/search:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// API Endpoint to filter listings
app.get('/api/listings/filter', async (req, res) => {
    try {
        console.log('Filter request:', req.query);
        const { minPrice, maxPrice, bedrooms, propertyType } = req.query;
        
        // Get all listings first
        const allListings = await fetchRealListings();
        let filteredListings = allListings;
        
        // Apply filters
        if (minPrice) {
            filteredListings = filteredListings.filter(listing => listing.price >= parseFloat(minPrice));
        }
        
        if (maxPrice) {
            filteredListings = filteredListings.filter(listing => listing.price <= parseFloat(maxPrice));
        }
        
        if (bedrooms) {
            filteredListings = filteredListings.filter(listing => listing.bedrooms === parseInt(bedrooms));
        }
        
        if (propertyType) {
            filteredListings = filteredListings.filter(listing => 
                listing.propertyType.toLowerCase() === propertyType.toLowerCase()
            );
        }
        
        console.log(`Found ${filteredListings.length} filtered listings`);
        res.json({ listings: filteredListings });
    } catch (error) {
        console.error('Error in /api/listings/filter:', error);
        res.status(500).json({ error: 'Server error' });
    }
});


// Helper function to generate chat responses
function generateChatResponse(message) {
    const lowerMessage = message.toLowerCase();
    
    if (lowerMessage.includes('price') || lowerMessage.includes('negotiate')) {
        return "I can help you negotiate the price. What's your budget range and what features are most important to you?";
    } else if (lowerMessage.includes('location')) {
        return "Location is crucial! Are you looking for something near public transit, schools, or specific neighborhoods?";
    } else if (lowerMessage.includes('room') || lowerMessage.includes('apartment')) {
        return "I'll help you find the perfect place. What size are you looking for and when do you need to move in?";
    } else if (lowerMessage.includes('hello') || lowerMessage.includes('hi')) {
        return "Hi there! I'm your AI housing assistant. I can help you find apartments, negotiate prices, and answer questions about housing. What can I help you with today?";
    } else if (lowerMessage.includes('help')) {
        return "I can help you with:\n• Finding apartments and rooms\n• Negotiating rental prices\n• Understanding lease terms\n• Answering housing questions\n\nWhat would you like to know?";
    } else {
        return "I understand. Let me help you with that. Could you provide more details about what you're looking for?";
    }
}

app.listen(port, '0.0.0.0', () => {
    console.log(`Server running at http://0.0.0.0:${port}`);
    console.log(`Also accessible at http://localhost:${port}`);
    console.log(`For Android emulator use: http://10.0.2.2:${port}`);
});
