# RoomFinderAI API Documentation

## 🚀 How to Start the API Server

### Prerequisites
```bash
# Install dependencies (if not already installed)
npm install

# Set up environment variables (create .env file)
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_key
OPENAI_API_KEY=your_openai_key
STRIPE_SECRET_KEY=your_stripe_key
# ... other required keys
```

### Start the Server
```bash
# Method 1: Start from backend directory
cd backend
node server.js

# Method 2: Use npm script (if configured)
npm start

# The API will be available at: http://localhost:3000
```

## 📡 API Endpoints

### Base URL
```
Local: http://localhost:3000/api
Production: https://yourdomain.com/api
```

## 🏠 Listings API

### Create Listing
```http
POST /api/listings
Content-Type: application/json

{
  "title": "Beautiful 2BR Apartment",
  "description": "Modern apartment in downtown",
  "price": 1500,
  "location": "123 Main St",
  "bedrooms": 2,
  "bathrooms": 1,
  "images": ["image1.jpg", "image2.jpg"]
}
```

### Get All Listings
```http
GET /api/listings
```

### Get Single Listing
```http
GET /api/listings/{id}
```

### Update Listing
```http
PUT /api/listings/{id}
Content-Type: application/json

{
  "title": "Updated Title",
  "price": 1600
}
```

### Delete Listing
```http
DELETE /api/listings/{id}
```

## 👤 Authentication API

### Register User
```http
POST /api/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword",
  "fullName": "John Doe"
}
```

### Login User
```http
POST /api/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword"
}
```

### Send Verification Email
```http
POST /api/send-verification
Content-Type: application/json

{
  "email": "user@example.com"
}
```

### Verify Email
```http
POST /api/verify-email
Content-Type: application/json

{
  "email": "user@example.com",
  "code": "123456"
}
```

### Send Password Reset
```http
POST /api/send-reset-code
Content-Type: application/json

{
  "email": "user@example.com"
}
```

### Verify Reset Code
```http
POST /api/verify-reset-code
Content-Type: application/json

{
  "email": "user@example.com",
  "code": "123456"
}
```

### Reset Password
```http
POST /api/reset-password
Content-Type: application/json

{
  "email": "user@example.com",
  "code": "123456",
  "newPassword": "newSecurePassword"
}
```

## 🤖 AI Features API

### AI Negotiation
```http
POST /api/ai-negotiate
Content-Type: application/json

{
  "message": "I'm interested in this property, can we negotiate the price?",
  "propertyId": "123",
  "currentPrice": 1500,
  "context": "student, urgent need"
}
```

### AI Negotiator Chat
```http
POST /api/ai-negotiator
Content-Type: application/json

{
  "message": "Hello, I need help with rent negotiation",
  "conversationId": "conv-123"
}
```

## 🔍 Prediction API

### Kijiji Price Prediction
```http
POST /api/predict/kijiji
Content-Type: application/json

{
  "location": "Toronto, ON",
  "bedrooms": 2,
  "bathrooms": 1,
  "propertyType": "apartment"
}
```

## 💳 Payment API

### Create Payment Intent
```http
POST /api/create-payment-intent
Content-Type: application/json

{
  "amount": 1500,
  "currency": "cad",
  "planType": "premium"
}
```

### Confirm Payment
```http
POST /api/confirm-payment
Content-Type: application/json

{
  "paymentIntentId": "pi_123456",
  "userId": "user-123"
}
```

## 📊 Analytics API

### Save Chat Data
```http
POST /api/save-chat-data
Content-Type: application/json

{
  "userId": "user-123",
  "chatType": "negotiation",
  "outcome": "successful",
  "savings": 200
}
```

### Get User Activities
```http
GET /api/user-activities/{userId}
```

## 🔐 Identity Verification API

### Verify Identity Documents
```http
POST /api/verify-identity
Content-Type: multipart/form-data

idDocument: [file upload]
facePhoto: [file upload]
userId: user-123
```

### Face Verification
```http
POST /api/verify-face
Content-Type: multipart/form-data

photo1: [file upload]
photo2: [file upload]
```

## 🏢 Property Management API

### Property Autocomplete
```http
GET /api/autocomplete?query=toronto
```

### Get Property Details
```http
GET /api/property-details/{propertyId}
```

### Save Property Search
```http
POST /api/save-search
Content-Type: application/json

{
  "userId": "user-123",
  "searchCriteria": {
    "location": "Toronto",
    "minPrice": 1000,
    "maxPrice": 2000,
    "bedrooms": 2
  }
}
```

## ⚙️ System API

### Health Check
```http
GET /api/health
```

### Get API Status
```http
GET /api/status
```

## 🔧 Configuration

### Required Environment Variables
```env
# Database
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key

# AI Services
OPENAI_API_KEY=your_openai_api_key
OPENAI_ORG_ID=your_openai_org_id

# Payment Processing
STRIPE_SECRET_KEY=your_stripe_secret_key
STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key

# Email Services
BREVO_API_KEY=your_brevo_api_key

# Azure Services (Optional)
AZURE_DOCUMENT_INTELLIGENCE_KEY=your_azure_key
AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT=your_azure_endpoint
AZURE_FACE_KEY=your_azure_face_key
AZURE_FACE_ENDPOINT=your_azure_face_endpoint

# Maps & Location
GOOGLE_API_KEY=your_google_maps_key
```

## 📱 Using the API

### JavaScript Example
```javascript
// Using fetch API
const response = await fetch('http://localhost:3000/api/listings', {
  method: 'GET',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer your-jwt-token'
  }
});

const listings = await response.json();
console.log(listings);
```

### cURL Example
```bash
# Get all listings
curl -X GET http://localhost:3000/api/listings

# Create a new listing
curl -X POST http://localhost:3000/api/listings \
  -H "Content-Type: application/json" \
  -d '{
    "title": "New Apartment",
    "price": 1500,
    "location": "Toronto"
  }'
```

### Python Example
```python
import requests

# Get listings
response = requests.get('http://localhost:3000/api/listings')
listings = response.json()

# Create listing
new_listing = {
    "title": "Python Created Listing",
    "price": 1200,
    "location": "Vancouver"
}
response = requests.post(
    'http://localhost:3000/api/listings',
    json=new_listing
)
```

## 🚨 Error Handling

### Standard Error Response
```json
{
  "success": false,
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": {}
}
```

### Success Response
```json
{
  "success": true,
  "data": {},
  "message": "Operation completed successfully"
}
```

## 🔒 Authentication

Most endpoints require authentication. Include the JWT token in the Authorization header:
```
Authorization: Bearer your-jwt-token
```

## 📈 Rate Limiting

- Default rate limit: 100 requests per minute per IP
- AI endpoints: 10 requests per minute per user
- File uploads: 5 requests per minute per user

## 🌐 CORS Configuration

The API is configured to accept requests from all origins in development. In production, configure specific domains in the CORS settings.

## 📝 Notes

- All timestamps are in ISO 8601 format
- Prices are in cents (e.g., $15.00 = 1500)
- File uploads have a 10MB limit
- API uses JSON for request/response bodies except file uploads