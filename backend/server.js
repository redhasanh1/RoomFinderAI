const express = require('express');
const cors = require('cors');
const axios = require('axios');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcryptjs');

// Load config with error handling
let config;
try {
    config = require('../config.js');
    console.log('✅ Config loaded successfully');
} catch (error) {
    console.log('⚠️ Config file not found, using environment variables directly');
    config = {
        STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY,
        STRIPE_PUBLISHABLE_KEY: process.env.STRIPE_PUBLISHABLE_KEY,
        GOOGLE_API_KEY: process.env.GOOGLE_API_KEY,
        SUPABASE_URL: process.env.SUPABASE_URL,
        SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY,
        OPENAI_API_KEY: process.env.OPENAI_API_KEY,
        OPENAI_ORG_ID: process.env.OPENAI_ORG_ID,
        OPENAI_MODEL: process.env.OPENAI_MODEL || 'gpt-3.5-turbo'
    };
}

const { createClient } = require('@supabase/supabase-js');
const app = express();
const port = process.env.PORT || 3000;

// Initialize Stripe with error handling
let stripe;
try {
    if (config.STRIPE_SECRET_KEY) {
        stripe = require('stripe')(config.STRIPE_SECRET_KEY);
        console.log('✅ Stripe initialized');
    } else {
        console.log('⚠️ Stripe not initialized - missing STRIPE_SECRET_KEY');
    }
} catch (error) {
    console.log('❌ Stripe initialization failed:', error.message);
}

// Initialize Supabase client with error handling
let supabase;
try {
    if (config.SUPABASE_URL && config.SUPABASE_ANON_KEY) {
        supabase = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);
        console.log('✅ Supabase initialized');
    } else {
        console.log('⚠️ Supabase not initialized - missing URL or ANON_KEY');
    }
} catch (error) {
    console.log('❌ Supabase initialization failed:', error.message);
}

// Middleware
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static files from parent directory (frontend files)
const staticPath = path.join(__dirname, '..');
console.log('📁 Serving static files from:', staticPath);
app.use(express.static(staticPath));

// Google Maps API key from config
const GOOGLE_API_KEY = config.GOOGLE_API_KEY;

// In-memory database (replace with MongoDB/PostgreSQL in production)
const listings = [];
const users = [];

// Location overrides for problematic North American cities
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
    'washington, dc': 'dc',
    'st johns': 'st-johns',
    'st johns, nl': 'st-johns',
    'st catharines': 'st-catharines',
    'st catharines, on': 'st-catharines',
    'fort st john': 'fort-st-john',
    'fort st john, bc': 'fort-st-john',
};

// Helper: Normalize city name to slug
function normalizeCityToSlug(city) {
    if (!city) return '';
    const lowerCity = city.toLowerCase();
    return locationOverrides[lowerCity] || lowerCity
        .replace(/[^a-z0-9\s]/g, '')
        .replace(/\s+/g, '');
}

// Helper: Get city slug via Google Maps Geocoding API
async function getCitySlug(location) {
    try {
        const response = await axios.get(
            `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(location)}&components=continent:North%20America&key=${GOOGLE_API_KEY}`
        );
        if (response.data.status !== 'OK') {
            throw new Error(`Geocoding API error: ${response.data.status}`);
        }
        const cityComponent = response.data.results[0]?.address_components.find(c => c.types.includes('locality'));
        const city = cityComponent ? cityComponent.short_name : null;
        const slug = city ? normalizeCityToSlug(city) : location.toLowerCase().replace(/[^a-z0-9]/g, '');
        console.log(`Geocoded location: ${location} -> City: ${city || 'none'}, Slug: ${slug || 'none'}`);
        return slug;
    } catch (error) {
        console.error('Geocoding error in getCitySlug:', error.message);
        return location.toLowerCase().replace(/[^a-z0-9]/g, '');
    }
}

