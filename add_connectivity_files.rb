#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Files to add
files_to_add = [
  '../Source/RoomFinderAI/Views/ConnectivityTestView.swift',
  '../Source/RoomFinderAI/Views/RealtimeTestView.swift',
  '../Source/RoomFinderAI/Services/ListingsRealtime.swift'
]

files_to_add.each do |file_path|
  next unless File.exist?(file_path)
  
  # Skip if file is already in project
  existing_file = project.files.find { |f| f.path == file_path }
  next if existing_file
  
  puts "Adding #{file_path}"
  
  # Add file reference to project
  file_ref = project.new_file(file_path)
  
  # Add file to target if it's a .swift file
  if file_path.end_with?('.swift')
    target.add_file_references([file_ref])
  end
end

# Save the project
project.save

puts "✅ Updated Xcode project with connectivity files"