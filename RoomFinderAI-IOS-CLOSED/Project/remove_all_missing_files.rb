#!/usr/bin/env ruby

require 'xcodeproj'

# List of missing files from the error message
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

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Track removed files
removed_files = []

# Find and remove each missing file
missing_files.each do |filename|
  project.targets.each do |target|
    target.source_build_phase.files.each do |file|
      if file.file_ref && file.file_ref.path && file.file_ref.path.include?(filename)
        puts "Removing #{filename} from #{target.name}"
        file.remove_from_project
        removed_files << filename
      end
    end
  end
  
  # Also remove from the project file references
  project.files.each do |file|
    if file.path && file.path.include?(filename)
      puts "Removing file reference: #{file.path}"
      file.remove_from_project
    end
  end
end

# Save the project
project.save

puts "\n✅ Removed #{removed_files.uniq.count} missing file references from the project"
puts "\nRemoved files:"
removed_files.uniq.sort.each { |f| puts "  - #{f}" }