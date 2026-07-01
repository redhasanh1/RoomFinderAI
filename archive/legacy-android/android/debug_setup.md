# Google Sign-In Debug Setup

## Issue Diagnosis
Google Sign-In error 10 (DEVELOPER_ERROR) typically occurs due to configuration mismatch between:
1. OAuth client ID in your Google Console project
2. SHA-1 certificate fingerprint 
3. Package name

## Steps to Fix:

### 1. Get your debug SHA-1 fingerprint
Run this command in Android Studio terminal or command line:

For macOS/Linux:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

For Windows:
```bash
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### 2. Update Google Console Configuration
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create one)
3. Go to "Credentials" in APIs & Services
4. Find your OAuth 2.0 client ID for Android
5. Add your debug SHA-1 fingerprint
6. Ensure package name is: `com.roomfinderai.app`

### 3. Download updated google-services.json
1. In Firebase Console or Google Cloud Console
2. Download the updated google-services.json
3. Replace the file in `/app/android/app/google-services.json`

### 4. Alternative: Create new OAuth client
If you don't have access to the original project:
1. Create new project in Google Cloud Console
2. Enable Google+ API
3. Create OAuth 2.0 client ID (Android)
4. Use package name: `com.roomfinderai.app`
5. Add your SHA-1 fingerprint
6. Update the client ID in `/app/android/app/src/main/res/values/strings.xml`

## Current Configuration
- Package name: `com.roomfinderai.app`
- Current OAuth client ID: `971569749460-a8c7vqutq3eqjf1q6jtit28gqnos268v.apps.googleusercontent.com`

## Testing
After making changes:
1. Clean and rebuild the project
2. Test Google Sign-In in the emulator/device
3. Check logcat for detailed error messages

## Temporary Workaround
The updated LoginActivity now provides better error messages and debugging information to help identify the exact issue.