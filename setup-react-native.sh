#!/bin/bash

# Script to set up a new React Native project

echo "🚀 Setting up React Native project..."

# Navigate to parent directory (assuming we're in the Capacitor project)
cd ..

# Create new React Native project
npx react-native@latest init RoomFinderAI --version 0.73.6

# Navigate to the new project
cd RoomFinderAI

# Install essential dependencies
echo "📦 Installing essential dependencies..."
npm install axios react-native-vector-icons @react-navigation/native @react-navigation/native-stack @react-navigation/bottom-tabs react-native-screens react-native-safe-area-context

# iOS specific installations
echo "🍎 Setting up iOS dependencies..."
cd ios && pod install && cd ..

echo "✅ React Native project setup complete!"
echo "📁 Your new project is in: ../RoomFinderAI"
echo "🏃‍♂️ To run: cd ../RoomFinderAI && npx react-native run-ios"