// Helper: Normalize city and province for Kijiji
function normalizeForKijiji(city, province) {
    if (!city) return { normalizedCity: '', normalizedProvince: '' };
    const normalizedCity = city.toLowerCase().replace(/[^a-z0-9]/g, '');
    const normalizedProvince = province ? province.toLowerCase().replace(/[^a-z0-9]/g, '') : '';
    return { normalizedCity, normalizedProvince };
}

// Helper: Get city and province for Kijiji (Canada only)
async function getCityDetails(location) {
    try {
        const response = await axios.get(
            `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(location)}&components=country:CA&key=${GOOGLE_API_KEY}`
        );
        if (response.data.status !== 'OK') {
            throw new Error(`Geocoding API error: ${response.data.status}`);
        }
        const cityComponent = response.data.results[0]?.address_components.find(c => c.types.includes('locality'));
        const provinceComponent = response.data.results[0]?.address_components.find(c => c.types.includes('administrative_area_level_1'));
        const city = cityComponent ? cityComponent.short_name : null;
        const province = provinceComponent ? provinceComponent.short_name : null;
        const { normalizedCity, normalizedProvince } = normalizeForKijiji(city, province);
        console.log(`Geocoded: ${location} -> City: ${city || 'none'}, Normalized: ${normalizedCity || 'none'}, Province: ${province || 'none'}, Normalized Province: ${normalizedProvince || 'none'}`);
        return { city: normalizedCity, province: normalizedProvince };
    } catch (error) {
        console.error('Geocoding error in getCityDetails:', error.message);
        return { city: '', province: '' };
    }
}

// Helper: Generate Kijiji search URL
async function generateKijijiUrl({ location, price, size, amenities, roomType }) {
    const { city, province } = await getCityDetails(location);
    const priceNum = parseInt(price);
    const sizeNum = size ? parseInt(size) : null;

    const minPrice = Math.floor(priceNum * 0.9);
    const maxPrice = Math.ceil(priceNum * 1.1);

    const amenityKeywords = amenities
        ? amenities.split(',').map(a => a.trim().replace(/\s+/g, '-')).join('-')
        : '';
    let query = roomType ? roomType.toLowerCase() : 'apartment';
    if (amenityKeywords) query += `-${amenityKeywords}`;
    if (sizeNum) query += `-${sizeNum}-sq-ft`;

    const baseUrl = 'https://www.kijiji.ca/b-apartments-condos';
    const encodedQuery = encodeURIComponent(query);
    const addressParam = encodeURIComponent(location);
    let locationPath = '';
    if (city && province) {
        locationPath = `/${city}-${province}`;
    }
    const kijijiUrl = `${baseUrl}${locationPath}/${encodedQuery}/k0c37?price=${minPrice}__${maxPrice}&address=${addressParam}`;
    console.log(`Generated Kijiji URL: ${kijijiUrl}`);
    return kijijiUrl;
}

// Helper: Generate Facebook Marketplace URL
async function generateMarketplaceUrl({ location, price, size, amenities, roomType }) {
    const normalizedLocation = await getCitySlug(location);
    console.log(`Input location: ${location}, Normalized: ${normalizedLocation || 'none'}`);

    const priceNum = parseInt(price);
    const sizeNum = size ? parseInt(size) : null;

    const minPrice = Math.floor(priceNum * 0.9);
    const maxPrice = Math.ceil(priceNum * 1.1);

    const amenityKeywords = amenities
        ? amenities.split(',').map(a => encodeURIComponent(a.trim())).join('%20')
        : '';

    let query = roomType ? roomType.toLowerCase() : 'apartment';
    if (amenityKeywords) query += `%20${amenityKeywords}`;
    if (sizeNum) query += `%20${sizeNum}%20sq%20ft`;
    if (!normalizedLocation) query += `%20${encodeURIComponent(location)}`;

    const baseUrl = 'https://www.facebook.com/marketplace';
    const locationPath = normalizedLocation ? `/${normalizedLocation}` : '';
    const marketplaceUrl = `${baseUrl}${locationPath}/search?minPrice=${minPrice}&maxPrice=${maxPrice}&query=${query}`;
    console.log(`Generated Marketplace URL: ${marketplaceUrl}`);
    return marketplaceUrl;
}

