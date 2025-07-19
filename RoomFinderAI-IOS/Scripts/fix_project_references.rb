#!/usr/bin/env ruby

# Fix all inconsistent file references in Xcode project

project_file = "Project/RoomFinderAI.xcodeproj/project.pbxproj"
content = File.read(project_file)

# List of files that should have consistent paths
files_to_fix = [
  # Views
  "ProfileView.swift",
  "MarketAnalyticsView.swift", 
  "MortgageCalculatorView.swift",
  "PaymentView.swift",
  "SubleaseView.swift",
  "OfflineStatusView.swift",
  "LazyLoadingDemoView.swift",
  "NetworkInterceptorDemoView.swift",
  "NetworkMonitoringView.swift",
  
  # Services
  "AIService.swift",
  "MarketAnalyticsService.swift",
  "MortgageCalculatorService.swift",
  "StripeService.swift",
  "CachingService.swift",
  "CoreDataService.swift",
  "DatabaseOptimizationService.swift",
  "DatabasePerformanceService.swift",
  "ImageLoadingService.swift",
  "InterceptedURLSession.swift",
  "LoggingService.swift",
  "MediaLoadingService.swift",
  "NetworkInterceptorService.swift",
  "NetworkMonitoringService.swift",
  "OfflineDataService.swift",
  "PaginationService.swift",
  "RateLimitingService.swift",
  "RetryService.swift",
  
  # Utils
  "ErrorHandler.swift"
]

# Fix each file to use consistent relative paths
files_to_fix.each do |filename|
  # Determine the correct path based on file type
  if filename.include?("View.swift")
    correct_path = "../Source/RoomFinderAI/Views/#{filename}"
  elsif filename.include?("Service.swift") || filename.include?("Session.swift")
    correct_path = "../Source/RoomFinderAI/Services/#{filename}"
  elsif filename.include?("Handler.swift")
    correct_path = "../Source/RoomFinderAI/Utils/#{filename}"
  else
    # Default to Services for other files
    correct_path = "../Source/RoomFinderAI/Services/#{filename}"
  end
  
  # Fix PBXFileReference entries
  content.gsub!(/(\w+) \/\* #{Regexp.escape(filename)} \*\/ = \{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode\.swift; name = #{Regexp.escape(filename)}; path = [^;]+; sourceTree = "<group>"; \};/) do |match|
    id = $1
    "#{id} /* #{filename} */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = #{filename}; path = #{correct_path}; sourceTree = \"<group>\"; };"
  end
  
  # Fix any remaining references without the correct path
  content.gsub!(/name = #{Regexp.escape(filename)}; path = #{Regexp.escape(filename)};/, "name = #{filename}; path = #{correct_path};")
  content.gsub!(/name = #{Regexp.escape(filename)}; path = [^;]+#{Regexp.escape(filename)};/, "name = #{filename}; path = #{correct_path};")
end

# Write the updated content back
File.write(project_file, content)

puts "Fixed all inconsistent file references in project!"
puts "Files processed: #{files_to_fix.count}"