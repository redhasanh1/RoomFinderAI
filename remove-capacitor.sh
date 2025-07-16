#!/bin/bash

# Script to completely remove Capacitor from your project

echo "🗑️  Removing Capacitor from your project..."

# Remove Capacitor dependencies
npm uninstall @capacitor/core @capacitor/cli @capacitor/ios @capacitor/android @capacitor/app @capacitor/browser @capacitor/camera @capacitor/device @capacitor/filesystem @capacitor/geolocation @capacitor/haptics @capacitor/keyboard @capacitor/network @capacitor/preferences @capacitor/share @capacitor/splash-screen @capacitor/status-bar @capacitor/toast

# Remove Capacitor configuration files
rm -f capacitor.config.json
rm -f capacitor.config.ts

# Remove iOS and Android folders
rm -rf ios/
rm -rf android/

# Remove any Capacitor-specific files
rm -rf .capacitor/
rm -f src/capacitor-welcome.js

echo "✅ Capacitor has been completely removed!"
echo "📝 Don't forget to:"
echo "   - Remove any Capacitor imports from your React code"
echo "   - Remove Capacitor plugins from package.json manually if any remain"
echo "   - Clean up any Capacitor-specific code in your components"