// Validate listing input
function validateListingInput(data) {
    const errors = [];
    if (!data.city) errors.push('City is required');
    if (!data.street) errors.push('Street is required');
    if (!data.postalCode) errors.push('Postal Code is required');
    if (!data.title) errors.push('Title is required');
    if (!data.price || isNaN(data.price)) errors.push('Valid price is required');
    if (!data.houseType) errors.push('House type is required');
    if (!data.bedrooms || isNaN(data.bedrooms)) errors.push('Valid number of bedrooms is required');
    if (!['included', 'not included'].includes(data.utilities?.toLowerCase())) errors.push('Utilities must be "included" or "not included"');
    return errors;
}

// API: Add a new listing
app.post('/api/listings', (req, res) => {
    try {
        console.log('Received listing request:', req.body);
        const { city, street, postalCode, title, price, houseType, bedrooms, utilities, description, media } = req.body;
        
        const errors = validateListingInput(req.body);
        if (errors.length > 0) {
            return res.status(400).json({ errors });
        }

        const listing = {
            id: uuidv4(),
            city,
            street,
            postalCode,
            title,
            price: parseFloat(price),
            houseType,
            bedrooms: parseInt(bedrooms),
            utilities,
            description,
            media: media || [],
            createdAt: new Date().toISOString(),
        };

        listings.push(listing);
        res.status(201).json({ message: 'Listing added successfully', listing });
    } catch (error) {
        console.error('Error in /api/listings:', error.message);
        res.status(500).json({ error: 'Failed to add listing' });
    }
});

// API: Get all listings
app.get('/api/listings', (req, res) => {
    try {
        res.json({ listings });
    } catch (error) {
        console.error('Error in /api/listings:', error.message);
        res.status(500).json({ error: 'Failed to retrieve listings' });
    }
});

// API: Get listing by ID
app.get('/api/listings/:id', (req, res) => {
    try {
        const listing = listings.find(l => l.id === req.params.id);
        if (!listing) {
            return res.status(404).json({ error: 'Listing not found' });
        }
        res.json({ listing });
    } catch (error) {
        console.error('Error in /api/listings/:id:', error.message);
        res.status(500).json({ error: 'Failed to retrieve listing' });
    }
});

// API: User registration
app.post('/api/register', async (req, res) => {
    try {
        const { firstName, lastName, email, password } = req.body;
        if (!firstName || !lastName || !email || !password) {
            return res.status(400).json({ error: 'All fields are required' });
        }

        const existingUser = users.find(u => u.email === email);
        if (existingUser) {
            return res.status(400).json({ error: 'Email already registered' });
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        const user = {
            id: uuidv4(),
            firstName,
            lastName,
            email,
            password: hashedPassword,
            createdAt: new Date().toISOString(),
        };

        users.push(user);
        res.status(201).json({ message: 'User registered successfully' });
    } catch (error) {
        console.error('Error in /api/register:', error.message);
        res.status(500).json({ error: 'Failed to register user' });
    }
});

// API: User login
app.post('/api/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required' });
        }

        const user = users.find(u => u.email === email);
        if (!user) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        res.json({ message: 'Login successful', userId: user.id });
    } catch (error) {
        console.error('Error in /api/login:', error.message);
        res.status(500).json({ error: 'Failed to login' });
    }
});

// API: AI Negotiator chat (placeholder)
app.post('/api/ai-negotiator', (req, res) => {
    try {
        const { message } = req.body;
        if (!message) {
            return res.status(400).json({ error: 'Message is required' });
        }

        // Placeholder: In production, integrate with an AI model
        const response = `AI Negotiator: I received your message: "${message}". How can I assist you with pricing tips, negotiation strategies, or adding a listing?`;
        res.json({ response });
    } catch (error) {
        console.error('Error in /api/ai-negotiator:', error.message);
        res.status(500).json({ error: 'Failed to process AI request' });
    }
});

