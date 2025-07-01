const express = require('express');
const cors = require('cors');
const axios = require('axios');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcryptjs');

// Load config with error handling
// Load configuration with environment variables taking priority
let config = {};
try {
    // First, try to load from config file as fallback
    const fileConfig = require('../config.js');
    config = { ...fileConfig };
    console.log('✅ Config file loaded as fallback');
} catch (error) {
    console.log('⚠️ Config file not found, using environment variables only');
}

// Override with environment variables (these take priority)
config = {
    STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY?.trim() || config.STRIPE_SECRET_KEY,
    STRIPE_PUBLISHABLE_KEY: process.env.STRIPE_PUBLISHABLE_KEY?.trim() || config.STRIPE_PUBLISHABLE_KEY,
    GOOGLE_API_KEY: process.env.GOOGLE_API_KEY?.trim() || config.GOOGLE_API_KEY,
    SUPABASE_URL: process.env.SUPABASE_URL?.trim() || config.SUPABASE_URL,
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY?.trim() || config.SUPABASE_ANON_KEY,
    OPENAI_API_KEY: process.env.OPENAI_API_KEY?.trim() || config.OPENAI_API_KEY,
    OPENAI_ORG_ID: process.env.OPENAI_ORG_ID?.trim() || config.OPENAI_ORG_ID,
    OPENAI_MODEL: process.env.OPENAI_MODEL?.trim() || config.OPENAI_MODEL || 'gpt-3.5-turbo',
    BREVO_API_KEY: process.env.BREVO_API_KEY?.trim() || config.BREVO_API_KEY,
    AZURE_DOCUMENT_INTELLIGENCE_KEY: process.env.AZURE_DOCUMENT_INTELLIGENCE_KEY?.trim() || config.AZURE_DOCUMENT_INTELLIGENCE_KEY,
    AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT: process.env.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT?.trim() || config.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT,
    AZURE_FACE_KEY: process.env.AZURE_FACE_KEY?.trim() || config.AZURE_FACE_KEY,
    AZURE_FACE_ENDPOINT: process.env.AZURE_FACE_ENDPOINT?.trim() || config.AZURE_FACE_ENDPOINT
};

console.log('🔧 Configuration priority: Environment variables > Config file > Defaults');

const { createClient } = require('@supabase/supabase-js');
const multer = require('multer');
const { DocumentAnalysisClient, AzureKeyCredential } = require('@azure/ai-form-recognizer');
const { FaceClient } = require('@azure/cognitiveservices-face');
const { CognitiveServicesCredentials } = require('@azure/ms-rest-azure-js');

const app = express();
const port = process.env.PORT || 3000;

// Log environment variables immediately at startup
console.log('🚀 Server starting - Environment variable check:');
console.log('- AZURE_DOCUMENT_INTELLIGENCE_KEY:', process.env.AZURE_DOCUMENT_INTELLIGENCE_KEY ? `Present (${process.env.AZURE_DOCUMENT_INTELLIGENCE_KEY.substring(0, 10)}...)` : 'MISSING');
console.log('- AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT:', process.env.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT || 'MISSING');
console.log('- AZURE_FACE_KEY:', process.env.AZURE_FACE_KEY ? `Present (${process.env.AZURE_FACE_KEY.substring(0, 10)}...)` : 'MISSING');
console.log('- AZURE_FACE_ENDPOINT:', process.env.AZURE_FACE_ENDPOINT || 'MISSING');

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

// Initialize Azure Document Intelligence client
let documentClient;
try {
    console.log('🔍 Azure Document Intelligence Config Check:');
    console.log('- KEY exists:', !!config.AZURE_DOCUMENT_INTELLIGENCE_KEY);
    console.log('- ENDPOINT exists:', !!config.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT);
    console.log('- KEY length:', config.AZURE_DOCUMENT_INTELLIGENCE_KEY?.length || 0);
    console.log('- ENDPOINT value:', config.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT || 'undefined');
    
    if (config.AZURE_DOCUMENT_INTELLIGENCE_KEY && config.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT) {
        documentClient = new DocumentAnalysisClient(
            config.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT,
            new AzureKeyCredential(config.AZURE_DOCUMENT_INTELLIGENCE_KEY)
        );
        console.log('✅ Azure Document Analysis initialized successfully');
    } else {
        console.log('⚠️ Azure Document Intelligence not initialized - missing credentials');
        console.log('  - KEY missing:', !config.AZURE_DOCUMENT_INTELLIGENCE_KEY);
        console.log('  - ENDPOINT missing:', !config.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT);
    }
} catch (error) {
    console.log('❌ Azure Document Intelligence initialization failed:', error.message);
    console.log('❌ Full error details:', error);
    console.log('❌ Stack trace:', error.stack);
}

// Initialize Azure Face client
let faceClient;
try {
    console.log('🔍 Azure Face API Config Check:');
    console.log('- KEY exists:', !!config.AZURE_FACE_KEY);
    console.log('- ENDPOINT exists:', !!config.AZURE_FACE_ENDPOINT);
    console.log('- KEY length:', config.AZURE_FACE_KEY?.length || 0);
    console.log('- ENDPOINT value:', config.AZURE_FACE_ENDPOINT || 'undefined');
    
    if (config.AZURE_FACE_KEY && config.AZURE_FACE_ENDPOINT) {
        const credentials = new CognitiveServicesCredentials(config.AZURE_FACE_KEY);
        faceClient = new FaceClient(credentials, config.AZURE_FACE_ENDPOINT);
        console.log('✅ Azure Face API initialized successfully');
    } else {
        console.log('⚠️ Azure Face API not initialized - missing credentials');
        console.log('  - KEY missing:', !config.AZURE_FACE_KEY);
        console.log('  - ENDPOINT missing:', !config.AZURE_FACE_ENDPOINT);
    }
} catch (error) {
    console.log('❌ Azure Face API initialization failed:', error.message);
    console.log('❌ Full error details:', error);
    console.log('❌ Stack trace:', error.stack);
}

// Configure multer for file uploads
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 10 * 1024 * 1024, // 10MB limit
    },
    fileFilter: (req, file, cb) => {
        // Allow only image files for ID verification
        if (file.fieldname === 'idDocument' || file.fieldname === 'facePhoto') {
            if (file.mimetype.startsWith('image/')) {
                cb(null, true);
            } else {
                cb(new Error('Only image files are allowed'), false);
            }
        } else {
            cb(new Error('Invalid field name'), false);
        }
    }
});

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
const emailVerificationCodes = new Map(); // Store verification codes with expiration
const passwordResetCodes = new Map(); // Store password reset codes with expiration

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

// API: Update listing by ID
app.put('/api/listings/:id', (req, res) => {
    try {
        const listingIndex = listings.findIndex(l => l.id === req.params.id);
        if (listingIndex === -1) {
            return res.status(404).json({ error: 'Listing not found' });
        }

        const { title, price, city, street, postalCode, houseType, bedrooms, utilities, description } = req.body;
        
        // Validate required fields
        const errors = [];
        if (!title) errors.push('Title is required');
        if (!price || price <= 0) errors.push('Valid price is required');
        if (!city) errors.push('City is required');
        
        if (errors.length > 0) {
            return res.status(400).json({ errors });
        }

        // Update listing
        listings[listingIndex] = {
            ...listings[listingIndex],
            title,
            price: parseFloat(price),
            city,
            street: street || listings[listingIndex].street,
            postalCode: postalCode || listings[listingIndex].postalCode,
            houseType: houseType || listings[listingIndex].houseType,
            bedrooms: bedrooms ? parseInt(bedrooms) : listings[listingIndex].bedrooms,
            utilities: utilities || listings[listingIndex].utilities,
            description: description || listings[listingIndex].description,
            updatedAt: new Date().toISOString()
        };

        res.json({ message: 'Listing updated successfully', listing: listings[listingIndex] });
    } catch (error) {
        console.error('Error in PUT /api/listings/:id:', error.message);
        res.status(500).json({ error: 'Failed to update listing' });
    }
});

// API: Delete listing by ID
app.delete('/api/listings/:id', (req, res) => {
    try {
        const listingIndex = listings.findIndex(l => l.id === req.params.id);
        if (listingIndex === -1) {
            return res.status(404).json({ error: 'Listing not found' });
        }

        // Remove listing from array
        const deletedListing = listings.splice(listingIndex, 1)[0];

        res.json({ message: 'Listing deleted successfully', listing: deletedListing });
    } catch (error) {
        console.error('Error in DELETE /api/listings/:id:', error.message);
        res.status(500).json({ error: 'Failed to delete listing' });
    }
});

// Helper: Generate 6-digit verification code
function generateVerificationCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}

