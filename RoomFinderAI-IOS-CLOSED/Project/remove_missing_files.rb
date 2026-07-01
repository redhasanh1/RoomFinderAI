#!/usr/bin/env ruby

require 'xcodeproj'

# List of files to remove from the project
missing_files = [
  'KeychainManager.swift',
  'CDChat.swift',
  'CDMessage.swift', 
  'CDUser.swift',
  'CDListing.swift',
  'OfflineStatusView.swift',
  'PaymentView.swift',
  'MortgageCalculatorView.swift',
  'MarketAnalyticsView.swift',
  'ErrorHandler.swift',
  'StripeService.swift',
  'MortgageCalculatorService.swift',
  'MarketAnalyticsService.swift',
  'AIService.swift',
  'MediaLoadingService.swift',
  'ImageLoadingService.swift',
  'CoreDataService.swift',
  'RateLimitingService.swift',
  'InterceptedURLSession.swift',
  'NetworkInterceptorService.swift',
  'RetryService.swift',
  'DatabasePerformanceService.swift',
  'DatabaseOptimizationService.swift',
  'NetworkMonitoringService.swift',
  'CachingService.swift',
  'LoggingService.swift',
  'OfflineDataService.swift',
  'PaginationService.swift',
  'Message.swift',
  'Chat.swift',
  'ChatView.swift',
  'NetworkManager.swift',
  'ChatViewModel.swift',
  'ListingsViewModel.swift',
  'AuthViewModel.swift',
  'SupabaseService.swift'
]

project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Removing missing file references..."

missing_files.each do |filename|
  files_to_remove = project.files.select { |file| file.path&.include?(filename) }
  
  files_to_remove.each do |file|
    puts "Removing: #{file.path}"
    file.remove_from_project
  end
end

project.save

puts "✅ Done! Removed #{missing_files.length} missing file references from Xcode project."
puts "You can now build the project successfully."