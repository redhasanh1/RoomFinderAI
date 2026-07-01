#!/usr/bin/env ruby

require 'xcodeproj'
require 'pathname'

# Full paths from the error message
missing_file_paths = [
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Utils/KeychainManager.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Source/RoomFinderAI/Models/CoreData/CDChat.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Source/RoomFinderAI/Models/CoreData/CDMessage.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Source/RoomFinderAI/Models/CoreData/CDUser.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Source/RoomFinderAI/Models/CoreData/CDListing.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Views/OfflineStatusView.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Views/PaymentView.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Views/MortgageCalculatorView.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Views/MarketAnalyticsView.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/StripeService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/MortgageCalculatorService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/MarketAnalyticsService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/AIService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/MediaLoadingService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/ImageLoadingService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/CoreDataService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/RateLimitingService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/InterceptedURLSession.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/NetworkInterceptorService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/RetryService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/DatabasePerformanceService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/DatabaseOptimizationService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/NetworkMonitoringService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/CachingService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/LoggingService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/OfflineDataService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/PaginationService.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Models/Message.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Models/Chat.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Views/ChatView.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/NetworkManager.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/ChatViewModel.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/ListingsViewModel.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/AuthViewModel.swift',
  '/Users/arsalanamirali/Downloads/RoomFinderAI/RoomFinderAI-IOS/Project/RoomFinderAI/Source/RoomFinderAI/Services/SupabaseService.swift'
]

# Note: ErrorHandler.swift exists but at wrong path in project file

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

removed_count = 0

# Extract filenames for easier matching
filenames_to_remove = missing_file_paths.map { |path| File.basename(path) }

puts "Looking for #{filenames_to_remove.count} missing files..."

# Remove from all targets
project.targets.each do |target|
  files_to_remove = []
  
  target.source_build_phase.files.each do |build_file|
    next unless build_file.file_ref
    
    file_name = build_file.file_ref.name || build_file.file_ref.path
    next unless file_name
    
    # Check if this is one of our missing files
    if filenames_to_remove.include?(File.basename(file_name))
      # Try to get the full path
      begin
        full_path = build_file.file_ref.real_path.to_s
      rescue
        full_path = nil
      end
      
      # If we can't resolve the path or the file doesn't exist
      if full_path.nil? || !File.exist?(full_path) || missing_file_paths.any? { |p| full_path.include?(File.basename(p)) }
        files_to_remove << build_file
        puts "  Marking for removal: #{file_name}"
      end
    end
  end
  
  # Remove the files
  files_to_remove.each do |build_file|
    build_file.remove_from_project
    removed_count += 1
  end
end

# Also remove orphaned file references
project.files.each do |file_ref|
  next unless file_ref.path
  
  file_name = File.basename(file_ref.path)
  if filenames_to_remove.include?(file_name)
    begin
      full_path = file_ref.real_path.to_s
      if !File.exist?(full_path)
        puts "  Removing orphaned reference: #{file_ref.path}"
        file_ref.remove_from_project
        removed_count += 1
      end
    rescue
      # If we can't resolve the path, it's probably broken
      puts "  Removing broken reference: #{file_ref.path}"
      file_ref.remove_from_project
      removed_count += 1
    end
  end
end

# Save the project
project.save

puts "\n✅ Removed #{removed_count} file references from the project"