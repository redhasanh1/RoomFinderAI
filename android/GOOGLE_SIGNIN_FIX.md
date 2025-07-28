# 🔧 Fix Google Sign-In Error 10 - Step by Step

## The Problem
Error 10 means the SHA-1 certificate fingerprint in your Google Console doesn't match your development environment.

## 🚀 Quick Fix Steps

### Step 1: Get Your SHA-1 Fingerprint
Run this script in your Android project directory:
```bash
./get_sha1_fingerprint.sh
```

**OR manually run:**
```bash
# macOS/Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Windows  
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Look for the **SHA1** line - copy that fingerprint!

### Step 2: Update Google Console
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create new one)
3. Navigate to **APIs & Services** → **Credentials**
4. Find your **OAuth 2.0 client ID** for Android
5. Add your SHA-1 fingerprint from Step 1
6. Ensure package name is: `com.roomfinderai.app`

### Step 3: Alternative - Create New OAuth Client
If you don't have access to the existing project:

1. **Enable APIs:**
   - Google+ API (legacy) or Google Sign-In API
   - Sign-In with Google API

2. **Create OAuth Client:**
   - Type: Android
   - Package name: `com.roomfinderai.app`
   - SHA-1: Your fingerprint from Step 1

3. **Update the app:**
   - Copy the new client ID
   - Replace in `/app/src/main/res/values/strings.xml`:
   ```xml
   <string name="web_client_id">YOUR_NEW_CLIENT_ID</string>
   ```

### Step 4: Download google-services.json
1. In Google Console, go to your project
2. Download the **google-services.json** 
3. Replace `/app/android/app/google-services.json`

### Step 5: Test
1. Clean and rebuild your project
2. Test Google Sign-In
3. Check logcat for detailed error messages

## 📱 Current Configuration
- **Package:** `com.roomfinderai.app`
- **Current Client ID:** `971569749460-a8c7vqutq3eqjf1q6jtit28gqnos268v.apps.googleusercontent.com`

## 🆘 Still Having Issues?
Check the enhanced error messages in the app logs - they'll tell you exactly what's wrong!