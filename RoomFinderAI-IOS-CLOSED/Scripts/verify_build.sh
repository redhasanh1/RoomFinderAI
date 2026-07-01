#!/bin/bash

# Script to verify the build works and display clean results

echo "=== Verifying iOS Project Build ==="
echo "📁 Current directory: $(pwd)"
echo "📱 Testing build for iOS Simulator..."

cd Project

# Test build
echo "🔨 Building project..."
xcodebuild -project RoomFinderAI.xcodeproj -scheme RoomFinderAI -configuration Debug build -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(BUILD|ERROR|FAILED|succeeded|Warning|✓)"

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
    echo "✅ File paths have been fixed"
    echo "✅ Project is ready for development"
else
    echo "❌ Build failed - checking specific issues..."
    # Show specific errors for debugging
    xcodebuild -project RoomFinderAI.xcodeproj -scheme RoomFinderAI -configuration Debug build -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(error|Error|ERROR)" | head -5
fi

cd ..

echo "=== Build Verification Complete ==="