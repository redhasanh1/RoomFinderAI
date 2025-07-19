# API Integration Examples

This document shows how to use the universal API wrapper system for iOS, web, and hybrid apps.

## Table of Contents

1. [Setup and Installation](#setup-and-installation)
2. [Universal API Usage](#universal-api-usage)
3. [Supabase Integration](#supabase-integration)
4. [OpenAI Integration](#openai-integration)
5. [Payment Integration](#payment-integration)
6. [iOS Native Bridge](#ios-native-bridge)
7. [Error Handling](#error-handling)
8. [Testing](#testing)

## Setup and Installation

### 1. Install Dependencies

```bash
# Install Capacitor HTTP plugin
npm install @capacitor-community/http

# Sync with iOS
npx cap sync ios

# Install other dependencies if needed
npm install @supabase/supabase-js openai stripe
```

### 2. Environment Configuration

Create a `.env` file in your project root:

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# OpenAI
OPENAI_API_KEY=your-openai-api-key
OPENAI_ORGANIZATION=your-org-id

# Stripe
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_your-publishable-key
STRIPE_SECRET_KEY=sk_test_your-secret-key
STRIPE_WEBHOOK_SECRET=whsec_your-webhook-secret

# PayPal
NEXT_PUBLIC_PAYPAL_CLIENT_ID=your-paypal-client-id
PAYPAL_CLIENT_SECRET=your-paypal-client-secret
PAYPAL_ENVIRONMENT=sandbox

# Backend
NEXT_PUBLIC_BACKEND_URL=https://your-backend.railway.app
```

### 3. Info.plist Configuration

The Info.plist has been updated to allow all necessary domains. No additional configuration needed.

## Universal API Usage

### Basic HTTP Requests

```typescript
import { universalApi } from './services/universal-api';

// GET request
const response = await universalApi.get('https://api.example.com/data');

// POST request
const response = await universalApi.post('https://api.example.com/data', {
  name: 'John Doe',
  email: 'john@example.com'
});

// Upload file
const response = await universalApi.uploadFile(
  'https://api.example.com/upload',
  fileObject,
  'image',
  { description: 'Profile picture' }
);
```

### Custom Headers and Authentication

```typescript
import { universalApi } from './services/universal-api';

// Set default headers
universalApi.setDefaultHeaders({
  'Authorization': 'Bearer your-token',
  'X-API-Key': 'your-api-key'
});

// Set individual header
universalApi.setHeader('Content-Type', 'application/json');

// Remove header
universalApi.removeHeader('Authorization');
```

## Supabase Integration

### Authentication

```typescript
import { supabaseApi } from './services/api-config';

// Sign up
const { user, session } = await supabaseApi.signUp(
  'user@example.com',
  'password123',
  {
    firstName: 'John',
    lastName: 'Doe'
  }
);

// Sign in
const { user, session } = await supabaseApi.signIn(
  'user@example.com',
  'password123'
);

// Get current user
const user = await supabaseApi.getUser();

// Sign out
await supabaseApi.signOut();
```

### Database Operations

```typescript
import { supabaseApi } from './services/api-config';

// Select data
const properties = await supabaseApi.select('properties', {
  select: 'id, title, price, bedrooms, bathrooms',
  where: {
    city: 'New York',
    price: { lte: 2000 }
  },
  order: { column: 'price', ascending: true },
  limit: 10
});

// Insert data
const newProperty = await supabaseApi.insert('properties', {
  title: 'Beautiful Apartment',
  price: 1500,
  bedrooms: 2,
  bathrooms: 1,
  city: 'New York'
});

// Update data
const updatedProperty = await supabaseApi.update('properties', {
  price: 1400
}, {
  where: { id: 'property-id' }
});

// Delete data
await supabaseApi.delete('properties', {
  where: { id: 'property-id' }
});
```

### File Storage

```typescript
import { supabaseApi } from './services/api-config';

// Upload file
const result = await supabaseApi.uploadFile(
  'property-images',
  'properties/123/image.jpg',
  fileObject,
  {
    cacheControl: '3600',
    contentType: 'image/jpeg'
  }
);

// Download file
const blob = await supabaseApi.downloadFile(
  'property-images',
  'properties/123/image.jpg'
);

// List files
const files = await supabaseApi.listFiles('property-images', 'properties/123');
```

## OpenAI Integration

### Chat Completions

```typescript
import { openaiApi } from './services/api-config';

// Simple chat
const response = await openaiApi.simpleChat(
  'What are the best neighborhoods in NYC for young professionals?',
  'You are a helpful real estate assistant.'
);

// Advanced chat completion
const completion = await openaiApi.createChatCompletion({
  model: 'gpt-3.5-turbo',
  messages: [
    { role: 'system', content: 'You are a helpful real estate assistant.' },
    { role: 'user', content: 'Help me find a 2-bedroom apartment in Manhattan under $3000.' }
  ],
  temperature: 0.7,
  max_tokens: 1000
});

// Generate property analysis
const analysis = await openaiApi.analyzeText(
  'This is a 2-bedroom apartment in downtown with great amenities...',
  'Analyze this property description and highlight pros and cons.'
);
```

### Image Generation

```typescript
import { openaiApi } from './services/api-config';

// Generate image
const images = await openaiApi.generateImage({
  model: 'dall-e-3',
  prompt: 'A modern apartment interior with minimalist design',
  n: 1,
  size: '1024x1024',
  quality: 'standard'
});

// Edit image
const editedImages = await openaiApi.editImage(
  imageFile,
  'Add a beautiful sunset view through the window',
  maskFile
);
```

### Audio Processing

```typescript
import { openaiApi } from './services/api-config';

// Transcribe audio
const transcript = await openaiApi.transcribeAudio(audioFile, {
  model: 'whisper-1',
  response_format: 'json'
});

// Generate speech
const audioBlob = await openaiApi.createSpeech(
  'Welcome to your new home!',
  {
    model: 'tts-1',
    voice: 'alloy'
  }
);
```

## Payment Integration

### Stripe Payments

```typescript
import { paymentApi } from './services/api-config';

// Create payment intent
const paymentIntent = await paymentApi.createStripePaymentIntent({
  amount: 150000, // $1500.00 in cents
  currency: 'usd',
  description: 'Monthly rent payment',
  metadata: { propertyId: 'prop-123' }
});

// Confirm payment
const confirmedPayment = await paymentApi.confirmStripePaymentIntent(
  paymentIntent.id,
  {
    payment_method: 'pm_card_visa'
  }
);

// Create customer
const customer = await paymentApi.createStripeCustomer({
  email: 'john@example.com',
  name: 'John Doe',
  metadata: { userId: 'user-123' }
});

// Create subscription
const subscription = await paymentApi.createStripeSubscription({
  customer: customer.id,
  items: [{ price: 'price_monthly_rent' }],
  metadata: { propertyId: 'prop-123' }
});
```

### PayPal Payments

```typescript
import { paymentApi } from './services/api-config';

// Create PayPal order
const order = await paymentApi.createPayPalOrder({
  amount: '1500.00',
  currency: 'USD',
  description: 'Monthly rent payment',
  return_url: 'https://yourapp.com/success',
  cancel_url: 'https://yourapp.com/cancel'
});

// Capture payment
const capturedOrder = await paymentApi.capturePayPalOrder(order.id);
```

## iOS Native Bridge

### Using in Swift

```swift
import UIKit

class PropertyViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadProperties()
    }
    
    private func loadProperties() {
        let filters = [
            "city": "New York",
            "maxPrice": 2000,
            "bedrooms": 2
        ]
        
        MobileAPIBridge.shared.fetchProperties(filters: filters) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let properties):
                    self?.displayProperties(properties)
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
    }
    
    private func sendMessage(to conversationId: String, message: String) {
        let userId = SessionManager.shared.getCurrentUser()?.id ?? ""
        
        MobileAPIBridge.shared.sendMessage(
            conversationId: conversationId,
            senderId: userId,
            content: message
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let sentMessage):
                    self?.addMessageToUI(sentMessage)
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
    }
    
    private func getAIHelp(query: String) {
        MobileAPIBridge.shared.getAIResponse(query: query) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.displayAIResponse(response)
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
    }
}
```

### Authentication Flow

```swift
class AuthViewController: UIViewController {
    
    @IBAction func signUpTapped(_ sender: UIButton) {
        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        let userData = [
            "firstName": firstNameTextField.text ?? "",
            "lastName": lastNameTextField.text ?? "",
            "userType": "tenant"
        ]
        
        MobileAPIBridge.shared.signUp(
            email: email,
            password: password,
            userData: userData
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self?.navigateToMainApp(user: user)
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
    }
    
    @IBAction func signInTapped(_ sender: UIButton) {
        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        
        MobileAPIBridge.shared.signIn(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self?.navigateToMainApp(user: user)
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
    }
}
```

## Error Handling

### Universal Error Handling

```typescript
import { universalApi, ApiError } from './services/universal-api';

try {
  const response = await universalApi.get('https://api.example.com/data');
  // Handle success
} catch (error: ApiError) {
  console.error('API Error:', error.message);
  console.error('Status:', error.status);
  console.error('URL:', error.url);
  
  // Handle specific error types
  if (error.status === 401) {
    // Handle unauthorized
    redirectToLogin();
  } else if (error.status === 429) {
    // Handle rate limiting
    showRateLimitMessage();
  } else if (error.status >= 500) {
    // Handle server errors
    showServerErrorMessage();
  }
}
```

### iOS Error Handling

```swift
extension UIViewController {
    func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Handle specific error types
        if let apiError = error as? APIError {
            switch apiError {
            case .bridgeNotAvailable:
                // Handle bridge issues
                break
            case .invalidData:
                // Handle data validation errors
                break
            case .custom(let message):
                // Handle custom errors
                alert.message = message
                break
            default:
                break
            }
        }
        
        present(alert, animated: true)
    }
}
```

## Testing

### Unit Tests for API Services

```typescript
import { universalApi } from './services/universal-api';
import { supabaseApi } from './services/api-config';

describe('API Services', () => {
  beforeEach(() => {
    // Reset API state
    universalApi.removeHeader('Authorization');
  });

  test('should fetch properties successfully', async () => {
    const properties = await supabaseApi.select('properties', {
      limit: 10
    });
    
    expect(properties).toBeInstanceOf(Array);
    expect(properties.length).toBeLessThanOrEqual(10);
  });

  test('should handle authentication', async () => {
    const result = await supabaseApi.signIn('test@example.com', 'password');
    expect(result).toHaveProperty('user');
    expect(result).toHaveProperty('session');
  });

  test('should handle API errors gracefully', async () => {
    try {
      await universalApi.get('https://invalid-url.com/api');
    } catch (error) {
      expect(error).toBeInstanceOf(Error);
    }
  });
});
```

### iOS Integration Tests

```swift
import XCTest

class APIIntegrationTests: XCTestCase {
    
    func testPropertyFetching() {
        let expectation = self.expectation(description: "Properties fetched")
        
        MobileAPIBridge.shared.fetchProperties { result in
            switch result {
            case .success(let properties):
                XCTAssertTrue(properties.count > 0)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Failed to fetch properties: \(error)")
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testAuthenticationFlow() {
        let expectation = self.expectation(description: "User authenticated")
        
        MobileAPIBridge.shared.signIn(email: "test@example.com", password: "password") { result in
            switch result {
            case .success(let user):
                XCTAssertFalse(user.email.isEmpty)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Authentication failed: \(error)")
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
}
```

## Production Checklist

### Security
- [ ] All API keys are stored securely in environment variables
- [ ] No sensitive data in client-side code
- [ ] Proper authentication and authorization
- [ ] Input validation on all API endpoints
- [ ] Rate limiting implemented
- [ ] HTTPS enforced for all API calls

### Performance
- [ ] API responses are cached appropriately
- [ ] Large requests are paginated
- [ ] Images are compressed and optimized
- [ ] Network requests are debounced for search
- [ ] Offline capabilities implemented where needed

### Error Handling
- [ ] All API calls have proper error handling
- [ ] User-friendly error messages
- [ ] Retry logic for transient failures
- [ ] Logging for debugging
- [ ] Graceful degradation for network issues

### Testing
- [ ] Unit tests for all API services
- [ ] Integration tests for critical flows
- [ ] End-to-end tests for user journeys
- [ ] Performance testing under load
- [ ] Security testing completed

This comprehensive system provides a production-ready solution for handling all API calls in your Capacitor iOS app while working seamlessly on web platforms.