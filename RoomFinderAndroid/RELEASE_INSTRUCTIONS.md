# RoomFinder Android App - Play Store Release Instructions

## Prerequisites

1. **Google Play Developer Account** ($25 one-time fee)
   - Sign up at: https://play.google.com/console
   - Complete developer profile and payment information

2. **API Keys Setup**
   - Copy `local.properties.template` to `local.properties`
   - Add your actual OpenAI API keys:
     ```
     OPENAI_API_KEY=your_actual_openai_api_key
     OPENAI_ORG_ID=your_actual_openai_org_id
     ```
   - **NEVER commit local.properties to version control**

3. **Generate Signing Key**
   ```bash
   keytool -genkey -v -keystore roomfinder-release-key.jks \
           -keyalg RSA -keysize 2048 -validity 10000 \
           -alias roomfinder-key
   ```
   
4. **Setup Keystore Properties**
   - Copy `keystore.properties.template` to `keystore.properties`
   - Update with your keystore information:
     ```
     storeFile=roomfinder-release-key.jks
     storePassword=YOUR_STORE_PASSWORD
     keyAlias=roomfinder-key
     keyPassword=YOUR_KEY_PASSWORD
     ```
   - **NEVER commit keystore.properties to version control**

## Build Release Version

### Option 1: Using Android Studio
1. Open project in Android Studio
2. Select "Build" → "Generate Signed Bundle / APK"
3. Choose "Android App Bundle (recommended)"
4. Select your keystore file and enter passwords
5. Choose "release" build variant
6. Click "Finish"

### Option 2: Using Command Line
```bash
cd RoomFinderAndroid
./gradlew bundleRelease
```

The signed AAB will be generated at:
`app/build/outputs/bundle/release/app-release.aab`

## Pre-Upload Checklist

- [ ] API keys are secured (not hardcoded)
- [ ] Release build tested on multiple devices
- [ ] ProGuard/R8 obfuscation working correctly
- [ ] App icons look good on various devices
- [ ] Privacy policy is accessible at hosted URL
- [ ] All required permissions are declared
- [ ] App size is optimized (should be under 100MB)

## Google Play Console Setup

### 1. Create New App
1. Go to Google Play Console
2. Click "Create app"
3. Fill in app details:
   - **App name**: RoomFinder
   - **Default language**: English (United States)
   - **App or game**: App
   - **Free or paid**: Free

### 2. App Content
1. **Privacy Policy**: https://your-domain.com/privacy-policy.html
2. **App Category**: House & Home
3. **Content Rating**: Complete the questionnaire (likely Everyone)
4. **Target Audience**: Adults (18+)

### 3. Store Listing
#### Store Listing Details
- **App name**: RoomFinder - AI Property Search
- **Short description** (80 chars max): AI-powered property search and rent negotiation app
- **Full description** (4000 chars max):
  ```
  🏠 Find Your Perfect Rental with AI-Powered Search 🤖

  RoomFinder revolutionizes property hunting with cutting-edge AI technology. Whether you're a student, young professional, or anyone looking for the perfect rental, our intelligent platform makes finding and securing your ideal home effortless.

  ✨ KEY FEATURES:
  🔍 Smart Property Search - AI-powered matching based on your preferences
  🤖 AI Rent Negotiator - Get the best deals with our intelligent negotiation assistant  
  💬 Direct Messaging - Chat directly with property owners and landlords
  📍 Location-Based Search - Find properties near your work, school, or desired area
  ❤️ Save Favorites - Keep track of properties you love
  📷 High-Quality Photos - Browse detailed property images and virtual tours
  🏫 Student Housing - Specialized search for university students

  🎯 PERFECT FOR:
  • Students looking for housing near campus
  • Young professionals seeking urban apartments
  • Anyone relocating to a new city
  • Budget-conscious renters wanting the best deals

  🛡️ PRIVACY & SECURITY:
  Your data is protected with bank-level encryption. We never sell your personal information.

  📱 EASY TO USE:
  1. Set your preferences (budget, location, amenities)
  2. Browse AI-curated property recommendations
  3. Use our AI negotiator to get the best price
  4. Connect directly with property owners
  5. Secure your perfect rental!

  Join thousands of satisfied users who found their perfect home with RoomFinder!
  ```

