#!/bin/bash

echo "=== Android Debug SHA-1 Fingerprint Generator ==="
echo ""

# Try different common locations for debug keystore
KEYSTORE_LOCATIONS=(
    "$HOME/.android/debug.keystore"
    "$ANDROID_HOME/.android/debug.keystore" 
    "$USERPROFILE\\.android\\debug.keystore"
    "./debug.keystore"
)

echo "Searching for debug keystore..."
KEYSTORE_FOUND=""

for location in "${KEYSTORE_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        echo "Found keystore at: $location"
        KEYSTORE_FOUND="$location"
        break
    fi
done

if [ -z "$KEYSTORE_FOUND" ]; then
    echo "❌ Debug keystore not found in common locations."
    echo ""
    echo "Please run this command manually with your keystore location:"
    echo "keytool -list -v -keystore [PATH_TO_KEYSTORE] -alias androiddebugkey -storepass android -keypass android"
    echo ""
    echo "Common locations:"
    echo "  - macOS/Linux: ~/.android/debug.keystore"
    echo "  - Windows: %USERPROFILE%\\.android\\debug.keystore"
    exit 1
fi

echo ""
echo "Getting SHA-1 fingerprint from: $KEYSTORE_FOUND"
echo "========================================"

# Extract SHA-1 fingerprint
keytool -list -v -keystore "$KEYSTORE_FOUND" -alias androiddebugkey -storepass android -keypass android 2>/dev/null | grep -i "sha1" | head -1

echo ""
echo "========================================"
echo "📋 COPY THE SHA-1 FINGERPRINT ABOVE"
echo ""
echo "Next steps:"
echo "1. Go to Google Cloud Console: https://console.cloud.google.com/"
echo "2. Select your project or create a new one"
echo "3. Go to 'APIs & Services' > 'Credentials'"
echo "4. Find your OAuth 2.0 client ID for Android (or create one)"
echo "5. Add the SHA-1 fingerprint above"
echo "6. Make sure package name is: com.roomfinderai.app"
echo "7. Download the updated google-services.json"
echo "8. Replace android/app/google-services.json in your project"
echo ""
echo "Current OAuth Client ID in your app:"
echo "971569749460-a8c7vqutq3eqjf1q6jtit28gqnos268v.apps.googleusercontent.com"