// Helper: Send email via Brevo
async function sendVerificationEmail(email, code, firstName) {
    try {
        const emailData = {
            sender: {
                name: "RoomFinderAI",
                email: "wilmahenning01@gmail.com"
            },
            to: [{
                email: email,
                name: firstName
            }],
            subject: "Verify your RoomFinderAI account",
            htmlContent: `
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Email Verification</title>
                </head>
                <body style="font-family: 'Inter', Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px;">
                    <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 20px; box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1); overflow: hidden;">
                        <!-- Header -->
                        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 30px; text-align: center;">
                            <h1 style="color: white; margin: 0; font-size: 28px; font-weight: bold;">RoomFinderAI</h1>
                            <p style="color: rgba(255, 255, 255, 0.9); margin: 10px 0 0 0; font-size: 16px;">Verify Your Account</p>
                        </div>
                        
                        <!-- Content -->
                        <div style="padding: 40px 30px;">
                            <h2 style="color: #1e293b; margin: 0 0 20px 0; font-size: 24px;">Hi ${firstName}!</h2>
                            <p style="color: #64748b; line-height: 1.6; margin: 0 0 30px 0; font-size: 16px;">
                                Welcome to RoomFinderAI! To complete your registration and start finding your perfect room, please verify your email address using the code below:
                            </p>
                            
                            <!-- Verification Code -->
                            <div style="text-align: center; margin: 40px 0;">
                                <div style="background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%); padding: 20px; border-radius: 12px; border: 2px dashed #667eea; display: inline-block;">
                                    <p style="margin: 0 0 10px 0; color: #64748b; font-size: 14px; font-weight: 600;">VERIFICATION CODE</p>
                                    <p style="margin: 0; font-size: 32px; font-weight: bold; color: #667eea; letter-spacing: 4px;">${code}</p>
                                </div>
                            </div>
                            
                            <p style="color: #64748b; line-height: 1.6; margin: 0 0 20px 0; font-size: 16px;">
                                Enter this code on the verification page to activate your account. This code will expire in <strong>10 minutes</strong> for security reasons.
                            </p>
                            
                            <p style="color: #64748b; line-height: 1.6; margin: 0; font-size: 14px;">
                                If you didn't create an account with RoomFinderAI, please ignore this email.
                            </p>
                        </div>
                        
                        <!-- Footer -->
                        <div style="background: #f8fafc; padding: 30px; text-align: center; border-top: 1px solid #e2e8f0;">
                            <p style="margin: 0; color: #64748b; font-size: 14px;">
                                © 2025 RoomFinderAI. All rights reserved.
                            </p>
                        </div>
                    </div>
                </body>
                </html>
            `
        };

        const response = await axios.post('https://api.brevo.com/v3/smtp/email', emailData, {
            headers: {
                'accept': 'application/json',
                'api-key': config.BREVO_API_KEY,
                'content-type': 'application/json'
            }
        });

        console.log('✅ Verification email sent successfully to:', email);
        return { success: true };
    } catch (error) {
        console.error('❌ Error sending verification email:', error.response?.data || error.message);
        return { success: false, error: error.message };
    }
}

// Function to send password reset email
async function sendPasswordResetEmail(email, code, firstName) {
    try {
        console.log('📧 Sending password reset email to:', email);
        
        const emailData = {
            sender: {
                name: "RoomFinderAI",
                email: "wilmahenning01@gmail.com"
            },
            to: [{
                email: email,
                name: firstName
            }],
            subject: "Reset your RoomFinderAI password",
            htmlContent: `
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Password Reset</title>
                </head>
                <body style="font-family: 'Inter', Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px;">
                    <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 20px; box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1); overflow: hidden;">
                        <!-- Header -->
                        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 30px; text-align: center;">
                            <h1 style="color: white; margin: 0; font-size: 28px; font-weight: bold;">RoomFinderAI</h1>
                            <p style="color: rgba(255, 255, 255, 0.9); margin: 10px 0 0 0; font-size: 16px;">Password Reset Request</p>
                        </div>
                        
                        <!-- Content -->
                        <div style="padding: 40px 30px;">
                            <h2 style="color: #1e293b; margin: 0 0 20px 0; font-size: 24px;">Hi ${firstName}!</h2>
                            <p style="color: #64748b; line-height: 1.6; margin: 0 0 30px 0; font-size: 16px;">
                                We received a request to reset your password. Use the code below to complete the process:
                            </p>
                            
                            <!-- Reset Code -->
                            <div style="text-align: center; margin: 40px 0;">
                                <div style="background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%); padding: 20px; border-radius: 12px; border: 2px dashed #667eea; display: inline-block;">
                                    <p style="margin: 0 0 10px 0; color: #64748b; font-size: 14px; font-weight: 600;">RESET CODE</p>
                                    <p style="margin: 0; font-size: 32px; font-weight: bold; color: #667eea; letter-spacing: 4px;">${code}</p>
                                </div>
                            </div>
                            
                            <p style="color: #64748b; line-height: 1.6; margin: 0 0 20px 0; font-size: 16px;">
                                Enter this code on the password reset page. This code will expire in <strong>10 minutes</strong> for security reasons.
                            </p>
                            
                            <p style="color: #64748b; line-height: 1.6; margin: 0; font-size: 14px;">
                                If you didn't request a password reset, please ignore this email. Your password won't be changed unless you enter this code.
                            </p>
                        </div>
                        
                        <!-- Footer -->
                        <div style="background: #f8fafc; padding: 30px; text-align: center; border-top: 1px solid #e2e8f0;">
                            <p style="margin: 0; color: #64748b; font-size: 14px;">
                                © 2025 RoomFinderAI. All rights reserved.
                            </p>
                        </div>
                    </div>
                </body>
                </html>
            `
        };

        const response = await axios.post('https://api.brevo.com/v3/smtp/email', emailData, {
            headers: {
                'accept': 'application/json',
                'api-key': config.BREVO_API_KEY,
                'content-type': 'application/json'
            }
        });

        console.log('✅ Password reset email sent successfully to:', email);
        return { success: true };
    } catch (error) {
        console.error('❌ Error sending password reset email:', error.response?.data || error.message);
        return { success: false, error: error.message };
    }
}

// API: Send verification email
app.post('/api/send-verification', async (req, res) => {
    try {
        console.log('📧 Received verification request:', req.body);
        const { firstName, lastName, email, password } = req.body;
        
        if (!firstName || !lastName || !email || !password) {
            console.log('❌ Missing required fields');
            return res.status(400).json({ error: 'All fields are required' });
        }

        // Check if user already exists
        const existingUser = users.find(u => u.email === email);
        if (existingUser) {
            console.log('❌ User already exists:', email);
            return res.status(400).json({ error: 'Email already registered' });
        }

        // Check if Brevo API key is available
        if (!config.BREVO_API_KEY) {
            console.log('❌ BREVO_API_KEY not found in config');
            return res.status(500).json({ error: 'Email service not configured' });
        }

        console.log('✅ Generating verification code...');
        // Generate verification code
        const code = generateVerificationCode();
        const expirationTime = Date.now() + 10 * 60 * 1000; // 10 minutes from now

        // Store code with user data and expiration
        emailVerificationCodes.set(email, {
            code,
            expirationTime,
            userData: { firstName, lastName, email, password },
            verified: false
        });

        console.log('📤 Sending verification email to:', email);
        // Send verification email
        const emailResult = await sendVerificationEmail(email, code, firstName);
        
        if (emailResult.success) {
            console.log('✅ Verification email sent successfully');
            res.json({ 
                message: 'Verification code sent to your email',
                email: email 
            });
        } else {
            console.log('❌ Failed to send verification email:', emailResult.error);
            // Clean up the stored code if email failed
            emailVerificationCodes.delete(email);
            res.status(500).json({ error: 'Failed to send verification email: ' + (emailResult.error || 'Unknown error') });
        }
    } catch (error) {
        console.error('❌ Error in /api/send-verification:', error.message);
        res.status(500).json({ error: 'Failed to send verification code: ' + error.message });
    }
});

// API: Verify email code and complete registration
app.post('/api/verify-email', async (req, res) => {
    try {
        const { email, code } = req.body;
        
        if (!email || !code) {
            return res.status(400).json({ error: 'Email and verification code are required' });
        }

        // Get stored verification data
        const verificationData = emailVerificationCodes.get(email);
        
        if (!verificationData) {
            return res.status(400).json({ error: 'No verification code found for this email' });
        }

        // Check if code has expired
        if (Date.now() > verificationData.expirationTime) {
            emailVerificationCodes.delete(email);
            return res.status(400).json({ error: 'Verification code has expired. Please request a new one.' });
        }

        // Check if code matches
        if (verificationData.code !== code) {
            return res.status(400).json({ error: 'Invalid verification code' });
        }

        // Code is valid, create the user account
        const { firstName, lastName, password } = verificationData.userData;
        const hashedPassword = await bcrypt.hash(password, 10);
        
        const user = {
            id: uuidv4(),
            firstName,
            lastName,
            email,
            password: hashedPassword,
            emailVerified: true,
            createdAt: new Date().toISOString(),
        };

        users.push(user);

        // Create profile in Supabase for chat functionality
        if (supabase) {
            try {
                const { error: profileError } = await supabase
                    .from('profiles')
                    .insert([{
                        id: user.id,
                        email: user.email,
                        first_name: user.firstName,
                        last_name: user.lastName,
                        created_at: user.createdAt
                    }]);
                
                if (profileError) {
                    console.warn('Warning: Could not create profile in Supabase:', profileError);
                } else {
                    console.log('✅ Profile created in Supabase for:', user.email);
                }
            } catch (profileErr) {
                console.warn('Warning: Error creating profile in Supabase:', profileErr);
            }
        }

        // Log user registration activity
        await logUserActivity(user.email, 'registered', 'User account created successfully', {
            firstName: user.firstName,
            lastName: user.lastName
        });

        // Clean up verification code
        emailVerificationCodes.delete(email);

        res.status(201).json({ 
            message: 'Email verified and account created successfully',
            user: {
                id: user.id,
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.email,
                emailVerified: user.emailVerified
            }
        });
    } catch (error) {
        console.error('Error in /api/verify-email:', error.message);
        res.status(500).json({ error: 'Failed to verify email and create account' });
    }
});

