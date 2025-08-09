# RoomFinderAI - Native iOS App

A native iOS application built with SwiftUI that provides AI-powered rental property search and negotiation capabilities.

## Features

### 🏠 Core Features
- **AI-Powered Search**: Intelligent property matching using OpenAI
- **Real-time Chat**: Messaging with landlords and AI assistant
- **Property Listings**: Advanced search and filtering
- **Favorites System**: Save and manage favorite properties
- **Interactive Maps**: Location-based property discovery
- **User Authentication**: Secure login with Supabase Auth

### 📱 Native iOS Features
- **SwiftUI Interface**: Modern, responsive design
- **Dark Mode Support**: Automatic light/dark mode switching
- **Face ID/Touch ID**: Biometric authentication (ready to implement)
- **Push Notifications**: Real-time message and update alerts
- **Location Services**: Nearby property search
- **Camera Integration**: Property photo capture
- **Keychain Security**: Secure token storage

## Technology Stack

- **Frontend**: SwiftUI, iOS 16.0+
- **Backend**: Supabase (PostgreSQL, Auth, Real-time)
- **AI**: OpenAI GPT integration
- **Payments**: Stripe integration
- **Maps**: MapKit with custom annotations
- **Networking**: URLSession with async/await
- **Security**: Keychain Services

## Project Structure

```
RoomFinderAI/
├── RoomFinderAI/
│   ├── Models/          # Data models and structures
│   │   ├── User.swift
│   │   ├── Listing.swift
│   │   ├── Chat.swift
│   │   └── Message.swift
│   ├── Views/           # SwiftUI views
│   │   ├── LoginView.swift
│   │   ├── SignUpView.swift
│   │   ├── DashboardView.swift
│   │   ├── ListingsView.swift
│   │   ├── PropertyDetailView.swift
│   │   ├── ChatView.swift
│   │   └── ProfileView.swift
│   ├── Services/        # Business logic and API calls
│   │   ├── SupabaseService.swift
│   │   ├── NetworkManager.swift
│   │   ├── AuthViewModel.swift
│   │   ├── ListingsViewModel.swift
│   │   └── ChatViewModel.swift
│   ├── Utils/           # Utilities and extensions
│   │   ├── Constants.swift
│   │   └── Extensions.swift
│   └── Resources/       # Assets and configuration
│       ├── Assets.xcassets/
│       └── Info.plist
```

## Setup Instructions

### Prerequisites
- Xcode 15.0+
- iOS 16.0+ deployment target
- Swift 5.9+
- Supabase account
- OpenAI API key
- Stripe account (for payments)

### Configuration

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd RoomFinderAI/ios-native
   ```

2. **Configure Supabase**
   - Create a new project at [supabase.com](https://supabase.com)
   - Copy your project URL and anon key
   - Update `Constants.swift`:
   ```swift
   static let supabaseURL = "https://your-project-ref.supabase.co"
   static let supabaseAnonKey = "your-anon-key"
   ```

3. **Set up Database Schema**
   - Run the SQL migrations from the `database/migrations/` folder
   - Set up Row Level Security policies
   - Configure real-time subscriptions

4. **Configure OpenAI**
   - Get your API key from [OpenAI](https://platform.openai.com)
   - Update `Constants.swift`:
   ```swift
   static let openAIAPIKey = "your-openai-api-key"
   ```

5. **Configure Stripe (Optional)**
   - Get your publishable key from [Stripe](https://stripe.com)
   - Update `Constants.swift`:
   ```swift
   static let stripePublishableKey = "your-stripe-publishable-key"
   ```

### Building and Running

1. **Open in Xcode**
   ```bash
   open RoomFinderAI.xcodeproj
   ```

2. **Install Swift Package Dependencies**
   - The project uses Swift Package Manager
   - Dependencies should auto-resolve in Xcode
   - Main dependency: `supabase-swift`

3. **Configure Code Signing**
   - Select your development team in project settings
   - Update bundle identifier if needed
   - Ensure proper provisioning profiles

4. **Run the App**
   - Select target device/simulator
   - Press `Cmd + R` to build and run

## API Integration

### Supabase Integration
The app integrates with Supabase for:
- User authentication and profiles
- Property listings management
- Real-time chat functionality
- File storage for images
- Row Level Security for data access

### OpenAI Integration
- Chat completions for AI assistant
- Property analysis and recommendations
- Automated negotiation assistance
- Search query optimization

### Real-time Features
- Message delivery and read receipts
- Typing indicators
- Live property updates
- Push notifications

## App Store Compliance

### Required Features
- [x] Privacy Policy implementation
- [x] Terms of Service acceptance
- [x] App Store Review Guidelines compliance
- [x] Privacy permission descriptions
- [x] Data encryption and security
- [x] Accessibility support (VoiceOver ready)

### Privacy Permissions
- Location: Finding nearby properties
- Camera: Taking property photos
- Photo Library: Selecting images
- Microphone: Voice messages
- Notifications: Updates and alerts

### Security Features
- Keychain storage for sensitive data
- HTTPS-only network requests
- Input validation and sanitization
- Secure authentication flows

## Testing

### Unit Tests
```bash
# Run tests in Xcode
Cmd + U
```

### UI Tests
- Automated UI testing with XCTest
- Accessibility testing
- Performance testing

### Manual Testing Checklist
- [ ] User registration and login
- [ ] Property search and filtering
- [ ] Chat functionality
- [ ] AI assistant responses
- [ ] Push notifications
- [ ] Offline functionality
- [ ] Dark mode support

## Deployment

### App Store Submission
1. **Archive the app** (`Product > Archive`)
2. **Upload to App Store Connect**
3. **Complete app metadata**
4. **Submit for review**

### TestFlight Distribution
1. **Upload build to App Store Connect**
2. **Add internal/external testers**
3. **Distribute beta versions**

## Performance Optimization

### Image Loading
- Async image loading with caching
- Progressive image loading
- Memory-efficient image handling

### Network Optimization
- Request caching
- Connection pooling
- Timeout handling
- Retry mechanisms

### Battery Optimization
- Background processing limits
- Location services optimization
- Efficient real-time connections

## Troubleshooting

### Common Issues

1. **Supabase Connection Issues**
   - Verify URL and API key
   - Check network connectivity
   - Validate database permissions

2. **Build Errors**
   - Clean build folder (`Cmd + Shift + K`)
   - Reset package cache
   - Update Xcode and dependencies

3. **Authentication Issues**
   - Check Supabase Auth settings
   - Verify email templates
   - Test with different providers

### Debug Mode
- Enable debug logging in `Constants.swift`
- Use Xcode debugger and breakpoints
- Monitor network requests

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new features
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the troubleshooting guide

---

**Note**: This is a native iOS port of the RoomFinderAI web application, providing the same functionality with native iOS performance and user experience enhancements.