#### Graphics
- **App icon**: 512x512 PNG (high-res version of your app icon)
- **Feature graphic**: 1024x500 PNG showcasing app interface
- **Phone screenshots**: Minimum 2, recommended 8 screenshots
- **Tablet screenshots**: Optional but recommended

### 4. App Bundle Upload
1. Go to "Release" → "Production"
2. Click "Create new release"
3. Upload your `app-release.aab` file
4. Fill in release notes:
   ```
   🎉 Welcome to RoomFinder v1.0!

   Features included in this release:
   • AI-powered property search and recommendations
   • Intelligent rent negotiation assistant
   • Direct messaging with property owners
   • Advanced filtering and search options
   • Secure user authentication
   • Favorites and saved searches
   • Student housing specialized features
   • High-quality property photos and details

   Ready to find your perfect rental? Download now and let AI help you discover your ideal home!
   ```

### 5. Content Rating
Complete the content rating questionnaire:
- **Violence**: None
- **Sexual Content**: None
- **Profanity**: None
- **Controlled Substances**: None
- **Gambling**: None
- **User-Generated Content**: Yes (users can post property listings and messages)
- **Location Sharing**: Yes (for property search)
- **Personal Information**: Yes (collected for account management)

### 6. App Access
- **App availability**: Make available in all countries
- **Device categories**: Phone and tablet
- **User programs**: Consider opting into Google Play Pass if eligible

## Testing Strategy

### 1. Internal Testing
- Upload AAB to internal testing track
- Test with your Google account
- Verify all features work correctly

### 2. Closed Testing (Optional)
- Add up to 100 test users
- Get feedback before public release
- Test on various devices and Android versions

### 3. Production Release
- Start with 5% rollout
- Monitor crash reports and user feedback
- Gradually increase to 100% if no issues

## Post-Launch Monitoring

### 1. Play Console Metrics
- **Install metrics**: Track downloads and install conversion
- **User acquisition**: Monitor where users come from
- **User behavior**: Analyze in-app actions and retention

### 2. Crash Reports
- Monitor vitals (crashes, ANRs, slow rendering)
- Fix critical issues quickly with hotfix updates
- Maintain 99%+ crash-free rate

### 3. User Reviews
- Respond to user reviews promptly and professionally
- Address common complaints in app updates
- Encourage satisfied users to leave positive reviews

## Update Strategy

### Version Updates
- **Patch updates** (1.0.1, 1.0.2): Bug fixes and minor improvements
- **Minor updates** (1.1.0, 1.2.0): New features and enhancements
- **Major updates** (2.0.0): Significant changes or redesigns

### Release Schedule
- **Critical bugs**: Hotfix within 24-48 hours
- **Regular updates**: Every 2-4 weeks
- **Major features**: Every 3-6 months

## Security Best Practices

1. **Regular security audits** of the codebase
2. **API key rotation** every 6-12 months  
3. **Dependency updates** to patch security vulnerabilities
4. **User data encryption** both in transit and at rest
5. **GDPR compliance** for international users

## Marketing and ASO

### App Store Optimization
- **Keywords**: room finder, apartment search, rent, housing, AI, property
- **Regular screenshot updates** showing new features
- **Seasonal promotions** (back-to-school for students)
- **Localization** for international markets

### User Acquisition
- **Social media presence** on Instagram, TikTok, Facebook
- **University partnerships** for student housing
- **Content marketing** about rental tips and property search
- **Referral program** to encourage user growth

## Support and Legal

### User Support
- **In-app help center** with FAQs and tutorials
- **Email support**: support@roomfinderai.com
- **Response time**: Within 24-48 hours

### Legal Compliance
- **Privacy policy** regularly updated and accessible
- **Terms of service** clearly defined
- **COPPA compliance** (no users under 13)
- **Fair housing laws** compliance in property listings

---

## Quick Checklist for Release

- [ ] API keys secured in local.properties
- [ ] Keystore created and properties configured
- [ ] Release build successfully generated
- [ ] Privacy policy hosted and accessible
- [ ] Google Play Developer account ready
- [ ] App icons and screenshots prepared
- [ ] Store listing content written
- [ ] Content rating questionnaire completed
- [ ] Internal testing completed successfully
- [ ] All permissions justified and documented

Ready to launch! 🚀