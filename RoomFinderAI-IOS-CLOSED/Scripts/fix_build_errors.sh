#!/bin/bash

# Navigate to the project directory
cd /Users/arsalanamirali/Downloads/RoomFinderAI/ios-native

# Function to add file to Xcode project
add_file_to_xcode() {
    local file_path=$1
    local group_name=$2
    local file_name=$(basename "$file_path")
    
    echo "Adding $file_name to $group_name group..."
    
    # Use ruby script to add files to Xcode project
    ruby -e "
require 'xcodeproj'

project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == 'RoomFinderAI' }

# Find or create the group
main_group = project.main_group['RoomFinderAI']
group = main_group['$group_name'] || main_group.new_group('$group_name')

# Add file reference
file_ref = group.new_file('$file_path')

# Add to build phase
if file_ref && target
    target.add_file_references([file_ref])
end

project.save
"
}

# First, let's fix the immediate compilation errors
echo "Fixing ListingSortBy reference in PaginationService.swift..."
sed -i '' 's/ListingSortBy/SortOption/g' /Users/arsalanamirali/Downloads/RoomFinderAI/ios-native/RoomFinderAI/Services/PaginationService.swift

echo "Fixing ListingSortBy reference in DatabaseOptimizationService.swift..."
sed -i '' 's/ListingSortBy/SortOption/g' /Users/arsalanamirali/Downloads/RoomFinderAI/ios-native/RoomFinderAI/Services/DatabaseOptimizationService.swift

# Add missing files to Xcode project
echo "Adding missing files to Xcode project..."

# Add Utils files
add_file_to_xcode "RoomFinderAI/Utils/ErrorHandler.swift" "Utils"

# Add Service files
add_file_to_xcode "RoomFinderAI/Services/PaginationService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/OfflineDataService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/LoggingService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/CachingService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/NetworkMonitoringService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/DatabaseOptimizationService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/DatabasePerformanceService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/RetryService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/NetworkInterceptorService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/InterceptedURLSession.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/RateLimitingService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/CoreDataService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/ImageLoadingService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/MediaLoadingService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/AIService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/MarketAnalyticsService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/MortgageCalculatorService.swift" "Services"
add_file_to_xcode "RoomFinderAI/Services/StripeService.swift" "Services"

# Add View files
add_file_to_xcode "RoomFinderAI/Views/MarketAnalyticsView.swift" "Views"
add_file_to_xcode "RoomFinderAI/Views/MortgageCalculatorView.swift" "Views"
add_file_to_xcode "RoomFinderAI/Views/PaymentView.swift" "Views"
add_file_to_xcode "RoomFinderAI/Views/SubleaseView.swift" "Views"
add_file_to_xcode "RoomFinderAI/Views/OfflineStatusView.swift" "Views"

echo "Build fix script completed!"