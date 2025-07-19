#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'RoomFinderAI' }
main_group = project.main_group['RoomFinderAI']

# Remove all incorrectly added files
puts "Removing incorrectly added files..."
files_to_remove = []

project.files.each do |file_ref|
  if file_ref.path && (file_ref.path.include?('RoomFinderAI/Services/RoomFinderAI/Services/') ||
                      file_ref.path.include?('RoomFinderAI/Utils/RoomFinderAI/Utils/') ||
                      file_ref.path.include?('RoomFinderAI/Views/RoomFinderAI/Views/'))
    files_to_remove << file_ref
  end
end

files_to_remove.each do |file_ref|
  puts "Removing: #{file_ref.path}"
  file_ref.remove_from_project
end

# Now add files correctly
puts "\nAdding files with correct paths..."

# Service files to add
service_files = {
  'PaginationService.swift' => 'RoomFinderAI/Services/PaginationService.swift',
  'OfflineDataService.swift' => 'RoomFinderAI/Services/OfflineDataService.swift',
  'LoggingService.swift' => 'RoomFinderAI/Services/LoggingService.swift',
  'CachingService.swift' => 'RoomFinderAI/Services/CachingService.swift',
  'NetworkMonitoringService.swift' => 'RoomFinderAI/Services/NetworkMonitoringService.swift',
  'DatabaseOptimizationService.swift' => 'RoomFinderAI/Services/DatabaseOptimizationService.swift',
  'DatabasePerformanceService.swift' => 'RoomFinderAI/Services/DatabasePerformanceService.swift',
  'RetryService.swift' => 'RoomFinderAI/Services/RetryService.swift',
  'NetworkInterceptorService.swift' => 'RoomFinderAI/Services/NetworkInterceptorService.swift',
  'InterceptedURLSession.swift' => 'RoomFinderAI/Services/InterceptedURLSession.swift',
  'RateLimitingService.swift' => 'RoomFinderAI/Services/RateLimitingService.swift',
  'CoreDataService.swift' => 'RoomFinderAI/Services/CoreDataService.swift',
  'ImageLoadingService.swift' => 'RoomFinderAI/Services/ImageLoadingService.swift',
  'MediaLoadingService.swift' => 'RoomFinderAI/Services/MediaLoadingService.swift',
  'AIService.swift' => 'RoomFinderAI/Services/AIService.swift',
  'MarketAnalyticsService.swift' => 'RoomFinderAI/Services/MarketAnalyticsService.swift',
  'MortgageCalculatorService.swift' => 'RoomFinderAI/Services/MortgageCalculatorService.swift',
  'StripeService.swift' => 'RoomFinderAI/Services/StripeService.swift'
}

# Utils files to add
utils_files = {
  'ErrorHandler.swift' => 'RoomFinderAI/Utils/ErrorHandler.swift'
}

# View files to add
view_files = {
  'MarketAnalyticsView.swift' => 'RoomFinderAI/Views/MarketAnalyticsView.swift',
  'MortgageCalculatorView.swift' => 'RoomFinderAI/Views/MortgageCalculatorView.swift',
  'PaymentView.swift' => 'RoomFinderAI/Views/PaymentView.swift',
  'SubleaseView.swift' => 'RoomFinderAI/Views/SubleaseView.swift',
  'OfflineStatusView.swift' => 'RoomFinderAI/Views/OfflineStatusView.swift'
}

# Function to add file to group
def add_file_to_group(project, main_group, target, file_name, file_path, group_name)
  group = main_group[group_name] || main_group.new_group(group_name)
  
  # Check if file already exists
  existing = group.files.find { |f| f.name == file_name }
  
  if existing.nil?
    file_ref = group.new_reference(file_path)
    file_ref.name = file_name
    
    # Add to build phase
    target.add_file_references([file_ref])
    puts "Added: #{file_name} to #{group_name}"
  else
    puts "Skipped (already exists): #{file_name}"
  end
end

# Add service files
service_files.each do |name, path|
  add_file_to_group(project, main_group, target, name, path, 'Services')
end

# Add utils files
utils_files.each do |name, path|
  add_file_to_group(project, main_group, target, name, path, 'Utils')
end

# Add view files
view_files.each do |name, path|
  add_file_to_group(project, main_group, target, name, path, 'Views')
end

# Save the project
project.save

puts "\nProject fixed successfully!"