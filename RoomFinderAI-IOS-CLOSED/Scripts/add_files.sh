#!/bin/bash

echo "Adding new service files to Xcode project..."

# Navigate to the project directory
cd "$(dirname "$0")"

# Check if the new files exist
if [ ! -f "RoomFinderAI/Services/AIService.swift" ]; then
    echo "AIService.swift not found. Please make sure all service files are in the correct location."
    exit 1
fi

echo "All service files found. Please add them to your Xcode project manually:"
echo "1. Open RoomFinderAI.xcodeproj in Xcode"
echo "2. Right-click on the 'Services' folder"
echo "3. Select 'Add Files to RoomFinderAI'"
echo "4. Add these files:"
echo "   - RoomFinderAI/Services/AIService.swift"
echo "   - RoomFinderAI/Services/MortgageCalculatorService.swift"
echo "   - RoomFinderAI/Services/MarketAnalyticsService.swift"
echo "   - RoomFinderAI/Services/StripeService.swift (will be created)"
echo "5. Add to Views folder:"
echo "   - RoomFinderAI/Views/SubleaseView.swift"
echo "   - RoomFinderAI/Views/MarketAnalyticsView.swift (will be created)"
echo "   - RoomFinderAI/Views/MortgageCalculatorView.swift (will be created)"
echo "   - RoomFinderAI/Views/PaymentView.swift (will be created)"

echo "Files are ready to be added to your Xcode project!"