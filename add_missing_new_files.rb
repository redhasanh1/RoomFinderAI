#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Files to add with specific references
files_to_add = [
  {
    path: '../Source/RoomFinderAI/Config/SupabaseClient.swift',
    build_file_ref: 'F1234567890123456789008',
    file_ref: 'F1234567890123456789108'
  },
  {
    path: '../Source/RoomFinderAI/Views/ListingsTabView.swift',
    build_file_ref: 'F1234567890123456789009',
    file_ref: 'F1234567890123456789109'
  }
]

files_to_add.each do |file_info|
  next unless File.exist?(file_info[:path])
  
  # Skip if file is already in project
  existing_file = project.files.find { |f| f.path == file_info[:path] }
  next if existing_file
  
  puts "Adding #{file_info[:path]}"
  
  # Add file reference to project
  file_ref = project.new_file(file_info[:path])
  file_ref.uuid = file_info[:file_ref]
  
  # Add file to target
  build_file = target.add_file_references([file_ref]).first
  build_file.uuid = file_info[:build_file_ref]
end

# Save the project
project.save

puts "✅ Updated Xcode project with missing files"