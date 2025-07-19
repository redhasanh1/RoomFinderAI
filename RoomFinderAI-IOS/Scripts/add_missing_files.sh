#!/bin/bash

# Script to add missing service files to Xcode project
# This script adds the new service files and views to the Xcode project

echo "🔧 Adding new service files to Xcode project..."

# List of files to add
FILES=(
    "RoomFinderAI/Services/AIService.swift"
    "RoomFinderAI/Services/MortgageCalculatorService.swift"
    "RoomFinderAI/Services/MarketAnalyticsService.swift"
    "RoomFinderAI/Services/StripeService.swift"
    "RoomFinderAI/Views/SubleaseView.swift"
    "RoomFinderAI/Views/MarketAnalyticsView.swift"
    "RoomFinderAI/Views/MortgageCalculatorView.swift"
    "RoomFinderAI/Views/PaymentView.swift"
)

echo "Files to add to Xcode project:"
for file in "${FILES[@]}"; do
    echo "  - $file"
done

echo ""
echo "⚠️  MANUAL STEPS REQUIRED:"
echo "1. Open RoomFinderAI.xcodeproj in Xcode"
echo "2. Right-click on the appropriate folders (Services/Views)"
echo "3. Select 'Add Files to RoomFinderAI'"
echo "4. Navigate to the files listed above and add them"
echo "5. Make sure 'Add to target: RoomFinderAI' is checked"
echo "6. Click 'Add'"
echo ""
echo "OR use the following terminal command (if you have Xcode command line tools):"
echo "open -a Xcode RoomFinderAI.xcodeproj"
echo ""
echo "Then build the project to test the integration."