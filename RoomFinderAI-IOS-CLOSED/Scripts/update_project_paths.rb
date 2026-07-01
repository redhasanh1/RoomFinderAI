#!/usr/bin/env ruby

# Script to update file paths in Xcode project for new iOS structure

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"

# Read the project file
content = File.read(project_file)

# Define path mappings
path_mappings = {
  # Main source files
  "RoomFinderAIApp.swift" => "../../Source/RoomFinderAI/RoomFinderAIApp.swift",
  "ContentView.swift" => "../../Source/RoomFinderAI/ContentView.swift",
  "Info.plist" => "../../Source/RoomFinderAI/Resources/Info.plist",
  
  # Services
  "SupabaseService.swift" => "../../Source/RoomFinderAI/Services/SupabaseService.swift",
  "AuthViewModel.swift" => "../../Source/RoomFinderAI/Services/AuthViewModel.swift",
  "ListingsViewModel.swift" => "../../Source/RoomFinderAI/Services/ListingsViewModel.swift",
  "ChatViewModel.swift" => "../../Source/RoomFinderAI/Services/ChatViewModel.swift",
  "NetworkManager.swift" => "../../Source/RoomFinderAI/Services/NetworkManager.swift",
  "AIService.swift" => "../../Source/RoomFinderAI/Services/AIService.swift",
  "MarketAnalyticsService.swift" => "../../Source/RoomFinderAI/Services/MarketAnalyticsService.swift",
  "MortgageCalculatorService.swift" => "../../Source/RoomFinderAI/Services/MortgageCalculatorService.swift",
  "StripeService.swift" => "../../Source/RoomFinderAI/Services/StripeService.swift",
  "CachingService.swift" => "../../Source/RoomFinderAI/Services/CachingService.swift",
  "CoreDataService.swift" => "../../Source/RoomFinderAI/Services/CoreDataService.swift",
  "DatabaseOptimizationService.swift" => "../../Source/RoomFinderAI/Services/DatabaseOptimizationService.swift",
  "DatabasePerformanceService.swift" => "../../Source/RoomFinderAI/Services/DatabasePerformanceService.swift",
  "ImageLoadingService.swift" => "../../Source/RoomFinderAI/Services/ImageLoadingService.swift",
  "InterceptedURLSession.swift" => "../../Source/RoomFinderAI/Services/InterceptedURLSession.swift",
  "LoggingService.swift" => "../../Source/RoomFinderAI/Services/LoggingService.swift",
  "MediaLoadingService.swift" => "../../Source/RoomFinderAI/Services/MediaLoadingService.swift",
  "NetworkInterceptorService.swift" => "../../Source/RoomFinderAI/Services/NetworkInterceptorService.swift",
  "NetworkMonitoringService.swift" => "../../Source/RoomFinderAI/Services/NetworkMonitoringService.swift",
  "OfflineDataService.swift" => "../../Source/RoomFinderAI/Services/OfflineDataService.swift",
  "PaginationService.swift" => "../../Source/RoomFinderAI/Services/PaginationService.swift",
  "RateLimitingService.swift" => "../../Source/RoomFinderAI/Services/RateLimitingService.swift",
  "RetryService.swift" => "../../Source/RoomFinderAI/Services/RetryService.swift",
  
  # Views
  "LoginView.swift" => "../../Source/RoomFinderAI/Views/LoginView.swift",
  "SignUpView.swift" => "../../Source/RoomFinderAI/Views/SignUpView.swift",
  "DashboardView.swift" => "../../Source/RoomFinderAI/Views/DashboardView.swift",
  "ListingsView.swift" => "../../Source/RoomFinderAI/Views/ListingsView.swift",
  "PropertyDetailView.swift" => "../../Source/RoomFinderAI/Views/PropertyDetailView.swift",
  "ChatView.swift" => "../../Source/RoomFinderAI/Views/ChatView.swift",
  "ProfileView.swift" => "../../Source/RoomFinderAI/Views/ProfileView.swift",
  "PaymentView.swift" => "../../Source/RoomFinderAI/Views/PaymentView.swift",
  "SubleaseView.swift" => "../../Source/RoomFinderAI/Views/SubleaseView.swift",
  "MortgageCalculatorView.swift" => "../../Source/RoomFinderAI/Views/MortgageCalculatorView.swift",
  "MarketAnalyticsView.swift" => "../../Source/RoomFinderAI/Views/MarketAnalyticsView.swift",
  "OfflineStatusView.swift" => "../../Source/RoomFinderAI/Views/OfflineStatusView.swift",
  "LazyLoadingDemoView.swift" => "../../Source/RoomFinderAI/Views/LazyLoadingDemoView.swift",
  "NetworkInterceptorDemoView.swift" => "../../Source/RoomFinderAI/Views/NetworkInterceptorDemoView.swift",
  "NetworkMonitoringView.swift" => "../../Source/RoomFinderAI/Views/NetworkMonitoringView.swift",
  
  # Models
  "User.swift" => "../../Source/RoomFinderAI/Models/User.swift",
  "Listing.swift" => "../../Source/RoomFinderAI/Models/Listing.swift",
  "Chat.swift" => "../../Source/RoomFinderAI/Models/Chat.swift",
  "Message.swift" => "../../Source/RoomFinderAI/Models/Message.swift",
  
  # Utils
  "Constants.swift" => "../../Source/RoomFinderAI/Utils/Constants.swift",
  "Extensions.swift" => "../../Source/RoomFinderAI/Utils/Extensions.swift",
  "ErrorHandler.swift" => "../../Source/RoomFinderAI/Utils/ErrorHandler.swift",
  
  # Resources
  "Assets.xcassets" => "../../Source/RoomFinderAI/Resources/Assets.xcassets"
}

# Update the paths
path_mappings.each do |old_path, new_path|
  # Update file references
  content.gsub!(/path = #{Regexp.escape(old_path)};/, "path = #{new_path};")
  
  # Update build file references that might have full paths
  content.gsub!(/(path = ")[^"]*\/#{Regexp.escape(old_path)}(";)/, "\\1#{new_path}\\2")
end

# Write the updated content back
File.write(project_file, content)

puts "Updated project file paths successfully!"
puts "Files updated: #{path_mappings.keys.count}"