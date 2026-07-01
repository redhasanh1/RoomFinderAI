#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# List of all missing files from the error
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

puts "Searching for missing file references in ALL build phases..."
total_removed = 0

# Check all targets
project.targets.each do |target|
  puts "\nTarget: #{target.name}"
  
  # Check all build phases
  target.build_phases.each do |phase|
    phase_name = phase.class.name.split('::').last
    files_to_remove = []
    
    # Get files from the phase
    if phase.respond_to?(:files)
      phase.files.each do |build_file|
        next unless build_file.file_ref
        
        file_path = build_file.file_ref.path || build_file.file_ref.name || ""
        file_name = File.basename(file_path)
        
        # Check if this is one of our missing files
        if missing_files.include?(file_name)
          puts "  Found in #{phase_name}: #{file_name}"
          files_to_remove << build_file
        end
      end
    end
    
    # Remove the files
    files_to_remove.each do |build_file|
      puts "    Removing: #{build_file.file_ref.path || build_file.file_ref.name}"
      build_file.remove_from_project
      total_removed += 1
    end
  end
  
  # Also check for any custom build rules or script phases
  if target.respond_to?(:build_rules)
    target.build_rules.each do |rule|
      puts "  Build rule found: #{rule}"
    end
  end
end

# Also check the project for any file references not in targets
puts "\nChecking for orphaned file references..."
project.files.each do |file_ref|
  next unless file_ref.path
  
  file_name = File.basename(file_ref.path)
  if missing_files.include?(file_name)
    puts "  Removing orphaned reference: #{file_ref.path}"
    file_ref.remove_from_project
    total_removed += 1
  end
end

# Check for any groups that might contain these files
puts "\nChecking all groups recursively..."
def check_group(group, missing_files, removed_count)
  group.children.each do |child|
    if child.isa == 'PBXFileReference'
      if child.path
        file_name = File.basename(child.path)
        if missing_files.include?(file_name)
          puts "  Removing from group: #{child.path}"
          child.remove_from_project
          removed_count[0] += 1
        end
      end
    elsif child.isa == 'PBXGroup'
      check_group(child, missing_files, removed_count)
    end
  end
end

removed_in_groups = [0]
check_group(project.main_group, missing_files, removed_in_groups)
total_removed += removed_in_groups[0]

# Save the project
project.save

puts "\n✅ Complete! Removed #{total_removed} file references from the project."
puts "\nIf you still see errors, try:"
puts "1. Clean Build Folder (Cmd+Shift+K in Xcode)"
puts "2. Delete Derived Data"
puts "3. Restart Xcode"