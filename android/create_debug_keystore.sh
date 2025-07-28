#!/bin/bash

echo "🔧 Creating Android Debug Keystore..."

# Create .android directory if it doesn't exist
mkdir -p ~/.android

# Generate debug keystore with default values
keytool -genkey -v \
    -keystore ~/.android/debug.keystore \
    -storepass android \
    -alias androiddebugkey \
    -keypass android \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US"

echo ""
echo "✅ Debug keystore created!"
echo ""
echo "🔍 Getting SHA-1 fingerprint..."
echo "================================"

# Get the SHA-1 fingerprint
keytool -list -v \
    -keystore ~/.android/debug.keystore \
    -alias androiddebugkey \
    -storepass android \
    -keypass android | grep -i "sha1"

echo ""
echo "📋 COPY THE SHA-1 FINGERPRINT ABOVE"
echo ""
echo "Next: Add this SHA-1 to your Google Console OAuth client"
echo "Package name: com.roomfinderai.app"