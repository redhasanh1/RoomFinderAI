#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# File to add
file_path = 'Source/RoomFinderAI/Config/Secrets.swift'

# Skip if file is already in project
existing_file = project.files.find { |f| f.path == file_path }
if existing_file
  puts "File already exists in project"
else
  puts "Adding #{file_path}"
  
  # Add file reference to project
  file_ref = project.new_file(file_path)
  
  # Add file to target
  target.add_file_references([file_ref])
  
  # Save the project
  project.save
  
  puts "✅ Added Secrets.swift to Xcode project"
end