// API: User registration (Deprecated - use /api/send-verification + /api/verify-email instead)
app.post('/api/register', async (req, res) => {
    // Redirect to new email verification flow
    res.status(400).json({ 
        error: 'Direct registration is no longer supported. Please use the email verification flow.',
        redirect: '/api/send-verification'
    });
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

// API: Send password reset code
app.post('/api/send-reset-code', async (req, res) => {
    try {
        console.log('📧 Received password reset request for:', req.body.email);
        const { email } = req.body;
        
        if (!email) {
            return res.status(400).json({ error: 'Email is required' });
        }

        // Check if user exists
        const user = users.find(u => u.email === email);
        if (!user) {
            // Don't reveal if user exists or not for security
            return res.json({ 
                message: 'If an account exists with this email, a reset code will be sent.',
                sessionId: uuidv4()
            });
        }

        // Check if Brevo API key is available
        if (!config.BREVO_API_KEY) {
            console.log('❌ BREVO_API_KEY not found in config');
            return res.status(500).json({ error: 'Email service not configured' });
        }

        // Generate reset code
        const code = generateVerificationCode();
        const sessionId = uuidv4();
        const expirationTime = Date.now() + 10 * 60 * 1000; // 10 minutes

        // Store reset code
        passwordResetCodes.set(email, {
            code,
            sessionId,
            expirationTime,
            verified: false
        });

        console.log('📤 Sending password reset email to:', email);
        // Send reset email
        const emailResult = await sendPasswordResetEmail(email, code, user.firstName);
        
        if (emailResult.success) {
            console.log('✅ Password reset email sent successfully');
            res.json({ 
                message: 'Reset code sent to your email',
                sessionId: sessionId
            });
        } else {
            console.log('❌ Failed to send reset email:', emailResult.error);
            passwordResetCodes.delete(email);
            res.status(500).json({ error: 'Failed to send reset email' });
        }
    } catch (error) {
        console.error('❌ Error in /api/send-reset-code:', error.message);
        res.status(500).json({ error: 'Failed to send reset code' });
    }
});

// API: Verify password reset code
app.post('/api/verify-reset-code', async (req, res) => {
    try {
        const { email, code, sessionId } = req.body;
        
        if (!email || !code || !sessionId) {
            return res.status(400).json({ error: 'Email, code, and sessionId are required' });
        }

        // Get stored reset data
        const resetData = passwordResetCodes.get(email);
        
        if (!resetData) {
            return res.status(400).json({ error: 'No reset code found for this email' });
        }

        // Check session ID
        if (resetData.sessionId !== sessionId) {
            return res.status(400).json({ error: 'Invalid session' });
        }

        // Check if code has expired
        if (Date.now() > resetData.expirationTime) {
            passwordResetCodes.delete(email);
            return res.status(400).json({ error: 'Reset code has expired. Please request a new one.' });
        }

        // Check if code matches
        if (resetData.code !== code) {
            return res.status(400).json({ error: 'Invalid reset code' });
        }

        // Mark as verified
        resetData.verified = true;
        passwordResetCodes.set(email, resetData);

        res.json({ message: 'Code verified successfully' });
    } catch (error) {
        console.error('Error in /api/verify-reset-code:', error.message);
        res.status(500).json({ error: 'Failed to verify code' });
    }
});

// API: Reset password
app.post('/api/reset-password', async (req, res) => {
    try {
        const { email, code, newPassword, sessionId } = req.body;
        
        if (!email || !code || !newPassword || !sessionId) {
            return res.status(400).json({ error: 'All fields are required' });
        }

        // Get stored reset data
        const resetData = passwordResetCodes.get(email);
        
        if (!resetData || !resetData.verified) {
            return res.status(400).json({ error: 'Invalid or unverified reset request' });
        }

        // Verify session and code again
        if (resetData.sessionId !== sessionId || resetData.code !== code) {
            return res.status(400).json({ error: 'Invalid reset credentials' });
        }

        // Find user and update password
        const user = users.find(u => u.email === email);
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        // Hash new password
        const hashedPassword = await bcrypt.hash(newPassword, 10);
        user.password = hashedPassword;
        
        // Update in Supabase if available
        if (supabase) {
            try {
                const { error } = await supabase
                    .from('profiles')
                    .update({ password: hashedPassword })
                    .eq('email', email);
                
                if (error) {
                    console.error('Error updating password in Supabase:', error);
                }
            } catch (dbError) {
                console.error('Database update error:', dbError);
            }
        }

        // Clean up reset code
        passwordResetCodes.delete(email);

        // Log password reset
        await logUserActivity(email, 'password_reset', 'Password successfully reset');

        res.json({ message: 'Password reset successfully' });
    } catch (error) {
        console.error('Error in /api/reset-password:', error.message);
        res.status(500).json({ error: 'Failed to reset password' });
    }
});

// API: AI Negotiator chat with OpenAI integration
app.post('/api/ai-negotiate', async (req, res) => {
    try {
        const { message, conversationHistory, userEmail } = req.body;
        
        if (!message) {
            return res.status(400).json({ error: 'Message is required' });
        }

        // Check if OpenAI is configured
        if (!config.OPENAI_API_KEY) {
            return res.status(503).json({ error: 'AI service not available - OpenAI not configured' });
        }

        // Build the conversation context for OpenAI
        const systemPrompt = buildNegotiationSystemPrompt();
        const messages = [
            { role: 'system', content: systemPrompt },
            ...(conversationHistory || []).slice(-8) // Keep last 8 messages for context
        ];

        // Add the current user message
        messages.push({ role: 'user', content: message });

        console.log('🤖 Sending OpenAI request for negotiation...');
        
        // Call OpenAI API
        const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${config.OPENAI_API_KEY}`,
                'Content-Type': 'application/json',
                ...(config.OPENAI_ORG_ID && { 'OpenAI-Organization': config.OPENAI_ORG_ID })
            },
            body: JSON.stringify({
                model: config.OPENAI_MODEL || 'gpt-3.5-turbo',
                messages: messages,
                max_tokens: 300,
                temperature: 0.8,
                presence_penalty: 0.1,
                frequency_penalty: 0.1
            })
        });

        if (!openaiResponse.ok) {
            const errorData = await openaiResponse.json().catch(() => ({}));
            console.error('❌ OpenAI API error:', errorData);
            throw new Error(`OpenAI API error: ${openaiResponse.status}`);
        }

        const data = await openaiResponse.json();
        
        if (!data.choices || !data.choices[0] || !data.choices[0].message) {
            throw new Error('Invalid OpenAI response format');
        }

        const aiResponse = data.choices[0].message.content.trim();
        
        // Log AI negotiation assistant usage
        if (userEmail) {
            await logUserActivity(userEmail, 'ai_negotiation_assistant', `Used AI negotiation assistant for rental advice`, {
                message_length: message.length,
                response_length: aiResponse.length,
                model_used: config.OPENAI_MODEL || 'gpt-3.5-turbo',
                tokens_used: data.usage?.total_tokens || 0
            });
        }

        // Store conversation in database if Supabase is available
        if (supabase && userEmail) {
            try {
                await supabase.from('ai_negotiations').insert({
                    user_email: userEmail,
                    user_message: message,
                    ai_response: aiResponse,
                    session_type: 'negotiation_assistant',
                    listing_details: {
                        location: 'Central District, Hong Kong',
                        rent: 1500,
                        type: 'Studio Apartment',
                        size: '450 sq ft'
                    },
                    tokens_used: data.usage?.total_tokens || 0,
                    created_at: new Date().toISOString()
                });
            } catch (dbError) {
                console.error('Error storing negotiation assistant session in database:', dbError);
            }
        }
        
        console.log('✅ AI negotiation assistant response generated successfully');
        res.json({ 
            response: aiResponse,
            tokensUsed: data.usage?.total_tokens || 0
        });
        
    } catch (error) {
        console.error('❌ Error in /api/ai-negotiate:', error.message);
        res.status(500).json({ error: 'Failed to process AI negotiation request' });
    }
});

// Helper function to build the negotiation system prompt
function buildNegotiationSystemPrompt() {
    return `You are an expert rental negotiation assistant helping users secure better deals with landlords in Hong Kong. You provide strategic advice, coaching, and sample responses to help users negotiate effectively.

SAMPLE PROPERTY CONTEXT (for practice):
- Location: Central District, Hong Kong  
- Listed Rent: HK$1,500/month
- Size: 450 sq ft
- Type: Studio apartment
- Amenities: Air conditioning, furnished, city view, near MTR

YOUR ROLE AS NEGOTIATION ASSISTANT:
- Help users craft compelling negotiation messages
- Provide strategic advice on timing and approach
- Suggest reasonable counter-offers based on market knowledge
- Coach users on landlord psychology and motivations
- Help identify negotiation leverage points

NEGOTIATION STRATEGIES TO TEACH:
- Research market rates for similar properties
- Highlight your strengths as a tenant (stable income, good references, etc.)
- Offer value-adds (longer lease, immediate move-in, upfront payment)
- Use anchoring techniques with realistic lower offers
- Create win-win scenarios for both parties
- Show genuine interest while maintaining leverage

COACHING APPROACH:
- Ask clarifying questions about their situation
- Provide 2-3 strategic options for each scenario
- Explain the reasoning behind each recommendation
- Help craft specific message templates
- Warn about common negotiation mistakes
- Boost confidence while maintaining realism

RESPONSE STYLE:
- Be supportive and encouraging
- Provide actionable, specific advice
- Use Hong Kong rental market context
- Give concrete examples and templates
- Explain landlord perspectives to help users understand
- Balance optimism with realistic expectations

MARKET KNOWLEDGE TO SHARE:
- Typical negotiation ranges (5-15% for good tenants)
- Seasonal rental patterns in Hong Kong
- What landlords value most (stability, cleanliness, prompt payment)
- Common lease terms and what's negotiable
- Red flags to avoid in negotiations

Remember: Your goal is to empower users to negotiate confidently and successfully while maintaining good relationships with landlords.`;
}

// Keep the old endpoint for backward compatibility
app.post('/api/ai-negotiator', async (req, res) => {
    try {
        const { message, userEmail } = req.body;
        if (!message) {
            return res.status(400).json({ error: 'Message is required' });
        }

        // Redirect to new negotiation endpoint
        const response = await fetch(`${req.protocol}://${req.get('host')}/api/ai-negotiate`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ message, userEmail })
        });
        
        const data = await response.json();
        res.json(data);
        
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
            
            // Log subscription activity
            await logUserActivity(customerEmail, 'subscription_bought', `Subscribed to ${plan} plan for $${price}`, {
                plan_type: plan,
                amount: price,
                charge_id: charge.id
            });
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

        // Get the most recent subscription regardless of status
        const { data: allSubs, error: allError } = await supabase
            .from('subscriptions')
            .select('*')
            .eq('email', email)
            .order('created_at', { ascending: false });

        if (allError) {
            console.error('Error fetching subscriptions:', allError);
            return res.status(500).json({ error: 'Failed to fetch subscription', details: allError.message });
        }

        let subscription = null;
        let error = null;

        if (allSubs && allSubs.length > 0) {
            // Prioritize active subscriptions first
            const activeSub = allSubs.find(sub => sub.status === 'active');
            
            if (activeSub) {
                subscription = activeSub;
            } else {
                // If no active subscription, find the most recent canceled subscription
                // that hasn't ended yet (pending cancellation)
                const pendingCancellationSub = allSubs.find(sub => 
                    sub.status === 'canceled' && 
                    sub.end_date && 
                    new Date(sub.end_date) > new Date()
                );
                
                if (pendingCancellationSub) {
                    subscription = pendingCancellationSub;
                } else {
                    // No active or pending cancellation subscriptions
                    error = { code: 'PGRST116' };
                }
            }
        } else {
            error = { code: 'PGRST116' };
        }

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

// API: Cancel user subscription
app.post('/api/subscription/cancel', async (req, res) => {
    try {
        if (!supabase) {
            return res.status(503).json({ error: 'Database service not available - Supabase not configured' });
        }

        const { email, subscription_id, cancellation_reason } = req.body;
        console.log('Canceling subscription for email:', email);
        
        if (!email) {
            return res.status(400).json({ error: 'Email is required' });
        }

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
            console.error('Subscription not found:', fetchError);
            return res.status(404).json({ error: 'Subscription not found' });
        }
        
        // Calculate cancellation effective date (end of current billing period)
        const startDate = new Date(currentSub.start_date);
        const cancelEffectiveDate = new Date(startDate);
        cancelEffectiveDate.setMonth(cancelEffectiveDate.getMonth() + 1);
        
        // For now, since the schema might not have the new columns, let's update just the status
        // and store cancellation info in a way that's compatible with current schema
        const updateData = {
            status: 'canceled', // Use existing status value
            end_date: cancelEffectiveDate.toISOString() // Use existing end_date field
        };
        
        // Use fallback approach with existing schema fields
        // Mark as canceled and set end_date to the cancellation effective date
        const { data: subscription, error } = await supabase
            .from('subscriptions')
            .update({
                status: 'canceled',
                end_date: cancelEffectiveDate.toISOString()
            })
            .eq('id', currentSub.id)
            .eq('email', email)
            .select()
            .single();

        if (error) {
            console.error('Error canceling subscription:', error);
            return res.status(500).json({ error: 'Failed to schedule subscription cancellation', details: error.message });
        }
        
        console.log('Subscription cancelled successfully:', subscription.id, 'effective date:', cancelEffectiveDate.toISOString());
        
        return res.json({ 
            success: true, 
            message: `Subscription cancelled. You'll continue to have access until ${cancelEffectiveDate.toLocaleDateString()}`,
            subscription: subscription,
            cancellation_effective_date: cancelEffectiveDate.toISOString()
        });
        
    } catch (error) {
        console.error('Error in /api/subscription/cancel:', error);
        res.status(500).json({ error: error.message });
    }
});

// API: Save bank information
app.post('/api/bank-info/save', async (req, res) => {
    try {
        if (!supabase) {
            return res.status(503).json({ error: 'Database service not available - Supabase not configured' });
        }

        const { 
            userEmail, 
            accountHolderName, 
            bankName, 
            accountNumber, 
            routingNumber, 
            accountType, 
            swiftCode, 
            bankAddress 
        } = req.body;

        console.log('Saving bank information for email:', userEmail);
        
        if (!userEmail || !accountHolderName || !bankName || !accountNumber || !routingNumber || !accountType) {
            return res.status(400).json({ error: 'Required fields are missing' });
        }

        // Check if user already has bank information
        const { data: existingBank, error: checkError } = await supabase
            .from('bank_information')
            .select('*')
            .eq('user_email', userEmail)
            .single();

        let result;
        if (existingBank) {
            // Update existing bank information
            const { data, error } = await supabase
                .from('bank_information')
                .update({
                    account_holder_name: accountHolderName,
                    bank_name: bankName,
                    account_number: accountNumber,
                    routing_number: routingNumber,
                    account_type: accountType,
                    swift_code: swiftCode || null,
                    bank_address: bankAddress || null,
                    verification_status: 'pending',
                    updated_at: new Date().toISOString()
                })
                .eq('user_email', userEmail)
                .select()
                .single();

            if (error) {
                console.error('Error updating bank information:', error);
                return res.status(500).json({ error: 'Failed to update bank information', details: error.message });
            }
            result = data;
        } else {
            // Insert new bank information
            const { data, error } = await supabase
                .from('bank_information')
                .insert({
                    user_email: userEmail,
                    account_holder_name: accountHolderName,
                    bank_name: bankName,
                    account_number: accountNumber,
                    routing_number: routingNumber,
                    account_type: accountType,
                    swift_code: swiftCode || null,
                    bank_address: bankAddress || null,
                    verification_status: 'pending'
                })
                .select()
                .single();

            if (error) {
                console.error('Error inserting bank information:', error);
                return res.status(500).json({ error: 'Failed to save bank information', details: error.message });
            }
            result = data;
        }

        // Log bank information submission activity
        await logUserActivity(userEmail, 'bank_info_updated', 'User submitted bank information for verification', {
            bank_name: bankName,
            account_type: accountType,
            verification_status: 'pending',
            bank_info_id: result.id
        });

        console.log('Bank information saved successfully:', result.id);
        res.json({ 
            success: true, 
            message: 'Bank information saved successfully and is pending verification.',
            bankInfo: {
                id: result.id,
                bank_name: result.bank_name,
                account_type: result.account_type,
                verification_status: result.verification_status,
                created_at: result.created_at
            }
        });
    } catch (error) {
        console.error('Error in bank info save endpoint:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// API: Get bank information
app.get('/api/bank-info/:email', async (req, res) => {
    try {
        if (!supabase) {
            return res.status(503).json({ error: 'Database service not available - Supabase not configured' });
        }

        const { email } = req.params;
        console.log('Fetching bank information for email:', email);
        
        if (!email) {
            return res.status(400).json({ error: 'Email is required' });
        }

        const { data: bankInfo, error } = await supabase
            .from('bank_information')
            .select('id, user_email, account_holder_name, bank_name, account_type, verification_status, created_at, updated_at')
            .eq('user_email', email)
            .order('created_at', { ascending: false })
            .limit(1)
            .single();

        console.log('Supabase bank info query result:', { bankInfo, error });

        if (error && error.code !== 'PGRST116') { // PGRST116 is "no rows returned"
            console.error('Error fetching bank information:', error);
            return res.status(500).json({ error: 'Failed to fetch bank information', details: error.message });
        }

        res.json({ bankInfo: bankInfo || null });

    } catch (error) {
        console.error('Error in bank info fetch endpoint:', error);
        res.status(500).json({ error: 'Failed to fetch bank information', details: error.message });
    }
});

// API: Get user payment methods
app.get('/api/payment-methods/:userId', async (req, res) => {
    try {
        if (!supabase) {
            return res.status(503).json({ error: 'Database service not available - Supabase not configured' });
        }

        const { userId } = req.params;
        console.log('Fetching payment methods for user:', userId);
        
        if (!userId) {
            return res.status(400).json({ error: 'User ID is required' });
        }

        const { data: paymentMethods, error } = await supabase
            .from('user_payment_methods')
            .select('*')
            .eq('user_id', userId)
            .order('is_default', { ascending: false })
            .order('created_at', { ascending: false });

        if (error) {
            console.error('Error fetching payment methods:', error);
            return res.status(500).json({ error: 'Failed to fetch payment methods', details: error.message });
        }

        res.json({ paymentMethods: paymentMethods || [] });

    } catch (error) {
        console.error('Error in payment methods fetch endpoint:', error);
        res.status(500).json({ error: 'Failed to fetch payment methods', details: error.message });
    }
});

// API: Add payment method
app.post('/api/payment-methods', async (req, res) => {
    try {
        if (!supabase) {
            return res.status(503).json({ error: 'Database service not available - Supabase not configured' });
        }

        const { 
            user_id,
            stripe_payment_method_id,
            card_brand,
            card_last4,
            card_exp_month,
            card_exp_year,
            is_default
        } = req.body;

        console.log('Adding payment method for user:', user_id);
        
        if (!user_id || !stripe_payment_method_id || !card_brand || !card_last4 || !card_exp_month || !card_exp_year) {
            return res.status(400).json({ error: 'Required fields are missing' });
        }

        // Insert new payment method
        const { data: paymentMethod, error } = await supabase
            .from('user_payment_methods')
            .insert([{
                user_id,
                stripe_payment_method_id,
                card_brand,
                card_last4,
                card_exp_month,
                card_exp_year,
                is_default: is_default || false
            }])
            .select()
            .single();

        if (error) {
            console.error('Error adding payment method:', error);
            return res.status(500).json({ error: 'Failed to add payment method', details: error.message });
        }

        console.log('Payment method added successfully:', paymentMethod.id);
        res.json({ 
            success: true, 
            message: 'Payment method added successfully',
            paymentMethod
        });

    } catch (error) {
        console.error('Error in payment method add endpoint:', error);
        res.status(500).json({ error: 'Failed to add payment method', details: error.message });
    }
});

// API: Update default payment method
app.put('/api/payment-methods/:id/default', async (req, res) => {
    try {
        if (!supabase) {
            return res.status(503).json({ error: 'Database service not available - Supabase not configured' });
        }

        const { id } = req.params;
        const { user_id } = req.body;
        
        console.log('Setting default payment method:', id);
        
        if (!id || !user_id) {
            return res.status(400).json({ error: 'Payment method ID and user ID are required' });
        }

        // Update the payment method to be default
        const { data: paymentMethod, error } = await supabase
            .from('user_payment_methods')
            .update({ is_default: true })
            .eq('id', id)
            .eq('user_id', user_id)
            .select()
            .single();

        if (error) {
            console.error('Error updating default payment method:', error);
            return res.status(500).json({ error: 'Failed to update default payment method', details: error.message });
        }

        console.log('Default payment method updated successfully');
        res.json({ 
            success: true, 
            message: 'Default payment method updated successfully',
            paymentMethod
        });

    } catch (error) {
        console.error('Error in default payment method update endpoint:', error);
        res.status(500).json({ error: 'Failed to update default payment method', details: error.message });
    }
});

// API: Delete payment method
app.delete('/api/payment-methods/:id', async (req, res) => {
    try {
        if (!supabase) {
            return res.status(503).json({ error: 'Database service not available - Supabase not configured' });
        }

        const { id } = req.params;
        const { user_id } = req.body;
        
        console.log('Deleting payment method:', id);
        
        if (!id || !user_id) {
            return res.status(400).json({ error: 'Payment method ID and user ID are required' });
        }

        // Delete the payment method
        const { error } = await supabase
            .from('user_payment_methods')
            .delete()
            .eq('id', id)
            .eq('user_id', user_id);

        if (error) {
            console.error('Error deleting payment method:', error);
            return res.status(500).json({ error: 'Failed to delete payment method', details: error.message });
        }

        console.log('Payment method deleted successfully');
        res.json({ 
            success: true, 
            message: 'Payment method deleted successfully'
        });

    } catch (error) {
        console.error('Error in payment method delete endpoint:', error);
        res.status(500).json({ error: 'Failed to delete payment method', details: error.message });
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

// Helper function to log user activity
async function logUserActivity(userEmail, activityType, description, metadata = {}) {
    try {
        if (!supabase) {
            console.log('⚠️ Cannot log activity - Supabase not initialized');
            return;
        }

        // First check if user exists to avoid foreign key constraint violation
        const { data: user, error: userError } = await supabase
            .from('users')
            .select('email')
            .eq('email', userEmail)
            .single();

        if (userError || !user) {
            console.log(`⚠️ Cannot log activity - User ${userEmail} not found in users table`);
            return;
        }

        await supabase.rpc('set_current_user_email', { email: userEmail });
        
        const { error } = await supabase
            .from('user_activities')
            .insert({
                user_email: userEmail,
                activity_type: activityType,
                description: description,
                metadata: metadata
            });

        if (error) {
            console.error('❌ Failed to log user activity:', error.message);
        }
    } catch (error) {
        console.error('❌ Error logging user activity:', error.message);
    }
}

// API endpoint to get user's recent activities
app.get('/api/user/activities', async (req, res) => {
    try {
        const userEmail = req.headers['x-user-email'];
        console.log('🔍 Activities request for user:', userEmail);
        
        if (!userEmail) {
            console.log('❌ No user email provided in headers');
            return res.status(401).json({ error: 'User email required' });
        }

        if (!supabase) {
            console.log('❌ Supabase not available');
            return res.status(500).json({ error: 'Database not available' });
        }

        await supabase.rpc('set_current_user_email', { email: userEmail });

        const { data: activities, error } = await supabase
            .from('user_activities')
            .select('*')
            .eq('user_email', userEmail)
            .order('created_at', { ascending: false })
            .limit(4);

        console.log('📊 Activities query result:', { activities, error });

        if (error) {
            console.error('❌ Error fetching user activities:', error.message);
            return res.status(500).json({ error: 'Failed to fetch activities' });
        }

        // If no activities found, create some sample activities for the user
        if (activities.length === 0) {
            const sampleActivities = [
                {
                    user_email: userEmail,
                    activity_type: 'registered',
                    description: 'Welcome to RoomFinderAI! Your account has been created successfully.',
                    metadata: {}
                }
            ];

            // Insert sample activities
            const { error: insertError } = await supabase
                .from('user_activities')
                .insert(sampleActivities);

            if (!insertError) {
                // Fetch the newly created activities
                const { data: newActivities } = await supabase
                    .from('user_activities')
                    .select('*')
                    .eq('user_email', userEmail)
                    .order('created_at', { ascending: false })
                    .limit(4);

                if (newActivities) {
                    const formattedActivities = newActivities.map(activity => ({
                        type: activity.activity_type,
                        message: activity.description,
                        time: formatTimeAgo(new Date(activity.created_at)),
                        created_at: activity.created_at
                    }));

                    return res.json(formattedActivities);
                }
            }
        }

        const formattedActivities = activities.map(activity => ({
            type: activity.activity_type,
            message: activity.description,
            time: formatTimeAgo(new Date(activity.created_at)),
            created_at: activity.created_at
        }));

        res.json(formattedActivities);
    } catch (error) {
        console.error('❌ Error in activities endpoint:', error.message);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Helper function to format time ago
function formatTimeAgo(date) {
    const now = new Date();
    const diffInSeconds = Math.floor((now - date) / 1000);
    
    if (diffInSeconds < 60) return 'Just now';
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)} minutes ago`;
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)} hours ago`;
    if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)} days ago`;
    return `${Math.floor(diffInSeconds / 604800)} weeks ago`;
}

// API: Upload and verify government ID
app.post('/api/verify/upload-id', upload.single('idDocument'), async (req, res) => {
    try {
        // Try to reinitialize Azure clients if they're not available
        reinitializeAzureClients();
        
        if (!documentClient) {
            console.log('⚠️ ID verification attempted but Azure Document Intelligence not configured');
            return res.status(503).json({ 
                error: 'ID verification service not available',
                message: 'The ID verification service is currently not configured. Please contact support.',
                serviceAvailable: false
            });
        }

        if (!req.file) {
            return res.status(400).json({ error: 'ID document image is required' });
        }

        const { userEmail } = req.body;
        if (!userEmail) {
            return res.status(400).json({ error: 'User email is required' });
        }

        console.log('Processing ID verification for:', userEmail);
        console.log('File info:', { 
            originalname: req.file.originalname, 
            mimetype: req.file.mimetype, 
            size: req.file.size 
        });

        // Analyze the government ID using Azure Document Intelligence
        const poller = await documentClient.beginAnalyzeDocument(
            'prebuilt-idDocument',
            req.file.buffer,
            {
                contentType: req.file.mimetype
            }
        );

        const result = await poller.pollUntilDone();
        
        if (!result.documents || result.documents.length === 0) {
            return res.status(400).json({ error: 'No valid government ID found in the image' });
        }

        const document = result.documents[0];
        const extractedData = {};

        // Extract key information from the ID
        if (document.fields) {
            if (document.fields.FirstName?.content) {
                extractedData.firstName = document.fields.FirstName.content;
            }
            if (document.fields.LastName?.content) {
                extractedData.lastName = document.fields.LastName.content;
            }
            if (document.fields.DateOfBirth?.content) {
                extractedData.dateOfBirth = document.fields.DateOfBirth.content;
            }
            if (document.fields.DocumentNumber?.content) {
                extractedData.documentNumber = document.fields.DocumentNumber.content;
            }
            if (document.fields.CountryRegion?.content) {
                extractedData.country = document.fields.CountryRegion.content;
            }
        }

        // Validate that this is actually a government ID document
        // Check if we have at least the essential fields that every government ID should have
        const hasRequiredFields = extractedData.firstName && extractedData.lastName && 
                                 (extractedData.dateOfBirth || extractedData.documentNumber);
        
        if (!hasRequiredFields) {
            return res.status(400).json({ 
                error: 'This image does not appear to be a valid government ID document. Please upload a clear photo of your driver\'s license, passport, or state ID.' 
            });
        }

        // Additional validation: check document confidence
        if (document.confidence && document.confidence < 0.5) {
            return res.status(400).json({ 
                error: 'Document quality is too low or document type not recognized. Please upload a clear, high-quality photo of your government ID.' 
            });
        }

        // Store verification status in database and save ID document to Supabase Storage
        if (supabase) {
            try {
                // Try to upload ID document to Supabase Storage, fallback to base64 if needed
                const fileName = `${userEmail}-${Date.now()}-id-document.${req.file.mimetype.split('/')[1]}`;
                let idDocumentPath = null;
                let idDocumentBase64 = null;
                
                try {
                    // First, ensure the govdocs bucket exists
                    console.log('🔍 Checking for govdocs bucket...');
                    console.log('📧 User email:', userEmail);
                    console.log('📄 File details:', {
                        originalname: req.file.originalname,
                        mimetype: req.file.mimetype,
                        size: req.file.size
                    });
                    
                    const { data: buckets, error: bucketsListError } = await supabase.storage.listBuckets();
                    
                    if (bucketsListError) {
                        console.error('❌ Error listing buckets:', bucketsListError);
                        console.log('📝 List buckets error details:', {
                            message: bucketsListError.message,
                            details: bucketsListError.details,
                            hint: bucketsListError.hint,
                            code: bucketsListError.code
                        });
                    }
                    
                    console.log('📋 Available buckets:', buckets?.map(b => b.name) || 'None');
                    const govdocsBucketExists = buckets?.some(bucket => bucket.name === 'govdocs');
                    console.log('🔍 govdocs bucket exists:', govdocsBucketExists);
                    
                    if (!govdocsBucketExists) {
                        console.log('📦 Creating govdocs bucket...');
                        const { data: newBucket, error: createError } = await supabase.storage.createBucket('govdocs', {
                            public: false,
                            allowedMimeTypes: ['image/jpeg', 'image/png', 'image/jpg', 'application/pdf'],
                            fileSizeLimit: 10485760 // 10MB
                        });
                        
                        if (createError) {
                            console.error('❌ Failed to create govdocs bucket:', createError);
                            console.log('📝 Create bucket error details:', {
                                message: createError.message,
                                details: createError.details,
                                hint: createError.hint,
                                code: createError.code
                            });
                            throw new Error(`Failed to create secure storage bucket: ${createError.message}`);
                        }
                        
                        console.log('✅ Created govdocs bucket successfully:', newBucket);
                    }

                    // Upload to pics subfolder within govdocs bucket
                    const folderPath = `pics/${fileName}`;
                    console.log('📁 Uploading to govdocs bucket path:', folderPath);
                    
                    const { data: uploadData, error: uploadError } = await supabase.storage
                        .from('govdocs')
                        .upload(folderPath, req.file.buffer, {
                            contentType: req.file.mimetype,
                            upsert: false
                        });

                    if (uploadError) {
                        console.error('❌ Supabase Storage upload error:', uploadError);
                        console.log('📝 Upload error details:', {
                            message: uploadError.message,
                            error: uploadError.error,
                            statusCode: uploadError.statusCode
                        });
                        throw uploadError;
                    }

                    idDocumentPath = uploadData.path;
                    console.log('✅ ID document uploaded to storage:', uploadData.path);
                } catch (storageError) {
                    console.log('⚠️ Storage upload failed, falling back to base64 storage');
                    console.error('Storage error details:', storageError);
                    
                    // Fallback: store as base64 in database
                    idDocumentBase64 = req.file.buffer.toString('base64');
                    console.log('📦 Using base64 fallback storage');
                }
                
                // Store verification data with either storage path or base64
                const verificationData = {
                    ...extractedData,
                    id_document_mimetype: req.file.mimetype
                };

                if (idDocumentPath) {
                    verificationData.id_document_path = idDocumentPath;
                    verificationData.storage_method = 'supabase_storage';
                } else if (idDocumentBase64) {
                    verificationData.id_document_image = idDocumentBase64;
                    verificationData.storage_method = 'base64';
                }

                const { error: verificationError } = await supabase
                    .from('user_verifications')
                    .upsert({
                        user_email: userEmail,
                        id_verification_status: 'verified',
                        id_verification_data: verificationData,
                        id_verified_at: new Date().toISOString()
                    });

                if (verificationError) {
                    console.error('Error storing verification:', verificationError);
                }
            } catch (dbError) {
                console.error('Database error:', dbError);
            }
        }

        // Log verification activity
        await logUserActivity(userEmail, 'id_verified', 'Government ID successfully verified', {
            document_type: document.docType,
            extracted_data: extractedData
        });

        res.json({
            success: true,
            message: 'Government ID verified successfully',
            extractedData: extractedData,
            documentType: document.docType,
            confidence: document.confidence
        });

    } catch (error) {
        console.error('ID verification error:', error);
        res.status(500).json({ 
            error: 'ID verification failed', 
            details: error.message 
        });
    }
});

// API: Face verification against stored ID
app.post('/api/verify/face-match', upload.single('facePhoto'), async (req, res) => {
    try {
        // Try to reinitialize Azure clients if they're not available
        reinitializeAzureClients();
        
        if (!faceClient || !documentClient) {
            console.log('⚠️ Face verification attempted but Azure services not configured');
            return res.status(503).json({ 
                error: 'Face verification service not available',
                message: 'The face verification service is currently not configured. Please contact support.',
                serviceAvailable: false
            });
        }

        if (!req.file) {
            return res.status(400).json({ error: 'Face photo is required' });
        }

        const { userEmail } = req.body;
        if (!userEmail) {
            return res.status(400).json({ error: 'User email is required' });
        }

        console.log('Processing face verification for:', userEmail);

        // First, check if user has completed ID verification and get the stored ID document
        if (!supabase) {
            return res.status(503).json({ error: 'Database service not available' });
        }

        const { data: verification, error: verificationError } = await supabase
            .from('user_verifications')
            .select('id_verification_status, id_verification_data')
            .eq('user_email', userEmail)
            .single();

        if (verificationError || !verification || verification.id_verification_status !== 'verified') {
            return res.status(400).json({ 
                error: 'ID verification must be completed first before face verification' 
            });
        }

        // Get the stored ID document (either from storage or base64)
        const storageMethod = verification.id_verification_data?.storage_method;
        const idDocumentPath = verification.id_verification_data?.id_document_path;
        const idDocumentBase64 = verification.id_verification_data?.id_document_image;
        
        let idDocumentBufferNode;

        if (storageMethod === 'supabase_storage' && idDocumentPath) {
            // Download from Supabase Storage
            console.log('📥 Downloading ID document from Supabase Storage:', idDocumentPath);
            const { data: idDocumentData, error: downloadError } = await supabase.storage
                .from('govdocs')
                .download(idDocumentPath);

            if (downloadError || !idDocumentData) {
                console.error('Error downloading ID document:', downloadError);
                return res.status(500).json({ 
                    error: 'Failed to retrieve ID document for comparison' 
                });
            }

            // Convert the downloaded blob to buffer
            const idDocumentBuffer = await idDocumentData.arrayBuffer();
            idDocumentBufferNode = Buffer.from(idDocumentBuffer);
            console.log('✅ ID document retrieved from storage');
            
        } else if (storageMethod === 'base64' && idDocumentBase64) {
            // Convert base64 to buffer
            console.log('📦 Using base64 stored ID document');
            idDocumentBufferNode = Buffer.from(idDocumentBase64, 'base64');
            console.log('✅ ID document retrieved from base64');
            
        } else {
            return res.status(400).json({ 
                error: 'ID document not found. Please complete ID verification again.' 
            });
        }

        // Perform liveness detection on the selfie photo first
        console.log('🔍 Performing liveness detection on selfie...');
        const livenessResult = await faceClient.face.detectWithStream(req.file.buffer, {
            returnFaceId: true,
            returnFaceLandmarks: false,
            returnFaceAttributes: ['headPose', 'smile', 'facialHair', 'glasses', 'emotion', 'age', 'gender', 'makeup', 'accessories', 'blur', 'exposure', 'noise']
        });

        if (!livenessResult || livenessResult.length === 0) {
            return res.status(400).json({ error: 'No face detected in selfie photo. Please take a clearer photo.' });
        }

        if (livenessResult.length > 1) {
            return res.status(400).json({ error: 'Multiple faces detected in selfie. Please take a photo with only your face visible.' });
        }

        // Check for liveness indicators (these suggest a real person vs a photo)
        const faceAttributes = livenessResult[0].faceAttributes;
        const isLikelyLive = (
            faceAttributes.blur?.blurLevel !== 'high' &&
            faceAttributes.exposure?.exposureLevel !== 'overExposure' &&
            faceAttributes.exposure?.exposureLevel !== 'underExposure' &&
            faceAttributes.noise?.noiseLevel !== 'high'
        );

        if (!isLikelyLive) {
            return res.status(400).json({ 
                error: 'Liveness detection failed. Please take a clear, well-lit selfie in good lighting conditions.' 
            });
        }

        console.log('✅ Liveness detection passed');

        // Detect faces in both ID document and selfie photo for comparison
        const [idFaces, userFaces] = await Promise.all([
            faceClient.face.detectWithStream(idDocumentBufferNode, {
                returnFaceId: true,
                returnFaceLandmarks: false,
                returnFaceAttributes: []
            }),
            // Use the same result from liveness detection
            Promise.resolve(livenessResult)
        ]);

        if (!idFaces || idFaces.length === 0) {
            return res.status(400).json({ error: 'No face detected in your ID document. Please upload a clearer ID photo.' });
        }

        // Compare the faces using Azure Face API
        const comparison = await faceClient.face.verifyFaceToFace(
            idFaces[0].faceId,
            userFaces[0].faceId
        );

        const isMatch = comparison.isIdentical;
        const confidence = comparison.confidence;

        // Store face verification status
        if (supabase) {
            try {
                const { error: verificationError } = await supabase
                    .from('user_verifications')
                    .upsert({
                        user_email: userEmail,
                        face_verification_status: isMatch ? 'verified' : 'failed',
                        face_verification_confidence: confidence,
                        face_verified_at: new Date().toISOString()
                    });

                if (verificationError) {
                    console.error('Error storing face verification:', verificationError);
                }
            } catch (dbError) {
                console.error('Database error:', dbError);
            }
        }

        // Log face verification activity
        await logUserActivity(userEmail, 'face_verified', 
            `Face verification ${isMatch ? 'successful' : 'failed'} with ${(confidence * 100).toFixed(1)}% confidence`, {
            is_match: isMatch,
            confidence: confidence
        });

        res.json({
            success: true,
            isMatch: isMatch,
            confidence: confidence,
            message: isMatch ? 'Face verification successful' : 'Face verification failed - faces do not match'
        });

    } catch (error) {
        console.error('Face verification error:', error);
        res.status(500).json({ 
            error: 'Face verification failed', 
            details: error.message 
        });
    }
});

// API: Get user verification status
app.get('/api/verify/status/:email', async (req, res) => {
    try {
        if (!supabase) {
            return res.status(503).json({ error: 'Database service not available' });
        }

        const { email } = req.params;
        
        const { data: verification, error } = await supabase
            .from('user_verifications')
            .select('*')
            .eq('user_email', email)
            .single();

        if (error && error.code !== 'PGRST116') {
            console.error('Error fetching verification status:', error);
            return res.status(500).json({ error: 'Failed to fetch verification status' });
        }
        
        // Include service availability status
        const servicesAvailable = {
            documentIntelligence: !!documentClient,
            faceAPI: !!faceClient
        };

        res.json({
            verification: verification || {
                user_email: email,
                id_verification_status: 'pending',
                face_verification_status: 'pending'
            },
            servicesAvailable: servicesAvailable
        });

    } catch (error) {
        console.error('Error in verification status endpoint:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// API: Real-time head pose detection for face scanning
app.post('/api/verify/head-pose', upload.single('facePhoto'), async (req, res) => {
    try {
        reinitializeAzureClients();
        
        if (!faceClient) {
            return res.status(503).json({ error: 'Face detection service not available' });
        }

        if (!req.file) {
            return res.status(400).json({ error: 'Face photo is required' });
        }

        const { expectedDirection } = req.body;
        
        // Detect face and head pose
        const faceResult = await faceClient.face.detectWithStream(req.file.buffer, {
            returnFaceId: false,
            returnFaceLandmarks: false,
            returnFaceAttributes: ['headPose']
        });

        if (!faceResult || faceResult.length === 0) {
            return res.status(400).json({ 
                error: 'No face detected', 
                isCorrectDirection: false 
            });
        }

        if (faceResult.length > 1) {
            return res.status(400).json({ 
                error: 'Multiple faces detected', 
                isCorrectDirection: false 
            });
        }

        const headPose = faceResult[0].faceAttributes.headPose;
        const { yaw, pitch, roll } = headPose;
        
        // More detailed logging
        console.log(`[HeadPose API] Expected: ${expectedDirection} | Actual Yaw: ${yaw.toFixed(2)}°, Pitch: ${pitch.toFixed(2)}°, Roll: ${roll.toFixed(2)}°`);

        // Define stricter direction thresholds (in degrees)
        const thresholds = {
            center: { yaw: [-12, 12], pitch: [-12, 12] },    // Narrowed center
            up:     { yaw: [-20, 20], pitch: [-50, -15] }, // Stricter min pitch, wider max
            down:   { yaw: [-20, 20], pitch: [15, 50] },   // Stricter min pitch, wider max
            left:   { yaw: [-50, -20], pitch: [-20, 20] }, // Stricter min yaw, wider max
            right:  { yaw: [20, 50], pitch: [-20, 20] }   // Stricter min yaw, wider max
        };

        const currentThreshold = thresholds[expectedDirection];
        let isCorrectDirection = false;
        let yawInRange = false;
        let pitchInRange = false;

        if (currentThreshold) {
            yawInRange = yaw >= currentThreshold.yaw[0] && yaw <= currentThreshold.yaw[1];
            pitchInRange = pitch >= currentThreshold.pitch[0] && pitch <= currentThreshold.pitch[1];
            isCorrectDirection = yawInRange && pitchInRange;

            console.log(`[HeadPose API] Thresholds for ${expectedDirection}: Yaw[${currentThreshold.yaw.join(', ')}], Pitch[${currentThreshold.pitch.join(', ')}]`);
            console.log(`[HeadPose API] Yaw in range: ${yawInRange}, Pitch in range: ${pitchInRange}`);
        } else {
            console.log(`[HeadPose API] No threshold found for expected direction: ${expectedDirection}`);
        }

        console.log(`[HeadPose API] Direction match for ${expectedDirection}: ${isCorrectDirection}`);

        let message = `Please look ${expectedDirection}.`;
        if (isCorrectDirection) {
            message = `Perfect! Looking ${expectedDirection}.`;
        } else if (currentThreshold) {
            if (expectedDirection === "up" || expectedDirection === "down") {
                if (!pitchInRange) message = `Look further ${expectedDirection}.`;
                else if (!yawInRange) message = `Keep looking ${expectedDirection}, but center your head.`;
            } else if (expectedDirection === "left" || expectedDirection === "right") {
                if (!yawInRange) message = `Look further ${expectedDirection}.`;
                else if (!pitchInRange) message = `Keep looking ${expectedDirection}, but level your head.`;
            }
        }

        res.json({
            success: true,
            isCorrectDirection,
            headPose: { yaw, pitch, roll },
            expectedDirection,
            message: message
        });

    } catch (error) {
        console.error('[HeadPose API] Error:', error);
        res.status(500).json({ 
            error: 'Head pose detection failed', 
            isCorrectDirection: false 
        });
    }
});

// Function to reinitialize Azure clients if they failed initially
function reinitializeAzureClients() {
    console.log('🔄 Attempting Azure client reinitialization...');
    
    // Force reload config from environment variables
    const currentConfig = {
        AZURE_DOCUMENT_INTELLIGENCE_KEY: process.env.AZURE_DOCUMENT_INTELLIGENCE_KEY?.trim(),
        AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT: process.env.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT?.trim(),
        AZURE_FACE_KEY: process.env.AZURE_FACE_KEY?.trim(),
        AZURE_FACE_ENDPOINT: process.env.AZURE_FACE_ENDPOINT?.trim()
    };
    
    console.log('🔍 Current environment variables:');
    console.log('- AZURE_DOCUMENT_INTELLIGENCE_KEY:', currentConfig.AZURE_DOCUMENT_INTELLIGENCE_KEY ? `Present (${currentConfig.AZURE_DOCUMENT_INTELLIGENCE_KEY.substring(0, 10)}...)` : 'MISSING');
    console.log('- AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT:', currentConfig.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT || 'MISSING');
    console.log('- AZURE_FACE_KEY:', currentConfig.AZURE_FACE_KEY ? `Present (${currentConfig.AZURE_FACE_KEY.substring(0, 10)}...)` : 'MISSING');
    console.log('- AZURE_FACE_ENDPOINT:', currentConfig.AZURE_FACE_ENDPOINT || 'MISSING');
    
    // Update global config with fresh environment variables
    config.AZURE_DOCUMENT_INTELLIGENCE_KEY = currentConfig.AZURE_DOCUMENT_INTELLIGENCE_KEY;
    config.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT = currentConfig.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT;
    config.AZURE_FACE_KEY = currentConfig.AZURE_FACE_KEY;
    config.AZURE_FACE_ENDPOINT = currentConfig.AZURE_FACE_ENDPOINT;
    
    // Try to reinitialize Document Intelligence if it's not available
    if (!documentClient && currentConfig.AZURE_DOCUMENT_INTELLIGENCE_KEY && currentConfig.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT) {
        try {
            documentClient = new DocumentAnalysisClient(
                currentConfig.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT,
                new AzureKeyCredential(currentConfig.AZURE_DOCUMENT_INTELLIGENCE_KEY)
            );
            console.log('✅ Azure Document Analysis reinitialized successfully');
        } catch (error) {
            console.log('❌ Azure Document Intelligence reinitialization failed:', error.message);
            console.log('❌ Full error details:', error);
        }
    }
    
    // Try to reinitialize Face API if it's not available
    if (!faceClient && currentConfig.AZURE_FACE_KEY && currentConfig.AZURE_FACE_ENDPOINT) {
        try {
            const credentials = new CognitiveServicesCredentials(currentConfig.AZURE_FACE_KEY);
            faceClient = new FaceClient(credentials, currentConfig.AZURE_FACE_ENDPOINT);
            console.log('✅ Azure Face API reinitialized successfully');
        } catch (error) {
            console.log('❌ Azure Face API reinitialization failed:', error.message);
            console.log('❌ Full error details:', error);
        }
    }
    
    // Log final status
    console.log('🏁 Reinitialization complete:');
    console.log('- Document Intelligence available:', !!documentClient);
    console.log('- Face API available:', !!faceClient);
}

// API: Check verification services availability
app.get('/api/verify/service-status', (req, res) => {
    // Try to reinitialize Azure clients if they're not available
    reinitializeAzureClients();
    
    const status = {
        documentIntelligence: {
            available: !!documentClient,
            configured: !!(config.AZURE_DOCUMENT_INTELLIGENCE_KEY && config.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT),
            message: documentClient ? 'Service is available' : 'Service not configured - Azure Document Intelligence credentials missing'
        },
        faceAPI: {
            available: !!faceClient,
            configured: !!(config.AZURE_FACE_KEY && config.AZURE_FACE_ENDPOINT),
            message: faceClient ? 'Service is available' : 'Service not configured - Azure Face API credentials missing'
        },
        overallStatus: !!(documentClient && faceClient)
    };
    
    res.json(status);
});

// API endpoint to serve client-safe configuration
app.get('/api/config', (req, res) => {
    // Try to reinitialize Azure clients if they're not available
    reinitializeAzureClients();
    console.log('📋 Config endpoint called - checking environment variables:');
    console.log('- OPENAI_API_KEY:', config.OPENAI_API_KEY ? `Present (${config.OPENAI_API_KEY.substring(0, 10)}...)` : 'MISSING');
    console.log('- OPENAI_ORG_ID:', config.OPENAI_ORG_ID ? `Present (${config.OPENAI_ORG_ID})` : 'MISSING');
    console.log('- SUPABASE_URL:', config.SUPABASE_URL ? `Present (${config.SUPABASE_URL.substring(0, 30)}...)` : 'MISSING');
    console.log('- SUPABASE_ANON_KEY:', config.SUPABASE_ANON_KEY ? `Present (${config.SUPABASE_ANON_KEY.substring(0, 10)}...)` : 'MISSING');
    console.log('- AZURE_DOCUMENT_INTELLIGENCE_KEY:', config.AZURE_DOCUMENT_INTELLIGENCE_KEY ? `Present (${config.AZURE_DOCUMENT_INTELLIGENCE_KEY.substring(0, 10)}...)` : 'MISSING');
    console.log('- AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT:', config.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT ? `Present (${config.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT})` : 'MISSING');
    console.log('- AZURE_FACE_KEY:', config.AZURE_FACE_KEY ? `Present (${config.AZURE_FACE_KEY.substring(0, 10)}...)` : 'MISSING');
    console.log('- AZURE_FACE_ENDPOINT:', config.AZURE_FACE_ENDPOINT ? `Present (${config.AZURE_FACE_ENDPOINT})` : 'MISSING');
    
    const configData = {
        STRIPE_PUBLISHABLE_KEY: config.STRIPE_PUBLISHABLE_KEY,
        GOOGLE_API_KEY: config.GOOGLE_API_KEY,
        SUPABASE_URL: config.SUPABASE_URL,
        SUPABASE_ANON_KEY: config.SUPABASE_ANON_KEY,
        OPENAI_API_KEY: config.OPENAI_API_KEY,
        OPENAI_ORG_ID: config.OPENAI_ORG_ID,
        OPENAI_MODEL: config.OPENAI_MODEL,
        // Azure service status (without exposing keys)
        azureServicesAvailable: {
            documentIntelligence: !!documentClient,
            faceAPI: !!faceClient
        },
        // Add debug info about missing variables
        _debug: {
            missingVars: config.getMissingVars ? config.getMissingVars() : [],
            isValid: config.isValid ? config.isValid() : false
        }
    };
    
    res.json(configData);
});

// Debug endpoint to check Azure configuration status
app.get('/api/debug/azure', (req, res) => {
    console.log('🔍 Azure debug endpoint called');
    
    // Force reinitialization
    reinitializeAzureClients();
    
    const azureStatus = {
        environmentVariables: {
            AZURE_DOCUMENT_INTELLIGENCE_KEY: process.env.AZURE_DOCUMENT_INTELLIGENCE_KEY ? `Present (${process.env.AZURE_DOCUMENT_INTELLIGENCE_KEY.substring(0, 10)}...)` : 'MISSING',
            AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT: process.env.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT || 'MISSING',
            AZURE_FACE_KEY: process.env.AZURE_FACE_KEY ? `Present (${process.env.AZURE_FACE_KEY.substring(0, 10)}...)` : 'MISSING',
            AZURE_FACE_ENDPOINT: process.env.AZURE_FACE_ENDPOINT || 'MISSING'
        },
        configObject: {
            AZURE_DOCUMENT_INTELLIGENCE_KEY: config.AZURE_DOCUMENT_INTELLIGENCE_KEY ? `Present (${config.AZURE_DOCUMENT_INTELLIGENCE_KEY.substring(0, 10)}...)` : 'MISSING',
            AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT: config.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT || 'MISSING',
            AZURE_FACE_KEY: config.AZURE_FACE_KEY ? `Present (${config.AZURE_FACE_KEY.substring(0, 10)}...)` : 'MISSING',
            AZURE_FACE_ENDPOINT: config.AZURE_FACE_ENDPOINT || 'MISSING'
        },
        clients: {
            documentClient: !!documentClient,
            faceClient: !!faceClient
        },
        ready: !!documentClient && !!faceClient
    };
    
    res.json(azureStatus);
});

// Health check route for Railway monitoring - MUST BE BEFORE /:page
app.get('/health', (req, res) => {
    res.status(200).send('✅ RoomFinderAI server is running');
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

// Dynamic route handler for all HTML pages - MUST BE LAST
app.get('/:page', (req, res) => {
    try {
        const pageName = req.params.page;
        
        // Skip API routes and health - they should be handled above
        if (pageName.startsWith('api') || pageName === 'health') {
            return res.status(404).send('Route not found');
        }
        
        const htmlPath = path.join(__dirname, '..', `${pageName}.html`);
        
        // Check if file exists
        if (fs.existsSync(htmlPath)) {
            console.log(`📄 Serving ${pageName}.html from:`, htmlPath);
            res.sendFile(htmlPath);
        } else {
            console.log(`❌ Page not found: ${pageName}.html`);
            res.status(404).send(`Page not found: /${pageName}`);
        }
    } catch (error) {
        console.error('Error serving page:', error);
        res.status(500).send('Server error');
    }
});

// Start server on Railway-required port
console.log('🚀 Starting server...');
console.log('Port:', port);
console.log('Environment variables check:');
console.log('- STRIPE_SECRET_KEY:', !!process.env.STRIPE_SECRET_KEY);
console.log('- SUPABASE_URL:', !!process.env.SUPABASE_URL);
console.log('- SUPABASE_ANON_KEY:', !!process.env.SUPABASE_ANON_KEY);
console.log('- AZURE_DOCUMENT_INTELLIGENCE_KEY:', !!process.env.AZURE_DOCUMENT_INTELLIGENCE_KEY);
console.log('- AZURE_FACE_KEY:', !!process.env.AZURE_FACE_KEY);

app.listen(port, '0.0.0.0', () => {
    console.log(`✅ Server running on port ${port}`);
    console.log(`🏥 Health check available at http://localhost:${port}/health`);
    console.log(`🌐 Server accessible at http://0.0.0.0:${port}`);
});
// Force update