// API: Generate Kijiji URL
app.post('/api/predict/kijiji', async (req, res) => {
    try {
        console.log('Received Kijiji request:', req.body);
        const { location, price, size, amenities, roomType } = req.body;
        if (!location || !price) {
            return res.status(400).json({ error: 'Location and price are required' });
        }

        const kijijiUrl = await generateKijijiUrl({ location, price, size, amenities, roomType });
        res.json({ url: kijijiUrl });
    } catch (error) {
        console.error('Error in /api/predict/kijiji:', error.message);
        res.status(500).json({ error: `Failed to generate Kijiji URL: ${error.message}` });
    }
});

// API: Generate Facebook Marketplace URL
app.post('/api/predict/marketplace', async (req, res) => {
    try {
        console.log('Received Marketplace request:', req.body);
        const { location, price, size, amenities, roomType } = req.body;
        if (!location || !price) {
            return res.status(400).json({ error: 'Location and price are required' });
        }

        const marketplaceUrl = await generateMarketplaceUrl({ location, price, size, amenities, roomType });
        res.json({ url: marketplaceUrl });
    } catch (error) {
        console.error('Error in /api/predict/marketplace:', error.message);
        res.status(500).json({ error: `Failed to generate Marketplace URL: ${error.message}` });
    }
});

// API: Process Stripe payment
app.post('/api/process-payment', async (req, res) => {
    try {
        if (!stripe) {
            return res.status(503).json({ error: 'Payment service not available - Stripe not configured' });
        }

        console.log('Payment request received:', req.body);
        const { token, email, name, plan, price } = req.body;
        
        if (!token || !email || !name || !plan || !price) {
            console.log('Missing required fields:', { token: !!token, email: !!email, name: !!name, plan: !!plan, price: !!price });
            return res.status(400).json({ error: 'Missing required payment information' });
        }

        // Convert price to cents (Stripe expects amounts in smallest currency unit)
        const amount = Math.round(parseFloat(price) * 100);
        console.log('Processing charge for amount:', amount, 'cents');

        // Create a charge using the token
        const charge = await stripe.charges.create({
            amount: amount,
            currency: 'usd',
            description: `Room Finder ${plan.charAt(0).toUpperCase() + plan.slice(1)} Plan Subscription`,
            source: token.id,
            receipt_email: email,
            metadata: {
                customer_name: name,
                plan_type: plan,
                monthly_price: price
            }
        });

        // If charge is successful, store subscription info in Supabase
        console.log('Payment successful:', charge.id);

        if (!supabase) {
            console.log('⚠️ Supabase not available, skipping subscription storage');
            return res.json({ 
                success: true, 
                chargeId: charge.id,
                message: 'Payment processed successfully (subscription not stored)' 
            });
        }

        // Get profile ID from email
        const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('id')
            .eq('email', email)
            .single();

        if (profileError) {
            console.error('Error finding profile:', profileError);
            // Continue without profile_id if profile not found
        }

        // Insert subscription into Supabase
        const subscriptionData = {
            email: email,
            profile_id: profile?.id || null,
            plan_type: plan,
            plan_price: parseFloat(price),
            status: 'active',
            stripe_charge_id: charge.id,
            payment_method: 'card',
            start_date: new Date().toISOString()
        };

        console.log('Attempting to save subscription:', subscriptionData);

        const { data: subscription, error: subError } = await supabase
            .from('subscriptions')
            .insert([subscriptionData])
            .select()
            .single();

        console.log('Supabase insert result:', { subscription, subError });

        if (subError) {
            console.error('Error saving subscription to Supabase:', subError);
            // Payment succeeded but subscription save failed - could handle this differently
        } else {
            console.log('Subscription saved to Supabase:', subscription?.id);
        }

        res.json({ 
            success: true, 
            chargeId: charge.id,
            subscriptionId: subscription?.id,
            message: 'Payment processed successfully' 
        });

    } catch (error) {
        console.error('Payment processing error:', error);
        res.status(400).json({ 
            error: 'Payment failed', 
            details: error.message 
        });
    }
});

