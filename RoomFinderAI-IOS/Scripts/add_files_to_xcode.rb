#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'RoomFinderAI' }
main_group = project.main_group['RoomFinderAI']

# Helper function to add file to group and target
def add_file_to_project(project, main_group, target, file_path, group_name)
  # Find or create the group
  group = main_group[group_name] || main_group.new_group(group_name)
  
  # Check if file already exists in project
  existing_ref = group.files.find { |f| f.path == file_path }
  
  if existing_ref.nil?
    # Add file reference
    file_ref = group.new_file(file_path)
    
    # Add to build phase if it's a Swift file
    if file_path.end_with?('.swift')
      target.add_file_references([file_ref])
    end
    
    puts "Added: #{File.basename(file_path)} to #{group_name}"
  else
    puts "Skipped (already exists): #{File.basename(file_path)}"
  end
end

# Service files to add
service_files = [
  'RoomFinderAI/Services/PaginationService.swift',
  'RoomFinderAI/Services/OfflineDataService.swift',
  'RoomFinderAI/Services/LoggingService.swift',
  'RoomFinderAI/Services/CachingService.swift',
  'RoomFinderAI/Services/NetworkMonitoringService.swift',
  'RoomFinderAI/Services/DatabaseOptimizationService.swift',
  'RoomFinderAI/Services/DatabasePerformanceService.swift',
  'RoomFinderAI/Services/RetryService.swift',
  'RoomFinderAI/Services/NetworkInterceptorService.swift',
  'RoomFinderAI/Services/InterceptedURLSession.swift',
  'RoomFinderAI/Services/RateLimitingService.swift',
  'RoomFinderAI/Services/CoreDataService.swift',
  'RoomFinderAI/Services/ImageLoadingService.swift',
  'RoomFinderAI/Services/MediaLoadingService.swift',
  'RoomFinderAI/Services/AIService.swift',
  'RoomFinderAI/Services/MarketAnalyticsService.swift',
  'RoomFinderAI/Services/MortgageCalculatorService.swift',
  'RoomFinderAI/Services/StripeService.swift'
]

# Utils files to add
utils_files = [
  'RoomFinderAI/Utils/ErrorHandler.swift'
]

# View files to add
view_files = [
  'RoomFinderAI/Views/MarketAnalyticsView.swift',
  'RoomFinderAI/Views/MortgageCalculatorView.swift',
  'RoomFinderAI/Views/PaymentView.swift',
  'RoomFinderAI/Views/SubleaseView.swift',
  'RoomFinderAI/Views/OfflineStatusView.swift'
]

# Add all service files
service_files.each do |file_path|
  add_file_to_project(project, main_group, target, file_path, 'Services')
end

# Add all utils files
utils_files.each do |file_path|
  add_file_to_project(project, main_group, target, file_path, 'Utils')
end

# Add all view files
view_files.each do |file_path|
  add_file_to_project(project, main_group, target, file_path, 'Views')
end

# Save the project
project.save

puts "\nProject updated successfully!"