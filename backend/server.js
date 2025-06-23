const express = require('express');
const cors = require('cors');
const axios = require('axios');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcryptjs');
const config = require('../config.js');

const { createClient } = require('@supabase/supabase-js');
const app = express();
const port = 3000;

// Initialize Stripe with API key from config
const stripe = require('stripe')(config.STRIPE_SECRET_KEY);

// Initialize Supabase client with config keys
const supabase = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);

// Middleware
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static files from parent directory
app.use(express.static('../'));

// Add explicit routes for your HTML pages
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, '../index.html'));
});

app.get('/pricing', (req, res) => {
    res.sendFile(path.join(__dirname, '../pricing.html'));
});

app.get('/payment', (req, res) => {
    res.sendFile(path.join(__dirname, '../payment.html'));
});

app.get('/login', (req, res) => {
    res.sendFile(path.join(__dirname, '../login.html'));
});

app.get('/signup', (req, res) => {
    res.sendFile(path.join(__dirname, '../signup.html'));
});

app.get('/listings', (req, res) => {
    res.sendFile(path.join(__dirname, '../listings.html'));
});

app.get('/sublease', (req, res) => {
    res.sendFile(path.join(__dirname, '../sublease.html'));
});

app.get('/ai-negotiator', (req, res) => {
    res.sendFile(path.join(__dirname, '../ai-negotiator.html'));
});

app.get('/profile', (req, res) => {
    res.sendFile(path.join(__dirname, '../profile.html'));
});

app.get('/manage-subscription', (req, res) => {
    res.sendFile(path.join(__dirname, '../manage-subscription.html'));
});

app.get('/listing_details', (req, res) => {
    res.sendFile(path.join(__dirname, '../listing_details.html'));
});

// Add routes for navigation links that go to index with anchors
app.get('/index', (req, res) => {
    res.sendFile(path.join(__dirname, '../index.html'));
});

app.get('/index/:section', (req, res) => {
    res.sendFile(path.join(__dirname, '../index.html'));
});

// Handle anchor navigation routes
app.get('/about', (req, res) => {
    res.redirect('/#about');
});

app.get('/contact', (req, res) => {
    res.redirect('/#contact');
});