// API: Get user subscription
app.get('/api/subscription/:email', async (req, res) => {
    try {
        if (!supabase) {
            return res.status(503).json({ error: 'Database service not available - Supabase not configured' });
        }

        const { email } = req.params;
        console.log('Fetching subscription for email:', email);
        
        if (!email) {
            return res.status(400).json({ error: 'Email is required' });
        }

        const { data: subscription, error } = await supabase
            .from('subscriptions')
            .select('*')
            .eq('email', email)
            .eq('status', 'active')
            .order('created_at', { ascending: false })
            .limit(1)
            .single();

        console.log('Supabase subscription query result:', { subscription, error });

        if (error && error.code !== 'PGRST116') { // PGRST116 is "no rows returned"
            console.error('Error fetching subscription:', error);
            return res.status(500).json({ error: 'Failed to fetch subscription', details: error.message });
        }

        res.json({ subscription: subscription || null });

    } catch (error) {
        console.error('Error in /api/subscription:', error);
        res.status(500).json({ error: 'Failed to fetch subscription', details: error.message });
    }
});

// Test endpoint for Supabase connection
app.get('/api/test-supabase', async (req, res) => {
    try {
        if (!supabase) {
            return res.status(503).json({ error: 'Supabase not configured' });
        }

        console.log('Testing Supabase connection...');
        
        // Test 1: Try to query profiles table
        const { data: profiles, error: profileError } = await supabase
            .from('profiles')
            .select('*')
            .limit(1);
        
        console.log('Profiles test:', { profiles, profileError });
        
        // Test 2: Try to query subscriptions table
        const { data: subscriptions, error: subError } = await supabase
            .from('subscriptions')
            .select('*')
            .limit(1);
        
        console.log('Subscriptions test:', { subscriptions, subError });
        
        // Test 3: Try to insert a test subscription
        const testSub = {
            email: 'test@example.com',
            plan_type: 'basic',
            plan_price: 9.99,
            status: 'active',
            stripe_charge_id: 'test_charge',
            payment_method: 'card',
            start_date: new Date().toISOString()
        };
        
        const { data: insertResult, error: insertError } = await supabase
            .from('subscriptions')
            .insert([testSub])
            .select()
            .single();
        
        console.log('Insert test:', { insertResult, insertError });
        
        res.json({ 
            profilesTest: { data: profiles, error: profileError },
            subscriptionsTest: { data: subscriptions, error: subError },
            insertTest: { data: insertResult, error: insertError }
        });
        
    } catch (error) {
        console.error('Supabase test error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Serve main website at root
app.get('/', (req, res) => {
    try {
        const indexPath = path.join(__dirname, '..', 'index.html');
        console.log('📄 Serving index.html from:', indexPath);
        res.sendFile(indexPath);
    } catch (error) {
        console.error('Error serving index.html:', error);
        res.status(200).send('✅ RoomFinderAI server is running');
    }
});

// Health check route for Railway monitoring
app.get('/health', (req, res) => {
    res.status(200).send('✅ RoomFinderAI server is running');
});

// Start server on Railway-required port
console.log('🚀 Starting server...');
console.log('Port:', port);
console.log('Environment variables check:');
console.log('- STRIPE_SECRET_KEY:', !!process.env.STRIPE_SECRET_KEY);
console.log('- SUPABASE_URL:', !!process.env.SUPABASE_URL);
console.log('- SUPABASE_ANON_KEY:', !!process.env.SUPABASE_ANON_KEY);

app.listen(port, () => {
    console.log(`✅ Server running on port ${port}`);
    console.log(`🏥 Health check available at http://localhost:${port}/`);
});
