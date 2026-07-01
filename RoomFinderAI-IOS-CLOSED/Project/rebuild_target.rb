#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the target
target = project.targets.find { |t| t.name == 'RoomFinderAI' }

puts "Current files in target:"
target.source_build_phase.files.each do |file|
  if file.file_ref
    puts "  - #{file.file_ref.path || file.file_ref.name}"
  end
end

# Clear all source files from the target
puts "\nClearing all source files from target..."
target.source_build_phase.clear

# List of files that we know exist
existing_files = [
  'Source/RoomFinderAI/RoomFinderAIApp.swift',
  'Source/RoomFinderAI/ContentView.swift',
  'RoomFinderAI/Source/RoomFinderAI/Views/LoginView.swift',
  'RoomFinderAI/Source/RoomFinderAI/Views/SignUpView.swift',
  'RoomFinderAI/Source/RoomFinderAI/Views/DashboardView.swift',
  'RoomFinderAI/Source/RoomFinderAI/Views/ListingsView.swift',
  'RoomFinderAI/Source/RoomFinderAI/Views/PropertyDetailView.swift',
  'RoomFinderAI/Source/RoomFinderAI/Views/ProfileView.swift',
  'RoomFinderAI/Source/RoomFinderAI/Models/User.swift',
  'RoomFinderAI/Source/RoomFinderAI/Models/Listing.swift',
  'RoomFinderAI/Source/RoomFinderAI/Utils/Constants.swift',
  'RoomFinderAI/Source/RoomFinderAI/Utils/Extensions.swift',
  'RoomFinderAI/Source/RoomFinderAI/Views/SubleaseView.swift',
  '../Source/RoomFinderAI/Services/MockDataService.swift',
  '../Source/RoomFinderAI/Services/SimpleAuthViewModel.swift',
  '../Source/RoomFinderAI/Services/SimpleListingsViewModel.swift',
  '../Source/RoomFinderAI/Components/SharedComponents.swift'
]

# Find and add only existing files
puts "\nAdding existing files back to target..."
added_count = 0

project.files.each do |file_ref|
  next unless file_ref.path
  
  # Check if this file should be in our target
  if existing_files.any? { |f| file_ref.path.include?(File.basename(f)) }
    # Check if file actually exists
    begin
      full_path = file_ref.real_path
      if File.exist?(full_path.to_s)
        target.add_file_references([file_ref])
        puts "  ✅ Added: #{file_ref.path}"
        added_count += 1
      else
        puts "  ❌ File doesn't exist: #{file_ref.path}"
      end
    rescue
      puts "  ❌ Can't resolve path: #{file_ref.path}"
    end
  end
end

# Save the project
project.save

puts "\n✅ Rebuilt target with #{added_count} source files"
puts "\nTry building now!"