app.get('/home', (req, res) => {
    res.redirect('/');
});

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
    const locationPath = normalizedLocation ? `/${encodedLocation}` : '';
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
        console.log('Payment request received:', req.body);
        const { token, email, name, plan, price, paymentMethod } = req.body;
        
        if (!token || !plan || !price) {
            console.log('Missing required fields:', { token: !!token, plan: !!plan, price: !!price });
            return res.status(400).json({ error: 'Missing required payment information' });
        }

        // For wallet payments, email and name might come from the token
        const customerEmail = email || token.email || 'no-email@provided.com';
        const customerName = name || token.card?.name || 'No Name Provided';

        // Convert price to cents (Stripe expects amounts in smallest currency unit)
        const amount = Math.round(parseFloat(price) * 100);
        console.log('Processing charge for amount:', amount, 'cents');

        // Create a charge using the token
        const charge = await stripe.charges.create({
            amount: amount,
            currency: 'usd',
            description: `Room Finder ${plan.charAt(0).toUpperCase() + plan.slice(1)} Plan Subscription`,
            source: token.id,
            receipt_email: customerEmail,
            metadata: {
                customer_name: customerName,
                plan_type: plan,
                monthly_price: price,
                payment_method: paymentMethod || 'card'
            }
        });

        // If charge is successful, store subscription info in Supabase
        console.log('Payment successful:', charge.id);

        // Get profile ID from email
        const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('id')
            .eq('email', customerEmail)
            .single();

        if (profileError) {
            console.error('Error finding profile:', profileError);
            // Continue without profile_id if profile not found
        }

        // Insert subscription into Supabase
        const subscriptionData = {
            email: customerEmail,
            profile_id: profile?.id || null,
            plan_type: plan,
            plan_price: parseFloat(price),
            status: 'active',
            stripe_charge_id: charge.id,
            payment_method: paymentMethod || 'card',
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

// API: Cancel subscription
app.post('/api/subscription/cancel', async (req, res) => {
    try {
        const { email, subscription_id, cancellation_reason } = req.body;
        
        if (!email || !subscription_id) {
            return res.status(400).json({ error: 'Email and subscription ID are required' });
        }
        
        console.log('Scheduling subscription cancellation:', { email, subscription_id, cancellation_reason });
        
        // Get the current subscription to calculate next billing date
        const { data: currentSub, error: fetchError } = await supabase
            .from('subscriptions')
            .select('*')
            .eq('id', subscription_id)
            .eq('email', email)
            .single();
            
        if (fetchError || !currentSub) {
            return res.status(404).json({ error: 'Subscription not found' });
        }
        
        // Calculate the end of current billing period (when cancellation takes effect)
        const startDate = new Date(currentSub.start_date);
        const cancelEffectiveDate = new Date(startDate);
        cancelEffectiveDate.setMonth(cancelEffectiveDate.getMonth() + 1);
        
        // Update subscription to be cancelled at end of billing period
        const { data: subscription, error } = await supabase
            .from('subscriptions')
            .update({
                status: 'pending_cancellation',
                cancellation_requested_at: new Date().toISOString(),
                cancellation_effective_date: cancelEffectiveDate.toISOString(),
                cancellation_reason: cancellation_reason || null
            })
            .eq('id', subscription_id)
            .eq('email', email)
            .select()
            .single();
            
        if (error) {
            console.error('Error scheduling subscription cancellation:', error);
            return res.status(500).json({ error: 'Failed to schedule subscription cancellation', details: error.message });
        }
        
        console.log('Subscription cancellation scheduled successfully:', subscription.id, 'effective date:', cancelEffectiveDate.toISOString());
        
        const responseData = { 
            success: true, 
            message: `Subscription will be cancelled at the end of your current billing period (${cancelEffectiveDate.toLocaleDateString()})`,
            subscription: subscription,
            cancellation_effective_date: cancelEffectiveDate.toISOString()
        };
        
        console.log('Sending response:', responseData);
        res.json(responseData);
        
    } catch (error) {
        console.error('Error in /api/subscription/cancel:', error);
        res.status(500).json({ error: 'Failed to schedule subscription cancellation', details: error.message });
    }
});

// API: Reactivate subscription
app.post('/api/subscription/reactivate', async (req, res) => {
    try {
        const { email, subscription_id } = req.body;
        
        if (!email || !subscription_id) {
            return res.status(400).json({ error: 'Email and subscription ID are required' });
        }
        
        console.log('Reactivating subscription:', { email, subscription_id });
        
        // Update subscription to remove cancellation
        const { data: subscription, error } = await supabase
            .from('subscriptions')
            .update({
                status: 'active',
                cancellation_requested_at: null,
                cancellation_effective_date: null,
                cancellation_reason: null,
                updated_at: new Date().toISOString()
            })
            .eq('id', subscription_id)
            .eq('email', email)
            .eq('status', 'pending_cancellation')
            .select()
            .single();
            
        if (error) {
            console.error('Error reactivating subscription:', error);
            return res.status(500).json({ error: 'Failed to reactivate subscription', details: error.message });
        }
        
        if (!subscription) {
            return res.status(404).json({ error: 'Subscription not found or not eligible for reactivation' });
        }
        
        console.log('Subscription reactivated successfully:', subscription.id);
        
        res.json({ 
            success: true, 
            message: 'Subscription reactivated successfully',
            subscription: subscription
        });
        
    } catch (error) {
        console.error('Error in /api/subscription/reactivate:', error);
        res.status(500).json({ error: 'Failed to reactivate subscription', details: error.message });
    }
});

// API: Update subscription plan
app.post('/api/subscription/change-plan', async (req, res) => {
    try {
        const { email, new_plan_type, new_plan_price, token } = req.body;
        
        if (!email || !new_plan_type || !new_plan_price) {
            return res.status(400).json({ error: 'Email, plan type, and price are required' });
        }
        
        console.log('Changing subscription plan:', { email, new_plan_type, new_plan_price });
        
        // Get current subscription
        const { data: currentSub, error: fetchError } = await supabase
            .from('subscriptions')
            .select('*')
            .eq('email', email)
            .eq('status', 'active')
            .order('created_at', { ascending: false })
            .limit(1)
            .single();
            
        if (fetchError || !currentSub) {
            return res.status(404).json({ error: 'No active subscription found' });
        }
        
        // If a payment token is provided, process payment for immediate upgrade
        if (token) {
            const amount = Math.round(parseFloat(new_plan_price) * 100);
            
            const charge = await stripe.charges.create({
                amount: amount,
                currency: 'usd',
                description: `Plan change to ${new_plan_type.charAt(0).toUpperCase() + new_plan_type.slice(1)}`,
                source: token.id,
                receipt_email: email,
                metadata: {
                    plan_change: 'true',
                    old_plan: currentSub.plan_type,
                    new_plan: new_plan_type,
                    customer_email: email
                }
            });
            
            console.log('Plan change payment successful:', charge.id);
        }
        
        // Update subscription in database
        const { data: updatedSub, error: updateError } = await supabase
            .from('subscriptions')
            .update({
                plan_type: new_plan_type,
                plan_price: parseFloat(new_plan_price),
                updated_at: new Date().toISOString()
            })
            .eq('id', currentSub.id)
            .select()
            .single();
            
        if (updateError) {
            console.error('Error updating subscription plan:', updateError);
            return res.status(500).json({ error: 'Failed to update subscription plan', details: updateError.message });
        }
        
        console.log('Subscription plan updated successfully:', updatedSub.id);
        
        res.json({ 
            success: true, 
            message: 'Subscription plan updated successfully',
            subscription: updatedSub
        });
        
    } catch (error) {
        console.error('Error in /api/subscription/change-plan:', error);
        res.status(500).json({ error: 'Failed to change subscription plan', details: error.message });
    }
});

// API: Update payment method
app.post('/api/subscription/update-payment-method', async (req, res) => {
    try {
        const { email, token } = req.body;
        
        if (!email || !token) {
            return res.status(400).json({ error: 'Email and payment token are required' });
        }
        
        console.log('Updating payment method for:', email);
        
        // Get current subscription
        const { data: subscription, error: fetchError } = await supabase
            .from('subscriptions')
            .select('*')
            .eq('email', email)
            .eq('status', 'active')
            .order('created_at', { ascending: false })
            .limit(1)
            .single();
            
        if (fetchError || !subscription) {
            return res.status(404).json({ error: 'No active subscription found' });
        }
        
        // Update payment method in database (store last 4 digits for reference)
        const last4 = token.card ? token.card.last4 : 'Unknown';
        const { data: updatedSub, error: updateError } = await supabase
            .from('subscriptions')
            .update({
                payment_method: 'card',
                payment_method_details: {
                    last4: last4,
                    brand: token.card?.brand || 'Unknown',
                    updated_at: new Date().toISOString()
                },
                updated_at: new Date().toISOString()
            })
            .eq('id', subscription.id)
            .select()
            .single();
            
        if (updateError) {
            console.error('Error updating payment method:', updateError);
            return res.status(500).json({ error: 'Failed to update payment method', details: updateError.message });
        }
        
        console.log('Payment method updated successfully for subscription:', updatedSub.id);
        
        res.json({ 
            success: true, 
            message: 'Payment method updated successfully',
            subscription: updatedSub
        });
        
    } catch (error) {
        console.error('Error in /api/subscription/update-payment-method:', error);
        res.status(500).json({ error: 'Failed to update payment method', details: error.message });
    }
});

// API: Get billing history
app.get('/api/subscription/billing-history/:email', async (req, res) => {
    try {
        const { email } = req.params;
        
        if (!email) {
            return res.status(400).json({ error: 'Email is required' });
        }
        
        console.log('Fetching billing history for:', email);
        
        // Get all subscriptions for this email (including cancelled ones)
        const { data: subscriptions, error } = await supabase
            .from('subscriptions')
            .select('*')
            .eq('email', email)
            .order('created_at', { ascending: false });
            
        if (error) {
            console.error('Error fetching billing history:', error);
            return res.status(500).json({ error: 'Failed to fetch billing history', details: error.message });
        }
        
        // Format billing history
        const billingHistory = subscriptions.map(sub => ({
            id: sub.id,
            date: sub.start_date,
            plan: sub.plan_type,
            amount: sub.plan_price,
            status: sub.status,
            payment_method: sub.payment_method,
            stripe_charge_id: sub.stripe_charge_id
        }));
        
        res.json({ 
            success: true, 
            billingHistory: billingHistory
        });
        
    } catch (error) {
        console.error('Error in /api/subscription/billing-history:', error);
        res.status(500).json({ error: 'Failed to fetch billing history', details: error.message });
    }
});

// API: Submit support request
app.post('/api/support/submit', async (req, res) => {
    try {
        const { email, subject, message, user_name } = req.body;
        
        if (!email || !subject || !message) {
            return res.status(400).json({ error: 'Email, subject, and message are required' });
        }
        
        console.log('Support request received:', { email, subject });
        
        const supportRequest = {
            email,
            subject,
            message,
            user_name: user_name || 'Unknown',
            created_at: new Date().toISOString(),
            status: 'open'
        };
        
        // Log the support request (you could save this to a database)
        console.log('Support request details:', supportRequest);
        
        res.json({ 
            success: true, 
            message: 'Support request submitted successfully. We\'ll get back to you within 24 hours.',
            request_id: Date.now() // Simple ID for demo
        });
        
    } catch (error) {
        console.error('Error in /api/support/submit:', error);
        res.status(500).json({ error: 'Failed to submit support request', details: error.message });
    }
});

// Test endpoint for Supabase connection
app.get('/api/test-supabase', async (req, res) => {
    try {
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

// User Verification Endpoints

// Onfido webhook handler
app.post('/api/onfido/webhook', async (req, res) => {
    try {
        const webhookData = req.body;
        const signature = req.headers['x-sha2-signature'];
        const webhookSecret = process.env.ONFIDO_WEBHOOK_SECRET || config.ONFIDO_WEBHOOK_SECRET;
        
        // Verify webhook signature
        const crypto = require('crypto');
        const expectedSignature = crypto
            .createHmac('sha256', webhookSecret)
            .update(JSON.stringify(webhookData))
            .digest('hex');
            
        if (signature !== expectedSignature) {
            return res.status(401).json({ error: 'Invalid webhook signature' });
        }
        
        const { resource_type, action, object } = webhookData.payload;
        
        if (resource_type === 'check' && action === 'check.completed') {
            // Update verification status based on Onfido check results
            const { data: verification, error } = await supabase
                .from('user_verifications')
                .update({
                    verification_status: object.result === 'clear' ? 'approved' : 'rejected',
                    processed_at: new Date().toISOString(),
                    verified_at: object.result === 'clear' ? new Date().toISOString() : null,
                    processed_by: 'onfido_webhook',
                    third_party_verification_data: {
                        ...object,
                        provider: 'onfido',
                        webhook_received_at: new Date().toISOString()
                    }
                })
                .eq('onfido_check_id', object.id)
                .select()
                .single();
                
            if (error) {
                console.error('Error updating verification from Onfido webhook:', error);
                return res.status(500).json({ error: 'Database update failed' });
            }
            
            console.log('Onfido verification updated:', verification);
        }
        
        res.json({ received: true });
    } catch (error) {
        console.error('Onfido webhook error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Jumio webhook handler
app.post('/api/jumio/callback', async (req, res) => {
    try {
        const callbackData = req.body;
        console.log('Jumio callback received:', callbackData);
        
        const { scanReference, verificationStatus, idScanStatus } = callbackData;
        
        // Determine verification status
        const isApproved = verificationStatus === 'APPROVED_VERIFIED' && idScanStatus === 'SUCCESS';
        const status = isApproved ? 'approved' : 'rejected';
        
        // Extract rejection reasons
        const rejectionReasons = [];
        if (!isApproved) {
            if (callbackData.rejectReason) {
                rejectionReasons.push(callbackData.rejectReason.detailsCode);
            }
            if (callbackData.idScanRejectReason) {
                rejectionReasons.push(callbackData.idScanRejectReason.detailsCode);
            }
        }
        
        // Update verification status
        const { data: verification, error } = await supabase
            .from('user_verifications')
            .update({
                verification_status: status,
                processed_at: new Date().toISOString(),
                verified_at: isApproved ? new Date().toISOString() : null,
                processed_by: 'jumio_webhook',
                rejection_reason: rejectionReasons.join(', ') || null,
                third_party_verification_data: {
                    ...callbackData,
                    provider: 'jumio',
                    callback_received_at: new Date().toISOString()
                }
            })
            .eq('jumio_scan_reference', scanReference)
            .select()
            .single();
            
        if (error) {
            console.error('Error updating verification from Jumio callback:', error);
            return res.status(500).json({ error: 'Database update failed' });
        }
        
        console.log('Jumio verification updated:', verification);
        res.json({ received: true });
    } catch (error) {
        console.error('Jumio callback error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Get user verification status
app.get('/api/verification/status/:email', async (req, res) => {
    try {
        const { email } = req.params;
        
        // Get user verification status
        const { data: user, error: userError } = await supabase
            .from('users')
            .select('is_verified, verification_badge_earned_at')
            .eq('email', email)
            .single();
            
        if (userError) {
            return res.status(404).json({ error: 'User not found' });
        }
        
        // Get latest verification request
        const { data: verification, error: verifyError } = await supabase
            .from('user_verifications')
            .select('*')
            .eq('user_email', email)
            .order('created_at', { ascending: false })
            .limit(1);
            
        res.json({
            isVerified: user.is_verified,
            verificationBadgeEarnedAt: user.verification_badge_earned_at,
            latestVerification: verification.length > 0 ? verification[0] : null
        });
        
    } catch (error) {
        console.error('Verification status error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Submit verification request
app.post('/api/verification/submit', async (req, res) => {
    try {
        const {
            user_email,
            id_document_url,
            id_document_type,
            face_scan_data,
            face_verification_score,
            ip_address,
            user_agent,
            verification_method
        } = req.body;
        
        // Validate required fields
        if (!user_email || !id_document_url || !face_scan_data) {
            return res.status(400).json({ error: 'Missing required verification data' });
        }
        
        // Determine verification method and adjust processing accordingly
        const method = verification_method || 'standard';
        let enhancedScore = face_verification_score || 0.85;
        let verificationStatus = 'pending';
        
        // Enhanced processing for FaceOnLive/professional verification
        if (method === 'enhanced_guided_scanning' || method === 'faceonlive') {
            // Higher confidence threshold for professional verification
            if (face_scan_data.verification_type === 'multi_pose') {
                // Multi-pose verification gets higher trust level
                enhancedScore = Math.min(face_scan_data.average_confidence * 1.1, 1.0);
                
                // Auto-approve high-confidence professional verifications (in production, you might still want manual review)
                if (enhancedScore > 0.95 && face_scan_data.total_poses >= 5) {
                    verificationStatus = 'approved';
                }
            }
        }
        
        const verificationData = {
            user_email,
            id_document_url,
            id_document_type: id_document_type || 'other',
            face_scan_data,
            face_verification_score: enhancedScore,
            ip_address,
            user_agent,
            verification_status: verificationStatus,
            verification_method: method,
            created_at: new Date().toISOString()
        };
        
        // Add auto-approval timestamp if approved
        if (verificationStatus === 'approved') {
            verificationData.verified_at = new Date().toISOString();
            verificationData.processed_at = new Date().toISOString();
            verificationData.processed_by = 'auto_approval_system';
            
            // Set expiry to 1 year from now
            const expiryDate = new Date();
            expiryDate.setFullYear(expiryDate.getFullYear() + 1);
            verificationData.expires_at = expiryDate.toISOString();
        }
        
        const { data, error } = await supabase
            .from('user_verifications')
            .insert([verificationData])
            .select()
            .single();
            
        if (error) {
            throw error;
        }
        
        // Update user verification status if auto-approved
        if (verificationStatus === 'approved') {
            await supabase
                .from('profiles')
                .update({
                    is_verified: true,
                    verification_badge_earned_at: new Date().toISOString()
                })
                .eq('email', user_email);
        }
        
        res.json({ 
            success: true, 
            verification: data,
            message: verificationStatus === 'approved' 
                ? 'Verification completed successfully!'
                : 'Verification request submitted successfully',
            autoApproved: verificationStatus === 'approved'
        });
        
    } catch (error) {
        console.error('Verification submission error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Admin endpoint to approve/reject verification (for testing)
app.post('/api/verification/admin/:id/:action', async (req, res) => {
    try {
        const { id, action } = req.params;
        const { rejection_reason } = req.body;
        
        if (!['approve', 'reject'].includes(action)) {
            return res.status(400).json({ error: 'Invalid action' });
        }
        
        const updateData = {
            verification_status: action === 'approve' ? 'approved' : 'rejected',
            processed_at: new Date().toISOString(),
            processed_by: 'admin'
        };
        
        if (action === 'approve') {
            updateData.verified_at = new Date().toISOString();
            // Set expiry to 1 year from now
            const expiryDate = new Date();
            expiryDate.setFullYear(expiryDate.getFullYear() + 1);
            updateData.expires_at = expiryDate.toISOString();
        } else if (rejection_reason) {
            updateData.rejection_reason = rejection_reason;
        }
        
        const { data, error } = await supabase
            .from('user_verifications')
            .update(updateData)
            .eq('id', id)
            .select()
            .single();
            
        if (error) {
            throw error;
        }
        
        res.json({ 
            success: true, 
            verification: data,
            message: `Verification ${action}d successfully`
        });
        
    } catch (error) {
        console.error('Verification admin action error:', error);
        res.status(500).json({ error: error.message });
    }
});

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
});